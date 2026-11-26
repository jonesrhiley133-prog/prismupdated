import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:shared_preferences/shared_preferences.dart';

/// How the launch logo animates in.
enum LaunchStyle { assemble, fade, minimal }

/// How the logo looks on the launch screen.
enum LaunchLogo { filled, outline, tile }

/// Launch screen background.
enum LaunchBackground { theme, prism }

/// Built-in greeting choices.
enum GreetingPreset {
  welcomeBack,
  timeOfDay,
  welcomeHome,
  niceToSee,
  custom,
  none,
}

/// Launch Experience preferences. Stored on the device (not synced), so they
/// are available the moment the app starts, before the database opens.
@immutable
class LaunchSettings {
  const LaunchSettings({
    this.enabled = true,
    this.speed = 1.0,
    this.style = LaunchStyle.assemble,
    this.logo = LaunchLogo.filled,
    this.background = LaunchBackground.theme,
    this.greeting = GreetingPreset.welcomeBack,
    this.customGreeting = '',
    this.showAvatar = true,
    this.reducedMotion = false,
    this.skipQuickReopen = true,
  });

  final bool enabled;

  /// 0.6 (slower) … 1.6 (faster).
  final double speed;
  final LaunchStyle style;
  final LaunchLogo logo;
  final LaunchBackground background;
  final GreetingPreset greeting;
  final String customGreeting;
  final bool showAvatar;

  /// Always use the gentle no-movement version (also follows the system
  /// "remove animations" setting).
  final bool reducedMotion;

  /// Skip the animation when Prism was closed less than two minutes ago.
  final bool skipQuickReopen;

  LaunchSettings copyWith({
    bool? enabled,
    double? speed,
    LaunchStyle? style,
    LaunchLogo? logo,
    LaunchBackground? background,
    GreetingPreset? greeting,
    String? customGreeting,
    bool? showAvatar,
    bool? reducedMotion,
    bool? skipQuickReopen,
  }) => LaunchSettings(
    enabled: enabled ?? this.enabled,
    speed: speed ?? this.speed,
    style: style ?? this.style,
    logo: logo ?? this.logo,
    background: background ?? this.background,
    greeting: greeting ?? this.greeting,
    customGreeting: customGreeting ?? this.customGreeting,
    showAvatar: showAvatar ?? this.showAvatar,
    reducedMotion: reducedMotion ?? this.reducedMotion,
    skipQuickReopen: skipQuickReopen ?? this.skipQuickReopen,
  );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'speed': speed,
    'style': style.name,
    'logo': logo.name,
    'background': background.name,
    'greeting': greeting.name,
    'customGreeting': customGreeting,
    'showAvatar': showAvatar,
    'reducedMotion': reducedMotion,
    'skipQuickReopen': skipQuickReopen,
  };

  static LaunchSettings fromJson(Map<String, Object?> j) {
    T pick<T extends Enum>(List<T> values, Object? v, T fallback) =>
        values.where((e) => e.name == v).firstOrNull ?? fallback;
    return LaunchSettings(
      enabled: j['enabled'] != false,
      speed: ((j['speed'] as num?)?.toDouble() ?? 1.0).clamp(0.6, 1.6),
      style: pick(LaunchStyle.values, j['style'], LaunchStyle.assemble),
      logo: pick(LaunchLogo.values, j['logo'], LaunchLogo.filled),
      background: pick(
        LaunchBackground.values,
        j['background'],
        LaunchBackground.theme,
      ),
      greeting: pick(
        GreetingPreset.values,
        j['greeting'],
        GreetingPreset.welcomeBack,
      ),
      customGreeting: '${j['customGreeting'] ?? ''}',
      showAvatar: j['showAvatar'] != false,
      reducedMotion: j['reducedMotion'] == true,
      skipQuickReopen: j['skipQuickReopen'] != false,
    );
  }

  /// Full animation length before the hand-off to the app.
  Duration get duration {
    final base = switch (style) {
      LaunchStyle.assemble => 1350,
      LaunchStyle.fade => 900,
      LaunchStyle.minimal => 600,
    };
    return Duration(milliseconds: (base / speed).round());
  }
}

const _prefsKey = 'prism_launch_settings_v1';
const _lastCloseKey = 'prism_last_close_ms';
const _nameKey = 'prism_launch_system_name';

