import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/members/studio/profile_config.dart';
import 'package:prism_plurality/features/relationships/hub/rel_editor.dart';
import 'package:prism_plurality/features/relationships/hub/rel_model.dart';
import 'package:prism_plurality/features/relationships/hub/rel_randomizer.dart';
import 'package:prism_plurality/features/relationships/utils/relationships.dart';
import 'package:prism_plurality/features/subsystems/hub/subsystem_data.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/widgets/prism_expandable_section.dart';

/// Builds what the randomizer may use from documented data only.
List<RandAlter> randAlters(WidgetRef ref) {
  final prefer = ref.read(memberNamePreferDisplayProvider);
  final memberships = ref.read(subMembershipsProvider);
  return [
    for (final m in ref.read(relAltersProvider))
      if (m.isActive)
        () {
          final cfg = ref.read(memberProfileProvider(m.id));
          final roles = <String>{
            for (final r in cfg?.roles ?? const <ProfileRole>[]) r.name,
            ...?cfg?.list('internalRoles'),
            for (final s in memberships.where((s) => s.memberId == m.id)) ...s.roles,
          };
          final interests = <String>{
            for (final k in const ['likes', 'hobbies', 'favMusic', 'favMedia', 'favFoods', 'favColors']) ...?cfg?.list(k).map((x) => x.trim().toLowerCase()),
          };
          return RandAlter(
            id: m.id,
            name: m.effectiveName(preferDisplayName: prefer),
            age: parseAge(m.age) ?? parseAge(cfg?.str('ageRange')),
            roles: roles,
            interests: interests,
            communication: {...?cfg?.list('communication').map((x) => x.trim().toLowerCase())},
          );
        }(),
  ];
}

Future<void> showRandomizer(BuildContext context) => PrismSheet.showFullScreen(context: context, builder: (ctx, scroll) => _RandomizerSheet(scroll: scroll));

class _RandomizerSheet extends ConsumerStatefulWidget {
  const _RandomizerSheet({required this.scroll});
  final ScrollController scroll;
  @override
  ConsumerState<_RandomizerSheet> createState() => _RandomizerSheetState();
}

class _RandomizerSheetState extends ConsumerState<_RandomizerSheet> {
  RelSuggestion? _s;
  bool _none = false;
  final _triedLabels = <String>{};
  final _triedPartners = <String>{};

  RelRandomizer _engine() {
    final settings = ref.read(relSettingsProvider);
    return RelRandomizer(alters: randAlters(ref), rels: ref.read(relsProvider), settings: settings, options: RandOptions.from(settings));
  }

  void _roll({bool keepPair = false, String? keepId}) {
    final e = _engine();
    RelSuggestion? next;
    final cur = _s;
    if (keepPair && cur != null) {
      _triedLabels.add(cur.label);
      next = e.suggestFor(cur.a, cur.b, avoidLabels: _triedLabels);
    } else if (keepId != null && cur != null) {
      _triedLabels.clear();
      _triedPartners.add(cur.a.id == keepId ? cur.b.id : cur.a.id);
      next = e.suggest(lockA: keepId, avoidPartners: _triedPartners);
    } else {
      _triedLabels.clear();
      _triedPartners.clear();
      next = e.suggest();
    }
    setState(() {
      _s = next;
      _none = next == null;
    });
  }

  bool _rolled = false;

