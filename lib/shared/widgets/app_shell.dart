import 'dart:async';
import 'package:prism_plurality/core/diagnostics/freeze_watchdog.dart';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_plurality/shared/navigation/prism_back.dart';
import 'package:prism_plurality/features/appearance/models/look.dart';
import 'package:prism_plurality/shared/theme/look_theme.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/core/database/database_provider.dart';
import 'package:prism_plurality/core/router/notification_navigation.dart';
import 'package:prism_plurality/core/router/notification_navigation_providers.dart';
import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/core/sync/prism_sync_providers.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/models/system_settings.dart';
import 'package:prism_plurality/features/boards/providers/board_posts_providers.dart';
import 'package:prism_plurality/features/chat/providers/chat_providers.dart';
import 'package:prism_plurality/features/fronting/migration/fronting_migration_service.dart';
import 'package:prism_plurality/features/fronting/migration/providers/fronting_migration_providers.dart';
import 'package:prism_plurality/features/fronting/migration/views/fronting_upgrade_sheet.dart';
import 'package:prism_plurality/features/fronting/providers/fronting_providers.dart';
import 'package:prism_plurality/features/habits/providers/habit_providers.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/pluralkit/providers/pk_auto_poll_provider.dart';
import 'package:prism_plurality/features/pluralkit/providers/pluralkit_providers.dart';
import 'package:prism_plurality/features/settings/providers/pin_lock_providers.dart';
import 'package:prism_plurality/features/settings/providers/settings_providers.dart';
import 'package:prism_plurality/features/settings/views/pin_input_screen.dart';
import 'package:prism_plurality/features/settings/widgets/sync_pin_sheet.dart';
import 'package:prism_plurality/features/settings/widgets/sync_rewrap_sheet.dart';
import 'package:prism_plurality/features/settings/widgets/sync_toast_listener.dart';
import 'package:prism_plurality/features/settings/providers/terminology_provider.dart';
import 'package:prism_plurality/shared/theme/prism_shapes.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/core/features/feature_registry.dart' show FeatureCategory, featureByTab, prismFeatures;
import 'package:prism_plurality/core/features/feature_state.dart' show featureStatesProvider;
import 'package:prism_plurality/core/app_icon/app_icon.dart' show appIconProvider, customAppIconProvider;
import 'package:flutter/services.dart' show HardwareKeyboard, KeyDownEvent, KeyEvent, LogicalKeyboardKey;
import 'package:prism_plurality/shared/utils/desktop_breakpoint.dart';
import 'package:prism_plurality/shared/utils/haptics.dart';
import 'package:prism_plurality/shared/utils/nav_bar_layout.dart';
import 'package:prism_plurality/shared/utils/pin_lock_decision.dart';
import 'package:prism_plurality/shared/widgets/floating_nav_bar_backdrop.dart';

/// Gap between overflow row and primary row when the nav bar is expanded.
const _kNavBarRowGap = 6.0;

/// Width of the compact More/close trigger on the trailing edge.
const _kMoreButtonWidth = 44.0;

/// Border width used by the floating nav container decoration.
const _kNavBarBorderWidth = 1.0;

const _kNavBarSelectedItemPillHeight = 32.0;
const _kNavBarSelectedItemPillTop = 8.0;
const _kNavBarPrimaryPillHorizontalInset = 8.0;
const _kNavBarIconOnlyIconOpticalOffsetY = 1.0;
const _kNavBarLabelRevealSlotHeight = kNavBarLabelFontSize + 4.0;

/// Extra vertical breathing room around the icon + label stack so scaled text
/// still fits after decoration insets and font metric differences.
const _kNavBarItemVerticalPadding = 12.0;

Color _navSelectedPillColor(ThemeData theme) {
  final colors = theme.colorScheme;
  final isDark = theme.brightness == Brightness.dark;
  return Color.alphaBlend(
    colors.primary.withValues(alpha: isDark ? 0.20 : 0.14),
    (isDark ? colors.surfaceContainerHighest : colors.surfaceContainerHigh)
        .withValues(alpha: isDark ? 0.72 : 0.88),
  );
}

Color _sidebarSelectedFillColor(ThemeData theme) {
  final colors = theme.colorScheme;
  final isDark = theme.brightness == Brightness.dark;
  return Color.alphaBlend(
    colors.primary.withValues(alpha: isDark ? 0.16 : 0.10),
    (isDark ? colors.surfaceContainerHigh : colors.surfaceContainer).withValues(
      alpha: isDark ? 0.64 : 0.78,
    ),
  );
}

Color _navInactiveIconColor(ThemeData theme) {
  return theme.colorScheme.onSurfaceVariant.withValues(
    alpha: theme.brightness == Brightness.dark ? 0.68 : 0.72,
  );
}

Color _navInactiveLabelColor(ThemeData theme, {double darkAlpha = 0.58}) {
  return theme.colorScheme.onSurfaceVariant.withValues(
    alpha: theme.brightness == Brightness.dark ? darkAlpha : 0.72,
  );
}

@visibleForTesting
double floatingNavBarExpandedHeight(
  int overflowRows, {
  double rowHeight = kFloatingNavBarHeight,
  double? overflowRowHeight,
}) {
  final resolvedOverflowRowHeight = overflowRowHeight ?? rowHeight;
  if (overflowRows <= 0) return rowHeight;
  return rowHeight +
      (resolvedOverflowRowHeight * overflowRows) +
      (_kNavBarRowGap * overflowRows);
}

/// Pure decision used by [AppShell] to decide whether to auto-surface
/// the per-member fronting upgrade modal, and whether the modal should
/// be dismissible.
///
/// Defined as a top-level function so the rule lives in one place and
/// can be unit-tested without spinning up the full widget tree.
///
/// Inputs:
/// - [gate]: resolved [FrontingMigrationGateStatus] from
///   [frontingMigrationGateProvider].
/// - [rawMode]: the underlying `pending_fronting_migration_mode`
///   string. Kept for diagnostic context and future mode-specific policy.
///
/// Returns:
/// - `shouldShow == false`: gate is `complete`.
/// - `shouldShow == false`: gate is still resolving and `rawMode` is null.
/// - `shouldShow == false`: gate is transiently `needsModal` from a
///   loading/error state while `rawMode` already says `complete`.
/// - `shouldShow == true, isDismissible == false`: any state where the
///   user must pick a recovery path before runtime new-shape work
///   resumes — `blocked`, `inProgress`, or `needsModal`.
@visibleForTesting
FrontingUpgradeSheetDecision frontingUpgradeSheetDecision({
  required FrontingMigrationGateStatus gate,
  required String? rawMode,
}) {
  switch (gate) {
    case FrontingMigrationGateStatus.complete:
      return const FrontingUpgradeSheetDecision.hidden();
    case FrontingMigrationGateStatus.blocked:
    case FrontingMigrationGateStatus.inProgress:
      // Hard read-only states — modal is the only recovery surface.
      return const FrontingUpgradeSheetDecision.show(isDismissible: false);
    case FrontingMigrationGateStatus.needsModal:
      if (rawMode == null || rawMode == FrontingMigrationService.modeComplete) {
        // The gate provider intentionally blocks writes while the DAO stream
        // is loading, but the UI should not surface the migration modal until
        // the stored mode resolves to a concrete pending/retry sentinel.
        // Riverpod reloads can keep the last concrete stream value while the
        // collapsed gate is temporarily `needsModal`; if that value is already
        // `complete`, a normal install must remain quiet.
        return const FrontingUpgradeSheetDecision.hidden();
      }
      if (rawMode != FrontingMigrationService.modeNotStarted &&
          rawMode != FrontingMigrationService.modeDeferred &&
          rawMode != FrontingMigrationService.modeUpgradeAndKeep &&
          rawMode != FrontingMigrationService.modeStartFresh) {
        return const FrontingUpgradeSheetDecision.hidden();
      }
      // First-time prompt, legacy deferred sentinel, or crashed-retry
      // sentinels. Present non-dismissible until the user picks a path.
      return const FrontingUpgradeSheetDecision.show(isDismissible: false);
  }
}

/// Result of [frontingUpgradeSheetDecision].
@immutable
@visibleForTesting
class FrontingUpgradeSheetDecision {
  const FrontingUpgradeSheetDecision.hidden()
    : shouldShow = false,
      isDismissible = false;
  const FrontingUpgradeSheetDecision.show({required this.isDismissible})
    : shouldShow = true;

  final bool shouldShow;
  final bool isDismissible;

  @override
  bool operator ==(Object other) =>
      other is FrontingUpgradeSheetDecision &&
      other.shouldShow == shouldShow &&
      other.isDismissible == isDismissible;

  @override
  int get hashCode => Object.hash(shouldShow, isDismissible);

  @override
  String toString() =>
      'FrontingUpgradeSheetDecision('
      'shouldShow: $shouldShow, isDismissible: $isDismissible)';
}

double _measureNavBarLabelHeight({
  required List<String> labels,
  required double slotWidth,
  required TextStyle labelStyle,
  required TextScaler textScaler,
  required TextDirection textDirection,
}) {
  if (labels.isEmpty) return 0;

  var maxLabelHeight = 0.0;
  final maxWidth = math.max(0.0, slotWidth);

  for (final label in labels) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: labelStyle),
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: 1,
    )..layout(maxWidth: maxWidth);
    maxLabelHeight = math.max(maxLabelHeight, painter.height);
  }

  return maxLabelHeight;
}

double _measurePrimaryNavBarRowHeight({
  required List<String> primaryLabels,
  required double barWidth,
  required bool usesOverflowMenu,
  required int primaryCount,
  required TextStyle labelStyle,
  required TextScaler textScaler,
  required TextDirection textDirection,
}) {
  if (primaryCount <= 0) return kFloatingNavBarHeight;

  final primarySlotWidth = math.max(
    0.0,
    (barWidth - (usesOverflowMenu ? 16.0 + _kMoreButtonWidth : 24.0)) /
        primaryCount,
  );
  final maxPrimaryLabelHeight = _measureNavBarLabelHeight(
    labels: primaryLabels,
    slotWidth: primarySlotWidth,
    labelStyle: labelStyle,
    textScaler: textScaler,
    textDirection: textDirection,
  );

  return math.max(
    kFloatingNavBarHeight,
    kNavBarItemIconHeight +
        maxPrimaryLabelHeight +
        _kNavBarItemVerticalPadding +
        (_kNavBarBorderWidth * 2),
  );
}

@visibleForTesting
double navBarPrimaryPillLayoutHeight({required bool prominentIcons}) {
  return prominentIcons
      ? kNavBarIconOnlyItemIconHeight
      : _kNavBarSelectedItemPillHeight;
}

@visibleForTesting
double navBarPrimaryPillHeight({
  required bool prominentIcons,
  required double labelVisibility,
}) {
  if (!prominentIcons) return _kNavBarSelectedItemPillHeight;
  return lerpDouble(
    kNavBarIconOnlyItemIconHeight,
    _kNavBarSelectedItemPillHeight,
    labelVisibility.clamp(0.0, 1.0).toDouble(),
  )!;
}

@visibleForTesting
double navBarPrimaryPillScaleY({
  required bool prominentIcons,
  required double labelVisibility,
}) {
  final layoutHeight = navBarPrimaryPillLayoutHeight(
    prominentIcons: prominentIcons,
  );
  return navBarPrimaryPillHeight(
        prominentIcons: prominentIcons,
        labelVisibility: labelVisibility,
      ) /
      layoutHeight;
}

@visibleForTesting
double navBarLabelRevealLiftY({required double labelVisibility}) {
  return labelVisibility.clamp(0.0, 1.0).toDouble() *
      _kNavBarLabelRevealSlotHeight /
      2;
}

@visibleForTesting
double navBarPrimaryPillLayoutTop({
  required double rowHeight,
  required bool prominentIcons,
}) {
  if (!prominentIcons) return _kNavBarSelectedItemPillTop;
  final layoutHeight = navBarPrimaryPillLayoutHeight(
    prominentIcons: prominentIcons,
  );
  return (rowHeight - layoutHeight).clamp(0.0, rowHeight) / 2;
}

@visibleForTesting
double navBarPrimaryPillTop({
  required double rowHeight,
  required bool prominentIcons,
  required double labelVisibility,
}) {
  if (!prominentIcons) return _kNavBarSelectedItemPillTop;
  final visibility = labelVisibility.clamp(0.0, 1.0).toDouble();
  final pillHeight = navBarPrimaryPillHeight(
    prominentIcons: prominentIcons,
    labelVisibility: visibility,
  );
  final centerY =
      (rowHeight / 2) - navBarLabelRevealLiftY(labelVisibility: visibility);
  return (centerY - (pillHeight / 2)).clamp(0.0, rowHeight);
}

