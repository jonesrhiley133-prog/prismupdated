import 'dart:async';
import 'dart:math' as math;

import 'package:intl/intl.dart' show DateFormat;

import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/companions/adopt_screen.dart';
import 'package:prism_plurality/features/companions/appearance_editor.dart';
import 'package:prism_plurality/features/companions/companion_art.dart';
import 'package:prism_plurality/features/companions/companion_data.dart';
import 'package:prism_plurality/features/companions/companion_species.dart';
import 'package:prism_plurality/features/companions/companion_widgets.dart';
import 'package:prism_plurality/features/companions/habitat_editor.dart';
import 'package:prism_plurality/features/companions/photo_mode.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/social/widgets/social_widgets.dart'
    show SocialImage;
import 'package:prism_plurality/features/subsystems/hub/subsystem_data.dart';
import 'package:prism_plurality/shared/media/prism_media.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

Future<T?> pushPage<T>(BuildContext context, Widget page) => Navigator.of(
  context,
  rootNavigator: true,
).push<T>(MaterialPageRoute(builder: (_) => page));

final memberNamesProvider = Provider<Map<String, String>>((ref) {
  final prefer = ref.watch(memberNamePreferDisplayProvider);
  return {
    for (final m
        in ref.watch(userVisibleMembersProvider).value ?? const <Member>[])
      m.id: m.effectiveName(preferDisplayName: prefer),
  };
});

final subsystemNamesProvider = Provider<Map<String, String>>(
  (ref) => {for (final s in ref.watch(subsystemsProvider)) s.id: s.title},
);

String _date(DateTime d) => DateFormat.yMMMd().format(d);

Future<void> openAdopt(BuildContext context, {bool hatch = false}) async {
  final id = await pushPage<String>(context, AdoptScreen(hatch: hatch));
  if (id != null && context.mounted)
    unawaited(pushPage<void>(context, CompanionProfileScreen(companionId: id)));
}

/// Companions home: who lives here, their habitats and saved memories.
class CompanionsHubScreen extends ConsumerStatefulWidget {
  const CompanionsHubScreen({super.key});
  @override
  ConsumerState<CompanionsHubScreen> createState() =>
      _CompanionsHubScreenState();
}

