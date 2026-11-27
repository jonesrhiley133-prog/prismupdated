import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/companions/companion_art.dart';
import 'package:prism_plurality/features/companions/companion_data.dart';
import 'package:prism_plurality/features/companions/companion_mood.dart';
import 'package:prism_plurality/features/companions/companion_species.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';

Companion _c([Map<String, Object?> f = const {}]) => Companion(
  TrackerRecord(
    id: 'c1',
    kind: TrackerKind.companion,
    title: 'Pip',
    createdAt: DateTime(2026),
    modifiedAt: DateTime(2026),
  ).withFields(f),
);

Map<String, int> _tally({
  required CompanionPersonality p,
  required CompanionEnvironment env,
  String? last,
}) {
  final out = <String, int>{};
  for (var seed = 0; seed < 600; seed++) {
    final e = chooseEmotion(p: p, env: env, lastInteraction: last, seed: seed);
    out[e] = (out[e] ?? 0) + 1;
  }
  return out;
}

String _top(Map<String, int> t) =>
    (t.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;

void main() {
  test('16 distinct emotions, every one a face the editor offers', () {
    expect(companionEmotions.length, 16);
    expect(companionEmotions.map((e) => e.id).toSet().length, 16);
    for (final e in companionEmotions) {
      expect(CompanionLook.expressions, contains(e.id), reason: e.id);
      expect(e.label, isNotEmpty);
    }
    expect(emotionById('nonsense').id, 'content');
  });

  test('moods follow what just happened, the weather and the time', () {
    const p = CompanionPersonality();
    expect(
      _top(_tally(p: p, env: const CompanionEnvironment(), last: 'pet')),
      'loving',
    );
    expect(
      _top(_tally(p: p, env: const CompanionEnvironment(), last: 'play')),
      anyOf('excited', 'silly'),
    );
    expect(
      _top(
        _tally(
          p: p,
          env: const CompanionEnvironment(timeOfDay: 'night'),
        ),
      ),
      'sleepy',
    );
    final timid = _tally(
      p: const CompanionPersonality(bravery: 0.05),
      env: const CompanionEnvironment(weather: 'snow'),
    );
    final brave = _tally(
      p: const CompanionPersonality(bravery: 0.95),
      env: const CompanionEnvironment(weather: 'snow'),
    );
    expect(timid['scared'] ?? 0, greaterThan(brave['scared'] ?? 0));
    // Same seed, same mood: it doesn't flicker between rebuilds.
    expect(
      chooseEmotion(p: p, env: const CompanionEnvironment(), seed: 42),
      chooseEmotion(p: p, env: const CompanionEnvironment(), seed: 42),
    );
  });

  test('time of day follows the clock when set to auto', () {
    expect(
      CompanionEnvironment.resolveTime('auto', DateTime(2026, 1, 1, 23)),
      'night',
    );
    expect(
      CompanionEnvironment.resolveTime('auto', DateTime(2026, 1, 1, 8)),
      'morning',
    );
    expect(
      CompanionEnvironment.resolveTime('evening', DateTime(2026, 1, 1, 8)),
      'evening',
    );
    expect(const CompanionEnvironment(weather: 'rain').note, contains('rain'));
  });

  test('personality comes from traits until set, and round-trips', () {
    expect(
      CompanionPersonality.of(
        _c({
          'traits': ['energetic'],
        }),
      ).energy,
      greaterThan(0.7),
    );
    expect(
      CompanionPersonality.of(
        _c({
          'traits': ['sleepy'],
        }),
      ).energy,
      lessThan(0.3),
    );
    final p = CompanionPersonality.of(
      _c({
        'persona': {'energy': 0.1, 'curiosity': 2, 'bravery': 'x'},
      }),
    );
    expect(p.energy, 0.1);
    expect(p.curiosity, 1.0);
    expect(p.bravery, 0.55);
    final again = CompanionPersonality.of(
      _c({'persona': p.copyWithKey('mischief', 0.9).toJson()}),
    );
    expect(again.mischief, 0.9);
  });

  test('motion settings default to full and read back', () {
    expect(CompanionMotionSettings.of(const CompanionSettings()).intensity, 1);
    final rec =
        TrackerRecord(
          id: 's',
          kind: TrackerKind.companionSettings,
          title: '',
          createdAt: DateTime(2026),
          modifiedAt: DateTime(2026),
        ).withFields({
          'anim': const CompanionMotionSettings(
            intensity: 0.3,
            environment: false,
          ).toJson(),
        });
    final m = CompanionMotionSettings.of(CompanionSettings.of(rec));
    expect(m.intensity, 0.3);
    expect(m.environment, isFalse);
  });

  testWidgets('every emotion, pose and weather draws, still or moving', (
    t,
  ) async {
    final species = speciesById('fox');
    const look = CompanionLook(hat: 'beanie', neck: 'scarf');
    for (final e in companionEmotions) {
      for (final pose in CompanionPose.values) {
        for (final weather in [null, 'rain', 'snow']) {
          await t.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: Center(
                child: CompanionView(
                  species: species,
                  look: look,
                  pose: pose,
                  expression: e.id,
                  weather: weather,
                  intensity: pose.index.isEven ? 1 : 0.4,
                  size: 90,
                ),
              ),
            ),
          );
          await t.pump(const Duration(milliseconds: 120));
          expect(
            t.takeException(),
            isNull,
            reason: '${e.id} ${pose.name} $weather',
          );
        }
      }
    }
  });

  testWidgets('reduced motion and zero strength keep them still', (t) async {
    for (final (reduced, intensity) in [(true, 1.0), (false, 0.0)]) {
      await t.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: CompanionView(
              species: speciesById('cat'),
              look: const CompanionLook(),
              expression: 'excited',
              intensity: intensity,
            ),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 50));
      expect(
        t.binding.hasScheduledFrame,
        isFalse,
        reason: 'reduced=$reduced intensity=$intensity',
      );
    }
  });
}
