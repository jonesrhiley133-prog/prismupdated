import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/core/router/onboarding_local_completion.dart';
import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/core/services/error_reporting_service.dart';
import 'package:prism_plurality/core/services/secure_storage.dart';
import 'package:prism_plurality/core/sync/prism_sync_providers.dart';
import '../../features/fronting/views/edit_front_session_screen.dart';
import '../../features/fronting/views/fronting_screen.dart';
import '../../features/fronting/views/period_detail_args.dart';
import '../../features/fronting/views/period_detail_screen.dart';
import '../../features/fronting/views/session_detail_screen.dart';
import '../../features/fronting/views/sleep_screen.dart';
import '../../features/sleep_log/views/sleep_log_screen.dart';
import '../../features/cycle/views/cycle_insights_screen.dart';
import '../../features/polls/advanced/poll_stats_screen.dart';
import '../../features/fronting_notification/views/fronting_notification_settings_screen.dart';
import '../../features/home_widgets/views/home_widgets_screen.dart';
import '../../features/music/views/now_playing_screen.dart';
import '../../features/social/views/alter_blog_screen.dart';
import '../../features/social/views/banner_positions_screen.dart';
import '../../features/social/views/bulletin_screen.dart';
import '../../features/social/views/post_thread_screen.dart';
import '../../features/appearance/views/appearance_studio_screen.dart';
import '../../features/accessibility/a11y_views.dart';
import '../../features/home_widgets/views/todo_screen.dart';
import '../../features/home_widgets/views/widget_studio_screen.dart';
import '../../features/fronting/views/timeline_screen.dart';
import '../../features/members/views/members_screen.dart';
import '../../features/members/navigation/member_navigation_branch.dart';
import '../../features/members/views/member_detail_screen.dart';
import '../../features/members/views/member_custom_field_group_page.dart';
import '../../features/members/views/member_fronting_history_screen.dart';
import '../../features/chat/views/chat_screen.dart';
import '../../features/chat/views/chat_search_screen.dart';
import '../../features/chat/views/conversation_screen.dart';
import '../../features/polls/views/polls_list_screen.dart';
import '../../features/polls/views/poll_detail_screen.dart';
import '../../features/settings/views/settings_screen.dart';
import '../../features/settings/views/sleep_feature_settings_screen.dart';
import '../../features/settings/views/polls_feature_settings_screen.dart';
import '../../features/settings/views/notes_feature_settings_screen.dart';
import '../../features/settings/views/boards_feature_settings_screen.dart';
import '../../features/boards/views/boards_screen.dart';
import '../../features/boards/views/member_board_screen.dart';
import '../../features/boards/views/post_detail_screen.dart';
import '../../features/settings/views/reminders_feature_settings_screen.dart';
import '../../features/settings/views/sync_settings_screen.dart';
import '../../features/settings/views/notification_settings_screen.dart';
import '../../features/settings/views/accessibility_settings_screen.dart';
import '../../features/settings/views/appearance_settings_screen.dart';
import '../../features/settings/views/palette_settings_screen.dart';
import '../../features/settings/views/terminology_settings_screen.dart';
import '../../features/settings/views/statistics_screen.dart';
import '../../features/settings/views/database_diagnostics_screen.dart';
import '../../features/settings/views/component_gallery_screen.dart';
import '../../features/settings/views/custom_field_icon_debug_screen.dart';
import '../../features/settings/views/debug_screen.dart';
import '../../features/settings/views/error_history_screen.dart';
import '../../features/settings/views/sync_debug_screen.dart';
import '../../features/settings/views/crypto_storage_debug_screen.dart';
import '../../features/migration/views/migration_screen.dart';
import '../../features/settings/views/sync_troubleshooting_screen.dart';
import '../../features/settings/views/device_management_screen.dart';
import '../../features/settings/views/data_browser_screen.dart';
import '../../features/members/views/groups_screen.dart';
import '../../features/members/views/group_detail_screen.dart';
import '../../features/members/views/system_management_screen.dart';
import '../../features/settings/views/secret_key_setup_screen.dart';
import '../../features/settings/views/verify_backup_screen.dart';
import '../../features/settings/views/sync_setup_screen.dart';
import '../../features/pluralkit/views/pk_sync_debug_screen.dart';
import '../../features/pluralkit/views/pluralkit_setup_screen.dart';
import '../../features/sharing/views/sharing_screen.dart';
import '../../features/sharing/views/friend_detail_screen.dart';
import '../../features/calendar/views/calendar_screen.dart';
import '../../features/connected/views/pattern_explorer_screen.dart';
import '../../features/connected/views/system_timeline_screen.dart';
import '../../features/contacts/views/contacts_screen.dart';
import '../../features/intro_cards/intro_cards_screen.dart';
import '../../features/availability/availability_screen.dart';
import '../../features/analytics/analytics_hub_screen.dart';
import '../../features/connections/connections_screens.dart';
import '../../features/scrapbook/scrapbook_screens.dart';
import '../../features/nutrition/nutrition_screen.dart';
import '../../features/social/views/stories_screen.dart';
import '../../features/music/views/music_screen.dart';
import '../../features/headspace/views/headspace_screen.dart';
import '../../features/subsystems/hub/subsystem_hub.dart';
import '../../features/subsystems/hub/subsystem_profile.dart';
import '../../features/relationships/hub/rel_hub_screen.dart';
import '../../features/relationships/hub/rel_profile.dart';
import '../../features/school/views/school_screen.dart';
import '../../features/finance/views/finance_screen.dart';
import '../../features/fitness/views/fitness_screen.dart';
import '../../features/achievements/views/achievements_screen.dart';
import '../../features/dictionary/views/dictionary_screen.dart';
import '../../features/journal/views/journal_screen.dart';
import '../../features/cycle/views/cycle_screen.dart';
import '../../features/import_center/views/import_center_screen.dart';
import '../../features/insights/views/daily_insights_screen.dart';
import '../../features/locations/views/locations_screen.dart';
import '../../features/work/views/work_screen.dart';
import '../../features/mood/views/mood_screen.dart';
import '../../features/data_management/views/import_export_screen.dart';
import '../../features/settings/views/features_settings_screen.dart';
import '../../features/settings/views/chat_feature_settings_screen.dart';
import '../../features/settings/views/habits_feature_settings_screen.dart';
import '../../features/settings/views/fronting_feature_settings_screen.dart';
import '../../features/settings/views/about_screen.dart';
import '../../features/settings/views/reset_data_screen.dart';
import '../../features/settings/views/custom_field_detail_screen.dart';
import '../../features/settings/views/custom_fields_screen.dart';
import '../../features/settings/views/analytics_screen.dart';
import '../../features/members/views/note_detail_screen.dart';
import '../../features/settings/views/pin_lock_settings_screen.dart';
import '../../features/reminders/views/reminders_screen.dart';
import '../../features/notes/views/notes_list_screen.dart';
import '../../features/settings/views/system_info_screen.dart';
import '../../features/settings/views/navigation_settings_screen.dart';
import '../../features/settings/utils/tag_usage_scan.dart';
import '../../features/settings/views/media_settings_screen.dart';
import '../../features/onboarding/views/onboarding_screen.dart';
import '../../features/settings/providers/settings_providers.dart';
import '../../shared/widgets/app_shell.dart';
import '../diagnostics/freeze_watchdog.dart';
import '../../features/habits/center/habit_center_screen.dart';
import '../../features/habits/center/habit_dashboard.dart';
import '../../features/alter_status/statuses_screen.dart';
import '../../features/analytics/cofront_screen.dart';
import '../../features/analytics/mood_correlation_screen.dart';
import '../../features/automations/automations_screen.dart';
import '../../features/demo/demo_mode_screen.dart';
import '../../features/links/views/link_explorer_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// The app's root navigator (used to show in-app messages from services).
GlobalKey<NavigatorState> get appRootNavigatorKey => _rootNavigatorKey;
final _homeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _chatNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'chat');
final _habitsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'habits');
final _pollsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'polls');
final _settingsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'settings');
final _membersNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'members');
final _remindersNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'reminders',
);
final _notesNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'notes');
final _statisticsNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'statistics',
);
final _timelineNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'timeline');
final _sleepNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'sleep');
final _boardsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'boards');
final _groupsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'groups');
final _mediaNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'media');
final _moodNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'mood');
final _calendarNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'calendar');
final _locationsNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'locations',
);
final _workNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'work');
final _insightsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'insights');
final _cycleNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'cycle');
final _journalNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'journal');
final _dictionaryNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'dictionary',
);
final _achievementsNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'achievements',
);
final _fitnessNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'fitness');
final _financeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'finance');
final _schoolNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'school');
final _relationshipsNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'relationships',
);
final _subsystemsNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'subsystems',
);
final _headspaceNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'headspace',
);
final _musicNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'music');
final _storiesNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'stories');
final _nutritionNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'nutrition',
);
final _scrapbookNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'scrapbook',
);
final _connectionsNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'connections',
);
final _analyticsNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'analytics',
);
final _availabilityNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'availability',
);
final _introductionsNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'introductions',
);
final _contactsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'contacts');

