import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/features/feature_state.dart';
import 'package:prism_plurality/features/fitness/health/health_sync.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Top of Fitness: offers the integration assistant the first time, and
/// shows today's imported totals once connected.
class HealthFitnessBanner extends ConsumerWidget {
  const HealthFitnessBanner({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(featureEnabledProvider('healthIntegration')))
      return const SizedBox.shrink();
    final g = ref.watch(healthGatewayProvider);
    if (!g.supported) return const SizedBox.shrink();
    final s = ref.watch(healthSettingsProvider);
    final theme = Theme.of(context);
    if (!s.connected) {
      if (s.assistantSeen) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: PrismSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    PhosphorIcons.sparkle(),
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr(
                        context,
                        'Log workouts automatically',
                        'Registra entrenamientos automáticamente',
                      ),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                tr(
                  context,
                  'Connect ${g.ios ? 'Apple Health' : 'Health Connect'} to import workouts, steps and more from your fitness apps. You choose what Prism can read.',
                  'Conecta ${g.ios ? 'Apple Health' : 'Health Connect'} para importar entrenamientos, pasos y más de tus apps. Tú eliges qué puede leer Prism.',
                ),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  PrismButton(
                    label: tr(context, 'Show me how', 'Enséñame'),
                    tone: PrismButtonTone.filled,
                    density: PrismControlDensity.compact,
                    onPressed: () {
                      ref.read(healthSyncProvider).saveSettings({
                        'assistantSeen': true,
                      });
                      context.push('/fitness/integrations');
                    },
                  ),
                  PrismButton(
                    label: tr(context, 'Not now', 'Ahora no'),
                    density: PrismControlDensity.compact,
                    onPressed: () => ref.read(healthSyncProvider).saveSettings({
                      'assistantSeen': true,
                    }),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rows =
        (ref.watch(trackerKindProvider(TrackerKind.fitnessDaily)).value ??
                const <TrackerRecord>[])
            .where(
              (r) =>
                  (r.str('dayKey') ??
                      (r.occurredAt == null ? null : dayKey(r.occurredAt!))) ==
                  dayKey(today),
            )
            .toList();
    // Live sync and a file import may both cover today: one value per
    // metric (the larger), never added together.
    final d = mergeDailyRows(rows);
    final parts = <String>[
      if (d['steps'] != null)
        tr(context, '${d['steps']} steps', '${d['steps']} pasos'),
      if (d['distanceKm'] != null) '${d['distanceKm']!.toStringAsFixed(1)} km',
      if (d['calories'] != null) '${d['calories']!.round()} kcal',
      if (d['activeMinutes'] != null)
        tr(
          context,
          '${d['activeMinutes']!.round()} active min',
          '${d['activeMinutes']!.round()} min activos',
        ),
      if (d['heartRateAvg'] != null) '♥ ${d['heartRateAvg']!.round()} bpm',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PrismSurface(
        onTap: () => context.push('/fitness/integrations'),
        child: Row(
          children: [
            Icon(PhosphorIcons.heartbeat(), color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(
                      context,
                      'Today from health apps',
                      'Hoy desde apps de salud',
                    ),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    parts.isEmpty
                        ? tr(
                            context,
                            'Nothing synced yet today.',
                            'Aún no hay datos de hoy.',
                          )
                        : parts.join(' · '),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(PhosphorIcons.caretRight(), size: 16),
          ],
        ),
      ),
    );
  }
}
