// lib/core/notifications/notification_service.dart
//
// Envoltorio sobre flutter_local_notifications (NOT-01/02/03).
// Solo hace algo en Android e iOS; en escritorio/web todas las llamadas
// son no-op para que la app siga funcionando durante el desarrollo.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../features/reminders/domain/reminder_planner.dart';
import 'notification_actions.dart';

/// IDs de las acciones de la notificación (NOT-02)
const kActionTake = 'take';
const kActionSnooze = 'snooze';

/// Minutos que se pospone un recordatorio
const kSnoozeMinutes = 10;

const _androidChannelId = 'dose_reminders_v1';
const _darwinCategoryId = 'dose_reminder';

class NotificationPermissionStatus {
  final bool notificationsEnabled;
  final bool exactAlarmsAllowed;

  const NotificationPermissionStatus({
    required this.notificationsEnabled,
    required this.exactAlarmsAllowed,
  });

  static const allGranted = NotificationPermissionStatus(
      notificationsEnabled: true, exactAlarmsAllowed: true);

  bool get isOk => notificationsEnabled && exactAlarmsAllowed;
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Avisa (en el isolate principal) cuando una notificación cambió datos,
  /// para que la pantalla Hoy se recargue.
  final StreamController<void> _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;
  void notifyChanged() => _changes.add(null);

  /// Las notificaciones locales programadas solo existen en Android e iOS.
  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> ensureInitialized() async {
    if (_initialized || !isSupported) return;

    final darwin = DarwinInitializationSettings(
      // Los permisos se piden explícitamente con requestPermissions()
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          _darwinCategoryId,
          actions: [
            DarwinNotificationAction.plain(kActionTake, 'Tomado'),
            DarwinNotificationAction.plain(
                kActionSnooze, 'Posponer $kSnoozeMinutes min'),
          ],
        ),
      ],
    );

    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('ic_stat_pill'),
        iOS: darwin,
      ),
      // App abierta (o al tocar la notificación)
      onDidReceiveNotificationResponse: (response) async {
        await handleNotificationResponse(response);
        notifyChanged();
      },
      // App cerrada o en segundo plano: corre en un isolate aparte
      onDidReceiveBackgroundNotificationResponse:
          onBackgroundNotificationResponse,
    );
    _initialized = true;
  }

  /// Pide permiso para mostrar notificaciones (Android 13+ e iOS).
  Future<void> requestPermissions() async {
    if (!isSupported) return;
    await ensureInitialized();
    if (Platform.isAndroid) {
      await _android?.requestNotificationsPermission();
    } else {
      await _ios?.requestPermissions(alert: true, sound: true, badge: true);
    }
  }

  /// Abre la pantalla del sistema para permitir "Alarmas y recordatorios"
  /// (alarmas exactas, Android 12+).
  Future<void> requestExactAlarms() async {
    if (!isSupported || !Platform.isAndroid) return;
    await _android?.requestExactAlarmsPermission();
  }

  Future<void> openNotificationSettings() async {
    if (!isSupported) return;
    await _plugin.openAppNotificationSettings();
  }

  Future<NotificationPermissionStatus> permissionStatus() async {
    if (!isSupported) return NotificationPermissionStatus.allGranted;
    await ensureInitialized();
    if (Platform.isAndroid) {
      final enabled = await _android?.areNotificationsEnabled() ?? true;
      final exact = await _android?.canScheduleExactNotifications() ?? true;
      return NotificationPermissionStatus(
          notificationsEnabled: enabled, exactAlarmsAllowed: exact);
    }
    final opts = await _ios?.checkPermissions();
    return NotificationPermissionStatus(
      notificationsEnabled: opts?.isEnabled ?? true,
      exactAlarmsAllowed: true,
    );
  }

  /// Programa un recordatorio para un instante concreto.
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required ReminderPayload payload,
  }) async {
    if (!isSupported) return;
    await ensureInitialized();

    // Se programa como instante absoluto (UTC) calculado desde la hora local,
    // así no dependemos de conocer el nombre de la zona horaria del equipo.
    // Si el usuario cambia de zona horaria, la app reprograma al abrirse.
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
      notificationDetails: _details,
      androidScheduleMode: await _scheduleMode(),
      title: title,
      body: body,
      payload: payload.encode(),
    );
  }

  /// Pospone [payload] [kSnoozeMinutes] minutos a partir de [now].
  Future<void> scheduleSnooze(
    ReminderPayload payload, {
    required String title,
    required String body,
    DateTime? now,
  }) {
    final base = payload.asSnooze();
    return schedule(
      id: snoozeNotificationIdForLog(base.logId),
      at: (now ?? DateTime.now()).add(const Duration(minutes: kSnoozeMinutes)),
      title: title,
      body: body,
      payload: base,
    );
  }

  /// Cancela la notificación programada y la quita de la bandeja si se mostró.
  Future<void> cancel(int id) async {
    if (!isSupported) return;
    await ensureInitialized();
    await _plugin.cancel(id: id);
  }

  /// Cancela el recordatorio y el pospuesto de una toma.
  Future<void> cancelForLog(String logId) async {
    await cancel(notificationIdForLog(logId));
    await cancel(snoozeNotificationIdForLog(logId));
  }

  Future<List<PendingNotificationRequest>> pending() async {
    if (!isSupported) return const [];
    await ensureInitialized();
    return _plugin.pendingNotificationRequests();
  }

  Future<AndroidScheduleMode> _scheduleMode() async {
    if (Platform.isAndroid) {
      final exact = await _android?.canScheduleExactNotifications() ?? false;
      // Sin el permiso de alarmas exactas puede llegar con unos minutos de
      // retraso, pero es mejor que no llegar.
      return exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
    }
    return AndroidScheduleMode.exactAllowWhileIdle;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _androidChannelId,
      'Recordatorios de medicamentos',
      channelDescription: 'Avisos a la hora de cada toma',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      // Sonido distintivo (NOT-03). Ojo: en Android 8+ el sonido queda fijado
      // al canal la primera vez; para cambiarlo hay que usar otro ID de canal.
      sound: RawResourceAndroidNotificationSound('med_chime'),
      playSound: true,
      enableVibration: true,
      ticker: 'Recordatorio de medicamento',
      visibility: NotificationVisibility.public,
      actions: [
        AndroidNotificationAction(kActionTake, 'Tomado'),
        AndroidNotificationAction(kActionSnooze, 'Posponer $kSnoozeMinutes min'),
      ],
    ),
    iOS: DarwinNotificationDetails(
      categoryIdentifier: _darwinCategoryId,
      presentSound: true,
      presentAlert: true,
      presentBanner: true,
    ),
  );
}