/// What the launch screen knows before the database opens: settings, the
/// last system name, and whether this start is a quick reopen.
class LaunchBoot {
  static LaunchSettings settings = const LaunchSettings();
  static String cachedSystemName = '';
  static bool quickReopen = false;
  static final Stopwatch clock = Stopwatch();
  static bool _loaded = false;

  /// Call early in main(); never throws.
  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null)
        settings = LaunchSettings.fromJson(
          (jsonDecode(raw) as Map).cast<String, Object?>(),
        );
      cachedSystemName = prefs.getString(_nameKey) ?? '';
      final last = prefs.getInt(_lastCloseKey);
      if (last != null) {
        quickReopen =
            DateTime.now().millisecondsSinceEpoch - last <
            const Duration(minutes: 2).inMilliseconds;
      }
    } catch (_) {}
  }

  /// Whether to play the launch animation this time.
  static bool get shouldPlay =>
      settings.enabled && !(settings.skipQuickReopen && quickReopen);

  static Future<void> noteClosed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastCloseKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  static Future<void> rememberSystemName(String name) async {
    if (name == cachedSystemName) return;
    cachedSystemName = name;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_nameKey, name);
    } catch (_) {}
  }
}

class LaunchSettingsNotifier extends Notifier<LaunchSettings> {
  @override
  LaunchSettings build() => LaunchBoot.settings;

  Future<void> set(LaunchSettings s) async {
    state = s;
    LaunchBoot.settings = s;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(s.toJson()));
    } catch (_) {}
  }
}

final launchSettingsProvider =
    NotifierProvider<LaunchSettingsNotifier, LaunchSettings>(
      LaunchSettingsNotifier.new,
    );

String timeOfDayWord(DateTime now, {bool es = false}) {
  final h = now.hour;
  if (h >= 5 && h < 12) return es ? 'mañana' : 'morning';
  if (h >= 12 && h < 18) return es ? 'tarde' : 'afternoon';
  return es ? 'noche' : 'evening';
}

/// The greeting text for [preset], with {system_name}, {primary_fronter},
/// {time_of_day}, {date} and {day_of_week} filled in. Empty for "none".
String buildGreeting({
  required GreetingPreset preset,
  required String custom,
  required String systemName,
  String? primaryFronter,
  DateTime? now,
  bool es = false,
  String? locale,
}) {
  final t = now ?? DateTime.now();
  final name = systemName.trim();
  final template = switch (preset) {
    GreetingPreset.welcomeBack =>
      name.isEmpty
          ? (es ? '¡Bienvenido de nuevo!' : 'Welcome back!')
          : (es
                ? '¡Bienvenido de nuevo, {system_name}!'
                : 'Welcome back, {system_name}!'),
    GreetingPreset.timeOfDay => () {
      final w = timeOfDayWord(t, es: es);
      final base = es
          ? (w == 'mañana'
                ? 'Buenos días'
                : (w == 'tarde' ? 'Buenas tardes' : 'Buenas noches'))
          : 'Good $w';
      return name.isEmpty ? base : '$base, {system_name}';
    }(),
    GreetingPreset.welcomeHome =>
      name.isEmpty
          ? (es ? 'Bienvenido a casa' : 'Welcome home')
          : (es
                ? 'Bienvenido a casa, {system_name}'
                : 'Welcome home, {system_name}'),
    GreetingPreset.niceToSee =>
      es ? 'Qué alegría verte de nuevo' : "It's nice to see you again",
    GreetingPreset.custom => custom,
    GreetingPreset.none => '',
  };
  String fmt(DateFormat Function(String? l) f) {
    try {
      return f(locale).format(t);
    } catch (_) {
      return f(null).format(t);
    }
  }

  return template
      .replaceAll('{system_name}', name)
      .replaceAll('{primary_fronter}', primaryFronter?.trim() ?? '')
      .replaceAll('{time_of_day}', timeOfDayWord(t, es: es))
      .replaceAll('{date}', fmt(DateFormat.yMMMMd))
      .replaceAll('{day_of_week}', fmt(DateFormat.EEEE))
      .replaceAllMapped(RegExp(r',\s*([!.?]|$)'), (m) => m[1] ?? '')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
}
