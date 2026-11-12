import 'package:flutter/foundation.dart';

import 'package:prism_plurality/l10n/app_localizations.dart';

enum WidgetCategory { fronting, wellness, productivity, system }

@immutable
class WidgetTypeInfo {
  const WidgetTypeInfo(this.key, this.category, this.emoji);

  /// Matches the native provider mapping in PrismWidgets.kt.
  final String key;
  final WidgetCategory category;
  final String emoji;
}

/// The 20 widget types, in library order.
const widgetCatalog = <WidgetTypeInfo>[
  WidgetTypeInfo('recent_fronters', WidgetCategory.fronting, '🕘'),
  WidgetTypeInfo('current_fronter', WidgetCategory.fronting, '👤'),
  WidgetTypeInfo('quick_front', WidgetCategory.fronting, '⚡'),
  WidgetTypeInfo('events', WidgetCategory.fronting, '📅'),
  WidgetTypeInfo('journal', WidgetCategory.wellness, '📓'),
  WidgetTypeInfo('cycle', WidgetCategory.wellness, '💧'),
  WidgetTypeInfo('mood', WidgetCategory.wellness, '🙂'),
  WidgetTypeInfo('location', WidgetCategory.wellness, '📍'),
  WidgetTypeInfo('sleep', WidgetCategory.wellness, '🌙'),
  WidgetTypeInfo('fitness', WidgetCategory.wellness, '💪'),
  WidgetTypeInfo('todo', WidgetCategory.productivity, '✅'),
  WidgetTypeInfo('school', WidgetCategory.productivity, '🎓'),
  WidgetTypeInfo('finance', WidgetCategory.productivity, '💰'),
  WidgetTypeInfo('countdown', WidgetCategory.productivity, '⏳'),
  WidgetTypeInfo('relationships', WidgetCategory.system, '🤝'),
  WidgetTypeInfo('achievements', WidgetCategory.system, '🏆'),
  WidgetTypeInfo('headspace', WidgetCategory.system, '🗺'),
  WidgetTypeInfo('notes', WidgetCategory.system, '📝'),
  WidgetTypeInfo('subsystems', WidgetCategory.system, '🌳'),
  WidgetTypeInfo('stats', WidgetCategory.system, '📊'),
];

WidgetTypeInfo widgetTypeInfo(String key) =>
    widgetCatalog.firstWhere((w) => w.key == key, orElse: () => widgetCatalog.first);

String widgetTypeLabel(AppLocalizations l10n, String key) => switch (key) {
  'recent_fronters' => l10n.hwRecentFronters,
  'current_fronter' => l10n.hwCurrentFronter,
  'quick_front' => l10n.fnActionQuickFront,
  'events' => l10n.hwEvents,
  'journal' => l10n.navJournal,
  'cycle' => l10n.navCycle,
  'mood' => l10n.navMood,
  'location' => l10n.hwLocation,
  'sleep' => l10n.navSleep,
  'fitness' => l10n.navFitness,
  'todo' => l10n.hwTodo,
  'school' => l10n.navSchool,
  'finance' => l10n.navFinance,
  'countdown' => l10n.hwCountdown,
  'relationships' => l10n.navRelationships,
  'achievements' => l10n.navAchievements,
  'headspace' => l10n.navHeadspace,
  'notes' => l10n.hwNotes,
  'subsystems' => l10n.navSubsystems,
  _ => l10n.hwStats,
};

String widgetTypeDescription(AppLocalizations l10n, String key) => switch (key) {
  'recent_fronters' => l10n.hwDescRecentFronters,
  'current_fronter' => l10n.hwDescCurrentFronter,
  'quick_front' => l10n.hwDescQuickFront,
  'events' => l10n.hwDescEvents,
  'journal' => l10n.hwDescJournal,
  'cycle' => l10n.hwDescCycle,
  'mood' => l10n.hwDescMood,
  'location' => l10n.hwDescLocation,
  'sleep' => l10n.hwDescSleep,
  'fitness' => l10n.hwDescFitness,
  'todo' => l10n.hwDescTodo,
  'school' => l10n.hwDescSchool,
  'finance' => l10n.hwDescFinance,
  'countdown' => l10n.hwDescCountdown,
  'relationships' => l10n.hwDescRelationships,
  'achievements' => l10n.hwDescAchievements,
  'headspace' => l10n.hwDescHeadspace,
  'notes' => l10n.hwDescNotes,
  'subsystems' => l10n.hwDescSubsystems,
  _ => l10n.hwDescStats,
};

String widgetCategoryLabel(AppLocalizations l10n, WidgetCategory c) => switch (c) {
  WidgetCategory.fronting => l10n.hwCatFronting,
  WidgetCategory.wellness => l10n.hwCatWellness,
  WidgetCategory.productivity => l10n.hwCatProductivity,
  WidgetCategory.system => l10n.hwCatSystem,
};

/// Widgets whose content is personal enough to be masked by default.
const sensitiveWidgetTypes = {'journal', 'finance', 'cycle', 'relationships', 'notes', 'mood'};
