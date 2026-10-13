import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_tracker/features/medication/domain/medication.dart';
import 'package:med_tracker/features/medication/presentation/medication_controller.dart';
import 'package:med_tracker/features/tracking/domain/tracking_log.dart';
import 'package:med_tracker/features/tracking/presentation/daily_controller.dart';
import 'package:med_tracker/features/tracking/presentation/today_screen.dart';

DailyTaskItem _item(String id, String time, String name,
    {LogStatus status = LogStatus.pendiente, String? takenAt}) {
  // Fecha lejana en el futuro para que ninguna toma aparezca como atrasada
  return DailyTaskItem(
    log: TrackingLog(
      logId: id,
      medicationId: id,
      scheduledDate: DateTime(2100, 1, 1),
      scheduledTime: time,
      status: status,
      actualTakeTime: takenAt,
    ),
    medicationName: name,
    medicationType: MedicationType.pastilla,
    dose: '1 pastilla',
  );
}

class _FakeDailyController extends DailyController {
  _FakeDailyController(this._items);

  List<DailyTaskItem> _items;
  final taken = <String>[];

  @override
  Future<List<DailyTaskItem>> build() async => _items;

  @override
  Future<void> refreshIfDayChanged() async {}

  @override
  Future<void> markAsTaken(String logId) async {
    taken.add(logId);
    _items = [
      for (final i in _items)
        i.log.logId == logId
            ? DailyTaskItem(
                log: i.log.copyWith(
                    status: LogStatus.realizada, actualTakeTime: '09:15'),
                medicationName: i.medicationName,
                medicationType: i.medicationType,
                dose: i.dose,
              )
            : i,
    ];
    state = AsyncData(_items);
  }
}

class _FakeMedicationController extends MedicationController {
  _FakeMedicationController(this._meds);
  final List<Medication> _meds;

  @override
  Future<List<Medication>> build() async => _meds;
}

Future<_FakeDailyController> _pump(
  WidgetTester tester,
  List<DailyTaskItem> items, {
  List<Medication> meds = const [],
}) async {
  final fake = _FakeDailyController(items);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dailyControllerProvider.overrideWith(() => fake),
        medicationControllerProvider
            .overrideWith(() => _FakeMedicationController(meds)),
      ],
      child: const MaterialApp(home: TodayScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('muestra las tomas del día con su hora en orden', (tester) async {
    await _pump(tester, [
      _item('a', '08:00', 'Ibuprofeno'),
      _item('b', '14:00', 'Jarabe'),
    ]);

    expect(find.text('0 de 2 tomas realizadas'), findsOneWidget);
    final first = tester.getTopLeft(find.text('08:00')).dy;
    final second = tester.getTopLeft(find.text('14:00')).dy;
    expect(first, lessThan(second));
    expect(find.text('Tomar'), findsNWidgets(2));
    expect(find.text('Omitir'), findsNWidgets(2));
  });

  testWidgets('tocar Tomar registra la toma y muestra la hora real',
      (tester) async {
    final fake = await _pump(tester, [_item('a', '08:00', 'Ibuprofeno')]);

    await tester.tap(find.text('Tomar'));
    await tester.pumpAndSettle();

    expect(fake.taken, ['a']);
    expect(find.text('Tomada a las 09:15'), findsOneWidget);
    expect(find.text('Tomar'), findsNothing);
    expect(find.text('¡Completaste todas tus tomas de hoy!'), findsOneWidget);
  });

  testWidgets('sin medicamentos invita a añadir uno', (tester) async {
    await _pump(tester, []);
    expect(find.text('Aún no tienes medicamentos registrados.'), findsOneWidget);
    expect(find.text('Añadir medicamento'), findsOneWidget);
    expect(find.text('Añadir'), findsOneWidget);
  });
}