/// Notifier that triggers GoRouter redirect re-evaluation when onboarding
/// status changes.
class _OnboardingRedirectNotifier extends ChangeNotifier {
  bool? _hasCompleted;

  bool? get hasCompleted => _hasCompleted;

  set hasCompleted(bool? value) {
    if (_hasCompleted != value) {
      _hasCompleted = value;
      notifyListeners();
    }
  }

  @override
  // ignore: unnecessary_overrides
  void dispose() {
    super.dispose();
  }

  /// Resets the global [_onboardingRedirectNotifier] state for testing.
  @visibleForTesting
  // ignore: unused_element
  static void resetForTesting() {
    _onboardingRedirectNotifier._hasCompleted = false;
  }
}

// NOTE: File-level global — can retain stale state across hot reload.
// Tightly coupled to GoRouter's refreshListenable API, so not easily fixable
// without a GoRouter lifecycle change. Acceptable for production; be aware
// during development that a hot restart (not hot reload) resets this.
final _onboardingRedirectNotifier = _OnboardingRedirectNotifier();

const _syncWrappedDekKey = 'prism_sync.wrapped_dek';
const _syncRuntimeDekKey = 'prism_sync.runtime_dek';
const _syncRuntimeDekWrappedKey = 'prism_sync.runtime_dek_wrapped_v1';

Widget buildAppShellRoute(
  BuildContext _,
  GoRouterState state,
  StatefulNavigationShell navigationShell,
) {
  return AppShell(navigationShell: navigationShell, routePath: state.uri.path);
}

