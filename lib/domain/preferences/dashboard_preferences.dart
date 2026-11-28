import 'package:prism_plurality/domain/preferences/preference_codec.dart';
import 'package:prism_plurality/domain/preferences/preference_definition.dart';

/// Dashboard widget ids, in display order. Anything not listed is hidden.
abstract final class DashboardWidgetId {
  static const now = 'now';
  static const quickActions = 'quick_actions';
  static const howWeFeel = 'how_we_feel';
  static const insight = 'insight';
  static const stats = 'stats';
  static const sleep = 'sleep';
  static const cycle = 'cycle';
  static const birthdays = 'birthdays';
  static const events = 'events';
  static const achievements = 'achievements';
  static const journal = 'journal';
  static const stories = 'stories';
  static const statuses = 'statuses';
  static const hydration = 'hydration';
  static const availability = 'availability';
  static const automation = 'automation';
  // Cards that used to be fixed on Home; now they can be hidden, moved and
  // resized like the rest without turning their feature off.
  static const frontingRoles = 'fronting_roles';
  static const health = 'health_today';
  static const companion = 'companion';
  // Experiences modules.
  static const memoryOfDay = 'memory_of_day';
  static const wrapped = 'wrapped';
  static const passportStamps = 'passport_stamps';
  static const habitat = 'habitat';
  static const rooms = 'digital_rooms';
  // Yumeships: upcoming anniversaries and countdowns (opt-in).
  static const yumeCountdown = 'yume_countdown';

  /// Cards whose size can be switched between compact and full.
  static const resizable = {health, companion};

  static const all = [
    stories,
    frontingRoles,
    now,
    health,
    companion,
    memoryOfDay,
    wrapped,
    passportStamps,
    habitat,
    rooms,
    yumeCountdown,
    quickActions,
    howWeFeel,
    insight,
    stats,
    sleep,
    cycle,
    birthdays,
    events,
    achievements,
    journal,
    statuses,
    hydration,
    availability,
    automation,
  ];
  static const defaults = [
    stories,
    frontingRoles,
    now,
    health,
    companion,
    memoryOfDay,
    wrapped,
    quickActions,
    howWeFeel,
    insight,
    birthdays,
    events,
  ];
}

/// Quick action ids, in display order.
abstract final class QuickActionId {
  static const switchFront = 'switch_front';
  static const logMood = 'log_mood';
  static const logBody = 'log_body';
  static const startLocation = 'start_location';
  static const clockIn = 'clock_in';
  static const journal = 'journal';
  static const event = 'event';
  static const birthday = 'birthday';
  static const contact = 'contact';
  static const cycle = 'cycle';
  static const insights = 'insights';
  static const timeline = 'timeline';
  static const importCenter = 'import';
  static const dictionary = 'dictionary';
  static const achievements = 'achievements';

  static const all = [
    switchFront,
    logMood,
    logBody,
    startLocation,
    clockIn,
    journal,
    event,
    birthday,
    contact,
    cycle,
    insights,
    timeline,
    importCenter,
    dictionary,
    achievements,
  ];
  static const defaults = [
    switchFront,
    logMood,
    startLocation,
    clockIn,
    journal,
    insights,
  ];
}

List<String> _decodeIds(Object? value, List<String> known) {
  if (value is! List) return const [];
  final seen = <String>{};
  return [
    for (final v in value)
      if (v is String && known.contains(v) && seen.add(v)) v,
  ];
}

Object? _encodeIds(List<String> v) => v;
List<String> _decodeWidgets(Object? v) => _decodeIds(v, DashboardWidgetId.all);
List<String> _decodeActions(Object? v) => _decodeIds(v, QuickActionId.all);

const dashboardWidgetsPreference = PreferenceDefinition<List<String>>(
  key: 'dashboard.widgets',
  scope: PreferenceScope.appSynced,
  defaultValue: DashboardWidgetId.defaults,
  codec: JsonPreferenceCodec<List<String>>(
    toJson: _encodeIds,
    fromJson: _decodeWidgets,
  ),
  introducedInAppVersion: '0.16.0',
  introducedInSchemaVersion: 44,
);

const dashboardQuickActionsPreference = PreferenceDefinition<List<String>>(
  key: 'dashboard.quick_actions',
  scope: PreferenceScope.appSynced,
  defaultValue: QuickActionId.defaults,
  codec: JsonPreferenceCodec<List<String>>(
    toJson: _encodeIds,
    fromJson: _decodeActions,
  ),
  introducedInAppVersion: '0.16.0',
  introducedInSchemaVersion: 44,
);
