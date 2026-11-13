import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/domain/preferences/dashboard_preferences.dart';
import 'package:prism_plurality/features/settings/providers/settings_providers.dart';

const _doneKey = 'social.onboarded.v1';

/// One-time setup when the social features arrive: turns the Bulletin
/// Board on (it used to sit behind the off-by-default Boards switch, so
/// people could not find it), puts Stories in the navigation "More" menu
/// and adds the Stories section to the top of the Home dashboard. Runs
/// once per device; everything can be switched off again afterwards.
final socialOnboardingProvider = Provider<void>((ref) {
  final settings = ref.watch(systemSettingsProvider).value;
  if (settings == null) return;
  // Start a little after launch so it never competes with opening the app.
  final t = Timer(const Duration(seconds: 3), () async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_doneKey) ?? false) return;
      if (!settings.boardsEnabled) {
        await ref.read(settingsNotifierProvider.notifier).updateFeatureToggle(boardsEnabled: true);
      }
      final repo = ref.read(systemSettingsRepositoryProvider);
      final now = await repo.getSettings();
      if (!now.navBarItems.contains('stories') && !now.navBarOverflowItems.contains('stories')) {
        await repo.updateNavBarOverflowItems([...now.navBarOverflowItems, 'stories']);
      }
      final appPrefs = ref.read(appPreferenceRepositoryProvider);
      final widgets = await appPrefs.get(dashboardWidgetsPreference);
      if (!widgets.contains(DashboardWidgetId.stories)) {
        await appPrefs.set(dashboardWidgetsPreference, [DashboardWidgetId.stories, ...widgets]);
      }
      await prefs.setBool(_doneKey, true);
    } catch (_) {
      // Tried again next launch.
    }
  });
  ref.onDispose(t.cancel);
});
