import 'package:flutter/material.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';

abstract final class AppRoutePaths {
  // Tabs
  static const home = '/';
  static const chat = '/chat';
  static const habits = '/habits';
  static const polls = '/polls';
  static const settings = '/settings';
  static const members = '/members';
  static const reminders = '/reminders';
  static const notes = '/notes';
  static const statistics = '/statistics';
  static const sleep = '/sleep';
  static const boards = '/boards';
  static const groups = '/groups';
  static const media = '/media';
  static const mediaUsage = '/media/usage';
  static const mood = '/mood';
  static const calendar = '/calendar';
  static const locations = '/locations';
  static const work = '/work';
  static const insights = '/insights';
  static const cycle = '/cycle';
  static const contacts = '/contacts';
  static const journal = '/journal';
  static const dictionary = '/dictionary';
  static const achievements = '/achievements';
  static const fitness = '/fitness';
  static const finance = '/finance';
  static const school = '/school';
  static const relationships = '/relationships';
  static const subsystems = '/subsystems';
  static const headspace = '/headspace';
  static const music = '/music';
  static const stories = '/stories';
  static const nutrition = '/nutrition';
  static const scrapbook = '/scrapbook';
  static const connections = '/connections';
  static const analytics = '/analytics';
  static const availability = '/availability';
  static const introductions = '/introductions';
  static const prismSocial = '/prism-social';
  static const health = '/health';

  /// A Health entry (opens it if the current alter may see it).
  static String healthEntry(String id) => '/health?entry=${Uri.encodeQueryComponent(id)}';

  /// Body sensations recorded on a Mood check-in, now in Health › Body Map.
  static String healthMoodSensations(String moodId) => '/health?tab=map&mood=${Uri.encodeQueryComponent(moodId)}';
  static const importCenter = '/import';
  static const systemTimeline = '/system-timeline';
  static const patterns = '/patterns';
  static const sleepLog = '/sleep-log';
  static const cycleInsights = '/cycle-insights';
  static const pollStats = '/poll-stats';
  static const frontingNotification = '/fronting-notification';
  static const homeWidgets = '/home-widgets';
  static const widgetStudioRoute = '/home-widgets/studio/:type';
  static String widgetStudio(String type, {int? id}) =>
      '/home-widgets/studio/$type${id == null ? '' : '?id=$id'}';
  static const todos = '/todos';
  static const nowPlaying = '/now-playing';
  static const boardMessages = '/boards/messages';
  static const socialPostRoute = '/social/post/:id';
  static const socialAlterRoute = '/social/alter/:id';
  static const socialTagRoute = '/social/tag/:tag';
  static const socialDrafts = '/social/drafts';
  static const socialReports = '/social/reports';
  static const headmateBanners = '/headmate-banners';
  static String socialPost(String id) => '/social/post/$id';
  static String socialAlter(String id) => '/social/alter/$id';
  static String socialTag(String tag) => '/social/tag/${Uri.encodeComponent(tag)}';
  static const appearanceStudio = '/appearance-studio';
  static const accessibilityQuick = '/accessibility-quick';

