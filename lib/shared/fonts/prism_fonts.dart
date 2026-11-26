import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:prism_plurality/shared/fonts/font_catalog.dart';
import 'package:prism_plurality/shared/fonts/font_prefs.dart';

/// Font keys used across Prism:
///  * `g:<Family>` – a catalogue font (loaded on demand, cached offline)
///  * `imp:<id>`   – a font file the person imported
///  * anything else – a legacy built-in key (`hand`, `serif`, …) that the
///    owning feature resolves itself.
abstract final class PrismFonts {
  static const _uuid = Uuid();
  static final _loaded = <String>{};
  static final _loading = <String, Future<bool>>{};
  static final _importedFamilies = <String, String>{};
  static List<ImportedFont> _registry = const [];

  /// Kept in sync with the saved choices so any widget can use an imported
  /// font by key without having the list passed in.
  static void registerImported(List<ImportedFont> fonts) => _registry = fonts;

  /// Bumped every time a font finishes loading, so themes and previews
  /// rebuild exactly once the glyphs are really available.
  static final ValueNotifier<int> loadTick = ValueNotifier(0);

  static bool isCatalog(String? key) => key != null && key.startsWith('g:');
  static bool isImported(String? key) => key != null && key.startsWith('imp:');
  static String familyOf(String key) => key.substring(2);

  static bool isLoaded(String? key) => key != null && _loaded.contains(key);

  /// Flutter family name of an imported font.
  static String importedFamily(String id) => 'PrismImp_$id';

  /// Loads [key] if needed. Completes true when it is ready to draw, false
  /// if it couldn't be fetched (offline and not cached yet); the UI keeps
  /// the fallback font in that case.
  static Future<bool> ensureLoaded(
    String? key, {
    List<ImportedFont> imported = const [],
  }) {
    if (key == null) return Future.value(true);
    if (!isCatalog(key) && !isImported(key)) return Future.value(true);
    if (_loaded.contains(key)) return Future.value(true);
    return _loading[key] ??= _load(
      key,
      imported,
    ).whenComplete(() => _loading.remove(key));
  }

