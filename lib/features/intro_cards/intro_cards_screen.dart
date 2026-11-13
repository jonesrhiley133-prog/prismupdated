import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/intro_cards/intro_card_widget.dart';
import 'package:prism_plurality/features/intro_cards/intro_models.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/media/prism_media.dart';
import 'package:prism_plurality/shared/pickers/style_pickers.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

final introTemplatesProvider = Provider<List<IntroTemplate>>((ref) {
  final custom = ref.watch(trackerKindProvider(TrackerKind.introTemplate)).value ?? const [];
  return [...builtInTemplates, for (final r in custom.reversed) IntroTemplate.fromRecord(r)];
});

/// Card record for each member that has one.
final introCardsProvider = Provider<Map<String, TrackerRecord>>((ref) {
  final rows = ref.watch(trackerKindProvider(TrackerKind.introCard)).value ?? const <TrackerRecord>[];
  return {for (final r in rows.reversed) if (r.memberId != null) r.memberId!: r};
});

IntroTemplate templateFor(TrackerRecord card, List<IntroTemplate> all) =>
    all.firstWhere((t) => t.id == card.str('template'), orElse: () => builtInTemplates.first);

class IntroCardsScreen extends ConsumerStatefulWidget {
  const IntroCardsScreen({super.key, this.showBackButton = false});
  final bool showBackButton;

  @override
  ConsumerState<IntroCardsScreen> createState() => _IntroCardsScreenState();
}

