import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:prism_plurality/features/account/account_core.dart';
import 'package:prism_plurality/features/smart_notifications/notify_service.dart';
import 'package:prism_plurality/features/members/studio/profile_config.dart';
import 'package:prism_plurality/shared/theme/theme_variants.dart';
import 'package:prism_plurality/features/music/services/music_library.dart';
import 'package:prism_plurality/core/diagnostics/perf_probe.dart';
import 'package:prism_plurality/features/music/services/music_player.dart';
import 'package:prism_plurality/core/web/render_mode.dart';
import 'package:prism_plurality/features/prism_social/social_device_notifications.dart';
import 'package:prism_plurality/features/prism_social/social_remote.dart'
    show socialSyncProvider;
import 'package:prism_plurality/features/dictionary/importer/import_job.dart'
    show importJobProvider;
import 'package:prism_plurality/features/fitness/health/health_sync.dart'
    show healthAutoSyncProvider;
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/features/music/views/mini_player.dart';
import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/features/accessibility/a11y_settings.dart';
import 'package:prism_plurality/features/accessibility/a11y_theme.dart';
import 'package:prism_plurality/features/app_update/app_update_provider.dart';
import 'package:prism_plurality/features/fronting_roles/roles_data.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/fronting/providers/fronting_providers.dart';
import 'package:prism_plurality/features/launch/launch_overlay.dart';
import 'package:prism_plurality/features/launch/launch_settings.dart';
import 'package:prism_plurality/features/appearance/services/appearance_store.dart';
import 'package:prism_plurality/shared/theme/look_theme.dart';
import 'package:prism_plurality/features/social/services/social_onboarding.dart';
import 'package:prism_plurality/features/automations/automation_engine.dart';
import 'package:prism_plurality/features/connections/connections_screens.dart'
    show registerConnOpeners;
import 'package:prism_plurality/features/demo/demo_mode_screen.dart'
    show DemoBanner;
import 'package:prism_plurality/features/dreams/dream_journal.dart'
    show registerDreamOpener;
import 'package:prism_plurality/features/habits/center/habit_center_services.dart'
    show habitCenterBootProvider;
import 'package:prism_plurality/features/relationships/hub/rel_profile.dart'
    show relRoute;
import 'package:prism_plurality/features/subsystems/hub/subsystem_data.dart'
    show isolationSyncProvider;
import 'package:prism_plurality/features/subsystems/hub/subsystem_profile.dart'
    show subsystemFrontNotifierProvider;
import 'package:prism_plurality/features/habits/center/habit_sheets.dart'
    show openHabitCompletion;
import 'package:prism_plurality/features/links/models/record_ref.dart'
    show RecordRef;
import 'package:prism_plurality/features/links/views/record_opener.dart'
    show recordKindOpeners, recordTypeOpeners;
import 'package:prism_plurality/features/nutrition/nutrition_meals.dart'
    show registerNutritionOpeners;
import 'package:prism_plurality/features/scrapbook/scrapbook_screens.dart'
    show registerScrapOpeners;
import 'package:prism_plurality/features/home_widgets/services/home_widget_controller.dart';
import 'package:prism_plurality/features/fronting_notification/services/fronting_notification_actions.dart';
import 'package:prism_plurality/features/fronting_notification/services/fronting_notification_controller.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_sync/generated/api.dart' as ffi;
import 'core/database/app_database.dart';
import 'core/database/database_providers.dart' show memberRepositoryProvider;
import 'package:prism_plurality/features/astro/data/astro_model.dart';
import 'package:prism_plurality/features/astro/engine/chart.dart'
    show BirthPlace;
import 'core/database/database_encryption.dart';
import 'core/database/database_provider.dart';
import 'core/diagnostics/main_isolate_stalls.dart';
import 'core/router/app_router.dart';
import 'core/router/notification_navigation_providers.dart';
import 'core/services/media/bio_media_reconciler.dart';
import 'core/services/media/media_heal_providers.dart';
import 'core/services/media/media_providers.dart';
import 'core/services/media/orphan_media_reconciler.dart';
import 'core/services/notification_providers.dart';
import 'core/services/local_notification_service.dart';
import 'core/services/reminder_scheduler_service.dart';
import 'core/services/screen_privacy_controller.dart';
import 'core/sync/prism_sync_providers.dart';
import 'features/pluralkit/providers/pk_sync_event_log_provider.dart';
import 'features/fronting/migration/providers/fronting_migration_providers.dart';
import 'features/fronting/providers/fronting_session_repair_provider.dart';
import 'features/calendar/services/calendar_notification_service.dart';
import 'features/habits/providers/habit_providers.dart';
import 'features/onboarding/providers/onboarding_providers.dart';
import 'domain/models/system_settings.dart';
import 'domain/preferences/preference_registry.dart';
import 'features/settings/providers/settings_providers.dart';
import 'shared/theme/app_colors.dart';
import 'shared/theme/app_icons.dart';
import 'shared/providers/accessibility_preferences_provider.dart';
import 'shared/theme/app_theme.dart';
import 'shared/theme/prism_text_scaler.dart';
import 'shared/theme/prism_shapes.dart' as ui_shapes;
import 'shared/widgets/prism_button.dart';
import 'shared/widgets/prism_keyboard_dismiss_scope.dart';
import 'shared/widgets/prism_spinner.dart';
import 'shared/widgets/prism_toast.dart';

const _databaseStartupStatusDelay = Duration(milliseconds: 500);

final _databaseStartupStatusDelayProvider = FutureProvider.autoDispose<void>((
  ref,
) {
  final completer = Completer<void>();
  final timer = Timer(_databaseStartupStatusDelay, completer.complete);
  ref.onDispose(timer.cancel);
  return completer.future;
});