  // Settings sub-routes
  static const settingsMembers = '/settings/members';
  static const settingsNotifications = '/settings/notifications';
  static const settingsFeatures = '/settings/features';
  static const settingsFeaturesChat = '/settings/features/chat';
  static const settingsFeaturesHabits = '/settings/features/habits';
  static const settingsFeaturesFronting = '/settings/features/fronting';
  static const settingsFeaturesSleep = '/settings/features/sleep';
  static const settingsFeaturesPolls = '/settings/features/polls';
  static const settingsFeaturesNotes = '/settings/features/notes';
  static const settingsFeaturesReminders = '/settings/features/reminders';
  static const settingsAppearance = '/settings/appearance';
  static const settingsTerminology = '/settings/terminology';
  static const settingsAccessibility = '/settings/accessibility';
  static const settingsHabits = '/settings/habits';
  static const settingsStatistics = '/settings/statistics';
  static const settingsSync = '/settings/sync';
  static const settingsImportExport = '/settings/import-export';
  static const settingsReset = '/settings/reset';
  static const settingsSharing = '/settings/sharing';
  static const settingsDatabase = '/settings/database';
  static const settingsAbout = '/settings/about';
  static const settingsDebug = '/settings/debug';
  static const settingsComponentGallery = '/settings/component-gallery';
  static const settingsCustomFieldIconDebug =
      '/settings/custom-field-icon-debug';
  static const settingsSyncDebug = '/settings/sync-debug';
  static const settingsCryptoStorageDebug = '/settings/crypto-storage-debug';
  static const settingsErrors = '/settings/errors';
  static const settingsPluralkit = '/settings/pluralkit';
  static const settingsPluralkitSyncDebug = '/settings/pluralkit/sync-debug';
  static const settingsMigration = '/settings/migration';
  static const settingsSyncTroubleshooting = '/settings/sync-troubleshooting';
  static const settingsSyncTroubleshootingTips =
      '/settings/sync-troubleshooting/tips';
  static const settingsDevices = '/settings/devices';
  static const settingsSyncVerifyBackup = '/settings/sync/verify-backup';
  static const settingsDataBrowser = '/settings/data-browser';
  static const settingsMembersManage = '/settings/members/manage';
  static const settingsGroups = '/settings/members/groups';
  static const settingsCustomFields = '/settings/custom-fields';
  static const settingsAnalytics = '/settings/analytics';
  static const settingsPinLock = '/settings/pin-lock';
  static const settingsReminders = '/settings/reminders';
  static const settingsNavigation = '/settings/navigation';
  static const settingsMedia = '/settings/media';
  static const settingsMediaUsage = '/settings/media/usage';
  static const settingsSystemInfo = '/settings/system-info';
  static const settingsPalette = '/settings/appearance/palette';
  static const settingsLaunch = '/settings/appearance/launch';
  static const whosThere = '/whos-there';
  static const settingsFrontStatuses = '/settings/fronting-statuses';
  static const settingsMoments = '/settings/moments';
  static const cycleImport = '/cycle-import';
  static const integrations = '/integrations';
  static const account = '/account';
  static const timeline = '/timeline';

  /// Astro: the system astrology hub, and one alter's astrology.
  static const astro = '/astro';
  static String astroAlter(String memberId, {String? section}) =>
      '/astro/alter/${Uri.encodeComponent(memberId)}${section == null ? '' : '?section=$section'}';

  /// Games: the recreation hub, one game, a custom game, a game night.
  static const games = '/games';
  static String gamePlay(String id, {String? challenge, String? custom, String? night}) {
    final q = {if (challenge != null) 'challenge': challenge, if (custom != null) 'custom': custom, if (night != null) 'night': night};
    return '/games/play/${Uri.encodeComponent(id)}${q.isEmpty ? '' : '?${Uri(queryParameters: q).query}'}';
  }

  static String gameNight(String id) => '/games/night/${Uri.encodeComponent(id)}';

  /// Cozy: shared spaces, letters, garden, comfort and collections.
  static const cozy = '/cozy';
  static String cozyRoom(String id) => '/cozy/room/${Uri.encodeComponent(id)}';

  // Parameterized helpers — groups
  static String memberGroup(String id) => '/members/groups/$id';
  static String settingsGroup(String id) => '/settings/members/groups/$id';
  static String group(String id) => '/groups/$id';
  static String groupMember(String groupId, String memberId) =>
      '/groups/$groupId/member/$memberId';
  static String groupMemberFrontingHistory(String groupId, String memberId) =>
      '/groups/$groupId/member/$memberId/fronting';
  static String groupMemberConversations(String groupId, String memberId) =>
      '/groups/$groupId/member/$memberId/conversations';
  static String groupMemberCustomFieldGroup(
    String groupId,
    String memberId,
    String fieldId,
  ) => '/groups/$groupId/member/$memberId/custom-fields/$fieldId';

  // Full-screen routes
  static const onboarding = '/onboarding';
  static const secretKeySetup = '/secret-key-setup';
  static const syncSetup = '/sync-setup';