class _IntroCardsScreenState extends ConsumerState<IntroCardsScreen> {
  final _q = TextEditingController();
  bool _showHidden = false;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final members = {for (final m in ref.watch(allMembersProvider).value ?? const <Member>[]) m.id: m};
    final cards = ref.watch(introCardsProvider);
    final templates = ref.watch(introTemplatesProvider);
    final preferDisplay = ref.watch(memberNamePreferDisplayProvider);
    final q = _q.text.trim().toLowerCase();
    final shown = [
      for (final e in cards.entries)
        if (members.containsKey(e.key) &&
            (_showHidden || e.value.flag('enabled')) &&
            (q.isEmpty || members[e.key]!.name.toLowerCase().contains(q) || (e.value.str('arcana')?.toLowerCase().contains(q) ?? false)))
          e,
    ];
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(context, 'Introductions', 'Presentaciones'),
        showBackButton: widget.showBackButton,
        actions: [
          PrismTopBarAction(
            icon: PhosphorIcons.palette(),
            tooltip: tr(context, 'Card designs', 'Diseños de tarjeta'),
            onPressed: () => showTemplateManager(context),
          ),
          PrismTopBarAction(
            icon: AppIcons.add,
            tooltip: tr(context, 'New card', 'Nueva tarjeta'),
            onPressed: () => _newCard(context, members.values.toList(), cards),
          ),
        ],
      ),
      bodyPadding: EdgeInsets.zero,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: PrismTextField(
                    controller: _q,
                    hintText: tr(context, 'Search cards', 'Buscar tarjetas'),
                    prefixIcon: Icon(AppIcons.search),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                PrismChip(
                  label: tr(context, 'Show hidden', 'Ver ocultas'),
                  selected: _showHidden,
                  onTap: () => setState(() => _showHidden = !_showHidden),
                ),
              ],
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? EmptyState(
                    icon: Icon(PhosphorIcons.cards()),
                    title: tr(context, 'No introduction cards yet', 'Aún no hay tarjetas'),
                    subtitle: tr(
                      context,
                      'Cards are optional. Create one for any alter who wants to introduce themselves.',
                      'Las tarjetas son opcionales. Crea una para cualquier alter que quiera presentarse.',
                    ),
                    actionLabel: tr(context, 'Create a card', 'Crear tarjeta'),
                    onAction: () => _newCard(context, members.values.toList(), cards),
                  )
                : LayoutBuilder(
                    builder: (context, c) {
                      final cols = (c.maxWidth / 230).floor().clamp(1, 6);
                      final w = (c.maxWidth - 32 - (cols - 1) * 16) / cols;
                      return GridView.builder(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, NavBarInset.of(context) + 16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: w / (w * 1.72 + 44),
                        ),
                        itemCount: shown.length,
                        itemBuilder: (context, i) {
                          final e = shown[i];
                          final m = members[e.key]!;
                          final name = m.effectiveName(preferDisplayName: preferDisplay);
                          return Column(
                            children: [
                              Opacity(
                                opacity: e.value.flag('enabled') ? 1 : 0.45,
                                child: IntroCardView(
                                  card: e.value,
                                  member: m,
                                  template: templateFor(e.value, templates),
                                  displayName: name,
                                  width: w,
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    tooltip: tr(context, 'Open profile', 'Abrir perfil'),
                                    icon: Icon(AppIcons.personOutline, size: 20),
                                    onPressed: () => context.push(AppRoutePaths.member(m.id)),
                                  ),
                                  IconButton(
                                    tooltip: tr(context, 'Edit card', 'Editar tarjeta'),
                                    icon: Icon(AppIcons.edit, size: 20),
                                    onPressed: () => showIntroCardEditor(context, memberId: m.id),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _newCard(BuildContext context, List<Member> members, Map<String, TrackerRecord> cards) async {
    final without = [for (final m in members) if (!cards.containsKey(m.id) && m.isActive) m];
    if (without.isEmpty) {
      PrismToast.show(context, message: tr(context, 'Every alter already has a card.', 'Todos los alters ya tienen tarjeta.'));
      return;
    }
    final preferDisplay = ref.read(memberNamePreferDisplayProvider);
    final picked = await PrismSheet.show<String>(
      context: context,
      title: tr(context, 'Whose card?', '¿De quién es la tarjeta?'),
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          for (final m in without)
            PrismListRow(
              title: Text(m.effectiveName(preferDisplayName: preferDisplay)),
              leading: Text(m.emoji, style: const TextStyle(fontSize: 22)),
              onTap: () => Navigator.of(ctx).pop(m.id),
            ),
        ],
      ),
    );
    if (picked != null && context.mounted) await showIntroCardEditor(context, memberId: picked);
  }
}

/// Small entry point for alter profiles.
class MemberIntroCardTile extends ConsumerWidget {
  const MemberIntroCardTile({super.key, required this.memberId});
  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = ref.watch(introCardsProvider)[memberId];
    return PrismSurface(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      onTap: () => card != null && card.flag('enabled') ? showIntroCardPreview(context, memberId) : showIntroCardEditor(context, memberId: memberId),
      child: Row(
        children: [
          Icon(PhosphorIcons.cards(), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              card == null
                  ? tr(context, 'Create an introduction card', 'Crear tarjeta de presentación')
                  : card.flag('enabled')
                  ? tr(context, 'Introduction card', 'Tarjeta de presentación')
                  : tr(context, 'Introduction card (hidden)', 'Tarjeta de presentación (oculta)'),
            ),
          ),
          Icon(AppIcons.chevronRight, size: 18),
        ],
      ),
    );
  }
}

Future<void> showIntroCardPreview(BuildContext context, String memberId) => PrismSheet.show(
  context: context,
  builder: (ctx) => Consumer(
    builder: (ctx, ref, _) {
      final card = ref.watch(introCardsProvider)[memberId];
      final m = (ref.watch(allMembersProvider).value ?? const <Member>[]).where((x) => x.id == memberId).firstOrNull;
      if (card == null || m == null) return const SizedBox(height: 120);
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IntroCardView(
              card: card,
              member: m,
              template: templateFor(card, ref.watch(introTemplatesProvider)),
              displayName: m.effectiveName(preferDisplayName: ref.watch(memberNamePreferDisplayProvider)),
              width: 260,
            ),
            const SizedBox(height: 12),
            PrismButton(
              label: tr(ctx, 'Edit card', 'Editar tarjeta'),
              icon: AppIcons.edit,
              onPressed: () {
                Navigator.of(ctx).pop();
                showIntroCardEditor(context, memberId: memberId);
              },
            ),
          ],
        ),
      );
    },
  ),
);

Future<void> showIntroCardEditor(BuildContext context, {required String memberId}) => PrismSheet.showFullScreen(
  context: context,
  builder: (ctx, scroll) => _CardEditor(memberId: memberId, scroll: scroll),
);

class _CardEditor extends ConsumerStatefulWidget {
  const _CardEditor({required this.memberId, required this.scroll});
  final String memberId;
  final ScrollController scroll;
  @override
  ConsumerState<_CardEditor> createState() => _CardEditorState();
}

class _CardEditorState extends ConsumerState<_CardEditor> {
  TrackerRecord? _existing;
  bool _enabled = true;
  String _template = builtInTemplates.first.id;
  String? _art;
  final _arcana = TextEditingController();
  final _numeral = TextEditingController();
  final Map<String, TextEditingController> _values = {for (final f in introFields) f.key: TextEditingController()};
  final Set<String> _shown = {for (final f in introFields) f.key};
  final List<(TextEditingController, TextEditingController)> _custom = [];
  bool _init = false;
  bool _back = false;

