import 'dart:math' as math;

import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:prism_plurality/features/voice/voice_engine.dart';
import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/features/companions/companion_data.dart';
import 'package:prism_plurality/features/companions/companion_screens.dart';
import 'package:prism_plurality/features/companions/companion_widgets.dart';
import 'package:prism_plurality/features/companions/photo_mode.dart';
import 'package:prism_plurality/features/passport/passport_book.dart';
import 'package:prism_plurality/features/passport/passport_data.dart';
import 'package:prism_plurality/features/passport/passport_widgets.dart';
import 'package:prism_plurality/features/passport/stamp_art.dart';
import 'package:prism_plurality/features/wrapped/wrapped_cards.dart';
import 'package:prism_plurality/features/wrapped/wrapped_data.dart';
import 'package:prism_plurality/features/wrapped/wrapped_engine.dart';
import 'package:prism_plurality/features/wrapped/wrapped_screens.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Something worth looking back on today: a companion photo or memory, or
/// a passport stamp. "On this day" in an earlier year wins; otherwise a
/// different one each day.
class ExperienceMemory {
  const ExperienceMemory({
    required this.id,
    required this.title,
    required this.at,
    this.memory,
    this.stamp,
    this.onThisDay = false,
  });
  final String id;
  final String title;
  final DateTime at;
  final CompanionMemory? memory;
  final PassportStamp? stamp;
  final bool onThisDay;
}

final memoryOfTheDayProvider = Provider<ExperienceMemory?>((ref) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final all = <ExperienceMemory>[
    for (final m in ref.watch(companionMemoriesProvider))
      if (m.scene != null || m.media != null || m.title.isNotEmpty)
        ExperienceMemory(
          id: m.id,
          title: m.title.isEmpty ? 'A companion memory' : m.title,
          at: m.at,
          memory: m,
        ),
    for (final s in ref.watch(allStampsProvider))
      ExperienceMemory(
        id: s.id,
        title: s.title.isEmpty ? 'A stamp' : s.title,
        at: s.at,
        stamp: s,
      ),
  ]..sort((a, b) => a.id.compareTo(b.id));
  if (all.isEmpty) return null;
  final otd = all
      .where(
        (e) =>
            e.at.month == now.month &&
            e.at.day == now.day &&
            e.at.year < now.year,
      )
      .toList();
  if (otd.isNotEmpty) {
    final e = otd.first;
    return ExperienceMemory(
      id: e.id,
      title: e.title,
      at: e.at,
      memory: e.memory,
      stamp: e.stamp,
      onThisDay: true,
    );
  }
  final day = today.difference(DateTime(2020)).inDays;
  return all[day % all.length];
});

void _openMemory(BuildContext context, ExperienceMemory e) {
  if (e.memory != null) {
    pushPage<void>(context, PhotoViewerScreen(memoryId: e.memory!.id));
  } else if (e.stamp != null) {
    pushPage<void>(
      context,
      PassportBookScreen(passportId: e.stamp!.passportId),
    );
  }
}

Widget _memoryVisual(ExperienceMemory e, double size) {
  final m = e.memory;
  if (m?.scene != null)
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: PhotoSceneView(scene: m!.scene!, animate: false),
      ),
    );
  if (e.stamp != null) return StampView(design: e.stamp!.design, size: size);
  return SizedBox(
    width: size,
    height: size,
    child: const Center(child: Text('🐾', style: TextStyle(fontSize: 32))),
  );
}

/// The Experiences tab: companions, passports and recaps in one place.
class ExperiencesHubScreen extends ConsumerWidget {
  const ExperiencesHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final companions = ref.watch(companionsProvider);
    final shown = ref.watch(shownCompanionProvider(currentFronterId(ref)));
    final passports = ref.watch(passportsProvider);
    final stamps = [...ref.watch(allStampsProvider)]
      ..sort((a, b) => b.at.compareTo(a.at));
    final wraps = ref.watch(wrapSnapshotsProvider);
    final memory = ref.watch(memoryOfTheDayProvider);
    final featured =
        passports.where((p) => p.pinned).firstOrNull ??
        passports.where((p) => p.favorite).firstOrNull ??
        passports.firstOrNull;