@visibleForTesting
double navBarPrimaryPillPaintOffsetY({
  required double rowHeight,
  required bool prominentIcons,
  required double labelVisibility,
}) {
  final layoutHeight = navBarPrimaryPillLayoutHeight(
    prominentIcons: prominentIcons,
  );
  final visualHeight = navBarPrimaryPillHeight(
    prominentIcons: prominentIcons,
    labelVisibility: labelVisibility,
  );
  return navBarPrimaryPillTop(
        rowHeight: rowHeight,
        prominentIcons: prominentIcons,
        labelVisibility: labelVisibility,
      ) -
      navBarPrimaryPillLayoutTop(
        rowHeight: rowHeight,
        prominentIcons: prominentIcons,
      ) -
      ((layoutHeight - visualHeight) / 2);
}

@visibleForTesting
double navBarPrimaryContentOffsetX({
  required double segmentWidth,
  required bool prominentIcons,
  required double pillWidth,
}) {
  if (!prominentIcons) return 0.0;
  return _kNavBarPrimaryPillHorizontalInset +
      (pillWidth / 2) -
      (segmentWidth / 2);
}

@visibleForTesting
double navBarIconOpticalOffsetY({required bool prominentIcons}) {
  return prominentIcons ? _kNavBarIconOnlyIconOpticalOffsetY : 0.0;
}

@visibleForTesting
double navBarEffectiveLabelVisibility({
  required NavBarLabelVisibility labelVisibility,
  required double expandProgress,
}) {
  return switch (labelVisibility) {
    NavBarLabelVisibility.always => 1.0,
    NavBarLabelVisibility.never => 0.0,
    NavBarLabelVisibility.whenExpanded =>
      expandProgress.clamp(0.0, 1.0).toDouble(),
  };
}

double _measureOverflowNavBarRowHeight({
  required List<String> overflowLabels,
  required double barWidth,
  required int overflowColumns,
  required TextStyle labelStyle,
  required TextScaler textScaler,
  required TextDirection textDirection,
}) {
  if (overflowLabels.isEmpty || overflowColumns <= 0) {
    return kFloatingNavBarHeight;
  }

  final overflowSlotWidth = math.max(0.0, (barWidth - 24.0) / overflowColumns);
  final maxOverflowLabelHeight = _measureNavBarLabelHeight(
    labels: overflowLabels,
    slotWidth: overflowSlotWidth,
    labelStyle: labelStyle,
    textScaler: textScaler,
    textDirection: textDirection,
  );

  return math.max(
    kFloatingNavBarHeight,
    kNavBarItemIconHeight +
        maxOverflowLabelHeight +
        _kNavBarItemVerticalPadding,
  );
}

class AppShellMobileNavLayout {
  const AppShellMobileNavLayout({
    required this.spec,
    required this.primaryTabs,
    required this.overflowTabs,
    required this.rowHeight,
    required this.overflowRowHeight,
  });

  final NavBarLayoutSpec spec;
  final List<AppShellTab> primaryTabs;
  final List<AppShellTab> overflowTabs;
  final double rowHeight;
  final double overflowRowHeight;

  List<AppShellTab> get allTabs => [...primaryTabs, ...overflowTabs];
  double get expandedHeight => floatingNavBarExpandedHeight(
    spec.overflowRows,
    rowHeight: rowHeight,
    overflowRowHeight: overflowRowHeight,
  );
}

/// Cheap signature for [computeAdaptiveMobileNavLayout] inputs. Built from
/// the values that influence label measurement: bar width, the label strings,
/// text scale, text direction, and the label style height (font size +
/// weight). Two signatures that compare equal produce identical layouts, so
/// we can skip the ~20-30 `TextPainter.layout()` calls the function performs.
@immutable
class _NavLayoutSignature {
  const _NavLayoutSignature({
    required this.barWidth,
    required this.primaryLabels,
    required this.overflowLabels,
    required this.textScaleFactor,
    required this.textDirection,
    required this.fontSize,
    required this.fontWeight,
    required this.labelVisibility,
    required this.labelStyleMode,
  });

  final double barWidth;
  final List<String> primaryLabels;
  final List<String> overflowLabels;
  final double textScaleFactor;
  final TextDirection textDirection;
  final double fontSize;
  final FontWeight fontWeight;
  final NavBarLabelVisibility labelVisibility;
  final NavBarLabelStyle labelStyleMode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _NavLayoutSignature &&
        other.barWidth == barWidth &&
        other.textScaleFactor == textScaleFactor &&
        other.textDirection == textDirection &&
        other.fontSize == fontSize &&
        other.fontWeight == fontWeight &&
        other.labelVisibility == labelVisibility &&
        other.labelStyleMode == labelStyleMode &&
        _listEquals(other.primaryLabels, primaryLabels) &&
        _listEquals(other.overflowLabels, overflowLabels);
  }

  @override
  int get hashCode => Object.hash(
    barWidth,
    textScaleFactor,
    textDirection,
    fontSize,
    fontWeight,
    labelVisibility,
    labelStyleMode,
    Object.hashAll(primaryLabels),
    Object.hashAll(overflowLabels),
  );

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Counter incremented inside [computeAdaptiveMobileNavLayout] for every
/// call that does not hit the memoization cache. Tests read this to assert
/// that repeated rebuilds with identical inputs reuse the cached layout.
@visibleForTesting
int debugAdaptiveMobileNavLayoutComputeCount = 0;

AppShellMobileNavLayout computeAdaptiveMobileNavLayout({
  required double barWidth,
  required List<AppShellTab> primaryTabs,
  required List<AppShellTab> overflowTabs,
  required List<String> primaryLabels,
  required List<String> overflowLabels,
  required TextStyle labelStyle,
  required TextScaler textScaler,
  required TextDirection textDirection,
  NavBarLabelVisibility labelVisibility = NavBarLabelVisibility.always,
  NavBarLabelStyle labelStyleMode = NavBarLabelStyle.full,
}) {
  assert(primaryTabs.length == primaryLabels.length);
  assert(overflowTabs.length == overflowLabels.length);

  debugAdaptiveMobileNavLayoutComputeCount++;

  final spec = computeNavBarLayoutSpec(
    barWidth: barWidth,
    primaryLabels: primaryLabels,
    overflowLabels: overflowLabels,
    labelStyle: labelStyle,
    textScaler: textScaler,
    textDirection: textDirection,
    labelVisibility: labelVisibility,
    labelStyleMode: labelStyleMode,
  );
  final split = splitNavBarTabsForLayout(
    primary: primaryTabs,
    overflow: overflowTabs,
    spec: spec,
  );
  // Labels only occupy the collapsed bar when always-visible; otherwise the
  // collapsed bar is icons-only and reveal happens on expand, so row heights
  // are measured without label text (matching the icons-only geometry).
  final showCollapsedLabels = labelVisibility == NavBarLabelVisibility.always;
  final visualPrimaryLabels = showCollapsedLabels
      ? primaryLabels.take(spec.collapsedPrimaryCount).toList()
      : const <String>[];
  final visualOverflowLabels = showCollapsedLabels
      ? [...primaryLabels.skip(spec.collapsedPrimaryCount), ...overflowLabels]
      : const <String>[];
  final rowHeight = _measurePrimaryNavBarRowHeight(
    primaryLabels: visualPrimaryLabels,
    barWidth: barWidth,
    usesOverflowMenu: spec.usesOverflowMenu,
    primaryCount: split.primary.length,
    labelStyle: labelStyle,
    textScaler: textScaler,
    textDirection: textDirection,
  );
  final overflowRowHeight = _measureOverflowNavBarRowHeight(
    overflowLabels: visualOverflowLabels,
    barWidth: barWidth,
    overflowColumns: spec.overflowColumns,
    labelStyle: labelStyle,
    textScaler: textScaler,
    textDirection: textDirection,
  );

  return AppShellMobileNavLayout(
    spec: spec,
    primaryTabs: split.primary,
    overflowTabs: split.overflow,
    rowHeight: rowHeight,
    overflowRowHeight: overflowRowHeight,
  );
}

/// Incremented each time the user taps the already-selected tab.
/// Screens can watch this to scroll-to-top or perform other re-engage actions.
final tabRetapProvider = NotifierProvider<TabRetapNotifier, int>(
  TabRetapNotifier.new,
);

class TabRetapNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void fire() => state++;
}

int appShellBranchIndex(AppShellTabId id) =>
    appShellTabs.firstWhere((tab) => tab.id == id).branchIndex;

@immutable
class TabSelectionEvent {
  const TabSelectionEvent({
    required this.branchIndex,
    required this.sequence,
    required this.isRetap,
  });

  final int branchIndex;
  final int sequence;
  final bool isRetap;
}

/// Emits the shell branch selected by the user.
final tabSelectionProvider =
    NotifierProvider<TabSelectionNotifier, TabSelectionEvent?>(
      TabSelectionNotifier.new,
    );

class TabSelectionNotifier extends Notifier<TabSelectionEvent?> {
  var _sequence = 0;

  @override
  TabSelectionEvent? build() => null;

  void fire({required int branchIndex, required bool isRetap}) {
    state = TabSelectionEvent(
      branchIndex: branchIndex,
      sequence: ++_sequence,
      isRetap: isRetap,
    );
  }
}

/// Provides the actual floating nav bar inset to descendant widgets.
/// Use `NavBarInset.of(context)` to get the total bottom space to pad content.
class NavBarInset extends InheritedWidget {
  const NavBarInset({
    super.key,
    required this.bottomInset,
    required super.child,
  });

  /// Total height from the bottom of the screen that the nav bar occupies
  /// (bar height + margin + safe area). Screens should use this for bottom
  /// padding on scrollable content.
  final double bottomInset;

  static double of(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<NavBarInset>();
    return widget?.bottomInset ?? 0;
  }

  @override
  bool updateShouldNotify(NavBarInset oldWidget) =>
      bottomInset != oldWidget.bottomInset;
}

/// Nav bar dimensions.
const kFloatingNavBarHeight = 64.0;
const kFloatingNavBarSideMargin = 16.0;
const kFloatingNavBarBottomMargin = 8.0;

/// Sidebar dimensions.
const _kSidebarWidth = 200.0;
const _kSidebarItemHeight = 38.0;

/// Wraps [child] in a [Badge] for tabs that have notifications.
Widget _maybeBadge({
  required AppShellTab tab,
  required bool showSyncBadge,
  required int habitsDueCount,
  required int chatUnreadCount,
  required int boardsBadge,
  required Widget child,
}) {
  if (tab.id == AppShellTabId.settings && showSyncBadge) {
    return Badge(isLabelVisible: true, smallSize: 8, child: child);
  }
  if (tab.id == AppShellTabId.habits && habitsDueCount > 0) {
    return Badge(label: Text('$habitsDueCount'), child: child);
  }
  if (tab.id == AppShellTabId.chat && chatUnreadCount > 0) {
    return Badge(
      label: Text(chatUnreadCount > 99 ? '99+' : '$chatUnreadCount'),
      child: child,
    );
  }
  if (tab.id == AppShellTabId.boards && boardsBadge > 0) {
    return Badge(
      label: Text(boardsBadge > 99 ? '99+' : '$boardsBadge'),
      child: child,
    );
  }
  return child;
}