  @override
  void dispose() {
    _arcana.dispose();
    _numeral.dispose();
    for (final c in _values.values) {
      c.dispose();
    }
    for (final (a, b) in _custom) {
      a.dispose();
      b.dispose();
    }
    super.dispose();
  }

  void _load(Member? m) {
    _init = true;
    final card = ref.read(introCardsProvider)[widget.memberId];
    _existing = card;
    if (card == null) {
      _values['pronouns']!.text = m?.pronouns ?? '';
      _values['age']!.text = m?.age ?? '';
      _values['description']!.text = m?.bio ?? '';
      _numeral.text = _roman(((m?.displayOrder ?? 0) % 21) + 1);
      return;
    }
    _enabled = card.flag('enabled');
    _template = card.str('template') ?? _template;
    _art = card.str('art');
    _arcana.text = card.str('arcana') ?? '';
    _numeral.text = card.str('numeral') ?? '';
    final values = card.fields['values'] is Map ? (card.fields['values'] as Map) : const {};
    for (final f in introFields) {
      _values[f.key]!.text = (values[f.key] as String?) ?? '';
    }
    final shown = card.strings('shown');
    if (shown.isNotEmpty) {
      _shown
        ..clear()
        ..addAll(shown);
    }
    for (final c in (card.fields['custom'] is List ? card.fields['custom'] as List : const [])) {
      if (c is Map) _custom.add((TextEditingController(text: c['label'] as String?), TextEditingController(text: c['value'] as String?)));
    }
  }

  static String _roman(int n) {
    const v = [10, 9, 5, 4, 1];
    const s = ['X', 'IX', 'V', 'IV', 'I'];
    var out = '';
    for (var i = 0; i < v.length; i++) {
      while (n >= v[i]) {
        out += s[i];
        n -= v[i];
      }
    }
    return out;
  }

  Map<String, Object?> _fields() => {
    'enabled': _enabled,
    'template': _template,
    'art': _art,
    'arcana': _arcana.text.trim().isEmpty ? null : _arcana.text.trim(),
    'numeral': _numeral.text.trim().isEmpty ? null : _numeral.text.trim(),
    'values': {for (final e in _values.entries) if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim()},
    'shown': _shown.toList(),
    'custom': [
      for (final (a, b) in _custom)
        if (a.text.trim().isNotEmpty) {'label': a.text.trim(), 'value': b.text.trim()},
    ],
  };

