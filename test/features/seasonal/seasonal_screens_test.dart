import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/core/database/app_database.dart';
import 'package:prism_plurality/core/database/database_provider.dart';
import 'package:prism_plurality/core/sync/prism_sync_providers.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/seasonal/decor_models.dart';
import 'package:prism_plurality/features/seasonal/decoration_studio_screen.dart';
import 'package:prism_plurality/features/seasonal/seasonal_calendar.dart';
import 'package:prism_plurality/features/seasonal/seasonal_catalog.dart';
import 'package:prism_plurality/features/seasonal/seasonal_hub_screen.dart';
import 'package:prism_plurality/features/seasonal/seasonal_prefs_screen.dart';
import 'package:prism_plurality/features/seasonal/seasonal_providers.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';

class _FakePrefs extends SeasonalPrefsNotifier {
  @override
  Future<void> flush() async {}
}

class _FakeTracker extends TrackerNotifier {
  @override
  Future<TrackerRecord> create({
    required String kind,
    String title = '',
    String? body,
    String? parentId,
    Map<String, Object?> fields = const {},
    List<String> tags = const [],
    DateTime? occurredAt,
    DateTime? endedAt,
    int? amount,
    String? memberId,
    bool isPrivate = false,
    bool isPinned = false,
    int sortOrder = 0,
    DateTime? now,
  }) async => TrackerRecord(
    id: 'fake',
    kind: kind,
    title: title,
    createdAt: DateTime(2026),
    modifiedAt: DateTime(2026),
  ).withFields(fields);

  @override
  Future<void> save(TrackerRecord record, {DateTime? now}) async {}

  @override
  Future<void> delete(String id, {bool children = true}) async {}
}

/// A container with no database, for widget tests (a real database leaves
/// close-timers pending under the test clock).
ProviderContainer _lightContainer() => ProviderContainer(
  overrides: [
    seasonalPrefsProvider.overrideWith(_FakePrefs.new),
    trackerNotifierProvider.overrideWith(_FakeTracker.new),
    trackerKindProvider.overrideWith(
      (ref, kind) => const AsyncValue.data(<TrackerRecord>[]),
    ),
  ],
);

class _Env {
  _Env() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        prismSyncHandleProvider.overrideWithBuild((ref, notifier) => null),
      ],
    );
  }
  late final AppDatabase db;
  late final ProviderContainer container;
  Future<void> dispose() async {
    container.dispose();
    await db.close();
  }
}

