import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/boards/providers/board_posts_providers.dart'
    show currentFronterMemberIdsProvider;
import 'package:prism_plurality/features/subsystems/hub/subsystem_data.dart'
    show subMembershipsProvider;
import 'package:prism_plurality/features/music/services/music_player.dart';
import 'package:prism_plurality/features/seasonal/decor_models.dart';
import 'package:prism_plurality/features/seasonal/living_environment.dart';
import 'package:prism_plurality/features/seasonal/living_layout.dart';
import 'package:prism_plurality/shared/theme/layout_decor.dart';
import 'package:prism_plurality/features/seasonal/seasonal_catalog.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';

/// The current date, refreshed so a look can change at midnight without the
/// app being restarted.
final seasonalClockProvider = StreamProvider<DateTime>((ref) {
  final controller = StreamController<DateTime>();
  Timer? timer;
  void schedule() {
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    timer = Timer(
      nextMidnight.difference(now) + const Duration(seconds: 2),
      () {
        if (controller.isClosed) return;
        controller.add(DateTime.now());
        schedule();
      },
    );
  }

  controller.add(DateTime.now());
  schedule();
  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });
  return controller.stream;
});

TrackerRecord? _first(AsyncValue<List<TrackerRecord>> v) =>
    (v.value ?? const <TrackerRecord>[]).firstOrNull;

/// Saved preferences. Edits show instantly and are written a moment later,
/// so dragging a slider doesn't write on every frame.
class SeasonalPrefsNotifier extends Notifier<SeasonalPrefs> {
  Timer? _debounce;
  SeasonalPrefs? _pending;

  @override
  SeasonalPrefs build() {
    ref.onDispose(() {
      _debounce?.cancel();
      _settle?.cancel();
    });
    final rec = _first(ref.watch(trackerKindProvider(TrackerKind.seasonPrefs)));
    final stored = rec == null
        ? const SeasonalPrefs()
        : SeasonalPrefs.fromJson(rec.fields);
    // A local edit wins until the database shows it: the stream can still
    // hand back the old record for a moment after a save, and taking that
    // would flip a switch back (e.g. Reduced motion turning itself on).
    final p = _pending;
    if (p != null) {
      if (_written == p && _sameJson(stored.toJson(), p.toJson())) {
        _pending = null;
        _written = null;
        return stored;
      }
      return p;
    }
    return stored;
  }

  /// The edit most recently written, waiting to come back from the database.
  SeasonalPrefs? _written;
  Timer? _settle;

  static bool _sameJson(Map<String, Object?> a, Map<String, Object?> b) =>
      jsonEncode(a) == jsonEncode(b);

  /// Applies [change] to the current preferences.
  void update(SeasonalPrefs Function(SeasonalPrefs p) change) {
    final next = change(state);
    _pending = next;
    state = next;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), flush);
  }

  /// Writes any pending change now.
  Future<void> flush() async {
    _debounce?.cancel();
    final p = _pending;
    if (p == null) return;
    final t = ref.read(trackerNotifierProvider.notifier);
    final rec = _first(ref.read(trackerKindProvider(TrackerKind.seasonPrefs)));
    if (rec == null) {
      await t.create(
        kind: TrackerKind.seasonPrefs,
        title: 'Seasonal preferences',
        fields: p.toJson(),
      );
    } else {
      await t.save(rec.replacingFields(p.toJson()));
    }
    // Keep showing [p] until the stored record matches it (see build).
    if (identical(_pending, p)) {
      _written = p;
      // If the stored copy never compares equal (a rounding difference, say),
      // stop holding the local copy once the write has certainly landed.
      _settle?.cancel();
      _settle = Timer(const Duration(seconds: 3), () {
        if (identical(_written, p) && identical(_pending, p)) {
          _pending = null;
          _written = null;
          ref.invalidateSelf();
        }
      });
    }
  }
}

final seasonalPrefsProvider =
    NotifierProvider<SeasonalPrefsNotifier, SeasonalPrefs>(
      SeasonalPrefsNotifier.new,
    );