/// True when the two members have identical values for every field the PK
/// member PATCH payload actually carries — kept in lock-step with
/// `PkPushService._memberToPayload`'s auto-push keys. `proxyTagsJson` is NOT
/// compared (auto-push passes `includeProxyTags: false`, so a tag-only edit
/// would fire a PATCH that can't carry it). Purely-local fields (emoji,
/// avatar bytes, in-app display name, etc.) must NOT trigger a PK push.
bool _pkSyncRelevantFieldsEqual(Member a, Member b) {
  return a.pluralkitDisplayName == b.pluralkitDisplayName &&
      a.pronouns == b.pronouns &&
      a.bio == b.bio &&
      a.birthday == b.birthday &&
      a.customColorEnabled == b.customColorEnabled &&
      a.customColorHex == b.customColorHex;
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.routePath,
  });

  final StatefulNavigationShell navigationShell;

  /// Current route path used to distinguish tab roots from detail routes.
  final String routePath;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  bool _notificationDrainScheduled = false;
  bool _notificationDrainBusy = false;
  bool _notificationDrainRequested = false;
  int _notificationLifecycleEpoch = 0;
  NotificationIntentClaim? _notificationClaim;
  NotificationNavigation? _notificationOwner;

  bool _notificationPrivacyReady() {
    if (!mounted ||
        !_pinCheckResolved ||
        _locked ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return false;
    }
    final settings = ref.read(systemSettingsProvider);
    if (settings.isLoading ||
        settings.hasError ||
        settings.value?.hasCompletedOnboarding != true) {
      return false;
    }
    final health = ref.read(syncHealthProvider);
    if (health == SyncHealthState.needsPassword ||
        health == SyncHealthState.needsRewrap ||
        health == SyncHealthState.awaitingDeviceUnlock ||
        health == SyncHealthState.runtimeDekRestoreDeferred ||
        ref.read(syncPasswordSheetVisibleProvider) ||
        ref.read(syncRewrapSheetVisibleProvider) ||
        _frontingUpgradeSheetShowing ||
        ref.read(frontingMigrationGateProvider) !=
            FrontingMigrationGateStatus.complete) {
      return false;
    }
    return true;
  }

  bool _notificationReady() =>
      _notificationPrivacyReady() &&
      ref.read(databaseReadyProvider).hasValue &&
      !ref.read(databaseReadyProvider).isLoading &&
      !ref.read(databaseReadyProvider).hasError &&
      ref.read(notificationTapBootstrapProvider).hasValue &&
      !ref.read(notificationTapBootstrapProvider).isLoading &&
      !ref.read(notificationTapBootstrapProvider).hasError;

  void _scheduleNotificationDrain() {
    if (!mounted) return;
    if (_notificationDrainBusy) {
      _notificationDrainRequested = true;
      return;
    }
    if (_notificationDrainScheduled) return;
    _notificationDrainScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationDrainScheduled = false;
      if (mounted) unawaited(_drainNotificationIntent());
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  Future<void> _drainNotificationIntent() async {
    if (_notificationDrainBusy || !_notificationReady()) return;
    final intents = ref.read(notificationNavigationProvider.notifier);
    if (intents.contextChanging || intents.pending == null) return;
    // Credential identity is resolved only here, after all privacy gates. It
    // is never a dependency of the plugin/bootstrap or pure intake queue.
    final identity = ref.read(syncIdProvider);
    if (identity.isLoading || identity.hasError || !identity.hasValue) return;
    intents.bindAuthorizedContext(identity.value);
    final claim = intents.claim();
    if (claim == null) return;
    _notificationDrainBusy = true;
    _notificationClaim = claim;
    _notificationOwner = intents;
    final lockEpoch = _lockGeneration;
    final lifecycleEpoch = _notificationLifecycleEpoch;
    final contextEpoch = intents.contextEpoch;
    try {
      String? destination;
      if (claim.intent.isAstro) {
        final id = claim.intent.astroMemberId!;
        final members = ref.read(userVisibleMembersProvider).value ?? const [];
        if (members.any((m) => m.id == id)) {
          destination = AppRoutePaths.astroAlter(id, section: 'horoscope');
        }
      } else if (claim.intent.isFronting) {
        if (ref.read(systemSettingsProvider).value?.frontingRemindersEnabled ==
            true) {
          destination = AppRoutePaths.home;
        }
      } else if (ref.read(featureFlagsProvider).reminders) {
        final reminder = await ref
            .read(remindersRepositoryProvider)
            .getById(claim.intent.reminderId!);
        if (reminder != null && reminder.isActive) {
          destination = AppRoutePaths.reminders;
        }
      }
      if (!mounted ||
          !_notificationReady() ||
          lockEpoch != _lockGeneration ||
          lifecycleEpoch != _notificationLifecycleEpoch ||
          contextEpoch != intents.contextEpoch ||
          !intents.isCurrent(claim)) {
        return;
      }
      final currentIdentity = ref.read(syncIdProvider);
      if (currentIdentity.isLoading ||
          currentIdentity.hasError ||
          !currentIdentity.hasValue) {
        return;
      }
      intents.bindAuthorizedContext(currentIdentity.value);
      // Feature settings may change during the repository await.
      if (claim.intent.isAstro
          ? false
          : claim.intent.isFronting
          ? ref.read(systemSettingsProvider).value?.frontingRemindersEnabled !=
                true
          : !ref.read(featureFlagsProvider).reminders) {
        destination = null;
      }
      if (!intents.complete(claim)) return;
      if (destination != null) GoRouter.of(context).go(destination);
    } catch (_) {
      // Malformed/stale or unavailable targets never trigger writes or expose
      // platform payload text through logs, errors or UI.
      if (mounted && _notificationReady()) intents.complete(claim);
    } finally {
      intents.release(claim);
      _notificationClaim = null;
      _notificationOwner = null;
      _notificationDrainBusy = false;
      if (_notificationDrainRequested) {
        _notificationDrainRequested = false;
        if (mounted) _scheduleNotificationDrain();
      }
    }
  }

  bool _wasDesktop = false;
  bool _webSidebarCollapsed = false;
  bool _locked = false;
  int _lockGeneration = 0;

  /// Whether the initial PIN check has completed. While false, the app shows
  /// a loading/locked state to prevent content from being visible before we
  /// know whether PIN lock is enabled.
  bool _pinCheckResolved = false;
  bool _navExpanded = false;
  bool _syncConfigureRetryInFlight = false;
  final _navBarKey = GlobalKey<_FloatingNavBarState>();
  DateTime? _backgroundedAt;

  // Memoized mobile nav layout. Cached across rebuilds triggered by unrelated
  // providers (sync health, badge counts, theme) so we don't re-run the ~20-30
  // `TextPainter.layout()` calls in `computeAdaptiveMobileNavLayout` every
  // frame. Invalidated automatically when the signature changes (label set,
  // text scale, locale, bar width).
  _NavLayoutSignature? _cachedNavLayoutSignature;
  AppShellMobileNavLayout? _cachedNavLayout;

  AppShellMobileNavLayout _memoizedMobileNavLayout({
    required double barWidth,
    required List<AppShellTab> primaryTabs,
    required List<AppShellTab> overflowTabs,
    required List<String> primaryLabels,
    required List<String> overflowLabels,
    required TextStyle labelStyle,
    required TextScaler textScaler,
    required TextDirection textDirection,
    required NavBarLabelVisibility labelVisibility,
    required NavBarLabelStyle labelStyleMode,
  }) {
    final signature = _NavLayoutSignature(
      barWidth: barWidth,
      primaryLabels: primaryLabels,
      overflowLabels: overflowLabels,
      textScaleFactor: textScaler.scale(1),
      textDirection: textDirection,
      fontSize: labelStyle.fontSize ?? 12.0,
      fontWeight: labelStyle.fontWeight ?? FontWeight.w500,
      labelVisibility: labelVisibility,
      labelStyleMode: labelStyleMode,
    );
    final cached = _cachedNavLayout;
    if (cached != null && _cachedNavLayoutSignature == signature) {
      return cached;
    }
    final layout = computeAdaptiveMobileNavLayout(
      barWidth: barWidth,
      primaryTabs: primaryTabs,
      overflowTabs: overflowTabs,
      primaryLabels: primaryLabels,
      overflowLabels: overflowLabels,
      labelStyle: labelStyle,
      textScaler: textScaler,
      textDirection: textDirection,
      labelVisibility: labelVisibility,
      labelStyleMode: labelStyleMode,
    );
    _cachedNavLayoutSignature = signature;
    _cachedNavLayout = layout;
    return layout;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Attempt an immediate check; if providers are still loading,
    // listeners set up in build() will resolve it when they emit data.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialLock();
      // Kick the PK auto-poll into "foregrounded" state on first build.
      ref.read(pkAutoPollProvider.notifier).markForegrounded(true);
    });
  }

  @override
  void dispose() {
    final claim = _notificationClaim;
    if (claim != null) _notificationOwner?.release(claim);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _checkInitialLock() {
    if (_pinCheckResolved) return;

    final settingsAsync = ref.read(systemSettingsProvider);
    final isPinSetAsync = ref.read(isPinSetProvider);

    final decision = initialLockDecision(
      settingsLoading: settingsAsync is AsyncLoading,
      isPinSetLoading: isPinSetAsync is AsyncLoading,
      pinLockEnabled: settingsAsync.value?.pinLockEnabled,
      isPinSet: isPinSetAsync.value,
    );

    if (!decision.resolved) return;

    setState(() {
      _locked = decision.locked;
      _pinCheckResolved = true;
    });
    if (decision.locked) {
      _startHardSyncLockIfEnabled(++_lockGeneration);
    }
  }

  void _lockApp() {
    if (_locked) return;
    final generation = ++_lockGeneration;
    setState(() => _locked = true);
    _startHardSyncLockIfEnabled(generation);
  }

  void _unlockApp() {
    ++_lockGeneration;
    setState(() => _locked = false);
  }

  void _startHardSyncLockIfEnabled(int generation) {
    unawaited(_hardLockSyncIfEnabled(generation));
  }

  Future<void> _hardLockSyncIfEnabled(int generation) async {
    try {
      final enabled = await ref.read(hardLockSyncOnAppLockProvider.future);
      if (!mounted || !enabled || !_locked || generation != _lockGeneration) {
        return;
      }
      await ref.read(syncHealthProvider.notifier).lock(hard: true);
    } catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: st,
          library: 'prism_plurality',
          context: ErrorDescription('hard locking sync on app lock'),
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _notificationLifecycleEpoch++;
    // Face ID can report `inactive` without leaving the foreground.
    // Only hidden/paused states arm auto-lock.
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _backgroundedAt ??= DateTime.now();
      ref.read(pkAutoPollProvider.notifier).markForegrounded(false);
    } else if (state == AppLifecycleState.inactive) {
      ref.read(pkAutoPollProvider.notifier).markForegrounded(false);
    } else if (state == AppLifecycleState.resumed) {
      _checkLockOnResume();
      _backgroundedAt = null;
      ref.invalidate(currentDateProvider);
      ref.read(pkAutoPollProvider.notifier).markForegrounded(true);
      _retryDeferredSyncConfigure();
      if (mounted &&
          ref.read(notificationNavigationProvider.notifier).pending != null) {
        setState(() {});
      }
      _scheduleNotificationDrain();
    }
  }

  /// Retry auto-config after a deferred runtime DEK restore.
  void _retryDeferredSyncConfigure() {
    final health = ref.read(syncHealthProvider);
    if (health != SyncHealthState.awaitingDeviceUnlock &&
        health != SyncHealthState.runtimeDekRestoreDeferred) {
      return;
    }
    final handle = ref.read(prismSyncHandleProvider).value;
    if (handle == null) return;
    if (_syncConfigureRetryInFlight) return;
    _syncConfigureRetryInFlight = true;
    unawaited(
      ref
          .read(prismSyncHandleProvider.notifier)
          .ensureConfigured(handle)
          .whenComplete(() => _syncConfigureRetryInFlight = false),
    );
  }

  void _checkLockOnResume() {
    final settings = ref.read(systemSettingsProvider).value;
    final shouldLock = resumeLockDecision(
      alreadyLocked: _locked,
      pinLockEnabled: settings?.pinLockEnabled,
      isPinSet: ref.read(isPinSetProvider).value,
      backgroundedAt: _backgroundedAt,
      autoLockDelaySeconds: settings?.autoLockDelaySeconds ?? 0,
    );

    if (shouldLock) {
      _lockApp();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(notificationNavigationProvider);
    final pendingNotification = ref
        .read(notificationNavigationProvider.notifier)
        .pending;
    if (pendingNotification != null) {
      // Observe only lightweight gate state before privacy authorization.
      ref.watch(systemSettingsProvider);
      ref.watch(syncPasswordSheetVisibleProvider);
      ref.watch(syncRewrapSheetVisibleProvider);
      if (_notificationPrivacyReady()) {
        ref.watch(databaseReadyProvider);
        ref.watch(notificationTapBootstrapProvider);
        if (_notificationReady()) ref.watch(syncIdProvider);
      }
      _scheduleNotificationDrain();
    }
    // Re-check once async lock settings resolve.
    if (!_pinCheckResolved) {
      ref.listen(systemSettingsProvider, (_, _) => _checkInitialLock());
      ref.listen(isPinSetProvider, (_, _) => _checkInitialLock());
    }

    // Keep the app-lock sync preference alive.
    ref.watch(hardLockSyncOnAppLockProvider);

    // Keep revoke/auth-failure cleanup alive behind privacy gates.
    ref.watch(syncStatusProvider);

    final syncHealth = ref.watch(syncHealthProvider);

    // Only present sync sheets after PIN state resolves and unlocks.
    ref.listen<SyncHealthState>(syncHealthProvider, (prev, next) {
      if (next == SyncHealthState.needsPassword &&
          prev != SyncHealthState.needsPassword &&
          !_locked &&
          _pinCheckResolved) {
        _showPasswordSheetIfNeeded(context, ref);
      }
      if (next == SyncHealthState.needsRewrap &&
          prev != SyncHealthState.needsRewrap &&
          !_locked &&
          _pinCheckResolved) {
        _showRewrapSheetIfNeeded(context, ref);
      }
    });

    // Redact member/fronting routes until auth/privacy gates clear.
    if (!_pinCheckResolved) {
      return const _OpaquePrivacyGate();
    }

    if (_locked) {
      return PinInputScreen(mode: PinInputMode.unlock, onSuccess: _unlockApp);
    }

    if (syncHealth == SyncHealthState.needsPassword) {
      _showPasswordSheetIfNeeded(context, ref);
      return const _OpaquePrivacyGate();
    }

    if (syncHealth == SyncHealthState.needsRewrap) {
      _showRewrapSheetIfNeeded(context, ref);
    }

    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = shouldBeDesktop(width, currentlyDesktop: _wasDesktop);
    _wasDesktop = isDesktop;

    // Providers resolve the configured nav layout. On mobile we may render a
    // smaller primary set at runtime when the current width/text scale cannot
    // fit all configured labels without clipping.
    final configuredPrimaryTabs = ref.watch(activeNavBarTabsProvider);
    final configuredOverflowTabs = ref.watch(navBarOverflowTabsProvider);
    final configuredTabs = [
      ...configuredPrimaryTabs,
      ...configuredOverflowTabs,
    ];
    // Tabs in the bar (or the desktop sidebar, which lists them all) need
    // no back button; every other page gets one.
    PrismNavRoots.update(
      (isDesktop ? configuredTabs : configuredPrimaryTabs).map(
        (t) => t.rootLocation,
      ),
    );

    // Watch the raw mode too, not only the collapsed gate: loading and
    // notStarted both collapse to `needsModal`, so without this watch the
    // shell might not rebuild when the concrete mode resolves.
    final frontingMigrationMode = ref
        .watch(frontingMigrationModeProvider)
        .unwrapPrevious()
        .value;
    final frontingMigrationGate = ref.watch(frontingMigrationGateProvider);

    // Keep the PK auto-poll notifier alive for its timer lifecycle.
    ref.watch(pkAutoPollProvider);

    // Push any pending fronting sessions to PluralKit whenever the active
    // session changes (start / end / switch fronter). Fire-and-forget —
    // the notifier no-ops when PK isn't connected or mapping is incomplete.
    ref.listen(activeSessionsProvider, (_, _) {
      unawaited(
        ref.read(pluralKitSyncProvider.notifier).pushPendingSwitches().then((
          pushed,
        ) {
          if (pushed <= 0 || !context.mounted) return;
          // Prevent the next auto-poll tick from re-ingesting the switch we
          // just authored locally.
          ref.read(pkAutoPollProvider.notifier).noteLocalPush();
        }),
      );
    });

    // Push edits to linked PK members when their sync-relevant fields change.
    // Fire-and-forget; the notifier no-ops when PK isn't connected, direction
    // is pull-only, or the member isn't linked.
    ref.listen(pkSyncRelevantMembersProvider, (prev, next) {
      final prevList = prev?.value;
      final nextList = next.value;
      if (prevList == null || nextList == null) return;
      final prevById = {for (final m in prevList) m.id: m};
      final pkSync = ref.read(pluralKitSyncProvider.notifier);
      for (final m in nextList) {
        if (m.pluralkitId == null || m.pluralkitId!.isEmpty) continue;
        final before = prevById[m.id];
        if (before == null) continue; // newly inserted — handled by imports
        if (_pkSyncRelevantFieldsEqual(before, m)) continue;
        unawaited(() async {
          final fullMember = await ref
              .read(memberRepositoryProvider)
              .getMemberById(m.id);
          if (!mounted || fullMember == null) return;
          await pkSync.pushMemberUpdate(fullMember);
        }());
      }
    });

    // Show the per-member fronting upgrade modal post-unlock.  Mirrors
    // the password-sheet trigger above: only fires once the PIN check
    // has resolved and the lock overlay is down, so the modal renders
    // over the home tabs (not over the lock).
    //
    // We watch the resolved [frontingMigrationGateProvider] rather than
    // the raw mode string so the policy lives at the gate provider and
    // every consumer (PK push/poll, sync apply, this listener) agrees
    // on what blocks runtime new-shape work. See WS1 step 4 + 5 in the
    // remediation plan.
    //
    // Behavior per status:
    // - [FrontingMigrationGateStatus.complete]: hidden.
    // - [FrontingMigrationGateStatus.needsModal]: present non-dismissible.
    // - [FrontingMigrationGateStatus.inProgress]: present non-dismissible.
    //   The modal opens straight to a "Finish migration" screen that
    //   calls `resumeCleanup()` (the Drift transaction committed but a
    //   post-tx step failed).
    // - [FrontingMigrationGateStatus.blocked]: present non-dismissible.
    //   v7 onUpgrade refused the composite index because of duplicates;
    //   the modal is the user's only recovery path.
    ref.listen<FrontingMigrationGateStatus>(frontingMigrationGateProvider, (
      prev,
      next,
    ) {
      if (!_pinCheckResolved || _locked) return;
      final mode = ref
          .read(frontingMigrationModeProvider)
          .unwrapPrevious()
          .value;
      _showFrontingUpgradeSheetIfNeeded(context, ref, next, mode);
    });
    if (!_locked && _pinCheckResolved) {
      _showFrontingUpgradeSheetIfNeeded(
        context,
        ref,
        frontingMigrationGate,
        frontingMigrationMode,
      );
    }

    void onTabSelected(AppShellTab tab, {required bool useHaptics}) {
      if (useHaptics) Haptics.selection();
      final isRetap = tab.branchIndex == widget.navigationShell.currentIndex;
      try {
        widget.navigationShell.goBranch(
          tab.branchIndex,
          initialLocation: isRetap,
        );
      } catch (e) {
        // If restoring the saved branch state fails (e.g. stale sub-route),
        // fall back to the branch's root location.
        debugPrint(
          '[AppShell] goBranch(${tab.branchIndex}) failed: $e '
          '— falling back to root',
        );
        widget.navigationShell.goBranch(tab.branchIndex, initialLocation: true);
      }
      ref
          .read(tabSelectionProvider.notifier)
          .fire(branchIndex: tab.branchIndex, isRetap: isRetap);
      if (isRetap) {
        ref.read(tabRetapProvider.notifier).fire();
      }
    }

    final accentColor = Theme.of(context).colorScheme.primary;

    Widget shell;

    // Wide web windows get a website layout (docked sidebar, wider content).
    final webWide = kIsWeb && isDesktop && width >= kWebDesktopMinWidth;
    PrismTokens.desktopWebContentWidth = webWide
        ? (width - (_webSidebarCollapsed ? kWebSidebarCollapsedWidth : kWebSidebarWidth) - 96).clamp(PrismTokens.mobileContentMaxWidth, 1100.0)
        : null;

    if (isDesktop) {
      final currentVisibleIndex = configuredTabs.indexWhere(
        (t) => t.branchIndex == widget.navigationShell.currentIndex,
      );
      final safeCurrentIndex = currentVisibleIndex < 0
          ? 0
          : currentVisibleIndex;

      // Desktop layout: sidebar + content side by side.
      shell = NavBarInset(
        bottomInset: 0,
        child: SyncToastListener(
          child: webWide
              ? Consumer(
                  builder: (context, ref, _) {
                    final webTabs = ref.watch(webSidebarTabsProvider);
                    // -1 = the open page isn't a sidebar section: highlight nothing.
                    final webIndex = webTabs.indexWhere((t) => t.branchIndex == widget.navigationShell.currentIndex);
                    return _WebDesktopFrame(
                      tabs: webTabs,
                      currentIndex: webIndex,
                      accentColor: accentColor,
                      collapsed: _webSidebarCollapsed,
                      onToggleCollapsed: () => setState(() => _webSidebarCollapsed = !_webSidebarCollapsed),
                      onTap: (index) => onTabSelected(webTabs[index], useHaptics: false),
                      child: BranchTransition(index: widget.navigationShell.currentIndex, child: widget.navigationShell),
                    );
                  },
                )
              : Scaffold(
            resizeToAvoidBottomInset: false,
            body: Row(
              children: [
                _FloatingSidebar(
                  tabs: configuredTabs,
                  currentIndex: safeCurrentIndex,
                  accentColor: accentColor,
                  onTap: (index) =>
                      onTabSelected(configuredTabs[index], useHaptics: false),
                ),
                Expanded(child: BranchTransition(index: widget.navigationShell.currentIndex, child: widget.navigationShell)),
              ],
            ),
          ),
        ),
      );
    } else {
      final terms = watchTerminology(context, ref);
      final labelVisibility = ref.watch(navBarLabelVisibilityProvider);
      final labelStyleMode = ref.watch(navBarLabelStyleProvider);
      final primaryLabels = configuredPrimaryTabs
          .map(
            (tab) =>
                tab.localizedLabel(context, terminologyPlural: terms.plural),
          )
          .toList();
      final overflowLabels = configuredOverflowTabs
          .map(
            (tab) =>
                tab.localizedLabel(context, terminologyPlural: terms.plural),
          )
          .toList();
      final navBarWidth = math.max(
        0.0,
        width - (kFloatingNavBarSideMargin * 2),
      );
      final mobileLayout = _memoizedMobileNavLayout(
        barWidth: navBarWidth,
        primaryTabs: configuredPrimaryTabs,
        overflowTabs: configuredOverflowTabs,
        primaryLabels: primaryLabels,
        overflowLabels: overflowLabels,
        labelStyle: navBarLabelTextStyle(context, isSelected: true),
        textScaler: MediaQuery.textScalerOf(context),
        textDirection: Directionality.of(context),
        labelVisibility: labelVisibility,
        labelStyleMode: labelStyleMode,
      );
      final currentVisibleIndex = mobileLayout.allTabs.indexWhere(
        (t) => t.branchIndex == widget.navigationShell.currentIndex,
      );
      final safeCurrentIndex = currentVisibleIndex < 0
          ? 0
          : currentVisibleIndex;
      final mobilePrimaryLabels = [
        for (final tab in mobileLayout.primaryTabs)
          tab.localizedLabel(context, terminologyPlural: terms.plural),
      ];
      final mobileOverflowLabels = [
        for (final tab in mobileLayout.overflowTabs)
          tab.localizedLabel(context, terminologyPlural: terms.plural),
      ];

      // Mobile layout: stack with floating bottom bar.
      // Hide the nav bar on sub-routes (detail screens) — only show on root tabs.
      final isRootTab = appShellTabs.any(
        (t) => t.rootLocation == widget.routePath,
      );

      final mediaQuery = MediaQuery.of(context);
      final bottomSafeArea = mediaQuery.viewPadding.bottom;
      final keyboardOpen = mediaQuery.viewInsets.bottom > 0;
      final hideNavBar = keyboardOpen || !isRootTab;
      if (hideNavBar && _navExpanded) {
        // Bar is gone — discard any stale expanded state so the overlay
        // doesn't re-appear when the bar returns.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_navExpanded) setState(() => _navExpanded = false);
        });
      }
      final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

      // On iOS the full safe area (~34pt) pushes the floating pill too high.
      // Use a fixed 21pt bottom to sit comfortably above the home indicator.
      final isApple =
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS;
      final navBarBottom = isApple && bottomSafeArea > 0
          ? 21.0
          : kFloatingNavBarBottomMargin + bottomSafeArea;
      final totalInset = mobileLayout.rowHeight + navBarBottom + 8;

      shell = NavBarInset(
        bottomInset: hideNavBar ? 0 : totalInset,
        child: SyncToastListener(
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            body: BackdropGroup(
              child: Stack(
                children: [
                  BranchTransition(index: widget.navigationShell.currentIndex, child: widget.navigationShell),

                  if (!hideNavBar) ...[
                    // Gradient fade
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: FloatingNavBarBackdrop(
                        height: totalInset + 10,
                        color: scaffoldBg,
                      ),
                    ),

                    // Dismiss overlay for expanded nav bar
                    if (_navExpanded)
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            _navBarKey.currentState?._collapse();
                            // Safety: the child may have already rebuilt with
                            // fresh state (bar was hidden and re-shown) so
                            // `_collapse()` can no-op. Reset parent state
                            // unconditionally to avoid a stuck invisible
                            // overlay blocking the screen.
                            if (_navExpanded) {
                              setState(() => _navExpanded = false);
                            }
                          },
                          child: const SizedBox.expand(),
                        ),
                      ),

                    // Floating pill nav bar
                    Positioned(
                      left: kFloatingNavBarSideMargin,
                      right: kFloatingNavBarSideMargin,
                      bottom: navBarBottom,
                      child: RepaintBoundary(
                        child: _FloatingNavBar(
                        key: _navBarKey,
                        primaryTabs: mobileLayout.primaryTabs,
                        primaryLabels: mobilePrimaryLabels,
                        overflowTabs: mobileLayout.overflowTabs,
                        overflowLabels: mobileOverflowLabels,
                        overflowColumns: mobileLayout.spec.overflowColumns,
                        overflowRows: mobileLayout.spec.overflowRows,
                        rowHeight: mobileLayout.rowHeight,
                        overflowRowHeight: mobileLayout.overflowRowHeight,
                        labelVisibility: labelVisibility,
                        labelStyleMode: labelStyleMode,
                        currentIndex: safeCurrentIndex,
                        accentColor: accentColor,
                        onTap: (index) => onTabSelected(
                          mobileLayout.allTabs[index],
                          useHaptics: true,
                        ),
                        onExpandedChanged: (expanded) {
                          setState(() => _navExpanded = expanded);
                        },
                      ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return shell;
  }

  static void _showPasswordSheetIfNeeded(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final isShowing = ref.read(syncPasswordSheetVisibleProvider);
      if (isShowing) return;
      ref.read(syncPasswordSheetVisibleProvider.notifier).setValue(true);
      SyncPinSheet.show(context).whenComplete(() {
        ref.read(syncPasswordSheetVisibleProvider.notifier).setValue(false);
      });
    });
  }

  static void _showRewrapSheetIfNeeded(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final isShowing = ref.read(syncRewrapSheetVisibleProvider);
      if (isShowing) return;
      ref.read(syncRewrapSheetVisibleProvider.notifier).setValue(true);
      SyncRewrapSheet.show(context).whenComplete(() {
        ref.read(syncRewrapSheetVisibleProvider.notifier).setValue(false);
      });
    });
  }

  /// Tracks whether the upgrade modal is already showing so listener
  /// re-fires (each settings stream emit) don't stack duplicate
  /// sheets. Reset in `whenComplete` so a failed/retried modal can re-open.
  bool _frontingUpgradeSheetShowing = false;

  void _showFrontingUpgradeSheetIfNeeded(
    BuildContext context,
    WidgetRef ref,
    FrontingMigrationGateStatus gate,
    String? rawMode,
  ) {
    final decision = frontingUpgradeSheetDecision(gate: gate, rawMode: rawMode);
    if (!decision.shouldShow) return;
    if (_frontingUpgradeSheetShowing) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      if (!_pinCheckResolved || _locked) return;
      if (_frontingUpgradeSheetShowing) return;
      final latestDecision = frontingUpgradeSheetDecision(
        gate: ref.read(frontingMigrationGateProvider),
        rawMode: ref.read(frontingMigrationModeProvider).unwrapPrevious().value,
      );
      if (!latestDecision.shouldShow) return;
      _frontingUpgradeSheetShowing = true;
      showFrontingUpgradeSheet(
        context,
        isDismissible: latestDecision.isDismissible,
      ).whenComplete(() {
        _frontingUpgradeSheetShowing = false;
        _scheduleNotificationDrain();
      });
    });
  }
}

