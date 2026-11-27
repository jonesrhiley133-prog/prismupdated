import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';

/// Favourites and recently used items for every appearance gallery. Keys
/// are namespaced: `genre:<id>`, `asset:<id>`, `bg:<id>`, `icon:<id>`…
@immutable
class AppearanceLibrary {
  const AppearanceLibrary({this.favorites = const {}, this.recents = const []});

  final Set<String> favorites;

  /// Newest first, at most [maxRecents].
  final List<String> recents;

  static const maxRecents = 60;

  bool isFavorite(String key) => favorites.contains(key);

  AppearanceLibrary toggleFavorite(String key) => AppearanceLibrary(
    favorites: favorites.contains(key)
        ? ({...favorites}..remove(key))
        : {...favorites, key},
    recents: recents,
  );

  AppearanceLibrary used(String key) => AppearanceLibrary(
    favorites: favorites,
    recents: [
      key,
      for (final r in recents)
        if (r != key) r,
    ].take(maxRecents).toList(),
  );

  /// Ids under [prefix] (`'asset:'` → asset ids), favourites in order added.
  List<String> favoritesIn(String prefix) => [
    for (final f in favorites)
      if (f.startsWith(prefix)) f.substring(prefix.length),
  ];

  List<String> recentsIn(String prefix) => [
    for (final r in recents)
      if (r.startsWith(prefix)) r.substring(prefix.length),
  ];

  Map<String, Object?> toJson() => {
    'v': 1,
    'fav': favorites.toList(),
    'rec': recents,
  };

  static AppearanceLibrary fromJson(Object? o) {
    if (o is! Map) return const AppearanceLibrary();
    List<String> strs(Object? x) => [
      if (x is List)
        for (final e in x)
          if (e is String && e.length < 200) e,
    ];
    return AppearanceLibrary(
      favorites: strs(o['fav']).toSet(),
      recents: strs(o['rec']).take(maxRecents).toList(),
    );
  }
}

class AppearanceLibraryNotifier extends Notifier<AppearanceLibrary> {
  Timer? _debounce;
  AppearanceLibrary? _pending;

  TrackerRecord? _rec(AsyncValue<List<TrackerRecord>> v) =>
      (v.value ?? const <TrackerRecord>[]).firstOrNull;

  @override
  AppearanceLibrary build() {
    ref.onDispose(() => _debounce?.cancel());
    final rec = _rec(
      ref.watch(trackerKindProvider(TrackerKind.appearanceLibrary)),
    );
    final stored = rec == null
        ? const AppearanceLibrary()
        : AppearanceLibrary.fromJson(rec.fields);
    final p = _pending;
    // A local change wins until the database hands it back.
    if (p != null) {
      if (jsonEncode(p.toJson()) == jsonEncode(stored.toJson())) {
        _pending = null;
        return stored;
      }
      return p;
    }
    return stored;
  }

  void update(AppearanceLibrary Function(AppearanceLibrary l) change) {
    final next = change(state);
    _pending = next;
    state = next;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), flush);
  }

  void toggleFavorite(String key) => update((l) => l.toggleFavorite(key));
  void used(String key) => update((l) => l.used(key));

  Future<void> flush() async {
    _debounce?.cancel();
    final p = _pending;
    if (p == null) return;
    final t = ref.read(trackerNotifierProvider.notifier);
    final rec = _rec(
      ref.read(trackerKindProvider(TrackerKind.appearanceLibrary)),
    );
    if (rec == null) {
      await t.create(
        kind: TrackerKind.appearanceLibrary,
        title: 'Appearance library',
        fields: p.toJson(),
      );
    } else {
      await t.save(rec.replacingFields(p.toJson()));
    }
  }
}

final appearanceLibraryProvider =
    NotifierProvider<AppearanceLibraryNotifier, AppearanceLibrary>(
      AppearanceLibraryNotifier.new,
    );

// ── Undo ───────────────────────────────────────────────────────────────

/// The last appearance change, so it can be taken back. Every gallery that
/// applies something (a living look, a background, an app icon…) records
/// what it replaced here; [AppearanceUndoBanner] offers to put it back.
@immutable
class AppearanceUndo {
  const AppearanceUndo(this.message, this.restore, {required this.at});
  final String message;
  final void Function() restore;
  final DateTime at;
}

class AppearanceUndoNotifier extends Notifier<AppearanceUndo?> {
  @override
  AppearanceUndo? build() => null;

  void record(String message, void Function() restore) =>
      state = AppearanceUndo(message, restore, at: DateTime.now());

  void clear() => state = null;

  /// Puts back whatever the last change replaced.
  void undo() {
    final u = state;
    state = null;
    u?.restore();
  }
}

final appearanceUndoProvider =
    NotifierProvider<AppearanceUndoNotifier, AppearanceUndo?>(
      AppearanceUndoNotifier.new,
    );
