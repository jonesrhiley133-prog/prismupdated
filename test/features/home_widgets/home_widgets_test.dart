import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/models/note.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/cycle/utils/cycle_stats.dart';
import 'package:prism_plurality/features/home_widgets/models/widget_catalog.dart';
import 'package:prism_plurality/features/home_widgets/models/widget_config.dart';
import 'package:prism_plurality/features/home_widgets/services/home_widget_data.dart';
import 'package:prism_plurality/features/home_widgets/services/home_widget_models.dart';
import 'package:prism_plurality/features/home_widgets/services/home_widget_platform.dart';
import 'package:prism_plurality/features/home_widgets/services/home_widget_store.dart';
import 'package:prism_plurality/features/home_widgets/views/widget_preview.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';

final _now = DateTime(2026, 11, 12, 15);
final _l10n = lookupAppLocalizations(const Locale('en'));

Member _m(String id, String name, {String emoji = '❔'}) =>
    Member(id: id, name: name, emoji: emoji, createdAt: _now);

TrackerRecord _r(
  String id,
  String kind,
  String title, {
  String? body,
  bool private = false,
  int? amount,
  Map<String, Object?>? data,
  DateTime? at,
}) => TrackerRecord(
  id: id,
  kind: kind,
  title: title,
  body: body,
  isPrivate: private,
  amount: amount,
  data: data == null ? null : jsonEncode(data),
  occurredAt: at ?? _now,
  createdAt: _now,
  modifiedAt: _now,
);

HomeWidgetData _data({
  List<TrackerRecord> records = const [],
  List<Note> notes = const [],
}) => HomeWidgetData(
  now: _now,
  members: {
    for (final m in [_m('a', 'Ash Vale', emoji: '🌸'), _m('k', 'Kai')]) m.id: m,
  },
  activeSessions: [
    FrontingSession(
      id: 's1',
      memberId: 'a',
      startTime: _now.subtract(const Duration(minutes: 30)),
    ),
  ],
  recentSessions: [
    FrontingSession(
      id: 's1',
      memberId: 'a',
      startTime: _now.subtract(const Duration(minutes: 30)),
    ),
    FrontingSession(
      id: 's0',
      memberId: 'k',
      startTime: _now.subtract(const Duration(hours: 5)),
      endTime: _now.subtract(const Duration(minutes: 30)),
    ),
  ],
  sleepSessions: const [],
  moods: const [],
  cycleEntries: const [],
  cycleStats: const CycleStats(
    periodStarts: [],
    cycleLengths: [],
    averageCycleLength: null,
    averagePeriodLength: null,
    currentCycleDay: null,
    nextPeriodEstimate: null,
  ),
  places: const [],
  records: records,
  notes: notes,
  contacts: const [],
  achievements: const [],
  currency: 'USD',
  customStatus: '',
);

Map<String, Object?> _build(
  String type,
  HomeWidgetData d, {
  WidgetPrivacy privacy = const WidgetPrivacy(),
  Map<String, Object?> options = const {},
}) => buildWidgetModel(
  WidgetConfig(type: type, privacy: privacy, options: options),
  d,
  _l10n,
  'en',
);

List<Map<String, Object?>> _rows(Map<String, Object?> m) => [
  for (final r in m['rows'] as List) r as Map<String, Object?>,
];

