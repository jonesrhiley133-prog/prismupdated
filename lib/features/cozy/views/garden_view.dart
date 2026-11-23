import 'package:intl/intl.dart' show DateFormat;

import 'package:prism_plurality/features/cozy/data/cozy_data.dart';
import 'package:prism_plurality/features/cozy/views/cozy_widgets.dart';
import 'package:prism_plurality/features/games/core/games_data.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

String plantEmoji(Plant p) => (plantSpecies[p.species] ?? plantSpecies['sprout']!).$2[p.stage];

const _stageNames = [('Seed', 'Semilla'), ('Sprout', 'Brote'), ('Growing', 'Creciendo'), ('Grown', 'Crecida'), ('Blooming', 'En flor')];

/// The system garden: anyone can plant and water; plants never die.
class GardenView extends ConsumerWidget {
  const GardenView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plants = ref.watch(plantsProvider);
    final theme = Theme.of(context);
    final me = ref.watch(cozyMeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrismSurface(
          tone: PrismSurfaceTone.accent,
          child: Text(
            tr(
              context,
              'Plant something for the system. Anyone can water anything — plants grow with care and never die. If nobody visits for a while, they just get a little sleepy.',
              'Planta algo para el sistema. Cualquiera puede regar. Las plantas crecen con cuidado y nunca mueren; si nadie las visita, solo se adormecen un poco.',
            ),
            style: theme.textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            PrismButton(
              tone: PrismButtonTone.filled,
              icon: PhosphorIcons.plant(),
              label: tr(context, 'Plant something', 'Plantar algo'),
              onPressed: () => PrismSheet.show<void>(context: context, title: tr(context, 'Plant something', 'Plantar algo'), builder: (_) => const _PlantSheet()),
            ),
            if (plants.any((p) => p.thirsty))
              PrismButton(
                icon: PhosphorIcons.drop(),
                label: tr(context, 'Water all thirsty plants', 'Regar todas las sedientas'),
                onPressed: () async {
                  for (final p in plants.where((p) => p.thirsty)) {
                    await ref.read(cozyActionsProvider).water(p, me);
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (plants.isEmpty)
          EmptyState(
            icon: const Text('🌱', style: TextStyle(fontSize: 34)),
            title: tr(context, 'An empty garden bed', 'Un bancal vacío'),
            subtitle: tr(context, 'Plant the first seed.', 'Planta la primera semilla.'),
          )
        else
          LayoutBuilder(
            builder: (context, box) {
              final cols = box.maxWidth > 560 ? 4 : 3;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.82,
                children: [
                  for (final p in plants)
                    Semantics(
                      button: true,
                      label: '${p.name}, ${cozyTrP(context, _stageNames[p.stage])}${p.thirsty ? ', ${tr(context, 'thirsty', 'con sed')}' : ''}',
                      excludeSemantics: true,
                      child: PrismSurface(
                        padding: const EdgeInsets.all(8),
                        onTap: () => PrismSheet.show<void>(
                          context: context,
                          title: p.name,
                          builder: (_) => _PlantDetail(plantId: p.r.id),
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: Center(
                                child: Opacity(
                                  opacity: p.thirsty ? 0.6 : 1,
                                  child: Transform.rotate(
                                    angle: p.thirsty ? 0.12 : 0,
                                    child: Text(plantEmoji(p), style: TextStyle(fontSize: 26 + p.stage * 6.0)),
                                  ),
                                ),
                              ),
                            ),
                            Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge),
                            Text(p.thirsty ? tr(context, '💧 thirsty', '💧 con sed') : cozyTrP(context, _stageNames[p.stage]), style: theme.textTheme.labelSmall),
                            const SizedBox(height: 4),
                            PrismButton(
                              density: PrismControlDensity.compact,
                              icon: PhosphorIcons.drop(),
                              label: tr(context, 'Water', 'Regar'),
                              onPressed: () {
                                ref.read(cozyActionsProvider).water(p, me);
                                PrismToast.show(context, message: tr(context, '${p.name} says thank you 💧', '${p.name} te da las gracias 💧'));
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

String cozyTrP(BuildContext c, (String, String) p) => tr(c, p.$1, p.$2);

class _PlantSheet extends ConsumerStatefulWidget {
  const _PlantSheet();
  @override
  ConsumerState<_PlantSheet> createState() => _PlantSheetState();
}

class _PlantSheetState extends ConsumerState<_PlantSheet> {
  String _species = 'flower';
  final _name = TextEditingController();
  late String? _by = ref.read(cozyMeProvider);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final names = ref.watch(gameNamesProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final e in plantSpecies.entries) PrismChip(label: '${e.value.$2.last} ${e.value.$1}', selected: _species == e.key, onTap: () => setState(() => _species = e.key))],
          ),
          const SizedBox(height: 8),
          PrismTextField(controller: _name, hintText: tr(context, 'Give it a name (e.g. "Pip")', 'Ponle nombre (p. ej. "Pip")')),
          PrismListRow(
            dense: true,
            leading: AlterDot(_by, size: 24),
            title: Text(tr(context, 'Planted by ${_by == null ? 'the system' : names[_by] ?? '?'}', 'Plantada por ${_by == null ? 'el sistema' : names[_by] ?? '?'}')),
            onTap: () async {
              final p = await pickAlters(context, ref, max: 1, selected: [?_by]);
              if (p != null) setState(() => _by = p.firstOrNull);
            },
          ),
          const SizedBox(height: 8),
          PrismButton(
            tone: PrismButtonTone.filled,
            label: tr(context, 'Plant', 'Plantar'),
            onPressed: () async {
              await ref
                  .read(trackerNotifierProvider.notifier)
                  .create(
                    kind: TrackerKind.cozyPlant,
                    title: _name.text.trim().isEmpty ? plantSpecies[_species]!.$1 : _name.text.trim(),
                    memberId: _by,
                    fields: {'species': _species, 'water': const []},
                  );
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

class _PlantDetail extends ConsumerWidget {
  const _PlantDetail({required this.plantId});
  final String plantId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(plantsProvider).where((x) => x.r.id == plantId).firstOrNull;
    if (p == null) return const SizedBox(height: 60);
    final names = ref.watch(gameNamesProvider);
    final carers = <String?, int>{};
    for (final w in p.waterings) {
      carers[w.$1] = (carers[w.$1] ?? 0) + 1;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(plantEmoji(p), textAlign: TextAlign.center, style: const TextStyle(fontSize: 64)),
          Text('${cozyTrP(context, _stageNames[p.stage])} · ${tr(context, 'watered ${p.waterings.length} times', 'regada ${p.waterings.length} veces')}', textAlign: TextAlign.center),
          Text(
            tr(
              context,
              'Planted ${DateFormat.yMMMd().format(p.r.createdAt)} by ${names[p.planter] ?? 'the system'}',
              'Plantada el ${DateFormat.yMMMd().format(p.r.createdAt)} por ${names[p.planter] ?? 'el sistema'}',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (carers.isNotEmpty) ...[
            PrismSectionHeader(title: tr(context, 'CARED FOR BY', 'CUIDADA POR')),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in carers.entries) PrismChip(avatar: AlterDot(e.key, size: 20), label: '${names[e.key] ?? tr(context, 'someone', 'alguien')} · ${e.value}', selected: false, onTap: () {}),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PrismButton(
                  label: tr(context, 'Move to compost (remove)', 'Retirar'),
                  onPressed: () {
                    ref.read(cozyActionsProvider).delete(p.r);
                    Navigator.of(context).pop();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PrismButton(
                  tone: PrismButtonTone.filled,
                  icon: PhosphorIcons.drop(),
                  label: tr(context, 'Water', 'Regar'),
                  onPressed: () => ref.read(cozyActionsProvider).water(p, ref.read(cozyMeProvider)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(cozyAgo(context, p.lastWatered), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
