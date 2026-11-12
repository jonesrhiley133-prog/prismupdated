import 'package:flutter/foundation.dart';

/// Pieces of information the notification can show, in user-chosen order.
abstract final class FnInfo {
  static const fronters = 'fronters';
  static const cofronters = 'cofronters';
  static const pronouns = 'pronouns';
  static const duration = 'duration';
  static const status = 'status';
  static const customStatus = 'custom_status';
  static const mood = 'mood';
  static const emotions = 'emotions';
  static const location = 'location';
  static const activity = 'activity';
  static const custom = 'custom';
  static const all = [
    fronters,
    cofronters,
    pronouns,
    duration,
    status,
    customStatus,
    mood,
    emotions,
    location,
    activity,
    custom,
  ];
}

abstract final class FnAction {
  static const quickFront = 'quick_front';
  static const switchFronter = 'switch';
  static const open = 'open';
  static const mood = 'mood';
  static const status = 'status';
  static const details = 'details';
  static const all = [quickFront, switchFronter, open, mood, status, details];
}

/// small icon keys (native vector drawables).
const fnSmallIcons = [
  'person',
  'group',
  'heart',
  'star',
  'moon',
  'sparkle',
  'leaf',
];

enum FnIconSource { none, avatar, emoji, builtIn }

enum FnLayout { compact, expanded, minimal, detailed }

enum FnStyle { system, custom }

enum FnLockScreen { show, hideDetails, hide }

enum FnWhenEmpty { message, hide }

/// Overrides for one member's notification.
@immutable
class FnMemberStyle {
  const FnMemberStyle({
    this.title,
    this.greeting,
    this.emoji,
    this.accentColor,
    this.backgroundColor,
    this.textColor,
  });

  final String? title;
  final String? greeting;
  final String? emoji;
  final int? accentColor;
  final int? backgroundColor;
  final int? textColor;

  bool get isEmpty =>
      title == null &&
      greeting == null &&
      emoji == null &&
      accentColor == null &&
      backgroundColor == null &&
      textColor == null;

  Map<String, Object?> toJson() => {
    'title': ?title,
    'greeting': ?greeting,
    'emoji': ?emoji,
    'accentColor': ?accentColor,
    'backgroundColor': ?backgroundColor,
    'textColor': ?textColor,
  };

  static FnMemberStyle fromJson(Map<String, dynamic> j) => FnMemberStyle(
    title: j['title'] as String?,
    greeting: j['greeting'] as String?,
    emoji: j['emoji'] as String?,
    accentColor: j['accentColor'] as int?,
    backgroundColor: j['backgroundColor'] as int?,
    textColor: j['textColor'] as int?,
  );

  @override
  bool operator ==(Object other) =>
      other is FnMemberStyle && mapEquals(toJson(), other.toJson());

  @override
  int get hashCode => Object.hashAll(toJson().values);
}

T _enum<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

/// Everything the user can configure. Stored per device.
@immutable
class FrontingNotificationSettings {
  const FrontingNotificationSettings({
    this.enabled = false,
    this.titleTemplate = 'Fronting: {fronters}',
    this.greeting = '',
    this.iconSource = FnIconSource.avatar,
    this.iconEmoji = '🌈',
    this.smallIcon = 'person',
    this.layout = FnLayout.expanded,
    this.style = FnStyle.system,
    this.accentColor,
    this.backgroundColor,
    this.textColor,
    this.colorized = false,
    this.info = const [
      FnInfo.fronters,
      FnInfo.cofronters,
      FnInfo.duration,
      FnInfo.mood,
      FnInfo.activity,
    ],
    this.actions = const [
      FnAction.switchFronter,
      FnAction.mood,
      FnAction.status,
    ],
    this.customStatus = '',
    this.customLines = const [],
    this.foregroundService = false,
    this.restoreOnBoot = true,
    this.allowDismiss = false,
    this.lockScreen = FnLockScreen.hideDetails,
    this.bypassDnd = false,
    this.whenEmpty = FnWhenEmpty.message,
    this.emptyMessage = '',
    this.memberStyles = const {},
    this.moodMaxAgeHours = 12,
  });