/// The look showing today, if any.
final activeSeasonProvider = Provider<ActiveSeason?>((ref) {
  final p = ref.watch(seasonalPrefsProvider);
  // Off means nothing shows, so don't keep a clock running at all.
  if (p.performance == DecoPerformance.off) return null;
  final now = ref.watch(seasonalClockProvider).value ?? DateTime.now();
  return resolveActiveSeason(now, p);
});

/// Saved arrangements.
final decorPresetsProvider = Provider<List<DecorPreset>>((ref) {
  final recs =
      ref.watch(trackerKindProvider(TrackerKind.seasonPreset)).value ??
      const <TrackerRecord>[];
  final list = <DecorPreset>[];
  for (final r in recs) {
    final p = DecorPreset.fromJson({...r.fields, 'id': r.id});
    if (p != null) list.add(p);
  }
  list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return list;
});

class DecorPresetActions {
  DecorPresetActions(this.ref);
  final Ref ref;

  TrackerNotifier get _t => ref.read(trackerNotifierProvider.notifier);

  /// Saves a new preset and returns its id.
  Future<String> create(DecorPreset p) async {
    final r = await _t.create(
      kind: TrackerKind.seasonPreset,
      title: p.name,
      fields: p.toJson(),
    );
    return r.id;
  }

  Future<void> update(DecorPreset p) async {
    final rec =
        (ref.read(trackerKindProvider(TrackerKind.seasonPreset)).value ??
                const <TrackerRecord>[])
            .where((r) => r.id == p.id)
            .firstOrNull;
    if (rec == null) {
      await create(p);
      return;
    }
    await _t.save(rec.copyWith(title: p.name).replacingFields(p.toJson()));
  }

  Future<void> delete(String id) async {
    await _t.delete(id);
    final prefs = ref.read(seasonalPrefsProvider);
    // Nothing should keep pointing at a preset that's gone.
    ref
        .read(seasonalPrefsProvider.notifier)
        .update(
          (p) => p.copyWith(
            activePresetId: p.activePresetId == id ? null : p.activePresetId,
            alterPresets: {
              for (final e in prefs.alterPresets.entries)
                if (e.value != id) e.key: e.value,
            },
            subsystemPresets: {
              for (final e in prefs.subsystemPresets.entries)
                if (e.value != id) e.key: e.value,
            },
            pagePresets: {
              for (final e in prefs.pagePresets.entries)
                if (e.value != id) e.key: e.value,
            },
          ),
        );
  }

  Future<String> duplicate(DecorPreset p) => create(
    DecorPreset(
      id: '',
      name: '${p.name} (copy)',
      description: p.description,
      category: p.category,
      items: [
        for (final i in p.items)
          i.copy(
              newId:
                  '${i.id}-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
            )
            ..x = i.x
            ..y = i.y,
      ],
      layers: p.layers,
      thumbnail: p.thumbnail,
      pages: p.pages,
      room: p.room,
    ),
  );
}

final decorPresetActionsProvider = Provider<DecorPresetActions>(
  DecorPresetActions.new,
);

// ── Sharing ────────────────────────────────────────────────────────────

/// A preset as shareable text. Pictures the person imported can't travel
/// (they live on this device), so items using one are left out and counted.
({String json, int skipped}) exportPreset(DecorPreset p) {
  final kept = [
    for (final i in p.items)
      if (i.image == null) i,
  ];
  final copy = DecorPreset(
    id: p.id,
    name: p.name,
    description: p.description,
    category: p.category,
    items: kept,
    layers: p.layers,
    thumbnail: p.thumbnail,
    pages: p.pages,
    room: p.room,
  );
  return (
    json: const JsonEncoder.withIndent(
      '  ',
    ).convert({'prismDecor': 1, 'preset': copy.toJson()}),
    skipped: p.items.length - kept.length,
  );
}

