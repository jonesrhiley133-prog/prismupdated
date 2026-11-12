import 'package:flutter/material.dart' show TimeOfDay;

import 'package:prism_plurality/domain/models/reminder.dart';

/// "HH:mm" storage form of a [TimeOfDay].
String formatReminderTime(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Parses "HH:mm", or returns null when malformed or out of range.
TimeOfDay? parseReminderTime(String? raw) {
  final normalized = normalizeReminderTime(raw);
  if (normalized == null) return null;
  final parts = normalized.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

int _minutesOf(TimeOfDay t) => t.hour * 60 + t.minute;

/// Sorts and de-duplicates [times].
List<TimeOfDay> sortedUniqueTimes(Iterable<TimeOfDay> times) {
  final byMinute = <int, TimeOfDay>{for (final t in times) _minutesOf(t): t};
  final keys = byMinute.keys.toList()..sort();
  return [for (final k in keys) byMinute[k]!];
}

/// Times from [start] to [end] (inclusive, same day) every [everyMinutes],
/// capped at [Reminder.maxTimesPerDay]. When [end] is earlier than [start]
/// only [start] is returned.
List<TimeOfDay> evenlySpacedTimes({
  required TimeOfDay start,
  required TimeOfDay end,
  required int everyMinutes,
}) {
  final step = everyMinutes < 15 ? 15 : everyMinutes;
  final first = _minutesOf(start);
  final last = _minutesOf(end);
  final out = <TimeOfDay>[];
  for (var m = first; m <= last; m += step) {
    out.add(TimeOfDay(hour: m ~/ 60, minute: m % 60));
    if (out.length >= Reminder.maxTimesPerDay) break;
  }
  if (out.isEmpty) out.add(start);
  return out;
}
