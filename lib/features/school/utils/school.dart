import 'package:flutter/foundation.dart';

import 'package:prism_plurality/domain/models/tracker_record.dart';

/// Field keys inside school records' `data`.
abstract final class SchoolField {
  static const teacher = 'teacher';
  static const room = 'room';
  static const color = 'color';
  static const credits = 'credits';
  static const schedule = 'schedule';
  static const targetPercent = 'targetPercent';
  static const type = 'type';
  static const status = 'status';
  static const priority = 'priority';
  static const weight = 'weight';
  static const earned = 'earned';
  static const possible = 'possible';
  static const minutes = 'minutes';
  static const focus = 'focus';
}

abstract final class AssignmentStatus {
  static const todo = 'todo';
  static const doing = 'doing';
  static const done = 'done';
  static const all = [todo, doing, done];
}

const assignmentTypes = [
  'homework',
  'reading',
  'essay',
  'project',
  'lab',
  'quiz',
  'exam',
  'presentation',
  'other',
];

/// One weekly meeting of a class.
@immutable
class ClassMeeting {
  const ClassMeeting({
    required this.weekday,
    required this.startMinute,
    required this.endMinute,
  });

  /// DateTime.monday … DateTime.sunday.
  final int weekday;

  /// Minutes after midnight.
  final int startMinute;
  final int endMinute;

  bool get isValid =>
      weekday >= 1 &&
      weekday <= 7 &&
      startMinute >= 0 &&
      endMinute > startMinute &&
      endMinute <= 24 * 60;

  Map<String, Object?> toJson() => {
    'weekday': weekday,
    'start': startMinute,
    'end': endMinute,
  };

  static ClassMeeting? fromJson(Object? v) {
    if (v is! Map) return null;
    final w = v['weekday'], s = v['start'], e = v['end'];
    if (w is! int || s is! int || e is! int) return null;
    final m = ClassMeeting(weekday: w, startMinute: s, endMinute: e);
    return m.isValid ? m : null;
  }
}

List<ClassMeeting> classSchedule(TrackerRecord c) {
  final raw = c.fields[SchoolField.schedule];
  if (raw is! List) return const [];
  return [for (final v in raw) ?ClassMeeting.fromJson(v)]..sort(
    (a, b) => a.weekday != b.weekday
        ? a.weekday.compareTo(b.weekday)
        : a.startMinute.compareTo(b.startMinute),
  );
}

/// Classes meeting on [day], in time order, with their meeting.
List<(TrackerRecord, ClassMeeting)> scheduleFor(
  Iterable<TrackerRecord> classes,
  DateTime day,
) => [
  for (final c in classes)
    for (final m in classSchedule(c))
      if (m.weekday == day.weekday) (c, m),
]..sort((a, b) => a.$2.startMinute.compareTo(b.$2.startMinute));

String assignmentStatus(TrackerRecord a) =>
    a.str(SchoolField.status) ?? AssignmentStatus.todo;

bool isDone(TrackerRecord a) => assignmentStatus(a) == AssignmentStatus.done;

bool isOverdue(TrackerRecord a, DateTime now) =>
    !isDone(a) && a.occurredAt != null && a.occurredAt!.isBefore(now);

/// Graded fraction (0–1) of an assignment, or null if ungraded.
double? assignmentScore(TrackerRecord a) {
  final e = a.number(SchoolField.earned);
  final p = a.number(SchoolField.possible);
  if (e == null || p == null || p <= 0) return null;
  return e / p;
}

/// Class grade as a percentage (0–100) from graded assignments, or null.
///
/// When any graded assignment has a weight, scores are averaged by weight
/// (unweighted ones count as weight 0 then, as in most syllabi, unless all
/// are unweighted); otherwise points are summed.
double? classPercent(Iterable<TrackerRecord> assignments) {
  final graded = [
    for (final a in assignments)
      if (assignmentScore(a) != null) a,
  ];
  if (graded.isEmpty) return null;
  final weighted = graded.where((a) => (a.number(SchoolField.weight) ?? 0) > 0);
  if (weighted.isNotEmpty) {
    var sum = 0.0, w = 0.0;
    for (final a in weighted) {
      final wt = a.number(SchoolField.weight)!;
      sum += assignmentScore(a)! * wt;
      w += wt;
    }
    return sum / w * 100;
  }
  var earned = 0.0, possible = 0.0;
  for (final a in graded) {
    earned += a.number(SchoolField.earned)!;
    possible += a.number(SchoolField.possible)!;
  }
  return earned / possible * 100;
}

/// US-style letter for a percentage.
String letterGrade(double percent) {
  if (percent >= 93) return 'A';
  if (percent >= 90) return 'A−';
  if (percent >= 87) return 'B+';
  if (percent >= 83) return 'B';
  if (percent >= 80) return 'B−';
  if (percent >= 77) return 'C+';
  if (percent >= 73) return 'C';
  if (percent >= 70) return 'C−';
  if (percent >= 67) return 'D+';
  if (percent >= 60) return 'D';
  return 'F';
}

/// 4.0-scale points for a percentage.
double gradePoints(double percent) => switch (letterGrade(percent)) {
  'A' => 4.0,
  'A−' => 3.7,
  'B+' => 3.3,
  'B' => 3.0,
  'B−' => 2.7,
  'C+' => 2.3,
  'C' => 2.0,
  'C−' => 1.7,
  'D+' => 1.3,
  'D' => 1.0,
  _ => 0.0,
};

/// Credit-weighted GPA over classes with a grade.
double? gpa(
  Iterable<TrackerRecord> classes,
  Map<String, List<TrackerRecord>> assignmentsByClass,
) {
  var points = 0.0, credits = 0.0;
  for (final c in classes) {
    final p = classPercent(assignmentsByClass[c.id] ?? const []);
    if (p == null) continue;
    final cr = c.number(SchoolField.credits) ?? 1;
    points += gradePoints(p) * cr;
    credits += cr;
  }
  return credits == 0 ? null : points / credits;
}

/// Score needed on the remaining weight to reach [target] percent, as a
/// percentage, or null when not computable (no weights).
double? neededOnRemaining(Iterable<TrackerRecord> assignments, double target) {
  var gradedWeight = 0.0, gradedSum = 0.0, remaining = 0.0;
  for (final a in assignments) {
    final w = a.number(SchoolField.weight) ?? 0;
    if (w <= 0) continue;
    final s = assignmentScore(a);
    if (s == null) {
      remaining += w;
    } else {
      gradedWeight += w;
      gradedSum += s * w;
    }
  }
  if (remaining <= 0) return null;
  final total = gradedWeight + remaining;
  return ((target / 100) * total - gradedSum) / remaining * 100;
}

Map<String, List<TrackerRecord>> groupByParent(Iterable<TrackerRecord> rs) {
  final out = <String, List<TrackerRecord>>{};
  for (final r in rs) {
    if (r.parentId != null) (out[r.parentId!] ??= []).add(r);
  }
  return out;
}

String formatMinuteOfDay(int m) =>
    '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
