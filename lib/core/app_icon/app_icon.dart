import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:prism_plurality/core/app_icon/custom_icon.dart';
import 'package:prism_plurality/core/app_icon/icon_art.dart';
import 'package:prism_plurality/core/app_icon/icon_catalog.dart';
import 'package:prism_plurality/core/app_icon/favicon.dart';

/// One choosable app icon.
@immutable
class AppIconPreset {
  const AppIconPreset(
    this.id,
    this.en,
    this.es, {
    this.plural = false,
    this.art,
    this.group = 'classic',
  });
  final String id;
  final String en;
  final String es;

  /// Plurality-themed designs (shown in their own group).
  final bool plural;

  /// Designs from the icon gallery are drawn in code (no preview file).
  final IconArt? art;

  /// Gallery group ('classic', 'plural', or one of [iconArtGroups]).
  final String group;

  /// Preview image bundled with the app.
  String get asset => 'assets/app_icons/$id.png';
}

/// The icons people can pick (Settings › Appearance › App icon). Android
/// has a matching launcher alias for each id (see AndroidManifest.xml).
const appIconPresets = [
  AppIconPreset('classic', 'Classic', 'Clásico'),
  AppIconPreset('nebula', 'Nebula', 'Nebulosa'),
  AppIconPreset('aurora', 'Aurora', 'Aurora'),
  AppIconPreset('halo', 'Halo', 'Halo'),
  AppIconPreset('lunar', 'Lunar', 'Lunar'),
  AppIconPreset('ember', 'Ember', 'Brasa'),
  AppIconPreset('abyss', 'Abyss', 'Abismo'),
  AppIconPreset('bloom', 'Bloom', 'Flor'),
  AppIconPreset('void', 'Void', 'Vacío'),
  AppIconPreset('spectrum', 'Spectrum', 'Espectro'),
  AppIconPreset('frost', 'Frost', 'Escarcha'),
  AppIconPreset('twilight', 'Twilight', 'Crepúsculo'),
  AppIconPreset('verdant', 'Verdant', 'Verdor'),
  AppIconPreset('starlight', 'Starlight', 'Luz estelar'),
  AppIconPreset('solstice', 'Solstice', 'Solsticio'),
  AppIconPreset('eclipse', 'Eclipse', 'Eclipse'),
  AppIconPreset('opal', 'Opal', 'Ópalo'),
  AppIconPreset('obsidian', 'Obsidian', 'Obsidiana'),
  AppIconPreset('ultraviolet', 'Ultraviolet', 'Ultravioleta'),
  AppIconPreset('tide', 'Tide', 'Marea'),
  AppIconPreset('constellation', 'Constellation', 'Constelación', plural: true),
  AppIconPreset('facets', 'Facets', 'Facetas', plural: true),
  AppIconPreset('moons', 'Many Moons', 'Muchas lunas', plural: true),
  AppIconPreset('chrysalis', 'Chrysalis', 'Crisálida', plural: true),
  AppIconPreset('headspace', 'Headspace', 'Espacio interior', plural: true),
  AppIconPreset('harmony', 'Harmony', 'Armonía', plural: true),
  AppIconPreset('garden', 'Garden', 'Jardín', plural: true),
  AppIconPreset('reflection', 'Reflection', 'Reflejo', plural: true),
  AppIconPreset('murmuration', 'Murmuration', 'Bandada', plural: true),
  AppIconPreset('threads', 'Threads', 'Hilos', plural: true),
  AppIconPreset('lanterns', 'Lanterns', 'Faroles', plural: true),
  AppIconPreset('chorus', 'Chorus', 'Coro', plural: true),
];

List<AppIconPreset>? _all;

/// Every launcher icon: the original 32 plus the 60 gallery designs.
List<AppIconPreset> get allAppIconPresets => _all ??= [
  for (final p in appIconPresets)
    AppIconPreset(
      p.id,
      p.en,
      p.es,
      plural: p.plural,
      group: p.plural ? 'plural' : 'classic',
    ),
  for (final d in permanentIconDesigns)
    AppIconPreset(d.id, d.en, d.es, art: d.art, group: d.group),
];

AppIconPreset? appIconPresetById(String id) {
  for (final p in allAppIconPresets) {
    if (p.id == id) return p;
  }
  return null;
}

/// PNG bytes of a gallery design at [size] px.
Future<Uint8List> renderIconArtPng(IconArt art, int size) async {
  final logo = await prismLogoImage();
  final img = await renderIconArtImage(art, size, logo: logo);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return bytes!.buffer.asUint8List();
}

/// Where changing the icon works: the Android launcher and the browser tab.
bool get appIconSupported =>
    kIsWeb || defaultTargetPlatform == TargetPlatform.android;

class AppIconService {
  const AppIconService();
  static const _channel = MethodChannel('com.prismplural.prism/app_icon');
  static const _key = 'prism.appIcon';

