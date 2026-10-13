import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_tracker/features/medication/domain/medication.dart';
import 'package:med_tracker/features/medication/presentation/medication_controller.dart';
import 'package:med_tracker/features/tracking/presentation/daily_controller.dart';
import 'package:med_tracker/main.dart';

class _NoMeds extends MedicationController {
  @override
  Future<List<Medication>> build() async => [];
}

class _NoTasks extends DailyController {
  @override
  Future<List<DailyTaskItem>> build() async => [];
  @override
  Future<void> refreshIfDayChanged() async {}
}

Widget _app() => ProviderScope(
      overrides: [
        medicationControllerProvider.overrideWith(_NoMeds.new),
        dailyControllerProvider.overrideWith(_NoTasks.new),
      ],
      child: const MyApp(),
    );

void main() {
  testWidgets('desde Hoy se abre el formulario de añadir', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();

    expect(find.text('Añadir Medicamento'), findsOneWidget);
    expect(find.text('Nombre del medicamento *'), findsOneWidget);
  });

  testWidgets('desde Medicamentos el botón + abre el formulario',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Medicamentos'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Añadir Medicamento'), findsOneWidget);
  });
}
