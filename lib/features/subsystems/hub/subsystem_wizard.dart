import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/constants/fronting_namespaces.dart';
import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/subsystems/hub/cosmos.dart';
import 'package:prism_plurality/features/subsystems/hub/subsystem_data.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/widgets/member_avatar.dart';

const subsystemEmojis = ['✦', '🌙', '🌸', '🪐', '🌊', '🔥', '🌿', '🦋', '⭐', '🛡️', '🎨', '🕯️', '🌈', '❄️', '🍄', '🐾'];
const subsystemColors = [0xFFB9A6FF, 0xFFFF8FD8, 0xFF7FB6FF, 0xFF8FF0D8, 0xFFFFC37F, 0xFFFF8A8A, 0xFFE3E3FF, 0xFF9EE37F];

/// Splits role input on spaces/commas; quote multi-word roles ("Inner Self Helper").
List<String> parseRoles(String input) {
  final out = <String>[];
  final re = RegExp(r'"([^"]+)"|([^\s,]+)');
  for (final m in re.allMatches(input)) {
    final v = (m.group(1) ?? m.group(2) ?? '').trim();
    if (v.isNotEmpty && !out.contains(v)) out.add(v);
  }
  return out;
}

Future<void> showSubsystemWizard(BuildContext context, {String? parentId}) async {
  final router = GoRouter.of(context);
  final created = await PrismSheet.showFullScreen<String>(
    context: context,
    builder: (ctx, scroll) => CosmicScope(child: SubsystemWizard(scroll: scroll, parentId: parentId)),
  );
  if (created != null) router.push('${AppRoutePaths.subsystems}/$created');
}

class _Pick {
  _Pick(this.id);
  final String id;
  List<String> roles = [];
  Set<String> perms = {'post', 'journal'};
}

class SubsystemWizard extends ConsumerStatefulWidget {
  const SubsystemWizard({super.key, this.scroll, this.parentId});
  final ScrollController? scroll;
  final String? parentId;
  @override
  ConsumerState<SubsystemWizard> createState() => _SubsystemWizardState();
}