  @override
  Widget build(BuildContext context) {
    final m = (ref.watch(allMembersProvider).value ?? const <Member>[]).where((x) => x.id == widget.memberId).firstOrNull;
    if (!_init) _load(m);
    final templates = ref.watch(introTemplatesProvider);
    final lang = Localizations.localeOf(context).languageCode;
    final preview = TrackerRecord(
      id: 'preview',
      kind: TrackerKind.introCard,
      memberId: widget.memberId,
      createdAt: DateTime(2020),
      modifiedAt: DateTime(2020),
    ).withFields(_fields());
    final name = m?.effectiveName(preferDisplayName: ref.watch(memberNamePreferDisplayProvider)) ?? '';
    return TrackerEditorScaffold(
      title: tr(context, 'Introduction card', 'Tarjeta de presentación'),
      canSave: m != null,
      scrollController: widget.scroll,
      onSave: () async {
        final t = ref.read(trackerNotifierProvider.notifier);
        if (_existing != null) {
          await t.save(_existing!.withFields(_fields()));
        } else {
          await t.create(kind: TrackerKind.introCard, memberId: widget.memberId, title: name, fields: _fields());
        }
        if (context.mounted) Navigator.of(context).pop();
      },
      children: [
        Center(
          child: IntroCardView(
            key: ValueKey('$_back-$_template'),
            card: preview,
            member: m,
            template: templates.firstWhere((t) => t.id == _template, orElse: () => templates.first),
            displayName: name,
            width: 200,
            initiallyBack: _back,
          ),
        ),
        Center(
          child: PrismButton(
            label: _back ? tr(context, 'Show front', 'Ver frente') : tr(context, 'Show back', 'Ver reverso'),
            icon: PhosphorIcons.arrowsClockwise(),
            onPressed: () => setState(() => _back = !_back),
          ),
        ),
        PrismSwitchRow(
          title: tr(context, 'Show in the introductions gallery', 'Mostrar en la galería'),
          value: _enabled,
          onChanged: (v) => setState(() => _enabled = v),
        ),
        TrackerLabel(tr(context, 'Design', 'Diseño')),
        SizedBox(
          height: 64,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final t in templates)
                GestureDetector(
                  onTap: () => setState(() => _template = t.id),
                  child: Container(
                    width: 44,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(colors: [Color(t.bg1), Color(t.bg2)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                      border: Border.all(color: _template == t.id ? Theme.of(context).colorScheme.primary : Color(t.border), width: _template == t.id ? 3 : 1),
                    ),
                    child: Tooltip(message: t.name, child: const SizedBox.expand()),
                  ),
                ),
              IconButton(
                tooltip: tr(context, 'New design', 'Nuevo diseño'),
                icon: Icon(AppIcons.addCircleOutline),
                onPressed: () => showTemplateEditor(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TrackerLabel(tr(context, 'Artwork', 'Ilustración')),
        Wrap(
          spacing: 6,
          children: [
            PrismButton(
              label: tr(context, 'Choose image', 'Elegir imagen'),
              icon: AppIcons.imageOutlined,
              onPressed: () async {
                final id = await PrismMedia.pickImage(ref, owner: widget.memberId);
                if (id != null) setState(() => _art = id);
              },
            ),
            if (_art != null)
              PrismButton(label: tr(context, 'Use avatar', 'Usar avatar'), onPressed: () => setState(() => _art = null)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            SizedBox(width: 90, child: PrismTextField(controller: _numeral, labelText: tr(context, 'Number', 'Número'), onChanged: (_) => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(
              child: PrismTextField(
                controller: _arcana,
                labelText: tr(context, 'Card title (e.g. The Protector)', 'Título (p. ej. El Protector)'),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TrackerLabel(tr(context, 'Back of the card', 'Reverso de la tarjeta')),
        for (final f in introFields) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _shown.contains(f.key),
                onChanged: (v) => setState(() => v == true ? _shown.add(f.key) : _shown.remove(f.key)),
              ),
              Expanded(
                child: PrismTextField(
                  controller: _values[f.key],
                  labelText: lang == 'es' ? f.es : f.en,
                  maxLines: f.multiline ? 4 : 1,
                  minLines: 1,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        TrackerLabel(tr(context, 'Custom fields', 'Campos personalizados')),
        for (var i = 0; i < _custom.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(child: PrismTextField(controller: _custom[i].$1, labelText: tr(context, 'Label', 'Etiqueta'), onChanged: (_) => setState(() {}))),
                const SizedBox(width: 6),
                Expanded(flex: 2, child: PrismTextField(controller: _custom[i].$2, labelText: tr(context, 'Value', 'Valor'), onChanged: (_) => setState(() {}))),
                IconButton(
                  tooltip: tr(context, 'Remove', 'Quitar'),
                  icon: Icon(AppIcons.close),
                  onPressed: () => setState(() => _custom.removeAt(i)),
                ),
              ],
            ),
          ),
        PrismButton(
          label: tr(context, 'Add field', 'Añadir campo'),
          icon: AppIcons.add,
          onPressed: () => setState(() => _custom.add((TextEditingController(), TextEditingController()))),
        ),
        if (_existing != null) ...[
          const SizedBox(height: 16),
          PrismButton(
            label: tr(context, 'Delete card', 'Eliminar tarjeta'),
            tone: PrismButtonTone.destructive,
            icon: AppIcons.delete,
            onPressed: () async {
              final ok = await PrismDialog.confirm(
                context: context,
                title: tr(context, 'Delete this card?', '¿Eliminar esta tarjeta?'),
                message: tr(context, 'The alter’s profile is not affected.', 'El perfil del alter no se ve afectado.'),
                destructive: true,
                confirmLabel: tr(context, 'Delete', 'Eliminar'),
                cancelLabel: context.l10n.cancel,
              );
              if (!ok) return;
              await ref.read(trackerNotifierProvider.notifier).delete(_existing!.id);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ],
    );
  }
}

Future<void> showTemplateManager(BuildContext context) => PrismSheet.show(
  context: context,
  title: tr(context, 'Card designs', 'Diseños de tarjeta'),
  builder: (ctx) => Consumer(
    builder: (ctx, ref, _) {
      final templates = ref.watch(introTemplatesProvider);
      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          for (final t in templates)
            PrismListRow(
              leading: Container(
                width: 28,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: LinearGradient(colors: [Color(t.bg1), Color(t.bg2)]),
                  border: Border.all(color: Color(t.border)),
                ),
              ),
              title: Text(t.name),
              subtitle: Text(t.record == null ? tr(ctx, 'Built-in', 'Predeterminado') : tr(ctx, 'Your design', 'Tu diseño')),
              trailing: Icon(AppIcons.copy, size: 18),
              onTap: () => showTemplateEditor(ctx, base: t),
            ),
          const SizedBox(height: 8),
          PrismButton(label: tr(ctx, 'New design', 'Nuevo diseño'), icon: AppIcons.add, tone: PrismButtonTone.filled, onPressed: () => showTemplateEditor(ctx)),
        ],
      );
    },
  ),
);

/// Edits a custom design, or starts a new one from [base].
Future<void> showTemplateEditor(BuildContext context, {IntroTemplate? base}) => PrismSheet.showFullScreen(
  context: context,
  builder: (ctx, scroll) => _TemplateEditor(base: base, scroll: scroll),
);

class _TemplateEditor extends ConsumerStatefulWidget {
  const _TemplateEditor({this.base, required this.scroll});
  final IntroTemplate? base;
  final ScrollController scroll;
  @override
  ConsumerState<_TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends ConsumerState<_TemplateEditor> {
  late final IntroTemplate _b = widget.base ?? builtInTemplates.first;
  late final _name = TextEditingController(text: widget.base?.record != null ? _b.name : '${_b.name} ✦');
  late int _bg1 = _b.bg1, _bg2 = _b.bg2, _border = _b.border, _ink = _b.ink;
  late String _font = _b.font, _pattern = _b.pattern;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  IntroTemplate get _current => IntroTemplate(id: 'x', name: _name.text, bg1: _bg1, bg2: _bg2, border: _border, ink: _ink, font: _font, pattern: _pattern);

  @override
  Widget build(BuildContext context) {
    final sample = TrackerRecord(id: 's', kind: TrackerKind.introCard, createdAt: DateTime(2020), modifiedAt: DateTime(2020))
        .withFields({'arcana': tr(context, 'The Example', 'El Ejemplo'), 'numeral': 'XVII'});
    const extraColors = [0xFF1E1B3A, 0xFF3D2C6B, 0xFFD4AF37, 0xFFF6EBD0, 0xFF0F2027, 0xFF2C5364, 0xFF1D3B2A, 0xFF3A0F0F, 0xFFFFFFFF, 0xFF000000, 0xFFF4E9D0, 0xFF6B4E2E];
    final colors = [...extraColors, ...colorChoices];
    Widget pick(String label, int v, ValueChanged<int> on) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [TrackerLabel(label), ColorChoiceRow(value: v, colors: colors, onChanged: (c) => setState(() => on(c))), const SizedBox(height: 10)],
    );
    final editing = widget.base?.record;
    return TrackerEditorScaffold(
      title: tr(context, 'Card design', 'Diseño de tarjeta'),
      canSave: _name.text.trim().isNotEmpty,
      scrollController: widget.scroll,
      onSave: () async {
        final t = ref.read(trackerNotifierProvider.notifier);
        if (editing != null) {
          await t.save(editing.copyWith(title: _name.text.trim()).withFields(_current.toFields()));
        } else {
          await t.create(kind: TrackerKind.introTemplate, title: _name.text.trim(), fields: _current.toFields());
        }
        if (context.mounted) Navigator.of(context).pop();
      },
      children: [
        Center(child: IntroCardView(card: sample, member: null, template: _current, displayName: _name.text, width: 170)),
        const SizedBox(height: 12),
        PrismTextField(controller: _name, labelText: tr(context, 'Design name', 'Nombre del diseño'), onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        pick(tr(context, 'Top colour', 'Color superior'), _bg1, (c) => _bg1 = c),
        pick(tr(context, 'Bottom colour', 'Color inferior'), _bg2, (c) => _bg2 = c),
        pick(tr(context, 'Border & ornaments', 'Borde y adornos'), _border, (c) => _border = c),
        pick(tr(context, 'Text colour', 'Color del texto'), _ink, (c) => _ink = c),
        TrackerLabel(tr(context, 'Typography', 'Tipografía')),
        Wrap(
          spacing: 6,
          children: [
            for (final f in const ['serif', 'display', 'rounded', 'mono', 'standard'])
              PrismChip(label: f, selected: _font == f, onTap: () => setState(() => _font = f)),
          ],
        ),
        const SizedBox(height: 10),
        TrackerLabel(tr(context, 'Pattern', 'Patrón')),
        Wrap(
          spacing: 6,
          children: [
            for (final p in const ['stars', 'moons', 'suns', 'leaves', 'waves', 'none'])
              PrismChip(label: p, selected: _pattern == p, onTap: () => setState(() => _pattern = p)),
          ],
        ),
        if (editing != null) ...[
          const SizedBox(height: 16),
          PrismButton(
            label: tr(context, 'Delete design', 'Eliminar diseño'),
            tone: PrismButtonTone.destructive,
            icon: AppIcons.delete,
            onPressed: () async {
              await ref.read(trackerNotifierProvider.notifier).delete(editing.id);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ],
    );
  }
}
