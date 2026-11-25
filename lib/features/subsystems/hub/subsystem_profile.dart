import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/features/experiences/color_sheet.dart';
import 'package:prism_plurality/core/features/feature_state.dart';
import 'package:prism_plurality/core/constants/fronting_namespaces.dart';
import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/core/services/local_notification_service.dart';
import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/fronting/providers/fronting_providers.dart';
import 'package:prism_plurality/features/links/models/record_ref.dart';
import 'package:prism_plurality/features/links/widgets/related_records.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/relationships/utils/relationships.dart';
import 'package:prism_plurality/features/relationships/views/relationship_editor.dart';
import 'package:prism_plurality/features/relationships/views/relationship_labels.dart';
import 'package:prism_plurality/features/subsystems/hub/cosmos.dart';
import 'package:prism_plurality/features/subsystems/hub/subsystem_data.dart';
import 'package:prism_plurality/features/subsystems/hub/subsystem_wizard.dart';
import 'package:prism_plurality/features/subsystems/utils/subsystems.dart';
import 'package:prism_plurality/features/subsystems/views/subsystems_screen.dart'
    show subsystemFrontingProvider;
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/notify.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/widgets/member_avatar.dart';

enum SubTab {
  overview,
  members,
  relationships,
  fronting,
  journal,
  notes,
  groups,
  rules,
  connections,
  chat,
  settings,
}

/// A subsystem's own mini-dashboard.
class SubsystemProfileScreen extends ConsumerStatefulWidget {
  const SubsystemProfileScreen({
    super.key,
    required this.id,
    this.initial = SubTab.overview,
  });
  final String id;
  final SubTab initial;
  @override
  ConsumerState<SubsystemProfileScreen> createState() =>
      _SubsystemProfileScreenState();
}