    return PrismPageScaffold(
      topBar: const PrismTopBar(title: 'Experiences'),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + NavBarInset.of(context)),
          children: [
            if (shown != null)
              PrismSurface(
                onTap: () => pushPage<void>(
                  context,
                  CompanionProfileScreen(companionId: shown.id),
                ),
                child: Row(
                  children: [
                    CompanionFigure(companion: shown, size: 72),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(shown.name, style: theme.textTheme.titleMedium),
                          (shown.status.isNotEmpty
                              ? Text(
                                  shown.status,
                                  style: theme.textTheme.bodySmall,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : VoiceText(
                                  VoiceContext.companionHello,
                                  fallback: companionFlavor(
                                    shown,
                                    'pet',
                                    rnd: math.Random(
                                      DateTime.now().day + shown.id.hashCode,
                                    ),
                                  ),
                                  feature: 'companions',
                                  vars: {'name': shown.name},
                                  style: theme.textTheme.bodySmall,
                                  maxLines: 2,
                                )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, box) {
                final cols = box.maxWidth > 560 ? 3 : 1;
                final tiles = [
                  _Tile(
                    emoji: '🐾',
                    title: 'Companions',
                    subtitle: companions.isEmpty
                        ? 'Adopt a little friend'
                        : '${companions.length} companion${companions.length == 1 ? '' : 's'}',
                    onTap: () => context.push(AppRoutePaths.companions),
                  ),
                  _Tile(
                    emoji: '📔',
                    title: 'Passports',
                    subtitle: passports.isEmpty
                        ? 'Collect stamps for moments'
                        : '${passports.length} passport${passports.length == 1 ? '' : 's'} · ${stamps.length} stamps',
                    onTap: () => context.push(AppRoutePaths.passports),
                  ),
                  _Tile(
                    emoji: '🎁',
                    title: 'Wrapped',
                    subtitle: wraps.isEmpty
                        ? 'Recaps of what you did'
                        : '${wraps.length} recap${wraps.length == 1 ? '' : 's'}',
                    onTap: () => context.push(AppRoutePaths.wrapped),
                  ),
                ];
                if (cols == 1)
                  return Column(
                    children: [
                      for (final t in tiles)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: t,
                        ),
                    ],
                  );
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final t in tiles)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: t,
                        ),
                      ),
                  ],
                );
              },
            ),
            if (memory != null) ...[
              PrismSectionHeader(
                title: memory.onThisDay ? 'ON THIS DAY' : 'MEMORY OF THE DAY',
              ),
              PrismSurface(
                onTap: () => _openMemory(context, memory),
                child: Row(
                  children: [
                    _memoryVisual(memory, 84),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(memory.title, style: theme.textTheme.titleSmall),
                          Text(
                            DateFormat.yMMMd().format(memory.at),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            PrismSectionHeader(title: 'RECAPS'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (p, label) in [
                  (WrapPeriod.weekly, 'This week'),
                  (WrapPeriod.monthly, 'This month'),
                  (WrapPeriod.seasonal, 'This season'),
                  (WrapPeriod.yearly, 'This year'),
                ])
                  PrismChip(
                    label: label,
                    selected: false,
                    onTap: () => quickWrap(context, ref, p),
                  ),
              ],
            ),
            if (wraps.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: wraps.length.clamp(0, 8),
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final s = wraps[i];
                    final cards = s.style.arrange(s.cards);
                    return GestureDetector(
                      onTap: () =>
                          pushPage<void>(context, WrapPlayerScreen.snapshot(s)),
                      child: SizedBox(
                        width: 96,
                        child: Column(
                          children: [
                            if (cards.isNotEmpty)
                              IgnorePointer(
                                child: WrapCardView(
                                  card: cards.first,
                                  style: s.style,
                                  animateFigures: false,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              s.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            if (featured != null) ...[
              PrismSectionHeader(title: 'FEATURED PASSPORT'),
              Center(
                child: GestureDetector(
                  onTap: () => pushPage<void>(
                    context,
                    PassportBookScreen(passportId: featured.id),
                  ),
                  child: PassportCoverView(
                    cover: featured.cover,
                    name: featured.name,
                    subtitle: featured.subtitle,
                    width: 160,
                  ),
                ),
              ),
            ],
            if (stamps.isNotEmpty) ...[
              PrismSectionHeader(title: 'LATEST STAMPS'),
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: stamps.length.clamp(0, 12),
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => GestureDetector(
                    onTap: () => pushPage<void>(
                      context,
                      PassportBookScreen(passportId: stamps[i].passportId),
                    ),
                    child: Tooltip(
                      message: stamps[i].title,
                      child: StampView(design: stamps[i].design, size: 96),
                    ),
                  ),
                ),
              ),
            ],
            PrismSectionHeader(title: 'MORE TO DO'),
            PrismSurface(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  if (companions.any((c) => !c.isEgg))
                    PrismListRow(
                      leading: const Icon(Icons.photo_camera_outlined),
                      title: const Text('Photo mode'),
                      subtitle: const Text('Pose companions and add stickers'),
                      showChevron: true,
                      onTap: () => pushPage<void>(
                        context,
                        PhotoModeScreen(
                          companionIds: [
                            for (final c
                                in companions.where((c) => !c.isEgg).take(3))
                              c.id,
                          ],
                        ),
                      ),
                    ),
                  PrismListRow(
                    leading: const Icon(Icons.sports_esports_outlined),
                    title: const Text('Games'),
                    subtitle: const Text('Play with your companions nearby'),
                    showChevron: true,
                    onTap: () => context.push(AppRoutePaths.games),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Makes and opens a recap for the current [period] in one tap.
Future<void> quickWrap(
  BuildContext context,
  WidgetRef ref,
  WrapPeriod period,
) async {
  final (from, to) = periodRange(
    period,
    DateTime.now(),
    seasons: ref.read(wrapSettingsProvider).seasons,
  );
  await pushPage<void>(
    context,
    WrapCreateScreen(period: period, from: from, to: to, autoGenerate: true),
  );
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final String emoji, title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PrismSurface(
      onTap: onTap,
      semanticLabel: title,
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 34)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Home cards

/// Home: a memory worth revisiting today.
class MemoryOfDayHomeCard extends ConsumerWidget {
  const MemoryOfDayHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = ref.watch(memoryOfTheDayProvider);
    if (e == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return PrismSurface(
      padding: const EdgeInsets.all(10),
      onTap: () => _openMemory(context, e),
      child: Row(
        children: [
          _memoryVisual(e, 56),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.onThisDay
                      ? 'On this day · ${e.at.year}'
                      : 'Memory of the day',
                  style: theme.textTheme.labelSmall,
                ),
                Text(
                  e.title,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  DateFormat.yMMMd().format(e.at),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Home: the latest recap, with one-tap weekly and monthly highlights.
class WrappedHomeCard extends ConsumerWidget {
  const WrappedHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(wrapSnapshotsProvider).firstOrNull;
    final theme = Theme.of(context);
    final cards = latest == null
        ? const <WrapCard>[]
        : latest.style.arrange(latest.cards);
    return PrismSurface(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          if (latest != null && cards.isNotEmpty)
            GestureDetector(
              onTap: () =>
                  pushPage<void>(context, WrapPlayerScreen.snapshot(latest)),
              child: SizedBox(
                width: 48,
                child: IgnorePointer(
                  child: WrapCardView(
                    card: cards.first,
                    style: latest.style,
                    animateFigures: false,
                  ),
                ),
              ),
            )
          else
            const Text('🎁', style: TextStyle(fontSize: 30)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  latest == null ? 'Your highlights' : 'Latest recap',
                  style: theme.textTheme.labelSmall,
                ),
                Text(
                  latest?.title ?? 'See your week or month at a glance',
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    PrismChip(
                      label: 'This week',
                      selected: false,
                      onTap: () => quickWrap(context, ref, WrapPeriod.weekly),
                    ),
                    PrismChip(
                      label: 'This month',
                      selected: false,
                      onTap: () => quickWrap(context, ref, WrapPeriod.monthly),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'All recaps',
            icon: const Icon(Icons.chevron_right),
            onPressed: () => context.push(AppRoutePaths.wrapped),
          ),
        ],
      ),
    );
  }
}

/// Home: latest stamps and the featured passport.
class StampsHomeCard extends ConsumerWidget {
  const StampsHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passports = ref.watch(passportsProvider);
    if (passports.isEmpty) return const SizedBox.shrink();
    final featured =
        passports.where((p) => p.pinned).firstOrNull ??
        passports.where((p) => p.favorite).firstOrNull ??
        passports.first;
    final stamps = [...ref.watch(allStampsProvider)]
      ..sort((a, b) => b.at.compareTo(a.at));
    final theme = Theme.of(context);
    return PrismSurface(
      padding: const EdgeInsets.all(10),
      onTap: () =>
          pushPage<void>(context, PassportBookScreen(passportId: featured.id)),
      onLongPress: () => context.push(AppRoutePaths.passports),
      child: Row(
        children: [
          PassportCoverView(
            cover: featured.cover,
            name: featured.name,
            width: 44,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  featured.name,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  stamps.isEmpty
                      ? 'No stamps yet'
                      : '${stamps.length} stamps · latest: ${stamps.first.title}',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          for (final s in stamps.take(3))
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: StampView(design: s.design, size: 40),
            ),
        ],
      ),
    );
  }
}

/// Home: a peek into a habitat with whoever lives there.
class HabitatHomeCard extends ConsumerWidget {
  const HabitatHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitats = ref.watch(habitatsProvider);
    if (habitats.isEmpty) return const SizedBox.shrink();
    final shown = ref.watch(shownCompanionProvider(currentFronterId(ref)));
    final h =
        habitats.where((x) => x.id == shown?.habitatId).firstOrNull ??
        habitats.first;
    final residents = ref
        .watch(companionsProvider)
        .where((c) => c.habitatId == h.id && !c.isEgg)
        .take(3)
        .toList();
    return GestureDetector(
      onTap: () => context.push(AppRoutePaths.companions),
      child: Semantics(
        button: true,
        label: 'Habitat: ${h.name}',
        child: SizedBox(
          height: 120,
          child: HabitatScene(
            env: h.env,
            time: h.timeOfDay,
            weather: h.weather,
            lighting: h.lighting,
            items: h.items,
            animate: false,
            borderRadius: 16,
            children: [
              for (final (i, c) in residents.indexed)
                Positioned(
                  left: 24.0 + i * 60,
                  bottom: 8,
                  child: CompanionFigure(
                    companion: c,
                    size: 60,
                    animate: false,
                    showParticles: false,
                  ),
                ),
              Positioned(
                left: 10,
                top: 8,
                child: Text(
                  h.name,
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
    );
  }
}
