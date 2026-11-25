import 'dart:math' as math;

import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/constants/fronting_namespaces.dart';
import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/fronting/providers/fronting_providers.dart';
import 'package:prism_plurality/features/fronting_roles/roles_data.dart';
import 'package:prism_plurality/features/fronting_roles/statuses_screen.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/settings/providers/settings_providers.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/widgets/member_avatar.dart';

/// "Who's there?" — a welcoming, full-screen way to confirm who's fronting.
class WhosThereScreen extends ConsumerStatefulWidget {
  const WhosThereScreen({super.key});
  @override
  ConsumerState<WhosThereScreen> createState() => _WhosThereScreenState();
}

class _WhosThereScreenState extends ConsumerState<WhosThereScreen>
    with TickerProviderStateMixin {
  late final AnimationController _bg = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );
  late final AnimationController _focus = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  final _search = TextEditingController();
  bool _multi = false;
  final List<String> _picked = [];
  Member? _chosen;
  bool _busy = false;
  bool _acted = false;
  late final RolesActions _actions = ref.read(rolesActionsProvider);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _bg.stop();
    } else if (!_bg.isAnimating) {
      _bg.repeat();
    }
  }

  @override
  void dispose() {
    _bg.dispose();
    _focus.dispose();
    _search.dispose();
    super.dispose();
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  Future<void> _run(Future<void> Function() action, {String? toast}) async {
    if (_busy) return;
    _acted = true;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      if (toast != null) PrismToast.show(context, message: toast);
      _close();
    } catch (e) {
      if (mounted) PrismToast.show(context, message: '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choose(Member m) async {
    if (_multi) {
      setState(
        () => _picked.contains(m.id) ? _picked.remove(m.id) : _picked.add(m.id),
      );
      return;
    }
    setState(() => _chosen = m);
    if (!MediaQuery.of(context).disableAnimations) await _focus.forward();
    await _run(
      () => ref.read(rolesActionsProvider).applyFronting(primary: m.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final members =
        (ref.watch(userVisibleMembersProvider).value ?? const <Member>[])
            .where((m) => !m.isDeleted && m.id != unknownSentinelMemberId)
            .toList();
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    String nameOf(Member m) => m.effectiveName(preferDisplayName: prefer);
    final roles = ref.watch(currentRolesProvider);
    final types = ref.watch(frontStatusTypesProvider);
    final roleOf = {
      for (final r in roles) r.memberId: statusById(types, r.statusId),
    };
    final fronting = [
      for (final r in roles)
        if (statusById(types, r.statusId)?.activeFronting == true) r.memberId,
    ];
    final system = ref.watch(systemSettingsProvider).value?.systemName ?? '';
    final history =
        ref.watch(frontingHistoryProvider(40)).value ??
        const <FrontingSession>[];
    final recent = <String>[];
    for (final s in history) {
      if (s.memberId != null &&
          !recent.contains(s.memberId) &&
          !fronting.contains(s.memberId))
        recent.add(s.memberId!);
    }
    final counts =
        ref.watch(memberFrontingCountsProvider).value ?? const <String, int>{};
    final favs =
        (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
            .map((e) => e.key)
            .where(
              (id) => !fronting.contains(id) && !recent.take(6).contains(id),
            )
            .take(6)
            .toList();
    final q = _search.text.trim().toLowerCase();
    final byId = {for (final m in members) m.id: m};
    List<Member> ids(Iterable<String> l) => [for (final id in l) ?byId[id]];

    Widget tile(Member m, [double width = 104]) {
      final role = roleOf[m.id];
      final picked = _picked.indexOf(m.id);
      return Semantics(
        button: true,
        selected: picked >= 0,
        label: '${nameOf(m)}${role == null ? '' : ', ${role.name}'}',
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _busy ? null : () => _choose(m),
          child: SizedBox(
            width: width,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            width: 3,
                            color: picked >= 0
                                ? scheme.primary
                                : (role?.activeFronting == true
                                      ? (role!.colorValue ?? scheme.tertiary)
                                      : Colors.transparent),
                          ),
                        ),
                        child: MemberAvatar(
                          avatarImageData: m.avatarImageData,
                          memberName: m.name,
                          emoji: m.emoji,
                          customColorEnabled: m.customColorEnabled,
                          customColorHex: m.customColorHex,
                          size: 76,
                        ),
                      ),
                      if (role != null && role.emoji.isNotEmpty)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: scheme.surface,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              role.emoji,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      if (picked >= 0)
                        Positioned(
                          left: -2,
                          top: -2,
                          child: CircleAvatar(
                            radius: 11,
                            backgroundColor: scheme.primary,
                            child: Text(
                              picked == 0 ? '★' : '${picked + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.onPrimary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    nameOf(m),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if ((m.pronouns ?? '').isNotEmpty)
                    Text(
                      m.pronouns!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Widget section(String title, List<Member> list) => list.isEmpty
        ? const SizedBox.shrink()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 14, 4, 4),
                child: Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              // Tiles share each row evenly so the grid fills the screen.
              LayoutBuilder(
                builder: (context, box) {
                  const gap = 4.0;
                  final cols = (box.maxWidth / 112).floor().clamp(3, 12);
                  final w = (box.maxWidth - gap * (cols - 1)) / cols;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [for (final m in list) tile(m, w)],
                  );
                },
              ),
            ],
          );

    final filtered = q.isEmpty
        ? members
        : members
              .where(
                (m) =>
                    nameOf(m).toLowerCase().contains(q) ||
                    (m.pronouns ?? '').toLowerCase().contains(q),
              )
              .toList();

    return PopScope(
      canPop: !_busy,
      // Backing out counts as "skip for now", so it doesn't come straight back.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_acted) _actions.snooze();
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _bg,
                  builder: (context, _) =>
                      CustomPaint(painter: _SoftBackground(_bg.value, scheme)),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Row(
                    children: [
                      PrismIconButton(
                        icon: PhosphorIcons.x(),
                        tooltip: tr(
                          context,
                          'Skip for now',
                          'Omitir por ahora',
                        ),
                        onPressed: _busy
                            ? () {}
                            : () => _run(
                                () => ref.read(rolesActionsProvider).snooze(),
                              ),
                      ),
                      const Spacer(),
                      PrismIconButton(
                        icon: PhosphorIcons.slidersHorizontal(),
                        tooltip: tr(
                          context,
                          'Manage fronting statuses',
                          'Gestionar estados',
                        ),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const FrontStatusesScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          tr(context, "Who's there?", '¿Quién está?'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (system.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              system,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        const SizedBox(height: 14),
                        PrismTextField(
                          controller: _search,
                          hintText: tr(context, 'Search', 'Buscar'),
                          prefixIcon: Icon(PhosphorIcons.magnifyingGlass()),
                          onChanged: (_) => setState(() {}),
                        ),
                        if (q.isNotEmpty)
                          section(
                            tr(context, 'RESULTS', 'RESULTADOS'),
                            filtered,
                          )
                        else ...[
                          section(
                            tr(context, 'FRONTING NOW', 'AL FRENTE AHORA'),
                            ids(fronting),
                          ),
                          section(
                            tr(context, 'RECENTLY', 'RECIENTES'),
                            ids(recent.take(6)),
                          ),
                          section(tr(context, 'OFTEN', 'A MENUDO'), ids(favs)),
                          section(
                            tr(context, 'EVERYONE', 'TODOS'),
                            members
                                .where(
                                  (m) =>
                                      !fronting.contains(m.id) &&
                                      !recent.take(6).contains(m.id) &&
                                      !favs.contains(m.id),
                                )
                                .toList(),
                          ),
                        ],
                        if (members.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              tr(
                                context,
                                'Add members first to choose who\'s fronting.',
                                'Añade miembros primero para elegir quién está al frente.',
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _ActionBar(
                    busy: _busy,
                    multi: _multi,
                    picked: _picked.length,
                    hasFronters: fronting.isNotEmpty,
                    frontingNames: [
                      for (final id in fronting)
                        if (byId[id] != null) nameOf(byId[id]!),
                    ],
                    onSame: () => _run(
                      () => ref.read(rolesActionsProvider).confirmSame(),
                      toast: tr(
                        context,
                        'Got it — still the same',
                        'Entendido: sigue igual',
                      ),
                    ),
                    onMulti: () => setState(() {
                      _multi = !_multi;
                      _picked.clear();
                    }),
                    onConfirmMulti: _picked.isEmpty
                        ? null
                        : () => _run(
                            () => ref
                                .read(rolesActionsProvider)
                                .applyFronting(
                                  primary: _picked.first,
                                  others: _picked.skip(1).toList(),
                                ),
                          ),
                    onUnsure: () => _run(
                      () => ref
                          .read(rolesActionsProvider)
                          .applyFronting(primary: unknownSentinelMemberId),
                    ),
                    onNoPrimary: fronting.isEmpty
                        ? null
                        : () => _run(() async {
                            await ref
                                .read(rolesActionsProvider)
                                .markNoPrimary();
                            await ref.read(rolesActionsProvider).confirmSame();
                          }),
                  ),
                ],
              ),
            ),
            if (_chosen != null)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _focus,
                  builder: (context, _) {
                    final t = Curves.easeOutCubic.transform(_focus.value);
                    return ColoredBox(
                      color: theme.scaffoldBackgroundColor.withValues(
                        alpha:
                            0.85 * t +
                            (MediaQuery.of(context).disableAnimations
                                ? 0.85
                                : 0),
                      ),
                      child: Center(
                        child: Opacity(
                          opacity: MediaQuery.of(context).disableAnimations
                              ? 1
                              : t,
                          child: Transform.scale(
                            scale: MediaQuery.of(context).disableAnimations
                                ? 1
                                : 0.7 + 0.3 * t,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                MemberAvatar(
                                  avatarImageData: _chosen!.avatarImageData,
                                  memberName: _chosen!.name,
                                  emoji: _chosen!.emoji,
                                  customColorEnabled:
                                      _chosen!.customColorEnabled,
                                  customColorHex: _chosen!.customColorHex,
                                  size: 132,
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  tr(
                                    context,
                                    'Hi, ${nameOf(_chosen!)}',
                                    'Hola, ${nameOf(_chosen!)}',
                                  ),
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.busy,
    required this.multi,
    required this.picked,
    required this.hasFronters,
    required this.frontingNames,
    required this.onSame,
    required this.onMulti,
    required this.onConfirmMulti,
    required this.onUnsure,
    required this.onNoPrimary,
  });
  final bool busy, multi, hasFronters;
  final int picked;
  final List<String> frontingNames;
  final VoidCallback onSame, onMulti, onUnsure;
  final VoidCallback? onConfirmMulti, onNoPrimary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        12 + MediaQuery.viewPaddingOf(context).bottom * 0,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.92),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (multi)
            PrismButton(
              tone: PrismButtonTone.filled,
              expanded: true,
              icon: PhosphorIcons.check(),
              label: picked == 0
                  ? tr(
                      context,
                      'Tap everyone who\'s fronting',
                      'Toca a todos los que están al frente',
                    )
                  : tr(
                      context,
                      'Confirm ($picked) — first is Primary',
                      'Confirmar ($picked): el primero es Principal',
                    ),
              onPressed: busy ? () {} : (onConfirmMulti ?? () {}),
            )
          else if (hasFronters)
            PrismButton(
              tone: PrismButtonTone.filled,
              expanded: true,
              icon: PhosphorIcons.check(),
              label: tr(
                context,
                'Still ${frontingNames.take(3).join(', ')}',
                'Sigue ${frontingNames.take(3).join(', ')}',
              ),
              onPressed: busy ? () {} : onSame,
            ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              PrismButton(
                density: PrismControlDensity.compact,
                icon: PhosphorIcons.users(),
                label: multi
                    ? tr(context, 'Just one', 'Solo uno')
                    : tr(context, 'Several of us', 'Varios'),
                onPressed: busy ? () {} : onMulti,
              ),
              PrismButton(
                density: PrismControlDensity.compact,
                icon: PhosphorIcons.question(),
                label: tr(context, 'Not sure', 'No lo sé'),
                onPressed: busy ? () {} : onUnsure,
              ),
              if (onNoPrimary != null)
                PrismButton(
                  density: PrismControlDensity.compact,
                  label: tr(context, 'No primary', 'Sin principal'),
                  onPressed: busy ? () {} : onNoPrimary!,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Slowly drifting soft colour blobs in the theme's colours. No blur
/// filters: plain radial gradients, cheap to draw.
class _SoftBackground extends CustomPainter {
  _SoftBackground(this.t, this.scheme);
  final double t;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final blobs = [
      (scheme.primary, 0.0, 0.55),
      (scheme.tertiary, 2.1, 0.45),
      (scheme.secondary, 4.2, 0.5),
    ];
    for (final (color, phase, r) in blobs) {
      final a = 2 * math.pi * t + phase;
      final c = Offset(
        size.width * (0.5 + 0.32 * math.cos(a)),
        size.height * (0.35 + 0.22 * math.sin(a * 0.8)),
      );
      final radius = size.shortestSide * r;
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: c, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SoftBackground old) =>
      old.t != t || old.scheme != scheme;
}