@visibleForTesting
Future<bool> recoverCompletedOnboardingFromPairedState({
  required Future<String?> Function(String key) readSecureValue,
  required Future<int> Function() getMemberCount,
  required Future<void> Function() markOnboardingComplete,
}) async {
  final syncId = await readSecureValue(kSyncIdKey);
  final deviceId = await readSecureValue(kSyncDeviceIdKey);
  if (syncId == null ||
      syncId.isEmpty ||
      deviceId == null ||
      deviceId.isEmpty) {
    return false;
  }

  final snapshotApplyMarker = await readSecureValue(kSnapshotApplyCompleteKey);
  if (!snapshotApplyCompleteMarkerMatches(
    marker: snapshotApplyMarker,
    syncId: syncId,
    deviceId: deviceId,
  )) {
    return false;
  }

  final wrappedDek = await readSecureValue(_syncWrappedDekKey);
  final runtimeDek = await readSecureValue(_syncRuntimeDekKey);
  final runtimeDekWrapped = await readSecureValue(_syncRuntimeDekWrappedKey);
  if ((wrappedDek == null || wrappedDek.isEmpty) &&
      (runtimeDek == null || runtimeDek.isEmpty) &&
      (runtimeDekWrapped == null || runtimeDekWrapped.isEmpty)) {
    return false;
  }

  final memberCount = await getMemberCount();
  if (memberCount == 0) return false;

  await markOnboardingComplete();
  return true;
}

Future<bool> _recoverCompletedOnboardingFromPairedState(Ref ref) async {
  try {
    return await recoverCompletedOnboardingFromPairedState(
      readSecureValue: (key) async => (await safeSecureRead(key)).value,
      getMemberCount: ref.read(memberRepositoryProvider).getCount,
      markOnboardingComplete: () => ref
          .read(systemSettingsRepositoryProvider)
          .updateHasCompletedOnboarding(true),
    );
  } catch (e, st) {
    ErrorReportingService.instance.report(
      'Recovered paired onboarding check failed: $e',
      severity: ErrorSeverity.warning,
      stackTrace: st,
    );
    return false;
  }
}