/// Reads a shared preset. Only recognised, bounded data is accepted; nothing
/// in the text is ever executed.
DecorPreset? importPreset(String text) {
  if (text.length > 2 * 1024 * 1024) return null;
  try {
    final o = jsonDecode(text);
    if (o is! Map || o['prismDecor'] is! num) return null;
    final p = DecorPreset.fromJson(o['preset']);
    if (p == null || p.items.length > 400) return null;
    // A fresh id so it can never overwrite one you already have.
    return DecorPreset(
      id: '',
      name: p.name.length > 80 ? p.name.substring(0, 80) : p.name,
      description: p.description.length > 400
          ? p.description.substring(0, 400)
          : p.description,
      category: p.category,
      items: [
        for (final i in p.items)
          if (i.image == null) i,
      ],
      layers: p.layers,
      thumbnail: (p.thumbnail?.length ?? 0) > 200000 ? null : p.thumbnail,
      pages: p.pages,
      room: p.room,
    );
  } catch (_) {
    return null;
  }
}

// ── What's on screen ───────────────────────────────────────────────────

/// The arrangement (or Digital Room) showing now, by priority: the one for
/// whoever is fronting, then their subsystem's, then the one used everywhere.
/// This is how decoration profiles inherit: anything unassigned falls back
/// to the system's choice.
final frontPresetProvider = Provider<DecorPreset?>((ref) {
  final prefs = ref.watch(seasonalPrefsProvider);
  if (prefs.performance == DecoPerformance.off) return null;
  final presets = ref.watch(decorPresetsProvider);
  DecorPreset? byId(String? id) =>
      id == null ? null : presets.where((p) => p.id == id).firstOrNull;
  if (prefs.alterPresets.isNotEmpty || prefs.subsystemPresets.isNotEmpty) {
    final fronters = ref.watch(currentFronterMemberIdsProvider);
    for (final f in fronters) {
      final p = byId(prefs.alterPresets[f]);
      if (p != null) return p;
    }
    if (prefs.subsystemPresets.isNotEmpty) {
      final memberships = ref.watch(subMembershipsProvider);
      for (final f in fronters) {
        for (final m in memberships) {
          if (m.memberId != f) continue;
          final p = byId(prefs.subsystemPresets[m.subsystemId]);
          if (p != null) return p;
        }
      }
    }
  }
  return byId(prefs.activePresetId);
});

/// The Digital Room showing now, if the current arrangement is one.
final activeRoomProvider = Provider<RoomSettings?>(
  (ref) => ref.watch(frontPresetProvider)?.room,
);

/// Environment settings in effect: the room's if it has its own.
final effectiveEnvProvider = Provider<EnvSettings>((ref) {
  final room = ref.watch(activeRoomProvider);
  return room?.env ?? ref.watch(seasonalPrefsProvider.select((p) => p.env));
});

/// The decorations to draw: the person's own arrangement (their chosen
/// preset, or the one for whoever is fronting, plus any per-page ones) and,
/// only when a look is active, that look's decorations on top. Nothing here
/// ever touches the theme, background or fonts.
final seasonalItemsProvider = Provider<List<DecorItem>>((ref) {
  final prefs = ref.watch(seasonalPrefsProvider);
  if (prefs.performance == DecoPerformance.off) return const [];
  final presets = ref.watch(decorPresetsProvider);
  DecorPreset? byId(String? id) =>
      id == null ? null : presets.where((p) => p.id == id).firstOrNull;

  final items = <DecorItem>[];
  final own = ref.watch(frontPresetProvider);
  if (own != null) items.addAll(own.items);
  for (final e in prefs.pagePresets.entries) {
    final p = byId(e.value);
    if (p == null) continue;
    for (final i in p.items) {
      items.add(
        DecorItem.fromJson({
          ...i.toJson(),
          'id': 'pg-${e.key}-${i.id}',
          'pg': [e.key],
        })!,
      );
    }
  }
  // A living look is its own layer: it stays whatever season it is. A room
  // can bring its own; otherwise the system's applies.
  final room = own?.room;
  final livingId = room?.living ?? prefs.livingVariation;
  final living = livingId == null ? null : variationById(livingId);
  if (living != null) items.addAll(arrangementForVariation(living));
  final layoutId = room?.layout ?? prefs.layoutVariation;
  final layout = layoutId == null ? null : variationById(layoutId);
  if (layout != null) {
    items.addAll(
      layoutOverlayItems(
        layout,
        (room?.layout != null ? room?.layoutParts : prefs.layoutParts) ??
            LayoutPart.all.toSet(),
      ),
    );
  }
  items.addAll(ref.watch(environmentItemsProvider));
  final active = ref.watch(activeSeasonProvider);
  if (active != null && prefs.integrationOn('overlay')) {
    final v = active.variation;
    final preset = active.celebration?.presetId == null
        ? null
        : byId(active.celebration!.presetId);
    if (preset != null) items.addAll(preset.items);
    if (v != null) items.addAll(arrangementForVariation(v));
  }
  return items;
});

