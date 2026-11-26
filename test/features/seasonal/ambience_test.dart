import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/features/games/engines/ambience_synth.dart';

void main() {
  for (final kind in ['forest', 'cafe', 'room', 'winter']) {
    test('$kind renders a clean, seamless, audible loop', () {
      final s = AmbienceSynth.render(kind);
      expect(s.length, greaterThan(AmbienceSynth.sampleRate * 10));
      var peak = 0.0, sum = 0.0;
      for (final v in s) {
        expect(v.isFinite, isTrue);
        peak = math.max(peak, v.abs());
        sum += v * v;
      }
      final rms = math.sqrt(sum / s.length);
      expect(peak, lessThanOrEqualTo(1.0));
      expect(rms, greaterThan(0.02), reason: '$kind is nearly silent');
      // The jump from the last sample back to the first must be no bigger
      // than ordinary sample-to-sample movement: no click at the loop point.
      var maxStep = 0.0;
      for (var i = 1; i < s.length; i++) {
        maxStep = math.max(maxStep, (s[i] - s[i - 1]).abs());
      }
      expect(
        (s.first - s.last).abs(),
        lessThanOrEqualTo(maxStep * 1.5 + 0.02),
        reason: '$kind clicks at the loop point',
      );
    });
  }

  test('the new ambiences are in the catalogue, in both languages', () {
    for (final id in ['forest', 'cafe', 'room', 'winter']) {
      final a = ambienceCatalog.where((e) => e.id == id).single;
      expect(a.label, isNotEmpty);
      expect(a.labelEs, isNotEmpty);
    }
  });
}