class PrismApp extends ConsumerStatefulWidget {
  const PrismApp({super.key});

  @override
  ConsumerState<PrismApp> createState() => _PrismAppState();
}

class _PrismAppState extends ConsumerState<PrismApp> {
  late final AppLifecycleListener _appLifecycleListener;
  Timer? _updateCheckTimer;
  Timer? _whosThereTimer;
  GoRouter? _watchedRouter;
  String _lastPath = '';
  bool _ranOrphanMediaReconcile = false;
  bool _ranBioMediaReconcile = false;
  bool _ranMediaHydration = false;
  bool _ranPrimaryDatabaseKeyRepair = false;

  @override
  void initState() {
    super.initState();
    _appLifecycleListener = AppLifecycleListener(
      onResume: _onResume,
      // Lets the next cold start know whether it's a quick reopen.
      onPause: () => unawaited(LaunchBoot.noteClosed()),
    );
    // Look for app updates shortly after launch (Android builds that know
    // their release feed; a no-op elsewhere), whichever screen opens first.
    // Who's There: after the launch animation, on resume, and when returning
    // to Home.
    _scheduleWhosThere(const Duration(milliseconds: 3500));
    _updateCheckTimer = Timer(const Duration(seconds: 8), () {
      if (mounted)
        unawaited(ref.read(appUpdateNotifierProvider.notifier).autoCheck());
    });
    if (kPerfMode) {
      PerfProbe.register('go', (path) {
        ref.read(routerProvider).go(path);
        return 'ok';
      });
      PerfProbe.register('push', (path) {
        unawaited(ref.read(routerProvider).push(path));
        return 'ok';
      });
      PerfProbe.register('playMusic', (_) {
        unawaited(() async {
          // The library loads lazily (normally when Music opens).
          await ref.read(musicLibraryProvider.future);
          await ref.read(musicControllerProvider.notifier).playTracks([
            'perf-track',
          ]);
        }());
        return 'ok';
      });
      PerfProbe.register('musicState', (_) {
        final st = ref.read(musicControllerProvider);
        return 'playing=${st.playing} loaded=${st.loaded} id=${st.currentId}';
      });
      PerfProbe.register('banners', (on) {
        unawaited(
          ref
              .read(appearanceProvider.notifier)
              .setShowMemberBanners(on == 'on'),
        );
        return 'ok';
      });
      PerfProbe.register('brightness', (v) {
        unawaited(
          ref
              .read(settingsNotifierProvider.notifier)
              .updateThemeBrightness(ThemeBrightness.values.byName(v)),
        );
        return 'ok';
      });
      PerfProbe.register('style', (v) {
        unawaited(
          ref
              .read(settingsNotifierProvider.notifier)
              .updateThemeStyle(ThemeStyle.values.byName(v)),
        );
        return 'ok';
      });
      PerfProbe.register('mood', (v) {
        final n = ref.read(settingsNotifierProvider.notifier);
        unawaited(() async {
          await n.updatePaletteSource(PaletteSource.custom);
          await n.updatePaletteMood(PaletteMood.values.byName(v));
        }());
        return 'ok';
      });
      PerfProbe.register('pageMode', (arg) {
        // arg: "<memberId> <app|light|medium|dark>"
        final parts = arg.split(' ');
        final cfg =
            ref.read(memberProfileProvider(parts[0])) ?? ProfileConfig.empty();
        unawaited(
          ref
              .read(profileStudioActionsProvider)
              .saveProfile(
                parts[0],
                cfg.withLook('pageMode', parts[1] == 'app' ? null : parts[1]),
              ),
        );
        return 'ok';
      });
      PerfProbe.register('route', (_) {
        return ref.read(routerProvider).state.uri.toString();
      });
      PerfProbe.register('astroSeed', (_) {
        // Birth details for a few stress-fixture alters (harness only).
        unawaited(() async {
          const seeds = [
            (
              'stress-member-0',
              '1994-02-03',
              14,
              20,
              'London',
              51.507,
              -0.128,
              'Europe/London',
              'system',
            ),
            (
              'stress-member-1',
              '1988-10-12',
              7,
              5,
              'New York City',
              40.713,
              -74.006,
              'America/New_York',
              'system',
            ),
            (
              'stress-member-2',
              '2001-07-28',
              null,
              null,
              null,
              null,
              null,
              null,
              'system',
            ),
            (
              'stress-member-3',
              '1979-05-15',
              22,
              40,
              'Madrid',
              40.417,
              -3.704,
              'Europe/Madrid',
              'shareable',
            ),
            (
              'stress-member-4',
              '0004-12-01',
              null,
              null,
              null,
              null,
              null,
              null,
              'private',
            ),
          ];
          final members = ref.read(membersNotifierProvider.notifier);
          final repo = ref.read(memberRepositoryProvider);
          for (final x in seeds) {
            final m = await repo.getMemberById(x.$1);
            if (m == null) continue;
            await members.updateMember(m.copyWith(birthday: x.$2));
            final existing = ref.read(astroProfilesProvider)[x.$1];
            await ref
                .read(astroActionsProvider)
                .saveProfile(
                  (existing ?? AstroProfile(memberId: x.$1)).copyWith(
                    hour: x.$3,
                    minute: x.$4,
                    place: x.$5 == null
                        ? null
                        : BirthPlace(
                            name: x.$5!,
                            lat: x.$6!,
                            lon: x.$7!,
                            timeZone: x.$8!,
                          ),
                    visibility: AstroVisibility.parse(x.$9),
                  ),
                );
          }
        }());
        return 'ok';
      });
      String? sampleIds;
      PerfProbe.register('ids', (_) {
        // First call starts the lookup; call again for "table=id" lines.
        if (sampleIds != null) return sampleIds!;
        unawaited(() async {
          final db = ref.read(databaseProvider);
          final out = <String>[];
          for (final t in [
            'members',
            'conversations',
            'habits',
            'polls',
            'notes',
            'fronting_sessions',
            'member_groups',
            'custom_fields',
            'sleep_sessions',
            'member_board_posts',
          ]) {
            try {
              final rows = await db
                  .customSelect('SELECT id FROM $t LIMIT 1')
                  .get();
              if (rows.isNotEmpty) out.add('$t=${rows.first.data['id']}');
            } catch (_) {}
          }
          sampleIds = out.join('\n');
        }());
        return 'pending';
      });
      PerfProbe.register('routes', (_) {
        // Every page path, for the harness's page-by-page checks.
        final out = <String>[];
        void walk(List<RouteBase> routes, String parent) {
          for (final r in routes) {
            if (r is GoRoute) {
              final full = r.path.startsWith('/')
                  ? r.path
                  : '${parent == '/' ? '' : parent}/${r.path}';
              out.add(full);
              walk(r.routes, full);
            } else if (r is ShellRouteBase) {
              walk(r.routes, parent);
            }
          }
        }

        walk(ref.read(routerProvider).configuration.routes, '');
        return out.join('\n');
      });
    }
  }