  // Parameterized helpers
  static String chatConversation(String id) => '/chat/$id';
  static String session(String id) => '/session/$id';
  static String sessionEdit(String id) => '/session/$id/edit';
  static String sleepSession(String id) => '/sleep/session/$id';
  static String poll(String id) => '/polls/$id';
  static String habit(String id) => '/habits/$id';
  static String note(String id) => '/notes/$id';
  static String settingsNote(String id) => '/settings/notes/$id';
  static String member(String id) => '/members/$id';
  static String memberFrontingHistory(String id) => '/members/$id/fronting';
  static String memberConversations(String id) => '/members/$id/conversations';
  static String memberCustomFieldGroup(String id, String fieldId) =>
      '/members/$id/custom-fields/$fieldId';
  static String settingsMember(String id) => '/settings/members/$id';
  static String settingsMemberFrontingHistory(String id) =>
      '/settings/members/$id/fronting';
  static String settingsMemberConversations(String id) =>
      '/settings/members/$id/conversations';
  static String settingsMemberCustomFieldGroup(String id, String fieldId) =>
      '/settings/members/$id/custom-fields/$fieldId';
  static String settingsCustomField(String id) => '/settings/custom-fields/$id';
  static String settingsHabit(String id) => '/settings/habits/$id';
  static String settingsFriend(String id) => '/settings/sharing/$id';
  static String memberBoard(String id) => '/boards/member/$id';
  static String boardPost(String id) => '/boards/post/$id';
  static String period(List<String> sessionIds) {
    final sorted = [...sessionIds]..sort();
    final qs = sorted
        .map((id) => 'id=${Uri.encodeQueryComponent(id)}')
        .join('&');
    return '/period?$qs';
  }
}

List<String> parsePeriodIds(Uri uri) {
  final ids = uri.queryParametersAll['id'] ?? const <String>[];
  return [...ids]..sort();
}

abstract final class AppRouteNames {
  static const home = 'home';
  static const chat = 'chat';
  static const habits = 'habits';
  static const polls = 'polls';
  static const settings = 'settings';
  static const members = 'members';
  static const reminders = 'reminders';
  static const notes = 'notes';
  static const statistics = 'statistics';
  static const settingsSync = 'settings-sync';
  static const settingsSyncVerifyBackup = 'settings-sync-verify-backup';
  static const onboarding = 'onboarding';
  static const secretKeySetup = 'secret-key-setup';
  static const syncSetup = 'sync-setup';
  static const timeline = 'timeline';
  static const boards = 'boards';
  static const memberBoard = 'member-board';
  static const boardPost = 'board-post';
  static const groups = 'groups';
}

enum AppShellTabId {
  home,
  chat,
  habits,
  polls,
  settings,
  members,
  reminders,
  notes,
  statistics,
  timeline,
  sleep,
  boards,
  groups,
  media,
  mood,
  calendar,
  locations,
  work,
  insights,
  cycle,
  contacts,
  journal,
  dictionary,
  achievements,
  fitness,
  finance,
  school,
  relationships,
  subsystems,
  headspace,
  music,
  stories,
  nutrition,
  scrapbook,
  connections,
  analytics,
  availability,
  introductions,
  social,
  health,
  astro,
  games,
  cozy,
}

class AppShellTab {
  const AppShellTab({
    required this.id,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.branchIndex,
    required this.rootLocation,
  });

  final AppShellTabId id;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final int branchIndex;
  final String rootLocation;

  /// Whether this tab is locked in the nav bar (cannot be removed/reordered).
  bool get isLocked => false;

  /// Whether this tab must remain reachable from either the nav bar or More.
  /// Home and Settings are required so users cannot softlock themselves out of
  /// core fronting history or config.
  bool get isRequired =>
      id == AppShellTabId.home || id == AppShellTabId.settings;

  /// Display label, substituting user's terminology for the Members tab.
  String displayLabel({String? terminologyPlural}) {
    if (id == AppShellTabId.members && terminologyPlural != null) {
      return terminologyPlural;
    }
    return label;
  }

