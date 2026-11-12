import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:prism_plurality/features/fronting_notification/models/fronting_notification_settings.dart';

const _prefsKey = 'fronting_notification.settings.v1';

/// Settings live on this device (each phone can look different) and
/// survive restarts and updates.
class FrontingNotificationSettingsNotifier
    extends AsyncNotifier<FrontingNotificationSettings> {
  @override
  Future<FrontingNotificationSettings> build() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_prefsKey);
      if (raw == null) return const FrontingNotificationSettings();
      final v = jsonDecode(raw);
      return v is Map<String, dynamic>
          ? FrontingNotificationSettings.fromJson(v)
          : const FrontingNotificationSettings();
    } on Exception {
      return const FrontingNotificationSettings();
    } on Error {
      return const FrontingNotificationSettings();
    }
  }

  Future<void> save(FrontingNotificationSettings next) async {
    state = AsyncData(next);
    try {
      await (await SharedPreferences.getInstance()).setString(
        _prefsKey,
        jsonEncode(next.toJson()),
      );
    } on Exception {
      // Kept in memory for this session.
    }
  }

  Future<void> change(
    FrontingNotificationSettings Function(FrontingNotificationSettings) change,
  ) async {
    final cur = state.value ?? await future;
    await save(change(cur));
  }
}

final frontingNotificationSettingsProvider =
    AsyncNotifierProvider<
      FrontingNotificationSettingsNotifier,
      FrontingNotificationSettings
    >(FrontingNotificationSettingsNotifier.new);
