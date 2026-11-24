import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import 'package:prism_plurality/core/features/feature_state.dart'
    show featureEnabledProvider;
import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/features/fitness/health/health_sync.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Home: today's synced health numbers, with where and when they came from.
/// Only shown once a health connection is set up.
class HealthHomeCard extends ConsumerWidget {
  const HealthHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(healthSettingsProvider);
    if (!s.connected || !ref.watch(featureEnabledProvider('fitness')))
      return const SizedBox.shrink();
    final rows =
        ref.watch(trackerKindProvider(TrackerKind.fitnessDaily)).value ??
        const <TrackerRecord>[];
    final now = DateTime.now();
    final today = dayKey(now);
    final yesterday = dayKey(now.subtract(const Duration(days: 1)));
    TrackerRecord? pick(String key) => rows
        .where(
          (r) =>
              (r.str('dayKey') ??
                  (r.occurredAt == null ? null : dayKey(r.occurredAt!))) ==
              key,
        )
        .fold<TrackerRecord?>(
          null,
          (a, b) => a == null || b.modifiedAt.isAfter(a.modifiedAt) ? b : a,
        );
    final t = pick(today);
    final y = pick(yesterday);
    final steps = t?.integer('steps');
    final hr = t?.integer('heartRateAvg') ?? y?.integer('heartRateAvg');
    // Sleep is recorded on the morning it ended.
    final sleep = t?.integer('sleepMinutes') ?? y?.integer('sleepMinutes');
    if (steps == null && hr == null && sleep == null)
      return const SizedBox.shrink();
    final theme = Theme.of(context);
    final sources = s.sourcesSeen.take(2).join(', ');
    final when = s.lastSync == null
        ? null
        : DateFormat.jm().format(s.lastSync!.toLocal());

    Widget metric(IconData icon, String value, String label) => Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PrismSurface(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        onTap: () => context.go(AppRoutePaths.fitness),
        child: Column(
          children: [
            Row(
              children: [
                if (steps != null)
                  metric(
                    Icons.directions_walk,
                    NumberFormat.decimalPattern().format(steps),
                    tr(context, 'steps today', 'pasos hoy'),
                  ),
                if (sleep != null)
                  metric(
                    Icons.bedtime_outlined,
                    '${sleep ~/ 60}h ${sleep % 60}m',
                    tr(context, 'sleep', 'sueño'),
                  ),
                if (hr != null)
                  metric(
                    Icons.favorite_outline,
                    '$hr',
                    tr(context, 'avg bpm', 'lpm medio'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              [
                if (sources.isNotEmpty) sources,
                if (when != null)
                  tr(context, 'synced $when', 'sincronizado $when'),
              ].join(' · '),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
