import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/domain/models/location.dart';
import 'package:prism_plurality/features/calendar/widgets/calendar_colors.dart';
import 'package:prism_plurality/features/locations/providers/location_providers.dart';
import 'package:prism_plurality/features/locations/views/location_editor_sheet.dart';
import 'package:prism_plurality/features/locations/views/location_session_sheet.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/extensions/duration_extensions.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/app_shell.dart';
import 'package:prism_plurality/shared/widgets/clamped_body.dart';
import 'package:prism_plurality/shared/widgets/empty_state.dart';
import 'package:prism_plurality/shared/widgets/live_ticker.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_loading_state.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar_action.dart';

/// Saved places, the current location session, and visit history.
class LocationsScreen extends ConsumerWidget {
  const LocationsScreen({super.key, this.showBackButton = false});

  final bool showBackButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locationsAsync = ref.watch(savedLocationsProvider);
    final sessionsAsync = ref.watch(locationSessionsProvider);
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: l10n.locationsTitle,
        showBackButton: showBackButton,
        actions: [
          PrismTopBarAction(
            icon: AppIcons.add,
            tooltip: l10n.locationsNewTitle,
            onPressed: () => showLocationEditor(context),
          ),
        ],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: (locationsAsync.hasError || sessionsAsync.hasError)
          ? Center(
              child: Text(
                l10n.errorWithDetail(
                  locationsAsync.error ?? sessionsAsync.error!,
                ),
              ),
            )
          : (!locationsAsync.hasValue || !sessionsAsync.hasValue)
          ? const PrismLoadingState()
          : const ClampedBody(child: _LocationsBody()),
    );
  }
}

class _LocationsBody extends ConsumerWidget {
  const _LocationsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final locations = ref.watch(sortedSavedLocationsProvider);
    final all = ref.watch(savedLocationsProvider).value ?? const [];
    final sessions = ref.watch(locationSessionsProvider).value ?? const [];
    final active = ref.watch(activeLocationSessionProvider);
    final byId = {for (final l in all) l.id: l};

    if (locations.isEmpty && sessions.isEmpty) {
      return EmptyState(
        icon: Icon(AppIcons.navLocations),
        title: l10n.locationsEmptyTitle,
        subtitle: l10n.locationsEmptySubtitle,
        actionLabel: l10n.locationsNewTitle,
        onAction: () => showLocationEditor(context),
      );
    }

    final history = sessions.where((s) => !s.isActive).take(100).toList();
    final weekStart = DateTime.now().subtract(const Duration(days: 7));
    final weekTotals = <String, Duration>{};
    final now = DateTime.now();
    for (final s in sessions) {
      final end = s.endedAt ?? now;
      if (end.isBefore(weekStart)) continue;
      final start = s.startedAt.isBefore(weekStart) ? weekStart : s.startedAt;
      weekTotals[s.locationId] =
          (weekTotals[s.locationId] ?? Duration.zero) + end.difference(start);
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + NavBarInset.of(context)),
      children: [
        if (active != null)
          ActiveLocationCard(
            session: active,
            location: byId[active.locationId],
          ),
        const SizedBox(height: 16),
        Text(l10n.locationsSavedPlaces, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          l10n.locationsTapToStart,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        for (final loc in locations)
          _LocationTile(
            location: loc,
            isActive: active?.locationId == loc.id,
            weekTotal: weekTotals[loc.id],
          ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.locationsHistory,
                style: theme.textTheme.titleSmall,
              ),
            ),
            PrismButton(
              label: l10n.locationsAddPastVisit,
              icon: AppIcons.add,
              density: PrismControlDensity.compact,
              onPressed: () => showLocationSessionSheet(context),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (history.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              l10n.locationsNoHistory,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ..._groupedHistory(context, history, byId),
      ],
    );
  }

