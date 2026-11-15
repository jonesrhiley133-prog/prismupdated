import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'package:prism_plurality/features/prism_social/social_device_notifications.dart';
import 'package:prism_plurality/app.dart';
import 'package:prism_plurality/core/database/app_database.dart';
import 'package:prism_plurality/core/database/database_encryption.dart';
import 'package:prism_plurality/core/database/database_provider.dart';
import 'package:prism_plurality/core/database/platform/web_database.dart';
import 'package:prism_plurality/core/services/error_reporting_service.dart';
import 'package:prism_plurality/core/web/render_mode.dart';
import 'package:prism_plurality/core/services/notification_providers.dart';
import 'package:prism_plurality/core/services/reminder_scheduler_service.dart';
import 'package:prism_plurality/core/services/screen_privacy_controller.dart';
import 'package:prism_plurality/core/sync/prism_sync_providers.dart';
import 'package:prism_plurality/features/calendar/services/calendar_notification_service.dart';
import 'package:prism_plurality/features/habits/providers/habit_providers.dart';

/// Browser entry point (used when `kIsWeb`).
///
/// The web build is a local-only development/preview build:
/// * data lives in the browser (Drift + WASM SQLite), unencrypted;
/// * the Rust sync engine and secure-storage keychain are not started, so
///   pairing and sync are unavailable;
/// * local notifications (reminders, habits, calendar alerts) are off.
///
/// Everything else (members, fronting, chat, mood, calendar, notes, …) runs
/// against the same Drift schema as the native apps.
Future<void> runWebApp() async {
  markWebStage('dart');
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    reportWebError(details.exceptionAsString());
    ErrorReportingService.instance.report(
      details.exceptionAsString(),
      stackTrace: details.stack,
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[Prism] Uncaught error: $error\n$stack');
    reportWebError(error.toString());
    ErrorReportingService.instance.report(error.toString(), stackTrace: stack);
    return true;
  };

  try {
    tz.initializeTimeZones();
  } catch (e) {
    debugPrint('[WEB_BOOT] Timezone init failed (non-fatal): $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        // No keychain or SQLCipher in the browser: a placeholder key satisfies
        // the throw-by-default startup provider and is never used.
        verifiedStartupKeyProvider.overrideWithValue('web'),
        databaseSchemaVersionBeforeOpenProvider.overrideWith(
          (ref) async => null,
        ),
        databaseProvider.overrideWith((ref) {
          final db = AppDatabase(openWebDatabase());
          ref.onDispose(db.close);
          return db;
        }),
        primaryDatabaseKeyRepairProvider.overrideWithValue(
          (_) async => PrimaryDatabaseKeyRepairOutcome.skippedNoDatabase,
        ),
        // Sync engine (Rust FFI) is not available on the web.
        prismSyncHandleProvider.overrideWithBuild((ref, notifier) => null),
        syncEventStreamProvider.overrideWith((ref) => const Stream.empty()),
        // Local notifications are not supported in the browser.
        reminderSchedulerListenerProvider.overrideWithValue(null),
        habitNotificationListenerProvider.overrideWithValue(null),
        calendarNotificationListenerProvider.overrideWithValue(null),
        socialNotificationListenerProvider.overrideWithValue(null),
        frontingReminderListenerProvider.overrideWithValue(null),
        screenPrivacyControllerProvider.overrideWithValue(null),
      ],
      child: const PrismApp(),
    ),
  );
}
