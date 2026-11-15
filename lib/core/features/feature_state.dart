import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:prism_plurality/core/features/feature_registry.dart';
import 'package:prism_plurality/core/services/local_notification_service.dart';
import 'package:prism_plurality/features/availability/availability_providers.dart';
import 'package:prism_plurality/features/nutrition/nutrition_data.dart';
import 'package:prism_plurality/features/settings/providers/settings_providers.dart';
import 'package:prism_plurality/shared/notify.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// The synced record holding feature switches and the Minimal preset.
final featureRecordProvider = Provider<TrackerRecord?>((ref) {
  final rows = ref.watch(trackerKindProvider(TrackerKind.appFeatures)).value ?? const <TrackerRecord>[];
  if (rows.isEmpty) return null;
  return (rows.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt))).first;
});

/// Whether each registered feature is on. Core features are always on; the
/// older switches (chat, polls, habits, sleep, notes, reminders, boards) keep
/// living in system settings so nothing changes for existing users.
final featureStatesProvider = Provider<Map<String, bool>>((ref) {
  final flags = ref.watch(featureFlagsProvider);
  final saved = (ref.watch(featureRecordProvider)?.fields['on'] as Map?)?.cast<String, Object?>() ?? const {};
  bool legacy(String k) => switch (k) {
    'chat' => flags.chat,
    'polls' => flags.polls,
    'habits' => flags.habits,
    'sleep' => flags.sleep,
    'notes' => flags.notes,
    'reminders' => flags.reminders,
    'boards' => flags.boards,
    _ => true,
  };
  return {
    for (final f in prismFeatures)
      f.id: f.core ? true : (f.legacyFlag != null ? legacy(f.legacyFlag!) : (saved[f.id] is bool ? saved[f.id] as bool : f.defaultEnabled)),
  };
});

final featureEnabledProvider = Provider.family<bool, String>((ref, id) => ref.watch(featureStatesProvider)[id] ?? true);

/// Feature ids in the (customisable) Minimal preset.
final minimalPresetProvider = Provider<Set<String>>((ref) {
  final raw = ref.watch(featureRecordProvider)?.fields['minimal'];
  if (raw is List && raw.isNotEmpty) return {for (final x in raw) if (x is String) x, for (final f in prismFeatures) if (f.core) f.id};
  return {for (final f in prismFeatures) if (f.core || f.essential) f.id};
});

/// Reads a feature switch outside the widget tree (background services).
bool isFeatureOn(Ref ref, String id) {
  try {
    return ref.read(featureStatesProvider)[id] ?? true;
  } catch (_) {
    return true;
  }
}

class FeatureActions {
  FeatureActions(this.ref);
  final Ref ref;

  Future<void> _saveRecord(Map<String, Object?> changes) async {
    final t = ref.read(trackerNotifierProvider.notifier);
    final r = ref.read(featureRecordProvider);
    if (r == null) {
      await t.create(kind: TrackerKind.appFeatures, fields: changes);
    } else {
      await t.save(r.withFields(changes));
    }
  }

  /// Turns one feature on or off. Data is never deleted.
  Future<void> setEnabled(String id, bool on) async {
    final f = prismFeatureIndex[id];
    if (f == null || f.core) return;
    final settings = ref.read(settingsNotifierProvider.notifier);
    switch (f.legacyFlag) {
      case 'chat':
        await settings.updateFeatureToggle(chatEnabled: on);
      case 'polls':
        await settings.updateFeatureToggle(pollsEnabled: on);
      case 'habits':
        await settings.updateFeatureToggle(habitsEnabled: on);
      case 'sleep':
        await settings.updateFeatureToggle(sleepTrackingEnabled: on);
      case 'boards':
        await settings.updateFeatureToggle(boardsEnabled: on);
      case 'notes':
        await settings.updateNotesEnabled(on);
      case 'reminders':
        await settings.updateRemindersEnabled(on);
      default:
        final current = (ref.read(featureRecordProvider)?.fields['on'] as Map?)?.cast<String, Object?>() ?? const {};
        await _saveRecord({'on': {...current, id: on}});
    }
    await _sideEffects(id, on);
  }

  /// Applies a set of enabled features (presets). Returns what changed.
  Future<void> applyPreset(Set<String> enabled) async {
    final states = ref.read(featureStatesProvider);
    for (final f in prismFeatures) {
      if (f.core) continue;
      final want = enabled.contains(f.id);
      if (states[f.id] != want) await setEnabled(f.id, want);
    }
  }

  Future<void> saveMinimalPreset(Set<String> ids) => _saveRecord({'minimal': ids.toList()});

  /// Pauses or resumes a feature's notifications and background work.
  Future<void> _sideEffects(String id, bool on) async {
    if (kIsWeb) return;
    final svc = ref.read(localNotificationServiceProvider);
    Future<void> cancel(int base) async {
      try {
        await svc.cancelRange(base, PrismNotify.range);
      } catch (_) {}
    }

    switch (id) {
      case 'availability':
        on ? await ref.read(availabilityActionsProvider).rescheduleNotifications() : await cancel(PrismNotify.availabilityBase);
      case 'nutrition':
        on ? await ref.read(nutritionActionsProvider).rescheduleReminders() : await cancel(PrismNotify.hydrationBase);
      case 'habits':
        if (!on) await cancel(PrismNotify.habitBase);
      case 'automations':
        if (!on) await cancel(PrismNotify.automationBase);
      case 'subsystems':
        if (!on) await cancel(PrismNotify.subsystemBase);
    }
  }
}

final featureActionsProvider = Provider<FeatureActions>(FeatureActions.new);

/// Feature that owns [location], if it is turned off (for the route gate).
PrismFeature? disabledFeatureFor(String location, Map<String, bool> states) {
  for (final f in prismFeatures) {
    final r = f.route;
    if (r == null || r == '/' || f.core || (states[f.id] ?? true)) continue;
    if (location == r || location.startsWith('$r/')) return f;
  }
  return null;
}