  final bool enabled;

  /// Supports {fronters}, {cofronters}, {first}, {count}, {mood}, {location}.
  final String titleTemplate;
  final String greeting;
  final FnIconSource iconSource;
  final String iconEmoji;
  final String smallIcon;
  final FnLayout layout;
  final FnStyle style;
  final int? accentColor;
  final int? backgroundColor;
  final int? textColor;
  final bool colorized;

  /// Enabled info items, in display order.
  final List<String> info;

  /// Up to three action ids, in order.
  final List<String> actions;
  final String customStatus;
  final List<String> customLines;
  final bool foregroundService;
  final bool restoreOnBoot;
  final bool allowDismiss;
  final FnLockScreen lockScreen;
  final bool bypassDnd;
  final FnWhenEmpty whenEmpty;
  final String emptyMessage;
  final Map<String, FnMemberStyle> memberStyles;

  /// Moods older than this are not shown.
  final int moodMaxAgeHours;

  FrontingNotificationSettings copyWith({
    bool? enabled,
    String? titleTemplate,
    String? greeting,
    FnIconSource? iconSource,
    String? iconEmoji,
    String? smallIcon,
    FnLayout? layout,
    FnStyle? style,
    int? accentColor,
    int? backgroundColor,
    int? textColor,
    bool clearAccent = false,
    bool clearBackground = false,
    bool clearText = false,
    bool? colorized,
    List<String>? info,
    List<String>? actions,
    String? customStatus,
    List<String>? customLines,
    bool? foregroundService,
    bool? restoreOnBoot,
    bool? allowDismiss,
    FnLockScreen? lockScreen,
    bool? bypassDnd,
    FnWhenEmpty? whenEmpty,
    String? emptyMessage,
    Map<String, FnMemberStyle>? memberStyles,
    int? moodMaxAgeHours,
  }) => FrontingNotificationSettings(
    enabled: enabled ?? this.enabled,
    titleTemplate: titleTemplate ?? this.titleTemplate,
    greeting: greeting ?? this.greeting,
    iconSource: iconSource ?? this.iconSource,
    iconEmoji: iconEmoji ?? this.iconEmoji,
    smallIcon: smallIcon ?? this.smallIcon,
    layout: layout ?? this.layout,
    style: style ?? this.style,
    accentColor: clearAccent ? null : (accentColor ?? this.accentColor),
    backgroundColor: clearBackground
        ? null
        : (backgroundColor ?? this.backgroundColor),
    textColor: clearText ? null : (textColor ?? this.textColor),
    colorized: colorized ?? this.colorized,
    info: info ?? this.info,
    actions: actions ?? this.actions,
    customStatus: customStatus ?? this.customStatus,
    customLines: customLines ?? this.customLines,
    foregroundService: foregroundService ?? this.foregroundService,
    restoreOnBoot: restoreOnBoot ?? this.restoreOnBoot,
    allowDismiss: allowDismiss ?? this.allowDismiss,
    lockScreen: lockScreen ?? this.lockScreen,
    bypassDnd: bypassDnd ?? this.bypassDnd,
    whenEmpty: whenEmpty ?? this.whenEmpty,
    emptyMessage: emptyMessage ?? this.emptyMessage,
    memberStyles: memberStyles ?? this.memberStyles,
    moodMaxAgeHours: moodMaxAgeHours ?? this.moodMaxAgeHours,
  );

