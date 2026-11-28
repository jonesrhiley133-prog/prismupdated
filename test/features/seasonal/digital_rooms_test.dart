import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/appearance/appearance_library.dart';
import 'package:prism_plurality/features/boards/providers/board_posts_providers.dart'
    show currentFronterMemberIdsProvider;
import 'package:prism_plurality/features/seasonal/decor_models.dart';
import 'package:prism_plurality/features/seasonal/decor_painter.dart';
import 'package:prism_plurality/features/seasonal/decor_presets_screen.dart';
import 'package:prism_plurality/features/seasonal/living_environment.dart';
import 'package:prism_plurality/features/seasonal/living_layout.dart';
import 'package:prism_plurality/features/seasonal/seasonal_providers.dart';
import 'package:prism_plurality/features/subsystems/hub/subsystem_data.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';

class _FakePrefs extends SeasonalPrefsNotifier {
  @override
  Future<void> flush() async {}
}

class _FakeLib extends AppearanceLibraryNotifier {
  @override
  Future<void> flush() async {}
}

final _created = <Map<String, Object?>>[];

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
  }) async {
    _created.add(fields);
    return TrackerRecord(
      id: 'new-room',
      kind: kind,
      title: title,
      createdAt: DateTime(2026),
      modifiedAt: DateTime(2026),
    ).withFields(fields);
  }

  @override
  Future<void> save(TrackerRecord record, {DateTime? now}) async {}

  @override
  Future<void> delete(String id, {bool children = true}) async {}
}

DecorPreset _room(String id, {RoomSettings? room}) => DecorPreset(
  id: id,
  name: id,
  items: [DecorItem(id: '$id-i', kind: DecoKind.illustration, glyph: '🪴')],
  room: room,
);

ProviderContainer _container({
  List<DecorPreset> presets = const [],
  List<String> fronters = const [],
  List<SubMembership> memberships = const [],
}) => ProviderContainer(
  overrides: [
    seasonalPrefsProvider.overrideWith(_FakePrefs.new),
    appearanceLibraryProvider.overrideWith(_FakeLib.new),
    trackerNotifierProvider.overrideWith(_FakeTracker.new),
    trackerKindProvider.overrideWith(
      (ref, kind) => const AsyncValue.data(<TrackerRecord>[]),
    ),
    decorPresetsProvider.overrideWithValue(presets),
    currentFronterMemberIdsProvider.overrideWithValue(fronters),
    subMembershipsProvider.overrideWithValue(memberships),
  ],
);

SubMembership _member(String sub, String member) => SubMembership(
  TrackerRecord(
    id: '$sub-$member',
    kind: TrackerKind.subMember,
    parentId: sub,
    memberId: member,
    createdAt: DateTime(2026),
    modifiedAt: DateTime(2026),
  ),
);

