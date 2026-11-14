import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/domain/models/system_settings.dart';
import 'package:prism_plurality/domain/preferences/preference_registry.dart';
import 'package:prism_plurality/features/appearance/models/look.dart';
import 'package:prism_plurality/features/appearance/services/synced_setting.dart';
import 'package:prism_plurality/features/settings/providers/settings_providers.dart';
import 'package:prism_plurality/shared/theme/prism_shapes.dart' as ui_shapes;

const _prefsKey = 'appearance.state.v1';
const appearanceSettingKind = 'settings.appearance';
const _uuid = Uuid();

/// Folder for uploaded background images (kept on this device).
final backgroundsDirProvider = FutureProvider<Directory?>((ref) async {
  if (kIsWeb) return null;
  final base = await getApplicationSupportDirectory();
  final dir = Directory(p.join(base.path, 'backgrounds'));
  await dir.create(recursive: true);
  return dir;
});

/// Shrinks a picked photo to screen size and re-encodes it as JPEG so
/// backgrounds stay small and quick to decode.
Uint8List? optimizeBackground(Uint8List bytes) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    return null;
  }
  if (decoded == null) return null;
  final oriented = img.bakeOrientation(decoded);
  const maxSide = 1600;
  final longest = oriented.width > oriented.height ? oriented.width : oriented.height;
  final resized = longest <= maxSide
      ? oriented
      : img.copyResize(
          oriented,
          width: oriented.width >= oriented.height ? maxSide : null,
          height: oriented.height > oriented.width ? maxSide : null,
          interpolation: img.Interpolation.average,
        );
  return img.encodeJpg(resized, quality: 84);
}

class AppearanceNotifier extends AsyncNotifier<AppearanceState> {
  @override
  Future<AppearanceState> build() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_prefsKey);
      return raw == null ? const AppearanceState() : AppearanceState.fromJson(jsonDecode(raw));
    } catch (_) {
      return const AppearanceState();
    }
  }

  Future<AppearanceState> _cur() async => state.value ?? await future;

  Future<void> _save(AppearanceState next, {bool touch = true}) async {
    final stamped = touch ? next.copyWith(modifiedAt: DateTime.now().millisecondsSinceEpoch) : next;
    state = AsyncData(stamped);
    try {
      await (await SharedPreferences.getInstance()).setString(_prefsKey, jsonEncode(stamped.toJson()));
    } catch (_) {
      // Kept in memory for this session.
    }
  }

  /// Puts the appearance back to how Prism looks out of the box: the plain
  /// Prism theme everywhere, no per-page themes or automatic light/dark
  /// switching, and — with [everything] — also removes saved themes and
  /// uploaded background images. Banner settings are not appearance and
  /// stay as they are.
  Future<void> resetAppearance({bool everything = false}) async {
    final s = await _cur();
    if (everything) {
      final dir = await ref.read(backgroundsDirProvider.future);
      if (dir != null) {
        try {
          for (final f in dir.listSync().whereType<File>()) {
            await f.delete();
          }
        } catch (_) {}
      }
    }
    await _save(
      AppearanceState(
        looks: everything ? const [] : s.looks,
        showMemberBanners: s.showMemberBanners,
        bannerPositions: s.bannerPositions,
      ),
    );
    // Theme style, accent, palette, corners and fonts back to defaults.
    // These go through the settings notifier so the startup theme cache is
    // refreshed too (no old theme flashing on the next launch).
    const d0 = SystemSettings();
    final settings = ref.read(settingsNotifierProvider.notifier);
    await settings.updateThemeBrightness(d0.themeBrightness);
    await settings.updateThemeStyle(d0.themeStyle);
    await settings.updateAccentColor(d0.accentColorHex);
    await settings.updateCornerStyle(ui_shapes.CornerStyle.rounded);
    await settings.updatePaletteSource(d0.paletteSource);
    await settings.updatePaletteSeedColorHex(d0.paletteSeedColorHex);
    await settings.updatePaletteMood(d0.paletteMood);
    await settings.updatePaletteContrast(d0.paletteContrast);
    final repo = ref.read(systemSettingsRepositoryProvider);
    final cur = await repo.getSettings();
    const d = SystemSettings();
    await repo.updateSettings(
      cur.copyWith(
        accentColorHex: d.accentColorHex,
        themeBrightness: d.themeBrightness,
        themeStyle: d.themeStyle,
        themeMode: d.themeMode,
        cornerStyle: d.cornerStyle,
        paletteSource: d.paletteSource,
        paletteSeedColorHex: d.paletteSeedColorHex,
        paletteMood: d.paletteMood,
        paletteContrast: d.paletteContrast,
        fontFamily: d.fontFamily,
        fontScale: d.fontScale,
        displayFontInAppBar: d.displayFontInAppBar,
      ),
    );
    await ref.read(appPreferenceRepositoryProvider).set(typographyLetterSpacingPreference, typographyLetterSpacingPreference.defaultValue);
  }

  /// Takes over newer settings that arrived from another device.
  Future<void> adoptRemote(Map<String, dynamic> json) => _save(AppearanceState.fromJson(json), touch: false);

  Future<void> setShowMemberBanners(bool v) async => _save((await _cur()).copyWith(showMemberBanners: v));

  Future<void> setBannerPosition(String memberId, double x, double y, double zoom) async {
    final s = await _cur();
    final next = Map<String, ({double x, double y, double zoom})>.of(s.bannerPositions);
    if (x == 0 && y == 0 && zoom == 1) {
      next.remove(memberId);
    } else {
      next[memberId] = (x: x, y: y, zoom: zoom);
    }
    await _save(s.copyWith(bannerPositions: next));
  }

  Future<void> activate(String id) async => _save((await _cur()).copyWith(activeId: id));

  Future<void> setAuto({bool? auto, String? lightId, String? darkId}) async =>
      _save((await _cur()).copyWith(auto: auto, lightId: lightId, darkId: darkId));

  Future<void> setPageLook(String page, String? lookId) async {
    final s = await _cur();
    final next = Map<String, String>.of(s.pageLooks);
    lookId == null ? next.remove(page) : next[page] = lookId;
    await _save(s.copyWith(pageLooks: next));
  }

  /// Adds or replaces one of the user's presets.
  Future<PrismLook> saveLook(PrismLook look) async {
    final s = await _cur();
    final mine = look.builtIn || look.id.isEmpty ? look.copyWith(id: _uuid.v4(), builtIn: false) : look;
    final exists = s.looks.any((l) => l.id == mine.id);
    await _save(s.copyWith(looks: exists ? [for (final l in s.looks) l.id == mine.id ? mine : l] : [...s.looks, mine]));
    return mine;
  }

  Future<PrismLook> duplicate(PrismLook look, String name) =>
      saveLook(PrismLook(id: _uuid.v4(), name: name, background: look.background, pageBackgrounds: look.pageBackgrounds, elements: look.elements, dark: look.dark));

  Future<void> rename(String id, String name) async {
    final s = await _cur();
    await _save(s.copyWith(looks: [for (final l in s.looks) l.id == id ? l.copyWith(name: name.trim()) : l]));
  }

  Future<void> deleteLook(String id) async {
    final s = await _cur();
    String keep(String x) => x == id ? 'prism' : x;
    await _save(
      s.copyWith(
        looks: [for (final l in s.looks) if (l.id != id) l],
        activeId: keep(s.activeId),
        lightId: keep(s.lightId),
        darkId: keep(s.darkId),
        pageLooks: {for (final e in s.pageLooks.entries) if (e.value != id) e.key: e.value},
      ),
    );
  }

  /// Text another user can import (pictures are not included).
  String export(PrismLook look) => const JsonEncoder.withIndent('  ').convert(look.toJson());

  /// Imports a theme shared as text. Returns null when it is not a Prism theme.
  Future<PrismLook?> import(String text) async {
    Object? j;
    try {
      j = jsonDecode(text.trim());
    } on FormatException {
      return null;
    }
    if (j is! Map || j['prismTheme'] == null) return null;
    final look = PrismLook.fromJson(j);
    if (look == null) return null;
    return saveLook(look.copyWith(id: _uuid.v4()));
  }

  /// Stores an optimised copy of a picked image; returns its file name.
  Future<String?> addBackgroundImage(Uint8List bytes) async {
    final dir = await ref.read(backgroundsDirProvider.future);
    if (dir == null) return null;
    final out = await compute(optimizeBackground, bytes);
    if (out == null) return null;
    final name = '${_uuid.v4()}.jpg';
    await File(p.join(dir.path, name)).writeAsBytes(out, flush: true);
    return name;
  }
}

