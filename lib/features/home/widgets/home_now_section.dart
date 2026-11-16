import 'package:prism_plurality/core/features/feature_state.dart';
import 'package:prism_plurality/features/health/health_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/features/locations/providers/location_providers.dart';
import 'package:prism_plurality/features/locations/views/location_editor_sheet.dart';
import 'package:prism_plurality/features/locations/views/locations_screen.dart';
import 'package:prism_plurality/features/mood/views/log_mood_sheet.dart';
import 'package:prism_plurality/features/work/providers/work_providers.dart';
import 'package:prism_plurality/features/work/utils/money.dart';
import 'package:prism_plurality/features/work/views/job_editor_sheet.dart';
import 'package:prism_plurality/features/work/views/work_screen.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_list_row.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';

/// "Now" on the home screen: the open location and work sessions with live
/// timers, plus quick actions to log a mood, start a location session,
/// clock in, or open Daily Insights.
class HomeNowSection extends ConsumerWidget {
  const HomeNowSection({super.key, this.showQuickChips = true});

  /// The dashboard shows quick actions separately, so it hides these.
  final bool showQuickChips;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final activeLocation = ref.watch(activeLocationSessionProvider);
    final locations = ref.watch(savedLocationsProvider).value ?? const [];
    final activeWork = ref.watch(activeWorkSessionsProvider);
    final jobs = ref.watch(jobByIdProvider);
    final location = activeLocation == null
        ? null
        : locations.where((l) => l.id == activeLocation.locationId).firstOrNull;

    if (!showQuickChips && activeLocation == null && activeWork.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: showQuickChips
          ? const EdgeInsets.fromLTRB(16, 8, 16, 4)
          : EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (activeLocation != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ActiveLocationCard(
                session: activeLocation,
                location: location,
                compact: true,
              ),
            ),
          for (final s in activeWork)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ActiveWorkCard(
                session: s,
                job: jobs[s.jobId],
                compact: true,
              ),
            ),
          if (showQuickChips)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _QuickChip(
                    icon: AppIcons.navMood,
                    label: l10n.homeQuickLogMood,
                    onTap: () => showLogMoodSheet(context),
                  ),
                  if (ref.watch(featureEnabledProvider('health')))
                    _QuickChip(
                      icon: Icons.health_and_safety_outlined,
                      label: 'Log health',
                      onTap: () => showHealthLog(context),
                    ),
                  _QuickChip(
                    icon: AppIcons.navLocations,
                    label: activeLocation == null
                        ? l10n.homeQuickStartLocation
                        : l10n.homeQuickChangeLocation,
                    onTap: () => pickLocation(context, ref),
                  ),
                  _QuickChip(
                    icon: AppIcons.navWork,
                    label: l10n.workClockIn,
                    onTap: () => pickJob(context, ref),
                  ),
                  _QuickChip(
                    icon: AppIcons.navInsights,
                    label: l10n.insightsTitle,
                    onTap: () => context.go(AppRoutePaths.insights),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static Future<void> pickLocation(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return PrismSheet.show(
      context: context,
      title: l10n.homeQuickStartLocation,
      builder: (sheetContext) => Consumer(
        builder: (sheetContext, ref, _) {
          final list = ref.watch(sortedSavedLocationsProvider);
          final active = ref.watch(activeLocationSessionProvider);
          return Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final loc in list)
                  PrismListRow(
                    leading: Text(
                      loc.emoji ?? '📍',
                      style: const TextStyle(fontSize: 22),
                    ),
                    title: Text(loc.name),
                    trailing: active?.locationId == loc.id
                        ? Text(l10n.locationsHereNow)
                        : null,
                    onTap: () {
                      ref
                          .read(locationsNotifierProvider.notifier)
                          .startSession(loc.id);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                if (active != null)
                  PrismListRow(
                    leading: Icon(AppIcons.close),
                    title: Text(l10n.locationsStop),
                    onTap: () {
                      ref
                          .read(locationsNotifierProvider.notifier)
                          .stopSession();
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                PrismListRow(
                  leading: Icon(AppIcons.add),
                  title: Text(l10n.locationsNewTitle),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    showLocationEditor(context);
                  },
                ),
                PrismListRow(
                  leading: Icon(AppIcons.navLocations),
                  title: Text(l10n.homeQuickManageLocations),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.go(AppRoutePaths.locations);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static Future<void> pickJob(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return PrismSheet.show(
      context: context,
      title: l10n.workClockIn,
      builder: (sheetContext) => Consumer(
        builder: (sheetContext, ref, _) {
          final jobs = (ref.watch(jobsProvider).value ?? const [])
              .where((j) => !j.isArchived)
              .toList();
          final active = ref.watch(activeWorkSessionsProvider);
          return Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final job in jobs)
                  PrismListRow(
                    leading: Icon(AppIcons.navWork),
                    title: Text(job.name),
                    subtitle: Text(
                      l10n.workRatePerHour(
                        formatMoneyCents(job.hourlyRateCents, job.currencyCode),
                      ),
                    ),
                    trailing: active.any((s) => s.jobId == job.id)
                        ? Text(l10n.workClockedIn)
                        : null,
                    onTap: () {
                      ref.read(workNotifierProvider.notifier).clockIn(job);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                PrismListRow(
                  leading: Icon(AppIcons.add),
                  title: Text(l10n.workNewJob),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    showJobEditor(context);
                  },
                ),
                PrismListRow(
                  leading: Icon(AppIcons.navWork),
                  title: Text(l10n.homeQuickManageWork),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.go(AppRoutePaths.work);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PrismChip(
        label: label,
        selected: false,
        avatar: Icon(icon, size: 16),
        onTap: onTap,
      ),
    );
  }
}
