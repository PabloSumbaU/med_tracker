// lib/features/reminders/presentation/permission_banner.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_service.dart';
import '../data/reminder_scheduler.dart';

/// Estado de los permisos de notificación. Se invalida al volver a la app.
final notificationPermissionProvider =
    FutureProvider<NotificationPermissionStatus>((ref) {
  return NotificationService.instance.permissionStatus();
});

/// Aviso visible en Hoy cuando faltan permisos para que los recordatorios
/// lleguen a tiempo con la app cerrada (CA-01).
class NotificationPermissionBanner extends ConsumerWidget {
  const NotificationPermissionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(notificationPermissionProvider).value;
    if (status == null || status.isOk) return const SizedBox.shrink();

    final service = NotificationService.instance;
    final scheme = Theme.of(context).colorScheme;

    final (message, buttonLabel, onPressed) = !status.notificationsEnabled
        ? (
            'Las notificaciones están desactivadas. Actívalas para recibir '
                'los recordatorios de tus tomas.',
            'Activar',
            () async {
              await service.requestPermissions();
              final after = await service.permissionStatus();
              // Si el usuario ya lo había rechazado, Android no vuelve a
              // preguntar: lo llevamos a los ajustes.
              if (!after.notificationsEnabled) {
                await service.openNotificationSettings();
              }
            },
          )
        : (
            'Permite "Alarmas y recordatorios" para que los avisos lleguen '
                'a la hora exacta.',
            'Permitir',
            () => service.requestExactAlarms(),
          );

    return Card(
      color: scheme.errorContainer,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.notifications_off_outlined,
                    color: scheme.onErrorContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async {
                  await onPressed();
                  ref.invalidate(notificationPermissionProvider);
                  await ref.read(reminderSchedulerProvider).reschedule();
                },
                child: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