final appearanceProvider = AsyncNotifierProvider<AppearanceNotifier, AppearanceState>(AppearanceNotifier.new);

/// A draft being edited in the studio: shown app-wide as a live preview
/// until it is saved or discarded.
class LookPreview extends Notifier<PrismLook?> {
  @override
  PrismLook? build() => null;
  void show(PrismLook? look) => state = look;
}

final lookPreviewProvider = NotifierProvider<LookPreview, PrismLook?>(LookPreview.new);

/// The preset in effect for the given brightness.
final activeLookProvider = Provider.family<PrismLook, bool>((ref, dark) {
  final preview = ref.watch(lookPreviewProvider);
  if (preview != null) return preview;
  return (ref.watch(appearanceProvider).value ?? const AppearanceState()).active(dark: dark);
});

/// A page's own preset, if it has one.
final appearancePageLookProvider = Provider.family<PrismLook?, String?>((ref, page) {
  if (ref.watch(lookPreviewProvider) != null) return null;
  return ref.watch(appearanceProvider).value?.pageLook(page);
});

/// Keep alive from the app root: syncs appearance settings across devices.
final appearanceSyncProvider = Provider<void>((ref) {
  bindSyncedSetting(
    ref,
    kind: appearanceSettingKind,
    local: () => ref.read(appearanceProvider).value?.toJson(),
    adopt: (j) => ref.read(appearanceProvider.notifier).adoptRemote(j),
    listenLocal: (cb) => ref.listen(appearanceProvider, (_, _) => cb()),
  );
});

/// Headmates display setting: banners on member cards.
final showMemberBannersProvider = Provider<bool>(
  (ref) => ref.watch(appearanceProvider.select((s) => s.value?.showMemberBanners ?? false)),
);

/// Banner crop per member for Headmates cards. Compared by value so the
/// list only rebuilds when a position actually changes.
@immutable
class BannerPositions {
  const BannerPositions(this.map);
  final Map<String, ({double x, double y, double zoom})> map;

  ({double x, double y, double zoom})? operator [](String id) => map[id];

  @override
  bool operator ==(Object other) => other is BannerPositions && mapEquals(other.map, map);

  @override
  int get hashCode => Object.hashAllUnordered(map.entries.map((e) => Object.hash(e.key, e.value)));
}

final memberBannerPositionsProvider = Provider<BannerPositions>(
  (ref) => BannerPositions(ref.watch(appearanceProvider.select((s) => s.value?.bannerPositions ?? const {}))),
);