  static Future<bool> _load(String key, List<ImportedFont> imported) async {
    try {
      if (isCatalog(key)) {
        await GoogleFonts.pendingFonts([GoogleFonts.getFont(familyOf(key))]);
      } else {
        final id = familyOf(key);
        final f = [
          ...imported,
          ..._registry,
        ].where((i) => i.id == id).firstOrNull;
        if (f == null) return false;
        final bytes = await File(f.file).readAsBytes();
        final loader = FontLoader(importedFamily(id))
          ..addFont(Future.value(ByteData.sublistView(bytes)));
        await loader.load();
        _importedFamilies[id] = importedFamily(id);
      }
      _loaded.add(key);
      loadTick.value++;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// A style in the font for [key], layered on [base]. Falls back to [base]
  /// until the font is ready; call [ensureLoaded] to get it loading.
  static TextStyle style(String? key, [TextStyle? base]) {
    final b = base ?? const TextStyle();
    if (isCatalog(key)) {
      try {
        return GoogleFonts.getFont(familyOf(key!), textStyle: b);
      } catch (_) {
        return b;
      }
    }
    if (isImported(key)) {
      // Draw with the family straight away; text falls back until the file
      // finishes loading, then re-lays out on its own.
      unawaited(ensureLoaded(key));
      return b.copyWith(fontFamily: importedFamily(familyOf(key!)));
    }
    return b;
  }

  /// Drops decorative fonts when the accessibility override is on.
  static String? resolve(String? key, FontPrefs prefs) {
    if (key == null) return null;
    if (prefs.plainOverride && isCatalog(key)) {
      final f = fontByFamily(familyOf(key));
      if (f != null && f.decorative) return null;
    }
    return key;
  }

  /// Applies the person's font choices to a theme: whole-app font first,
  /// then heading and body overrides, then weight / spacing / height / size.
  static ThemeData applyTheme(ThemeData theme, FontPrefs prefs) {
    if (prefs.isDefault) return theme;
    var tt = theme.textTheme;
    final global = prefs.of(FontSurface.global);
    final heading = prefs.of(FontSurface.heading);
    final body = prefs.of(FontSurface.body);

    TextStyle? tweak(
      TextStyle? s,
      SurfaceFont a,
      SurfaceFont b,
      String? familyKey,
    ) {
      if (s == null) return null;
      var out = s;
      final key = resolve(familyKey, prefs);
      if (key != null && (isLoaded(key) || false)) out = style(key, out);
      final weight = b.weight ?? a.weight;
      if (weight != null)
        out = out.copyWith(
          fontWeight: FontWeight.values[(weight ~/ 100 - 1).clamp(0, 8)],
        );
      final ls = a.letterSpacing + b.letterSpacing;
      if (ls != 0)
        out = out.copyWith(letterSpacing: (out.letterSpacing ?? 0) + ls);
      final lh = b.lineHeight != 0 ? b.lineHeight : a.lineHeight;
      if (lh != 0) out = out.copyWith(height: lh);
      final scale = a.size * b.size;
      if (scale != 1 && out.fontSize != null)
        out = out.copyWith(fontSize: out.fontSize! * scale);
      return out;
    }

    final headingKey = heading.family ?? global.family;
    final bodyKey = body.family ?? global.family;
    tt = tt.copyWith(
      displayLarge: tweak(tt.displayLarge, global, heading, headingKey),
      displayMedium: tweak(tt.displayMedium, global, heading, headingKey),
      displaySmall: tweak(tt.displaySmall, global, heading, headingKey),
      headlineLarge: tweak(tt.headlineLarge, global, heading, headingKey),
      headlineMedium: tweak(tt.headlineMedium, global, heading, headingKey),
      headlineSmall: tweak(tt.headlineSmall, global, heading, headingKey),
      titleLarge: tweak(tt.titleLarge, global, heading, headingKey),
      titleMedium: tweak(tt.titleMedium, global, body, bodyKey),
      titleSmall: tweak(tt.titleSmall, global, body, bodyKey),
      bodyLarge: tweak(tt.bodyLarge, global, body, bodyKey),
      bodyMedium: tweak(tt.bodyMedium, global, body, bodyKey),
      bodySmall: tweak(tt.bodySmall, global, body, bodyKey),
      labelLarge: tweak(tt.labelLarge, global, body, bodyKey),
      labelMedium: tweak(tt.labelMedium, global, body, bodyKey),
      labelSmall: tweak(tt.labelSmall, global, body, bodyKey),
    );
    return theme.copyWith(textTheme: tt);
  }

  /// The text theme for one surface (profiles, journal, nav…), on top of
  /// the current theme.
  static TextTheme surfaceTextTheme(
    TextTheme base,
    FontPrefs prefs,
    FontSurface surface,
  ) {
    final s = prefs.of(surface);
    if (s.isDefault) return base;
    final key = resolve(s.family, prefs);
    TextStyle? t(TextStyle? x) {
      if (x == null) return null;
      var out = x;
      if (key != null && isLoaded(key)) out = style(key, out);
      if (s.weight != null)
        out = out.copyWith(
          fontWeight: FontWeight.values[(s.weight! ~/ 100 - 1).clamp(0, 8)],
        );
      if (s.letterSpacing != 0)
        out = out.copyWith(
          letterSpacing: (out.letterSpacing ?? 0) + s.letterSpacing,
        );
      if (s.lineHeight != 0) out = out.copyWith(height: s.lineHeight);
      if (s.size != 1 && out.fontSize != null)
        out = out.copyWith(fontSize: out.fontSize! * s.size);
      return out;
    }

    return base.copyWith(
      displayLarge: t(base.displayLarge),
      displayMedium: t(base.displayMedium),
      displaySmall: t(base.displaySmall),
      headlineLarge: t(base.headlineLarge),
      headlineMedium: t(base.headlineMedium),
      headlineSmall: t(base.headlineSmall),
      titleLarge: t(base.titleLarge),
      titleMedium: t(base.titleMedium),
      titleSmall: t(base.titleSmall),
      bodyLarge: t(base.bodyLarge),
      bodyMedium: t(base.bodyMedium),
      bodySmall: t(base.bodySmall),
      labelLarge: t(base.labelLarge),
      labelMedium: t(base.labelMedium),
      labelSmall: t(base.labelSmall),
    );
  }

  // ── Importing ──────────────────────────────────────────────────────

  static Future<Directory?> _dir() async {
    if (kIsWeb) return null;
    final d = Directory(
      p.join((await getApplicationSupportDirectory()).path, 'prism_fonts'),
    );
    await d.create(recursive: true);
    return d;
  }

  /// Result of an import attempt: a font, or a plain-language reason.
  static Future<({ImportedFont? font, String? error})> importFile(
    String path, {
    String? displayName,
  }) async {
    final ext = p.extension(path).toLowerCase();
    if (ext == '.woff2' || ext == '.woff') {
      return (
        font: null,
        error:
            'WOFF fonts can\'t be used here. Convert it to TTF or OTF first.',
      );
    }
    if (ext != '.ttf' && ext != '.otf') {
      return (font: null, error: 'Choose a TTF or OTF font file.');
    }
    final src = File(path);
    if (kIsWeb || !await src.exists()) {
      return (
        font: null,
        error: kIsWeb
            ? 'Importing fonts isn\'t supported in the browser.'
            : 'That file couldn\'t be read.',
      );
    }
    final len = await src.length();
    if (len > 20 * 1024 * 1024) {
      return (font: null, error: 'That font is too large (20 MB max).');
    }
    final bytes = await src.readAsBytes();
    if (!looksLikeFont(bytes)) {
      return (font: null, error: 'That doesn\'t look like a valid font file.');
    }
    final Directory? dir;
    try {
      dir = await _dir();
    } catch (_) {
      return (
        font: null,
        error: 'Prism couldn\'t store that font on this device.',
      );
    }
    if (dir == null) {
      return (
        font: null,
        error: 'Importing fonts isn\'t supported in the browser.',
      );
    }
    final id = _uuid.v4().substring(0, 8);
    final dest = File(p.join(dir.path, '$id$ext'));
    await dest.writeAsBytes(bytes, flush: true);
    final name = (displayName ?? p.basenameWithoutExtension(path)).trim();
    final font = ImportedFont(id, name.isEmpty ? id : name, dest.path);
    // Prove it loads before keeping it.
    try {
      final loader = FontLoader(importedFamily(id))
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    } catch (_) {
      await dest.delete();
      return (font: null, error: 'That font file couldn\'t be loaded.');
    }
    return (font: font, error: null);
  }

  /// TrueType (0x00010000 / `true`), OpenType (`OTTO`) or a collection.
  static bool looksLikeFont(Uint8List b) {
    if (b.length < 12) return false;
    final tag = String.fromCharCodes(b.sublist(0, 4));
    return (b[0] == 0 && b[1] == 1 && b[2] == 0 && b[3] == 0) ||
        tag == 'true' ||
        tag == 'OTTO' ||
        tag == 'ttcf';
  }

  static Future<void> deleteImportedFile(ImportedFont f) async {
    try {
      final file = File(f.file);
      if (await file.exists()) await file.delete();
    } catch (_) {}
    _loaded.remove(f.key);
  }
}

/// Re-themes everything below it for one surface of the app (profiles,
/// journal, navigation…). Cheap: it only wraps a `Theme` when the person
/// actually chose something for that surface.
class FontSurfaceScope extends ConsumerWidget {
  const FontSurfaceScope({
    super.key,
    required this.surface,
    required this.child,
  });
  final FontSurface surface;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(fontPrefsProvider);
    final s = prefs.of(surface);
    if (s.isDefault) return child;
    final key = PrismFonts.resolve(s.family, prefs);
    // Make sure the font loads, then rebuild when it lands.
    if (key != null && !PrismFonts.isLoaded(key)) {
      PrismFonts.ensureLoaded(key, imported: prefs.imported);
    }
    return ValueListenableBuilder<int>(
      valueListenable: PrismFonts.loadTick,
      builder: (context, _, _) {
        final theme = Theme.of(context);
        final tt = PrismFonts.surfaceTextTheme(theme.textTheme, prefs, surface);
        return Theme(
          data: theme.copyWith(textTheme: tt),
          child: DefaultTextStyle.merge(style: tt.bodyMedium, child: child),
        );
      },
    );
  }
}

/// Rebuilds watchers whenever any font finishes loading.
final fontLoadTickProvider = Provider<int>((ref) {
  void listener() => ref.invalidateSelf();
  PrismFonts.loadTick.addListener(listener);
  ref.onDispose(() => PrismFonts.loadTick.removeListener(listener));
  return PrismFonts.loadTick.value;
});

/// Starts loading every font the current choices need (only those).
void warmFontPrefs(FontPrefs prefs) {
  for (final s in FontSurface.values) {
    final key = PrismFonts.resolve(prefs.of(s).family, prefs);
    if (key != null && !PrismFonts.isLoaded(key)) {
      unawaited(PrismFonts.ensureLoaded(key, imported: prefs.imported));
    }
  }
}