class _OpaquePrivacyGate extends StatelessWidget {
  const _OpaquePrivacyGate();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: const SizedBox.expand(),
    );
  }
}

/// Floating pill-shaped navigation bar with "More" overflow support.
///
/// On mobile this can render fewer than the configured primary tabs when
/// larger labels or text scaling would otherwise clip. Tapping the More
/// trigger expands the pill upward to reveal the rendered overflow rows.
class _FloatingNavBar extends StatefulWidget {
  _FloatingNavBar({
    super.key,
    required this.primaryTabs,
    required this.primaryLabels,
    required this.overflowTabs,
    required this.overflowLabels,
    required this.overflowColumns,
    required this.overflowRows,
    required this.rowHeight,
    required this.overflowRowHeight,
    required this.labelVisibility,
    required this.labelStyleMode,
    required this.currentIndex,
    required this.onTap,
    required this.accentColor,
    this.onExpandedChanged,
  }) : assert(
         overflowTabs.isEmpty
             ? overflowColumns == 0 && overflowRows == 0
             : overflowColumns > 0 && overflowRows > 0,
       ),
       assert(primaryTabs.length == primaryLabels.length),
       assert(overflowTabs.length == overflowLabels.length);

  /// Tabs shown directly in the bar.
  final List<AppShellTab> primaryTabs;
  final List<String> primaryLabels;

