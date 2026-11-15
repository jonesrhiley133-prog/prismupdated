import 'package:prism_plurality/features/relationships/hub/rel_editor.dart';
import 'package:prism_plurality/features/relationships/hub/rel_map.dart';
import 'package:prism_plurality/features/relationships/hub/rel_model.dart';
import 'package:prism_plurality/features/relationships/hub/rel_randomize_sheet.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/widgets/prism_expandable_section.dart';

const _palette = [0xFFD98A9B, 0xFF7FA7D6, 0xFF7FB08A, 0xFF6FB3AE, 0xFF5E9E6E, 0xFF9C86C9, 0xFFD4AE5A, 0xFFDB8A4E, 0xFF9A9A9A, 0xFFB5ADA5, 0xFFC98B8B, 0xFFE29A86, 0xFF8B6A5C];

Future<void> showRelSettings(BuildContext context) => PrismSheet.showFullScreen(context: context, builder: (ctx, scroll) => _RelSettings(scroll: scroll));

class _RelSettings extends ConsumerWidget {
  const _RelSettings({required this.scroll});
  final ScrollController scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = ref.watch(relSettingsProvider);
    final a = ref.read(relActionsProvider);
    Widget section(String title, List<Widget> children, {bool open = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PrismExpandableSection(initiallyExpanded: open, title: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)), children: children),
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Expanded(child: Text(tr(context, 'Relationship settings', 'Ajustes de relaciones'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
              PrismTopBarAction(icon: AppIcons.close, tooltip: tr(context, 'Close', 'Cerrar'), onPressed: () => Navigator.of(context).pop()),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              section(tr(context, 'Map', 'Mapa'), [
                TrackerLabel(tr(context, 'Default layout', 'Diseño predeterminado')),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final v in RelMapView.values.where((v) => v != RelMapView.individual)) PrismChip(label: relViewLabel(context, v), selected: s.defaultLayout == v.name, onTap: () => a.saveSettings({'layout': v.name}))],
                ),
                PrismSwitchRow(title: tr(context, 'Show avatars', 'Mostrar avatares'), subtitle: tr(context, 'Turn off for very large systems or slower devices.', 'Desactívalo en sistemas muy grandes o dispositivos lentos.'), value: s.showAvatars, onChanged: (v) => a.saveSettings({'avatars': v})),
                PrismSwitchRow(title: tr(context, 'Always show line labels', 'Mostrar siempre las etiquetas'), value: s.showLabels, onChanged: (v) => a.saveSettings({'labels': v})),
              ], open: true),
              section(tr(context, 'Colours', 'Colores'), [
                for (final st in relStyles) ...[
                  TrackerLabel(relStyleText(context, st)),
                  ColorChoiceRow(
                    value: s.colorOf(st),
                    colors: _palette,
                    onChanged: (v) {
                      final m = {...((s.raw['colors'] as Map?)?.cast<String, Object?>() ?? const {}), st: v};
                      a.saveSettings({'colors': m});
                    },
                  ),
                  const SizedBox(height: 6),
                ],
                PrismButton(label: tr(context, 'Reset colours', 'Restablecer colores'), onPressed: () => a.saveSettings({'colors': null})),
              ]),
              section(tr(context, 'Categories & labels', 'Categorías y etiquetas'), [
                Text(tr(context, 'Custom categories', 'Categorías propias'), style: theme.textTheme.labelLarge),
                for (final c in s.customCategories)
                  PrismListRow(
                    dense: true,
                    leading: Container(width: 14, height: 14, decoration: BoxDecoration(color: Color(c.color), shape: BoxShape.circle)),
                    title: Text(c.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PrismTopBarAction(icon: AppIcons.editOutlined, tooltip: tr(context, 'Rename', 'Renombrar'), onPressed: () => _editCategory(context, ref, c)),
                        PrismTopBarAction(
                          icon: AppIcons.deleteOutline,
                          tooltip: tr(context, 'Delete', 'Eliminar'),
                          onPressed: () async {
                            final used = ref.read(relsProvider).any((r) => r.labels.any((l) => categoryOf(l, s) == c.key));
                            final ok = await PrismDialog.confirm(
                              context: context,
                              title: tr(context, 'Delete “${c.name}”?', '¿Eliminar «${c.name}»?'),
                              message: used ? tr(context, 'Labels in it move to Other. No relationship is removed.', 'Sus etiquetas pasan a Otra. No se elimina ninguna relación.') : null,
                              destructive: true,
                              confirmLabel: tr(context, 'Delete', 'Eliminar'),
                              cancelLabel: context.l10n.cancel,
                            );
                            if (ok != true) return;
                            await a.saveSettings({
                              'categories': [for (final x in s.customCategories) if (x.key != c.key) x.toJson()],
                              'customLabels': [for (final l in s.customLabels) (l.category == c.key ? RelCustomLabel(l.key, l.name, 'other', directional: l.directional, inverseName: l.inverseName) : l).toJson()],
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                PrismButton(label: tr(context, 'Add category', 'Añadir categoría'), icon: AppIcons.add, density: PrismControlDensity.compact, onPressed: () => _editCategory(context, ref, null)),
                const SizedBox(height: 12),
                Text(tr(context, 'Custom labels', 'Etiquetas propias'), style: theme.textTheme.labelLarge),
                for (final l in s.customLabels)
                  PrismListRow(
                    dense: true,
                    title: Text(l.directional && l.inverseName != null ? '${l.name} / ${l.inverseName}' : l.name),
                    subtitle: Text(relCategoryLabel(context, l.category, s)),
                    trailing: PrismTopBarAction(
                      icon: AppIcons.deleteOutline,
                      tooltip: tr(context, 'Delete', 'Eliminar'),
                      onPressed: () async {
                        final used = ref.read(relsProvider).where((r) => r.labels.contains(l.key) || r.labels.contains('~${l.key}')).length;
                        if (used > 0) {
                          PrismToast.show(context, message: tr(context, 'Used by $used relationship(s) — remove it there first.', 'La usan $used relación(es): quítala de ahí primero.'));
                          return;
                        }
                        await a.saveSettings({'customLabels': [for (final x in s.customLabels) if (x.key != l.key) x.toJson()]});
                      },
                    ),
                  ),
                PrismButton(label: tr(context, 'Add label', 'Añadir etiqueta'), icon: AppIcons.add, density: PrismControlDensity.compact, onPressed: () => addCustomLabel(context, ref)),
              ]),
              section(tr(context, 'Check-in questions', 'Preguntas de registro'), [
                for (final (i, q) in s.checkinQuestions.indexed)
                  PrismListRow(
                    dense: true,
                    title: Text(q),
                    trailing: PrismTopBarAction(
                      icon: AppIcons.deleteOutline,
                      tooltip: tr(context, 'Remove', 'Quitar'),
                      onPressed: () => a.saveSettings({'questions': [...s.checkinQuestions]..removeAt(i)}),
                    ),
                  ),
                Row(
                  children: [
                    PrismButton(
                      label: tr(context, 'Add question', 'Añadir pregunta'),
                      icon: AppIcons.add,
                      density: PrismControlDensity.compact,
                      onPressed: () async {
                        final q = await _prompt(context, tr(context, 'Question', 'Pregunta'));
                        if (q != null && q.trim().isNotEmpty) await a.saveSettings({'questions': [...s.checkinQuestions, q.trim()]});
                      },
                    ),
                    const SizedBox(width: 8),
                    PrismButton(label: tr(context, 'Restore defaults', 'Restaurar'), density: PrismControlDensity.compact, onPressed: () => a.saveSettings({'questions': null})),
                  ],
                ),
              ]),
              section(tr(context, 'Insights', 'Perspectivas'), [
                PrismSwitchRow(
                  title: tr(context, 'Show insights and summaries', 'Mostrar perspectivas y síntesis'),
                  subtitle: tr(context, 'Calculated on this device from your records only.', 'Calculadas en este dispositivo solo con tus registros.'),
                  value: s.insightsEnabled,
                  onChanged: (v) => a.saveSettings({'insights': v}),
                ),
              ]),
              section(tr(context, 'Privacy', 'Privacidad'), [
                PrismSwitchRow(
                  title: tr(context, 'Hide private relationships', 'Ocultar relaciones privadas'),
                  subtitle: tr(context, 'Leaves them off the map and directory (useful when someone else is looking). They still appear on alters’ own profiles behind a tap.', 'Las quita del mapa y del directorio (útil si alguien más mira). Siguen en los perfiles de los alters tras un toque.'),
                  value: s.hidePrivate,
                  onChanged: (v) => a.saveSettings({'hidePrivate': v}),
                ),
              ]),
              section(tr(context, 'Randomizer', 'Aleatorizador'), const [RandomizerSettings()]),
              section(tr(context, 'Saved map positions', 'Posiciones guardadas'), [
                Text(tr(context, 'Positions you arranged by hand are kept per layout.', 'Las posiciones que organizaste se guardan por diseño.'), style: theme.textTheme.bodySmall),
                const SizedBox(height: 6),
                PrismButton(label: tr(context, 'Clear all saved positions', 'Borrar todas las posiciones'), onPressed: () => a.saveSettings({'positions': null})),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

Future<String?> _prompt(BuildContext context, String title, {String? initial}) async {
  final c = TextEditingController(text: initial);
  String? out;
  await PrismSheet.show(
    context: context,
    title: title,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrismTextField(controller: c, autofocus: true),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: PrismButton(
              label: ctx.l10n.save,
              tone: PrismButtonTone.filled,
              onPressed: () {
                out = c.text;
                Navigator.of(ctx).pop();
              },
            ),
          ),
        ],
      ),
    ),
  );
  return out;
}

Future<void> _editCategory(BuildContext context, WidgetRef ref, RelCustomCategory? c) async {
  final name = await _prompt(context, c == null ? tr(context, 'New category', 'Nueva categoría') : tr(context, 'Rename category', 'Renombrar categoría'), initial: c?.name);
  if (name == null || name.trim().isEmpty) return;
  final s = ref.read(relSettingsProvider);
  final list = [
    for (final x in s.customCategories) (x.key == c?.key ? RelCustomCategory(x.key, name.trim(), x.color) : x).toJson(),
    if (c == null) RelCustomCategory('cat_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}', name.trim(), 0xFFB5ADA5).toJson(),
  ];
  await ref.read(relActionsProvider).saveSettings({'categories': list});
}
