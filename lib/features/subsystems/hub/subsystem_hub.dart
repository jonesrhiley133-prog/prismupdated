import 'dart:math' as math;

import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/subsystems/hub/cosmos.dart';
import 'package:prism_plurality/features/subsystems/hub/subsystem_data.dart';
import 'package:prism_plurality/features/subsystems/hub/subsystem_wizard.dart';
import 'package:prism_plurality/features/subsystems/utils/subsystems.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/widgets/prism_expandable_section.dart';
import 'package:prism_plurality/shared/widgets/member_avatar.dart';

/// Subsystems hub: the user's subsystems orbit their system in a dark,
/// starry space. No statistic boxes — the subsystems are the centrepiece.
class SubsystemHubScreen extends ConsumerStatefulWidget {
  const SubsystemHubScreen({super.key});
  @override
  ConsumerState<SubsystemHubScreen> createState() => _SubsystemHubScreenState();
}

class _SubsystemHubScreenState extends ConsumerState<SubsystemHubScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 40));
  bool _migrated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The orbit stays still: subtle and understated.
    _spin.stop();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  void _maybeMigrate() {
    if (_migrated) return;
    final legacy = ref.read(subMembershipsProvider).any((m) => m.record.flag('legacy'));
    if (!legacy) return;
    _migrated = true;
    Future.microtask(() => ref.read(subsystemActionsProvider).migrateLegacy());
  }

  @override
  Widget build(BuildContext context) {
    final subs = ref.watch(subsystemsProvider);
    final memberships = ref.watch(subMembershipsProvider);
    if (subs.isNotEmpty) _maybeMigrate();
    final roots = subsystemTree(subs).where((e) => e.$2 == 0).map((e) => e.$1).toList();
    final counts = <String, int>{};
    for (final m in memberships) {
      counts[m.subsystemId] = (counts[m.subsystemId] ?? 0) + 1;
    }

    return CosmicScope(
      child: Builder(
        builder: (context) => PrismPageScaffold(
          topBar: PrismTopBar(
            title: tr(context, 'Subsystems', 'Subsistemas'),
            showBackButton: Navigator.of(context).canPop(),
            actions: [if (subs.isNotEmpty) PrismTopBarAction(icon: AppIcons.add, tooltip: tr(context, 'New subsystem', 'Nuevo subsistema'), onPressed: () => showSubsystemWizard(context))],
          ),
          body: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: ClampedBody(
                      child: _OrbitStage(subs: roots, all: subs, counts: counts, spin: _spin),
                    ),
                  ),
                  if (subs.isEmpty)
                    SliverToBoxAdapter(child: ClampedBody(child: _EmptyCall(onCreate: () => showSubsystemWizard(context))))
                  else ...[
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverToBoxAdapter(child: ClampedBody(child: CosmicHeading(tr(context, 'Constellation', 'Constelación')))),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList.list(
                        children: [
                          for (final (s, depth) in subsystemTree(subs))
                            ClampedBody(
                              child: Padding(
                                padding: EdgeInsets.only(left: depth * 22.0, bottom: 10),
                                child: _SubsystemRow(s: s, depth: depth, members: [for (final m in memberships) if (m.subsystemId == s.id) m.memberId]),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, NavBarInset.of(context) + 32),
                    sliver: const SliverToBoxAdapter(child: ClampedBody(child: _LearnMore())),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrbitStage extends StatelessWidget {
  const _OrbitStage({required this.subs, required this.all, required this.counts, required this.spin});
  final List<TrackerRecord> subs;
  final List<TrackerRecord> all;
  final Map<String, int> counts;
  final Animation<double> spin;

  static const _capacity = [3, 4, 6];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = math.min(box.maxWidth, 620.0);
        final h = math.min(w * 1.05, 560.0);
        final c = Offset(box.maxWidth / 2, h / 2);
        final rings = [w * 0.22, w * 0.335, w * 0.45];
        final shown = subs.take(_capacity.reduce((a, b) => a + b)).toList();
        final extra = subs.length - shown.length;
        final cardW = w < 420 ? 82.0 : 100.0;

        final placed = <(TrackerRecord, int, double)>[];
        var i = 0;
        for (var ring = 0; ring < 3 && i < shown.length; ring++) {
          final n = math.min(_capacity[ring], shown.length - i);
          for (var k = 0; k < n; k++) {
            placed.add((shown[i++], ring, -math.pi / 2 + (2 * math.pi * k / n) + ring * 0.5));
          }
        }

        return SizedBox(
          height: h,
          child: AnimatedBuilder(
            animation: spin,
            builder: (context, _) {
              final t = spin.value;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(child: CustomPaint(painter: OrbitPainter(rings: rings, center: c, color: context.sp.line, phase: t))),
                  Positioned(left: c.dx - 46, top: c.dy - 46, child: _Core(extra: extra, empty: subs.isEmpty)),
                  for (final (s, ring, a) in placed)
                    Builder(
                      builder: (context) {
                        final p = Offset(c.dx + rings[ring] * math.cos(a), c.dy + rings[ring] * 0.86 * math.sin(a));
                        return Positioned(
                          left: p.dx - cardW / 2,
                          top: p.dy - cardW / 2,
                          width: cardW,
                          child: _FloatingCard(s: s, size: cardW, members: counts[s.id] ?? 0, nested: all.where((x) => x.parentId == s.id).length),
                        );
                      },
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _Core extends StatelessWidget {
  const _Core({required this.extra, required this.empty});
  final int extra;
  final bool empty;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 92,
      height: 92,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.surfaceContainerHigh, border: Border.all(color: theme.colorScheme.outlineVariant)),
      child: Text(
        extra > 0 ? '+$extra' : tr(context, empty ? 'Your system' : 'System', empty ? 'Tu sistema' : 'Sistema'),
        textAlign: TextAlign.center,
        style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _FloatingCard extends ConsumerWidget {
  const _FloatingCard({required this.s, required this.size, required this.members, required this.nested});
  final TrackerRecord s;
  final double size;
  final int members;
  final int nested;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = subColor(s);
    return Semantics(
      button: true,
      label: '${s.title}, ${tr(context, '$members members', '$members miembros')}',
      child: GestureDetector(
        onTap: () => context.push('${AppRoutePaths.subsystems}/${s.id}'),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PrismTokens.radiusMedium),
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SubOrb(emoji: subEmoji(s), color: color, color2: subColor2(s), size: size * 0.42),
              const SizedBox(height: 6),
              Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(color: context.sp.text, fontSize: 12, fontWeight: FontWeight.w700)),
              Text(
                nested > 0 ? '$members · ◎$nested' : tr(context, '$members members', '$members miembros'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.sp.faint, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCall extends StatelessWidget {
  const _EmptyCall({required this.onCreate});
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Column(
      children: [
        Text(
          tr(context, 'No subsystems yet', 'Aún no hay subsistemas'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: context.sp.text),
        ),
        const SizedBox(height: 8),
        Text(
          tr(
            context,
            'A subsystem is a small system inside yours, with its own members, fronters, rules and history. Start with a founding alter and build from there.',
            'Un subsistema es un pequeño sistema dentro del tuyo, con sus propios miembros, frentes, normas e historial. Empieza con un alter fundador y crece desde ahí.',
          ),
          textAlign: TextAlign.center,
          style: TextStyle(color: context.sp.dim, height: 1.45),
        ),
        const SizedBox(height: 22),
        GlowButton(label: tr(context, 'Create a subsystem', 'Crear un subsistema'), icon: PhosphorIcons.planet(), large: true, onPressed: onCreate),
        const SizedBox(height: 12),
      ],
    ),
  );
}

class _SubsystemRow extends ConsumerWidget {
  const _SubsystemRow({required this.s, required this.depth, required this.members});
  final TrackerRecord s;
  final int depth;
  final List<String> members;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(memberIndexProvider);
    final color = subColor(s);
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    final shown = [for (final id in members.take(5)) ?index[id]];
    return CosmicPanel(
      accent: color,
      padding: const EdgeInsets.all(14),
      onTap: () => context.push('${AppRoutePaths.subsystems}/${s.id}'),
      child: Row(
        children: [
          if (depth > 0) Padding(padding: const EdgeInsets.only(right: 8), child: Icon(PhosphorIcons.arrowElbowDownRight(), size: 16, color: context.sp.faint)),
          SubOrb(emoji: subEmoji(s), color: color, color2: subColor2(s), size: 42),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: context.sp.text)),
                if ((s.body ?? '').trim().isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 2), child: Text(s.body!.trim(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.sp.dim, fontSize: 12.5))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      height: 24,
                      width: shown.isEmpty ? 0 : 24.0 + (shown.length - 1) * 16,
                      child: Stack(
                        children: [
                          for (var i = 0; i < shown.length; i++)
                            Positioned(
                              left: i * 16.0,
                              child: Container(
                                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: context.sp.bg, width: 1.5)),
                                child: MemberAvatar(
                                  avatarImageData: shown[i].avatarImageData,
                                  memberName: shown[i].effectiveName(preferDisplayName: prefer),
                                  emoji: shown[i].emoji,
                                  customColorEnabled: shown[i].customColorEnabled,
                                  customColorHex: shown[i].customColorHex,
                                  size: 22,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (shown.isNotEmpty) const SizedBox(width: 8),
                    Text(tr(context, '${members.length} members', '${members.length} miembros'), style: TextStyle(color: context.sp.faint, fontSize: 12)),
                    if (SubSettings(s).isolate) ...[const SizedBox(width: 8), Icon(PhosphorIcons.lockSimple(), size: 13, color: context.sp.faint)],
                  ],
                ),
              ],
            ),
          ),
          Icon(PhosphorIcons.caretRight(), size: 16, color: context.sp.faint),
        ],
      ),
    );
  }
}

class _LearnMore extends StatelessWidget {
  const _LearnMore();
  @override
  Widget build(BuildContext context) {
    final items = [
      (PhosphorIcons.planet(), context.sp.primary, tr(context, 'What is a subsystem?', '¿Qué es un subsistema?'),
          tr(context, 'A group of alters who form their own smaller system — with its own members, fronters, roles, relationships, rules and history — while still being part of your whole system.', 'Un grupo de alters que forman su propio sistema más pequeño —con sus miembros, frentes, roles, relaciones, normas e historial— sin dejar de ser parte de todo tu sistema.')),
      (PhosphorIcons.crown(), context.sp.secondary, tr(context, 'Founders, roles & permissions', 'Fundadores, roles y permisos'),
          tr(context, 'Every subsystem starts with a founding alter. Members get subsystem-only roles and permissions; an alter can belong to several subsystems without being copied, and their main profile never changes.', 'Cada subsistema empieza con un alter fundador. Los miembros tienen roles y permisos propios del subsistema; un alter puede estar en varios subsistemas sin copiarse, y su perfil principal no cambia.')),
      (PhosphorIcons.lockSimple(), context.sp.tertiary, tr(context, 'Private membership', 'Membresía privada'),
          tr(context, 'With member isolation on (the default), a subsystem’s members appear only inside that subsystem — not in Headmates, alter searches or other system-wide member lists.', 'Con el aislamiento activado (por defecto), los miembros de un subsistema solo aparecen dentro de él —no en Headmates, búsquedas de alters ni otras listas del sistema.')),
      (PhosphorIcons.treeStructure(), context.sp.primary, tr(context, 'Nesting & groups', 'Anidación y grupos'),
          tr(context, 'Subsystems can hold nested subsystems and internal groups, so layered or branching structures stay readable.', 'Los subsistemas pueden contener subsistemas anidados y grupos internos, para que las estructuras por capas o ramas sean claras.')),
      (PhosphorIcons.graph(), context.sp.secondary, tr(context, 'Its own space', 'Su propio espacio'),
          tr(context, 'Each subsystem keeps its own fronting history, journal, notes, chat and announcements, rules and boundaries, and connections to the main system and other subsystems.', 'Cada subsistema guarda su historial de frente, diario, notas, chat y anuncios, normas y límites, y conexiones con el sistema principal y otros subsistemas.')),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CosmicHeading(tr(context, 'Learn more', 'Más información'), color: context.sp.tertiary),
        for (final (icon, color, title, body) in items) Padding(padding: const EdgeInsets.only(bottom: 8), child: _Expander(icon: icon, color: color, title: title, body: body)),
      ],
    );
  }
}

class _Expander extends StatelessWidget {
  const _Expander({required this.icon, required this.color, required this.title, required this.body});
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => PrismExpandableSection(
    leading: Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
    title: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
    children: [Text(body, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5))],
  );
}