  /// Localized display label using [context] for l10n.
  /// For the Members tab, uses [terminologyPlural] (the user's custom term) if provided.
  String localizedLabel(BuildContext context, {String? terminologyPlural}) {
    if (id == AppShellTabId.members && terminologyPlural != null) {
      return terminologyPlural;
    }
    final l10n = context.l10n;
    return switch (id) {
      AppShellTabId.home => l10n.navHome,
      AppShellTabId.chat => l10n.navChat,
      AppShellTabId.habits => l10n.navHabits,
      AppShellTabId.polls => l10n.navPolls,
      AppShellTabId.settings => l10n.navSettings,
      AppShellTabId.members => l10n.navMembers,
      AppShellTabId.reminders => l10n.navReminders,
      AppShellTabId.notes => l10n.navNotes,
      AppShellTabId.statistics => l10n.navStatistics,
      AppShellTabId.timeline => l10n.navTimeline,
      AppShellTabId.sleep => l10n.navSleep,
      AppShellTabId.boards => l10n.navBoards,
      AppShellTabId.groups => l10n.navGroups,
      AppShellTabId.media => l10n.navMedia,
      AppShellTabId.mood => l10n.navMood,
      AppShellTabId.calendar => l10n.navCalendar,
      AppShellTabId.locations => l10n.navLocations,
      AppShellTabId.work => l10n.navWork,
      AppShellTabId.insights => l10n.navInsights,
      AppShellTabId.cycle => l10n.navCycle,
      AppShellTabId.contacts => l10n.navContacts,
      AppShellTabId.journal => l10n.navJournal,
      AppShellTabId.dictionary => l10n.navDictionary,
      AppShellTabId.achievements => l10n.navAchievements,
      AppShellTabId.fitness => l10n.navFitness,
      AppShellTabId.finance => l10n.navFinance,
      AppShellTabId.school => l10n.navSchool,
      AppShellTabId.relationships => l10n.navRelationships,
      AppShellTabId.subsystems => l10n.navSubsystems,
      AppShellTabId.headspace => l10n.navHeadspace,
      AppShellTabId.music => l10n.navMusic,
      AppShellTabId.stories => l10n.navStories,
      AppShellTabId.nutrition => l10n.navNutrition,
      AppShellTabId.scrapbook => l10n.navScrapbook,
      AppShellTabId.connections => l10n.navConnections,
      AppShellTabId.analytics => l10n.navAnalytics,
      AppShellTabId.availability => l10n.navAvailability,
      AppShellTabId.introductions => l10n.navIntroductions,
      AppShellTabId.social => 'Social',
      AppShellTabId.health => l10n.localeName.startsWith('es') ? 'Salud' : 'Health',
      AppShellTabId.astro => 'Astro',
      AppShellTabId.games => l10n.localeName.startsWith('es') ? 'Juegos' : 'Games',
      AppShellTabId.cozy => l10n.localeName.startsWith('es') ? 'Acogedor' : 'Cozy',
    };
  }

  bool isEnabled(
    ({
      bool chat,
      bool polls,
      bool habits,
      bool sleep,
      bool notes,
      bool reminders,
      bool boards,
    })
    flags,
  ) {
    return switch (id) {
      AppShellTabId.home => true,
      AppShellTabId.chat => flags.chat,
      AppShellTabId.habits => flags.habits,
      AppShellTabId.polls => flags.polls,
      AppShellTabId.settings => true,
      AppShellTabId.members => true,
      AppShellTabId.reminders => flags.reminders,
      AppShellTabId.notes => flags.notes,
      AppShellTabId.statistics => true,
      AppShellTabId.timeline => true,
      AppShellTabId.sleep => flags.sleep,
      AppShellTabId.boards => flags.boards,
      AppShellTabId.groups => true,
      AppShellTabId.media => true,
      AppShellTabId.mood => true,
      AppShellTabId.calendar => true,
      AppShellTabId.locations => true,
      AppShellTabId.work => true,
      AppShellTabId.insights => true,
      AppShellTabId.cycle => true,
      AppShellTabId.contacts => true,
      AppShellTabId.journal => true,
      AppShellTabId.dictionary => true,
      AppShellTabId.achievements => true,
      AppShellTabId.fitness => true,
      AppShellTabId.finance => true,
      AppShellTabId.school => true,
      AppShellTabId.relationships => true,
      AppShellTabId.subsystems => true,
      AppShellTabId.headspace => true,
      AppShellTabId.music => true,
      AppShellTabId.stories => true,
      AppShellTabId.nutrition => true,
      AppShellTabId.scrapbook => true,
      AppShellTabId.connections => true,
      AppShellTabId.analytics => true,
      AppShellTabId.availability => true,
      AppShellTabId.introductions => true,
      AppShellTabId.social => true,
      AppShellTabId.health => true,
      AppShellTabId.astro => true,
      AppShellTabId.games => true,
      AppShellTabId.cozy => true,
    };
  }
}