  /// Tabs shown in the expanded overflow menu.
  final List<AppShellTab> overflowTabs;
  final List<String> overflowLabels;
  final int overflowColumns;
  final int overflowRows;
  final double rowHeight;
  final double overflowRowHeight;
  final NavBarLabelVisibility labelVisibility;
  final NavBarLabelStyle labelStyleMode;
  final int currentIndex;

  /// Called with the index into [primaryTabs] ++ [overflowTabs].
  final ValueChanged<int> onTap;
  final Color accentColor;
  final ValueChanged<bool>? onExpandedChanged;

  @override
  State<_FloatingNavBar> createState() => _FloatingNavBarState();
}

class _FloatingNavBarState extends State<_FloatingNavBar>
    with TickerProviderStateMixin {
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;
  bool _expanded = false;

  // Sliding pill indicator for the selected tab.
  late AnimationController _pillController;
  static final _pillSpring = SpringDescription.withDampingRatio(
    mass: 0.8,
    stiffness: 250.0,
    ratio: 0.68,
  );

  bool get _needsOverflow => widget.overflowTabs.isNotEmpty;
  double get _overflowAreaHeight {
    if (!_needsOverflow) return 0;
    return widget.overflowRowHeight * widget.overflowRows +
        _kNavBarRowGap * (widget.overflowRows - 1);
  }

  /// Overflow tabs arranged into visual rows with the partial row on top.
  /// Each slot carries the tab's original index for tap/selection mapping;
  /// `null` slots render as empty space.
  List<List<({int index, AppShellTab tab})?>>? _slotsCache;
  List<AppShellTab>? _slotsTabs;
  int? _slotsColumns;

  List<List<({int index, AppShellTab tab})?>> get _overflowRowSlots {
    if (_slotsCache != null && identical(_slotsTabs, widget.overflowTabs) && _slotsColumns == widget.overflowColumns) return _slotsCache!;
    _slotsTabs = widget.overflowTabs;
    _slotsColumns = widget.overflowColumns;
    return _slotsCache = _computeOverflowRowSlots();
  }

  List<List<({int index, AppShellTab tab})?>> _computeOverflowRowSlots() {
    final indexed = [
      for (var i = 0; i < widget.overflowTabs.length; i++)
        (index: i, tab: widget.overflowTabs[i]),
    ];
    return arrangeOverflowRows(indexed, widget.overflowColumns);
  }

  double get _expandedHeight => floatingNavBarExpandedHeight(
    widget.overflowRows,
    rowHeight: widget.rowHeight,
    overflowRowHeight: widget.overflowRowHeight,
  );

  static const _collapsedRadius = 32.0;
  static const _expandedRadius = 28.0;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _pillController = AnimationController.unbounded(
      vsync: this,
      value: _primaryTabIndex >= 0 ? _primaryTabIndex.toDouble() : 0,
    );
  }

  @override
  void didUpdateWidget(covariant _FloatingNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final idx = _primaryTabIndex;
    final primaryChanged = !_sameBranchIndices(
      widget.primaryTabs,
      oldWidget.primaryTabs,
    );
    // If the set of primary tabs changed (tab moved in/out of overflow), the
    // pill's spring target can be stale — snap it to the current index.
    if (primaryChanged) {
      _pillController.stop();
      _pillController.value = idx >= 0 ? idx.toDouble() : 0;
      return;
    }
    if (idx >= 0 && oldWidget.currentIndex != widget.currentIndex) {
      final reduceMotion = MediaQuery.of(context).disableAnimations;
      if (reduceMotion) {
        _pillController.value = idx.toDouble();
      } else {
        final distance = idx.toDouble() - _pillController.value;
        _pillController.animateWith(
          SpringSimulation(
            _pillSpring,
            _pillController.value,
            idx.toDouble(),
            distance * 8,
          ),
        );
      }
    }
  }

  static bool _sameBranchIndices(List<AppShellTab> a, List<AppShellTab> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].branchIndex != b[i].branchIndex) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _expandController.dispose();
    _pillController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    Haptics.selection();
    setState(() {
      _expanded = !_expanded;
      FreezeWatchdog.crumb('nav more ${_expanded ? 'open' : 'close'}');
      if (_expanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
    widget.onExpandedChanged?.call(_expanded);
  }

  void _collapse() {
    if (_expanded) {
      setState(() => _expanded = false);
      _expandController.reverse();
      widget.onExpandedChanged?.call(false);
    }
  }

  void _handleTap(int visibleIndex) {
    _collapse();
    widget.onTap(visibleIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, _) => _buildContent(context, ref));
  }

  Widget _buildContent(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncStatusProvider);
    final showSyncBadge =
        syncStatus.hasQuarantinedItems || syncStatus.lastError != null;
    final habitsBadgeEnabled = ref.watch(habitsBadgeEnabledProvider);
    final dueCount = habitsBadgeEnabled ? ref.watch(dueHabitsCountProvider) : 0;
    final chatUnreadCount = ref.watch(unreadConversationCountProvider);
    final boardsBadge = ref.watch(boardsTabBadgeProvider);

    final isOled = Theme.of(context).scaffoldBackgroundColor == Colors.black;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showLabels = widget.labelVisibility == NavBarLabelVisibility.always;

    if (!_needsOverflow) {
      return _buildSimpleBar(
        showSyncBadge: showSyncBadge,
        dueCount: dueCount,
        chatUnreadCount: chatUnreadCount,
        boardsBadge: boardsBadge,
        isDark: isDark,
        showLabels: showLabels,
      );
    }

    // Overflow mode — expanding pill with adaptive overflow rows.
    final overflowSelected = widget.currentIndex >= widget.primaryTabs.length;

    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, _) {
        final t = _expandAnimation.value;
        final currentHeight =
            widget.rowHeight + (_expandedHeight - widget.rowHeight) * t;
        final showExpandedLabels =
            widget.labelVisibility != NavBarLabelVisibility.never;
        final labelVisibility = navBarEffectiveLabelVisibility(
          labelVisibility: widget.labelVisibility,
          expandProgress: t,
        );
        final prominentIcons =
            widget.labelVisibility != NavBarLabelVisibility.always;
        final radius =
            _collapsedRadius + (_expandedRadius - _collapsedRadius) * t;

        final shapes = PrismShapes.of(context);
        return Semantics(
          container: true,
          label: context.l10n.navigationBar,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(shapes.radius(radius)),
            child: _NavGlass(
              // While the More panel is open or animating, a live blur
              // over the page is recomputed every frame (Android's
              // renderer doesn't cache it) and can stall drawing.
              liveBlur: t == 0,
              child: Container(
                height: currentHeight,
                decoration: _barDecoration(isDark, isOled, radius, shapes),
                child: Column(
                  children: [
                    // Overflow rows (top, revealed by expansion). The partial
                    // row sits on top so the full row is adjacent to the
                    // primary row — more ergonomic than a gap-on-bottom layout.
                    // Kept built (offstage) while collapsed so opening the
                    // bar doesn't have to build every overflow tab in its
                    // first frame, which made the expansion stutter.
                    Offstage(
                      offstage: t == 0,
                      child: ClipRect(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          heightFactor: t,
                          child: SizedBox(
                            height: _overflowAreaHeight,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Column(
                                children: [
                                  for (
                                    var r = 0;
                                    r < _overflowRowSlots.length;
                                    r++
                                  ) ...[
                                    if (r > 0)
                                      const SizedBox(height: _kNavBarRowGap),
                                    SizedBox(
                                      height: widget.overflowRowHeight,
                                      child: _buildOverflowRow(
                                        slots: _overflowRowSlots[r],
                                        expandProgress: t,
                                        isDark: isDark,
                                        showSyncBadge: showSyncBadge,
                                        dueCount: dueCount,
                                        chatUnreadCount: chatUnreadCount,
                                        boardsBadge: boardsBadge,
                                        showLabels: showExpandedLabels,
                                        labelVisibility: labelVisibility,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      ),
                    // Subtle separator line between rows
                    if (t > 0)
                      Opacity(
                        opacity: t,
                        child: Container(
                          height: _kNavBarRowGap * t,
                          alignment: Alignment.center,
                          child: Container(
                            height: 0.5,
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            color: Theme.of(context).colorScheme.outlineVariant
                                .withValues(alpha: isDark ? 0.22 : 0.32),
                          ),
                        ),
                      ),
                    // Primary row (bottom, fills remaining space)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12, right: 4),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final availableForTabs =
                                constraints.maxWidth - _kMoreButtonWidth;
                            final segWidth =
                                availableForTabs / widget.primaryTabs.length;
                            final pillColor = _navSelectedPillColor(
                              Theme.of(context),
                            );

                            final pillHeight = navBarPrimaryPillLayoutHeight(
                              prominentIcons: prominentIcons,
                            );
                            final pillTop = navBarPrimaryPillLayoutTop(
                              rowHeight: widget.rowHeight,
                              prominentIcons: prominentIcons,
                            );
                            final pillPaintOffsetY =
                                navBarPrimaryPillPaintOffsetY(
                                  rowHeight: widget.rowHeight,
                                  prominentIcons: prominentIcons,
                                  labelVisibility: labelVisibility,
                                );
                            final pillScaleY = navBarPrimaryPillScaleY(
                              prominentIcons: prominentIcons,
                              labelVisibility: labelVisibility,
                            );
                            final pillWidth = prominentIcons
                                ? math.min(
                                    segWidth - 8,
                                    kNavBarIconOnlySelectedItemPillWidth,
                                  )
                                : segWidth - 16;
                            final contentOffsetX = navBarPrimaryContentOffsetX(
                              segmentWidth: segWidth,
                              prominentIcons: prominentIcons,
                              pillWidth: pillWidth,
                            );
                            return Stack(
                              children: [
                                // Sliding pill (hidden when overflow tab selected)
                                if (_primaryTabIndex >= 0)
                                  AnimatedBuilder(
                                    animation: _pillController,
                                    builder: (context, child) {
                                      final isRtl =
                                          Directionality.of(context) ==
                                          TextDirection.rtl;
                                      final slot = isRtl
                                          ? (widget.primaryTabs.length -
                                                1 -
                                                _pillController.value)
                                          : _pillController.value;
                                      return Transform.translate(
                                        offset: Offset(
                                          slot * segWidth +
                                              _kNavBarPrimaryPillHorizontalInset,
                                          0,
                                        ),
                                        child: child,
                                      );
                                    },
                                    child: Padding(
                                      padding: EdgeInsets.only(top: pillTop),
                                      child: Transform.translate(
                                        offset: Offset(0, pillPaintOffsetY),
                                        child: Transform.scale(
                                          key: const ValueKey(
                                            'nav_selected_pill_transform',
                                          ),
                                          scaleY: pillScaleY,
                                          child: DecoratedBox(
                                            key: const ValueKey(
                                              'nav_selected_pill',
                                            ),
                                            decoration: BoxDecoration(
                                              color: pillColor,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    PrismShapes.of(
                                                      context,
                                                    ).radius(16),
                                                  ),
                                            ),
                                            child: SizedBox(
                                              width: pillWidth,
                                              height: pillHeight,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                Row(
                                  children: [
                                    // 5 primary tab icons
                                    ...List.generate(
                                      widget.primaryTabs.length,
                                      (i) {
                                        final tab = widget.primaryTabs[i];
                                        final isSelected =
                                            i == _primaryTabIndex;
                                        return Expanded(
                                          child: _NavBarItem(
                                            tab: tab,
                                            label: widget.primaryLabels[i],
                                            isSelected: isSelected,
                                            accentColor: widget.accentColor,
                                            isDark: isDark,
                                            showSyncBadge: showSyncBadge,
                                            habitsDueCount: dueCount,
                                            chatUnreadCount: chatUnreadCount,
                                            boardsBadge: boardsBadge,
                                            rowHeight: widget.rowHeight,
                                            showLabel: showExpandedLabels,
                                            labelVisibility: labelVisibility,
                                            prominentIcon: prominentIcons,
                                            horizontalContentOffset:
                                                contentOffsetX,
                                            onTap: () => _handleTap(i),
                                          ),
                                        );
                                      },
                                    ),
                                    // Compact More/close trigger on trailing edge
                                    _MoreTrigger(
                                      isExpanded: _expanded,
                                      isHighlighted:
                                          _expanded || overflowSelected,
                                      animationValue: t,
                                      accentColor: widget.accentColor,
                                      isDark: isDark,
                                      rowHeight: widget.rowHeight,
                                      prominentIcon: prominentIcons,
                                      onTap: _toggleExpand,
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverflowSlot({
    required ({int index, AppShellTab tab})? slot,
    required double expandProgress,
    required bool isDark,
    required bool showSyncBadge,
    required int dueCount,
    required int chatUnreadCount,
    required int boardsBadge,
    required bool showLabels,
    required double labelVisibility,
  }) {
    if (slot == null) return const SizedBox.shrink();
    // Stagger on the original tab index so icons animate in reading order
    // regardless of how the grid aligns partial rows.
    final staggerStart = (slot.index * 0.08).clamp(0.0, 0.6);
    final staggerEnd = (staggerStart + 0.5).clamp(0.0, 1.0);
    final itemT = Interval(
      staggerStart,
      staggerEnd,
      curve: Curves.easeOut,
    ).transform(expandProgress);
    if (itemT <= 0) return const SizedBox.shrink();

    final isSelected = slot.index == _overflowTabIndex;
    final item = Transform.translate(
      offset: Offset(0, (1 - itemT) * 8),
      child: _NavBarItem(
        tab: slot.tab,
        label: widget.overflowLabels[slot.index],
        isSelected: isSelected,
        accentColor: widget.accentColor,
        isDark: isDark,
        showSyncBadge: showSyncBadge,
        habitsDueCount: dueCount,
        chatUnreadCount: chatUnreadCount,
        boardsBadge: boardsBadge,
        rowHeight: widget.rowHeight,
        showLabel: showLabels,
        labelVisibility: labelVisibility,
        prominentIcon: widget.labelVisibility != NavBarLabelVisibility.always,
        showItemPill: true,
        onTap: () => _handleTap(widget.primaryTabs.length + slot.index),
      ),
    );

    if (itemT >= 1) return item;
    return Opacity(opacity: itemT, child: item);
  }

  Widget _buildOverflowRow({
    required List<({int index, AppShellTab tab})?> slots,
    required double expandProgress,
    required bool isDark,
    required bool showSyncBadge,
    required int dueCount,
    required int chatUnreadCount,
    required int boardsBadge,
    required bool showLabels,
    required double labelVisibility,
  }) {
    final populatedSlots = slots
        .whereType<({int index, AppShellTab tab})>()
        .toList();
    if (populatedSlots.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final slotColumns = widget.overflowRows > 1
            ? widget.overflowColumns
            : populatedSlots.length;
        final slotWidth = slotColumns <= 0
            ? 0.0
            : constraints.maxWidth / slotColumns;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final slot in populatedSlots)
              SizedBox(
                width: slotWidth,
                child: _buildOverflowSlot(
                  slot: slot,
                  expandProgress: expandProgress,
                  isDark: isDark,
                  showSyncBadge: showSyncBadge,
                  dueCount: dueCount,
                  chatUnreadCount: chatUnreadCount,
                  boardsBadge: boardsBadge,
                  showLabels: showLabels,
                  labelVisibility: labelVisibility,
                ),
              ),
          ],
        );
      },
    );
  }

  int get _primaryTabIndex {
    if (widget.currentIndex >= widget.primaryTabs.length) return -1;
    return widget.currentIndex;
  }

  int get _overflowTabIndex {
    final offset = widget.primaryTabs.length;
    if (widget.currentIndex < offset) return -1;
    return widget.currentIndex - offset;
  }

  BoxDecoration _barDecoration(
    bool isDark,
    bool isOled,
    double radius,
    PrismShapes shapes,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final look = LookTheme.of(context);
    final navStyle = look?.style(LookElement.nav);
    final navFill = look?.fill(LookElement.nav);
    final baseColor =
        navFill ??
        (isDark
            ? colors.surfaceContainerHigh.withValues(
                alpha: look?.reduceTransparency ?? false ? 1 : 0.50,
              )
            : colors.surfaceContainer.withValues(
                alpha: look?.reduceTransparency ?? false ? 1 : 0.54,
              ));
    if (navFill != null) {
      return BoxDecoration(
        color: look!.gradient(LookElement.nav) == null ? navFill : null,
        gradient: look.gradient(LookElement.nav),
        borderRadius: BorderRadius.circular(
          navStyle?.radius ?? shapes.radius(radius),
        ),
        border:
            look.border(LookElement.nav) ??
            Border.all(
              width: _kNavBarBorderWidth,
              color: colors.outlineVariant.withValues(
                alpha: isDark ? 0.42 : 0.56,
              ),
            ),
        boxShadow:
            look.shadow(LookElement.nav) ??
            [
              BoxShadow(
                color: colors.shadow.withValues(alpha: isDark ? 0.34 : 0.10),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
      );
    }

    return BoxDecoration(
      color: Color.alphaBlend(
        widget.accentColor.withValues(alpha: 0.06),
        baseColor,
      ),
      borderRadius: BorderRadius.circular(shapes.radius(radius)),
      border: Border.all(
        width: _kNavBarBorderWidth,
        color: colors.outlineVariant.withValues(alpha: isDark ? 0.42 : 0.56),
      ),
      boxShadow: [
        BoxShadow(
          color: colors.shadow.withValues(alpha: isDark ? 0.34 : 0.10),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// Simple bar for <=5 tabs — no More trigger.
  Widget _buildSimpleBar({
    required bool showSyncBadge,
    required int dueCount,
    required int chatUnreadCount,
    required int boardsBadge,
    required bool isDark,
    required bool showLabels,
  }) {
    final isOled = Theme.of(context).scaffoldBackgroundColor == Colors.black;
    final tabCount = widget.primaryTabs.length;
    final shapes = PrismShapes.of(context);
    final prominentIcons =
        widget.labelVisibility != NavBarLabelVisibility.always;

    // Pill colors
    final pillColor = _navSelectedPillColor(Theme.of(context));

    return Semantics(
      container: true,
      label: context.l10n.navigationBar,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(shapes.radius(_collapsedRadius)),
        child: _NavGlass(
          liveBlur: true,
          child: Container(
            height: widget.rowHeight,
            decoration: _barDecoration(
              isDark,
              isOled,
              _collapsedRadius,
              shapes,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final segmentWidth = constraints.maxWidth / tabCount;
                  final simpleLabelVisibility = showLabels ? 1.0 : 0.0;
                  final pillHeight = navBarPrimaryPillLayoutHeight(
                    prominentIcons: prominentIcons,
                  );
                  final pillTop = navBarPrimaryPillLayoutTop(
                    rowHeight: widget.rowHeight,
                    prominentIcons: prominentIcons,
                  );
                  final pillPaintOffsetY = navBarPrimaryPillPaintOffsetY(
                    rowHeight: widget.rowHeight,
                    prominentIcons: prominentIcons,
                    labelVisibility: simpleLabelVisibility,
                  );
                  final pillScaleY = navBarPrimaryPillScaleY(
                    prominentIcons: prominentIcons,
                    labelVisibility: simpleLabelVisibility,
                  );
                  final pillWidth = prominentIcons
                      ? math.min(
                          segmentWidth - 8,
                          kNavBarIconOnlySelectedItemPillWidth,
                        )
                      : segmentWidth - 16;
                  final contentOffsetX = navBarPrimaryContentOffsetX(
                    segmentWidth: segmentWidth,
                    prominentIcons: prominentIcons,
                    pillWidth: pillWidth,
                  );
                  return Stack(
                    children: [
                      // Sliding pill — uses Transform.translate (paint-only,
                      // no layout pass) for smooth 60fps on low-end devices.
                      AnimatedBuilder(
                        animation: _pillController,
                        builder: (context, child) {
                          final isRtl =
                              Directionality.of(context) == TextDirection.rtl;
                          final slot = isRtl
                              ? (tabCount - 1 - _pillController.value)
                              : _pillController.value;
                          return Transform.translate(
                            offset: Offset(
                              slot * segmentWidth +
                                  _kNavBarPrimaryPillHorizontalInset,
                              0,
                            ),
                            child: child,
                          );
                        },
                        child: Padding(
                          padding: EdgeInsets.only(top: pillTop),
                          child: Transform.translate(
                            offset: Offset(0, pillPaintOffsetY),
                            child: Transform.scale(
                              key: const ValueKey(
                                'nav_selected_pill_transform',
                              ),
                              scaleY: pillScaleY,
                              child: DecoratedBox(
                                key: const ValueKey('nav_selected_pill'),
                                decoration: BoxDecoration(
                                  color: pillColor,
                                  borderRadius: BorderRadius.circular(
                                    shapes.radius(16),
                                  ),
                                ),
                                child: SizedBox(
                                  width: pillWidth,
                                  height: pillHeight,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Tab items — force the row to fill the nav bar
                      // height so each item's content vertically centers the
                      // same way it does in overflow mode (where the tall
                      // _MoreTrigger sibling forces the row to full height).
                      SizedBox(
                        height: widget.rowHeight,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(tabCount, (index) {
                            final tab = widget.primaryTabs[index];
                            final isSelected = index == widget.currentIndex;
                            return Expanded(
                              child: _NavBarItem(
                                tab: tab,
                                label: widget.primaryLabels[index],
                                isSelected: isSelected,
                                accentColor: widget.accentColor,
                                isDark: isDark,
                                showSyncBadge: showSyncBadge,
                                habitsDueCount: dueCount,
                                chatUnreadCount: chatUnreadCount,
                                boardsBadge: boardsBadge,
                                rowHeight: widget.rowHeight,
                                showLabel: showLabels,
                                labelVisibility: simpleLabelVisibility,
                                prominentIcon: prominentIcons,
                                horizontalContentOffset: contentOffsetX,
                                onTap: () => widget.onTap(index),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact vertical-dots trigger that rotates to an X when expanded.
class _MoreTrigger extends StatelessWidget {
  const _MoreTrigger({
    required this.isExpanded,
    required this.isHighlighted,
    required this.animationValue,
    required this.accentColor,
    required this.isDark,
    required this.rowHeight,
    required this.prominentIcon,
    required this.onTap,
  });

  final bool isExpanded;
  final bool isHighlighted;
  final double animationValue;
  final Color accentColor;
  final bool isDark;
  final double rowHeight;
  final bool prominentIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = isHighlighted
        ? accentColor
        : _navInactiveIconColor(Theme.of(context));

    return Semantics(
      button: true,
      expanded: isExpanded,
      label: isExpanded ? context.l10n.closeMenu : context.l10n.moreTabs,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: _kMoreButtonWidth,
          height: rowHeight,
          child: Center(
            child: Transform.rotate(
              angle: animationValue * 0.785, // 45 degrees
              child: Icon(
                AppIcons.moreVert,
                size: prominentIcon
                    ? kNavBarIconOnlyMoreTriggerIconSize
                    : kNavBarMoreTriggerIconSize,
                color: iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Individual nav bar item.
/// The nav bar's glass. Uses a live backdrop blur only when it is cheap
/// (small and still); otherwise — expanded/animating on Android, or with
/// reduced motion / high contrast — a near-opaque backing instead.
class _NavGlass extends StatelessWidget {
  const _NavGlass({required this.liveBlur, required this.child});

  final bool liveBlur;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final reduced = mq.disableAnimations || mq.highContrast;
    final blur = !reduced && (liveBlur || !android);
    if (blur) {
      return BackdropFilter.grouped(
        filter: ImageFilter.blur(sigmaX: PrismTokens.glassBlurStrong, sigmaY: PrismTokens.glassBlurStrong),
        child: child,
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: scheme.surface.withValues(alpha: 0.9)),
      child: child,
    );
  }
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.tab,
    required this.label,
    required this.isSelected,
    required this.accentColor,
    required this.isDark,
    required this.showSyncBadge,
    required this.habitsDueCount,
    required this.chatUnreadCount,
    required this.boardsBadge,
    required this.rowHeight,
    required this.showLabel,
    required this.labelVisibility,
    required this.prominentIcon,
    this.horizontalContentOffset = 0.0,
    required this.onTap,
    this.showItemPill = false,
  });

  final AppShellTab tab;
  final String label;
  final bool isSelected;
  final Color accentColor;
  final bool isDark;
  final bool showSyncBadge;
  final int habitsDueCount;
  final int chatUnreadCount;
  final int boardsBadge;
  final double rowHeight;
  final bool showLabel;
  final double labelVisibility;
  final bool prominentIcon;
  final double horizontalContentOffset;
  final VoidCallback onTap;

  /// When true, render a per-item pill behind the icon (for overflow row).
  final bool showItemPill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemIcon = isSelected ? tab.activeIcon : tab.icon;
    final visibleLabelFactor = showLabel
        ? labelVisibility.clamp(0.0, 1.0).toDouble()
        : 0.0;
    final iconSize = prominentIcon
        ? kNavBarIconOnlyItemIconSize
        : kNavBarItemIconSize;
    final iconHeight = prominentIcon
        ? kNavBarIconOnlyItemIconHeight
        : kNavBarItemIconHeight;
    final selectedPillWidth = prominentIcon
        ? kNavBarIconOnlySelectedItemPillWidth
        : kNavBarSelectedItemPillWidth;
    final restingIconWidth = prominentIcon
        ? kNavBarIconOnlyItemIconHeight
        : kNavBarItemWidth;
    final iconLift = navBarLabelRevealLiftY(
      labelVisibility: visibleLabelFactor,
    );
    final labelOffsetY =
        (iconHeight / 2) + (_kNavBarLabelRevealSlotHeight / 2) - iconLift;

    Widget iconWidget = Icon(
      itemIcon,
      size: iconSize,
      color: isSelected ? accentColor : _navInactiveIconColor(theme),
    );

    iconWidget = _maybeBadge(
      tab: tab,
      showSyncBadge: showSyncBadge,
      habitsDueCount: habitsDueCount,
      chatUnreadCount: chatUnreadCount,
      boardsBadge: boardsBadge,
      child: iconWidget,
    );

    final iconOpticalOffsetY = navBarIconOpticalOffsetY(
      prominentIcons: prominentIcon,
    );
    if (iconOpticalOffsetY != 0) {
      iconWidget = Transform.translate(
        key: ValueKey('nav_icon_visual_${tab.id.name}'),
        offset: Offset(0, iconOpticalOffsetY),
        child: iconWidget,
      );
    } else {
      iconWidget = KeyedSubtree(
        key: ValueKey('nav_icon_visual_${tab.id.name}'),
        child: iconWidget,
      );
    }

    final semanticLabel = tab.id == AppShellTabId.chat && chatUnreadCount > 0
        ? context.l10n.navUnreadCount(label, chatUnreadCount)
        : label;
    final labelWidget = visibleLabelFactor <= 0
        ? const SizedBox.shrink()
        : Transform.translate(
            offset: Offset(0, labelOffsetY),
            child: _NavBarLabel(
              key: ValueKey('nav_label_${tab.id.name}'),
              label: label,
              style: navBarLabelTextStyle(
                context,
                isSelected: isSelected,
                color: isSelected
                    ? theme.colorScheme.onSurface
                    : _navInactiveLabelColor(theme),
              ),
              opacity: visibleLabelFactor,
            ),
          );

    return Semantics(
      selected: isSelected,
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: rowHeight,
          child: Transform.translate(
            offset: Offset(horizontalContentOffset, 0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.translate(
                  offset: Offset(0, -iconLift),
                  child: SizedBox(
                    height: iconHeight,
                    child: Container(
                      key: ValueKey('nav_icon_slot_${tab.id.name}'),
                      width: showItemPill && isSelected
                          ? selectedPillWidth
                          : restingIconWidth,
                      alignment: Alignment.center,
                      decoration: showItemPill
                          ? BoxDecoration(
                              color: isSelected
                                  ? _navSelectedPillColor(theme)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(
                                PrismShapes.of(context).radius(16),
                              ),
                            )
                          : null,
                      child: iconWidget,
                    ),
                  ),
                ),
                labelWidget,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarLabel extends StatelessWidget {
  const _NavBarLabel({
    super.key,
    required this.label,
    required this.style,
    required this.opacity,
  });

  final String label;
  final TextStyle style;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      style: style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
    );
    if (opacity >= 1) return text;
    return Opacity(opacity: opacity, child: text);
  }
}

/// Desktop sidebar navigation.
class _FloatingSidebar extends ConsumerWidget {
  const _FloatingSidebar({
    required this.tabs,
    required this.currentIndex,
    required this.onTap,
    required this.accentColor,
  });

  final List<AppShellTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color accentColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncStatusProvider);
    final showSyncBadge =
        syncStatus.hasQuarantinedItems || syncStatus.lastError != null;
    final habitsBadgeEnabled = ref.watch(habitsBadgeEnabledProvider);
    final dueCount = habitsBadgeEnabled ? ref.watch(dueHabitsCountProvider) : 0;
    final chatUnreadCount = ref.watch(unreadConversationCountProvider);
    final boardsBadge = ref.watch(boardsTabBadgeProvider);
    final terms = watchTerminology(context, ref);

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isOled = theme.scaffoldBackgroundColor == Colors.black;

    return Semantics(
      container: true,
      label: context.l10n.mainNavigation,
      child: SafeArea(
        right: false,
        bottom: false,
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 12, top: 12, bottom: 12),
            child: Container(
              width: _kSidebarWidth,
              height: double.infinity,
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  accentColor.withValues(alpha: isDark ? 0.08 : 0.06),
                  (isDark
                          ? (isOled
                                ? colors.surfaceContainerLow
                                : colors.surfaceContainer)
                          : colors.surfaceContainer)
                      .withValues(alpha: isDark ? 0.72 : 0.78),
                ),
                borderRadius: BorderRadius.circular(
                  PrismShapes.of(context).radius(16),
                ),
                border: Border.all(
                  color: colors.outlineVariant.withValues(
                    alpha: isDark ? 0.42 : 0.56,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withValues(
                      alpha: isDark ? 0.26 : 0.08,
                    ),
                    blurRadius: 12,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 8,
                  children: List.generate(tabs.length, (index) {
                    final tab = tabs[index];
                    final isSelected = index == currentIndex;

                    return _SidebarItem(
                      tab: tab,
                      terminologyPlural: terms.plural,
                      isSelected: isSelected,
                      accentColor: accentColor,
                      isDark: isDark,
                      showSyncBadge: showSyncBadge,
                      habitsDueCount: dueCount,
                      chatUnreadCount: chatUnreadCount,
                      boardsBadge: boardsBadge,
                      onTap: () => onTap(index),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single sidebar navigation item with hover support.
class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.tab,
    required this.terminologyPlural,
    required this.isSelected,
    required this.accentColor,
    required this.isDark,
    required this.showSyncBadge,
    required this.habitsDueCount,
    required this.chatUnreadCount,
    required this.boardsBadge,
    required this.onTap,
    this.compact = false,
  });

  /// Icon only (collapsed web sidebar).
  final bool compact;
  final AppShellTab tab;
  final String terminologyPlural;
  final bool isSelected;
  final Color accentColor;
  final bool isDark;
  final bool showSyncBadge;
  final int habitsDueCount;
  final int chatUnreadCount;
  final int boardsBadge;
  final VoidCallback onTap;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fillColor = widget.isSelected
        ? _sidebarSelectedFillColor(theme)
        : _hovering
        ? theme.colorScheme.surfaceContainerHigh.withValues(
            alpha: widget.isDark ? 0.62 : 0.72,
          )
        : Colors.transparent;

    final iconColor = widget.isSelected
        ? widget.accentColor
        : _navInactiveIconColor(theme);

    final labelColor = widget.isSelected
        ? theme.colorScheme.onSurface
        : _navInactiveLabelColor(theme, darkAlpha: 0.6);

    return Semantics(
      selected: widget.isSelected,
      button: true,
      label: widget.tab.localizedLabel(
        context,
        terminologyPlural: widget.terminologyPlural,
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          // Plain Container, not AnimatedContainer: tweening the fill from
          // Colors.transparent (a transparent black) flashed a dark tint
          // mid-fade and lagged the highlight onto adjacent rows on hover.
          child: Container(
            height: _kSidebarItemHeight,
            padding: EdgeInsets.symmetric(horizontal: widget.compact ? 0 : 12),
            alignment: widget.compact ? Alignment.center : null,
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(
                PrismShapes.of(context).radius(10),
              ),
            ),
            child: Row(
              mainAxisAlignment: widget.compact ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                _maybeBadge(
                  tab: widget.tab,
                  showSyncBadge: widget.showSyncBadge,
                  habitsDueCount: widget.habitsDueCount,
                  chatUnreadCount: widget.chatUnreadCount,
                  boardsBadge: widget.boardsBadge,
                  child: Icon(
                    widget.isSelected ? widget.tab.activeIcon : widget.tab.icon,
                    size: 20,
                    color: iconColor,
                  ),
                ),
                if (!widget.compact) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.tab.localizedLabel(
                        context,
                        terminologyPlural: widget.terminologyPlural,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: widget.isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: labelColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// ───────────────────────── Web desktop layout ─────────────────────────

/// Web windows at least this wide use the website layout.
const kWebDesktopMinWidth = 1024.0;
const kWebSidebarWidth = 264.0;
const kWebSidebarCollapsedWidth = 76.0;

String _categoryLabel(BuildContext context, FeatureCategory c) => switch (c) {
  FeatureCategory.system => context.l10n.localeName.startsWith('es') ? 'Sistema' : 'System',
  FeatureCategory.tracking => context.l10n.localeName.startsWith('es') ? 'Seguimiento' : 'Tracking',
  FeatureCategory.organization => context.l10n.localeName.startsWith('es') ? 'Organización' : 'Organize',
  FeatureCategory.social => context.l10n.localeName.startsWith('es') ? 'Social' : 'Social',
  FeatureCategory.knowledge => context.l10n.localeName.startsWith('es') ? 'Conocimiento' : 'Knowledge',
  FeatureCategory.community => context.l10n.localeName.startsWith('es') ? 'Comunidad' : 'Community',
  FeatureCategory.analytics => context.l10n.localeName.startsWith('es') ? 'Estadísticas' : 'Insights',
};

/// Website frame for wide web windows: a docked, sectioned sidebar and a
/// content area, plus Ctrl/⌘+K to jump anywhere.
class _WebDesktopFrame extends ConsumerStatefulWidget {
  const _WebDesktopFrame({
    required this.tabs,
    required this.currentIndex,
    required this.accentColor,
    required this.collapsed,
    required this.onToggleCollapsed,
    required this.onTap,
    required this.child,
  });

  final List<AppShellTab> tabs;
  final int currentIndex;
  final Color accentColor;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;
  final ValueChanged<int> onTap;
  final Widget child;

  @override
  ConsumerState<_WebDesktopFrame> createState() => _WebDesktopFrameState();
}

class _WebDesktopFrameState extends ConsumerState<_WebDesktopFrame> {
  bool _paletteOpen = false;

  @override
  void initState() {
    super.initState();
    // Listen to the keyboard directly so Ctrl/⌘+K works wherever focus is
    // (or when nothing is focused, e.g. after clicking empty space).
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent) return false;
    final k = HardwareKeyboard.instance;
    final mod = k.isControlPressed || k.isMetaPressed;
    if (mod && e.logicalKey == LogicalKeyboardKey.keyK) {
      _palette();
      return true;
    }
    if (k.isControlPressed && e.logicalKey == LogicalKeyboardKey.backslash) {
      widget.onToggleCollapsed();
      return true;
    }
    return false;
  }

  Future<void> _palette() async {
    if (_paletteOpen || !mounted) return;
    _paletteOpen = true;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => _CommandPalette(tabs: widget.tabs, onTap: widget.onTap, onRoute: (r) => GoRouter.of(context).go(r)),
    );
    _paletteOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WebSidebar(
            tabs: widget.tabs,
            currentIndex: widget.currentIndex,
            accentColor: widget.accentColor,
            collapsed: widget.collapsed,
            onToggleCollapsed: widget.onToggleCollapsed,
            onSearch: _palette,
            onTap: widget.onTap,
          ),
          VerticalDivider(width: 1, thickness: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}

class _WebSidebar extends ConsumerWidget {
  const _WebSidebar({
    required this.tabs,
    required this.currentIndex,
    required this.accentColor,
    required this.collapsed,
    required this.onToggleCollapsed,
    required this.onSearch,
    required this.onTap,
  });

  final List<AppShellTab> tabs;
  final int currentIndex;
  final Color accentColor;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;
  final VoidCallback onSearch;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final syncStatus = ref.watch(syncStatusProvider);
    final showSyncBadge = syncStatus.hasQuarantinedItems || syncStatus.lastError != null;
    final habitsBadgeEnabled = ref.watch(habitsBadgeEnabledProvider);
    final dueCount = habitsBadgeEnabled ? ref.watch(dueHabitsCountProvider) : 0;
    final chatUnreadCount = ref.watch(unreadConversationCountProvider);
    final boardsBadge = ref.watch(boardsTabBadgeProvider);
    final terms = watchTerminology(context, ref);
    final systemName = ref.watch(systemNameProvider);
    final es = context.l10n.localeName.startsWith('es');

    Widget item(int i) => Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Tooltip(
        message: collapsed ? tabs[i].localizedLabel(context, terminologyPlural: terms.plural) : '',
        waitDuration: const Duration(milliseconds: 400),
        child: _SidebarItem(
          tab: tabs[i],
          terminologyPlural: terms.plural,
          isSelected: i == currentIndex,
          accentColor: accentColor,
          isDark: isDark,
          showSyncBadge: showSyncBadge,
          habitsDueCount: dueCount,
          chatUnreadCount: chatUnreadCount,
          boardsBadge: boardsBadge,
          compact: collapsed,
          onTap: () => onTap(i),
        ),
      ),
    );

    // Home first, Settings last, everything else grouped by category in the
    // person's own order.
    final home = <int>[], settings = <int>[];
    final groups = <FeatureCategory?, List<int>>{};
    for (var i = 0; i < tabs.length; i++) {
      final id = tabs[i].id;
      if (id == AppShellTabId.home) {
        home.add(i);
      } else if (id == AppShellTabId.settings) {
        settings.add(i);
      } else {
        (groups[featureByTab[id]?.category] ??= []).add(i);
      }
    }
    final order = [...FeatureCategory.values, null];

    Widget header(String label) => collapsed
        ? Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: colors.outlineVariant.withValues(alpha: 0.5)))
        : Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
            child: Text(label.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.8, fontWeight: FontWeight.w700, color: colors.onSurfaceVariant.withValues(alpha: 0.75))),
          );

    final width = collapsed ? kWebSidebarCollapsedWidth : kWebSidebarWidth;
    return Semantics(
      container: true,
      label: context.l10n.mainNavigation,
      child: Container(
        width: width,
        color: Color.alphaBlend(accentColor.withValues(alpha: isDark ? 0.05 : 0.035), isDark ? colors.surfaceContainerLow : colors.surfaceContainer),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Brand + system.
            Padding(
              padding: EdgeInsets.fromLTRB(collapsed ? 0 : 18, 18, collapsed ? 0 : 10, 10),
              child: Row(
                mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  // The app icon chosen in Settings › Appearance.
                  if (ref.watch(appIconProvider).value == 'custom' && ref.watch(customAppIconProvider).value != null)
                    ClipRRect(borderRadius: prismCorners(context, 9), child: Image.memory(ref.watch(customAppIconProvider).value!, width: 34, height: 34, filterQuality: FilterQuality.medium))
                  else
                    Image.asset('assets/app_icons/${ref.watch(appIconProvider).value ?? 'classic'}.png', width: 34, height: 34, filterQuality: FilterQuality.medium, errorBuilder: (_, _, _) => Image.asset('assets/app_icons/classic.png', width: 34, height: 34)),
                  if (!collapsed) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Prism', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.1)),
                          if ((systemName ?? '').isNotEmpty) Text(systemName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelMedium?.copyWith(color: colors.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Search / jump (Ctrl+K).
            Padding(
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 14 : 12, vertical: 6),
              child: _WebSearchButton(collapsed: collapsed, onTap: onSearch, label: es ? 'Buscar…' : 'Search Prism…'),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: collapsed ? 12 : 10, vertical: 4),
                children: [
                  for (final i in home) item(i),
                  for (final c in order)
                    if (groups[c]?.isNotEmpty ?? false) ...[
                      header(c == null ? (es ? 'Más' : 'More') : _categoryLabel(context, c)),
                      for (final i in groups[c]!) item(i),
                    ],
                ],
              ),
            ),
            Divider(height: 1, color: colors.outlineVariant.withValues(alpha: 0.5)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 12 : 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final i in settings) item(i),
                  _WebCollapseButton(collapsed: collapsed, onTap: onToggleCollapsed, label: collapsed ? (es ? 'Expandir menú' : 'Expand sidebar') : (es ? 'Contraer menú' : 'Collapse sidebar')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WebSearchButton extends StatefulWidget {
  const _WebSearchButton({required this.collapsed, required this.onTap, required this.label});
  final bool collapsed;
  final VoidCallback onTap;
  final String label;
  @override
  State<_WebSearchButton> createState() => _WebSearchButtonState();
}

class _WebSearchButtonState extends State<_WebSearchButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isMac = defaultTargetPlatform == TargetPlatform.macOS;
    return Semantics(
      button: true,
      label: '${widget.label} (${isMac ? '⌘' : 'Ctrl'}+K)',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            height: 38,
            padding: EdgeInsets.symmetric(horizontal: widget.collapsed ? 0 : 12),
            decoration: BoxDecoration(
              color: _hover ? colors.surfaceContainerHighest : colors.surfaceContainerHigh.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(PrismShapes.of(context).radius(10)),
              border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.6)),
            ),
            child: widget.collapsed
                ? Icon(Icons.search_rounded, size: 18, color: colors.onSurfaceVariant)
                : Row(
                    children: [
                      Icon(Icons.search_rounded, size: 18, color: colors.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(child: Text(widget.label, style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(borderRadius: prismCorners(context, 6), border: Border.all(color: colors.outlineVariant)),
                        child: Text(isMac ? '⌘K' : 'Ctrl K', style: theme.textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant)),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _WebCollapseButton extends StatelessWidget {
  const _WebCollapseButton({required this.collapsed, required this.onTap, required this.label});
  final bool collapsed;
  final VoidCallback onTap;
  final String label;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: '$label (Ctrl+\\)',
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          borderRadius: prismCorners(context, 10),
          onTap: onTap,
          child: SizedBox(
            height: 36,
            child: Row(
              mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                if (!collapsed) const SizedBox(width: 12),
                Icon(collapsed ? Icons.keyboard_double_arrow_right_rounded : Icons.keyboard_double_arrow_left_rounded, size: 18, color: colors.onSurfaceVariant),
                if (!collapsed) ...[
                  const SizedBox(width: 10),
                  Text(label, style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ctrl/⌘+K: type to jump to any section.
class _CommandPalette extends ConsumerStatefulWidget {
  const _CommandPalette({required this.tabs, required this.onTap, required this.onRoute});
  final List<AppShellTab> tabs;
  final ValueChanged<int> onTap;
  final ValueChanged<String> onRoute;
  @override
  ConsumerState<_CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<_CommandPalette> {
  final _q = TextEditingController();
  int _sel = 0;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final terms = watchTerminology(context, ref);
    final q = _q.text.trim().toLowerCase();
    final es = context.l10n.localeName.startsWith('es');
    final states = ref.watch(featureStatesProvider);
    final shownTabs = {for (final t in widget.tabs) t.id};
    // Sidebar sections first, then every other enabled feature.
    final entries = <({String label, IconData icon, String? group, VoidCallback open})>[
      for (var i = 0; i < widget.tabs.length; i++)
        (
          label: widget.tabs[i].localizedLabel(context, terminologyPlural: terms.plural),
          icon: widget.tabs[i].icon,
          group: featureByTab[widget.tabs[i].id] == null ? null : _categoryLabel(context, featureByTab[widget.tabs[i].id]!.category),
          open: () => widget.onTap(i),
        ),
      for (final f in prismFeatures)
        if (f.route != null && (states[f.id] ?? true) && !f.tabs.any(shownTabs.contains))
          (label: es ? f.name.$2 : f.name.$1, icon: f.icon, group: _categoryLabel(context, f.category), open: () => widget.onRoute(f.route!)),
    ];
    // Also match each section's full feature name ("Prism Social" → Social).
    String alias(int i) {
      if (i >= widget.tabs.length) return '';
      final f = featureByTab[widget.tabs[i].id];
      return f == null ? '' : '${f.name.$1} ${f.name.$2}'.toLowerCase();
    }

    final results = [
      for (var i = 0; i < entries.length; i++)
        if (q.isEmpty || entries[i].label.toLowerCase().contains(q) || alias(i).contains(q)) i,
    ];
    if (_sel >= results.length) _sel = results.isEmpty ? 0 : results.length - 1;
    void go(int i) {
      Navigator.of(context).pop();
      entries[i].open();
    }

    return Align(
      alignment: const Alignment(0, -0.45),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 460),
        child: Material(
          color: colors.surfaceContainer,
          elevation: 12,
          borderRadius: BorderRadius.circular(PrismShapes.of(context).radius(16)),
          clipBehavior: Clip.antiAlias,
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.arrowDown): () => setState(() => _sel = (_sel + 1).clamp(0, results.isEmpty ? 0 : results.length - 1)),
              const SingleActivator(LogicalKeyboardKey.arrowUp): () => setState(() => _sel = (_sel - 1).clamp(0, results.isEmpty ? 0 : results.length - 1)),
              const SingleActivator(LogicalKeyboardKey.enter): () {
                if (results.isNotEmpty) go(results[_sel]);
              },
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, color: colors.onSurfaceVariant),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _q,
                          autofocus: true,
                          onChanged: (_) => setState(() => _sel = 0),
                          onSubmitted: (_) {
                            if (results.isNotEmpty) go(results[_sel]);
                          },
                          style: theme.textTheme.titleMedium,
                          decoration: InputDecoration(
                            hintText: context.l10n.localeName.startsWith('es') ? 'Ir a…' : 'Go to…',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      Text('Esc', style: theme.textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant)),
                    ],
                  ),
                ),
                Divider(height: 1, color: colors.outlineVariant),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(8),
                    children: [
                      for (final (n, i) in results.indexed)
                        Material(
                          color: n == _sel ? colors.secondaryContainer : Colors.transparent,
                          borderRadius: prismCorners(context, 10),
                          child: InkWell(
                            borderRadius: prismCorners(context, 10),
                            onTap: () => go(i),
                            onHover: (h) {
                              if (h) setState(() => _sel = n);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  Icon(entries[i].icon, size: 20, color: n == _sel ? colors.onSecondaryContainer : colors.onSurfaceVariant),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(entries[i].label, style: theme.textTheme.bodyLarge)),
                                  if (entries[i].group case final g?) Text(g, style: theme.textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (results.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(context.l10n.localeName.startsWith('es') ? 'Sin resultados' : 'No matches', style: theme.textTheme.bodyMedium)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


/// Animates switching between main sections (nav bar, sidebar, search or a
/// link into another section): the new section fades in and rises slightly.
/// The shell keeps every section alive in an IndexedStack, so this animates
/// the visible one in rather than cross-fading two pages.
class BranchTransition extends StatefulWidget {
  const BranchTransition({super.key, required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<BranchTransition> createState() => _BranchTransitionState();
}

class _BranchTransitionState extends State<BranchTransition> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 260), value: 1);
  late final Animation<double> _curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  late final Animation<Offset> _slide = Tween(begin: const Offset(0, 0.018), end: Offset.zero).animate(_curve);

  @override
  void didUpdateWidget(BranchTransition old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index && !MediaQuery.of(context).disableAnimations) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _curve,
    child: SlideTransition(position: _slide, child: widget.child),
  );
}
