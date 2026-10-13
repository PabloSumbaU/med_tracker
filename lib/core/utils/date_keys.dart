// lib/core/utils/date_keys.dart
//
// Helpers para guardar fechas y horas en SQLite como texto con un formato
// fijo. Siempre se usan los campos LOCALES del DateTime, para que el
// "día natural" (00:00 - 23:59) coincida con el del usuario (BR-01).

String _two(int n) => n.toString().padLeft(2, '0');

/// Fecha en formato `YYYY-MM-DD`.
String toDateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

/// Hora en formato `HH:mm` (24 h).
String toTimeKey(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// Combina una fecha con una hora `HH:mm` en un DateTime local.
DateTime combineDateAndTime(DateTime date, String hhmm) {
  final parts = hhmm.split(':');
  return DateTime(
    date.year,
    date.month,
    date.day,
    int.parse(parts[0]),
    int.parse(parts[1]),
  );
}