final appShellTabs = [
  AppShellTab(
    id: AppShellTabId.home,
    label: 'Home',
    icon: AppIcons.navHome,
    activeIcon: AppIcons.navHomeActive,
    branchIndex: 0,
    rootLocation: AppRoutePaths.home,
  ),
  AppShellTab(
    id: AppShellTabId.chat,
    label: 'Chat',
    icon: AppIcons.navChat,
    activeIcon: AppIcons.navChatActive,
    branchIndex: 1,
    rootLocation: AppRoutePaths.chat,
  ),
  AppShellTab(
    id: AppShellTabId.habits,
    label: 'Habits',
    icon: AppIcons.navHabits,
    activeIcon: AppIcons.navHabitsActive,
    branchIndex: 2,
    rootLocation: AppRoutePaths.habits,
  ),
  AppShellTab(
    id: AppShellTabId.polls,
    label: 'Polls',
    icon: AppIcons.navPolls,
    activeIcon: AppIcons.navPollsActive,
    branchIndex: 3,
    rootLocation: AppRoutePaths.polls,
  ),
  AppShellTab(
    id: AppShellTabId.settings,
    label: 'Settings',
    icon: AppIcons.navSettings,
    activeIcon: AppIcons.navSettingsActive,
    branchIndex: 4,
    rootLocation: AppRoutePaths.settings,
  ),
  AppShellTab(
    id: AppShellTabId.members,
    label: 'Members',
    icon: AppIcons.navMembers,
    activeIcon: AppIcons.navMembersActive,
    branchIndex: 5,
    rootLocation: AppRoutePaths.members,
  ),
  AppShellTab(
    id: AppShellTabId.reminders,
    label: 'Reminders',
    icon: AppIcons.navReminders,
    activeIcon: AppIcons.navRemindersActive,
    branchIndex: 6,
    rootLocation: AppRoutePaths.reminders,
  ),
  AppShellTab(
    id: AppShellTabId.notes,
    label: 'Notes',
    icon: AppIcons.navNotes,
    activeIcon: AppIcons.navNotesActive,
    branchIndex: 7,
    rootLocation: AppRoutePaths.notes,
  ),
  AppShellTab(
    id: AppShellTabId.statistics,
    label: 'Statistics',
    icon: AppIcons.navStatistics,
    activeIcon: AppIcons.navStatisticsActive,
    branchIndex: 8,
    rootLocation: AppRoutePaths.statistics,
  ),
  AppShellTab(
    id: AppShellTabId.timeline,
    label: 'Timeline',
    icon: AppIcons.navTimeline,
    activeIcon: AppIcons.navTimelineActive,
    branchIndex: 9,
    rootLocation: AppRoutePaths.timeline,
  ),
  AppShellTab(
    id: AppShellTabId.sleep,
    label: 'Sleep',
    icon: AppIcons.navSleep,
    activeIcon: AppIcons.navSleepActive,
    branchIndex: 10,
    rootLocation: AppRoutePaths.sleep,
  ),
  AppShellTab(
    id: AppShellTabId.boards,
    label: 'Boards',
    // shared with Chat — both surfaces use the conversation glyph
    icon: AppIcons.navBoards,
    activeIcon: AppIcons.navBoardsActive,
    branchIndex: 11,
    rootLocation: AppRoutePaths.boards,
  ),
  AppShellTab(
    id: AppShellTabId.groups,
    label: 'Groups',
    icon: AppIcons.navGroups,
    activeIcon: AppIcons.navGroupsActive,
    branchIndex: 12,
    rootLocation: AppRoutePaths.groups,
  ),
  AppShellTab(
    id: AppShellTabId.media,
    label: 'Media',
    icon: AppIcons.navMedia,
    activeIcon: AppIcons.navMediaActive,
    branchIndex: 13,
    rootLocation: AppRoutePaths.media,
  ),
  AppShellTab(
    id: AppShellTabId.mood,
    label: 'Mood',
    icon: AppIcons.navMood,
    activeIcon: AppIcons.navMoodActive,
    branchIndex: 14,
    rootLocation: AppRoutePaths.mood,
  ),
  AppShellTab(
    id: AppShellTabId.calendar,
    label: 'Calendar',
    icon: AppIcons.navCalendar,
    activeIcon: AppIcons.navCalendarActive,
    branchIndex: 15,
    rootLocation: AppRoutePaths.calendar,
  ),
  AppShellTab(
    id: AppShellTabId.locations,
    label: 'Locations',
    icon: AppIcons.navLocations,
    activeIcon: AppIcons.navLocationsActive,
    branchIndex: 16,
    rootLocation: AppRoutePaths.locations,
  ),
  AppShellTab(
    id: AppShellTabId.work,
    label: 'Work',
    icon: AppIcons.navWork,
    activeIcon: AppIcons.navWorkActive,
    branchIndex: 17,
    rootLocation: AppRoutePaths.work,
  ),
  AppShellTab(
    id: AppShellTabId.insights,
    label: 'Insights',
    icon: AppIcons.navInsights,
    activeIcon: AppIcons.navInsightsActive,
    branchIndex: 18,
    rootLocation: AppRoutePaths.insights,
  ),
  AppShellTab(
    id: AppShellTabId.cycle,
    label: 'Cycle',
    icon: AppIcons.navCycle,
    activeIcon: AppIcons.navCycleActive,
    branchIndex: 19,
    rootLocation: AppRoutePaths.cycle,
  ),
  AppShellTab(
    id: AppShellTabId.contacts,
    label: 'Contacts',
    icon: AppIcons.navContacts,
    activeIcon: AppIcons.navContactsActive,
    branchIndex: 20,
    rootLocation: AppRoutePaths.contacts,
  ),
  AppShellTab(
    id: AppShellTabId.journal,
    label: 'Journal',
    icon: AppIcons.navJournal,
    activeIcon: AppIcons.navJournalActive,
    branchIndex: 21,
    rootLocation: AppRoutePaths.journal,
  ),
  AppShellTab(
    id: AppShellTabId.dictionary,
    label: 'Dictionary',
    icon: AppIcons.navDictionary,
    activeIcon: AppIcons.navDictionaryActive,
    branchIndex: 22,
    rootLocation: AppRoutePaths.dictionary,
  ),
  AppShellTab(
    id: AppShellTabId.achievements,
    label: 'Achievements',
    icon: AppIcons.navAchievements,
    activeIcon: AppIcons.navAchievementsActive,
    branchIndex: 23,
    rootLocation: AppRoutePaths.achievements,
  ),
  AppShellTab(
    id: AppShellTabId.fitness,
    label: 'Fitness',
    icon: AppIcons.navFitness,
    activeIcon: AppIcons.navFitnessActive,
    branchIndex: 24,
    rootLocation: AppRoutePaths.fitness,
  ),
  AppShellTab(
    id: AppShellTabId.finance,
    label: 'Finance',
    icon: AppIcons.navFinance,
    activeIcon: AppIcons.navFinanceActive,
    branchIndex: 25,
    rootLocation: AppRoutePaths.finance,
  ),
  AppShellTab(
    id: AppShellTabId.school,
    label: 'School',
    icon: AppIcons.navSchool,
    activeIcon: AppIcons.navSchoolActive,
    branchIndex: 26,
    rootLocation: AppRoutePaths.school,
  ),
  AppShellTab(
    id: AppShellTabId.relationships,
    label: 'Relationships',
    icon: AppIcons.navRelationships,
    activeIcon: AppIcons.navRelationshipsActive,
    branchIndex: 27,
    rootLocation: AppRoutePaths.relationships,
  ),
  AppShellTab(
    id: AppShellTabId.subsystems,
    label: 'Subsystems',
    icon: AppIcons.navSubsystems,
    activeIcon: AppIcons.navSubsystemsActive,
    branchIndex: 28,
    rootLocation: AppRoutePaths.subsystems,
  ),
  AppShellTab(
    id: AppShellTabId.headspace,
    label: 'Headspace',
    icon: AppIcons.navHeadspace,
    activeIcon: AppIcons.navHeadspaceActive,
    branchIndex: 29,
    rootLocation: AppRoutePaths.headspace,
  ),
  AppShellTab(
    id: AppShellTabId.music,
    label: 'Music',
    icon: AppIcons.navMusic,
    activeIcon: AppIcons.navMusicActive,
    branchIndex: 30,
    rootLocation: AppRoutePaths.music,
  ),
  AppShellTab(
    id: AppShellTabId.stories,
    label: 'Stories',
    icon: AppIcons.navStories,
    activeIcon: AppIcons.navStoriesActive,
    branchIndex: 31,
    rootLocation: AppRoutePaths.stories,
  ),
  AppShellTab(
    id: AppShellTabId.nutrition,
    label: 'Nourish',
    icon: AppIcons.navNutrition,
    activeIcon: AppIcons.navNutritionActive,
    branchIndex: 32,
    rootLocation: AppRoutePaths.nutrition,
  ),
  AppShellTab(
    id: AppShellTabId.scrapbook,
    label: 'Scrapbook',
    icon: AppIcons.navScrapbook,
    activeIcon: AppIcons.navScrapbookActive,
    branchIndex: 33,
    rootLocation: AppRoutePaths.scrapbook,
  ),
  AppShellTab(
    id: AppShellTabId.connections,
    label: 'Connections',
    icon: AppIcons.navConnections,
    activeIcon: AppIcons.navConnectionsActive,
    branchIndex: 34,
    rootLocation: AppRoutePaths.connections,
  ),
  AppShellTab(
    id: AppShellTabId.analytics,
    label: 'Analytics',
    icon: AppIcons.navAnalytics,
    activeIcon: AppIcons.navAnalyticsActive,
    branchIndex: 35,
    rootLocation: AppRoutePaths.analytics,
  ),
  AppShellTab(
    id: AppShellTabId.availability,
    label: 'Availability',
    icon: AppIcons.navAvailability,
    activeIcon: AppIcons.navAvailabilityActive,
    branchIndex: 36,
    rootLocation: AppRoutePaths.availability,
  ),
  AppShellTab(
    id: AppShellTabId.introductions,
    label: 'Introductions',
    icon: AppIcons.navIntroductions,
    activeIcon: AppIcons.navIntroductionsActive,
    branchIndex: 37,
    rootLocation: AppRoutePaths.introductions,
  ),
  AppShellTab(
    id: AppShellTabId.social,
    label: 'Social',
    icon: AppIcons.navSocial,
    activeIcon: AppIcons.navSocialActive,
    branchIndex: 38,
    rootLocation: AppRoutePaths.prismSocial,
  ),
  AppShellTab(
    id: AppShellTabId.health,
    label: 'Health',
    icon: AppIcons.navHealth,
    activeIcon: AppIcons.navHealthActive,
    branchIndex: 39,
    rootLocation: AppRoutePaths.health,
  ),
  AppShellTab(
    id: AppShellTabId.astro,
    label: 'Astro',
    icon: AppIcons.navAstro,
    activeIcon: AppIcons.navAstroActive,
    branchIndex: 40,
    rootLocation: AppRoutePaths.astro,
  ),
  AppShellTab(
    id: AppShellTabId.games,
    label: 'Games',
    icon: AppIcons.navGames,
    activeIcon: AppIcons.navGamesActive,
    branchIndex: 41,
    rootLocation: AppRoutePaths.games,
  ),
  AppShellTab(
    id: AppShellTabId.cozy,
    label: 'Cozy',
    icon: AppIcons.navCozy,
    activeIcon: AppIcons.navCozyActive,
    branchIndex: 42,
    rootLocation: AppRoutePaths.cozy,
  ),
];

