import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/models/mood_entry.dart';
import 'package:prism_plurality/features/fronting_notification/models/fronting_notification_settings.dart';
import 'package:prism_plurality/features/fronting_notification/services/fronting_notification_controller.dart';
import 'package:prism_plurality/features/fronting_notification/services/fronting_notification_settings_store.dart';
import 'package:prism_plurality/features/fronting_notification/services/fronting_notification_snapshot.dart';
import 'package:prism_plurality/features/fronting_notification/services/fronting_status_platform.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';

final _now = DateTime(2026, 11, 12, 15);
final _strings = frontingNotificationStrings(
  lookupAppLocalizations(const Locale('en')),
  'en',
);

Member _m(String id, String name, {String? pronouns, String emoji = '❔'}) =>
    Member(
      id: id,
      name: name,
      pronouns: pronouns,
      emoji: emoji,
      createdAt: _now,
    );

FrontingSession _s(String member, int minutesAgo) => FrontingSession(
  id: 's$member',
  memberId: member,
  startTime: _now.subtract(Duration(minutes: minutesAgo)),
);

FnInputs _inputs({
  List<FrontingSession> sessions = const [],
  MoodEntry? mood,
  FrontingSession? sleep,
  String? place,
  String? job,
}) => FnInputs(
  sessions: sessions,
  members: {
    for (final m in [
      _m('a', 'Ash', pronouns: 'she/her', emoji: '🌸'),
      _m('k', 'Kai'),
      _m('r', 'River'),
    ])
      m.id: m,
  },
  latestMood: mood,
  sleep: sleep,
  locationName: place,
  workJob: job,
);

class _FakePlatform extends FrontingStatusPlatform {
  final shows = <Map<String, Object?>>[];
  int cancels = 0;

  @override
  bool get isSupported => true;

  @override
  Future<void> ensureChannels({
    required String name,
    required String dndName,
    required String description,
  }) async {}

  @override
  Future<bool> show(Map<String, Object?> snapshot) async {
    shows.add(snapshot);
    return true;
  }

  @override
  Future<void> cancel() async => cancels++;
}

class _FixedSettings extends FrontingNotificationSettingsNotifier {
  _FixedSettings(this.initial);

  final FrontingNotificationSettings initial;

  @override
  Future<FrontingNotificationSettings> build() async => initial;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('settings survive a JSON round trip and ignore junk', () {
    final s = const FrontingNotificationSettings().copyWith(
      enabled: true,
      titleTemplate: 'Hi {first}',
      layout: FnLayout.detailed,
      style: FnStyle.custom,
      accentColor: 0xFF123456,
      info: [FnInfo.mood, FnInfo.fronters],
      actions: [FnAction.mood, FnAction.details],
      lockScreen: FnLockScreen.hide,
      memberStyles: {
        'a': const FnMemberStyle(
          greeting: 'Hello Ash',
          accentColor: 0xFFFF0000,
        ),
      },
    );
    final back = FrontingNotificationSettings.fromJson(
      jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>,
    );
    expect(back, s);
    final junk = FrontingNotificationSettings.fromJson({
      'layout': 'bogus',
      'info': ['mood', 'nope', 'mood'],
      'actions': ['a', 'mood', 'switch', 'open', 'details'],
      'smallIcon': 'x',
    });
    expect(junk.layout, FnLayout.expanded);
    expect(junk.info, ['mood']);
    expect(junk.actions, ['mood', 'switch', 'open']);
    expect(junk.smallIcon, 'person');
    expect(junk.enabled, isFalse);
  });

  test(
    'snapshot lists fronters (newest first), co-fronters, pronouns and live timer',
    () {
      final settings = const FrontingNotificationSettings().copyWith(
        info: [
          FnInfo.fronters,
          FnInfo.cofronters,
          FnInfo.pronouns,
          FnInfo.duration,
          FnInfo.location,
          FnInfo.activity,
        ],
        titleTemplate: '{count} fronting: {fronters}',
      );
      final snap = buildFrontingSnapshot(
        settings,
        _inputs(
          sessions: [_s('k', 90), _s('a', 10)],
          place: 'Home',
          job: 'Café',
        ),
        _strings,
        _now,
      );
      expect(snap.title, '2 fronting: Ash, Kai');
      expect(snap.lines, [
        'Fronting: Ash (she/her)',
        'Co-fronting: Kai',
        'Since ${_strings.formatTime(_now.subtract(const Duration(minutes: 10)))}',
        'At Home',
        'Working: Café',
      ]);
      expect(snap.chronometerBase, _now.subtract(const Duration(minutes: 10)));
      expect(snap.primaryMemberId, 'a');
      expect(snap.subText, '2');
    },
  );

