import 'dart:math' as math;

/// One variable as a value per day (missing days are absent).
class DailySeries {
  DailySeries({
    required this.id,
    required this.group,
    required this.en,
    required this.es,
    required this.values,
    this.unit = '',
    this.zeroFill = false,
  });
  final String id;

  /// Category for grouping in the picker (fronting, sleep, …).
  final String group;
  final String en;
  final String es;
  final Map<DateTime, double> values;
  final String unit;

  /// Counts and minutes: a missing day means zero, not unknown.
  final bool zeroFill;

  double? at(DateTime day) => values[day] ?? (zeroFill ? 0 : null);
}

enum Confidence { insufficient, low, moderate, high }

class Correlation {
  const Correlation(this.series, this.r, this.n, this.p);
  final DailySeries series;
  final double r;
  final int n;
  final double p;

  Confidence get confidence {
    if (n < 7) return Confidence.insufficient;
    if (p < 0.01 && n >= 30) return Confidence.high;
    if (p < 0.05 && n >= 14) return Confidence.moderate;
    return Confidence.low;
  }

  /// none / weak / moderate / strong by |r|.
  String get strength {
    final a = r.abs();
    if (a < 0.1) return 'none';
    if (a < 0.3) return 'weak';
    if (a < 0.5) return 'moderate';
    return 'strong';
  }
}

/// Pearson correlation of mood with [s] over [days]. With [lag] = 1 the
/// variable on day d is compared with mood on day d+1.
Correlation? correlate(
  DailySeries mood,
  DailySeries s,
  List<DateTime> days, {
  int lag = 0,
}) {
  final xs = <double>[], ys = <double>[];
  for (final d in days) {
    final m = mood.at(lag == 0 ? d : DateTime(d.year, d.month, d.day + lag));
    final v = s.at(d);
    if (m == null || v == null) continue;
    xs.add(v);
    ys.add(m);
  }
  final n = xs.length;
  if (n < 3) return n == 0 ? null : Correlation(s, 0, n, 1);
  final mx = xs.reduce((a, b) => a + b) / n,
      my = ys.reduce((a, b) => a + b) / n;
  var sxy = 0.0, sxx = 0.0, syy = 0.0;
  for (var i = 0; i < n; i++) {
    sxy += (xs[i] - mx) * (ys[i] - my);
    sxx += (xs[i] - mx) * (xs[i] - mx);
    syy += (ys[i] - my) * (ys[i] - my);
  }
  if (sxx == 0 || syy == 0) return Correlation(s, 0, n, 1);
  final r = (sxy / math.sqrt(sxx * syy)).clamp(-1.0, 1.0);
  return Correlation(s, r, n, pValue(r, n));
}

/// Two-sided p-value via the Fisher z transform.
double pValue(double r, int n) {
  if (n <= 3) return 1;
  final rr = r.clamp(-0.999999, 0.999999);
  final z = 0.5 * math.log((1 + rr) / (1 - rr)) * math.sqrt(n - 3);
  return (2 * (1 - _phi(z.abs()))).clamp(0.0, 1.0);
}

double _phi(double x) => 0.5 * (1 + _erf(x / math.sqrt2));

double _erf(double x) {
  // Abramowitz & Stegun 7.1.26.
  final t = 1 / (1 + 0.3275911 * x.abs());
  final y =
      1 -
      (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t -
                      0.284496736) *
                  t +
              0.254829592) *
          t *
          math.exp(-x * x);
  return x >= 0 ? y : -y;
}

/// Mean and count of mood by weekday (1 = Monday).
Map<int, (double, int)> weekdayPattern(DailySeries mood) {
  final sums = <int, (double, int)>{};
  mood.values.forEach((d, v) {
    final c = sums[d.weekday];
    sums[d.weekday] = ((c?.$1 ?? 0) + v, (c?.$2 ?? 0) + 1);
  });
  return {
    for (final e in sums.entries) e.key: (e.value.$1 / e.value.$2, e.value.$2),
  };
}

/// Average mood on days with the variable above vs at/below its median.
(double, double, int, int)? splitByMedian(
  DailySeries mood,
  DailySeries s,
  List<DateTime> days,
) {
  final pairs = <(double, double)>[];
  for (final d in days) {
    final m = mood.at(d), v = s.at(d);
    if (m != null && v != null) pairs.add((v, m));
  }
  if (pairs.length < 6) return null;
  final sorted = [for (final p in pairs) p.$1]..sort();
  final median = sorted[sorted.length ~/ 2];
  final hi = [
    for (final p in pairs)
      if (p.$1 > median) p.$2,
  ];
  final lo = [
    for (final p in pairs)
      if (p.$1 <= median) p.$2,
  ];
  if (hi.isEmpty || lo.isEmpty) return null;
  double avg(List<double> l) => l.reduce((a, b) => a + b) / l.length;
  return (avg(hi), avg(lo), hi.length, lo.length);
}
