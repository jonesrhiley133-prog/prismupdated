import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:prism_plurality/shared/fonts/prism_fonts.dart';

/// Places in Prism where a person can pick a different font.
enum FontSurface {
  global('Whole app', 'Toda la app'),
  heading('Headings', 'Títulos'),
  body('Body text', 'Texto'),
  navigation('Navigation', 'Navegación'),
  profile('Alter profiles', 'Perfiles'),
  bio('Biographies', 'Biografías'),
  scrapbook('Scrapbooks', 'Álbumes'),
  idCard('ID cards', 'Tarjetas de ID'),
  journal('Journal', 'Diario'),
  widget('Widgets', 'Widgets');

  const FontSurface(this.en, this.es);
  final String en, es;
}

/// One surface's typography. A null [family] inherits from the whole-app
/// choice; a null [weight] keeps the font's normal weight.
@immutable
class SurfaceFont {
  const SurfaceFont({
    this.family,
    this.weight,
    this.letterSpacing = 0,
    this.lineHeight = 0,
    this.size = 1,
  });

  /// `g:<Google family>`, `imp:<id>` for an imported file, or null.
  final String? family;

  /// 100–900, or null for the font's own default.
  final int? weight;

  /// Extra letter spacing in logical pixels (−2…+6).
  final double letterSpacing;

  /// Line-height multiplier; 0 keeps the default.
  final double lineHeight;

  /// Size multiplier (0.7…1.8).
  final double size;

  bool get isDefault =>
      family == null &&
      weight == null &&
      letterSpacing == 0 &&
      lineHeight == 0 &&
      size == 1;

  SurfaceFont copyWith({
    Object? family = _keep,
    Object? weight = _keep,
    double? letterSpacing,
    double? lineHeight,
    double? size,
  }) => SurfaceFont(
    family: identical(family, _keep) ? this.family : family as String?,
    weight: identical(weight, _keep) ? this.weight : weight as int?,
    letterSpacing: letterSpacing ?? this.letterSpacing,
    lineHeight: lineHeight ?? this.lineHeight,
    size: size ?? this.size,
  );

  static const _keep = Object();

  Map<String, Object?> toJson() => {
    'f': ?family,
    'w': ?weight,
    if (letterSpacing != 0) 'ls': letterSpacing,
    if (lineHeight != 0) 'lh': lineHeight,
    if (size != 1) 's': size,
  };

