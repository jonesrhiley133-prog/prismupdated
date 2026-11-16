import 'package:intl/intl.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Imported metrics remain visible independently of connection status/platform.
/// Separate sources are shown side by side, never summed across import paths.
class FitnessDailySection extends ConsumerWidget {
  const FitnessDailySection({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(trackerKindProvider(TrackerKind.fitnessDaily));
    return records.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) =>
          const Text('Imported daily activity could not be loaded.'),
      data: (rows) {
        if (rows.isEmpty) return const SizedBox.shrink();
        return ExpansionTile(
          title: const Text('Imported daily activity'),
          subtitle: const Text(
            'Daily records by source · overlapping sources are not added together',
          ),
          children: [
            for (final r in rows.take(60))
              ListTile(
                title: Text(
                  DateFormat.yMMMd().format(
                    (r.occurredAt ?? r.createdAt).toLocal(),
                  ),
                ),
                subtitle: Text(
                  [
                    r.str('source') ?? r.str('platform') ?? 'Health app',
                    ...r.strings('sources'),
                    if (r.integer('steps') != null)
                      '${r.integer('steps')} steps',
                    if (r.number('distanceKm') != null)
                      '${r.number('distanceKm')!.toStringAsFixed(2)} km',
                    if (r.integer('calories') != null)
                      '${r.integer('calories')} active kcal',
                    if (r.integer('totalEnergyKcal') != null)
                      '${r.integer('totalEnergyKcal')} total kcal',
                    if (r.integer('activeMinutes') != null)
                      '${r.integer('activeMinutes')} active min',
                    if (r.integer('heartRateAvg') != null)
                      '${r.integer('heartRateAvg')} bpm average',
                    if (r.integer('sleepMinutes') != null)
                      '${r.integer('sleepMinutes')} min sleep',
                  ].join(' · '),
                ),
              ),
          ],
        );
      },
    );
  }
}