class _SubsystemWizardState extends ConsumerState<SubsystemWizard> {
  int _step = 0;
  String? _founder;
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _search = TextEditingController();
  final _tags = TextEditingController();
  String _emoji = '✦';
  int _color = subsystemColors.first;
  int _color2 = subsystemColors[1];
  final _picks = <String, _Pick>{};
  bool _isolate = true;
  bool _coFront = true;
  bool _notify = false;
  bool _chat = true;
  bool _journal = true;
  String _visibility = 'system';
  String? _parent;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _parent = widget.parentId;
  }

  @override
  void dispose() {
    for (final c in [_name, _desc, _search, _tags]) {
      c.dispose();
    }
    super.dispose();
  }

  List<Member> _members() => [for (final m in ref.watch(allMemberListProvider).value ?? const <Member>[]) if (m.id != unknownSentinelMemberId) m];

  bool get _canNext => switch (_step) {
    0 => _founder != null && _name.text.trim().isNotEmpty,
    _ => true,
  };

  Future<void> _create() async {
    setState(() => _busy = true);
    final s = await ref.read(subsystemActionsProvider).create(
      name: _name.text.trim(),
      founderId: _founder!,
      emoji: _emoji,
      description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      color: _color,
      color2: _color2,
      parentId: _parent,
      tags: parseRoles(_tags.text),
      settings: {'isolate': _isolate, 'coFronting': _coFront, 'notifyFronting': _notify, 'chat': _chat, 'separateJournal': _journal, 'visibility': _visibility},
      members: [for (final p in _picks.values) (p.id, p.roles, p.perms)],
    );
    if (mounted) Navigator.of(context).pop(s.id);
  }

  @override
  Widget build(BuildContext context) {
    final steps = [tr(context, 'Founder', 'Fundador'), tr(context, 'Members', 'Miembros'), tr(context, 'Settings', 'Ajustes'), tr(context, 'Review', 'Revisar')];
    return ColoredBox(
      color: Cosmos.black,
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _StaticSky())),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr(context, 'Step ${_step + 1} of 4', 'Paso ${_step + 1} de 4'), style: const TextStyle(color: Cosmos.faint, fontSize: 12, letterSpacing: 1.2)),
                          Text(steps[_step], style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: Colors.white)),
                        ],
                      ),
                    ),
                    PrismTopBarAction(icon: AppIcons.close, tooltip: context.mounted ? tr(context, 'Close', 'Cerrar') : '', onPressed: () => Navigator.of(context).pop()),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    for (var i = 0; i < 4; i++)
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          height: 4,
                          margin: EdgeInsets.only(right: i == 3 ? 0 : 6),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), gradient: i <= _step ? Cosmos.glow : null, color: i <= _step ? null : Cosmos.line),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: ListView(
                      controller: widget.scroll,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: switch (_step) {
                        0 => _identity(context),
                        1 => _membersStep(context),
                        2 => _settings(context),
                        _ => _review(context),
                      },
                    ),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      if (_step > 0) PrismButton(label: tr(context, 'Back', 'Atrás'), icon: PhosphorIcons.arrowLeft(), onPressed: () => setState(() => _step--)),
                      const Spacer(),
                      if (_step < 3)
                        GlowButton(label: tr(context, 'Next', 'Siguiente'), icon: PhosphorIcons.arrowRight(), onPressed: _canNext ? () => setState(() => _step++) : null)
                      else
                        GlowButton(label: _busy ? '…' : tr(context, 'Create subsystem', 'Crear subsistema'), icon: PhosphorIcons.sparkle(), onPressed: _busy ? null : _create),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _avatar(Member m, {double size = 36}) {
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    return MemberAvatar(avatarImageData: m.avatarImageData, memberName: m.effectiveName(preferDisplayName: prefer), emoji: m.emoji, customColorEnabled: m.customColorEnabled, customColorHex: m.customColorHex, size: size);
  }

  List<Widget> _identity(BuildContext context) {
    final members = _members();
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    final q = _search.text.trim().toLowerCase();
    final shown = [for (final m in members) if (q.isEmpty || m.effectiveName(preferDisplayName: prefer).toLowerCase().contains(q)) m];
    return [
      Center(child: SubOrb(emoji: _emoji, color: Color(_color), color2: Color(_color2), size: 84)),
      const SizedBox(height: 18),
      CosmicHeading(tr(context, 'Founding alter', 'Alter fundador')),
      Text(tr(context, 'The founder becomes the subsystem’s first member.', 'El fundador será el primer miembro del subsistema.'), style: const TextStyle(color: Cosmos.dim)),
      const SizedBox(height: 10),
      if (members.length > 8) ...[PrismTextField(controller: _search, hintText: tr(context, 'Search alters', 'Buscar alters'), prefixIcon: Icon(AppIcons.search), onChanged: (_) => setState(() {})), const SizedBox(height: 10)],
      if (members.isEmpty)
        Text(tr(context, 'Add an alter in Headmates first.', 'Añade primero un alter en Headmates.'), style: const TextStyle(color: Cosmos.dim))
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in shown)
              PrismChip(
                avatar: _avatar(m, size: 22),
                label: m.effectiveName(preferDisplayName: prefer),
                selected: _founder == m.id,
                onTap: () => setState(() {
                  _founder = m.id;
                  _picks.remove(m.id);
                }),
              ),
          ],
        ),
      CosmicHeading(tr(context, 'Identity', 'Identidad'), color: Cosmos.pink),
      PrismTextField(controller: _name, labelText: tr(context, 'Name', 'Nombre'), onChanged: (_) => setState(() {}), textCapitalization: TextCapitalization.words),
      const SizedBox(height: 10),
      PrismTextField(controller: _desc, labelText: tr(context, 'Description', 'Descripción'), minLines: 2, maxLines: 4),
      const SizedBox(height: 14),
      TrackerLabel(tr(context, 'Icon', 'Icono')),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final e in subsystemEmojis)
            GestureDetector(
              onTap: () => setState(() => _emoji = e),
              child: Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: _emoji == e ? Color(_color).withValues(alpha: 0.25) : Cosmos.panel, border: Border.all(color: _emoji == e ? Color(_color) : Cosmos.line)),
                child: Text(e, style: const TextStyle(fontSize: 20)),
              ),
            ),
        ],
      ),
      const SizedBox(height: 14),
      TrackerLabel(tr(context, 'Main colour', 'Color principal')),
      ColorChoiceRow(value: _color, colors: subsystemColors, onChanged: (v) => setState(() => _color = v)),
      const SizedBox(height: 10),
      TrackerLabel(tr(context, 'Glow colour', 'Color de brillo')),
      ColorChoiceRow(value: _color2, colors: subsystemColors, onChanged: (v) => setState(() => _color2 = v)),
    ];
  }

  List<Widget> _membersStep(BuildContext context) {
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    final q = _search.text.trim().toLowerCase();
    final members = [for (final m in _members()) if (m.id != _founder && (q.isEmpty || m.effectiveName(preferDisplayName: prefer).toLowerCase().contains(q))) m];
    return [
      Text(
        tr(context, 'Pick who belongs here. Alters can belong to more than one subsystem — they are never copied, and their main profile stays the same.', 'Elige quién pertenece aquí. Un alter puede estar en varios subsistemas: nunca se copia y su perfil principal no cambia.'),
        style: const TextStyle(color: Cosmos.dim, height: 1.4),
      ),
      const SizedBox(height: 12),
      PrismTextField(controller: _search, hintText: tr(context, 'Search alters', 'Buscar alters'), prefixIcon: Icon(AppIcons.search), onChanged: (_) => setState(() {})),
      const SizedBox(height: 8),
      if (_picks.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(tr(context, '${_picks.length} selected', '${_picks.length} seleccionados'), style: const TextStyle(color: Cosmos.pink, fontWeight: FontWeight.w700))),
      for (final m in members) Padding(padding: const EdgeInsets.only(bottom: 8), child: _memberPick(context, m)),
      if (members.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(tr(context, 'No other alters match.', 'Ningún otro alter coincide.'), style: const TextStyle(color: Cosmos.dim))),
    ];
  }

  Widget _memberPick(BuildContext context, Member m) {
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    final p = _picks[m.id];
    return CosmicPanel(
      accent: p != null ? Color(_color) : Cosmos.line,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      onTap: () => setState(() => p == null ? _picks[m.id] = _Pick(m.id) : _picks.remove(m.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatar(m),
              const SizedBox(width: 12),
              Expanded(child: Text(m.effectiveName(preferDisplayName: prefer), style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white))),
              Icon(p != null ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill) : PhosphorIcons.circle(), color: p != null ? Color(_color) : Cosmos.faint),
            ],
          ),
          if (p != null) ...[
            const SizedBox(height: 10),
            PrismTextField(
              initialValue: p.roles.map((r) => r.contains(' ') ? '"$r"' : r).join(' '),
              hintText: tr(context, 'Subsystem roles (space-separated)', 'Roles en el subsistema (separados por espacios)'),
              onChanged: (v) => p.roles = parseRoles(v),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (key, en, es) in subsystemPermissions)
                  PrismChip(label: tr(context, en, es), selected: p.perms.contains(key), onTap: () => setState(() => p.perms.contains(key) ? p.perms.remove(key) : p.perms.add(key))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _settings(BuildContext context) {
    final subs = ref.watch(subsystemsProvider);
    return [
      CosmicHeading(tr(context, 'Privacy', 'Privacidad'), color: Cosmos.blue),
      PrismSwitchRow(
        title: tr(context, 'Member isolation', 'Aislamiento de miembros'),
        subtitle: tr(context, 'Members only appear inside this subsystem, not in Headmates or system-wide lists.', 'Los miembros solo aparecen dentro de este subsistema, no en Headmates ni listas del sistema.'),
        value: _isolate,
        onChanged: (v) => setState(() => _isolate = v),
      ),
      const SizedBox(height: 8),
      PrismSegmentedControl<String>(
        segments: [PrismSegment(value: 'system', label: tr(context, 'Whole system', 'Todo el sistema')), PrismSegment(value: 'members', label: tr(context, 'Members only', 'Solo miembros'))],
        selected: _visibility,
        onChanged: (v) => setState(() => _visibility = v),
      ),
      CosmicHeading(tr(context, 'Fronting', 'Frente')),
      PrismSwitchRow(title: tr(context, 'Allow co-fronting', 'Permitir co-frente'), value: _coFront, onChanged: (v) => setState(() => _coFront = v)),
      PrismSwitchRow(title: tr(context, 'Notify when a member fronts', 'Avisar cuando un miembro esté al frente'), value: _notify, onChanged: (v) => setState(() => _notify = v)),
      CosmicHeading(tr(context, 'Communication & data', 'Comunicación y datos'), color: Cosmos.pink),
      PrismSwitchRow(title: tr(context, 'Internal chat & announcements', 'Chat interno y anuncios'), value: _chat, onChanged: (v) => setState(() => _chat = v)),
      PrismSwitchRow(title: tr(context, 'Separate journal & notes', 'Diario y notas propios'), value: _journal, onChanged: (v) => setState(() => _journal = v)),
      CosmicHeading(tr(context, 'Structure', 'Estructura'), color: Cosmos.blue),
      Text(tr(context, 'Nest inside another subsystem', 'Anidar dentro de otro subsistema'), style: const TextStyle(color: Cosmos.dim)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          PrismChip(label: tr(context, 'Top level', 'Nivel superior'), selected: _parent == null, onTap: () => setState(() => _parent = null)),
          for (final s in subs) PrismChip(label: '${subEmoji(s)} ${s.title}', selected: _parent == s.id, onTap: () => setState(() => _parent = s.id)),
        ],
      ),
      const SizedBox(height: 14),
      PrismTextField(controller: _tags, labelText: tr(context, 'Tags (space-separated)', 'Etiquetas (separadas por espacios)')),
    ];
  }

  List<Widget> _review(BuildContext context) {
    final index = ref.watch(memberIndexProvider);
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    final founder = index[_founder];
    return [
      CosmicPanel(
        accent: Color(_color),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            SubOrb(emoji: _emoji, color: Color(_color), color2: Color(_color2), size: 72),
            const SizedBox(height: 12),
            Text(_name.text.trim(), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: Colors.white)),
            if (_desc.text.trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_desc.text.trim(), textAlign: TextAlign.center, style: const TextStyle(color: Cosmos.dim))),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                if (founder != null) GlowPill('👑 ${founder.effectiveName(preferDisplayName: prefer)}', color: Cosmos.pink),
                for (final p in _picks.values)
                  if (index[p.id] != null) GlowPill(index[p.id]!.effectiveName(preferDisplayName: prefer), color: Color(_color)),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                if (_isolate) GlowPill(tr(context, 'Isolated', 'Aislado'), icon: PhosphorIcons.lockSimple(), color: Cosmos.blue),
                if (_coFront) GlowPill(tr(context, 'Co-fronting', 'Co-frente'), color: Cosmos.lavender),
                if (_chat) GlowPill(tr(context, 'Chat', 'Chat'), color: Cosmos.pink),
                if (_journal) GlowPill(tr(context, 'Own journal', 'Diario propio'), color: Cosmos.blue),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Text(
        tr(context, 'You can change everything later in the subsystem’s settings.', 'Puedes cambiarlo todo después en los ajustes del subsistema.'),
        textAlign: TextAlign.center,
        style: const TextStyle(color: Cosmos.faint),
      ),
    ];
  }
}

class _StaticSky extends CustomPainter {
  const _StaticSky();
  @override
  void paint(Canvas canvas, Size size) => CosmosPainter().paint(canvas, size);
  @override
  bool shouldRepaint(_StaticSky oldDelegate) => false;
}