  List<Widget> _groupedHistory(
    BuildContext context,
    List<LocationSession> history,
    Map<String, SavedLocation> byId,
  ) {
    final theme = Theme.of(context);
    final fmt = DateFormat.yMMMEd(context.dateLocale);
    final groups = groupBy(
      history,
      (LocationSession s) =>
          DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day),
    );
    return [
      for (final g in groups.entries) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
          child: Text(fmt.format(g.key), style: theme.textTheme.labelLarge),
        ),
        for (final s in g.value)
          _SessionRow(session: s, location: byId[s.locationId]),
      ],
    ];
  }
}

/// The open location session with a live, to-the-second timer.
class ActiveLocationCard extends ConsumerWidget {
  const ActiveLocationCard({
    super.key,
    required this.session,
    required this.location,
    this.compact = false,
  });

  final LocationSession session;
  final SavedLocation? location;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final color =
        parseHexColor(location?.colorHex) ?? theme.colorScheme.primary;
    return PrismSurface(
      tone: PrismSurfaceTone.strong,
      padding: EdgeInsets.all(compact ? 12 : 16),
      onTap: () => showLocationSessionSheet(context, editing: session),
      child: Row(
        children: [
          Container(
            width: compact ? 36 : 44,
            height: compact ? 36 : 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              location?.emoji ?? '📍',
              style: TextStyle(fontSize: compact ? 18 : 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location == null
                      ? l10n.locationsDeletedPlace
                      : l10n.locationsAtPlace(location!.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                LiveTicker(
                  builder: (context, now) => Text(
                    '${session.durationAt(now).toClockString()} · '
                    '${l10n.locationsSince(context.formatTime(session.startedAt))}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
          PrismButton(
            label: l10n.locationsStop,
            density: PrismControlDensity.compact,
            onPressed: () =>
                ref.read(locationsNotifierProvider.notifier).stopSession(),
          ),
        ],
      ),
    );
  }
}

class _LocationTile extends ConsumerWidget {
  const _LocationTile({
    required this.location,
    required this.isActive,
    this.weekTotal,
  });

  final SavedLocation location;
  final bool isActive;
  final Duration? weekTotal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final color = parseHexColor(location.colorHex) ?? theme.colorScheme.primary;
    final details = [
      if (location.address != null) location.address!,
      if (weekTotal != null && weekTotal! > Duration.zero)
        l10n.locationsThisWeek(weekTotal!.toRoundedString()),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PrismSurface(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        borderColor: isActive ? color : null,
        onTap: isActive
            ? null
            : () => ref
                  .read(locationsNotifierProvider.notifier)
                  .startSession(location.id),
        semanticLabel: isActive
            ? l10n.locationsAtPlace(location.name)
            : l10n.locationsStartAt(location.name),
        child: Row(
          children: [
            Text(location.emoji ?? '📍', style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          location.name,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      if (location.isFavorite) ...[
                        const SizedBox(width: 4),
                        Icon(AppIcons.star, size: 14, color: Colors.amber),
                      ],
                    ],
                  ),
                  if (details.isNotEmpty)
                    Text(
                      details.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (isActive)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  l10n.locationsHereNow,
                  style: theme.textTheme.labelSmall?.copyWith(color: color),
                ),
              ),
            IconButton(
              tooltip: l10n.locationsEditTitle,
              icon: Icon(AppIcons.edit, size: 18),
              onPressed: () => showLocationEditor(context, editing: location),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.location});

  final LocationSession session;
  final SavedLocation? location;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final end = session.endedAt!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: PrismSurface(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onTap: () => showLocationSessionSheet(context, editing: session),
        child: Row(
          children: [
            Text(location?.emoji ?? '📍', style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    location?.name ?? context.l10n.locationsDeletedPlace,
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    '${context.formatTime(session.startedAt)} – '
                    '${context.formatTime(end)}'
                    '${session.note == null ? '' : ' · ${session.note}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              end.difference(session.startedAt).toExactString(),
              style: theme.textTheme.labelMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