// ── Environment ────────────────────────────────────────────────────────

/// Whether anything follows the time of day, so the phase clock only runs
/// when it's needed.
final _needsPhaseProvider = Provider<bool>((ref) {
  final prefs = ref.watch(seasonalPrefsProvider);
  if (prefs.performance == DecoPerformance.off) return false;
  final env = ref.watch(effectiveEnvProvider);
  if (env.phases || env.fireflies || env.birds) return true;
  // A look or preset item limited to certain phases also needs the clock.
  final presets = ref.watch(decorPresetsProvider);
  return presets.any((p) => p.items.any((i) => i.phases.isNotEmpty));
});

/// The current time phase name, or null when nothing follows the clock.
final currentPhaseProvider = Provider<TimePhase?>((ref) {
  if (!ref.watch(_needsPhaseProvider)) return null;
  // A room can keep its own fixed lighting.
  final lit = ref.watch(activeRoomProvider)?.lighting;
  if (lit != null) {
    return TimePhase.values.where((p) => p.name == lit).firstOrNull;
  }
  return ref.watch(livingPhaseProvider).value ?? timePhaseOf(DateTime.now());
});

/// Music is playing in Prism's own player and decorations may react.
final decorMusicProvider = Provider<bool>((ref) {
  final env = ref.watch(effectiveEnvProvider);
  if (!env.music) return false;
  return ref.watch(musicControllerProvider.select((s) => s.playing));
});

/// The weather showing now, if any.
final currentWeatherProvider = Provider<WeatherKind?>((ref) {
  final prefs = ref.watch(seasonalPrefsProvider);
  if (prefs.performance == DecoPerformance.off) return null;
  final env = ref.watch(effectiveEnvProvider);
  WeatherKind? live;
  if (env.mode == WeatherMode.live && env.hasPlace) {
    live = ref.watch(liveWeatherProvider((env.lat!, env.lon!))).value;
  }
  return effectiveWeather(env, live);
});

final environmentItemsProvider = Provider<List<DecorItem>>((ref) {
  final env = ref.watch(effectiveEnvProvider);
  if (!env.any) return const [];
  return environmentItems(
    env,
    phase: ref.watch(currentPhaseProvider) ?? timePhaseOf(DateTime.now()),
    weather: ref.watch(currentWeatherProvider),
    musicPlaying: ref.watch(decorMusicProvider),
  );
});

// ── Theme sharing ──────────────────────────────────────────────────────

/// Adds a decoration arrangement to an exported theme, so sharing a theme
/// can optionally carry the decorations too.
String attachDecorToThemeExport(String themeJson, DecorPreset preset) {
  try {
    final o = jsonDecode(themeJson);
    if (o is! Map) return themeJson;
    final bundle = exportPreset(preset);
    return const JsonEncoder.withIndent(
      '  ',
    ).convert({...o, 'decor': jsonDecode(bundle.json)});
  } catch (_) {
    return themeJson;
  }
}

/// The decorations bundled in a shared theme, if any. Importing these only
/// ever adds a preset; it never changes the base theme or applies itself.
DecorPreset? extractDecorFromThemeImport(String text) {
  try {
    final o = jsonDecode(text);
    if (o is! Map || o['decor'] == null) return null;
    return importPreset(jsonEncode(o['decor']));
  } catch (_) {
    return null;
  }
}

// ── Layers in effect ───────────────────────────────────────────────────