void main() {
  test('catalog has 20 unique widget types across 4 categories', () {
    expect(widgetCatalog.length, 20);
    expect({for (final w in widgetCatalog) w.key}.length, 20);
    expect({for (final w in widgetCatalog) w.category}.length, 4);
  });

  test('config survives a JSON round trip', () {
    const cfg = WidgetConfig(
      type: 'mood',
      name: 'Glass',
      style: WidgetStyle(
        theme: WidgetTheme.amoled,
        bg1: 0xFF112233,
        opacity: 0.4,
        radius: 12,
        font: WidgetFont.mono,
        compact: true,
      ),
      privacy: WidgetPrivacy(hideSensitive: false, hideNames: true),
      options: {
        'days': 30,
        'memberIds': ['a'],
      },
    );
    final back = WidgetConfig.fromJson(
      jsonDecode(jsonEncode(cfg.toJson())) as Map<String, dynamic>,
    );
    expect(back.toJson(), cfg.toJson());
    expect(back.intOption('days', 7), 30);
    expect(back.stringList('memberIds'), ['a']);
  });

  test('bad stored values are clamped, privacy defaults to hidden', () {
    final cfg = WidgetConfig.fromJson({
      'type': 'notes',
      'style': <String, dynamic>{'opacity': 9, 'radius': -4, 'theme': 'nope'},
    });
    expect(cfg.style.opacity, 1);
    expect(cfg.style.radius, 0);
    expect(cfg.style.theme, WidgetTheme.system);
    expect(cfg.privacy.hideSensitive, isTrue);
  });

  test('palette: AMOLED is pure black, overrides win', () {
    expect(
      paletteFor(const WidgetStyle(theme: WidgetTheme.amoled), dark: true).bg1,
      0xFF000000,
    );
    final p = paletteFor(
      const WidgetStyle(bg1: 0xFF010203, textColor: 0xFFABCDEF),
      dark: false,
    );
    expect(p.bg1, 0xFF010203);
    expect(p.bg2, 0xFF010203);
    expect(p.text, 0xFFABCDEF);
  });

  test('every widget type builds an encodable model', () {
    for (final w in widgetCatalog) {
      final m = _build(w.key, _data());
      expect(m['header'], isA<Map>(), reason: w.key);
      expect(() => jsonEncode(m), returnsNormally, reason: w.key);
    }
  });

  test(
    'current fronter shows the fronting alter; initials when names are hidden',
    () {
      final d = _data();
      final shown =
          _build('current_fronter', d)['header'] as Map<String, Object?>;
      expect(shown['title'], 'Ash Vale');
      expect(shown['memberId'], 'a');
      final hidden =
          _build(
                'current_fronter',
                d,
                privacy: const WidgetPrivacy(hideNames: true),
              )['header']
              as Map<String, Object?>;
      expect(hidden['title'], 'AV');
      expect(hidden.containsKey('memberId'), isFalse);
    },
  );

  test('quick front marks who is fronting and toggles in the background', () {
    final rows = _rows(_build('quick_front', _data()));
    expect(rows.first['title'], 'Ash Vale');
    expect(rows.first['checked'], isTrue);
    expect(rows[1]['checked'], isFalse);
    final action = rows[1]['action'] as Map<String, Object?>;
    expect(action['action'], 'quickfront:k');
    expect(action['background'], isTrue);
  });

  test('journal text stays off the home screen unless explicitly allowed', () {
    final d = _data(
      records: [
        _r(
          'j1',
          TrackerKind.journalEntry,
          'Therapy notes',
          body: 'secret body',
        ),
        _r(
          'j2',
          TrackerKind.journalEntry,
          'Locked',
          body: 'very secret',
          private: true,
        ),
      ],
    );
    final safe = jsonEncode(_build('journal', d));
    expect(safe.contains('secret body'), isFalse);
    expect(safe.contains('Therapy notes'), isFalse);
    final open = jsonEncode(
      _build('journal', d, privacy: const WidgetPrivacy(hideSensitive: false)),
    );
    expect(open.contains('Therapy notes'), isTrue);
    expect(open.contains('secret body'), isTrue);
    // Private entries never leak, even when the widget is opened up.
    expect(open.contains('very secret'), isFalse);
    expect(open.contains('Locked'), isFalse);
  });

  test('finance shows nothing by default and masks numbers on request', () {
    final d = _data(
      records: [
        _r(
          't1',
          TrackerKind.financeTxn,
          'Rent',
          amount: 123456,
          data: {'type': 'expense', 'category': 'Housing'},
        ),
      ],
    );
    final safe = _build('finance', d);
    expect(jsonEncode(safe).contains('1,234'), isFalse);
    expect(_rows(safe), isEmpty);
    final open = jsonEncode(
      _build('finance', d, privacy: const WidgetPrivacy(hideSensitive: false)),
    );
    expect(open.contains('1,234.56'), isTrue);
    final masked = jsonEncode(
      _build(
        'finance',
        d,
        privacy: const WidgetPrivacy(hideSensitive: false, maskNumbers: true),
      ),
    );
    expect(masked.contains('1,234'), isFalse);
    expect(masked.contains('••••'), isTrue);
  });

  test('notes hide titles and bodies by default', () {
    final d = _data(
      notes: [
        Note(
          id: 'n1',
          title: 'Triggers',
          body: 'private list',
          date: _now,
          createdAt: _now,
          modifiedAt: _now,
        ),
      ],
    );
    final safe = jsonEncode(_build('notes', d));
    expect(safe.contains('Triggers'), isFalse);
    expect(safe.contains('private list'), isFalse);
    expect(
      jsonEncode(
        _build('notes', d, privacy: const WidgetPrivacy(hideSensitive: false)),
      ).contains('Triggers'),
      isTrue,
    );
  });

  test('to-do rows toggle optimistically; done tasks hidden unless asked', () {
    final d = _data(
      records: [
        _r('t1', todoKind, 'Water plants'),
        _r('t2', todoKind, 'Old', data: {'done': true}),
      ],
    );
    final rows = _rows(_build('todo', d));
    expect(rows.length, 1);
    expect((rows.single['action'] as Map)['optimistic'], {'toggleRow': 0});
    expect(_rows(_build('todo', d, options: {'showDone': true})).length, 2);
  });

  test('countdown includes custom dates, soonest first', () {
    final m = _build(
      'countdown',
      _data(),
      options: {
        'events': false,
        'birthdays': false,
        'countdowns': [
          {
            'title': 'Trip',
            'date': _now.add(const Duration(days: 9)).millisecondsSinceEpoch,
          },
          {
            'title': 'Concert',
            'date': _now.add(const Duration(days: 2)).millisecondsSinceEpoch,
          },
          {
            'title': 'Past',
            'date': _now
                .subtract(const Duration(days: 2))
                .millisecondsSinceEpoch,
          },
        ],
      },
    );
    expect((m['header'] as Map)['title'], 'Concert');
    expect(_rows(m).map((r) => r['title']), ['Trip']);
  });

  test('statistics share front time between alters', () {
    final rows = _rows(_build('stats', _data()));
    expect(rows.first['title'], 'Kai');
    expect(rows.first['trailing'], '90%');
    expect(rows[1]['trailing'], '10%');
  });

  test('store keeps separate looks for two widgets of the same type', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(homeWidgetsProvider.future);
    final n = c.read(homeWidgetsProvider.notifier);
    await n.saveConfig(
      1,
      const WidgetConfig(type: 'mood', style: WidgetStyle(radius: 4)),
    );
    await n.saveConfig(
      2,
      const WidgetConfig(type: 'mood', style: WidgetStyle(radius: 30)),
    );
    await n.saveDefault(
      const WidgetConfig(type: 'mood', style: WidgetStyle(radius: 16)),
    );
    await n.savePreset(const WidgetConfig(type: 'mood', name: 'Mine'));
    var s = c.read(homeWidgetsProvider).value!;
    expect(s.configFor(1, 'mood').style.radius, 4);
    expect(s.configFor(2, 'mood').style.radius, 30);
    expect(s.configFor(3, 'mood').style.radius, 16);
    expect(s.recent, ['mood']);
    await n.prune({2});
    await n.resetConfig(null, 'mood');
    // Reload from disk: persisted across restarts.
    final c2 = ProviderContainer();
    addTearDown(c2.dispose);
    s = await c2.read(homeWidgetsProvider.future);
    expect(s.configs.keys, [2]);
    expect(s.configFor(1, 'mood').style.radius, 24);
    expect(s.presets.single.name, 'Mine');
  });

  test(
    'platform bridge parses placed widgets and the offline action queue',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const channel = MethodChannel('test/widgets');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return switch (call.method) {
              'listWidgets' => [
                {'id': 5, 'type': 'mood', 'minWidth': 120, 'maxHeight': 120},
                {'id': 6, 'type': 'todo', 'minWidth': 300, 'maxHeight': 300},
              ],
              'takeQueue' =>
                '[{"id":5,"action":"mood:4","at":1},{"id":6,"action":"todo:t1","at":2}]',
              _ => true,
            };
          });
      final p = HomeWidgetPlatform(channel: channel, supported: true);
      final placed = await p.listWidgets();
      expect(placed.map((w) => w.size), ['small', 'large']);
      expect((await p.takeQueue()).map((q) => q.action), ['mood:4', 'todo:t1']);
      await p.updateWidgets({
        5: {
          'header': {'title': 'x'},
        },
      });
      final sent = (calls.last.arguments as Map)['models'] as Map;
      expect(jsonDecode(sent['5'] as String), {
        'header': {'title': 'x'},
      });
      expect(
        await HomeWidgetPlatform(
          channel: channel,
          supported: false,
        ).listWidgets(),
        isEmpty,
      );
    },
  );

  testWidgets('preview renders every type at every size without overflow', (
    tester,
  ) async {
    final d = _data(records: [_r('t1', todoKind, 'Water plants')]);
    for (final w in widgetCatalog) {
      for (final size in const ['small', 'medium', 'large']) {
        const cfg = WidgetConfig(type: 'x');
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: WidgetPreview(
                  model: _build(w.key, d),
                  config: cfg.copyWith(type: w.key),
                  data: d,
                  size: size,
                  dark: true,
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: '${w.key} $size');
      }
    }
  });
}