  static const _customKey = 'prism.appIcon.custom';
  static const _specKey = 'prism.appIcon.customSpec';

  Future<String> current() async {
    try {
      if ((await SharedPreferences.getInstance()).getString(_key) == 'custom')
        return 'custom';
    } catch (_) {}
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        return await _channel.invokeMethod<String>('current') ?? 'classic';
      } catch (_) {
        return 'classic';
      }
    }
    try {
      return (await SharedPreferences.getInstance()).getString(_key) ??
          'classic';
    } catch (_) {
      return 'classic';
    }
  }

  /// Switches the icon. Returns false where it isn't supported.
  Future<bool> set(String id) async {
    final preset = appIconPresetById(id);
    if (preset == null) return false;
    if (kIsWeb) {
      final art = preset.art;
      if (art == null) {
        setFavicon('icons/app/$id.png');
      } else {
        setFavicon(
          'data:image/png;base64,${base64Encode(await renderIconArtPng(art, 128))}',
        );
      }
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      final ok = await _channel.invokeMethod<bool>('set', {'id': id}) ?? false;
      if (!ok) return false;
    } else {
      return false;
    }
    try {
      await (await SharedPreferences.getInstance()).setString(_key, id);
    } catch (_) {}
    return true;
  }
}

extension SeasonalAppIcon on AppIconService {
  static const autoKey = 'prism.appIcon.seasonAuto';

  /// Uses a seasonal design. Android launchers can only switch between
  /// icons built into the app, so it goes on a home-screen shortcut (Android
  /// asks once; later changes update it silently). Web: the tab icon.
  Future<bool> setDesign(IconDesign d, {bool ask = true}) async {
    final png = await renderIconArtPng(d.art, kIsWeb ? 128 : 432);
    if (kIsWeb) {
      setFavicon('data:image/png;base64,${base64Encode(png)}');
      return true;
    }
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await AppIconService._channel.invokeMethod<bool>(
            ask ? 'pinShortcut' : 'updateShortcut',
            {'png': png, 'label': 'Prism'},
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> autoSeasonal() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(autoKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setAutoSeasonal(bool on) async {
    try {
      await (await SharedPreferences.getInstance()).setBool(autoKey, on);
    } catch (_) {}
  }
}

extension CustomAppIcon on AppIconService {
  /// The saved custom icon (small PNG), if any.
  Future<Uint8List?> customPng() async {
    try {
      final v = (await SharedPreferences.getInstance()).getString(
        AppIconService._customKey,
      );
      return v == null ? null : base64Decode(v);
    } catch (_) {
      return null;
    }
  }

  Future<CustomIconSpec?> customSpec() async {
    try {
      final v = (await SharedPreferences.getInstance()).getString(
        AppIconService._specKey,
      );
      return v == null
          ? null
          : CustomIconSpec.fromJson(
              (jsonDecode(v) as Map).cast<String, Object?>(),
            );
    } catch (_) {
      return null;
    }
  }

  /// Uses a custom icon. Web: the browser tab icon. Android: launchers only
  /// switch between built-in icons, so Prism adds a home-screen shortcut with
  /// the custom icon (Android asks to confirm). Returns whether it was applied.
  Future<bool> setCustom(CustomIconSpec spec) async {
    final small = await renderCustomIcon(spec, size: 256);
    var ok = true;
    if (kIsWeb) {
      setFavicon('data:image/png;base64,${base64Encode(small)}');
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      final big = await renderCustomIcon(spec, size: 432);
      ok =
          await AppIconService._channel.invokeMethod<bool>('pinShortcut', {
            'png': big,
            'label': 'Prism',
          }) ??
          false;
    } else {
      return false;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppIconService._customKey, base64Encode(small));
      await prefs.setString(AppIconService._specKey, jsonEncode(spec.toJson()));
      await prefs.setString(AppIconService._key, 'custom');
    } catch (_) {}
    return ok;
  }
}

/// The saved custom icon image (for previews and the web sidebar).
final customAppIconProvider = FutureProvider<Uint8List?>((ref) {
  ref.watch(appIconProvider);
  return ref.read(appIconServiceProvider).customPng();
});

final appIconServiceProvider = Provider<AppIconService>(
  (ref) => const AppIconService(),
);

class AppIconNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() => ref.read(appIconServiceProvider).current();

  Future<bool> select(String id) async {
    final ok = await ref.read(appIconServiceProvider).set(id);
    if (ok) state = AsyncData(id);
    return ok;
  }

  Future<bool> selectCustom(CustomIconSpec spec) async {
    final ok = await ref.read(appIconServiceProvider).setCustom(spec);
    state = const AsyncData('custom');
    return ok;
  }
}

final appIconProvider = AsyncNotifierProvider<AppIconNotifier, String>(
  AppIconNotifier.new,
);