  static SurfaceFont fromJson(Object? o) {
    if (o is! Map) return const SurfaceFont();
    double d(String k, double def) => (o[k] as num?)?.toDouble() ?? def;
    return SurfaceFont(
      family: o['f'] as String?,
      weight: ((o['w'] as num?)?.toInt())?.clamp(100, 900),
      letterSpacing: d('ls', 0).clamp(-2.0, 6.0),
      lineHeight: d('lh', 0) == 0 ? 0 : d('lh', 0).clamp(0.8, 2.6),
      size: d('s', 1).clamp(0.7, 1.8),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SurfaceFont &&
      other.family == family &&
      other.weight == weight &&
      other.letterSpacing == letterSpacing &&
      other.lineHeight == lineHeight &&
      other.size == size;

  @override
  int get hashCode =>
      Object.hash(family, weight, letterSpacing, lineHeight, size);
}

/// A font file the user brought in.
@immutable
class ImportedFont {
  const ImportedFont(this.id, this.name, this.file);
  final String id, name, file;
  String get key => 'imp:$id';
  Map<String, Object?> toJson() => {'id': id, 'n': name, 'f': file};
  static ImportedFont? fromJson(Object? o) {
    if (o is! Map || o['id'] is! String || o['f'] is! String) return null;
    return ImportedFont(
      o['id'] as String,
      '${o['n'] ?? o['id']}',
      o['f'] as String,
    );
  }
}

@immutable
class FontPrefs {
  const FontPrefs({
    this.surfaces = const {},
    this.favorites = const [],
    this.recents = const [],
    this.imported = const [],
    this.plainOverride = false,
  });

  final Map<FontSurface, SurfaceFont> surfaces;
  final List<String> favorites;
  final List<String> recents;
  final List<ImportedFont> imported;

  /// Accessibility: ignore decorative fonts everywhere and use the plain,
  /// readable app font instead.
  final bool plainOverride;

  SurfaceFont of(FontSurface s) => surfaces[s] ?? const SurfaceFont();

  /// The family a surface really uses: its own, else the whole-app one.
  String? effectiveFamily(FontSurface s) =>
      of(s).family ??
      (s == FontSurface.global ? null : of(FontSurface.global).family);

  bool get isDefault =>
      surfaces.values.every((e) => e.isDefault) && !plainOverride;

  FontPrefs copyWith({
    Map<FontSurface, SurfaceFont>? surfaces,
    List<String>? favorites,
    List<String>? recents,
    List<ImportedFont>? imported,
    bool? plainOverride,
  }) => FontPrefs(
    surfaces: surfaces ?? this.surfaces,
    favorites: favorites ?? this.favorites,
    recents: recents ?? this.recents,
    imported: imported ?? this.imported,
    plainOverride: plainOverride ?? this.plainOverride,
  );

  Map<String, Object?> toJson() => {
    'v': 1,
    'surfaces': {
      for (final e in surfaces.entries)
        if (!e.value.isDefault) e.key.name: e.value.toJson(),
    },
    'fav': favorites,
    'rec': recents,
    'imp': [for (final i in imported) i.toJson()],
    if (plainOverride) 'plain': true,
  };

  static FontPrefs fromJson(Object? o) {
    if (o is! Map) return const FontPrefs();
    final s = <FontSurface, SurfaceFont>{};
    final raw = o['surfaces'];
    if (raw is Map) {
      for (final e in raw.entries) {
        final surface = FontSurface.values
            .where((x) => x.name == e.key)
            .firstOrNull;
        if (surface != null) s[surface] = SurfaceFont.fromJson(e.value);
      }
    }
    List<String> strs(Object? v) => [
      if (v is List)
        for (final x in v)
          if (x is String) x,
    ];
    return FontPrefs(
      surfaces: s,
      favorites: strs(o['fav']),
      recents: strs(o['rec']),
      imported: [
        if (o['imp'] is List)
          for (final x in o['imp'] as List) ?ImportedFont.fromJson(x),
      ],
      plainOverride: o['plain'] == true,
    );
  }
}

const _prefsKey = 'prism_fonts_v1';

/// Persisted font choices. Starts at the defaults and fills in as soon as
/// the saved value is read.
class FontPrefsNotifier extends Notifier<FontPrefs> {
  @override
  FontPrefs build() {
    _load();
    return const FontPrefs();
  }

  Future<void> _load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_prefsKey);
      if (raw != null) {
        state = FontPrefs.fromJson(jsonDecode(raw));
        PrismFonts.registerImported(state.imported);
      }
    } catch (_) {}
  }

  Future<void> _set(FontPrefs p) async {
    state = p;
    PrismFonts.registerImported(p.imported);
    try {
      await (await SharedPreferences.getInstance()).setString(
        _prefsKey,
        jsonEncode(p.toJson()),
      );
    } catch (_) {}
  }

  Future<void> setSurface(FontSurface s, SurfaceFont f) =>
      _set(state.copyWith(surfaces: {...state.surfaces, s: f}));

  /// Chooses [family] for [s] and remembers it in recents.
  Future<void> choose(FontSurface s, String? family) {
    final recents = family == null
        ? state.recents
        : [
            family,
            ...state.recents.where((r) => r != family),
          ].take(12).toList();
    return _set(
      state.copyWith(
        surfaces: {
          ...state.surfaces,
          s: state.of(s).copyWith(family: family),
        },
        recents: recents,
      ),
    );
  }

  Future<void> noteUsed(String family) => _set(
    state.copyWith(
      recents: [
        family,
        ...state.recents.where((r) => r != family),
      ].take(12).toList(),
    ),
  );

  Future<void> toggleFavorite(String family) => _set(
    state.copyWith(
      favorites: state.favorites.contains(family)
          ? state.favorites.where((f) => f != family).toList()
          : [...state.favorites, family],
    ),
  );

  Future<void> setPlain(bool v) => _set(state.copyWith(plainOverride: v));

  Future<void> addImported(ImportedFont f) =>
      _set(state.copyWith(imported: [...state.imported, f]));

  Future<void> removeImported(String id) => _set(
    state.copyWith(
      imported: state.imported.where((i) => i.id != id).toList(),
      surfaces: {
        for (final e in state.surfaces.entries)
          e.key: e.value.family == 'imp:$id'
              ? e.value.copyWith(family: null)
              : e.value,
      },
    ),
  );

  Future<void> resetAll() => _set(
    FontPrefs(
      favorites: state.favorites,
      recents: state.recents,
      imported: state.imported,
    ),
  );
}

final fontPrefsProvider = NotifierProvider<FontPrefsNotifier, FontPrefs>(
  FontPrefsNotifier.new,
);