class _SubsystemProfileScreenState
    extends ConsumerState<SubsystemProfileScreen> {
  late SubTab _tab = widget.initial;

  String _label(BuildContext c, SubTab t) => switch (t) {
    SubTab.overview => tr(c, 'Overview', 'Resumen'),
    SubTab.members => tr(c, 'Members', 'Miembros'),
    SubTab.relationships => tr(c, 'Relationships', 'Relaciones'),
    SubTab.fronting => tr(c, 'Fronting', 'Frente'),
    SubTab.journal => tr(c, 'Journal', 'Diario'),
    SubTab.notes => tr(c, 'Notes', 'Notas'),
    SubTab.groups => tr(c, 'Groups', 'Grupos'),
    SubTab.rules => tr(c, 'Rules', 'Normas'),
    SubTab.connections => tr(c, 'Connections', 'Conexiones'),
    SubTab.chat => tr(c, 'Chat', 'Chat'),
    SubTab.settings => tr(c, 'Settings', 'Ajustes'),
  };

  @override
  Widget build(BuildContext context) {
    final s = ref
        .watch(subsystemsProvider)
        .where((x) => x.id == widget.id)
        .firstOrNull;
    if (s == null) {
      return CosmicScope(
        child: PrismPageScaffold(
          topBar: PrismTopBar(
            title: tr(context, 'Subsystem', 'Subsistema'),
            showBackButton: true,
          ),
          body: Center(
            child: Text(
              tr(
                context,
                'This subsystem isn’t available.',
                'Este subsistema no está disponible.',
              ),
              style: TextStyle(color: context.sp.dim),
            ),
          ),
        ),
      );
    }
    final set = SubSettings(s);
    final tabs = [
      for (final t in SubTab.values)
        if (!(t == SubTab.chat && !set.chat) &&
            !((t == SubTab.journal || t == SubTab.notes) &&
                !set.separateJournal))
          t,
    ];
    final tab = tabs.contains(_tab) ? _tab : SubTab.overview;
    final color = subColor(s);
    final ctx = SubCtx(
      s,
      ref
          .watch(subMembershipsProvider)
          .where((m) => m.subsystemId == s.id)
          .toList(),
      ref.watch(memberIndexProvider),
    );

    return CosmicScope(
      accent: color,
      child: Builder(
        builder: (context) => PrismPageScaffold(
          topBar: PrismTopBar(
            title: s.title,
            showBackButton: true,
            actions: [
              PrismTopBarAction(
                icon: AppIcons.navSettings,
                tooltip: tr(context, 'Settings', 'Ajustes'),
                onPressed: () => setState(() => _tab = SubTab.settings),
              ),
            ],
          ),
          bodyPadding: EdgeInsets.zero,
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _Hero(c: ctx)),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    height: 52,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      children: [
                        for (final t in tabs)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _TabPill(
                              label: _label(context, t),
                              selected: t == tab,
                              color: color,
                              onTap: () => setState(() => _tab = t),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  NavBarInset.of(context) + 32,
                ),
                sliver: SliverToBoxAdapter(
                  child: ClampedBody(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: KeyedSubtree(
                        key: ValueKey(tab),
                        child: switch (tab) {
                          SubTab.overview => _Overview(
                            c: ctx,
                            go: (t) => setState(() => _tab = t),
                          ),
                          SubTab.members => _Members(c: ctx),
                          SubTab.relationships => _Relationships(c: ctx),
                          SubTab.fronting => _Fronting(c: ctx),
                          SubTab.journal => _Entries(
                            c: ctx,
                            kind: TrackerKind.subJournal,
                          ),
                          SubTab.notes => _Entries(
                            c: ctx,
                            kind: TrackerKind.subNote,
                          ),
                          SubTab.groups => _Groups(c: ctx),
                          SubTab.rules => _Rules(c: ctx),
                          SubTab.connections => _Connections(c: ctx),
                          SubTab.chat => _Chat(c: ctx),
                          SubTab.settings => _Settings(c: ctx),
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What every section needs: the subsystem, its memberships and members.
class SubCtx {
  SubCtx(this.s, this.memberships, this.index);
  final TrackerRecord s;
  final List<SubMembership> memberships;
  final Map<String, Member> index;
  Color get color => subColor(s);
  SubSettings get settings => SubSettings(s);
  Set<String> get ids => {for (final m in memberships) m.memberId};
  List<Member> get members => [for (final m in memberships) ?index[m.memberId]];
  SubMembership? of(String memberId) =>
      memberships.where((m) => m.memberId == memberId).firstOrNull;
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate({required this.child});
  final Widget child;
  @override
  double get minExtent => 52;
  @override
  double get maxExtent => 52;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child;
  @override
  bool shouldRebuild(_TabBarDelegate old) => true;
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) =>
      PrismChip(label: label, selected: selected, onTap: onTap);
}

Widget memberAvatar(WidgetRef ref, Member m, {double size = 36}) {
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

String memberName(WidgetRef ref, Member? m) => m == null
    ? '—'
    : m.effectiveName(
        preferDisplayName: ref.watch(memberNamePreferDisplayProvider),
      );

class _Hero extends ConsumerWidget {
  const _Hero({required this.c});
  final SubCtx c;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = c.s;
    final set = c.settings;
    final founder = c.index[set.founderId] ?? c.members.firstOrNull;
    final parent = ref
        .watch(subsystemsProvider)
        .where((x) => x.id == s.parentId)
        .firstOrNull;
    final style = s.str('bannerStyle') ?? 'nebula';
    return SizedBox(
      height: 250,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: switch (style) {
                  'aurora' => [
                    c.color.withValues(alpha: 0.24),
                    subColor2(s).withValues(alpha: 0.12),
                    context.sp.bg,
                  ],
                  'eclipse' => [context.sp.panel, context.sp.bg],
                  _ => [c.color.withValues(alpha: 0.18), context.sp.bg],
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SubOrb(
                  emoji: subEmoji(s),
                  color: c.color,
                  color2: subColor2(s),
                  size: 76,
                ),
                const SizedBox(height: 12),
                Text(
                  s.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.sp.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (founder != null)
                      tr(
                        context,
                        'Founded by ${memberName(ref, founder)}',
                        'Fundado por ${memberName(ref, founder)}',
                      ),
                    tr(
                      context,
                      '${c.memberships.length} members',
                      '${c.memberships.length} miembros',
                    ),
                    if (parent != null)
                      tr(context, 'in ${parent.title}', 'en ${parent.title}'),
                  ].join(' · '),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.sp.dim, fontSize: 13),
                ),
                if (s.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final t in s.tags) GlowPill('#$t', color: c.color),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Overview ─────────────────────────

class _Overview extends ConsumerWidget {
  const _Overview({required this.c, required this.go});
  final SubCtx c;
  final ValueChanged<SubTab> go;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = c.s;
    final active =
        ref.watch(activeSessionsProvider).value ?? const <FrontingSession>[];
    final fronting = [
      for (final f in active)
        if (f.memberId != null && c.ids.contains(f.memberId) && !f.isSleep)
          ?c.index[f.memberId],
    ];
    final announcements =
        (ref.watch(trackerKindProvider(TrackerKind.subMessage)).value ??
                const <TrackerRecord>[])
            .where((m) => m.parentId == s.id && m.flag('announce'))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final nested = ref
        .watch(subsystemsProvider)
        .where((x) => x.parentId == s.id)
        .toList();
    final rules =
        (ref.watch(trackerKindProvider(TrackerKind.subRule)).value ??
                const <TrackerRecord>[])
            .where((r) => r.parentId == s.id)
            .take(3)
            .toList();
    final about = [
      (s.body ?? '').trim(),
      (s.str(SubField.purpose) ?? '').trim(),
      (s.str(SubField.origin) ?? '').trim(),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CosmicHeading(
          tr(context, 'Fronting now', 'Al frente ahora'),
          color: context.sp.secondary,
        ),
        if (fronting.isEmpty)
          Text(
            tr(
              context,
              'No one from this subsystem is fronting.',
              'Nadie de este subsistema está al frente.',
            ),
            style: TextStyle(color: context.sp.dim),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final m in fronting)
                CosmicPanel(
                  accent: context.sp.secondary,
                  padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
                  radius: 999,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      memberAvatar(ref, m, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        memberName(ref, m),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        if (about.any((x) => x.isNotEmpty)) ...[
          CosmicHeading(tr(context, 'About', 'Acerca de')),
          CosmicPanel(
            accent: c.color,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (about[0].isNotEmpty)
                  Text(about[0], style: const TextStyle(height: 1.5)),
                if (about[1].isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    tr(context, 'Purpose', 'Propósito'),
                    style: TextStyle(color: context.sp.faint, fontSize: 12),
                  ),
                  Text(about[1]),
                ],
                if (about[2].isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    tr(context, 'Origin', 'Origen'),
                    style: TextStyle(color: context.sp.faint, fontSize: 12),
                  ),
                  Text(about[2]),
                ],
              ],
            ),
          ),
        ],
        if (announcements.isNotEmpty) ...[
          CosmicHeading(
            tr(context, 'Latest announcement', 'Último anuncio'),
            color: context.sp.tertiary,
          ),
          _MessageCard(c: c, m: announcements.first),
        ],
        CosmicHeading(
          tr(context, 'Members', 'Miembros'),
          trailing: _Link(
            tr(context, 'See all', 'Ver todos'),
            () => go(SubTab.members),
          ),
        ),
        SizedBox(
          height: 84,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final mm in c.memberships)
                if (c.index[mm.memberId] case final m?)
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: SizedBox(
                      width: 62,
                      child: Column(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              memberAvatar(ref, m, size: 48),
                              if (mm.founder)
                                const Positioned(
                                  right: -4,
                                  top: -6,
                                  child: Text(
                                    '👑',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            memberName(ref, m),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: context.sp.dim,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        ),
        if (rules.isNotEmpty) ...[
          CosmicHeading(
            tr(context, 'Rules & boundaries', 'Normas y límites'),
            color: context.sp.secondary,
            trailing: _Link(
              tr(context, 'All', 'Todas'),
              () => go(SubTab.rules),
            ),
          ),
          for (final r in rules)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('✦  ', style: TextStyle(color: c.color)),
                  Expanded(
                    child: Text(r.title, style: const TextStyle(height: 1.4)),
                  ),
                ],
              ),
            ),
        ],
        if (nested.isNotEmpty) ...[
          CosmicHeading(
            tr(context, 'Nested subsystems', 'Subsistemas anidados'),
            color: context.sp.tertiary,
          ),
          for (final n in nested)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CosmicPanel(
                accent: subColor(n),
                padding: const EdgeInsets.all(12),
                onTap: () =>
                    context.push('${AppRoutePaths.subsystems}/${n.id}'),
                child: Row(
                  children: [
                    SubOrb(emoji: subEmoji(n), color: subColor(n), size: 34),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        n.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Icon(
                      PhosphorIcons.caretRight(),
                      size: 16,
                      color: context.sp.faint,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _Link extends StatelessWidget {
  const _Link(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Text(
      label,
      style: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    ),
  );
}

// ───────────────────────── Members ─────────────────────────

class _Members extends ConsumerWidget {
  const _Members({required this.c});
  final SubCtx c;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                c.settings.isolate
                    ? tr(
                        context,
                        'These members are private to this subsystem.',
                        'Estos miembros son privados de este subsistema.',
                      )
                    : tr(
                        context,
                        'These members also appear in Headmates.',
                        'Estos miembros también aparecen en Headmates.',
                      ),
                style: TextStyle(color: context.sp.dim, fontSize: 13),
              ),
            ),
            GlowButton(
              label: tr(context, 'Add', 'Añadir'),
              icon: AppIcons.add,
              onPressed: () => showAddSubMembers(context, c),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final mm in c.memberships)
          if (c.index[mm.memberId] case final m?)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CosmicPanel(
                accent: mm.founder ? context.sp.secondary : c.color,
                padding: const EdgeInsets.all(12),
                onTap: () => _editMembership(context, ref, c, mm),
                child: Row(
                  children: [
                    memberAvatar(ref, m, size: 42),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  memberName(ref, m),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              if (mm.founder) const Text('  👑'),
                            ],
                          ),
                          if (mm.roles.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                for (final r in mm.roles)
                                  GlowPill(r, color: c.color),
                              ],
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            tr(
                              context,
                              'Joined ${DateFormat.yMMMd(context.dateLocale).format(mm.joined)}',
                              'Se unió el ${DateFormat.yMMMd(context.dateLocale).format(mm.joined)}',
                            ),
                            style: TextStyle(
                              color: context.sp.faint,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (mm.permissions.contains('manage'))
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Icon(
                          PhosphorIcons.shieldCheck(),
                          size: 16,
                          color: context.sp.tertiary,
                        ),
                      ),
                    Icon(
                      PhosphorIcons.caretRight(),
                      size: 16,
                      color: context.sp.faint,
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

Future<void> _editMembership(
  BuildContext context,
  WidgetRef ref,
  SubCtx c,
  SubMembership mm,
) async {
  final m = c.index[mm.memberId];
  if (m == null) return;
  final roles = TextEditingController(
    text: mm.roles.map((r) => r.contains(' ') ? '"$r"' : r).join(' '),
  );
  final perms = {...mm.permissions};
  final router = GoRouter.of(context);
  await PrismSheet.show(
    context: context,
    title: memberName(ref, m),
    builder: (ctx) => CosmicScope(
      accent: c.color,
      child: StatefulBuilder(
        builder: (ctx, set) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PrismTextField(
                controller: roles,
                labelText: tr(ctx, 'Subsystem roles', 'Roles en el subsistema'),
                helperText: tr(
                  ctx,
                  'Separate with spaces; use quotes for "multi word" roles.',
                  'Sepáralos con espacios; usa comillas para roles de "varias palabras".',
                ),
              ),
              const SizedBox(height: 12),
              TrackerLabel(tr(ctx, 'Permissions', 'Permisos')),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final (k, en, es) in subsystemPermissions)
                    PrismChip(
                      label: tr(ctx, en, es),
                      selected: perms.contains(k),
                      onTap: () => set(
                        () =>
                            perms.contains(k) ? perms.remove(k) : perms.add(k),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PrismButton(
                    label: tr(
                      ctx,
                      'Open main profile',
                      'Abrir perfil principal',
                    ),
                    icon: PhosphorIcons.userCircle(),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      router.push(AppRoutePaths.member(m.id));
                    },
                  ),
                  if (!mm.founder)
                    PrismButton(
                      label: tr(
                        ctx,
                        'Remove from subsystem',
                        'Quitar del subsistema',
                      ),
                      tone: PrismButtonTone.destructive,
                      icon: AppIcons.delete,
                      onPressed: () async {
                        await ref
                            .read(subsystemActionsProvider)
                            .removeMember(mm);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                    ),
                  PrismButton(
                    label: ctx.l10n.save,
                    tone: PrismButtonTone.filled,
                    onPressed: () async {
                      await ref
                          .read(subsystemActionsProvider)
                          .updateMember(
                            mm,
                            roles: parseRoles(roles.text),
                            perms: perms,
                          );
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> showAddSubMembers(BuildContext context, SubCtx c) =>
    PrismSheet.showFullScreen(
      context: context,
      builder: (ctx, scroll) => CosmicScope(
        accent: c.color,
        child: _AddMembers(c: c, scroll: scroll),
      ),
    );

class _AddMembers extends ConsumerStatefulWidget {
  const _AddMembers({required this.c, required this.scroll});
  final SubCtx c;
  final ScrollController scroll;
  @override
  ConsumerState<_AddMembers> createState() => _AddMembersState();
}

class _AddMembersState extends ConsumerState<_AddMembers> {
  final _q = TextEditingController();
  final _sel = <String>{};
  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.text.trim().toLowerCase();
    final all =
        ref
            .watch(memberIndexProvider)
            .values
            .where(
              (m) =>
                  !widget.c.ids.contains(m.id) &&
                  m.id != unknownSentinelMemberId,
            )
            .toList()
          ..sort((a, b) => memberName(ref, a).compareTo(memberName(ref, b)));
    final shown = [
      for (final m in all)
        if (q.isEmpty || memberName(ref, m).toLowerCase().contains(q)) m,
    ];
    return ColoredBox(
      color: Colors.transparent,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    tr(context, 'Add members', 'Añadir miembros'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: PrismTextField(
              controller: _q,
              hintText: tr(context, 'Search alters', 'Buscar alters'),
              prefixIcon: Icon(AppIcons.search),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: ListView(
              controller: widget.scroll,
              padding: const EdgeInsets.all(16),
              children: [
                for (final m in shown)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: CosmicPanel(
                      accent: _sel.contains(m.id)
                          ? widget.c.color
                          : context.sp.line,
                      padding: const EdgeInsets.all(10),
                      onTap: () => setState(
                        () => _sel.contains(m.id)
                            ? _sel.remove(m.id)
                            : _sel.add(m.id),
                      ),
                      child: Row(
                        children: [
                          memberAvatar(ref, m),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              memberName(ref, m),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(
                            _sel.contains(m.id)
                                ? PhosphorIcons.checkCircle(
                                    PhosphorIconsStyle.fill,
                                  )
                                : PhosphorIcons.circle(),
                            color: _sel.contains(m.id)
                                ? widget.c.color
                                : context.sp.faint,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GlowButton(
                label: tr(
                  context,
                  'Add ${_sel.length}',
                  'Añadir ${_sel.length}',
                ),
                icon: AppIcons.add,
                onPressed: _sel.isEmpty
                    ? null
                    : () async {
                        for (final id in _sel) {
                          await ref
                              .read(subsystemActionsProvider)
                              .addMember(widget.c.s.id, id);
                        }
                        if (context.mounted) Navigator.of(context).pop();
                      },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Relationships ─────────────────────────

class _Relationships extends ConsumerWidget {
  const _Relationships({required this.c});
  final SubCtx c;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all =
        ref.watch(trackerKindProvider(TrackerKind.relationship)).value ??
        const <TrackerRecord>[];
    final rels = [
      for (final r in all)
        if (isInternal(r) &&
            memberEnds(r).length == 2 &&
            c.ids.containsAll(memberEnds(r)))
          r,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                tr(
                  context,
                  'Relationships between this subsystem’s members.',
                  'Relaciones entre los miembros de este subsistema.',
                ),
                style: TextStyle(color: context.sp.dim, fontSize: 13),
              ),
            ),
            GlowButton(
              label: tr(context, 'Add', 'Añadir'),
              icon: AppIcons.add,
              onPressed: c.members.isEmpty
                  ? null
                  : () => showRelationshipEditor(
                      context,
                      memberId: c.members.first.id,
                    ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (rels.isEmpty)
          _Empty(
            tr(
              context,
              'No internal relationships yet.',
              'Aún no hay relaciones internas.',
            ),
          ),
        for (final r in rels)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: CosmicPanel(
              accent: c.color,
              padding: const EdgeInsets.all(12),
              onTap: () => showRelationshipEditor(context, editing: r),
              child: Row(
                children: [
                  if (c.index[r.memberId] case final a?)
                    memberAvatar(ref, a, size: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      PhosphorIcons.arrowsLeftRight(),
                      size: 16,
                      color: c.color,
                    ),
                  ),
                  if (c.index[r.str(RelField.otherId)] case final b?)
                    memberAvatar(ref, b, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${memberName(ref, c.index[r.memberId])} & ${memberName(ref, c.index[r.str(RelField.otherId)])}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          relTypeLabel(
                            context.l10n,
                            r.str(RelField.type) ?? 'other',
                          ),
                          style: TextStyle(
                            color: context.sp.dim,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(color: context.sp.faint),
    ),
  );
}

// ───────────────────────── Fronting ─────────────────────────

class _Fronting extends ConsumerWidget {
  const _Fronting({required this.c});
  final SubCtx c;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = [
      for (final f
          in ref.watch(subsystemFrontingProvider).value ??
              const <FrontingSession>[])
        if (f.memberId != null && c.ids.contains(f.memberId) && !f.isSleep) f,
    ]..sort((a, b) => b.startTime.compareTo(a.startTime));
    final share = <String, Duration>{};
    for (final f in sessions) {
      share[f.memberId!] = (share[f.memberId!] ?? Duration.zero) + f.duration;
    }
    final total = share.values.fold(Duration.zero, (a, b) => a + b);
    final ranked = share.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final df = DateFormat.MMMd(context.dateLocale).add_jm();
    String dur(Duration d) => d.inHours > 0
        ? '${d.inHours}h ${d.inMinutes % 60}m'
        : '${d.inMinutes}m';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CosmicHeading(
          tr(context, 'Last 30 days', 'Últimos 30 días'),
          color: context.sp.secondary,
        ),
        if (ranked.isEmpty)
          _Empty(
            tr(
              context,
              'No fronting from this subsystem in the last 30 days.',
              'Sin frente de este subsistema en los últimos 30 días.',
            ),
          ),
        for (final e in ranked)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                if (c.index[e.key] case final m?)
                  memberAvatar(ref, m, size: 28),
                const SizedBox(width: 10),
                SizedBox(
                  width: 90,
                  child: Text(
                    memberName(ref, c.index[e.key]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: prismCorners(context, 6),
                    child: LinearProgressIndicator(
                      value: total.inSeconds == 0
                          ? 0
                          : e.value.inSeconds / total.inSeconds,
                      minHeight: 8,
                      color: c.color,
                      backgroundColor: context.sp.panelHi,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  dur(e.value),
                  style: TextStyle(color: context.sp.dim, fontSize: 12),
                ),
              ],
            ),
          ),
        if (sessions.isNotEmpty) ...[
          CosmicHeading(tr(context, 'History', 'Historial')),
          for (final f in sessions.take(40))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: CosmicPanel(
                accent: f.isActive ? context.sp.secondary : c.color,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                onTap: () => context.push(AppRoutePaths.member(f.memberId!)),
                child: Row(
                  children: [
                    if (c.index[f.memberId] case final m?)
                      memberAvatar(ref, m, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        memberName(ref, c.index[f.memberId]),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      f.isActive
                          ? tr(
                              context,
                              'Now · ${dur(f.duration)}',
                              'Ahora · ${dur(f.duration)}',
                            )
                          : '${df.format(f.startTime)} · ${dur(f.duration)}',
                      style: TextStyle(color: context.sp.dim, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

// ───────────────────────── Journal & notes ─────────────────────────

class _Entries extends ConsumerWidget {
  const _Entries({required this.c, required this.kind});
  final SubCtx c;
  final String kind;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journal = kind == TrackerKind.subJournal;
    final rows =
        (ref.watch(trackerKindProvider(kind)).value ?? const <TrackerRecord>[])
            .where((r) => r.parentId == c.s.id)
            .toList()
          ..sort(
            (a, b) =>
                (b.flag('pinned') ? 1 : 0) - (a.flag('pinned') ? 1 : 0) != 0
                ? (b.flag('pinned') ? 1 : 0) - (a.flag('pinned') ? 1 : 0)
                : (b.occurredAt ?? b.createdAt).compareTo(
                    a.occurredAt ?? a.createdAt,
                  ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                journal
                    ? tr(
                        context,
                        'The subsystem’s own journal.',
                        'El diario propio del subsistema.',
                      )
                    : tr(
                        context,
                        'Notes and internal info.',
                        'Notas e información interna.',
                      ),
                style: TextStyle(color: context.sp.dim, fontSize: 13),
              ),
            ),
            GlowButton(
              label: tr(context, 'Write', 'Escribir'),
              icon: PhosphorIcons.pencilSimple(),
              onPressed: () => editSubEntry(context, ref, c, kind),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          _Empty(
            journal
                ? tr(context, 'No journal entries yet.', 'Aún no hay entradas.')
                : tr(context, 'No notes yet.', 'Aún no hay notas.'),
          ),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: CosmicPanel(
              accent: c.color,
              onTap: () => editSubEntry(context, ref, c, kind, editing: r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (r.flag('pinned'))
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(
                            PhosphorIcons.pushPin(PhosphorIconsStyle.fill),
                            size: 14,
                            color: context.sp.secondary,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          r.title.isEmpty
                              ? tr(context, 'Untitled', 'Sin título')
                              : r.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Text(
                        DateFormat.yMMMd(
                          context.dateLocale,
                        ).format(r.occurredAt ?? r.createdAt),
                        style: TextStyle(color: context.sp.faint, fontSize: 12),
                      ),
                    ],
                  ),
                  if ((r.body ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        r.body!,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.sp.dim, height: 1.45),
                      ),
                    ),
                  if (c.index[r.memberId] case final m?)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          memberAvatar(ref, m, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            memberName(ref, m),
                            style: TextStyle(
                              color: context.sp.faint,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

Future<void> editSubEntry(
  BuildContext context,
  WidgetRef ref,
  SubCtx c,
  String kind, {
  TrackerRecord? editing,
  List<(String, String, String)> categories = const [],
}) async {
  final title = TextEditingController(text: editing?.title);
  final body = TextEditingController(text: editing?.body);
  String? author = editing?.memberId;
  var pinned = editing?.flag('pinned') ?? false;
  String? cat = editing?.str('cat') ?? categories.firstOrNull?.$1;
  final isRule = kind == TrackerKind.subRule;
  await PrismSheet.show(
    context: context,
    title: editing == null
        ? tr(context, 'New', 'Nuevo')
        : tr(context, 'Edit', 'Editar'),
    builder: (ctx) => CosmicScope(
      accent: c.color,
      child: StatefulBuilder(
        builder: (ctx, set) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (categories.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final (k, en, es) in categories)
                      PrismChip(
                        label: tr(ctx, en, es),
                        selected: cat == k,
                        onTap: () => set(() => cat = k),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              PrismTextField(
                controller: title,
                labelText: isRule
                    ? tr(ctx, 'Rule or boundary', 'Norma o límite')
                    : tr(ctx, 'Title', 'Título'),
                maxLines: isRule ? 3 : 1,
              ),
              const SizedBox(height: 10),
              PrismTextField(
                controller: body,
                labelText: isRule
                    ? tr(ctx, 'Details (optional)', 'Detalles (opcional)')
                    : tr(ctx, 'Write…', 'Escribe…'),
                minLines: isRule ? 2 : 6,
                maxLines: 16,
              ),
              const SizedBox(height: 12),
              TrackerLabel(tr(ctx, 'Written by', 'Escrito por')),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final m in c.members)
                    PrismChip(
                      avatar: memberAvatar(ref, m, size: 20),
                      label: memberName(ref, m),
                      selected: author == m.id,
                      onTap: () =>
                          set(() => author = author == m.id ? null : m.id),
                    ),
                ],
              ),
              if (!isRule)
                PrismSwitchRow(
                  title: tr(ctx, 'Pin to top', 'Fijar arriba'),
                  value: pinned,
                  onChanged: (v) => set(() => pinned = v),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (editing != null)
                    PrismButton(
                      label: tr(ctx, 'Delete', 'Eliminar'),
                      tone: PrismButtonTone.destructive,
                      onPressed: () async {
                        await ref
                            .read(trackerNotifierProvider.notifier)
                            .delete(editing.id);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                    ),
                  const Spacer(),
                  PrismButton(
                    label: ctx.l10n.save,
                    tone: PrismButtonTone.filled,
                    onPressed: () async {
                      if (title.text.trim().isEmpty && body.text.trim().isEmpty)
                        return;
                      final t = ref.read(trackerNotifierProvider.notifier);
                      final fields = {'pinned': pinned, 'cat': cat};
                      if (editing == null) {
                        await t.create(
                          kind: kind,
                          parentId: c.s.id,
                          title: title.text.trim(),
                          body: body.text.trim(),
                          memberId: author,
                          occurredAt: DateTime.now(),
                          fields: fields,
                        );
                      } else {
                        await t.save(
                          editing
                              .copyWith(
                                title: title.text.trim(),
                                body: body.text.trim(),
                                memberId: author,
                              )
                              .withFields(fields),
                        );
                      }
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ───────────────────────── Groups & nesting ─────────────────────────

class _Groups extends ConsumerWidget {
  const _Groups({required this.c});
  final SubCtx c;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups =
        (ref.watch(trackerKindProvider(TrackerKind.subGroup)).value ??
                const <TrackerRecord>[])
            .where((g) => g.parentId == c.s.id)
            .toList();
    final nested = ref
        .watch(subsystemsProvider)
        .where((x) => x.parentId == c.s.id)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CosmicHeading(
          tr(context, 'Internal groups', 'Grupos internos'),
          trailing: _Link(
            tr(context, 'New group', 'Nuevo grupo'),
            () => _editGroup(context, ref, c, null),
          ),
        ),
        if (groups.isEmpty)
          _Empty(
            tr(
              context,
              'Group members inside this subsystem — teams, pairs, circles.',
              'Agrupa miembros dentro del subsistema: equipos, parejas, círculos.',
            ),
          ),
        for (final g in groups)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: CosmicPanel(
              accent: Color(g.integer('color') ?? c.color.toARGB32()),
              padding: const EdgeInsets.all(12),
              onTap: () => _editGroup(context, ref, c, g),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${g.str('emoji') ?? '◎'}  ${g.title}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final id in g.strings('members'))
                        if (c.index[id] case final m?)
                          GlowPill(
                            memberName(ref, m),
                            color: Color(
                              g.integer('color') ?? c.color.toARGB32(),
                            ),
                          ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        CosmicHeading(
          tr(context, 'Nested subsystems', 'Subsistemas anidados'),
          color: context.sp.tertiary,
          trailing: _Link(
            tr(context, 'New nested', 'Nuevo anidado'),
            () => showSubsystemWizard(context, parentId: c.s.id),
          ),
        ),
        if (nested.isEmpty)
          _Empty(
            tr(
              context,
              'Subsystems can contain their own subsystems.',
              'Los subsistemas pueden contener sus propios subsistemas.',
            ),
          ),
        for (final n in nested)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: CosmicPanel(
              accent: subColor(n),
              padding: const EdgeInsets.all(12),
              onTap: () => context.push('${AppRoutePaths.subsystems}/${n.id}'),
              child: Row(
                children: [
                  SubOrb(emoji: subEmoji(n), color: subColor(n), size: 34),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      n.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Icon(
                    PhosphorIcons.caretRight(),
                    size: 16,
                    color: context.sp.faint,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

Future<void> _editGroup(
  BuildContext context,
  WidgetRef ref,
  SubCtx c,
  TrackerRecord? g,
) async {
  final name = TextEditingController(text: g?.title);
  final emoji = TextEditingController(text: g?.str('emoji'));
  final sel = {...?g?.strings('members')};
  int color = g?.integer('color') ?? c.color.toARGB32();
  await PrismSheet.show(
    context: context,
    title: g == null ? tr(context, 'New group', 'Nuevo grupo') : g.title,
    builder: (ctx) => CosmicScope(
      accent: c.color,
      child: StatefulBuilder(
        builder: (ctx, set) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: PrismTextField(
                      controller: emoji,
                      labelText: tr(ctx, 'Icon', 'Icono'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PrismTextField(
                      controller: name,
                      labelText: tr(ctx, 'Name', 'Nombre'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ColorChoiceRow(
                value: color,
                colors: subsystemColors,
                onChanged: (v) => set(() => color = v),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final m in c.members)
                    PrismChip(
                      avatar: memberAvatar(ref, m, size: 20),
                      label: memberName(ref, m),
                      selected: sel.contains(m.id),
                      onTap: () => set(
                        () => sel.contains(m.id)
                            ? sel.remove(m.id)
                            : sel.add(m.id),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (g != null)
                    PrismButton(
                      label: tr(ctx, 'Delete', 'Eliminar'),
                      tone: PrismButtonTone.destructive,
                      onPressed: () async {
                        await ref
                            .read(trackerNotifierProvider.notifier)
                            .delete(g.id);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                    ),
                  const Spacer(),
                  PrismButton(
                    label: ctx.l10n.save,
                    tone: PrismButtonTone.filled,
                    onPressed: () async {
                      if (name.text.trim().isEmpty) return;
                      final t = ref.read(trackerNotifierProvider.notifier);
                      final f = {
                        'emoji': emoji.text.trim().isEmpty
                            ? null
                            : emoji.text.trim(),
                        'color': color,
                        'members': sel.toList(),
                      };
                      if (g == null) {
                        await t.create(
                          kind: TrackerKind.subGroup,
                          parentId: c.s.id,
                          title: name.text.trim(),
                          fields: f,
                        );
                      } else {
                        await t.save(
                          g.copyWith(title: name.text.trim()).withFields(f),
                        );
                      }
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ───────────────────────── Rules ─────────────────────────

const _ruleCats = [
  ('rule', 'Rule', 'Norma'),
  ('boundary', 'Boundary', 'Límite'),
  ('comm', 'Communication', 'Comunicación'),
];

class _Rules extends ConsumerWidget {
  const _Rules({required this.c});
  final SubCtx c;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules =
        (ref.watch(trackerKindProvider(TrackerKind.subRule)).value ??
                const <TrackerRecord>[])
            .where((r) => r.parentId == c.s.id)
            .toList();
    final legacy = (c.s.str(SubField.rules) ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                tr(
                  context,
                  'Rules, boundaries and communication preferences.',
                  'Normas, límites y preferencias de comunicación.',
                ),
                style: TextStyle(color: context.sp.dim, fontSize: 13),
              ),
            ),
            GlowButton(
              label: tr(context, 'Add', 'Añadir'),
              icon: AppIcons.add,
              onPressed: () => editSubEntry(
                context,
                ref,
                c,
                TrackerKind.subRule,
                categories: _ruleCats,
              ),
            ),
          ],
        ),
        if (legacy.isNotEmpty) ...[
          const SizedBox(height: 12),
          CosmicPanel(
            accent: c.color,
            child: Text(legacy, style: const TextStyle(height: 1.5)),
          ),
        ],
        for (final (k, en, es) in _ruleCats)
          if (rules.where((r) => (r.str('cat') ?? 'rule') == k).toList()
              case final list when list.isNotEmpty) ...[
            CosmicHeading(
              tr(context, en, es),
              color: k == 'boundary'
                  ? context.sp.secondary
                  : (k == 'comm' ? context.sp.tertiary : context.sp.primary),
            ),
            for (final r in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CosmicPanel(
                  accent: c.color,
                  padding: const EdgeInsets.all(12),
                  onTap: () => editSubEntry(
                    context,
                    ref,
                    c,
                    TrackerKind.subRule,
                    editing: r,
                    categories: _ruleCats,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                      if ((r.body ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            r.body!,
                            style: TextStyle(
                              color: context.sp.dim,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        if (rules.isEmpty && legacy.isEmpty)
          _Empty(tr(context, 'No rules yet.', 'Aún no hay normas.')),
      ],
    );
  }
}

// ───────────────────────── Connections ─────────────────────────

class _Connections extends ConsumerWidget {
  const _Connections({required this.c});
  final SubCtx c;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final others = ref
        .watch(subsystemsProvider)
        .where((x) => x.id != c.s.id)
        .toList();
    final linked = c.s.strings('links').toSet();
    final note = (c.s.str(SubField.connections) ?? '').trim();
    final shared = <String, int>{};
    final allM = ref.watch(subMembershipsProvider);
    for (final o in others) {
      final n = allM
          .where((m) => m.subsystemId == o.id && c.ids.contains(m.memberId))
          .length;
      if (n > 0) shared[o.id] = n;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CosmicHeading(tr(context, 'Main system', 'Sistema principal')),
        CosmicPanel(
          accent: c.color,
          onTap: () => _editConnectionNote(context, ref, c),
          child: Text(
            note.isEmpty
                ? tr(
                    context,
                    'Describe how this subsystem relates to the main system…',
                    'Describe cómo se relaciona este subsistema con el sistema principal…',
                  )
                : note,
            style: TextStyle(
              color: note.isEmpty ? context.sp.faint : context.sp.text,
              height: 1.5,
            ),
          ),
        ),
        CosmicHeading(
          tr(context, 'Other subsystems', 'Otros subsistemas'),
          color: context.sp.tertiary,
        ),
        if (others.isEmpty)
          _Empty(
            tr(
              context,
              'No other subsystems yet.',
              'Aún no hay otros subsistemas.',
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in others)
              PrismChip(
                label:
                    '${subEmoji(o)} ${o.title}${shared[o.id] != null ? ' · ${shared[o.id]} ${tr(context, 'shared', 'en común')}' : ''}',
                selected: linked.contains(o.id),
                onTap: () {
                  final next = linked.contains(o.id)
                      ? (linked..remove(o.id))
                      : (linked..add(o.id));
                  ref.read(subsystemActionsProvider).saveSettings(c.s, {
                    'links': next.toList(),
                  });
                },
              ),
          ],
        ),
        RelatedRecordsSection(self: RecordRef(RecordRef.rec, c.s.id)),
      ],
    );
  }
}

Future<void> _editConnectionNote(
  BuildContext context,
  WidgetRef ref,
  SubCtx c,
) async {
  final t = TextEditingController(text: c.s.str(SubField.connections));
  await PrismSheet.show(
    context: context,
    title: tr(
      context,
      'Connection to the main system',
      'Conexión con el sistema principal',
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrismTextField(controller: t, minLines: 3, maxLines: 8),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: PrismButton(
              label: ctx.l10n.save,
              tone: PrismButtonTone.filled,
              onPressed: () async {
                await ref.read(subsystemActionsProvider).saveSettings(c.s, {
                  SubField.connections: t.text.trim(),
                });
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
            ),
          ),
        ],
      ),
    ),
  );
}

// ───────────────────────── Chat & announcements ─────────────────────────

class _Chat extends ConsumerStatefulWidget {
  const _Chat({required this.c});
  final SubCtx c;
  @override
  ConsumerState<_Chat> createState() => _ChatState();
}

class _ChatState extends ConsumerState<_Chat> {
  final _text = TextEditingController();
  String? _author;
  bool _announce = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty || _author == null) return;
    await ref
        .read(trackerNotifierProvider.notifier)
        .create(
          kind: TrackerKind.subMessage,
          parentId: widget.c.s.id,
          memberId: _author,
          body: body,
          occurredAt: DateTime.now(),
          fields: {'announce': _announce},
        );
    _text.clear();
    setState(() => _announce = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final msgs =
        (ref.watch(trackerKindProvider(TrackerKind.subMessage)).value ??
                const <TrackerRecord>[])
            .where((m) => m.parentId == c.s.id)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final ann = msgs
        .where((m) => m.flag('announce'))
        .toList()
        .reversed
        .take(3)
        .toList();
    final canPost = {
      for (final m in c.memberships)
        if (m.permissions.contains('post') || m.founder) m.memberId,
    };
    final announceOnly = c.s.flag('announceOnly');
    _author ??= c.members.where((m) => canPost.contains(m.id)).firstOrNull?.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ann.isNotEmpty) ...[
          CosmicHeading(
            tr(context, 'Announcements', 'Anuncios'),
            color: context.sp.secondary,
          ),
          for (final m in ann)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _MessageCard(c: c, m: m),
            ),
        ],
        CosmicHeading(tr(context, 'Internal chat', 'Chat interno')),
        if (msgs.where((m) => !m.flag('announce')).isEmpty)
          _Empty(
            tr(
              context,
              'Say hello to your subsystem.',
              'Saluda a tu subsistema.',
            ),
          ),
        for (final m
            in msgs
                .where((m) => !m.flag('announce'))
                .toList()
                .reversed
                .take(60)
                .toList()
                .reversed)
          _Bubble(c: c, m: m),
        const SizedBox(height: 12),
        CosmicPanel(
          accent: c.color,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final m in c.members.where(
                      (m) => canPost.contains(m.id),
                    ))
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: PrismChip(
                          avatar: memberAvatar(ref, m, size: 18),
                          label: memberName(ref, m),
                          selected: _author == m.id,
                          onTap: () => setState(() => _author = m.id),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              PrismTextField(
                controller: _text,
                hintText: tr(context, 'Message…', 'Mensaje…'),
                minLines: 1,
                maxLines: 5,
                onSubmitted: (_) => _send(),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: PrismSwitchRow(
                      title: tr(context, 'Announcement', 'Anuncio'),
                      value: _announce || announceOnly,
                      onChanged: (v) =>
                          announceOnly ? null : setState(() => _announce = v),
                    ),
                  ),
                  GlowButton(
                    label: tr(context, 'Send', 'Enviar'),
                    icon: PhosphorIcons.paperPlaneTilt(),
                    onPressed: _author == null ? null : _send,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageCard extends ConsumerWidget {
  const _MessageCard({required this.c, required this.m});
  final SubCtx c;
  final TrackerRecord m;
  @override
  Widget build(BuildContext context, WidgetRef ref) => CosmicPanel(
    accent: context.sp.secondary,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              PhosphorIcons.megaphone(),
              size: 15,
              color: context.sp.secondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                memberName(ref, c.index[m.memberId]),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              DateFormat.MMMd(context.dateLocale).add_jm().format(m.createdAt),
              style: TextStyle(color: context.sp.faint, fontSize: 11.5),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(m.body ?? '', style: const TextStyle(height: 1.45)),
      ],
    ),
  );
}

class _Bubble extends ConsumerWidget {
  const _Bubble({required this.c, required this.m});
  final SubCtx c;
  final TrackerRecord m;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final who = c.index[m.memberId];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (who != null)
            memberAvatar(ref, who, size: 30)
          else
            const SizedBox(width: 30),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onLongPress: () async {
                final ok = await PrismDialog.confirm(
                  context: context,
                  title: tr(context, 'Delete message?', '¿Eliminar mensaje?'),
                  destructive: true,
                  confirmLabel: tr(context, 'Delete', 'Eliminar'),
                  cancelLabel: context.l10n.cancel,
                );
                if (ok == true)
                  await ref.read(trackerNotifierProvider.notifier).delete(m.id);
              },
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    c.color.withValues(alpha: 0.10),
                    context.sp.panel,
                  ),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                    topLeft: Radius.circular(4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            memberName(ref, who),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              color: c.color,
                            ),
                          ),
                        ),
                        Text(
                          DateFormat.jm(context.dateLocale).format(m.createdAt),
                          style: TextStyle(
                            color: context.sp.faint,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(m.body ?? ''),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Settings ─────────────────────────

class _Settings extends ConsumerWidget {
  const _Settings({required this.c});
  final SubCtx c;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = c.s;
    final set = c.settings;
    final a = ref.read(subsystemActionsProvider);
    void put(Map<String, Object?> f) => a.saveSettings(s, f);
    final subs = ref.watch(subsystemsProvider);
    final blocked = descendantsOf(s.id, subs);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CosmicHeading(tr(context, 'General', 'General')),
        CosmicPanel(
          accent: c.color,
          padding: const EdgeInsets.all(12),
          onTap: () => _editIdentity(context, ref, c),
          child: Row(
            children: [
              SubOrb(
                emoji: subEmoji(s),
                color: c.color,
                color2: subColor2(s),
                size: 38,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      tr(
                        context,
                        'Name, icon, description, tags',
                        'Nombre, icono, descripción, etiquetas',
                      ),
                      style: TextStyle(color: context.sp.faint, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(
                PhosphorIcons.pencilSimple(),
                size: 16,
                color: context.sp.faint,
              ),
            ],
          ),
        ),
        CosmicHeading(
          tr(context, 'Members', 'Miembros'),
          color: context.sp.secondary,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            PrismButton(
              label: tr(context, 'Add members', 'Añadir miembros'),
              icon: AppIcons.add,
              onPressed: () => showAddSubMembers(context, c),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          tr(
            context,
            'Tap a member in the Members tab to change their roles and permissions.',
            'Toca un miembro en la pestaña Miembros para cambiar sus roles y permisos.',
          ),
          style: TextStyle(color: context.sp.faint, fontSize: 12),
        ),
        CosmicHeading(
          tr(context, 'Structure', 'Estructura'),
          color: context.sp.tertiary,
        ),
        Text(
          tr(context, 'Nested inside', 'Anidado en'),
          style: TextStyle(color: context.sp.dim),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            PrismChip(
              label: tr(context, 'Top level', 'Nivel superior'),
              selected: s.parentId == null,
              onTap: () => a.saveSettings(s, const {}, clearParent: true),
            ),
            for (final o in subs)
              if (!blocked.contains(o.id))
                PrismChip(
                  label: '${subEmoji(o)} ${o.title}',
                  selected: s.parentId == o.id,
                  onTap: () => a.saveSettings(s, const {}, parentId: o.id),
                ),
          ],
        ),
        CosmicHeading(tr(context, 'Fronting', 'Frente')),
        PrismSwitchRow(
          title: tr(context, 'Allow co-fronting', 'Permitir co-frente'),
          value: set.coFronting,
          onChanged: (v) => put({'coFronting': v}),
        ),
        PrismSwitchRow(
          title: tr(
            context,
            'Notify when a member starts fronting',
            'Avisar cuando un miembro empiece a estar al frente',
          ),
          value: set.notifyFronting,
          onChanged: (v) => put({'notifyFronting': v}),
        ),
        CosmicHeading(
          tr(context, 'Communication', 'Comunicación'),
          color: context.sp.secondary,
        ),
        PrismSwitchRow(
          title: tr(context, 'Internal chat', 'Chat interno'),
          value: set.chat,
          onChanged: (v) => put({'chat': v}),
        ),
        PrismSwitchRow(
          title: tr(context, 'Announcements only', 'Solo anuncios'),
          subtitle: tr(
            context,
            'Every message is posted as an announcement.',
            'Cada mensaje se publica como anuncio.',
          ),
          value: s.flag('announceOnly'),
          onChanged: (v) => put({'announceOnly': v}),
        ),
        CosmicHeading(
          tr(context, 'Privacy', 'Privacidad'),
          color: context.sp.tertiary,
        ),
        PrismSwitchRow(
          title: tr(context, 'Member isolation', 'Aislamiento de miembros'),
          subtitle: tr(
            context,
            'Members appear only inside this subsystem — not in Headmates, alter searches or system-wide lists.',
            'Los miembros solo aparecen dentro de este subsistema, no en Headmates, búsquedas ni listas del sistema.',
          ),
          value: set.isolate,
          onChanged: (v) => put({'isolate': v}),
        ),
        const SizedBox(height: 8),
        PrismSegmentedControl<String>(
          segments: [
            PrismSegment(
              value: 'system',
              label: tr(context, 'Whole system', 'Todo el sistema'),
            ),
            PrismSegment(
              value: 'members',
              label: tr(context, 'Members only', 'Solo miembros'),
            ),
          ],
          selected: set.visibility,
          onChanged: (v) => put({'visibility': v}),
        ),
        CosmicHeading(tr(context, 'Appearance', 'Apariencia')),
        TrackerLabel(tr(context, 'Colours', 'Colores')),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final e in subPaletteModes.entries)
              PrismChip(
                label: switch (e.key) {
                  'inherit' => tr(
                    context,
                    'Same as parent',
                    'Igual que el padre',
                  ),
                  'blend' => tr(
                    context,
                    'Blend with parent',
                    'Mezclar con el padre',
                  ),
                  'theme' => tr(context, 'Follow app theme', 'Seguir el tema'),
                  _ => tr(context, 'Own palette', 'Paleta propia'),
                },
                selected: (s.str('paletteMode') ?? 'own') == e.key,
                onTap: () => put({'paletteMode': e.key}),
              ),
          ],
        ),
        if ((s.str('paletteMode') ?? 'own') != 'own' &&
            s.parentId == null &&
            (s.str('paletteMode') ?? 'own') != 'theme')
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              tr(
                context,
                'This subsystem isn\'t nested, so it uses its own palette.',
                'Este subsistema no está anidado, así que usa su propia paleta.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 8),
        Builder(
          builder: (context) {
            final own = [
              for (final x in (s.fields['palette'] as List? ?? const []))
                if (x is num) x.toInt(),
            ];
            final pal = own.length >= 5
                ? own
                : [
                    set.color,
                    set.color2 ?? set.color,
                    ...subPalettePresets.values.first.skip(2),
                  ];
            const names = ['Main', 'Glow', 'Accent', 'Soft', 'Deep'];
            final shown = subPalette(s);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (var i = 0; i < 5; i++)
                      Column(
                        children: [
                          GestureDetector(
                            onTap: () async {
                              final c = await showPrismColorPicker(
                                context: context,
                                initial: Color(pal[i]),
                                title: '${names[i]} colour',
                              );
                              if (c == null) return;
                              final next = [...pal]..[i] = c.toARGB32();
                              put({
                                'palette': next,
                                SubField.color: next[0],
                                'color2': next[1],
                              });
                            },
                            child: Semantics(
                              button: true,
                              label: '${names[i]} colour',
                              child: PrismCircleAvatar(
                                radius: 18,
                                backgroundColor: Color(pal[i]),
                              ),
                            ),
                          ),
                          Text(
                            names[i],
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final e in subPalettePresets.entries)
                      PrismChip(
                        label: e.key,
                        selected: false,
                        tintColor: Color(e.value.first),
                        onTap: () => put({
                          'palette': e.value,
                          SubField.color: e.value[0],
                          'color2': e.value[1],
                          'paletteMode': 'own',
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  tr(context, 'Showing now', 'Se muestra'),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: prismCorners(context, 8),
                  child: SizedBox(
                    height: 18,
                    child: Row(
                      children: [
                        if (shown.isEmpty)
                          Expanded(
                            child: ColoredBox(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        for (final c in shown)
                          Expanded(child: ColoredBox(color: c)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        TrackerLabel(tr(context, 'Banner', 'Banner')),
        PrismSegmentedControl<String>(
          segments: [
            PrismSegment(
              value: 'nebula',
              label: tr(context, 'Nebula', 'Nebulosa'),
            ),
            PrismSegment(
              value: 'aurora',
              label: tr(context, 'Aurora', 'Aurora'),
            ),
            PrismSegment(
              value: 'eclipse',
              label: tr(context, 'Eclipse', 'Eclipse'),
            ),
          ],
          selected: s.str('bannerStyle') ?? 'nebula',
          onChanged: (v) => put({'bannerStyle': v}),
        ),
        CosmicHeading(
          tr(context, 'Data', 'Datos'),
          color: context.sp.secondary,
        ),
        PrismSwitchRow(
          title: tr(
            context,
            'Separate journal & notes',
            'Diario y notas propios',
          ),
          value: set.separateJournal,
          onChanged: (v) => put({'separateJournal': v}),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: PrismButton(
            label: tr(context, 'Delete subsystem', 'Eliminar subsistema'),
            icon: AppIcons.delete,
            tone: PrismButtonTone.destructive,
            onPressed: () async {
              final router = GoRouter.of(context);
              final ok = await PrismDialog.confirm(
                context: context,
                title: tr(
                  context,
                  'Delete ${s.title}?',
                  '¿Eliminar ${s.title}?',
                ),
                message: tr(
                  context,
                  'Its memberships, journal, notes, rules, groups and chat are removed. The alters themselves stay, and nested subsystems move up a level.',
                  'Se quitan sus membresías, diario, notas, normas, grupos y chat. Los alters se quedan y los subsistemas anidados suben un nivel.',
                ),
                destructive: true,
                confirmLabel: tr(context, 'Delete', 'Eliminar'),
                cancelLabel: context.l10n.cancel,
              );
              if (ok != true) return;
              await a.delete(s);
              if (router.canPop()) router.pop();
            },
          ),
        ),
      ],
    );
  }
}

Future<void> _editIdentity(
  BuildContext context,
  WidgetRef ref,
  SubCtx c,
) async {
  final s = c.s;
  final name = TextEditingController(text: s.title);
  final desc = TextEditingController(text: s.body);
  final purpose = TextEditingController(text: s.str(SubField.purpose));
  final origin = TextEditingController(text: s.str(SubField.origin));
  final tags = TextEditingController(text: s.tags.join(' '));
  var emoji = subEmoji(s);
  await PrismSheet.show(
    context: context,
    title: tr(context, 'General', 'General'),
    builder: (ctx) => CosmicScope(
      accent: c.color,
      child: StatefulBuilder(
        builder: (ctx, set) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in subsystemEmojis)
                    PrismChip(
                      label: e,
                      selected: emoji == e,
                      onTap: () => set(() => emoji = e),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              PrismTextField(
                controller: name,
                labelText: tr(ctx, 'Name', 'Nombre'),
              ),
              const SizedBox(height: 10),
              PrismTextField(
                controller: desc,
                labelText: tr(ctx, 'Description', 'Descripción'),
                minLines: 2,
                maxLines: 5,
              ),
              const SizedBox(height: 10),
              PrismTextField(
                controller: purpose,
                labelText: tr(ctx, 'Purpose', 'Propósito'),
                maxLines: 3,
              ),
              const SizedBox(height: 10),
              PrismTextField(
                controller: origin,
                labelText: tr(ctx, 'Origin', 'Origen'),
                maxLines: 3,
              ),
              const SizedBox(height: 10),
              PrismTextField(
                controller: tags,
                labelText: tr(
                  ctx,
                  'Tags (space-separated)',
                  'Etiquetas (separadas por espacios)',
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: PrismButton(
                  label: ctx.l10n.save,
                  tone: PrismButtonTone.filled,
                  onPressed: () async {
                    if (name.text.trim().isEmpty) return;
                    await ref
                        .read(subsystemActionsProvider)
                        .saveSettings(
                          s,
                          {
                            SubField.emoji: emoji,
                            SubField.purpose: purpose.text.trim(),
                            SubField.origin: origin.text.trim(),
                          },
                          title: name.text.trim(),
                          body: desc.text.trim(),
                          tags: parseRoles(tags.text),
                        );
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ───────────────────────── Fronting notifications ─────────────────────────

/// Posts a notification when a member of a subsystem with fronting
/// notifications on starts fronting.
final subsystemFrontNotifierProvider = Provider<void>((ref) {
  Timer? t;
  t = Timer(const Duration(seconds: 7), () {
    if (!ref.mounted || kIsWeb) return;
    Set<String>? known;
    ref.listen<AsyncValue<List<FrontingSession>>>(activeSessionsProvider, (
      _,
      next,
    ) async {
      final sessions = next.value;
      if (sessions == null || !isFeatureOn(ref, 'subsystems')) return;
      final ids = {for (final f in sessions) f.id};
      final before = known;
      known = ids;
      if (before == null) return;
      final subs = {
        for (final s in ref.read(subsystemsProvider))
          if (SubSettings(s).notifyFronting) s.id: s,
      };
      if (subs.isEmpty) return;
      final members = ref.read(memberIndexProvider);
      for (final f in sessions.where(
        (f) => !before.contains(f.id) && f.memberId != null && !f.isSleep,
      )) {
        for (final m
            in ref
                .read(subMembershipsProvider)
                .where(
                  (m) =>
                      m.memberId == f.memberId &&
                      subs.containsKey(m.subsystemId),
                )) {
          final s = subs[m.subsystemId]!;
          final who =
              members[f.memberId]?.effectiveName(
                preferDisplayName: ref.read(memberNamePreferDisplayProvider),
              ) ??
              '';
          try {
            await ref
                .read(localNotificationServiceProvider)
                .showImmediate(
                  id:
                      PrismNotify.subsystemBase +
                      (s.id.hashCode.abs() % PrismNotify.range),
                  title: s.title,
                  body: '$who is fronting',
                  details: PrismNotify.details(
                    'prism_subsystems',
                    'Subsystems',
                  ),
                );
          } catch (_) {}
        }
      }
    }, fireImmediately: true);
  });
  ref.onDispose(() => t?.cancel());
});