  /// Run the on-disk media cache sweep exactly once per app launch, after
  /// `prismSyncHandleProvider` has resolved (so we don't race a still-loading
  /// sync layer materializing inbound media). Fires regardless of whether
  /// the handle is null (no sync configured) or non-null (sync up) — both
  /// states mean the sync layer is finished with its first init pass.
  void _maybeRunOrphanMediaReconcile(
    AsyncValue<ffi.PrismSyncHandle?>? previous,
    AsyncValue<ffi.PrismSyncHandle?> next,
  ) {
    if (_ranOrphanMediaReconcile) return;
    if (next is AsyncLoading) return;
    _ranOrphanMediaReconcile = true;
    unawaited(
      runOrphanMediaReconcileFromRef(ref).catchError((Object e) {
        // runOrphanMediaReconcileFromRef already swallows + logs internally;
        // this catchError is a final safety net so a programmer bug in the
        // reconcile path can never crash app startup.
        debugPrint('Orphan media reconcile threw out (non-fatal): $e');
        return 0;
      }),
    );
  }

  /// Run the bio-media orphan sweep exactly once per app launch, after
  /// `prismSyncHandleProvider` has resolved (so we don't race the sync layer
  /// materializing inbound bio-media). Catches orphaned bio `media_attachments`
  /// rows missed by the on-save hook in add_edit_member_sheet.dart.
  void _maybeRunBioMediaReconcile(
    AsyncValue<ffi.PrismSyncHandle?>? previous,
    AsyncValue<ffi.PrismSyncHandle?> next,
  ) {
    if (_ranBioMediaReconcile) return;
    if (next is AsyncLoading) return;
    _ranBioMediaReconcile = true;
    unawaited(
      runBioMediaReconcileFromRef(ref).catchError((Object e) {
        // runBioMediaReconcileFromRef already swallows + logs internally;
        // this catchError is a final safety net so a programmer bug in the
        // reconcile path can never crash app startup.
        debugPrint('Bio media reconcile threw out (non-fatal): $e');
        return 0;
      }),
    );
  }

  /// Kick off eager media hydration once per launch, after
  /// `prismSyncHandleProvider` has finished its first resolve. Walks every
  /// non-deleted `media_attachments` row and background-downloads any blob not
  /// already cached. This covers relaunch + reinstall of an already-paired
  /// device (its rows are in the local DB at startup); a *fresh* pair is
  /// covered separately by the post-sync-batch trigger in syncEventStreamProvider
  /// once the snapshot's rows commit. Fire-and-forget and self-swallowing.
  void _maybeRunMediaHydration(
    AsyncValue<ffi.PrismSyncHandle?>? previous,
    AsyncValue<ffi.PrismSyncHandle?> next,
  ) {
    if (_ranMediaHydration) return;
    if (next is AsyncLoading) return;
    _ranMediaHydration = true;
    unawaited(
      runMediaHydrationFromRef(ref).catchError((Object e) {
        // runMediaHydrationFromRef already swallows + logs internally; this
        // catchError is a final safety net so a programmer bug in the
        // hydration path can never crash app startup.
        debugPrint('Media hydration startup walk threw out (non-fatal): $e');
      }),
    );
  }

  @override
  void dispose() {
    _updateCheckTimer?.cancel();
    _whosThereTimer?.cancel();
    _watchedRouter?.routerDelegate.removeListener(_onRouteChanged);
    _appLifecycleListener.dispose();
    super.dispose();
  }

  void _watchRouter() {
    if (!mounted) return;
    try {
      final r = ref.read(routerProvider);
      if (identical(r, _watchedRouter)) return;
      _watchedRouter?.routerDelegate.removeListener(_onRouteChanged);
      _watchedRouter = r..routerDelegate.addListener(_onRouteChanged);
    } catch (_) {}
  }

  void _onRouteChanged() {
    final c = _watchedRouter?.routerDelegate.currentConfiguration;
    final path = c == null || c.isEmpty ? '' : c.uri.path;
    if (path == AppRoutePaths.home && _lastPath != AppRoutePaths.home)
      _scheduleWhosThere(const Duration(milliseconds: 600));
    _lastPath = path;
  }

  void _scheduleWhosThere(Duration delay) {
    _whosThereTimer?.cancel();
    _whosThereTimer = Timer(delay, _maybeShowWhosThere);
  }

