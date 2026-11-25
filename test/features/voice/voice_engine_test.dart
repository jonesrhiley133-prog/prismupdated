import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/fronting/providers/fronting_providers.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/voice/voice_engine.dart';
import 'package:prism_plurality/features/voice/voice_settings_screen.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';
import 'package:prism_plurality/shared/theme/app_theme.dart';

void main() {
  setUp(VoiceEngine.resetMemory);

  test('every style has lines for every everyday context', () {
    for (final c in VoiceContext.values.where((c) => !c.sensitive)) {
      for (final s in VoiceStyle.values) {
        expect(voiceLibrary[c]?[s], isNotEmpty, reason: '${c.name} / ${s.name}');
      }
    }
  });

  test('sensitive moments never use teasing or chaotic styles', () {
    for (final s in VoiceStyle.values.where((s) => !s.gentle)) {
      final e = VoiceEngine(VoiceSettings(base: VoiceTuning(style: s), sensitiveStyle: VoiceStyle.cozy), random: math.Random(1));
      final line = e.line(VoiceContext.insightHard);
      expect(voiceLibrary[VoiceContext.insightHard]![VoiceStyle.cozy]!.any((l) => line.startsWith(l.substring(0, 12))), isTrue, reason: '$s → $line');
    }
    // The library has no non-gentle lines for sensitive contexts at all.
    for (final c in VoiceContext.values.where((c) => c.sensitive)) {
      expect(voiceLibrary[c]!.keys.every((s) => s.gentle), isTrue);
    }
  });

  test('does not repeat a line back-to-back', () {
    final e = VoiceEngine(const VoiceSettings(), random: math.Random(3));
    String? last;
    for (var i = 0; i < 20; i++) {
      final l = e.line(VoiceContext.greeting, vars: const {'name': 'Ash'});
      expect(l, isNot(last));
      expect(l, isNot(contains('{')));
      last = l;
    }
  });

  test('custom lines, per-feature and per-headmate voices', () {
    final e = VoiceEngine(
      const VoiceSettings(features: {'games': VoiceStyle.gamer}, profiles: {'m1': VoiceTuning(style: VoiceStyle.poetic)}),
      custom: const [CustomLine(id: 'x', text: 'Yo {name}!', context: VoiceContext.farewell, memberId: 'm2')],
      random: math.Random(2),
    );
    expect(e.tuningFor(feature: 'games').style, VoiceStyle.gamer);
    expect(e.tuningFor(feature: 'games', memberId: 'm1').style, VoiceStyle.poetic);
    expect(e.tuningFor().style, VoiceStyle.natural);
    final seen = {for (var i = 0; i < 12; i++) e.line(VoiceContext.farewell, memberId: 'm2', vars: const {'name': 'Kit'})};
    expect(seen, contains('Yo Kit!'));
    final other = {for (var i = 0; i < 12; i++) e.line(VoiceContext.farewell, memberId: 'm3')};
    expect(other.any((l) => l.startsWith('Yo')), isFalse);
  });

  test('sliders shape lines', () {
    expect(VoiceEngine.shape('Hi there. How are you?', const VoiceTuning(length: 0.1)), 'Hi there.');
    expect(VoiceEngine.shape("You're great.", const VoiceTuning(formality: 0.9)), 'You are great.');
    expect(VoiceEngine.shape('Yay! 🎉', const VoiceTuning(emoji: 0)), 'Yay!');
    expect(VoiceEngine.shape('Nice.', const VoiceTuning(energy: 0.9, emoji: 0.3)), 'Nice!');
    expect(VoiceEngine.shape('Rest now.', const VoiceTuning(energy: 0.9), sensitive: true), 'Rest now.');
  });

  test('settings round-trip and reject non-gentle sensitive voices', () {
    const s = VoiceSettings(base: VoiceTuning(style: VoiceStyle.chaotic, emoji: 0.9), features: {'astro': VoiceStyle.poetic}, profiles: {'m': VoiceTuning(style: VoiceStyle.grumpy)}, sensitiveStyle: VoiceStyle.serious, customTracks: false);
    final b = VoiceSettings.fromJson(s.toJson());
    expect([b.base.style, b.base.emoji, b.features['astro'], b.profiles['m']!.style, b.sensitiveStyle, b.customTracks], [VoiceStyle.chaotic, 0.9, VoiceStyle.poetic, VoiceStyle.grumpy, VoiceStyle.serious, false]);
    expect(VoiceSettings.fromJson({'sensitive': 'sarcastic'}).sensitiveStyle, VoiceStyle.natural);
  });

  testWidgets('settings screen renders previews for all styles', (t) async {
    await t.pumpWidget(ProviderScope(
      overrides: [
        trackerRecordsProvider.overrideWith((ref) => Stream.value(const <TrackerRecord>[])),
        userVisibleMembersProvider.overrideWithValue(const AsyncData(<Member>[])),
        activeSessionsProvider.overrideWith((ref) => Stream.value(const <FrontingSession>[])),
        currentFronterProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: MaterialApp(theme: AppTheme.light(), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, home: const VoiceSettingsScreen()),
    ));
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(t.takeException(), isNull);
    expect(find.text('Personality & voice'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Sarcastic'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Sarcastic'), findsWidgets);
    await t.pumpWidget(const SizedBox());
  });
}
