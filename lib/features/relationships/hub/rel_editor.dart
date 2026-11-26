import 'package:intl/intl.dart';

import 'package:prism_plurality/domain/models/contact.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/contacts/providers/contact_providers.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/relationships/hub/rel_model.dart';
import 'package:prism_plurality/features/relationships/utils/relationships.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/widgets/member_avatar.dart';

/// Opens the relationship editor. Returns the saved relationship id.
Future<String?> showRelEditor(
  BuildContext context, {
  Rel? editing,
  String? memberId,
  String? otherId,
  List<String> labels = const [],
  String? category,
}) => PrismSheet.showFullScreen<String>(
  context: context,
  builder: (ctx, scroll) => RelEditor(
    editing: editing,
    memberId: memberId,
    otherId: otherId,
    presetLabels: labels,
    focusCategory: category,
    scroll: scroll,
  ),
);

/// Searchable alter picker. Returns the chosen member id.
Future<String?> pickAlter(
  BuildContext context,
  WidgetRef ref, {
  Set<String> exclude = const {},
  String? title,
}) async {
  String? picked;
  final q = TextEditingController();
  await PrismSheet.show(
    context: context,
    title: title ?? tr(context, 'Choose an alter', 'Elige un alter'),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final prefer = ref.read(memberNamePreferDisplayProvider);
        final list =
            [
              for (final m in ref.read(relAltersProvider))
                if (!exclude.contains(m.id) &&
                    (q.text.isEmpty ||
                        m
                            .effectiveName(preferDisplayName: prefer)
                            .toLowerCase()
                            .contains(q.text.toLowerCase())))
                  m,
            ]..sort(
              (a, b) => a
                  .effectiveName(preferDisplayName: prefer)
                  .compareTo(b.effectiveName(preferDisplayName: prefer)),
            );
        return SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.6,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: PrismTextField(
                  controller: q,
                  hintText: tr(ctx, 'Search alters', 'Buscar alters'),
                  prefixIcon: Icon(AppIcons.search),
                  onChanged: (_) => set(() {}),
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final m in list)
                      PrismListRow(
                        leading: relAvatar(ref, m, 32),
                        title: Text(m.effectiveName(preferDisplayName: prefer)),
                        subtitle: (m.pronouns ?? '').isEmpty
                            ? null
                            : Text(m.pronouns!),
                        onTap: () {
                          picked = m.id;
                          Navigator.of(ctx).pop();
                        },
                      ),
                    if (list.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          tr(
                            ctx,
                            'No alters found.',
                            'No se encontraron alters.',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
  return picked;
}

Widget relAvatar(WidgetRef ref, Member m, double size) {
  final prefer = ref.watch(memberNamePreferDisplayProvider);
  return MemberAvatar(
    avatarImageData: m.avatarImageData,
    memberName: m.effectiveName(preferDisplayName: prefer),
    emoji: m.emoji,
    customColorEnabled: m.customColorEnabled,
    customColorHex: m.customColorHex,
    size: size,
  );
}

/// Adds a custom label to the hub settings. Returns its key.
Future<String?> addCustomLabel(
  BuildContext context,
  WidgetRef ref, {
  String category = 'other',
}) async {
  final name = TextEditingController();
  final inverse = TextEditingController();
  var cat = category;
  var directional = false;
  String? out;
  await PrismSheet.show(
    context: context,
    title: tr(context, 'Custom label', 'Etiqueta personalizada'),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final settings = ref.read(relSettingsProvider);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PrismTextField(
                controller: name,
                labelText: tr(ctx, 'Label', 'Etiqueta'),
                autofocus: true,
              ),
              const SizedBox(height: 10),
              TrackerLabel(tr(ctx, 'Category', 'Categoría')),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in settings.categories)
                    PrismChip(
                      label: relCategoryLabel(ctx, c, settings),
                      selected: cat == c,
                      onTap: () => set(() => cat = c),
                    ),
                ],
              ),
              PrismSwitchRow(
                title: tr(
                  ctx,
                  'Has a direction (like mentor → mentee)',
                  'Tiene dirección (como mentor → aprendiz)',
                ),
                value: directional,
                onChanged: (v) => set(() => directional = v),
              ),
              if (directional)
                PrismTextField(
                  controller: inverse,
                  labelText: tr(
                    ctx,
                    'Name for the other side',
                    'Nombre para la otra parte',
                  ),
                ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: PrismButton(
                  label: ctx.l10n.save,
                  tone: PrismButtonTone.filled,
                  onPressed: () async {
                    final n = name.text.trim();
                    if (n.isEmpty) return;
                    final key =
                        'c_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
                    final list = [
                      for (final c in settings.customLabels) c.toJson(),
                      RelCustomLabel(
                        key,
                        n,
                        cat,
                        directional: directional,
                        inverseName: inverse.text.trim().isEmpty
                            ? null
                            : inverse.text.trim(),
                      ).toJson(),
                    ];
                    await ref.read(relActionsProvider).saveSettings({
                      'customLabels': list,
                    });
                    out = key;
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
  return out;
}

class RelEditor extends ConsumerStatefulWidget {
  const RelEditor({
    super.key,
    this.editing,
    this.memberId,
    this.otherId,
    this.presetLabels = const [],
    this.focusCategory,
    this.scroll,
  });
  final Rel? editing;
  final String? memberId;
  final String? otherId;
  final List<String> presetLabels;
  final String? focusCategory;
  final ScrollController? scroll;
  @override
  ConsumerState<RelEditor> createState() => _RelEditorState();
}

class _RelEditorState extends ConsumerState<RelEditor> {
  Rel? get _e => widget.editing;
  late String? _a = _e?.a ?? widget.memberId;
  late String _otherType = _e?.r.str(RelField.otherType) ?? RelOther.member;
  late String? _b = _e == null ? widget.otherId : _e!.r.str(RelField.otherId);
  late final _otherName = TextEditingController(
    text: _e?.internal == false ? _e?.otherName : '',
  );
  late final _title = TextEditingController(text: _e?.title ?? '');
  late final _desc = TextEditingController(text: _e?.description ?? '');
  late final _boundaries = TextEditingController(
    text: _e?.r.strings(RelField.boundaries).join('\n') ?? '',
  );
  late final _dynNote = TextEditingController(
    text: _e?.r.str(RelField.dynamics) ?? '',
  );
  late final List<String> _labels = [
    ...?_e?.labels,
    for (final l in widget.presetLabels)
      if (!(_e?.labels.contains(l) ?? false)) l,
  ];
  late String _status = _e?.status ?? 'active';
  late String _confidence = _e?.confidence ?? 'confirmed';
  late bool _private = _e?.private ?? false;
  late bool _mutual = _e?.r.flag(RelField.mutual) ?? true;
  late DateTime _documented = _e?.documented ?? DateTime.now();
  late final Map<String, int?> _dyn = {
    for (final k in relDynamics) k: _e?.dyn(k),
  };
  late String _openCategory =
      widget.focusCategory ??
      (_labels.isEmpty
          ? 'platonic'
          : categoryOf(_labels.first, ref.read(relSettingsProvider)));
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_otherName, _title, _desc, _boundaries, _dynNote]) {
      c.dispose();
    }
    super.dispose();
  }

  Rel? get _existingPair {
    if (_otherType != RelOther.member || _a == null || _b == null) return null;
    final ex = ref.read(relActionsProvider).existingFor(_a!, _b!);
    return ex == null || ex.id == _e?.id ? null : ex;
  }

  Future<void> _save() async {
    setState(() => _error = null);
    String? err;
    if (_a == null)
      err = tr(context, 'Choose the first alter.', 'Elige el primer alter.');
    if (_otherType == RelOther.member && (_b == null || _b == _a))
      err ??= tr(
        context,
        'Choose a different second alter.',
        'Elige un segundo alter distinto.',
      );
    if (_otherType == RelOther.contact && _b == null)
      err ??= tr(context, 'Choose a contact.', 'Elige un contacto.');
    if (_otherType == RelOther.person && _otherName.text.trim().isEmpty)
      err ??= tr(
        context,
        'Enter who the relationship is with.',
        'Indica con quién es la relación.',
      );
    if (_labels.isEmpty)
      err ??= tr(
        context,
        'Choose at least one label.',
        'Elige al menos una etiqueta.',
      );
    if (_e != null && _existingPair != null)
      err ??= tr(
        context,
        'These two already have a relationship — edit that one instead.',
        'Estos dos ya tienen una relación: edita esa.',
      );
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() => _saving = true);
    final contacts = ref.read(contactsProvider).value ?? const <Contact>[];
    final otherName = switch (_otherType) {
      RelOther.member => ref.read(relAlterIndexProvider)[_b]?.name,
      RelOther.contact =>
        contacts.where((c) => c.id == _b).firstOrNull?.displayName,
      _ => _otherName.text.trim(),
    };
    try {
      final id = await ref
          .read(relActionsProvider)
          .save(
            editing: _e,
            memberId: _a!,
            otherType: _otherType,
            otherId: _otherType == RelOther.person ? null : _b,
            otherName: otherName,
            title: _title.text.trim(),
            description: _desc.text.trim(),
            labels: _labels,
            status: _status,
            confidence: _confidence,
            dyn: _dyn,
            mutual: _mutual,
            private: _private,
            boundaries: [
              for (final l in _boundaries.text.split('\n'))
                if (l.trim().isNotEmpty) l.trim(),
            ],
            dynamicsNote: _dynNote.text,
            documented: _documented,
          );
      if (!mounted) return;
      PrismToast.show(
        context,
        message: tr(context, 'Relationship saved', 'Relación guardada'),
        icon: PhosphorIcons.check(),
      );
      Navigator.of(context).pop(id);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = tr(context, 'Couldn’t save: $e', 'No se pudo guardar: $e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(relSettingsProvider);
    final alters = ref.watch(relAlterIndexProvider);
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    final contacts = ref.watch(contactsProvider).value ?? const <Contact>[];
    String nm(String? id) =>
        alters[id]?.effectiveName(preferDisplayName: prefer) ??
        tr(context, 'Choose…', 'Elegir…');
    final existing = _e == null ? _existingPair : null;
    final directionalSelected = [
      for (final l in _labels)
        if (relLabelIndex[l]?.directional ??
            settings.customLabels.any((c) => c.key == l && c.directional))
          l,
    ];

    Widget alterButton(
      String? id,
      ValueChanged<String> onPick, {
      Set<String> exclude = const {},
    }) => PrismSurface(
      padding: const EdgeInsets.all(10),
      onTap: () async {
        final p = await pickAlter(context, ref, exclude: exclude);
        if (p != null) onPick(p);
      },
      child: Row(
        children: [
          if (alters[id] != null)
            relAvatar(ref, alters[id]!, 32)
          else
            PrismCircleAvatar(
              radius: 16,
              child: Icon(PhosphorIcons.user(), size: 16),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              nm(id),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(PhosphorIcons.caretDown(), size: 16),
        ],
      ),
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _e == null
                      ? tr(context, 'New relationship', 'Nueva relación')
                      : tr(context, 'Edit relationship', 'Editar relación'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              PrismTopBarAction(
                icon: AppIcons.close,
                tooltip: tr(context, 'Close', 'Cerrar'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: widget.scroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              TrackerLabel(tr(context, 'First alter', 'Primer alter')),
              alterButton(_a, (v) => setState(() => _a = v), exclude: {?_b}),
              const SizedBox(height: 12),
              TrackerLabel(tr(context, 'With', 'Con')),
              PrismSegmentedControl<String>(
                segments: [
                  PrismSegment(
                    value: RelOther.member,
                    label: tr(context, 'Alter', 'Alter'),
                  ),
                  PrismSegment(
                    value: RelOther.contact,
                    label: tr(context, 'Contact', 'Contacto'),
                  ),
                  PrismSegment(
                    value: RelOther.person,
                    label: tr(context, 'Someone else', 'Otra persona'),
                  ),
                ],
                selected: _otherType,
                onChanged: (v) => setState(() {
                  _otherType = v;
                  _b = null;
                }),
              ),
              const SizedBox(height: 8),
              if (_otherType == RelOther.member)
                alterButton(_b, (v) => setState(() => _b = v), exclude: {?_a})
              else if (_otherType == RelOther.contact)
                contacts.isEmpty
                    ? Text(
                        tr(
                          context,
                          'No contacts yet.',
                          'Aún no hay contactos.',
                        ),
                      )
                    : Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final c in contacts)
                            PrismChip(
                              label: c.displayName,
                              selected: _b == c.id,
                              onTap: () => setState(() => _b = c.id),
                            ),
                        ],
                      )
              else
                PrismTextField(
                  controller: _otherName,
                  labelText: tr(context, 'Name', 'Nombre'),
                ),
              if (existing != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: prismCorners(context, 12),
                  ),
                  child: Text(
                    tr(
                      context,
                      'These two already have a relationship (${existing.labels.map((l) => labelText(context, l, settings)).join(', ')}). The labels you pick will be added to it — nothing is replaced.',
                      'Estos dos ya tienen una relación (${existing.labels.map((l) => labelText(context, l, settings)).join(', ')}). Las etiquetas que elijas se añadirán: no se reemplaza nada.',
                    ),
                    style: TextStyle(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              PrismTextField(
                controller: _title,
                labelText: tr(context, 'Title (optional)', 'Título (opcional)'),
                hintText: tr(
                  context,
                  'e.g. The night-shift duo',
                  'p. ej. El dúo del turno de noche',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                tr(context, 'Labels', 'Etiquetas'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                tr(
                  context,
                  'Pick as many as apply — for example siblings and best friends.',
                  'Elige todas las que apliquen, por ejemplo hermanos y mejores amigos.',
                ),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in settings.categories)
                    PrismChip(
                      label:
                          '${relCategoryLabel(context, c, settings)}${_labels.where((l) => categoryOf(l, settings) == c).isEmpty ? '' : ' · ${_labels.where((l) => categoryOf(l, settings) == c).length}'}',
                      selected: _openCategory == c,
                      onTap: () => setState(() => _openCategory = c),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final l in relLabels.where(
                    (l) => l.category == _openCategory,
                  ))
                    PrismChip(
                      label: tr(context, l.en, l.es),
                      selected: _labels.contains(l.key),
                      onTap: () => setState(
                        () => _labels.contains(l.key)
                            ? _labels.remove(l.key)
                            : _labels.add(l.key),
                      ),
                    ),
                  for (final cl in settings.customLabels.where(
                    (c) => c.category == _openCategory,
                  ))
                    PrismChip(
                      label: '✎ ${cl.name}',
                      selected: _labels.contains(cl.key),
                      onTap: () => setState(
                        () => _labels.contains(cl.key)
                            ? _labels.remove(cl.key)
                            : _labels.add(cl.key),
                      ),
                    ),
                  PrismButton(
                    label: tr(context, 'Custom label', 'Etiqueta propia'),
                    icon: AppIcons.add,
                    density: PrismControlDensity.compact,
                    onPressed: () async {
                      final k = await addCustomLabel(
                        context,
                        ref,
                        category: _openCategory,
                      );
                      if (k != null) setState(() => _labels.add(k));
                    },
                  ),
                ],
              ),
              if (_labels.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  '${tr(context, 'Selected', 'Seleccionadas')}: ${_labels.map((l) => labelText(context, l, settings)).join(', ')}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (directionalSelected.isNotEmpty &&
                  _otherType == RelOther.member) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr(
                          context,
                          'Reads as: ${nm(_a)} is ${nm(_b)}’s ${directionalSelected.map((l) => labelText(context, l, settings).toLowerCase()).join(', ')}',
                          'Se lee: ${nm(_a)} es ${directionalSelected.map((l) => labelText(context, l, settings).toLowerCase()).join(', ')} de ${nm(_b)}',
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    PrismButton(
                      label: tr(context, 'Swap', 'Invertir'),
                      icon: PhosphorIcons.arrowsLeftRight(),
                      density: PrismControlDensity.compact,
                      onPressed: () => setState(() {
                        final t = _a;
                        _a = _b;
                        _b = t;
                      }),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              TrackerLabel(tr(context, 'Status', 'Estado')),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in relStatuses)
                    PrismChip(
                      label: relStatusText(context, s),
                      selected: _status == s,
                      onTap: () => setState(() => _status = s),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TrackerLabel(tr(context, 'Confidence', 'Certeza')),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in relConfidences)
                    PrismChip(
                      label: relConfidenceText(context, s),
                      selected: _confidence == s,
                      onTap: () => setState(() => _confidence = s),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              PrismSwitchRow(
                title: tr(context, 'Private', 'Privada'),
                subtitle: tr(
                  context,
                  'Hidden behind a tap and left out of shared views.',
                  'Oculta tras un toque y fuera de las vistas compartidas.',
                ),
                value: _private,
                onChanged: (v) => setState(() => _private = v),
              ),
              if (_otherType == RelOther.member)
                PrismSwitchRow(
                  title: tr(context, 'Felt by both', 'Mutua'),
                  value: _mutual,
                  onChanged: (v) => setState(() => _mutual = v),
                ),
              PrismButton(
                label:
                    '${tr(context, 'First documented', 'Documentada desde')}: ${DateFormat.yMMMd(context.dateLocale).format(_documented)}',
                icon: PhosphorIcons.calendar(),
                onPressed: () async {
                  final d = await showPrismDatePicker(
                    context: context,
                    initialDate: _documented,
                    firstDate: DateTime(1990),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                  );
                  if (d != null) setState(() => _documented = d);
                },
              ),
              const SizedBox(height: 16),
              PrismTextField(
                controller: _desc,
                labelText: tr(context, 'Description', 'Descripción'),
                hintText: tr(
                  context,
                  'How they interact, what makes it unique, what they share or disagree about…',
                  'Cómo interactúan, qué la hace única, qué comparten o en qué discrepan…',
                ),
                minLines: 4,
                maxLines: 14,
              ),
              const SizedBox(height: 16),
              Text(
                tr(context, 'Dynamics', 'Dinámica'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                tr(
                  context,
                  'Optional, from 1 to 5, set by you.',
                  'Opcional, de 1 a 5, a tu criterio.',
                ),
                style: theme.textTheme.bodySmall,
              ),
              for (final k in relDynamics)
                Row(
                  children: [
                    SizedBox(
                      width: 150,
                      child: Text(
                        relDynamicLabel(context, k),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Expanded(
                      child: _dyn[k] == null
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: PrismChip(
                                label: tr(context, 'Not set', 'Sin valorar'),
                                selected: false,
                                onTap: () => setState(() => _dyn[k] = 3),
                              ),
                            )
                          : Slider(
                              value: _dyn[k]!.toDouble(),
                              min: 1,
                              max: 5,
                              divisions: 4,
                              label: '${_dyn[k]}',
                              onChanged: (v) =>
                                  setState(() => _dyn[k] = v.round()),
                            ),
                    ),
                    if (_dyn[k] != null)
                      PrismTopBarAction(
                        icon: AppIcons.close,
                        tooltip: tr(context, 'Clear', 'Quitar'),
                        onPressed: () => setState(() => _dyn[k] = null),
                      ),
                  ],
                ),
              const SizedBox(height: 12),
              PrismTextField(
                controller: _dynNote,
                labelText: tr(
                  context,
                  'Dynamics notes',
                  'Notas sobre la dinámica',
                ),
                minLines: 2,
                maxLines: 6,
              ),
              const SizedBox(height: 12),
              PrismTextField(
                controller: _boundaries,
                labelText: tr(
                  context,
                  'Boundaries (one per line)',
                  'Límites (uno por línea)',
                ),
                minLines: 2,
                maxLines: 8,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              runSpacing: 8,
              children: [
                PrismButton(
                  label: context.l10n.cancel,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                PrismButton(
                  label: existing != null
                      ? tr(
                          context,
                          'Add to relationship',
                          'Añadir a la relación',
                        )
                      : context.l10n.save,
                  tone: PrismButtonTone.filled,
                  isLoading: _saving,
                  onPressed: _saving ? () {} : _save,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