  Future<void> _accept() async {
    final s = _s;
    if (s == null) return;
    final settings = ref.read(relSettingsProvider);
    final label = labelText(context, s.label, settings);
    final ok = await PrismDialog.confirm(
      context: context,
      title: tr(context, 'Save this relationship?', '¿Guardar esta relación?'),
      message: tr(
        context,
        '${s.a.name} & ${s.b.name}: $label. It is saved as “suspected” so it isn’t confused with confirmed relationships — you can change that any time.${s.existing.isEmpty ? '' : ' The label is added to their existing relationship.'}',
        '${s.a.name} y ${s.b.name}: $label. Se guarda como «sospechada» para no confundirla con relaciones confirmadas; puedes cambiarlo cuando quieras.${s.existing.isEmpty ? '' : ' La etiqueta se añade a su relación existente.'}',
      ),
      confirmLabel: tr(context, 'Save', 'Guardar'),
      cancelLabel: context.l10n.cancel,
    );
    if (ok != true) return;
    await ref.read(relActionsProvider).save(memberId: s.a.id, otherType: RelOther.member, otherId: s.b.id, otherName: s.b.name, labels: [s.label], confidence: 'suspected', status: 'exploring');
    if (!mounted) return;
    PrismToast.show(context, message: tr(context, 'Relationship saved', 'Relación guardada'), icon: PhosphorIcons.check());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(relSettingsProvider);
    final alters = ref.watch(relAlterIndexProvider);
    // Roll once the alters have loaded.
    if (!_rolled && alters.length >= 2) {
      _rolled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _roll();
      });
    }
    final s = _s;
    Widget person(RandAlter a, VoidCallback reroll) => Expanded(
      child: PrismSurface(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (alters[a.id] != null) relAvatar(ref, alters[a.id]!, 52),
            const SizedBox(height: 6),
            Text(a.name, textAlign: TextAlign.center, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            Text(a.age == null ? tr(context, 'Age not documented', 'Edad sin documentar') : tr(context, 'Age ${a.age}', 'Edad ${a.age}'), style: theme.textTheme.bodySmall),
            if (a.roles.isNotEmpty) Text(a.roles.take(3).join(', '), maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            PrismButton(label: tr(context, 'Reroll the other', 'Cambiar al otro'), icon: PhosphorIcons.shuffle(), density: PrismControlDensity.compact, onPressed: reroll),
          ],
        ),
      ),
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Expanded(child: Text(tr(context, 'Randomize relationship', 'Relación aleatoria'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
              PrismTopBarAction(icon: AppIcons.close, tooltip: tr(context, 'Dismiss', 'Descartar'), onPressed: () => Navigator.of(context).pop()),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: widget.scroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                tr(context, 'A possible relationship built from what you’ve documented — ages, roles, interests and existing relationships. Nothing is saved unless you confirm it.', 'Una posible relación basada en lo que has documentado: edades, roles, intereses y relaciones existentes. No se guarda nada sin tu confirmación.'),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              if (alters.length < 2)
                PrismSurface(child: Text(tr(context, 'Add at least two alters to get suggestions.', 'Añade al menos dos alters para recibir sugerencias.')))
              else if (_none)
                PrismSurface(
                  child: Text(
                    tr(context, 'No suggestion fits your current settings and records. Try loosening the randomizer settings below, or add more alters.', 'Ninguna sugerencia encaja con tus ajustes y registros. Prueba a relajar los ajustes de abajo o añade más alters.'),
                  ),
                )
              else if (s != null) ...[
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      person(s.a, () => _roll(keepId: s.a.id)),
                      const SizedBox(width: 8),
                      person(s.b, () => _roll(keepId: s.b.id)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                PrismSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr(context, 'Suggested', 'Sugerida'), style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Text(labelText(context, s.label, settings), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      Text(relCategoryLabel(context, s.category, settings), style: theme.textTheme.bodySmall),
                      if (relLabelIndex[s.label]?.directional ?? false) Text(tr(context, '${s.a.name} would be ${s.b.name}’s ${labelText(context, s.label, settings).toLowerCase()}', '${s.a.name} sería ${labelText(context, s.label, settings).toLowerCase()} de ${s.b.name}'), style: theme.textTheme.bodySmall),
                      if (s.existing.isNotEmpty) Text(tr(context, 'Already documented: ${s.existing.map((l) => labelText(context, l, settings)).join(', ')}', 'Ya documentado: ${s.existing.map((l) => labelText(context, l, settings)).join(', ')}'), style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _List(title: tr(context, 'Why this pairing', 'Por qué esta combinación'), icon: PhosphorIcons.lightbulb(), items: s.reasons),
                _List(title: tr(context, 'Factors considered', 'Factores considerados'), icon: PhosphorIcons.listChecks(), items: s.factors),
                if (s.warnings.isNotEmpty) _List(title: tr(context, 'Missing information & cautions', 'Información faltante y advertencias'), icon: PhosphorIcons.warning(), items: s.warnings, warn: true),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    PrismButton(label: tr(context, 'Reroll type', 'Otra etiqueta'), icon: PhosphorIcons.arrowsClockwise(), onPressed: () => _roll(keepPair: true)),
                    PrismButton(label: tr(context, 'Reroll both', 'Otros dos'), icon: PhosphorIcons.shuffle(), onPressed: _roll),
                    PrismButton(
                      label: tr(context, 'Edit', 'Editar'),
                      icon: AppIcons.editOutlined,
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        final id = await showRelEditor(context, memberId: s.a.id, otherId: s.b.id, labels: [s.label], category: s.category);
                        if (id != null) nav.pop();
                      },
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              PrismExpandableSection(
                title: Text(tr(context, 'Randomizer settings', 'Ajustes del aleatorizador'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                children: [RandomizerSettings(onChanged: () => setState(() {}))],
              ),
            ],
          ),
        ),
        if (s != null)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                runSpacing: 8,
                children: [
                  PrismButton(label: tr(context, 'Dismiss', 'Descartar'), onPressed: () => Navigator.of(context).pop()),
                  PrismButton(label: tr(context, 'Accept & save', 'Aceptar y guardar'), icon: PhosphorIcons.check(), tone: PrismButtonTone.filled, onPressed: _accept),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.title, required this.icon, required this.items, this.warn = false});
  final String title;
  final IconData icon;
  final List<Bi> items;
  final bool warn;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, size: 16, color: warn ? theme.colorScheme.error : theme.colorScheme.primary), const SizedBox(width: 6), Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))]),
          const SizedBox(height: 4),
          for (final i in items) Padding(padding: const EdgeInsets.only(left: 22, bottom: 3), child: Text('• ${tr(context, i.$1, i.$2)}', style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// Randomizer options, saved to the hub settings.
class RandomizerSettings extends ConsumerWidget {
  const RandomizerSettings({super.key, this.onChanged});
  final VoidCallback? onChanged;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(relSettingsProvider);
    final a = ref.read(relActionsProvider);
    Widget sw(String key, String en, String es, {bool fallback = false}) => PrismSwitchRow(
      title: tr(context, en, es),
      value: s.rand(key, fallback),
      onChanged: (v) async {
        await a.setRandomizer(key, v);
        onChanged?.call();
      },
    );
    final allRoles = <String>{
      for (final m in ref.watch(relAltersProvider)) ...?ref.watch(memberProfileProvider(m.id))?.roles.map((r) => r.name.toLowerCase()),
    }.toList()
      ..sort();
    final chosen = s.randomizerRoles.toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sw('excludeNoAge', 'Exclude alters without a documented age', 'Excluir alters sin edad documentada'),
        sw('excludeConnected', 'Exclude alters who are already connected', 'Excluir alters ya conectados'),
        sw('allowAdditional', 'Allow extra labels for existing pairs', 'Permitir etiquetas extra en parejas existentes', fallback: true),
        sw('noRomantic', 'No romantic suggestions', 'Sin sugerencias románticas'),
        sw('noFamilial', 'No family suggestions', 'Sin sugerencias familiares'),
        sw('onlyPlatonic', 'Only platonic connections', 'Solo conexiones platónicas'),
        sw('includeCustom', 'Include custom labels', 'Incluir etiquetas personalizadas'),
        sw('useRoles', 'Use roles as context', 'Usar roles como contexto', fallback: true),
        sw('useInterests', 'Use shared interests', 'Usar intereses en común', fallback: true),
        if (allRoles.isNotEmpty) ...[
          const SizedBox(height: 6),
          TrackerLabel(tr(context, 'Only include alters with these roles (none = everyone)', 'Solo alters con estos roles (ninguno = todos)')),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final r in allRoles)
                PrismChip(
                  label: r,
                  selected: chosen.contains(r),
                  onTap: () async {
                    final next = chosen.contains(r) ? (chosen..remove(r)) : (chosen..add(r));
                    await a.setRandomizer('roles', next.toList());
                    onChanged?.call();
                  },
                ),
            ],
          ),
        ],
        const SizedBox(height: 6),
        Text(
          tr(context, 'Always on: romantic labels are never suggested when a minor is involved or an age is unknown; family members are never paired romantically; existing relationships are never overwritten.', 'Siempre activo: nunca se sugieren etiquetas románticas con un menor o una edad desconocida; nunca se empareja románticamente a familiares; nunca se sobrescriben relaciones existentes.'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
