import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/features/games/engines/ambience_synth.dart';
import 'package:prism_plurality/features/games/engines/tone_player.dart';

void main() {
  for (final a in ambienceCatalog) {
    test('${a.id} renders a clean, seamless loop', () {
      final sw = Stopwatch()..start();
      final s = AmbienceSynth.render(a.id);
      final ms = sw.elapsedMilliseconds;
      expect(s.length, greaterThan(AmbienceSynth.sampleRate * 8));
      var sum = 0.0, peak = 0.0, finite = true;
      for (final v in s) {
        if (!v.isFinite) finite = false;
        sum += v * v;
        peak = math.max(peak, v.abs());
      }
      expect(finite, isTrue);
      final rms = math.sqrt(sum / s.length);
      expect(rms, inInclusiveRange(0.05, 0.2));
      expect(peak, lessThanOrEqualTo(0.96));
      // The jump across the loop point is no bigger than a typical step.
      var steps = 0.0;
      for (var i = 1; i < s.length; i++) {
        steps += (s[i] - s[i - 1]).abs();
      }
      final seam = (s.first - s.last).abs();
      expect(seam, lessThan(steps / s.length * 12 + 0.02));
      final out = Platform.environment['AMBIENCE_OUT'];
      if (out != null)
        File('$out/${a.id}.wav').writeAsBytesSync(TonePlayer.ambienceWav(a.id));
      // ignore: avoid_print
      print(
        '${a.id}: ${ms}ms rms=${rms.toStringAsFixed(3)} peak=${peak.toStringAsFixed(2)}',
      );
    });
  }
}
