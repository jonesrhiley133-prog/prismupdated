import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:prism_plurality/features/appearance/services/synced_setting.dart';
import 'package:prism_plurality/shared/utils/haptics.dart';

enum ColorVision { standard, protanopia, deuteranopia, tritanopia, monochrome }

/// Every accessibility option, each independently adjustable.
@immutable
class A11ySettings {
  const A11ySettings({
    this.uiScale = 1,
    this.lineHeight = 1,
    this.wordSpacing = 0,
    this.boldText = false,
    this.highContrast = false,
    this.contrast = 0,
    this.reduceTransparency = false,
    this.reduceEffects = false,
    this.reduceMotion = false,
    this.animationSpeed = 1,
    this.colorVision = ColorVision.standard,
    this.strongFocus = false,
    this.largeIcons = false,
    this.touchScale = 1,
    this.haptics = true,
    this.confirmActions = false,
    this.announce = true,
    this.modifiedAt = 0,
  });

  /// Whole-interface zoom (0.85–1.4).
  final double uiScale;

  /// Line-height multiplier (1–1.8).
  final double lineHeight;

  /// Extra space between words in logical pixels (0–6).
  final double wordSpacing;
  final bool boldText;
  final bool highContrast;

  /// Extra contrast for secondary text, borders and dividers (0–1).
  final double contrast;
  final bool reduceTransparency;

  /// No blur, shadows, background overlays or decorative effects.
  final bool reduceEffects;
  final bool reduceMotion;

  /// 0.5 (slower) … 2 (faster); 1 is normal.
  final double animationSpeed;
  final ColorVision colorVision;
  final bool strongFocus;
  final bool largeIcons;

  /// Touch target multiplier (1–1.5).
  final double touchScale;
  final bool haptics;

  /// Ask before deleting things.
  final bool confirmActions;

  /// Announce changing content (toasts, track changes) to screen readers.
  final bool announce;
  final int modifiedAt;

  bool get isDefault => jsonEncode((copyWith(modifiedAt: 0)).toJson()) == jsonEncode(const A11ySettings().toJson());

  A11ySettings copyWith({
    double? uiScale,
    double? lineHeight,
    double? wordSpacing,
    bool? boldText,
    bool? highContrast,
    double? contrast,
    bool? reduceTransparency,
    bool? reduceEffects,
    bool? reduceMotion,
    double? animationSpeed,
    ColorVision? colorVision,
    bool? strongFocus,
    bool? largeIcons,
    double? touchScale,
    bool? haptics,
    bool? confirmActions,
    bool? announce,
    int? modifiedAt,
  }) => A11ySettings(
    uiScale: uiScale ?? this.uiScale,
    lineHeight: lineHeight ?? this.lineHeight,
    wordSpacing: wordSpacing ?? this.wordSpacing,
    boldText: boldText ?? this.boldText,
    highContrast: highContrast ?? this.highContrast,
    contrast: contrast ?? this.contrast,
    reduceTransparency: reduceTransparency ?? this.reduceTransparency,
    reduceEffects: reduceEffects ?? this.reduceEffects,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    animationSpeed: animationSpeed ?? this.animationSpeed,
    colorVision: colorVision ?? this.colorVision,
    strongFocus: strongFocus ?? this.strongFocus,
    largeIcons: largeIcons ?? this.largeIcons,
    touchScale: touchScale ?? this.touchScale,
    haptics: haptics ?? this.haptics,
    confirmActions: confirmActions ?? this.confirmActions,
    announce: announce ?? this.announce,
    modifiedAt: modifiedAt ?? this.modifiedAt,
  );

  Map<String, Object?> toJson() => {
    'uiScale': uiScale,
    'lineHeight': lineHeight,
    'wordSpacing': wordSpacing,
    'boldText': boldText,
    'highContrast': highContrast,
    'contrast': contrast,
    'reduceTransparency': reduceTransparency,
    'reduceEffects': reduceEffects,
    'reduceMotion': reduceMotion,
    'animationSpeed': animationSpeed,
    'colorVision': colorVision.name,
    'strongFocus': strongFocus,
    'largeIcons': largeIcons,
    'touchScale': touchScale,
    'haptics': haptics,
    'confirmActions': confirmActions,
    'announce': announce,
    'modifiedAt': modifiedAt,
  };

  static A11ySettings fromJson(Object? j) {
    if (j is! Map) return const A11ySettings();
    double d(String k, double def, double lo, double hi) => (j[k] is num ? (j[k] as num).toDouble() : def).clamp(lo, hi).toDouble();
    return A11ySettings(
      uiScale: d('uiScale', 1, 0.85, 1.4),
      lineHeight: d('lineHeight', 1, 1, 1.8),
      wordSpacing: d('wordSpacing', 0, 0, 6),
      boldText: j['boldText'] == true,
      highContrast: j['highContrast'] == true,
      contrast: d('contrast', 0, 0, 1),
      reduceTransparency: j['reduceTransparency'] == true,
      reduceEffects: j['reduceEffects'] == true,
      reduceMotion: j['reduceMotion'] == true,
      animationSpeed: d('animationSpeed', 1, 0.5, 2),
      colorVision: ColorVision.values.firstWhere((v) => v.name == j['colorVision'], orElse: () => ColorVision.standard),
      strongFocus: j['strongFocus'] == true,
      largeIcons: j['largeIcons'] == true,
      touchScale: d('touchScale', 1, 1, 1.5),
      haptics: j['haptics'] != false,
      confirmActions: j['confirmActions'] == true,
      announce: j['announce'] != false,
      modifiedAt: j['modifiedAt'] is int ? j['modifiedAt'] as int : 0,
    );
  }
}

const _prefsKey = 'accessibility.settings.v1';
const a11ySettingKind = 'settings.accessibility';

class A11yNotifier extends AsyncNotifier<A11ySettings> {
  @override
  Future<A11ySettings> build() async {
    A11ySettings s;
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_prefsKey);
      s = raw == null ? const A11ySettings() : A11ySettings.fromJson(jsonDecode(raw));
    } catch (_) {
      s = const A11ySettings();
    }
    Haptics.enabled = s.haptics;
    return s;
  }

  Future<void> _save(A11ySettings next, {bool touch = true}) async {
    final stamped = touch ? next.copyWith(modifiedAt: DateTime.now().millisecondsSinceEpoch) : next;
    Haptics.enabled = stamped.haptics;
    state = AsyncData(stamped);
    try {
      await (await SharedPreferences.getInstance()).setString(_prefsKey, jsonEncode(stamped.toJson()));
    } catch (_) {
      // Kept in memory for this session.
    }
  }

  /// Saved automatically on every change.
  Future<void> change(A11ySettings Function(A11ySettings) f) async => _save(f(state.value ?? await future));

  Future<void> reset() => _save(const A11ySettings());

  Future<void> adoptRemote(Map<String, dynamic> json) => _save(A11ySettings.fromJson(json), touch: false);
}

final a11yProvider = AsyncNotifierProvider<A11yNotifier, A11ySettings>(A11yNotifier.new);

/// Current settings, defaults until loaded.
final a11ySettingsProvider = Provider<A11ySettings>((ref) => ref.watch(a11yProvider).value ?? const A11ySettings());

final a11ySyncProvider = Provider<void>((ref) {
  bindSyncedSetting(
    ref,
    kind: a11ySettingKind,
    local: () => ref.read(a11yProvider).value?.toJson(),
    adopt: (j) => ref.read(a11yProvider.notifier).adoptRemote(j),
    listenLocal: (cb) => ref.listen(a11yProvider, (_, _) => cb()),
  );
});