  test('mood freshness, emotions and per-member style', () {
    final mood = MoodEntry(
      id: 'm',
      mood: 4,
      emotions: const ['calm@3', 'hopeful'],
      recordedAt: _now.subtract(const Duration(hours: 2)),
      createdAt: _now,
      modifiedAt: _now,
    );
    final settings = const FrontingNotificationSettings().copyWith(
      info: [FnInfo.mood, FnInfo.emotions],
      greeting: 'General',
      memberStyles: {
        'a': const FnMemberStyle(
          title: 'Ash is here',
          greeting: 'Hi {first}!',
          emoji: '⭐',
          accentColor: 0xFF00FF00,
        ),
      },
    );
    final snap = buildFrontingSnapshot(
      settings,
      _inputs(sessions: [_s('a', 5)], mood: mood),
      _strings,
      _now,
    );
    expect(snap.title, 'Ash is here');
    expect(snap.text, 'Hi Ash!');
    expect(snap.lines, ['Mood: Good (4/5)', 'Feeling: calm, hopeful']);
    expect(snap.iconEmoji, '⭐');
    expect(snap.accentColor, 0xFF00FF00);
    final stale = buildFrontingSnapshot(
      settings.copyWith(moodMaxAgeHours: 1),
      _inputs(sessions: [_s('k', 5)], mood: mood),
      _strings,
      _now,
    );
    expect(stale.lines, isEmpty);
    expect(stale.text, 'General');
  });

  test('nobody fronting: message, hide, or asleep', () {
    const base = FrontingNotificationSettings(
      actions: [FnAction.switchFronter, FnAction.mood],
    );
    final msg = buildFrontingSnapshot(base, _inputs(), _strings, _now);
    expect(msg.hidden, isFalse);
    expect(msg.title, 'Nobody is logged as fronting');
    expect(msg.actions.map((a) => a.$1), [FnAction.mood]);
    expect(
      buildFrontingSnapshot(
        base.copyWith(whenEmpty: FnWhenEmpty.hide),
        _inputs(),
        _strings,
        _now,
      ).hidden,
      isTrue,
    );
    final sleep = FrontingSession(
      id: 'z',
      startTime: _now.subtract(const Duration(hours: 1)),
      sessionType: SessionType.sleep,
    );
    final asleep = buildFrontingSnapshot(
      base.copyWith(info: [FnInfo.status]),
      _inputs(sleep: sleep),
      _strings,
      _now,
    );
    expect(asleep.lines, [
      'Asleep since ${_strings.formatTime(_now.subtract(const Duration(hours: 1)))}',
    ]);
    expect(
      fillTemplate('{a}  and {missing} {b}', {'a': 'x', 'b': 'y'}),
      'x and y',
    );
  });

  test(
    'controller pushes once per real change and cancels when disabled',
    () async {
      final platform = _FakePlatform();
      var inputs = _inputs(sessions: [_s('a', 5)]);
      final settings = const FrontingNotificationSettings(
        enabled: true,
        iconSource: FnIconSource.builtIn,
      );
      final c = ProviderContainer(
        overrides: [
          frontingStatusPlatformProvider.overrideWithValue(platform),
          frontingNotificationSettingsProvider.overrideWith(
            () => _FixedSettings(settings),
          ),
          frontingNotificationInputsProvider.overrideWith((ref) => inputs),
        ],
      );
      addTearDown(c.dispose);
      await c.read(frontingNotificationSettingsProvider.future);
      final controller = c.read(frontingNotificationControllerProvider);
      await controller.push();
      await controller.push();
      expect(platform.shows, hasLength(1));
      expect(platform.shows.single['title'], 'Fronting: Ash');
      expect(platform.shows.single['ongoing'], isTrue);
      expect(platform.shows.single['visibility'], 'private');
      expect((platform.shows.single['actions'] as List).length, 3);

      inputs = _inputs(sessions: [_s('a', 5), _s('k', 1)]);
      c.invalidate(frontingNotificationInputsProvider);
      await controller.push();
      expect(platform.shows, hasLength(2));
      expect(platform.shows.last['title'], 'Fronting: Kai, Ash');

      await c
          .read(frontingNotificationSettingsProvider.notifier)
          .save(settings.copyWith(enabled: false));
      await controller.push();
      expect(platform.cancels, 1);
      await controller.push();
      expect(platform.cancels, 1);
    },
  );

  test('platform calls are safe without the native side', () async {
    final p = FrontingStatusPlatform(channel: const MethodChannel('test/none'));
    expect(await p.show({'title': 'x'}), isFalse);
    expect(await p.takePendingAction(), isNull);
  });
}