void main() {
  const settings = RoomSettings(
    living: 'kawaii.1',
    layout: 'cyberpunk.4',
    layoutParts: {'cards'},
    env: EnvSettings(mode: WeatherMode.manual, weather: WeatherKind.snow),
    audioId: 'rain',
    lighting: 'evening',
    companions: ['c1'],
  );

  test('a room keeps everything through save, export and import', () {
    final r = _room('cozy', room: settings);
    final back = DecorPreset.fromJson(r.toJson())!;
    expect(back.isRoom, isTrue);
    expect(back.room!.toJson(), settings.toJson());
    final shared = importPreset(exportPreset(r).json)!;
    expect(shared.room!.toJson(), settings.toJson());
    expect(shared.id, isEmpty, reason: 'imports never overwrite');
    // Unknown lighting is dropped; plain presets aren't rooms.
    expect(RoomSettings.fromJson({'lt': 'noon'})!.lighting, isNull);
    expect(DecorPreset.fromJson(_room('plain').toJson())!.isRoom, isFalse);
  });

  test('subsystem assignments are saved', () {
    final p = const SeasonalPrefs().copyWith(subsystemPresets: {'s1': 'r1'});
    expect(SeasonalPrefs.fromJson(p.toJson()).subsystemPresets, {'s1': 'r1'});
  });

  test('profiles: alter, then subsystem, then the system choice', () {
    final presets = [
      _room('system'),
      _room('subsystem', room: settings),
      _room('alter'),
    ];
    ProviderContainer make(List<String> fronters) => _container(
      presets: presets,
      fronters: fronters,
      memberships: [_member('s1', 'm2')],
    );
    void prefs(ProviderContainer c) => c
        .read(seasonalPrefsProvider.notifier)
        .update(
          (p) => p.copyWith(
            performance: DecoPerformance.balanced,
            activePresetId: 'system',
            alterPresets: {'m1': 'alter'},
            subsystemPresets: {'s1': 'subsystem'},
          ),
        );
    final a = make(['m1', 'm2']);
    prefs(a);
    expect(a.read(frontPresetProvider)?.id, 'alter');
    final b = make(['m2']);
    prefs(b);
    expect(b.read(frontPresetProvider)?.id, 'subsystem');
    // The subsystem's room brings its own look, layout and weather…
    expect(b.read(activeRoomProvider)?.audioId, 'rain');
    expect(
      b.read(seasonalItemsProvider).any((i) => i.variationId == 'kawaii.1'),
      isTrue,
    );
    expect(b.read(effectiveEnvProvider).weather, WeatherKind.snow);
    expect(b.read(layoutDecorProvider)?.on('cards'), isTrue);
    expect(b.read(layoutDecorProvider)?.on('dividers'), isFalse);
    final c = make(['someone-else']);
    prefs(c);
    expect(c.read(frontPresetProvider)?.id, 'system');
    // …and a plain arrangement inherits the system's environment.
    expect(c.read(effectiveEnvProvider).mode, WeatherMode.off);
    for (final x in [a, b, c]) {
      x.dispose();
    }
  });

  test(
    'switching or removing a look changes the room that is showing it',
    () async {
      _created.clear();
      final c = _container(presets: [_room('den', room: settings)]);
      addTearDown(c.dispose);
      c
          .read(seasonalPrefsProvider.notifier)
          .update(
            (p) => p.copyWith(
              performance: DecoPerformance.balanced,
              activePresetId: 'den',
              livingVariation: 'bookshop.1',
            ),
          );
      // The room's own look is the one in effect, not the system's.
      expect(c.read(effectiveLivingProvider), 'kawaii.1');
      await c.read(decorLayersProvider).setLiving('cyberpunk.3');
      expect(DecorPreset.fromJson(_created.last)!.room!.living, 'cyberpunk.3');
      expect(c.read(seasonalPrefsProvider).livingVariation, 'bookshop.1');
      await c.read(decorLayersProvider).setLiving(null);
      expect(DecorPreset.fromJson(_created.last)!.room!.living, isNull);
      expect(
        c.read(seasonalPrefsProvider).livingVariation,
        isNull,
        reason: 'off is off everywhere',
      );
      // Environment edits go to the room's own environment too.
      await c
          .read(decorLayersProvider)
          .setEnv((e) => e.copyWith(weather: WeatherKind.fog));
      expect(
        DecorPreset.fromJson(_created.last)!.room!.env!.weather,
        WeatherKind.fog,
      );
      await c.read(decorLayersProvider).setLayoutParts({'cards'});
      expect(DecorPreset.fromJson(_created.last)!.room!.layoutParts, {'cards'});
    },
  );

  test('without a room, layers change the system settings', () async {
    final c = _container();
    addTearDown(c.dispose);
    await c.read(decorLayersProvider).setLiving('kawaii.4');
    expect(c.read(seasonalPrefsProvider).livingVariation, 'kawaii.4');
    expect(
      c.read(seasonalPrefsProvider).performance,
      isNot(DecoPerformance.off),
    );
    await c.read(decorLayersProvider).setLayout('gothic.1');
    expect(c.read(effectiveLayoutProvider).$1, 'gothic.1');
    await c.read(decorLayersProvider).setLiving(null);
    expect(c.read(effectiveLivingProvider), isNull);
  });

  test('studio extras round-trip, are bounded and paint', () {
    final i = DecorItem(
      id: 'x',
      kind: DecoKind.illustration,
      glyph: '🌷',
      shadow: 0.6,
      outline: 3,
      texture: 'kraft',
      safeArea: true,
      scroll: true,
    );
    final b = DecorItem.fromJson(i.toJson())!;
    expect(
      [b.shadow, b.outline, b.texture, b.safeArea, b.scroll],
      [0.6, 3.0, 'kraft', true, true],
    );
    expect(
      DecorItem.fromJson({
        'id': 'y',
        'k': 'flower',
        'ol': 99,
        'sh': 4,
      })!.outline,
      12,
    );
    final rec = ui.PictureRecorder();
    DecorPainter(
      scene: DecorScene(
        items: [
          i,
          DecorItem(id: 'z', kind: DecoKind.flower, outline: 2),
        ],
        layers: const DecoLayerSettings(),
        safe: const EdgeInsets.only(top: 40),
        scroll: 120,
      ),
      t: 1,
      layersToDraw: const {DecoLayer.staticDeco},
    ).paint(Canvas(rec), const Size(400, 800));
    rec.endRecording().dispose();
  });

  testWidgets('rooms screen saves what is showing as a new room', (t) async {
    _created.clear();
    final c = _container(
      presets: [
        _room('plain'),
        _room('den', room: settings),
      ],
    );
    c
        .read(seasonalPrefsProvider.notifier)
        .update(
          (p) => p.copyWith(
            performance: DecoPerformance.balanced,
            livingVariation: 'bookshop.2',
          ),
        );
    t.view.physicalSize = const Size(420, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DecorPresetsScreen(rooms: true),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 200));
    expect(find.text('Digital Rooms'), findsOneWidget);
    expect(find.text('den'), findsOneWidget);
    expect(find.text('plain'), findsNothing, reason: 'rooms only');
    await t.tap(find.text('New room from what\'s showing'));
    for (var k = 0; k < 8; k++) {
      await t.pump(const Duration(milliseconds: 150));
    }
    expect(find.text('Create room'), findsOneWidget);
    await t.tap(find.text('Create room'), warnIfMissed: true);
    for (var k = 0; k < 6; k++) {
      await t.pump(const Duration(milliseconds: 200));
    }
    expect(_created, hasLength(1));
    final saved = DecorPreset.fromJson(_created.single)!;
    expect(saved.room?.living, 'bookshop.2');
    expect(c.read(seasonalPrefsProvider).activePresetId, 'new-room');
    await t.pump(const Duration(seconds: 4));
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });
}