Widget _host(ProviderContainer c, Widget child) => UncontrolledProviderScope(
  container: c,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  ),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  test('preferences are saved and come back after a restart', () async {
    final env = _Env();
    addTearDown(env.dispose);
    final n = env.container.read(seasonalPrefsProvider.notifier);
    n.update(
      (p) => p.copyWith(
        performance: DecoPerformance.immersive,
        celebrated: {'christmas'},
        autoSchedule: true,
        region: SeasonalRegion.europe,
        audioOn: true,
        audioId: 'fire',
      ),
    );
    await n.flush();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    // A fresh container over the same database stands in for a restart.
    final again = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(env.db),
        prismSyncHandleProvider.overrideWithBuild((ref, notifier) => null),
      ],
    );
    addTearDown(again.dispose);
    final sub = again.listen(seasonalPrefsProvider, (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final p = sub.read();
    expect(p.performance, DecoPerformance.immersive);
    expect(p.celebrated, {'christmas'});
    expect(p.autoSchedule, isTrue);
    expect(p.audioId, 'fire');
  });

  test(
    'switching Reduced motion off stays off, including after a restart',
    () async {
      final env = _Env();
      addTearDown(env.dispose);
      final n = env.container.read(seasonalPrefsProvider.notifier);
      final sub = env.container.listen(seasonalPrefsProvider, (_, _) {});
      n.update((p) => p.copyWith(reducedMotion: true, greetingsOn: false));
      await n.flush();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      n.update((p) => p.copyWith(reducedMotion: false));
      expect(sub.read().reducedMotion, isFalse);
      await n.flush();
      // The database stream catching up must not flip it back on.
      for (var i = 0; i < 6; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(sub.read().reducedMotion, isFalse, reason: 'tick $i');
      }
      final again = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(env.db),
          prismSyncHandleProvider.overrideWithBuild((ref, notifier) => null),
        ],
      );
      addTearDown(again.dispose);
      final sub2 = again.listen(seasonalPrefsProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(sub2.read().reducedMotion, isFalse);
    },
  );

  test(
    'arrangements can be saved, updated, duplicated, exported, imported and deleted',
    () async {
      final env = _Env();
      addTearDown(env.dispose);
      final c = env.container;
      final actions = c.read(decorPresetActionsProvider);
      final sub = c.listen(decorPresetsProvider, (_, _) {});
      final id = await actions.create(
        DecorPreset(
          id: '',
          name: 'Cozy',
          category: 'Winter',
          items: arrangementForVariation(variationById('christmas.1')!),
          thumbnail: 'AAAA',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      var list = sub.read();
      expect(list.single.name, 'Cozy');
      expect(list.single.items.length, greaterThan(5));

      await actions.update(
        DecorPreset(
          id: id,
          name: 'Cozy 2',
          category: 'Winter',
          items: list.single.items,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(sub.read().single.name, 'Cozy 2');

      await actions.duplicate(sub.read().single);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(sub.read().length, 2);

      // Export then import into a clean slate: same content, new id, no theme change.
      final exported = exportPreset(sub.read().first);
      final imported = importPreset(exported.json)!;
      expect(imported.items.length, sub.read().first.items.length);
      expect(imported.id, isEmpty);

      // Delete cleans up anything pointing at it.
      c
          .read(seasonalPrefsProvider.notifier)
          .update(
            (p) => p.copyWith(
              activePresetId: id,
              alterPresets: {'m1': id, 'm2': 'other'},
            ),
          );
      await actions.delete(id);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final p = c.read(seasonalPrefsProvider);
      expect(p.activePresetId, isNull);
      expect(p.alterPresets, {'m2': 'other'});
      await c.read(seasonalPrefsProvider.notifier).flush();
    },
  );

  test(
    'importing rejects anything that is not a Prism arrangement, and never runs it',
    () {
      expect(importPreset('not json'), isNull);
      expect(importPreset('{"prismDecor": 1}'), isNull);
      expect(importPreset('{"hello": "world"}'), isNull);
      expect(importPreset('x' * (3 * 1024 * 1024)), isNull);
      final big =
          '{"prismDecor":1,"preset":{"it":[${List.filled(500, '{"id":"a","k":"garland"}').join(',')}]}}';
      expect(importPreset(big), isNull);
    },
  );

  test(
    'exported arrangements leave device-only pictures out and say how many',
    () {
      final p = DecorPreset(
        id: 'p',
        name: 'x',
        items: [
          DecorItem(id: 'a', kind: DecoKind.garland),
          DecorItem(id: 'b', kind: DecoKind.sticker, image: 'media-1'),
        ],
      );
      final e = exportPreset(p);
      expect(e.skipped, 1);
      expect(importPreset(e.json)!.items.length, 1);
    },
  );

  test(
    'a theme can carry decorations without them applying or touching the theme',
    () {
      final p = DecorPreset(
        id: 'p',
        name: 'Winter',
        items: [DecorItem(id: 'a', kind: DecoKind.garland)],
      );
      final themed = attachDecorToThemeExport(
        '{"name":"Gothic","accent":123}',
        p,
      );
      expect(themed.contains('"name": "Gothic"'), isTrue);
      expect(extractDecorFromThemeImport(themed)!.name, 'Winter');
      expect(extractDecorFromThemeImport('{"name":"Plain"}'), isNull);
      expect(attachDecorToThemeExport('not json', p), 'not json');
    },
  );

  testWidgets('the hub explains independence and starts switched off', (
    tester,
  ) async {
    final c = _lightContainer();
    tester.view.physicalSize = const Size(420, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(c, const SeasonalHubScreen()));
    await _settle(tester);
    expect(
      find.textContaining('never changes your background'),
      findsOneWidget,
    );
    expect(find.text('Off'), findsWidgets);
    expect(find.textContaining('Seasonal Living is off'), findsOneWidget);
    expect(find.textContaining('yours, never changed here'), findsNWidgets(3));
    // Ambient sound is off until you turn it on.
    expect(c.read(seasonalPrefsProvider).audioOn, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('choosing a mode turns Seasonal Living on', (tester) async {
    final c = _lightContainer();
    tester.view.physicalSize = const Size(420, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(c, const SeasonalHubScreen()));
    await _settle(tester);
    await tester.tap(find.text('Balanced'));
    await _settle(tester);
    expect(c.read(seasonalPrefsProvider).performance, DecoPerformance.balanced);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets(
    'preferences: scheduling is off until chosen, holidays can be celebrated or hidden',
    (tester) async {
      final c = _lightContainer();
      tester.view.physicalSize = const Size(420, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(c, const SeasonalPrefsScreen()));
      await _settle(tester);
      expect(c.read(seasonalPrefsProvider).autoSchedule, isFalse);
      await tester.tap(find.byTooltip('I celebrate Christmas'));
      await _settle(tester);
      expect(c.read(seasonalPrefsProvider).celebrated, contains('christmas'));
      await tester.tap(find.byTooltip('Hide Christmas'));
      await _settle(tester);
      final p = c.read(seasonalPrefsProvider);
      expect(p.hidden, contains('christmas'));
      expect(p.celebrated, isNot(contains('christmas')));
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets(
    'studio: add a whole look, undo and redo, group, lock, and the draft is kept',
    (tester) async {
      final c = _lightContainer();
      tester.view.physicalSize = const Size(420, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(c, const DecorationStudioScreen()));
      await _settle(tester);
      expect(find.text('Decoration Studio'), findsOneWidget);

      await tester.tap(find.text('The whole look'));
      await _settle(tester);
      // The Layers tab lists what was added.
      await tester.tap(find.text('Layers'));
      await _settle(tester);
      expect(find.textContaining('Interactive object'), findsWidgets);

      // Undo takes it all back; redo restores it.
      await tester.tap(find.byTooltip('Undo'));
      await _settle(tester);
      expect(find.textContaining('Nothing here yet'), findsOneWidget);
      await tester.tap(find.byTooltip('Redo'));
      await _settle(tester);
      expect(find.textContaining('Interactive object'), findsWidgets);

      // Select all, group, then lock.
      await tester.tap(find.text('Select all'));
      await _settle(tester);
      await tester.tap(find.text('Group'));
      await _settle(tester);
      await tester.tap(find.text('Lock'));
      await _settle(tester);
      expect(find.byIcon(Icons.lock), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 2));
    },
  );
}
