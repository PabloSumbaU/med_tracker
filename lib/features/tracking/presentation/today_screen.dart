// lib/features/tracking/presentation/today_screen.dart
//
// Pantalla de inicio (UI-01): muestra las tomas del día actual en orden
// cronológico con su hora programada, y permite marcarlas como Tomadas u
// Omitidas. Al tomar se guarda la hora real de confirmación (BR-03).

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/date_keys.dart';
import '../../medication/presentation/medication_controller.dart';
import '../../medication/presentation/medication_icons.dart';
import '../domain/tracking_log.dart';
import 'daily_controller.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  late final AppLifecycleListener _lifecycle;
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Al volver a la app, si ya es otro día, cargamos las tomas del nuevo día
    _lifecycle = AppLifecycleListener(onResume: _tick);
    // Cada minuto actualizamos qué tomas están atrasadas
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    setState(() => _now = DateTime.now());
    ref.read(dailyControllerProvider.notifier).refreshIfDayChanged();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasksState = ref.watch(dailyControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Column(
          children: [
            const Text('Hoy'),
            Text(
              formatLongDateEs(_now),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'today-add',
        icon: const Icon(Icons.add),
        label: const Text('Añadir'),
        onPressed: () => context.push('/add-medication'),
      ),
      body: tasksState.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _ErrorView(
          message: '$err',
          onRetry: () => ref.read(dailyControllerProvider.notifier).refresh(),
        ),
        data: (tasks) => RefreshIndicator(
          onRefresh: () => ref.read(dailyControllerProvider.notifier).refresh(),
          child: tasks.isEmpty
              ? const _EmptyView()
              : _TaskList(tasks: tasks, now: _now),
        ),
      ),
    );
  }
}

class _TaskList extends ConsumerWidget {
  const _TaskList({required this.tasks, required this.now});

  final List<DailyTaskItem> tasks;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = tasks.where((t) => t.log.status == LogStatus.realizada).length;

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: tasks.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _ProgressHeader(done: done, total: tasks.length);
        }
        final task = tasks[index - 1];
        return _DoseCard(
          key: ValueKey(task.log.logId),
          task: task,
          now: now,
        );
      },
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allDone = total > 0 && done == total;

    return Card(
      color: theme.colorScheme.primaryContainer,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              allDone
                  ? '¡Completaste todas tus tomas de hoy!'
                  : '$done de $total tomas realizadas',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : done / total,
                minHeight: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoseCard extends ConsumerWidget {
  const _DoseCard({super.key, required this.task, required this.now});

  final DailyTaskItem task;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final log = task.log;
    final controller = ref.read(dailyControllerProvider.notifier);
    final overdue = task.isOverdue(now);
    final isPending = log.status == LogStatus.pendiente;

    final timeColor = switch (log.status) {
      LogStatus.realizada => scheme.primary,
      LogStatus.omitida => scheme.outline,
      LogStatus.pendiente => overdue ? scheme.error : scheme.onSurface,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: log.status == LogStatus.omitida ? 0.7 : 1,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hora programada, grande y fácil de leer
                  SizedBox(
                    width: 72,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log.scheduledTime,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: timeColor,
                          ),
                        ),
                        if (overdue)
                          Text(
                            'Atrasada',
                            style: theme.textTheme.labelMedium
                                ?.copyWith(color: scheme.error),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(task.medicationType.icon,
                                size: 20, color: scheme.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                task.medicationName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  decoration: log.status == LogStatus.omitida
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (task.dose.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(task.dose, style: theme.textTheme.bodyLarge),
                        ],
                        if (task.description != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            task.description!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (isPending)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.close),
                        label: const Text('Omitir'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: () async {
                          await controller.markAsSkipped(log.logId);
                          if (context.mounted) {
                            _showUndo(context, controller, log.logId,
                                '${task.medicationName} omitido');
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text('Tomar'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: () async {
                          await controller.markAsTaken(log.logId);
                          if (context.mounted) {
                            _showUndo(
                              context,
                              controller,
                              log.logId,
                              '${task.medicationName} registrado a las '
                              '${toTimeKey(DateTime.now())}',
                            );
                          }
                        },
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Icon(
                      log.status == LogStatus.realizada
                          ? Icons.check_circle
                          : Icons.cancel,
                      size: 20,
                      color: log.status == LogStatus.realizada
                          ? scheme.primary
                          : scheme.outline,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        log.status == LogStatus.realizada
                            ? 'Tomada a las ${log.actualTakeTime ?? '--:--'}'
                            : 'Omitida',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () => controller.undo(log.logId),
                      child: const Text('Deshacer'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUndo(BuildContext context, DailyController controller,
      String logId, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () => controller.undo(logId),
          ),
        ),
      );
  }
}

class _EmptyView extends ConsumerWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasMeds =
        ref.watch(medicationControllerProvider).value?.isNotEmpty ?? false;
    final theme = Theme.of(context);

    // ListView para que funcione el "deslizar para actualizar"
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 48),
        Icon(Icons.event_available,
            size: 72, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          hasMeds
              ? 'No tienes tomas programadas para hoy.'
              : 'Aún no tienes medicamentos registrados.',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        if (!hasMeds) ...[
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Añadir medicamento'),
              onPressed: () => context.push('/add-medication'),
            ),
          ),
        ],
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error al cargar las tomas de hoy:\n$message',
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

const _weekdaysEs = [
  'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo',
];
const _monthsEs = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
  'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/// Ej. "lunes, 12 de octubre"
String formatLongDateEs(DateTime d) =>
    '${_weekdaysEs[d.weekday - 1]}, ${d.day} de ${_monthsEs[d.month - 1]}';
