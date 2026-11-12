import 'package:prism_plurality/domain/models/cycle_entry.dart';

/// Derived cycle information. Predictions are simple averages of past
/// cycles, shown as estimates, never as medical information.
class CycleStats {
  const CycleStats({
    required this.periodStarts,
    required this.cycleLengths,
    required this.averageCycleLength,
    required this.averagePeriodLength,
    required this.currentCycleDay,
    required this.nextPeriodEstimate,
  });

  /// First day of each period, oldest first.
  final List<DateTime> periodStarts;

  /// Days between consecutive period starts (plausible 15–60 only).
  final List<int> cycleLengths;
  final double? averageCycleLength;
  final double? averagePeriodLength;

  /// Day of the current cycle (1 = first period day), if known.
  final int? currentCycleDay;

  /// Estimated next start (needs at least two completed cycles).
  final DateTime? nextPeriodEstimate;

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static int _days(DateTime a, DateTime b) => DateTime.utc(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

  static CycleStats of(
    Iterable<CycleEntry> entries, {
    required DateTime today,
  }) {
    final periodDays =
        entries.where((e) => e.isPeriodDay).map((e) => e.day).toSet().toList()
          ..sort();
    final starts = <DateTime>[];
    final runs = <int>[];
    for (var i = 0; i < periodDays.length; i++) {
      final d = periodDays[i];
      // A new period starts after a gap of more than 2 days.
      if (i == 0 || _days(periodDays[i - 1], d) > 2) {
        starts.add(d);
        runs.add(1);
      } else {
        runs[runs.length - 1] = _days(starts.last, d) + 1;
      }
    }
    final lengths = <int>[
      for (var i = 1; i < starts.length; i++)
        if (_days(starts[i - 1], starts[i]) >= 15 &&
            _days(starts[i - 1], starts[i]) <= 60)
          _days(starts[i - 1], starts[i]),
    ];
    final recent = lengths.length > 6
        ? lengths.sublist(lengths.length - 6)
        : lengths;
    final avgCycle = recent.isEmpty
        ? null
        : recent.reduce((a, b) => a + b) / recent.length;
    final avgPeriod = runs.isEmpty
        ? null
        : runs.reduce((a, b) => a + b) / runs.length;
    final t = DateTime(today.year, today.month, today.day);
    final lastStart = starts.where((s) => !s.isAfter(t)).lastOrNull;
    final day = lastStart == null ? null : _days(lastStart, t) + 1;
    DateTime? next;
    if (lastStart != null && avgCycle != null && lengths.length >= 2) {
      next = DateTime(
        lastStart.year,
        lastStart.month,
        lastStart.day + avgCycle.round(),
      );
    }
    return CycleStats(
      periodStarts: starts,
      cycleLengths: lengths,
      averageCycleLength: avgCycle,
      averagePeriodLength: avgPeriod,
      currentCycleDay: (day != null && day <= 90) ? day : null,
      nextPeriodEstimate: next,
    );
  }
}

/// Symptom keys offered in the cycle logger.
const cycleSymptoms = <String, String>{
  'cramps': 'Cramps',
  'bloating': 'Bloating',
  'headache': 'Headache',
  'back_pain': 'Back pain',
  'breast_tenderness': 'Breast tenderness',
  'fatigue': 'Fatigue',
  'acne': 'Acne',
  'cravings': 'Cravings',
  'nausea': 'Nausea',
  'mood_swings': 'Mood swings',
  'irritability': 'Irritability',
  'low_mood': 'Low mood',
  'anxiety': 'Anxiety',
  'insomnia': 'Trouble sleeping',
  'dysphoria': 'Dysphoria',
  'discharge': 'Discharge',
  'ovulation_pain': 'Ovulation pain',
  'libido_high': 'Higher libido',
  'libido_low': 'Lower libido',
};