class _CompanionsHubScreenState extends ConsumerState<CompanionsHubScreen> {
  String _owner = 'all';

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(companionsProvider);
    final featured = ref.watch(shownCompanionProvider(currentFronterId(ref)));
    final habitats = ref.watch(habitatsProvider);
    final memories = ref.watch(companionMemoriesProvider);
    final names = ref.watch(memberNamesProvider);
    final subNames = ref.watch(subsystemNamesProvider);
    final theme = Theme.of(context);
    final ownerIds = {
      for (final c in all)
        if (c.ownerType == OwnerType.member || c.ownerType == OwnerType.members)
          ...c.owners,
    };
    final shown = all
        .where(
          (c) => switch (_owner) {
            'all' => true,
            'system' => c.ownerType == OwnerType.system,
            'none' => c.ownerType == OwnerType.none,
            _ => c.owners.contains(_owner),
          },
        )
        .toList();

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: 'Companions',
        showBackButton: true,
        actions: [
          PrismTopBarAction(
            icon: Icons.tune,
            tooltip: 'Companion settings',
            onPressed: () =>
                pushPage<void>(context, const CompanionSettingsScreen()),
          ),
          PrismTopBarAction(
            icon: Icons.add,
            tooltip: 'Adopt a companion',
            onPressed: () => openAdopt(context),
          ),
        ],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: all.isEmpty
            ? _Empty(
                onAdopt: () => openAdopt(context),
                onHatch: () => openAdopt(context, hatch: true),
              )
            : ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  32 + NavBarInset.of(context),
                ),
                children: [
                  if (featured != null)
                    _FeaturedStage(
                      companion: featured,
                      habitat: habitats
                          .where((h) => h.id == featured.habitatId)
                          .firstOrNull,
                    ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Everyone',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      PrismButton(
                        label: 'Hatch an egg',
                        icon: Icons.egg_outlined,
                        density: PrismControlDensity.compact,
                        onPressed: () => openAdopt(context, hatch: true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final (id, label) in [
                          ('all', 'All'),
                          ...[for (final m in ownerIds) (m, names[m] ?? '?')],
                          ('system', 'Whole system'),
                          ('none', 'Unassigned'),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: PrismChip(
                              label: label,
                              selected: _owner == id,
                              onTap: () => setState(() => _owner = id),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, box) {
                      final cols = (box.maxWidth / 170).floor().clamp(2, 5);
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final c in shown)
                            SizedBox(
                              width: (box.maxWidth - 10 * (cols - 1)) / cols,
                              child: _CompanionCard(
                                companion: c,
                                owners: ownersLabel(c, names, subNames),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Habitats',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      PrismButton(
                        label: 'New habitat',
                        icon: Icons.add,
                        density: PrismControlDensity.compact,
                        onPressed: () => _newHabitat(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (habitats.isEmpty)
                    Text(
                      'Give your companions a cozy place to hang out — a bedroom, a crystal cave, a cloud island…',
                      style: theme.textTheme.bodySmall,
                    )
                  else
                    SizedBox(
                      height: 132,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final h in habitats)
                            Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: Semantics(
                                button: true,
                                label: 'Habitat ${h.name}',
                                child: GestureDetector(
                                  onTap: () => pushPage<void>(
                                    context,
                                    HabitatEditorScreen(habitatId: h.id),
                                  ),
                                  child: SizedBox(
                                    width: 190,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          height: 104,
                                          child: HabitatScene(
                                            env: h.env,
                                            time: h.timeOfDay,
                                            weather: h.weather,
                                            lighting: h.lighting,
                                            items: h.items,
                                            animate: false,
                                            borderRadius: 14,
                                            children: [
                                              for (final (i, c)
                                                  in all
                                                      .where(
                                                        (c) =>
                                                            c.habitatId ==
                                                                h.id &&
                                                            !c.isEgg,
                                                      )
                                                      .take(3)
                                                      .indexed)
                                                Positioned(
                                                  left: 20.0 + i * 50,
                                                  bottom: 6,
                                                  child: CompanionFigure(
                                                    companion: c,
                                                    size: 56,
                                                    animate: false,
                                                    showParticles: false,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          h.name,
                                          style: theme.textTheme.labelLarge,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Memories',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      if (memories.isNotEmpty)
                        PrismButton(
                          label: 'See all',
                          density: PrismControlDensity.compact,
                          onPressed: () => pushPage<void>(
                            context,
                            const CompanionMemoriesScreen(),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (memories.isEmpty)
                    Text(
                      'Photos and milestones you save show up here.',
                      style: theme.textTheme.bodySmall,
                    ),
                  for (final m in memories.take(4)) MemoryTile(memory: m),
                ],
              ),
      ),
    );
  }

  Future<void> _newHabitat(BuildContext context) async {
    final env = await PrismSheet.show<String>(
      context: context,
      title: 'Choose a place',
      builder: (ctx) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        padding: const EdgeInsets.all(12),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.5,
        children: [
          for (final e in habitatEnvs)
            Semantics(
              button: true,
              label: e.name,
              child: GestureDetector(
                onTap: () => Navigator.of(ctx).pop(e.id),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    HabitatScene(env: e.id, animate: false, borderRadius: 12),
                    Positioned(
                      left: 8,
                      bottom: 6,
                      child: Text(
                        '${e.emoji} ${e.name}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          shadows: [Shadow(blurRadius: 4)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    if (env == null) return;
    final rec = await ref.read(companionActionsProvider).createHabitat(env);
    if (context.mounted)
      unawaited(
        pushPage<void>(context, HabitatEditorScreen(habitatId: rec.id)),
      );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdopt, required this.onHatch});
  final VoidCallback onAdopt, onHatch;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: -10,
          children: [
            for (final id in const ['fox', 'slime', 'owl', 'moon_rabbit'])
              CompanionView(
                species: speciesById(id),
                look: const CompanionLook(),
                size: 86,
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'A little friend for your system',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Adopt or hatch a companion — a cat, a fox, a tiny dragon, a cloud… Dress them up, decorate their home and take photos. They never get hungry, sick or lonely, and they\'ll be right here whenever you come back.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        PrismButton(
          label: 'Adopt a companion',
          icon: Icons.pets,
          tone: PrismButtonTone.filled,
          expanded: true,
          onPressed: onAdopt,
        ),
        const SizedBox(height: 8),
        PrismButton(
          label: 'Hatch an egg',
          icon: Icons.egg_outlined,
          expanded: true,
          onPressed: onHatch,
        ),
      ],
    );
  }
}

class _FeaturedStage extends StatelessWidget {
  const _FeaturedStage({required this.companion, this.habitat});
  final Companion companion;
  final Habitat? habitat;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: 'Visit ${companion.name}',
      child: GestureDetector(
        onTap: () => pushPage<void>(
          context,
          CompanionProfileScreen(companionId: companion.id),
        ),
        child: SizedBox(
          height: 220,
          child: HabitatScene(
            env:
                habitat?.env ??
                (companion.species.body == BodyKind.fish
                    ? 'aquarium'
                    : 'clearing'),
            time: habitat?.timeOfDay ?? 'auto',
            weather: habitat?.weather ?? 'clear',
            lighting: habitat?.lighting ?? 'soft',
            items: habitat?.items ?? const [],
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 4,
                child: Center(
                  child: CompanionFigure(companion: companion, size: 150),
                ),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.85),
                    borderRadius: prismCorners(context, 12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(companion.name, style: theme.textTheme.titleMedium),
                      Text(
                        companion.status.isNotEmpty
                            ? companion.status
                            : companion.species.name,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
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

class _CompanionCard extends StatelessWidget {
  const _CompanionCard({required this.companion, required this.owners});
  final Companion companion;
  final String owners;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = Color.lerp(
      companion.look.primaryOf(companion.species),
      theme.colorScheme.surface,
      0.8,
    )!;
    return Semantics(
      button: true,
      label:
          '${companion.name}, ${companion.species.name}${companion.isEgg ? ', still an egg' : ''}. $owners',
      child: InkWell(
        borderRadius: prismCorners(context, 18),
        onTap: () => pushPage<void>(
          context,
          CompanionProfileScreen(companionId: companion.id),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          decoration: BoxDecoration(
            color: tint,
            borderRadius: prismCorners(context, 18),
          ),
          child: Column(
            children: [
              ExcludeSemantics(
                child: companion.isEgg
                    ? EggView(style: companion.eggStyle, size: 96)
                    : CompanionFigure(
                        companion: companion,
                        size: 104,
                        animate: false,
                        showParticles: false,
                      ),
              ),
              Text(
                companion.name,
                style: theme.textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                companion.isEgg
                    ? 'Hatches ${_date(companion.hatchAt!)}'
                    : owners,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MemoryTile extends ConsumerWidget {
  const MemoryTile({super.key, required this.memory});
  final CompanionMemory memory;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final companions = [
      for (final id in memory.companionIds)
        ?ref.watch(companionByIdProvider(id)),
    ];
    final icon = switch (memory.kind) {
      'photo' => '📸',
      'adopt' => '🏡',
      'hatch' => '🥚',
      'milestone' => '⭐',
      _ => '📝',
    };
    return PrismListRow(
      leading: memory.scene != null
          ? ClipRRect(
              borderRadius: prismCorners(context, 8),
              child: SizedBox(
                width: 52,
                height: 52,
                child: PhotoSceneView(scene: memory.scene!, animate: false),
              ),
            )
          : (companions.isNotEmpty
                ? CompanionAvatar(companion: companions.first, size: 44)
                : Text(icon, style: const TextStyle(fontSize: 26))),
      title: Text(
        memory.title.isNotEmpty
            ? memory.title
            : (memory.kind == 'photo' ? 'Photo' : 'Memory'),
      ),
      subtitle: Text(
        '${_date(memory.at)}${companions.isEmpty ? '' : ' · ${companions.map((c) => c.name).join(', ')}'}${memory.caption.isEmpty ? '' : '\n${memory.caption}'}',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: memory.scene == null
          ? null
          : () =>
                pushPage<void>(context, PhotoViewerScreen(memoryId: memory.id)),
      trailing: Text(icon, style: theme.textTheme.titleMedium),
    );
  }
}

/// Every saved companion memory, newest first.
class CompanionMemoriesScreen extends ConsumerWidget {
  const CompanionMemoriesScreen({super.key, this.companionId});
  final String? companionId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = [
      for (final m in ref.watch(companionMemoriesProvider))
        if (companionId == null || m.companionIds.contains(companionId)) m,
    ];
    String? lastMonth;
    return PrismPageScaffold(
      topBar: const PrismTopBar(title: 'Memories', showBackButton: true),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: all.isEmpty
            ? const EmptyState(
                icon: Icon(Icons.photo_album_outlined),
                title: 'No memories yet',
                subtitle:
                    'Take a photo or adopt a companion to start the timeline.',
              )
            : ListView.builder(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  32 + NavBarInset.of(context),
                ),
                itemCount: all.length,
                itemBuilder: (context, i) {
                  final m = all[i];
                  final month = DateFormat.yMMMM().format(m.at);
                  final header = month != lastMonth;
                  lastMonth = month;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (header)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 14, 4, 4),
                          child: Text(
                            month,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      MemoryTile(memory: m),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

/// A companion's profile: say hi, play, and see everything about them.
class CompanionProfileScreen extends ConsumerStatefulWidget {
  const CompanionProfileScreen({super.key, required this.companionId});
  final String companionId;
  @override
  ConsumerState<CompanionProfileScreen> createState() =>
      _CompanionProfileScreenState();
}

class _CompanionProfileScreenState
    extends ConsumerState<CompanionProfileScreen> {
  CompanionPose _pose = CompanionPose.sit;
  String? _bubble;
  Timer? _reset;
  String? _as;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _interact(Companion c, String kind) async {
    final text = await ref
        .read(companionActionsProvider)
        .interact(c, kind, by: _as ?? currentFronterId(ref));
    if (!mounted) return;
    setState(() {
      _pose = poseFor(kind);
      _bubble = text;
    });
    _reset?.cancel();
    _reset = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _pose = CompanionPose.sit);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(companionByIdProvider(widget.companionId));
    if (c == null) {
      return const PrismPageScaffold(
        topBar: PrismTopBar(title: 'Companion', showBackButton: true),
        body: EmptyState(
          icon: Icon(Icons.pets),
          title: 'Not found',
          subtitle: 'This companion may have been removed.',
        ),
      );
    }
    final theme = Theme.of(context);
    final habitat = ref
        .watch(habitatsProvider)
        .where((h) => h.id == c.habitatId)
        .firstOrNull;
    final names = ref.watch(memberNamesProvider);
    final subNames = ref.watch(subsystemNamesProvider);
    final memories = [
      for (final m in ref.watch(companionMemoriesProvider))
        if (m.companionIds.contains(c.id)) m,
    ];
    final photos = memories.where((m) => m.scene != null).toList();
    final history = [
      for (final i in ref.watch(companionInteractionsProvider))
        if (i.companionId == c.id) i,
    ];
    final outfits = ref.watch(companionOutfitsProvider(c.id));
    final actions = ref.read(companionActionsProvider);

    Widget section(String title, List<Widget> children, {Widget? trailing}) =>
        Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleMedium),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 6),
              ...children,
            ],
          ),
        );

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: c.name,
        showBackButton: true,
        actions: [
          PrismTopBarAction(
            icon: c.favorite ? Icons.star : Icons.star_border,
            tooltip: c.favorite ? 'Unfavourite' : 'Favourite',
            onPressed: () => ref
                .read(trackerNotifierProvider.notifier)
                .save(c.r.withFields({...c.r.fields, 'favorite': !c.favorite})),
          ),
          PrismTopBarAction(
            icon: Icons.edit_outlined,
            tooltip: 'Edit profile',
            onPressed: () =>
                pushPage<void>(context, CompanionInfoEditor(companionId: c.id)),
          ),
        ],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + NavBarInset.of(context)),
          children: [
            // Stage
            SizedBox(
              height: 260,
              child: c.bannerMedia != null && habitat == null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: prismCorners(context, 20),
                          child: SocialImage(
                            id: c.bannerMedia!,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 4,
                          child: Center(
                            child: c.isEgg
                                ? EggView(style: c.eggStyle, size: 140)
                                : CompanionFigure(
                                    companion: c,
                                    size: 170,
                                    pose: _pose,
                                  ),
                          ),
                        ),
                      ],
                    )
                  : HabitatScene(
                      env:
                          habitat?.env ??
                          (c.species.body == BodyKind.fish
                              ? 'aquarium'
                              : 'clearing'),
                      time: habitat?.timeOfDay ?? 'auto',
                      weather: habitat?.weather ?? 'clear',
                      lighting: habitat?.lighting ?? 'soft',
                      items: habitat?.items ?? const [],
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 4,
                          child: Center(
                            child: c.isEgg
                                ? EggView(style: c.eggStyle, size: 140)
                                : CompanionFigure(
                                    companion: c,
                                    size: 170,
                                    pose: _pose,
                                  ),
                          ),
                        ),
                        if (_bubble != null)
                          Positioned(
                            left: 12,
                            right: 12,
                            top: 12,
                            child: Semantics(
                              liveRegion: true,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface.withValues(
                                    alpha: 0.92,
                                  ),
                                  borderRadius: prismCorners(context, 14),
                                ),
                                child: Text(
                                  _bubble!,
                                  style: theme.textTheme.bodyMedium,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 10),
            // Identity
            Row(
              children: [
                CompanionAvatar(companion: c, size: 54),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.displayName, style: theme.textTheme.titleLarge),
                      Text(
                        [
                          c.species.name,
                          if (c.pronouns.isNotEmpty) c.pronouns,
                          ownersLabel(c, names, subNames),
                        ].join(' · '),
                        style: theme.textTheme.bodySmall,
                      ),
                      if (c.status.isNotEmpty)
                        Text(
                          '“${c.status}”',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (c.isEgg) ...[
              const SizedBox(height: 12),
              PrismSurface(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'This egg hatches ${_date(c.hatchAt!)}. It\'s cozy and in no hurry.',
                      ),
                    ),
                    PrismButton(
                      label: 'Hatch now',
                      tone: PrismButtonTone.filled,
                      onPressed: () => actions.hatchNow(c),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('Interacting as', style: theme.textTheme.labelMedium),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final e in names.entries.take(12))
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: PrismChip(
                                label: e.value,
                                selected:
                                    (_as ?? currentFronterId(ref)) == e.key,
                                onTap: () => setState(() => _as = e.key),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in companionInteractions.entries)
                    _ActionButton(
                      emoji: e.value.$2,
                      label: e.value.$1,
                      onTap: () => _interact(c, e.key),
                    ),
                  _ActionButton(
                    emoji: '📸',
                    label: 'Take a photo',
                    onTap: () => pushPage<void>(
                      context,
                      PhotoModeScreen(companionIds: [c.id]),
                    ),
                  ),
                  _ActionButton(
                    emoji: '👗',
                    label: 'Dress up',
                    onTap: () => pushPage<void>(
                      context,
                      AppearanceEditorScreen(companionId: c.id),
                    ),
                  ),
                  _ActionButton(
                    emoji: '🏡',
                    label: 'Decorate home',
                    onTap: () async {
                      if (habitat != null) {
                        await pushPage<void>(
                          context,
                          HabitatEditorScreen(habitatId: habitat.id),
                        );
                      } else {
                        await _pickHabitat(context, c);
                      }
                    },
                  ),
                  _ActionButton(
                    emoji: '⭐',
                    label: 'Catch the stars',
                    onTap: () async {
                      final caught = await pushPage<int>(
                        context,
                        StarCatchGame(companion: c),
                      );
                      if (caught != null && caught > 0)
                        await actions.interact(
                          c,
                          'play',
                          by: _as ?? currentFronterId(ref),
                        );
                    },
                  ),
                ],
              ),
            ],
            section('About', [
              if (c.bio.isNotEmpty) Text(c.bio),
              if (c.traits.isNotEmpty || c.customPersonality.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in c.traits)
                      Chip(
                        label: Text(
                          '${personalityTraits[t] ?? ''} ${traitLabel(t)}',
                        ),
                      ),
                  ],
                ),
                if (c.customPersonality.isNotEmpty)
                  Text(c.customPersonality, style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 6),
              _Fact('Adopted', _date(c.adoptedAt)),
              if (c.birthday != null) _Fact('Birthday', c.birthday!),
              if (c.favActivities.isNotEmpty)
                _Fact('Loves', c.favActivities.join(', ')),
              if (c.favFoods.isNotEmpty)
                _Fact('Favourite treats', c.favFoods.join(', ')),
              if (c.favAccessories.isNotEmpty)
                _Fact('Favourite accessories', c.favAccessories.join(', ')),
              if (c.tags.isNotEmpty)
                Wrap(
                  spacing: 6,
                  children: [for (final t in c.tags) Chip(label: Text('#$t'))],
                ),
            ]),
            section(
              'Outfits',
              [
                if (outfits.isEmpty)
                  Text(
                    'Save looks in the appearance editor to switch between them.',
                    style: theme.textTheme.bodySmall,
                  ),
                if (outfits.isNotEmpty)
                  SizedBox(
                    height: 118,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final o in outfits)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Semantics(
                              button: true,
                              selected: c.outfitId == o.r.id,
                              label: 'Wear ${o.name}',
                              child: GestureDetector(
                                onTap: () => actions.wearOutfit(c, o),
                                child: Container(
                                  width: 92,
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    borderRadius: prismCorners(context, 14),
                                    border: Border.all(
                                      color: c.outfitId == o.r.id
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.outlineVariant,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      CompanionFigure(
                                        companion: c,
                                        look: o.look,
                                        size: 80,
                                        animate: false,
                                        showParticles: false,
                                      ),
                                      Text(
                                        o.name,
                                        style: theme.textTheme.labelSmall,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
              trailing: PrismButton(
                label: 'Edit look',
                density: PrismControlDensity.compact,
                onPressed: () => pushPage<void>(
                  context,
                  AppearanceEditorScreen(companionId: c.id),
                ),
              ),
            ),
            section(
              'Photo album',
              [
                if (photos.isEmpty)
                  Text('No photos yet.', style: theme.textTheme.bodySmall),
                if (photos.isNotEmpty)
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    children: [
                      for (final p in photos.take(9))
                        Semantics(
                          button: true,
                          label: p.title.isEmpty
                              ? 'Photo from ${_date(p.at)}'
                              : p.title,
                          child: GestureDetector(
                            onTap: () => pushPage<void>(
                              context,
                              PhotoViewerScreen(memoryId: p.id),
                            ),
                            child: ClipRRect(
                              borderRadius: prismCorners(context, 10),
                              child: PhotoSceneView(
                                scene: p.scene!,
                                animate: false,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
              trailing: PrismButton(
                label: 'New photo',
                density: PrismControlDensity.compact,
                onPressed: () => pushPage<void>(
                  context,
                  PhotoModeScreen(companionIds: [c.id]),
                ),
              ),
            ),
            section(
              'Memories',
              [
                for (final m in memories.take(5)) MemoryTile(memory: m),
                if (memories.isEmpty)
                  Text('Nothing saved yet.', style: theme.textTheme.bodySmall),
              ],
              trailing: memories.length > 5
                  ? PrismButton(
                      label: 'All',
                      density: PrismControlDensity.compact,
                      onPressed: () => pushPage<void>(
                        context,
                        CompanionMemoriesScreen(companionId: c.id),
                      ),
                    )
                  : PrismButton(
                      label: 'Add note',
                      density: PrismControlDensity.compact,
                      onPressed: () => _addNote(context, c),
                    ),
            ),
            section('Recent moments', [
              if (history.isEmpty)
                Text(
                  'Moments you share show up here — completely optional.',
                  style: theme.textTheme.bodySmall,
                ),
              for (final h in history.take(6))
                PrismListRow(
                  dense: true,
                  leading: Text(
                    companionInteractions[h.kind]?.$2 ?? '✨',
                    style: const TextStyle(fontSize: 20),
                  ),
                  title: Text(h.flavor),
                  subtitle: Text(
                    '${DateFormat.MMMd().add_jm().format(h.at)}${h.by == null ? '' : ' · ${names[h.by] ?? 'someone'}'}',
                  ),
                ),
            ]),
            if (c.notes.isNotEmpty) section('Notes', [Text(c.notes)]),
            const SizedBox(height: 20),
            PrismButton(
              label: 'Change owners',
              icon: Icons.group_outlined,
              expanded: true,
              onPressed: () => _changeOwners(context, c),
            ),
            const SizedBox(height: 8),
            PrismButton(
              label: 'Move to a habitat',
              icon: Icons.house_outlined,
              expanded: true,
              onPressed: () => _pickHabitat(context, c),
            ),
            const SizedBox(height: 8),
            PrismButton(
              label: 'Say goodbye',
              icon: Icons.delete_outline,
              tone: PrismButtonTone.destructive,
              expanded: true,
              onPressed: () async {
                final ok = await PrismDialog.confirm(
                  context: context,
                  title: 'Remove ${c.name}?',
                  message:
                      'This removes the companion, their outfits, history and memories. Shared photos keep the other companions.',
                  confirmLabel: 'Remove',
                  destructive: true,
                );
                if (!ok) return;
                await actions.delete(c);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addNote(BuildContext context, Companion c) async {
    final t = TextEditingController();
    final ok = await PrismDialog.show<bool>(
      context: context,
      title: 'A memory with ${c.name}',
      builder: (_) => PrismTextField(
        controller: t,
        hintText: 'What happened?',
        maxLines: 3,
        autofocus: true,
      ),
      actions: [
        PrismButton(
          label: 'Cancel',
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
        ),
        PrismButton(
          label: 'Save',
          tone: PrismButtonTone.filled,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
        ),
      ],
    );
    if (ok == true && t.text.trim().isNotEmpty) {
      await ref
          .read(companionActionsProvider)
          .addMemory(
            companionIds: [c.id],
            kind: 'note',
            title: t.text.trim().split('\n').first,
            caption: t.text.trim(),
            by: currentFronterId(ref),
          );
    }
    t.dispose();
  }

  Future<void> _pickHabitat(BuildContext context, Companion c) async {
    final habitats = ref.read(habitatsProvider);
    final pick = await PrismSheet.show<String>(
      context: context,
      title: 'Where does ${c.name} hang out?',
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          for (final h in habitats)
            PrismListRow(
              leading: Text(
                habitatEnvById(h.env).emoji,
                style: const TextStyle(fontSize: 22),
              ),
              title: Text(h.name),
              selected: c.habitatId == h.id,
              onTap: () => Navigator.of(ctx).pop(h.id),
            ),
          PrismListRow(
            leading: const Icon(Icons.add),
            title: const Text('A new habitat'),
            onTap: () => Navigator.of(ctx).pop('__new'),
          ),
          if (c.habitatId != null)
            PrismListRow(
              leading: const Icon(Icons.close),
              title: const Text('No habitat'),
              onTap: () => Navigator.of(ctx).pop('__none'),
            ),
        ],
      ),
    );
    if (pick == null) return;
    final actions = ref.read(companionActionsProvider);
    if (pick == '__none') return actions.save(c, {'habitat': null});
    if (pick == '__new') {
      final rec = await actions.createHabitat(
        c.species.body == BodyKind.fish ? 'aquarium' : 'bedroom',
      );
      await actions.save(c, {'habitat': rec.id});
      return;
    }
    await actions.save(c, {'habitat': pick});
  }

  Future<void> _changeOwners(BuildContext context, Companion c) async {
    var type = c.ownerType;
    var owners = [...c.owners];
    final names = ref.read(memberNamesProvider);
    final subs = ref.read(subsystemsProvider);
    final ok = await PrismSheet.show<bool>(
      context: context,
      title: 'Owners',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final o in OwnerType.values)
                  if (o != OwnerType.subsystem || subs.isNotEmpty)
                    PrismChip(
                      label: o.label,
                      selected: type == o,
                      onTap: () => set(() {
                        type = o;
                        owners = o == OwnerType.member
                            ? owners.take(1).toList()
                            : (o == OwnerType.members ? owners : []);
                      }),
                    ),
              ],
            ),
            const SizedBox(height: 10),
            if (type == OwnerType.member || type == OwnerType.members)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in names.entries)
                    PrismChip(
                      label: e.value,
                      selected: owners.contains(e.key),
                      onTap: () => set(
                        () => type == OwnerType.member
                            ? owners = [e.key]
                            : (owners.contains(e.key)
                                  ? owners.remove(e.key)
                                  : owners.add(e.key)),
                      ),
                    ),
                ],
              ),
            if (type == OwnerType.subsystem)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in subs)
                    PrismChip(
                      label: s.title,
                      selected: owners.contains(s.id),
                      onTap: () => set(() => owners = [s.id]),
                    ),
                ],
              ),
            const SizedBox(height: 10),
            Text(
              'Memories, outfits and history all stay.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            PrismButton(
              label: 'Save',
              tone: PrismButtonTone.filled,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      ),
    );
    if (ok == true)
      await ref.read(companionActionsProvider).setOwners(c, type, owners);
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.emoji,
    required this.label,
    required this.onTap,
  });
  final String emoji, label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.9),
        borderRadius: prismCorners(context, 14),
        child: InkWell(
          borderRadius: prismCorners(context, 14),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: Text(emoji, style: const TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 6),
                  ExcludeSemantics(
                    child: Text(label, style: theme.textTheme.labelLarge),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label  ',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          TextSpan(text: value),
        ],
      ),
    ),
  );
}

/// Edit name, bio, status, favourites, tags, notes, pictures.
class CompanionInfoEditor extends ConsumerStatefulWidget {
  const CompanionInfoEditor({super.key, required this.companionId});
  final String companionId;
  @override
  ConsumerState<CompanionInfoEditor> createState() =>
      _CompanionInfoEditorState();
}

class _CompanionInfoEditorState extends ConsumerState<CompanionInfoEditor> {
  late final Companion _c = ref.read(
    companionByIdProvider(widget.companionId),
  )!;
  late final _name = TextEditingController(text: _c.name);
  late final _nick = TextEditingController(text: _c.nickname);
  late final _pronouns = TextEditingController(text: _c.pronouns);
  late final _status = TextEditingController(text: _c.status);
  late final _bio = TextEditingController(text: _c.bio);
  late final _acts = TextEditingController(text: _c.favActivities.join(', '));
  late final _foods = TextEditingController(text: _c.favFoods.join(', '));
  late final _accs = TextEditingController(text: _c.favAccessories.join(', '));
  late final _tags = TextEditingController(text: _c.tags.join(', '));
  late final _notes = TextEditingController(text: _c.notes);
  late final _custom = TextEditingController(text: _c.customPersonality);
  late final Set<String> _traits = {..._c.traits};
  late String? _avatar = _c.avatarMedia;
  late String? _banner = _c.bannerMedia;
  late String? _birthday = _c.birthday;

  @override
  void dispose() {
    for (final t in [
      _name,
      _nick,
      _pronouns,
      _status,
      _bio,
      _acts,
      _foods,
      _accs,
      _tags,
      _notes,
      _custom,
    ]) {
      t.dispose();
    }
    super.dispose();
  }

  List<String> _split(TextEditingController t) => t.text
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PrismPageScaffold(
      topBar: PrismTopBar(title: 'Edit ${_c.name}', showBackButton: true),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            32 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          children: [
            PrismTextField(controller: _name, labelText: 'Name'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: PrismTextField(
                    controller: _nick,
                    labelText: 'Nickname',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PrismTextField(
                    controller: _pronouns,
                    labelText: 'Pronouns',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            PrismTextField(
              controller: _status,
              labelText: 'Status',
              hintText: 'Napping in a sunbeam',
            ),
            const SizedBox(height: 10),
            PrismTextField(
              controller: _bio,
              labelText: 'Biography',
              maxLines: 4,
            ),
            const SizedBox(height: 14),
            Text('Personality', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in personalityTraits.entries)
                  PrismChip(
                    label: '${e.value} ${traitLabel(e.key)}',
                    selected: _traits.contains(e.key),
                    onTap: () => setState(
                      () => _traits.contains(e.key)
                          ? _traits.remove(e.key)
                          : _traits.add(e.key),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            PrismTextField(
              controller: _custom,
              labelText: 'Personality in your words',
              maxLines: 2,
            ),
            const SizedBox(height: 14),
            PrismTextField(
              controller: _acts,
              labelText: 'Favourite activities (comma-separated)',
            ),
            const SizedBox(height: 10),
            PrismTextField(controller: _foods, labelText: 'Favourite treats'),
            const SizedBox(height: 10),
            PrismTextField(
              controller: _accs,
              labelText: 'Favourite accessories',
            ),
            const SizedBox(height: 10),
            PrismTextField(controller: _tags, labelText: 'Tags'),
            const SizedBox(height: 10),
            PrismTextField(
              controller: _notes,
              labelText: 'Personal notes',
              maxLines: 3,
            ),
            const SizedBox(height: 10),
            Builder(
              builder: (rowContext) => PrismListRow(
                leading: const Icon(Icons.cake_outlined),
                title: const Text('Birthday'),
                subtitle: Text(_birthday ?? 'Not set'),
                trailing: _birthday == null
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _birthday = null),
                      ),
                onTap: () async {
                  final d = await showPrismDatePicker(
                    context: context,
                    anchorContext: rowContext,
                    initialDate: DateTime.now(),
                  );
                  if (d != null)
                    setState(
                      () => _birthday =
                          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
                    );
                },
              ),
            ),
            PrismListRow(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text('Profile picture'),
              subtitle: Text(
                _avatar == null
                    ? 'Drawn companion (default)'
                    : 'Uploaded picture',
              ),
              trailing: _avatar == null
                  ? null
                  : IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _avatar = null),
                    ),
              onTap: () async {
                final id = await PrismMedia.pickImage(ref);
                if (id != null) setState(() => _avatar = id);
              },
            ),
            PrismListRow(
              leading: const Icon(Icons.panorama_outlined),
              title: const Text('Profile banner'),
              subtitle: Text(
                _banner == null
                    ? 'Their habitat (default)'
                    : 'Uploaded picture',
              ),
              trailing: _banner == null
                  ? null
                  : IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _banner = null),
                    ),
              onTap: () async {
                final id = await PrismMedia.pickImage(ref);
                if (id != null) setState(() => _banner = id);
              },
            ),
            const SizedBox(height: 16),
            PrismButton(
              label: 'Save',
              tone: PrismButtonTone.filled,
              expanded: true,
              onPressed: () async {
                await ref
                    .read(companionActionsProvider)
                    .save(
                      _c,
                      {
                        'nickname': _nick.text.trim(),
                        'pronouns': _pronouns.text.trim(),
                        'status': _status.text.trim(),
                        'traits': [..._traits],
                        'customPersonality': _custom.text.trim(),
                        'favActivities': _split(_acts),
                        'favFoods': _split(_foods),
                        'favAccessories': _split(_accs),
                        'tags': _split(_tags),
                        'notes': _notes.text.trim(),
                        'avatar': _avatar,
                        'banner': _banner,
                        'birthday': _birthday,
                      },
                      title: _name.text.trim().isEmpty
                          ? _c.name
                          : _name.text.trim(),
                      body: _bio.text.trim(),
                    );
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A gentle mini-game: tap falling stars for 20 seconds. No score keeping
/// beyond a friendly line at the end.
class StarCatchGame extends StatefulWidget {
  const StarCatchGame({super.key, required this.companion});
  final Companion companion;
  @override
  State<StarCatchGame> createState() => _StarCatchGameState();
}

class _StarCatchGameState extends State<StarCatchGame> {
  final _rnd = math.Random();
  final _stars = <(int, double, double)>[];
  int _caught = 0, _next = 0, _left = 20;
  Timer? _tick, _spawn;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _left--);
      if (_left <= 0) {
        _tick?.cancel();
        _spawn?.cancel();
      }
    });
    _spawn = Timer.periodic(const Duration(milliseconds: 900), (_) {
      setState(() {
        _stars.add((
          _next++,
          0.08 + _rnd.nextDouble() * 0.84,
          0.1 + _rnd.nextDouble() * 0.55,
        ));
        if (_stars.length > 6) _stars.removeAt(0);
      });
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _spawn?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = _left <= 0;
    return PrismPageScaffold(
      topBar: PrismTopBar(title: 'Catch the stars', showBackButton: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              done
                  ? '${widget.companion.name} caught $_caught stars with you! ⭐'
                  : '$_left s · $_caught caught',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) => HabitatScene(
                env: 'celestial',
                animate: false,
                children: [
                  for (final (id, x, y) in _stars)
                    Positioned(
                      key: ValueKey(id),
                      left: x * box.maxWidth - 28,
                      top: y * box.maxHeight,
                      child: Semantics(
                        button: true,
                        label: 'Star',
                        child: IconButton(
                          iconSize: 40,
                          onPressed: done
                              ? null
                              : () => setState(() {
                                  _caught++;
                                  _stars.removeWhere((s) => s.$1 == id);
                                }),
                          icon: const Text('⭐', style: TextStyle(fontSize: 34)),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 6,
                    child: Center(
                      child: CompanionFigure(
                        companion: widget.companion,
                        size: 120,
                        pose: done ? CompanionPose.hop : CompanionPose.play,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: PrismButton(
              label: done ? 'Done' : 'Stop',
              tone: PrismButtonTone.filled,
              expanded: true,
              onPressed: () => Navigator.of(context).pop(_caught),
            ),
          ),
        ],
      ),
    );
  }
}

/// Where companions appear, which one, and notifications.
class CompanionSettingsScreen extends ConsumerWidget {
  const CompanionSettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(companionSettingsProvider);
    final all = [
      for (final c in ref.watch(companionsProvider))
        if (!c.isEgg) c,
    ];
    final save = ref.read(companionActionsProvider).saveSettings;
    final theme = Theme.of(context);
    return PrismPageScaffold(
      topBar: const PrismTopBar(
        title: 'Companion settings',
        showBackButton: true,
      ),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + NavBarInset.of(context)),
          children: [
            PrismSectionHeader(title: 'WHERE THEY APPEAR'),
            PrismSurface(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final e in CompanionSettings.placementLabels.entries)
                    PrismSwitchRow(
                      title: e.value,
                      value: s.shows(e.key),
                      onChanged: (v) => save(
                        s.copyWith(placements: {...s.placements, e.key: v}),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Text(
                'Companions never cover buttons, text or navigation.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            PrismSectionHeader(title: 'WHICH COMPANION'),
            PrismSurface(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final (k, l) in const [
                        ('featured', 'One I choose'),
                        ('rotate', 'A different one each day'),
                        ('profile', 'One the current fronter owns'),
                      ])
                        PrismChip(
                          label: l,
                          selected: s.choice == k,
                          onTap: () => save(s.copyWith(choice: k)),
                        ),
                    ],
                  ),
                  if (s.choice == 'featured' && all.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final c in all)
                          PrismChip(
                            label: c.name,
                            selected: (s.featuredId ?? all.first.id) == c.id,
                            onTap: () => save(s.copyWith(featuredId: c.id)),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            PrismSectionHeader(title: 'NOTIFICATIONS'),
            PrismSurface(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final e in CompanionSettings.notifyLabels.entries)
                    PrismSwitchRow(
                      title: e.value,
                      value: s.notify[e.key] ?? false,
                      onChanged: (v) =>
                          save(s.copyWith(notify: {...s.notify, e.key: v})),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Text(
                'All off by default. Companions never send "I miss you" or "I\'m hungry" messages — they don\'t have needs.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            PrismSectionHeader(title: 'PASSPORT'),
            PrismSurface(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: PrismSwitchRow(
                title: 'Suggest passport stamps',
                subtitle: 'After adopting, hatching or saving a photo.',
                value: s.passportSuggestions,
                onChanged: (v) => save(s.copyWith(passportSuggestions: v)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