/// The default nav bar tab IDs when no custom configuration exists.
const defaultNavBarTabIds = ['home', 'chat', 'habits', 'polls', 'settings'];

/// The default overflow (More menu) tab IDs when no custom configuration
/// exists. Tabs whose feature flag is off are filtered out by
/// [AppShellTab.isEnabled], so disabling Notes or Reminders in onboarding
/// removes them automatically.
const defaultNavBarOverflowTabIds = [
  'members',
  'groups',
  'calendar',
  'mood',
  'health',
  'astro',
  'games',
  'cozy',
  'insights',
  'locations',
  'work',
  'cycle',
  'contacts',
  'journal',
  'dictionary',
  'achievements',
  'fitness',
  'finance',
  'school',
  'relationships',
  'social',
  'subsystems',
  'headspace',
  'music',
  'stories',
  'nutrition',
  'scrapbook',
  'connections',
  'analytics',
  'availability',
  'introductions',
  'notes',
  'reminders',
  'statistics',
  'timeline',
  'sleep',
  'boards',
];

/// Maximum number of tabs that can appear in the primary nav bar. Excess
/// tabs spill into the overflow menu. This constraint is enforced by
/// [normalizeNavLayout] and is the single source of truth for both the
/// settings UI and the rendered nav bar.
const int kMaxPrimaryNavTabs = 5;
