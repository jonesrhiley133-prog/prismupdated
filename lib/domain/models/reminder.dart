import 'package:freezed_annotation/freezed_annotation.dart';

part 'reminder.freezed.dart';
part 'reminder.g.dart';

enum ReminderTrigger {
  scheduled,
  onFrontChange;
}

enum ReminderFrequency {
  daily,
  weekly,
  interval;
}

@freezed
abstract class Reminder with _$Reminder {
  const Reminder._();

  /// Maximum number of times per day a scheduled reminder can fire.
  static const maxTimesPerDay = 12;

  /// Every valid "HH:mm" time this reminder fires at, deduplicated and sorted.
  /// Falls back to 09:00 when no valid time is stored.
  List<String> get allTimesOfDay {
    final times = <String>{};
    for (final raw in [timeOfDay, ...?additionalTimes]) {
      final normalized = normalizeReminderTime(raw);
      if (normalized != null) times.add(normalized);
    }
    if (times.isEmpty) return const ['09:00'];
    final sorted = times.toList()..sort();
    return sorted.take(maxTimesPerDay).toList();
  }

  const factory Reminder({
    required String id,
    required String name,
    required String message,
    @Default(ReminderTrigger.scheduled) ReminderTrigger trigger,
    @Default(ReminderFrequency.daily) ReminderFrequency frequency,
    List<int>? weeklyDays,
    int? intervalDays,
    String? timeOfDay,

    /// Extra "HH:mm" times for scheduled reminders that fire more than once a
    /// day. Use [Reminder.allTimesOfDay] for the full, sorted list.
    List<String>? additionalTimes,
    int? delayHours,
    /// Optional target member ID. null = fires on any front change;
    /// non-null = fires only when the referenced member is in the current
    /// fronter set. Custom fronts are represented as tagged members, so the
    /// same column covers both SP timer type=0 (member) and type=1 (custom
    /// front).
    String? targetMemberId,
    @Default(true) bool isActive,
    required DateTime createdAt,
    required DateTime modifiedAt,
  }) = _Reminder;

  factory Reminder.fromJson(Map<String, dynamic> json) =>
      _$ReminderFromJson(json);
}

/// Parses and re-formats an "HH:mm" string, or returns null when it is
/// malformed or out of range.
String? normalizeReminderTime(String? raw) {
  if (raw == null) return null;
  final parts = raw.trim().split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';
}