  /// Shows Who's There when it's due — only on Home, with nothing open on
  /// top and no text being typed, so it never interrupts an activity.
  void _maybeShowWhosThere({int retries = 3}) {
    if (!mounted) return;
    try {
      if (!ref.read(databaseReadyProvider).hasValue) {
        if (retries > 0)
          _whosThereTimer = Timer(
            const Duration(seconds: 2),
            () => _maybeShowWhosThere(retries: retries - 1),
          );
        return;
      }
      _watchRouter();
      // Wait until role data has loaded, so defaults never trigger it early.
      final settingsLoaded = ref
          .read(trackerKindProvider(TrackerKind.frontRoleSettings))
          .hasValue;
      final sessionsLoaded = ref.read(activeSessionsProvider).hasValue;
      final membersLoaded = ref.read(userVisibleMembersProvider).hasValue;
      if (!settingsLoaded || !sessionsLoaded || !membersLoaded) {
        if (retries > 0)
          _whosThereTimer = Timer(
            const Duration(seconds: 2),
            () => _maybeShowWhosThere(retries: retries - 1),
          );
        return;
      }
      if ((ref.read(userVisibleMembersProvider).value ?? const []).isEmpty)
        return;
      if (!whosThereDue(
        settings: ref.read(roleSettingsProvider),
        lastChange: ref.read(lastFrontingChangeProvider),
        now: DateTime.now(),
      ))
        return;
      final router = ref.read(routerProvider);
      final c = router.routerDelegate.currentConfiguration;
      if (c.isEmpty || c.uri.path != AppRoutePaths.home || router.canPop())
        return;
      final focus = FocusManager.instance.primaryFocus?.context;
      if (focus != null &&
          (focus.widget is EditableText ||
              focus.findAncestorWidgetOfExactType<EditableText>() != null))
        return;
      router.push(AppRoutePaths.whosThere);
    } catch (_) {}
  }

  void _onResume() {
    MainIsolateStalls.mark('resume');
    _scheduleWhosThere(const Duration(milliseconds: 800));
    // At most every few hours (see AppUpdateNotifier.autoCheckInterval).
    unawaited(ref.read(appUpdateNotifierProvider.notifier).autoCheck());
    ref.read(localNotificationServiceProvider).refreshDesktopSchedules();
    if (!ref.read(databaseReadyProvider).hasValue) return;
    _repairPrimaryDatabaseKeySlotOnce();
    final handle = ref.read(prismSyncHandleProvider).value;
    if (handle == null) return;
    final health = ref.read(syncHealthProvider);
    if (!shouldAutoReconnectWebsocketOnResume(health)) {
      return;
    }

    // Re-establish the WebSocket if it dropped while backgrounded,
    // resetting the exponential backoff for an immediate reconnect.
    ffi.reconnectWebsocket(handle: handle).catchError((e) {
      debugPrint('WebSocket reconnect on resume failed (non-fatal): $e');
    });

    // Only nudge the sync engine when it's actually configured. Calling
    // onResume before pairing / unlock produces `sync not configured` error
    // spam that's not actionable. `reconnecting` is a transient sibling of
    // `healthy` (credentials + relay config intact), so we nudge in both.
    if (health == SyncHealthState.healthy ||
        health == SyncHealthState.reconnecting) {
      unawaited(_nudgeSyncOnResume(handle));
    }
  }

  /// Nudge the sync engine on resume, self-healing a failed `onResume`.
  ///
  /// A failed `onResume` must NEVER drop to the destructive "Set up sync again"
  /// UI, and must not strand the engine "Relay not configured" (which breaks
  /// every media download → "Image expired"). On failure we surface the real
  /// cause (the engine now captures the masked iOS resume panic), mark a
  /// transient `reconnecting`, re-read `relay_url` + rebuild the relay via
  /// `configureEngine`, and retry once. Credentials + relay config are always
  /// preserved; the auto-sync driver and the next resume keep retrying.
  Future<void> _nudgeSyncOnResume(ffi.PrismSyncHandle handle) {
    return runResumeSyncNudge(
      onResume: () => ffi.onResume(handle: handle),
      configureEngine: () => ffi.configureEngine(handle: handle),
      triggerSync: () => unawaited(triggerSync(handle)),
      takeLastPanic: ffi.takeLastPanic,
      readHealth: () => ref.read(syncHealthProvider),
      setHealth: (state) =>
          ref.read(syncHealthProvider.notifier).setState(state),
    );
  }

  void _repairPrimaryDatabaseKeySlotOnce() {
    if (_ranPrimaryDatabaseKeyRepair) return;
    _ranPrimaryDatabaseKeyRepair = true;
    _repairPrimaryDatabaseKeySlot();
  }

  void _repairPrimaryDatabaseKeySlot() {
    String? verifiedStartupKey;
    Future<PrimaryDatabaseKeyRepairOutcome> Function(String?) repair;
    try {
      verifiedStartupKey = ref.read(verifiedStartupKeyProvider);
      repair = ref.read(primaryDatabaseKeyRepairProvider);
    } catch (_) {
      return;
    }
    unawaited(_repairPrimaryDatabaseKeySlotAsync(verifiedStartupKey, repair));
  }