/// Pure decision for the onboarding gate, extracted so it can be unit-tested
/// without spinning up a [GoRouter]. Returns the path to redirect to, or null
/// to leave the requested location alone.
///
/// [completedLocally] distinguishes a device that finished onboarding here
/// (an empty member table is a deliberate end-state) from one that inherited
/// `hasCompletedOnboarding` over sync and is still waiting for its members —
/// only the latter is held on onboarding to avoid an empty home.
@visibleForTesting
Future<String?> resolveOnboardingRedirect({
  required bool? hasCompleted,
  required bool isOnboarding,
  required bool completedLocally,
  required Future<bool> Function() tryRecoverPaired,
  required Future<int> Function() getMemberCount,
}) async {
  // While settings are still loading, don't redirect.
  if (hasCompleted == null) return null;

  if (!hasCompleted) {
    final recovered = await tryRecoverPaired();
    if (recovered) {
      return isOnboarding ? AppRoutePaths.home : null;
    }
  }

  if (!hasCompleted && !isOnboarding) {
    return AppRoutePaths.onboarding;
  }
  if (hasCompleted && isOnboarding) {
    // A device that inherited hasCompletedOnboarding over CRDT sync waits for
    // its members before leaving onboarding, so it doesn't land on an empty
    // home. A device that finished onboarding locally is exempt: an empty
    // system is a valid choice here (e.g. importing via the main UI later).
    if (!completedLocally && await getMemberCount() == 0) {
      return null;
    }
    return AppRoutePaths.home;
  }
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  // Update the redirect notifier reactively.
  ref.listen(systemSettingsProvider, (_, next) {
    _onboardingRedirectNotifier.hasCompleted = next.whenOrNull(
      data: (s) => s.hasCompletedOnboarding,
    );
  });

  // Also set the initial value.
  _onboardingRedirectNotifier.hasCompleted = ref
      .read(systemSettingsProvider)
      .whenOrNull(data: (s) => s.hasCompletedOnboarding);

  String? redirectIfChatDisabled(BuildContext context, GoRouterState state) {
    final flags = ref.read(featureFlagsProvider);
    return flags.chat ? null : AppRoutePaths.home;
  }

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutePaths.home,
    refreshListenable: _onboardingRedirectNotifier,
    onException: (context, state, router) {
      debugPrint(
        '[GoRouter] exception navigating to ${state.uri}: '
        '${state.error}',
      );
      // Only redirect to home if we're not already there, to avoid
      // swallowing tab-switch failures silently.
      if (state.matchedLocation != AppRoutePaths.home) {
        router.go(AppRoutePaths.home);
      }
    },
    redirect: (context, state) async {
      FreezeWatchdog.crumb(
        'redirect ${state.fullPath ?? state.matchedLocation}',
      );
      return resolveOnboardingRedirect(
        hasCompleted: _onboardingRedirectNotifier.hasCompleted,
        isOnboarding: state.matchedLocation == AppRoutePaths.onboarding,
        completedLocally: ref.read(localOnboardingCompletionProvider),
        tryRecoverPaired: () => _recoverCompletedOnboardingFromPairedState(ref),
        getMemberCount: ref.read(memberRepositoryProvider).getCount,
      );
    },
    routes: [
      // Onboarding (full-screen)
      GoRoute(
        name: AppRouteNames.onboarding,
        path: AppRoutePaths.onboarding,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const OnboardingScreen(),
      ),
      // Full-screen route for Secret Key setup (shown once after key generation)
      GoRoute(
        name: AppRouteNames.secretKeySetup,
        path: AppRoutePaths.secretKeySetup,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          // Try state.extra first, then fall back to transient provider
          final mnemonic = switch (state.extra) {
            final String value when value.trim().isNotEmpty => value,
            _ => ref.read(pendingMnemonicProvider),
          };
          return DemoGuard(
            child: SecretKeySetupScreen(
              mnemonic: mnemonic,
              onComplete: () => context.goNamed(AppRouteNames.settingsSync),
            ),
          );
        },
      ),
      // Full-screen route for sync setup wizard
      GoRoute(
        name: AppRouteNames.syncSetup,
        path: AppRoutePaths.syncSetup,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const DemoGuard(child: SyncSetupScreen()),
      ),
      GoRoute(
        path: AppRoutePaths.importCenter,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ImportCenterScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.systemTimeline,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SystemTimelineScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.nowPlaying,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          fullscreenDialog: true,
          child: const NowPlayingScreen(),
          transitionsBuilder: (context, animation, _, child) => SlideTransition(
            position: Tween(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
            child: child,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.appearanceStudio,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AppearanceStudioScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.accessibilityQuick,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          opaque: false,
          barrierDismissible: true,
          barrierColor: Colors.black54,
          child: const _QuickA11yPage(),
          transitionsBuilder: (context, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.socialPostRoute,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            PostThreadScreen(postId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutePaths.socialAlterRoute,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            AlterBlogScreen(memberId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutePaths.socialTagRoute,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            TagScreen(tag: state.pathParameters['tag']!),
      ),
      GoRoute(
        path: AppRoutePaths.socialDrafts,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const DraftsScreen(),
      ),
      GoRoute(
        path: '/links',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LinkExplorerScreen(),
      ),
      GoRoute(
        path: '/statuses',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const StatusesScreen(),
      ),
      GoRoute(
        path: '/automations',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AutomationsScreen(),
      ),
      GoRoute(
        path: '/demo',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const DemoModeScreen(),
      ),
      GoRoute(
        path: '/analytics/cofronting',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CoFrontingScreen(),
      ),
      GoRoute(
        path: '/analytics/mood',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MoodCorrelationScreen(),
      ),
      GoRoute(
        path: '/scrapbook/book/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ScrapBookScreen(
          bookId: state.pathParameters['id']!,
          initialPageId: state.uri.queryParameters['page'],
        ),
      ),
      GoRoute(
        path: '/connections/map/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ConnectionMapScreen(
          mapId: state.pathParameters['id']!,
          focusNodeId: state.uri.queryParameters['node'],
        ),
      ),
      GoRoute(
        path: AppRoutePaths.headmateBanners,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const BannerPositionsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.socialReports,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.homeWidgets,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const HomeWidgetsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.widgetStudioRoute,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => WidgetStudioScreen(
          type: state.pathParameters['type'] ?? 'current_fronter',
          widgetId: int.tryParse(state.uri.queryParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.todos,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            TodoScreen(focusNew: state.uri.queryParameters['new'] == '1'),
      ),
      GoRoute(
        path: AppRoutePaths.frontingNotification,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const FrontingNotificationSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.pollStats,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PollStatsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.cycleInsights,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CycleInsightsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.sleepLog,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SleepLogScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.patterns,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PatternExplorerScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: buildAppShellRoute,
        branches: [
          // Branch 0: Home (fronting)
          StatefulShellBranch(
            navigatorKey: _homeNavigatorKey,
            routes: [
              GoRoute(
                name: AppRouteNames.home,
                path: AppRoutePaths.home,
                builder: (context, state) => const FrontingScreen(),
                routes: [
                  GoRoute(
                    path: 'session/:id',
                    builder: (context, state) => SessionDetailScreen(
                      sessionId: state.pathParameters['id']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) => EditFrontSessionScreen(
                          sessionId: state.pathParameters['id']!,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'period',
                    builder: (context, state) {
                      final ids = parsePeriodIds(state.uri);
                      final hint = state.extra is PeriodDetailArgs
                          ? state.extra as PeriodDetailArgs
                          : null;
                      return PeriodDetailScreen(
                        sessionIds: ids,
                        hint: hint,
                        isSessionGroup:
                            state.uri.queryParameters['mode'] == 'sessions',
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          // Branch 1: Chat
          StatefulShellBranch(
            navigatorKey: _chatNavigatorKey,
            routes: [
              GoRoute(
                name: AppRouteNames.chat,
                path: AppRoutePaths.chat,
                redirect: (context, state) {
                  final flags = ref.read(featureFlagsProvider);
                  return flags.chat ? null : AppRoutePaths.home;
                },
                builder: (context, state) => const ChatScreen(),
                routes: [
                  GoRoute(
                    path: 'search',
                    builder: (context, state) => const ChatSearchScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => ConversationScreen(
                      conversationId: state.pathParameters['id']!,
                      initialMessageId: state.uri.queryParameters['messageId'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Branch 2: Habits
          StatefulShellBranch(
            navigatorKey: _habitsNavigatorKey,
            routes: [
              GoRoute(
                name: AppRouteNames.habits,
                path: AppRoutePaths.habits,
                redirect: (context, state) {
                  final flags = ref.read(featureFlagsProvider);
                  return flags.habits ? null : AppRoutePaths.home;
                },
                builder: (context, state) => const HabitCenterScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => HabitDashboardScreen(
                      habitId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Branch 3: Polls
          StatefulShellBranch(
            navigatorKey: _pollsNavigatorKey,
            routes: [
              GoRoute(
                name: AppRouteNames.polls,
                path: AppRoutePaths.polls,
                redirect: (context, state) {
                  final flags = ref.read(featureFlagsProvider);
                  return flags.polls ? null : AppRoutePaths.home;
                },
                builder: (context, state) => const PollsListScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) =>
                        PollDetailScreen(pollId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          // Branch 4: Settings (includes members management)
          StatefulShellBranch(
            navigatorKey: _settingsNavigatorKey,
            routes: [
              GoRoute(
                name: AppRouteNames.settings,
                path: AppRoutePaths.settings,
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  // Members routes (under settings)
                  GoRoute(
                    path: 'members',
                    builder: (context, state) => const MembersScreen(
                      branch: MemberNavigationBranch.settings,
                    ),
                    routes: [
                      GoRoute(
                        path: 'manage',
                        builder: (context, state) =>
                            const SystemManagementScreen(),
                      ),
                      GoRoute(
                        path: 'groups',
                        builder: (context, state) => const GroupsScreen(
                          branch: MemberNavigationBranch.settings,
                        ),
                        routes: [
                          GoRoute(
                            path: ':id',
                            builder: (context, state) => GroupDetailScreen(
                              groupId: state.pathParameters['id']!,
                              branch: MemberNavigationBranch.settings,
                            ),
                          ),
                        ],
                      ),
                      GoRoute(
                        path: ':id',
                        builder: (context, state) => MemberDetailScreen(
                          memberId: state.pathParameters['id']!,
                          branch: MemberNavigationBranch.settings,
                        ),
                        routes: [
                          GoRoute(
                            path: 'fronting',
                            builder: (context, state) =>
                                MemberFrontingHistoryScreen(
                                  memberId: state.pathParameters['id']!,
                                ),
                          ),
                          GoRoute(
                            path: 'conversations',
                            redirect: redirectIfChatDisabled,
                            builder: (context, state) =>
                                MemberConversationsScreen(
                                  memberId: state.pathParameters['id']!,
                                ),
                          ),
                          GoRoute(
                            path: 'custom-fields/:fieldId',
                            builder: (context, state) =>
                                MemberCustomFieldGroupPage(
                                  memberId: state.pathParameters['id']!,
                                  fieldId: state.pathParameters['fieldId']!,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'habits',
                    builder: (context, state) =>
                        const HabitCenterScreen(inSettings: true),
                    routes: [
                      GoRoute(
                        path: ':id',
                        builder: (context, state) => HabitDashboardScreen(
                          habitId: state.pathParameters['id']!,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'sleep',
                    redirect: (context, state) => '/settings/features/sleep',
                  ),
                  GoRoute(
                    name: AppRouteNames.settingsSync,
                    path: 'sync',
                    builder: (context, state) =>
                        const DemoGuard(child: SyncSettingsScreen()),
                    routes: [
                      GoRoute(
                        name: AppRouteNames.settingsSyncVerifyBackup,
                        path: 'verify-backup',
                        builder: (context, state) => const VerifyBackupScreen(),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'notifications',
                    builder: (context, state) =>
                        const NotificationSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'appearance',
                    builder: (context, state) =>
                        const AppearanceSettingsScreen(),
                    routes: [
                      GoRoute(
                        path: 'palette',
                        builder: (context, state) =>
                            const PaletteSettingsScreen(),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'terminology',
                    builder: (context, state) =>
                        const TerminologySettingsScreen(),
                  ),
                  GoRoute(
                    path: 'accessibility',
                    builder: (context, state) =>
                        const AccessibilitySettingsScreen(),
                  ),
                  GoRoute(
                    path: 'statistics',
                    builder: (context, state) => const StatisticsScreen(),
                  ),
                  GoRoute(
                    path: 'database',
                    builder: (context, state) =>
                        const DatabaseDiagnosticsScreen(),
                  ),
                  GoRoute(
                    path: 'about',
                    builder: (context, state) => const AboutScreen(),
                  ),
                  GoRoute(
                    path: 'debug',
                    redirect: (context, state) =>
                        !kReleaseMode ? null : AppRoutePaths.settings,
                    builder: (context, state) => const DebugScreen(),
                  ),
                  GoRoute(
                    path: 'component-gallery',
                    redirect: (context, state) =>
                        !kReleaseMode ? null : AppRoutePaths.settings,
                    builder: (context, state) => const ComponentGalleryScreen(),
                  ),
                  GoRoute(
                    path: 'custom-field-icon-debug',
                    redirect: (context, state) =>
                        !kReleaseMode ? null : AppRoutePaths.settings,
                    builder: (context, state) =>
                        const CustomFieldIconDebugScreen(),
                  ),
                  GoRoute(
                    path: 'sync-debug',
                    builder: (context, state) => const SyncDebugScreen(),
                  ),
                  GoRoute(
                    path: 'crypto-storage-debug',
                    builder: (context, state) =>
                        const CryptoStorageDebugScreen(),
                  ),
                  GoRoute(
                    path: 'errors',
                    builder: (context, state) => const ErrorHistoryScreen(),
                  ),
                  GoRoute(
                    path: 'migration',
                    builder: (context, state) => const MigrationScreen(),
                  ),
                  GoRoute(
                    path: 'pluralkit',
                    builder: (context, state) =>
                        const DemoGuard(child: PluralKitSetupScreen()),
                    routes: [
                      GoRoute(
                        path: 'sync-debug',
                        builder: (context, state) => const PkSyncDebugScreen(),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'sync-troubleshooting',
                    builder: (context, state) =>
                        const SyncTroubleshootingScreen(),
                    routes: [
                      GoRoute(
                        path: 'tips',
                        builder: (context, state) =>
                            const SyncTroubleshootingTipsScreen(),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'devices',
                    builder: (context, state) => const DeviceManagementScreen(),
                  ),
                  GoRoute(
                    path: 'data-browser',
                    builder: (context, state) => const DataBrowserScreen(),
                  ),
                  GoRoute(
                    path: 'import-export',
                    builder: (context, state) => const ImportExportScreen(),
                  ),
                  GoRoute(
                    path: 'features',
                    builder: (context, state) => const FeaturesSettingsScreen(),
                    routes: [
                      GoRoute(
                        path: 'chat',
                        builder: (context, state) =>
                            const ChatFeatureSettingsScreen(),
                      ),
                      GoRoute(
                        path: 'habits',
                        builder: (context, state) =>
                            const HabitsFeatureSettingsScreen(),
                      ),
                      GoRoute(
                        path: 'fronting',
                        builder: (context, state) =>
                            const FrontingFeatureSettingsScreen(),
                      ),
                      GoRoute(
                        path: 'sleep',
                        builder: (context, state) => SleepFeatureSettingsScreen(
                          args: state.extra is SleepFeatureSettingsArgs
                              ? state.extra as SleepFeatureSettingsArgs
                              : null,
                        ),
                      ),
                      GoRoute(
                        path: 'polls',
                        builder: (context, state) =>
                            const PollsFeatureSettingsScreen(),
                      ),
                      GoRoute(
                        path: 'notes',
                        builder: (context, state) =>
                            const NotesFeatureSettingsScreen(),
                      ),
                      GoRoute(
                        path: 'boards',
                        builder: (context, state) =>
                            const BoardsFeatureSettingsScreen(),
                      ),
                      GoRoute(
                        path: 'reminders',
                        builder: (context, state) =>
                            const RemindersFeatureSettingsScreen(),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'reset',
                    builder: (context, state) => const ResetDataScreen(),
                  ),
                  GoRoute(
                    path: 'custom-fields',
                    builder: (context, state) => const CustomFieldsScreen(),
                    routes: [
                      GoRoute(
                        path: ':id',
                        builder: (context, state) => CustomFieldDetailScreen(
                          fieldId: state.pathParameters['id']!,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'analytics',
                    builder: (context, state) => const AnalyticsScreen(),
                  ),
                  GoRoute(
                    path: 'pin-lock',
                    builder: (context, state) => const PinLockSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'reminders',
                    builder: (context, state) => const RemindersScreen(),
                  ),
                  GoRoute(
                    path: 'notes/:id',
                    builder: (context, state) =>
                        NoteDetailScreen(noteId: state.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: 'navigation',
                    builder: (context, state) =>
                        const NavigationSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'media',
                    builder: (context, state) => const MediaSettingsScreen(
                      branch: MediaNavigationBranch.settings,
                    ),
                    routes: [
                      GoRoute(
                        path: 'usage',
                        builder: (context, state) => TagUsageScreen(
                          usages: state.extra is List<TagUsageRef>
                              ? state.extra! as List<TagUsageRef>
                              : const <TagUsageRef>[],
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'system-info',
                    builder: (context, state) => const SystemInfoScreen(),
                  ),
                  if (kDebugMode)
                    GoRoute(
                      path: 'sharing',
                      builder: (context, state) => const SharingScreen(),
                      routes: [
                        GoRoute(
                          path: ':friendId',
                          builder: (context, state) => FriendDetailScreen(
                            friendId: state.pathParameters['friendId']!,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
          // Branch 5: Members (top-level tab)
          StatefulShellBranch(
            navigatorKey: _membersNavigatorKey,
            routes: [
              GoRoute(
                name: AppRouteNames.members,
                path: AppRoutePaths.members,
                builder: (context, state) => const MembersScreen(
                  showBackButton: false,
                  branch: MemberNavigationBranch.members,
                ),
                routes: [
                  GoRoute(
                    path: 'groups/:id',
                    builder: (context, state) => GroupDetailScreen(
                      groupId: state.pathParameters['id']!,
                      branch: MemberNavigationBranch.members,
                    ),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => MemberDetailScreen(
                      memberId: state.pathParameters['id']!,
                      branch: MemberNavigationBranch.members,
                    ),
                    routes: [
                      GoRoute(
                        path: 'fronting',
                        builder: (context, state) =>
                            MemberFrontingHistoryScreen(
                              memberId: state.pathParameters['id']!,
                            ),
                      ),
                      GoRoute(
                        path: 'conversations',
                        redirect: redirectIfChatDisabled,
                        builder: (context, state) => MemberConversationsScreen(
                          memberId: state.pathParameters['id']!,
                        ),
                      ),
                      GoRoute(
                        path: 'custom-fields/:fieldId',
                        builder: (context, state) => MemberCustomFieldGroupPage(
                          memberId: state.pathParameters['id']!,
                          fieldId: state.pathParameters['fieldId']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // Branch 6: Reminders (top-level tab)
          StatefulShellBranch(
            navigatorKey: _remindersNavigatorKey,
            routes: [
              GoRoute(
                name: AppRouteNames.reminders,
                path: AppRoutePaths.reminders,
                redirect: (context, state) {
                  final flags = ref.read(featureFlagsProvider);
                  return flags.reminders ? null : AppRoutePaths.home;
                },
                builder: (context, state) =>
                    const RemindersScreen(showBackButton: false),
              ),
            ],
          ),
          // Branch 7: Notes (top-level tab)
          StatefulShellBranch(
            navigatorKey: _notesNavigatorKey,
            routes: [
              GoRoute(
                name: AppRouteNames.notes,
                path: AppRoutePaths.notes,
                redirect: (context, state) {
                  final flags = ref.read(featureFlagsProvider);
                  return flags.notes ? null : AppRoutePaths.home;
                },
                builder: (context, state) => const NotesListScreen(
                  showBackButton: false,
                  branch: NotesListBranch.notes,
                ),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) =>
                        NoteDetailScreen(noteId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          // Branch 8: Statistics (top-level tab)
          StatefulShellBranch(
            navigatorKey: _statisticsNavigatorKey,
            routes: [
              GoRoute(
                name: AppRouteNames.statistics,
                path: AppRoutePaths.statistics,
                builder: (context, state) =>
                    const AnalyticsScreen(showBackButton: false),
              ),
            ],
          ),
          // Branch 9: Timeline (optional top-level tab)
          StatefulShellBranch(
            navigatorKey: _timelineNavigatorKey,
            routes: [
              GoRoute(
                name: AppRouteNames.timeline,
                path: AppRoutePaths.timeline,
                builder: (context, state) => const TimelineScreen(),
              ),
            ],
          ),
          // Branch 10: Sleep (opt-in tab; feature-flagged)
          StatefulShellBranch(
            navigatorKey: _sleepNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutePaths.sleep,
                redirect: (context, state) {
                  final flags = ref.read(featureFlagsProvider);
                  return flags.sleep ? null : AppRoutePaths.home;
                },
                builder: (context, state) =>
                    const SleepScreen(showBackButton: false),
                routes: [
                  GoRoute(
                    path: 'session/:id',
                    builder: (context, state) => SessionDetailScreen(
                      sessionId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Branch 11: Boards (opt-in tab; feature-flagged)
          StatefulShellBranch(
            navigatorKey: _boardsNavigatorKey,
            routes: [
              GoRoute(
                name: AppRouteNames.boards,
                path: AppRoutePaths.boards,
                redirect: (context, state) {
                  final flags = ref.read(featureFlagsProvider);
                  return flags.boards ? null : AppRoutePaths.home;
                },
                builder: (context, state) => const BulletinScreen(),
                routes: [
                  GoRoute(
                    path: 'messages',
                    builder: (context, state) => const BoardsScreen(),
                  ),
                  GoRoute(
                    name: AppRouteNames.memberBoard,
                    path: 'member/:memberId',
                    builder: (context, state) => MemberBoardScreen(
                      memberId: state.pathParameters['memberId']!,
                    ),
                  ),
                  GoRoute(
                    name: AppRouteNames.boardPost,
                    path: 'post/:postId',
                    builder: (context, state) => PostDetailScreen(
                      postId: state.pathParameters['postId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Branch 12: Groups (optional top-level tab)
          StatefulShellBranch(
            navigatorKey: _groupsNavigatorKey,
            routes: [
              GoRoute(
                name: AppRouteNames.groups,
                path: AppRoutePaths.groups,
                builder: (context, state) => const GroupsScreen(
                  showBackButton: false,
                  branch: MemberNavigationBranch.groups,
                ),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => GroupDetailScreen(
                      groupId: state.pathParameters['id']!,
                      branch: MemberNavigationBranch.groups,
                    ),
                    routes: [
                      GoRoute(
                        path: 'member/:memberId',
                        builder: (context, state) => MemberDetailScreen(
                          memberId: state.pathParameters['memberId']!,
                          branch: MemberNavigationBranch.groups,
                          groupId: state.pathParameters['id']!,
                        ),
                        routes: [
                          GoRoute(
                            path: 'fronting',
                            builder: (context, state) =>
                                MemberFrontingHistoryScreen(
                                  memberId: state.pathParameters['memberId']!,
                                ),
                          ),
                          GoRoute(
                            path: 'conversations',
                            redirect: redirectIfChatDisabled,
                            builder: (context, state) =>
                                MemberConversationsScreen(
                                  memberId: state.pathParameters['memberId']!,
                                ),
                          ),
                          GoRoute(
                            path: 'custom-fields/:fieldId',
                            builder: (context, state) =>
                                MemberCustomFieldGroupPage(
                                  memberId: state.pathParameters['memberId']!,
                                  fieldId: state.pathParameters['fieldId']!,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // Branch 13: Media (optional top-level tab)
          StatefulShellBranch(
            navigatorKey: _mediaNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutePaths.media,
                builder: (context, state) => const MediaSettingsScreen(
                  branch: MediaNavigationBranch.media,
                ),
                routes: [
                  GoRoute(
                    path: 'usage',
                    builder: (context, state) => TagUsageScreen(
                      usages: state.extra is List<TagUsageRef>
                          ? state.extra! as List<TagUsageRef>
                          : const <TagUsageRef>[],
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Branch 14: Mood (optional top-level tab)
          StatefulShellBranch(
            navigatorKey: _moodNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutePaths.mood,
                builder: (context, state) => const MoodScreen(),
              ),
            ],
          ),
          // Branch 15: Calendar (optional top-level tab)
          StatefulShellBranch(
            navigatorKey: _calendarNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutePaths.calendar,
                builder: (context, state) => const CalendarScreen(),
              ),
            ],
          ),
          // Branch 16: Locations (optional top-level tab)
          StatefulShellBranch(
            navigatorKey: _locationsNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutePaths.locations,
                builder: (context, state) => const LocationsScreen(),
              ),
            ],
          ),
          // Branch 17: Work (optional top-level tab)
          StatefulShellBranch(
            navigatorKey: _workNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutePaths.work,
                builder: (context, state) => const WorkScreen(),
              ),
            ],
          ),
          // Branch 18: Daily Insights (optional top-level tab)
          StatefulShellBranch(
            navigatorKey: _insightsNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutePaths.insights,
                builder: (context, state) => const DailyInsightsScreen(),
              ),
            ],
          ),
          // Branch 19: Cycle (optional top-level tab)
          StatefulShellBranch(
            navigatorKey: _cycleNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutePaths.cycle,
                builder: (context, state) => const CycleScreen(),
              ),
            ],
          ),
          // Branch 20: Contacts (optional top-level tab)
          StatefulShellBranch(
            navigatorKey: _contactsNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutePaths.contacts,
                builder: (context, state) => const ContactsScreen(),
              ),
            ],
          ),
          // Branch 21: Journal (optional top-level tab)
          StatefulShellBranch(
            navigatorKey: _journalNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutePaths.journal,
                builder: (context, state) => const JournalScreen(),
              ),
            ],
          ),
          // Branch 22: Dictionary (optional top-level tab)
          StatefulShellBranch(
            navigatorKey: _dictionaryNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutePaths.dictionary,
                builder: (context, state) => const DictionaryScreen(),
              ),
            ],
          ),
          // Branch 23: Achievements (optional top-level tab)
          StatefulShellBranch(
            navigatorKey: _achievementsNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutePaths.achievements,
                builder: (context, state) => const AchievementsScreen(),
              ),
            ],
          ),
          // Branch 24: Fitness (optional top-level tab)
          StatefulShellBranch(
            navigatorKey: _fitnessNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutePaths.fitness,
                builder: (context, state) => const FitnessScreen(),
              ),
            ],
          ),
          // Branch 25: Finance (optional top-level tab)
          StatefulShellBranch(
            navigatorKey: _financeNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutePaths.finance,
                builder: (context, state) => const FinanceScreen(),
              ),
            ],
          ),
          // Branch 26: School (optional top-level tab)
          StatefulShellBranch(
            navigatorKey: _schoolNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutePaths.school,
                builder: (context, state) => const SchoolScreen(),
              ),
            ],
          ),
          // Branch 27: Relationships (optional top-level tab)
          StatefulShellBranch(
            navigatorKey: _relationshipsNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutePaths.relationships,
                builder: (context, state) => const RelationshipsHubScreen(),
                routes: [
                  GoRoute(
                    path: 'r/:id',
                    builder: (context, state) => RelationshipProfileScreen(id: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          // Branch 28: Subsystems (optional top-level tab)
          StatefulShellBranch(
            navigatorKey: _subsystemsNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutePaths.subsystems,
                builder: (context, state) => const SubsystemHubScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => SubsystemProfileScreen(id: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          // Branch 29: Headspace (optional top-level tab)
          StatefulShellBranch(
            navigatorKey: _headspaceNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutePaths.headspace,
                builder: (context, state) => const HeadspaceScreen(),
              ),
            ],
          ),
          // Branch 30: Music (optional top-level tab)
          StatefulShellBranch(
            navigatorKey: _musicNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutePaths.music,
                builder: (context, state) => const MusicScreen(),
              ),
            ],
          ),
          // Branch 31: Stories (optional top-level tab)
          StatefulShellBranch(
            navigatorKey: _storiesNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutePaths.stories,
                builder: (context, state) => const StoriesScreen(),
              ),
            ],
          ),
          // Branch 32: Nourish (optional top-level tab)
          StatefulShellBranch(
            navigatorKey: _nutritionNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutePaths.nutrition,
                builder: (context, state) => const NutritionScreen(),
              ),
            ],
          ),
          // Branch 33: Scrapbook (optional top-level tab)
          StatefulShellBranch(
            navigatorKey: _scrapbookNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutePaths.scrapbook,
                builder: (context, state) => const ScrapbooksScreen(),
              ),
            ],
          ),
          // Branch 34: Connections (optional top-level tab)
          StatefulShellBranch(
            navigatorKey: _connectionsNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutePaths.connections,
                builder: (context, state) => const ConnectionsScreen(),
              ),
            ],
          ),
          // Branch 35: Analytics (optional top-level tab)
          StatefulShellBranch(
            navigatorKey: _analyticsNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutePaths.analytics,
                builder: (context, state) => const AnalyticsHubScreen(),
              ),
            ],
          ),
          // Branch 36: Availability (optional top-level tab)
          StatefulShellBranch(
            navigatorKey: _availabilityNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutePaths.availability,
                builder: (context, state) => const AvailabilityScreen(),
              ),
            ],
          ),
          // Branch 37: Introductions (optional top-level tab)
          StatefulShellBranch(
            navigatorKey: _introductionsNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutePaths.introductions,
                builder: (context, state) => const IntroCardsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  void logRoute() {
    final c = router.routerDelegate.currentConfiguration;
    FreezeWatchdog.crumb('page ${c.isEmpty ? '-' : c.fullPath}');
  }

  router.routerDelegate.addListener(logRoute);
  ref.onDispose(() => router.routerDelegate.removeListener(logRoute));
  return router;
});

/// Keyboard shortcut target (Alt+Shift+A): the quick accessibility panel.
class _QuickA11yPage extends StatelessWidget {
  const _QuickA11yPage();

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460, maxHeight: 640),
      child: Material(
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: const Padding(
          padding: EdgeInsets.only(top: 16),
          child: A11yQuickPanel(),
        ),
      ),
    ),
  );
}