  Map<String, Object?> toJson() => {
    'v': 1,
    'enabled': enabled,
    'titleTemplate': titleTemplate,
    'greeting': greeting,
    'iconSource': iconSource.name,
    'iconEmoji': iconEmoji,
    'smallIcon': smallIcon,
    'layout': layout.name,
    'style': style.name,
    'accentColor': accentColor,
    'backgroundColor': backgroundColor,
    'textColor': textColor,
    'colorized': colorized,
    'info': info,
    'actions': actions,
    'customStatus': customStatus,
    'customLines': customLines,
    'foregroundService': foregroundService,
    'restoreOnBoot': restoreOnBoot,
    'allowDismiss': allowDismiss,
    'lockScreen': lockScreen.name,
    'bypassDnd': bypassDnd,
    'whenEmpty': whenEmpty.name,
    'emptyMessage': emptyMessage,
    'memberStyles': {
      for (final e in memberStyles.entries)
        if (!e.value.isEmpty) e.key: e.value.toJson(),
    },
    'moodMaxAgeHours': moodMaxAgeHours,
  };

  static FrontingNotificationSettings fromJson(Map<String, dynamic> j) {
    const d = FrontingNotificationSettings();
    List<String> strings(
      Object? v,
      List<String> fallback, {
      List<String>? allowed,
    }) {
      if (v is! List) return fallback;
      final seen = <String>{};
      return [
        for (final x in v)
          if (x is String &&
              (allowed == null || allowed.contains(x)) &&
              seen.add(x))
            x,
      ];
    }

    final styles = <String, FnMemberStyle>{};
    final rawStyles = j['memberStyles'];
    if (rawStyles is Map) {
      rawStyles.forEach((k, v) {
        if (k is String && v is Map<String, dynamic>)
          styles[k] = FnMemberStyle.fromJson(v);
      });
    }
    return FrontingNotificationSettings(
      enabled: j['enabled'] == true,
      titleTemplate: j['titleTemplate'] is String
          ? j['titleTemplate'] as String
          : d.titleTemplate,
      greeting: j['greeting'] is String ? j['greeting'] as String : '',
      iconSource: _enum(FnIconSource.values, j['iconSource'], d.iconSource),
      iconEmoji: j['iconEmoji'] is String
          ? j['iconEmoji'] as String
          : d.iconEmoji,
      smallIcon: fnSmallIcons.contains(j['smallIcon'])
          ? j['smallIcon'] as String
          : d.smallIcon,
      layout: _enum(FnLayout.values, j['layout'], d.layout),
      style: _enum(FnStyle.values, j['style'], d.style),
      accentColor: j['accentColor'] as int?,
      backgroundColor: j['backgroundColor'] as int?,
      textColor: j['textColor'] as int?,
      colorized: j['colorized'] == true,
      info: strings(j['info'], d.info, allowed: FnInfo.all),
      actions: strings(
        j['actions'],
        d.actions,
        allowed: FnAction.all,
      ).take(3).toList(),
      customStatus: j['customStatus'] is String
          ? j['customStatus'] as String
          : '',
      customLines: strings(j['customLines'], const []),
      foregroundService: j['foregroundService'] == true,
      restoreOnBoot: j['restoreOnBoot'] != false,
      allowDismiss: j['allowDismiss'] == true,
      lockScreen: _enum(FnLockScreen.values, j['lockScreen'], d.lockScreen),
      bypassDnd: j['bypassDnd'] == true,
      whenEmpty: _enum(FnWhenEmpty.values, j['whenEmpty'], d.whenEmpty),
      emptyMessage: j['emptyMessage'] is String
          ? j['emptyMessage'] as String
          : '',
      memberStyles: styles,
      moodMaxAgeHours:
          (j['moodMaxAgeHours'] as num?)?.toInt().clamp(1, 168) ??
          d.moodMaxAgeHours,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FrontingNotificationSettings &&
      mapEquals(_flat(toJson()), _flat(other.toJson()));

  @override
  int get hashCode => toJson().toString().hashCode;

  static Map<String, Object?> _flat(Map<String, Object?> m) => {
    for (final e in m.entries)
      e.key: e.value is List || e.value is Map ? e.value.toString() : e.value,
  };
}