/// The living look showing now: the active room's own, else the system's.
final effectiveLivingProvider = Provider<String?>((ref) {
  final room = ref.watch(activeRoomProvider);
  return room?.living ?? ref.watch(seasonalPrefsProvider).livingVariation;
});

/// The layout look showing now and its parts (null parts = all).
final effectiveLayoutProvider = Provider<(String?, Set<String>?)>((ref) {
  final room = ref.watch(activeRoomProvider);
  if (room?.layout != null) return (room!.layout, room.layoutParts);
  final p = ref.watch(seasonalPrefsProvider);
  return (p.layoutVariation, p.layoutParts);
});

/// Changes a decoration layer where it really comes from. A Digital Room
/// with its own living look, layout or environment overrides the system's,
/// so changing only the system's value would look like nothing happened
/// (and a "removed" look would keep showing). Edits go to the room when the
/// room has its own value, otherwise to the system settings.
class DecorLayers {
  DecorLayers(this.ref);
  final Ref ref;

  SeasonalPrefsNotifier get _prefs => ref.read(seasonalPrefsProvider.notifier);

  DecorPreset? get _room {
    final p = ref.read(frontPresetProvider);
    return p?.room == null ? null : p;
  }

  Future<void> _saveRoom(DecorPreset p, RoomSettings r) async {
    final copy = DecorPreset.fromJson(p.toJson())!..room = r;
    await ref.read(decorPresetActionsProvider).update(copy);
  }

  void _wake(bool on) {
    if (!on) return;
    _prefs.update(
      (p) => p.performance == DecoPerformance.off
          ? p.copyWith(performance: DecoPerformance.balanced)
          : p,
    );
  }

  /// Shows [id] as the living look, or turns living decorations off.
  Future<void> setLiving(String? id) async {
    final room = _room;
    if (id == null) {
      // Off means off everywhere it could come from.
      _prefs.update((p) => p.copyWith(livingVariation: null));
      if (room?.room?.living != null) {
        await _saveRoom(room!, room.room!.copyWith(living: null));
      }
      return;
    }
    _wake(true);
    if (room?.room?.living != null) {
      await _saveRoom(room!, room.room!.copyWith(living: id));
    } else {
      _prefs.update((p) => p.copyWith(livingVariation: id));
    }
  }

  Future<void> setLayout(String? id) async {
    final room = _room;
    if (id == null) {
      _prefs.update((p) => p.copyWith(layoutVariation: null));
      if (room?.room?.layout != null) {
        await _saveRoom(room!, room.room!.copyWith(layout: null));
      }
      return;
    }
    _wake(true);
    if (room?.room?.layout != null) {
      await _saveRoom(room!, room.room!.copyWith(layout: id));
    } else {
      _prefs.update((p) => p.copyWith(layoutVariation: id));
    }
  }

  Future<void> setLayoutParts(Set<String> parts) async {
    final room = _room;
    if (room?.room?.layout != null) {
      await _saveRoom(room!, room.room!.copyWith(layoutParts: parts));
    } else {
      _prefs.update((p) => p.copyWith(layoutParts: parts));
    }
  }

  /// Edits the environment in effect (the room's own, if it has one).
  Future<void> setEnv(EnvSettings Function(EnvSettings e) change) async {
    final room = _room;
    final env = room?.room?.env;
    if (env != null) {
      final next = change(env);
      _wake(next.any);
      await _saveRoom(room!, room.room!.copyWith(env: next));
    } else {
      final next = change(ref.read(seasonalPrefsProvider).env);
      _prefs.update(
        (p) => p.copyWith(
          env: next,
          performance: next.any && p.performance == DecoPerformance.off
              ? DecoPerformance.balanced
              : p.performance,
        ),
      );
    }
  }

  /// Turns environmental effects off wherever they come from.
  Future<void> clearEnv() async {
    _prefs.update((p) => p.copyWith(env: const EnvSettings()));
    final room = _room;
    if (room?.room?.env != null) {
      await _saveRoom(room!, room.room!.copyWith(env: null));
    }
  }
}

final decorLayersProvider = Provider<DecorLayers>(DecorLayers.new);