  Future<void> _repairPrimaryDatabaseKeySlotAsync(
    String? verifiedStartupKey,
    Future<PrimaryDatabaseKeyRepairOutcome> Function(String?) repair,
  ) async {
    try {
      await repair(verifiedStartupKey);
    } catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: st,
          library: 'prism_plurality',
          context: ErrorDescription(
            'repairing primary database key slot from verified memory',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(notificationTapBootstrapProvider);
    final databaseReady = ref.watch(databaseReadyProvider);
    if (!databaseReady.hasValue) {
      return _DatabaseStartupApp(databaseReady: databaseReady);
    }
    _repairPrimaryDatabaseKeySlotOnce();

    // Start sheet preferences before the first user-opened sheet.
    ref.watch(dimBackgroundBehindSheetsProvider);
    ref.watch(forceCenteredSheetsProvider);

    // Run the orphan-media reconcile pass once `prismSyncHandleProvider`
    // has finished its first resolve. Picks up `.enc` files stranded by a
    // crash mid-_resetChat / _resetAll (DB rows deleted, OS killed the
    // process before the file-loop completed). Startup-only sweep.
    ref.listen(prismSyncHandleProvider, _maybeRunOrphanMediaReconcile);
    // Cover the case where the provider was already resolved before this
    // build ran — the listener above won't fire for a cached value, so we
    // peek at the current state and trigger directly.
    _maybeRunOrphanMediaReconcile(null, ref.read(prismSyncHandleProvider));

    // Run the bio-media orphan sweep once per launch, after the sync layer
    // has finished its first init pass (same timing rationale as above).
    ref.listen(prismSyncHandleProvider, _maybeRunBioMediaReconcile);
    _maybeRunBioMediaReconcile(null, ref.read(prismSyncHandleProvider));

    // Eagerly hydrate referenced media in the background once the sync layer
    // has finished its first init pass. Fixes "I paired a new device and all
    // my media is missing": without this, a device only fetches a blob when
    // the user happens to scroll its image into view.
    ref.listen(prismSyncHandleProvider, _maybeRunMediaHydration);
    _maybeRunMediaHydration(null, ref.read(prismSyncHandleProvider));

    // Keep the FFI event stream alive for the lifetime of the app.
    ref.listen(syncEventStreamProvider, (_, _) {});
    // Drive the media heal heal loop (media heal): respond to peers' media_request,
    // re-download re-supplied blobs, and run the missing-media cadence each pull.
    ref.listen(mediaHealReactorProvider, (_, _) {});
    // Keep the diagnostic event buffer alive for the lifetime of the app.
    ref.listen(syncEventLogProvider, (previous, next) {});
    // Keep the PluralKit sync log notifier subscribed so events emitted
    // before the user opens the PK debug screen are still recorded.
    ref.listen(pkSyncEventLogProvider, (_, _) {});
    // Keep the reminder scheduler alive — reschedules on reminder/front changes.
    ref.listen(reminderSchedulerListenerProvider, (previous, next) {});
    // Keep the habit notification listener alive — reschedules on habit changes.
    ref.listen(habitNotificationListenerProvider, (_, _) {});
    // Keep calendar event alerts armed — reschedules on event changes.
    ref.listen(calendarNotificationListenerProvider, (_, _) {});
    // Birthdays, holidays and horoscopes.
    ref.listen(smartNotificationListenerProvider, (_, _) {});
    // Optional account: daily encrypted backup when switched on.
    ref.listen(autoBackupListenerProvider, (_, _) {});
    ref.listen(socialNotificationListenerProvider, (_, _) {});
    ref.listen(socialSyncProvider, (_, _) {});
    // Resumes a Dictionary wiki import that was running when Prism closed.
    ref.listen(importJobProvider, (_, _) {});
    // Keep the fronting reminder listener alive — schedules/cancels based on settings.
    ref.listen(frontingReminderListenerProvider, (_, _) {});
    // Keep the live fronting notification in step with the front.
    ref.listen(frontingNotificationListenerProvider, (_, _) {});
    ref.listen(frontingNotificationActionsProvider, (_, _) {});
    ref.listen(homeWidgetListenerProvider, (_, _) {});
    ref.listen(homeWidgetSyncProvider, (_, _) {});
    // Appearance and accessibility follow the user across devices.
    ref.listen(appearanceSyncProvider, (_, _) {});
    ref.listen(a11ySyncProvider, (_, _) {});
    // The one app-wide music controller lives as long as the app.
    ref.listen(musicControllerProvider, (_, _) {});
    // One-time: make the Bulletin Board and Stories easy to find.
    ref.listen(socialOnboardingProvider, (_, _) {});
    ref.listen(automationBootProvider, (_, _) {});
    ref.listen(habitCenterBootProvider, (_, _) {});
    ref.listen(subsystemFrontNotifierProvider, (_, _) {});
    ref.listen(isolationSyncProvider, (_, _) {});
    ref.listen(healthAutoSyncProvider, (_, _) {});
    registerAdvancedRecordOpeners();
    // Keep frontingMigrationModeProvider always-warm. The sync apply path
    // reads `frontingMigrationWritesBlockedProvider` per row inside a
    // `db.transaction(...)` (drift_sync_adapter.dart `_frontingSessionsEntity`
    // → `applyGate`). That read traverses
    // `frontingMigrationWritesBlockedProvider` →
    // `frontingMigrationGateProvider` → `frontingMigrationModeProvider`, and
    // the last one is a StreamProvider whose build callback synchronously
    // calls `systemSettingsDao.watchSettings()`. If the chain is cold when
    // the apply transaction reads it, that Drift call fires from INSIDE the
    // open transaction and deadlocks Drift's commit-result message on the
    // background isolate (verified 2026-05-03 on Pixel 6 Pro fresh-install
    // pairing). Building it here guarantees the chain is warm before any
    // sync apply runs. Do not remove without re-testing fresh-install pairing.
    ref.listen(frontingMigrationModeProvider, (_, _) {});
    // Run the one-time open-session repair once per device, after sync is
    // configured + healthy and the fronting migration is complete. Collapses
    // duplicate open sessions and merges overlapping same-member rows through
    // the sync layer so peers converge. Idempotent; no-ops on later launches.
    ref.listen(frontingOpenSessionRepairBootstrapProvider, (_, _) {});
    // Trigger the SP boards backfill once on first launch after v15 upgrade.
    // The provider is gated on spBoardsBackfilledAt == null and is a no-op on
    // all subsequent launches. Fire-and-forget — errors are non-fatal.
    ref.listen(spBoardsBackfillProvider, (_, _) {});
    // Repair legacy SP-imported replies whose quote snapshot was missing.
    // Candidate-gated; later launches no-op after affected rows are fixed.
    ref.listen(spReplyQuoteBackfillProvider, (_, _) {});
    // Keep the screen-privacy controller warm so the Settings → Privacy
    // & Security toggle is mirrored to the platform secure-display flag
    // for the lifetime of the app.
    ref.listen(screenPrivacyControllerProvider, (_, _) {});

    final router = ref.watch(routerProvider);
    var brightness = ref.watch(themeBrightnessProvider);
    var style = ref.watch(effectiveThemeStyleProvider);
    var cornerStyle = ref.watch(cornerStyleProvider);

    // Resolve the user's accent color and font settings from narrow providers.
    var accentHex = ref.watch(accentColorHexProvider);
    final paletteSource = ref.watch(paletteSourceProvider);
    final paletteSeedColorHex = ref.watch(paletteSeedColorHexProvider);
    final paletteMood = ref.watch(paletteMoodProvider);
    final paletteContrast = ref.watch(paletteContrastProvider);
    final paletteCustom = ref.watch(customPaletteAccentsProvider);
    final onboardingAppearance = ref.watch(
      onboardingProvider.select(
        (state) => (
          active: state.hasAppearancePreview,
          accentColorHex: state.hasAccentColorPreview
              ? state.accentColorHex
              : null,
          brightness: state.hasThemeBrightnessPreview
              ? state.themeBrightness
              : null,
          style: state.hasThemeStylePreview ? state.themeStyle : null,
          cornerStyle: state.hasCornerStylePreview ? state.cornerStyle : null,
        ),
      ),
    );
    if (onboardingAppearance.active) {
      accentHex = onboardingAppearance.accentColorHex ?? accentHex;
      brightness = onboardingAppearance.brightness ?? brightness;
      final draftStyle = onboardingAppearance.style;
      if (draftStyle != null) {
        style = effectiveThemeStyleForPlatform(
          draftStyle,
          ref.watch(targetPlatformProvider),
        );
      }
      final draftCornerStyle = onboardingAppearance.cornerStyle;
      if (draftCornerStyle != null) {
        cornerStyle = ui_shapes.CornerStyle.values[draftCornerStyle.index];
      }
    }
    final accentColor = accentHex != null
        ? AppColors.fromHex(accentHex)
        : AppColors.prismPurple;

    final fontFamily = ref.watch(fontFamilySettingProvider);
    final useDisplayFont = ref.watch(displayFontInAppBarProvider);
    final rawFontScale = ref.watch(fontScaleSettingProvider);
    final letterSpacing =
        ref
            .watch(typographyLetterSpacingProvider)
            .whenOrNull(data: (value) => value) ??
        typographyLetterSpacingPreference.defaultValue;
    final appFontFamily = fontFamily.assetFontFamily;
    final a11y = ref.watch(a11ySettingsProvider);
    final lightLook = ref.watch(activeLookProvider(false));
    final darkLook = ref.watch(activeLookProvider(true));
    final backgroundDir = ref.watch(backgroundsDirProvider).value?.path;
    final fontScale = rawFontScale
        .clamp(fontFamily.minimumScale, fontFamily.maximumScale)
        .toDouble();

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        // The whole pipeline (style, fonts, accessibility, looks) for one
        // light/dark pair. [medium] swaps the dark side for the medium tone.
        (ThemeData, ThemeData) buildPair({required bool medium}) {
          ThemeData lightTheme;
          ThemeData darkTheme;

          switch (style) {
            case ThemeStyle.materialYou:
              lightTheme = AppTheme.materialYouLight(
                lightDynamic,
                cornerStyle: cornerStyle,
                paletteSource: paletteSource,
                paletteSeedColorHex: paletteSeedColorHex,
                paletteMood: paletteMood,
                paletteContrast: paletteContrast,
                paletteCustom: paletteCustom,
              );
              darkTheme = medium
                  ? AppTheme.materialYouMedium(
                      darkDynamic,
                      lightDynamic,
                      cornerStyle: cornerStyle,
                      paletteSource: paletteSource,
                      paletteSeedColorHex: paletteSeedColorHex,
                      paletteMood: paletteMood,
                      paletteContrast: paletteContrast,
                      paletteCustom: paletteCustom,
                    )
                  : AppTheme.materialYouDark(
                      darkDynamic,
                      cornerStyle: cornerStyle,
                      paletteSource: paletteSource,
                      paletteSeedColorHex: paletteSeedColorHex,
                      paletteMood: paletteMood,
                      paletteContrast: paletteContrast,
                      paletteCustom: paletteCustom,
                    );
            case ThemeStyle.oled:
              lightTheme = AppTheme.light(
                accentColor: accentColor,
                cornerStyle: cornerStyle,
              );
              // OLED is about true black; the medium tone replaces it.
              darkTheme = medium
                  ? AppTheme.medium(
                      accentColor: accentColor,
                      cornerStyle: cornerStyle,
                    )
                  : AppTheme.oled(
                      accentColor: accentColor,
                      cornerStyle: cornerStyle,
                    );
            case ThemeStyle.standard:
              lightTheme = AppTheme.light(
                accentColor: accentColor,
                cornerStyle: cornerStyle,
              );
              darkTheme = medium
                  ? AppTheme.medium(
                      accentColor: accentColor,
                      cornerStyle: cornerStyle,
                    )
                  : AppTheme.dark(
                      accentColor: accentColor,
                      cornerStyle: cornerStyle,
                    );
          }

          // Strip Unbounded from display/headline roles when the user opts out.
          if (!useDisplayFont) {
            lightTheme = AppTheme.withoutDisplayFont(lightTheme);
            darkTheme = AppTheme.withoutDisplayFont(darkTheme);
          }

          if (appFontFamily != null) {
            lightTheme = AppTheme.withAppFontFamily(
              lightTheme,
              appFontFamily,
              preserveDisplayFont: useDisplayFont,
            );
            darkTheme = AppTheme.withAppFontFamily(
              darkTheme,
              appFontFamily,
              preserveDisplayFont: useDisplayFont,
            );
          }

          if (letterSpacing != 0.0) {
            lightTheme = AppTheme.withLetterSpacing(lightTheme, letterSpacing);
            darkTheme = AppTheme.withLetterSpacing(darkTheme, letterSpacing);
          }

          // Light, GPU-friendly page transitions on Android (the zoom
          // transition renders whole pages into offscreen layers).
          const transitions = PageTransitionsTheme(
            builders: {
              TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
              // Desktop and the web on Windows/Linux get the same animated
              // transition instead of the heavier default zoom.
              TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
              TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
              TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
            },
          );
          lightTheme = lightTheme.copyWith(pageTransitionsTheme: transitions);
          darkTheme = darkTheme.copyWith(pageTransitionsTheme: transitions);

          // Accessibility first (colour-vision palette, contrast, spacing),
          // then the appearance preset on top.
          lightTheme = applyAccessibility(lightTheme, a11y);
          darkTheme = applyAccessibility(darkTheme, a11y);
          final lightBase = lightTheme;
          final darkBase = darkTheme;
          lightTheme = applyLook(
            lightBase,
            lightLook,
            opposite: darkBase,
            reduceTransparency: a11y.reduceTransparency || a11y.highContrast,
            reduceEffects: a11y.reduceEffects,
            backgroundDir: backgroundDir,
          );
          darkTheme = applyLook(
            darkBase,
            darkLook,
            opposite: lightBase,
            reduceTransparency: a11y.reduceTransparency || a11y.highContrast,
            reduceEffects: a11y.reduceEffects,
            backgroundDir: backgroundDir,
          );
          return (lightTheme, darkTheme);
        }

        final appMedium = brightness == ThemeBrightness.medium;
        final (lightTheme, darkTheme) = buildPair(medium: appMedium);
        // Other tones for pages that pick their own (alter profiles); built
        // only when such a page asks.
        final variants = PrismThemeVariants(
          light: lightTheme,
          dark: appMedium ? () => buildPair(medium: false).$2 : () => darkTheme,
          medium: appMedium
              ? () => darkTheme
              : () => buildPair(medium: true).$2,
          appTone: switch (brightness) {
            ThemeBrightness.light => PageTone.light,
            ThemeBrightness.dark => PageTone.dark,
            ThemeBrightness.medium => PageTone.medium,
            ThemeBrightness.system => null,
          },
        );

        return MaterialApp.router(
          title: 'Prism',
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('es')],
          locale: ref.watch(localeOverrideProvider),
          theme: lightTheme,
          darkTheme: darkTheme,
          // Switch themes in a single frame: a cross-fade made some parts
          // (backgrounds, cards) lag behind the rest.
          themeAnimationDuration: Duration.zero,
          themeMode: switch (brightness) {
            ThemeBrightness.system => ThemeMode.system,
            ThemeBrightness.light => ThemeMode.light,
            // Medium is the dark side of the pair, built with mid tones.
            ThemeBrightness.dark || ThemeBrightness.medium => ThemeMode.dark,
          },
          routerConfig: router,
          builder: (context, child) {
            if (kIsWeb) {
              markWebStage('app');
              // Safari tints its top bar from the page; keep it on-theme.
              setWebChromeColor(
                Theme.of(context).scaffoldBackgroundColor.toARGB32(),
              );
            }
            Widget result = child ?? const SizedBox.shrink();
            if (fontScale != 1.0) {
              result = MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: PrismTextScaler(
                    MediaQuery.textScalerOf(context),
                    fontScale,
                  ),
                ),
                child: result,
              );
            }
            // The player host sits above the navigator so music and its
            // controls survive every page change.
            result = LaunchOverlay(child: result);
            return A11yScope(
              onOpenQuickPanel: () =>
                  router.push(AppRoutePaths.accessibilityQuick),
              child: PrismKeyboardDismissScope(
                child: PrismToastHost(
                  child: MusicPlayerHost(
                    child: DemoBanner(
                      child: _ThemeSwitchObserver(
                        child: PrismThemeVariantsScope(
                          variants: variants,
                          child: result,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class _DatabaseStartupApp extends ConsumerWidget {
  const _DatabaseStartupApp({required this.databaseReady});

  final AsyncValue<DatabaseReadyReport> databaseReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = ref.watch(cachedThemeBrightnessProvider);
    final style = effectiveThemeStyleForPlatform(
      ref.watch(cachedThemeStyleProvider),
      ref.watch(targetPlatformProvider),
    );
    final cornerStyle = ref.watch(cachedCornerStyleProvider);
    final accentHex = ref.watch(cachedAccentColorHexProvider);
    final accentColor = accentHex != null
        ? AppColors.fromHex(accentHex)
        : AppColors.prismPurple;

    final schemaVersionBeforeOpen = ref.watch(
      databaseSchemaVersionBeforeOpenProvider,
    );

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ThemeData lightTheme;
        ThemeData darkTheme;

        switch (style) {
          case ThemeStyle.materialYou:
            lightTheme = AppTheme.materialYouLight(
              lightDynamic,
              cornerStyle: cornerStyle,
            );
            darkTheme = AppTheme.materialYouDark(
              darkDynamic,
              cornerStyle: cornerStyle,
            );
          case ThemeStyle.oled:
            lightTheme = AppTheme.light(
              accentColor: accentColor,
              cornerStyle: cornerStyle,
            );
            darkTheme = AppTheme.oled(
              accentColor: accentColor,
              cornerStyle: cornerStyle,
            );
          case ThemeStyle.standard:
            lightTheme = AppTheme.light(
              accentColor: accentColor,
              cornerStyle: cornerStyle,
            );
            darkTheme = AppTheme.dark(
              accentColor: accentColor,
              cornerStyle: cornerStyle,
            );
        }

        return MaterialApp(
          title: 'Prism',
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('es')],
          theme: lightTheme,
          darkTheme: darkTheme,
          // Switch themes in a single frame: a cross-fade made some parts
          // (backgrounds, cards) lag behind the rest.
          themeAnimationDuration: Duration.zero,
          themeMode: switch (brightness) {
            ThemeBrightness.system => ThemeMode.system,
            ThemeBrightness.light => ThemeMode.light,
            // Medium is the dark side of the pair, built with mid tones.
            ThemeBrightness.dark || ThemeBrightness.medium => ThemeMode.dark,
          },
          home: _DatabaseStartupScreen(
            databaseReady: databaseReady,
            schemaVersionBeforeOpen: schemaVersionBeforeOpen,
          ),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class _DatabaseStartupScreen extends ConsumerWidget {
  const _DatabaseStartupScreen({
    required this.databaseReady,
    required this.schemaVersionBeforeOpen,
  });

  final AsyncValue<DatabaseReadyReport> databaseReady;
  final AsyncValue<int?> schemaVersionBeforeOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schemaVersion = schemaVersionBeforeOpen.whenOrNull(
      data: (version) => version,
    );
    final isKnownMigration =
        schemaVersion != null &&
        schemaVersion < AppDatabase.currentSchemaVersion;
    final canStartFallbackDelay =
        !isKnownMigration &&
        (schemaVersionBeforeOpen.hasValue || schemaVersionBeforeOpen.hasError);
    final showDelayedStatus =
        canStartFallbackDelay &&
        ref.watch(_databaseStartupStatusDelayProvider).hasValue;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: databaseReady.when(
              data: (_) => PrismSpinner(
                color: Theme.of(context).colorScheme.primary,
                size: 52,
              ),
              loading: () {
                if (isKnownMigration || showDelayedStatus || kIsWeb) {
                  return _DatabaseStartupStatus(
                    schemaVersionBeforeOpen: schemaVersion,
                  );
                }
                // The launch animation starts here and carries on over the
                // app once the database is ready.
                return LaunchBoot.shouldPlay
                    ? const LaunchMark(liveData: false)
                    : const SizedBox.shrink();
              },
              error: (error, _) => _DatabaseStartupError(
                error: error,
                onRetry: () {
                  ref.invalidate(databaseProvider);
                  ref.invalidate(databaseSchemaVersionBeforeOpenProvider);
                  ref.invalidate(databaseReadyProvider);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DatabaseStartupStatus extends StatelessWidget {
  const _DatabaseStartupStatus({required this.schemaVersionBeforeOpen});

  final int? schemaVersionBeforeOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final before = schemaVersionBeforeOpen;
    final title = before == null
        ? 'Setting up Prism'
        : before < AppDatabase.currentSchemaVersion
        ? 'Updating Prism data'
        : 'Opening Prism';
    final message = before == null
        ? 'Preparing your local database.'
        : before < AppDatabase.currentSchemaVersion
        ? 'Updating database schema v$before to v${AppDatabase.currentSchemaVersion}. Keep Prism open until this finishes.'
        : 'Preparing your workspace.';

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrismSpinner(color: theme.colorScheme.primary, size: 52),
          const SizedBox(height: 28),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _DatabaseStartupError extends StatelessWidget {
  const _DatabaseStartupError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            AppIcons.errorOutlineRounded,
            size: 44,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 20),
          Text(
            'Prism could not finish opening its database.',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            error.toString(),
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 24),
          PrismButton(
            label: 'Try again',
            icon: AppIcons.refresh,
            tone: PrismButtonTone.filled,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

bool _openersRegistered = false;

/// Lets the connections explorer open records owned by the newer modules.
void registerAdvancedRecordOpeners() {
  if (_openersRegistered) return;
  _openersRegistered = true;
  registerDreamOpener(recordKindOpeners);
  registerNutritionOpeners(recordKindOpeners);
  registerScrapOpeners(recordKindOpeners);
  registerConnOpeners(recordKindOpeners);
  recordTypeOpeners[RecordRef.habitLog] = openHabitCompletion;
  recordKindOpeners[TrackerKind.relationship] = (context, id) =>
      GoRouter.of(context).push(relRoute(id));
}

/// Notes theme switches (it sits below the app theme) so implicit
/// animations can skip their tween for that frame.
class _ThemeSwitchObserver extends StatelessWidget {
  const _ThemeSwitchObserver({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    ThemeSwitch.observe((
      t.brightness,
      t.colorScheme.primary,
      t.colorScheme.surface,
      t.extension<LookTheme>()?.look.id,
    ));
    return child;
  }
}
