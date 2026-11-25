import 'package:prism_plurality/shared/theme/prism_shapes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/features/settings/views/feature_data_screen.dart';
import 'package:prism_plurality/features/achievements/providers/achievement_providers.dart';
import 'package:prism_plurality/features/achievements/utils/achievements.dart';
import 'package:prism_plurality/features/prism_social/social_share.dart';
import 'package:prism_plurality/shared/l10n/tr.dart';
import 'package:prism_plurality/features/trackers/widgets/tracker_widgets.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/app_shell.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_loading_state.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_segmented_control.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';

String achievementMetricLabel(AppLocalizations l10n, AchievementMetric m) =>
    switch (m) {
      AchievementMetric.members => l10n.achMetricMembers,
      AchievementMetric.frontSessions => l10n.achMetricFrontSessions,
      AchievementMetric.frontHours => l10n.achMetricFrontHours,
      AchievementMetric.sleepNights => l10n.achMetricSleepNights,
      AchievementMetric.moodCheckIns => l10n.achMetricMood,
      AchievementMetric.moodStreak => l10n.achMetricMoodStreak,
      AchievementMetric.journalEntries => l10n.achMetricJournal,
      AchievementMetric.journalStreak => l10n.achMetricJournalStreak,
      AchievementMetric.dictionaryTerms => l10n.achMetricTerms,
      AchievementMetric.habitCompletions => l10n.achMetricHabits,
      AchievementMetric.notes => l10n.achMetricNotes,
      AchievementMetric.pollVotes => l10n.achMetricVotes,
      AchievementMetric.contacts => l10n.achMetricContacts,
      AchievementMetric.cycleDays => l10n.achMetricCycle,
      AchievementMetric.placesVisited => l10n.achMetricPlaces,
      AchievementMetric.activeDays => l10n.achMetricActiveDays,
      AchievementMetric.gamesPlayed => l10n.localeName.startsWith('es') ? 'Partidas jugadas' : 'Games played',
      AchievementMetric.cozyMoments => l10n.localeName.startsWith('es') ? 'Momentos acogedores' : 'Cozy moments',
    };

String achievementCategoryLabel(AppLocalizations l10n, AchievementCategory c) =>
    switch (c) {
      AchievementCategory.system => l10n.achCatSystem,
      AchievementCategory.fronting => l10n.achCatFronting,
      AchievementCategory.wellbeing => l10n.achCatWellbeing,
      AchievementCategory.journal => l10n.achCatJournal,
      AchievementCategory.knowledge => l10n.achCatKnowledge,
      AchievementCategory.habits => l10n.achCatHabits,
      AchievementCategory.social => l10n.achCatSocial,
      AchievementCategory.consistency => l10n.achCatConsistency,
    };

String achievementTierLabel(AppLocalizations l10n, AchievementTier t) =>
    switch (t) {
      AchievementTier.bronze => l10n.achTierBronze,
      AchievementTier.silver => l10n.achTierSilver,
      AchievementTier.gold => l10n.achTierGold,
      AchievementTier.platinum => l10n.achTierPlatinum,
      AchievementTier.diamond => l10n.achTierDiamond,
    };

Color achievementTierColor(AchievementTier t) => switch (t) {
  AchievementTier.bronze => const Color(0xFFB8733D),
  AchievementTier.silver => const Color(0xFF9EA7B0),
  AchievementTier.gold => const Color(0xFFE0B021),
  AchievementTier.platinum => const Color(0xFF4FB3BF),
  AchievementTier.diamond => const Color(0xFF8C7BFF),
};

/// "Gold · Mood check-ins (50)".
String achievementTitle(AppLocalizations l10n, AchievementDef d) =>
    l10n.achTitle(
      achievementTierLabel(l10n, d.tier),
      achievementMetricLabel(l10n, d.metric),
      d.target,
    );

enum _AchView { progress, history }

class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key, this.showBackButton = false});

  final bool showBackButton;

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  _AchView _view = _AchView.progress;
  AchievementCategory? _category;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    ref.watch(achievementRecorderProvider);
    final async = ref.watch(achievementProgressProvider);
    return PrismPageScaffold(
      topBar: PrismTopBar(
        actions: [FeatureDataAction(featureId: 'achievements')],
        title: l10n.navAchievements,
        showBackButton: widget.showBackButton,
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: async.when(
        loading: () => const PrismLoadingState(),
        error: (e, _) => Center(child: Text(l10n.errorWithDetail(e))),
        data: (progress) {
          final unlocked = progress.where((p) => p.unlocked).length;
          final byMetric = <AchievementMetric, List<AchievementProgress>>{};
          for (final p in progress) {
            (byMetric[p.def.metric] ??= []).add(p);
          }
          final ladders = [
            for (final e in byMetric.entries)
              if (_category == null || e.value.first.def.category == _category)
                e.value,
          ];
          final history = [
            for (final p in progress)
              if (p.unlockedAt != null) p,
          ]..sort((a, b) => b.unlockedAt!.compareTo(a.unlockedAt!));
          final next = [
            for (final p in progress)
              if (!p.unlocked) p,
          ]..sort((a, b) => b.fraction.compareTo(a.fraction));
          final children = <Widget>[
            TrackerStatGrid(
              children: [
                TrackerStatTile(
                  label: l10n.achUnlocked,
                  value: '$unlocked / ${progress.length}',
                  icon: AppIcons.navAchievements,
                ),
                TrackerStatTile(
                  label: l10n.achComplete,
                  value: '${(unlocked * 100 / progress.length).round()}%',
                ),
                for (final t in [AchievementTier.gold, AchievementTier.diamond])
                  TrackerStatTile(
                    label: achievementTierLabel(l10n, t),
                    value:
                        '${progress.where((p) => p.unlocked && p.def.tier == t).length}',
                    color: achievementTierColor(t),
                    icon: AppIcons.navAchievementsActive,
                  ),
              ],
            ),
            if (next.isNotEmpty) ...[
              TrackerLabel(l10n.achAlmostThere),
              for (final p in next.take(3)) _NextTile(p: p),
            ],
            const SizedBox(height: 12),
            PrismSegmentedControl<_AchView>(
              segments: [
                PrismSegment(value: _AchView.progress, label: l10n.achProgress),
                PrismSegment(
                  value: _AchView.history,
                  label: l10n.achHistory(history.length),
                ),
              ],
              selected: _view,
              onChanged: (v) => setState(() => _view = v),
            ),
            const SizedBox(height: 8),
          ];
          if (_view == _AchView.progress) {
            children.add(
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: PrismChip(
                        label: l10n.journalFilterAll,
                        selected: _category == null,
                        onTap: () => setState(() => _category = null),
                      ),
                    ),
                    for (final c in AchievementCategory.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: PrismChip(
                          label: achievementCategoryLabel(l10n, c),
                          selected: _category == c,
                          onTap: () => setState(() => _category = c),
                        ),
                      ),
                  ],
                ),
              ),
            );
            children.add(const SizedBox(height: 8));
            for (final l in ladders) {
              children.add(_LadderCard(ladder: l));
            }
          } else {
            if (history.isEmpty) {
              children.add(
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: Text(l10n.achNoHistory)),
                ),
              );
            }
            for (final p in history) {
              children.add(
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: PrismSurface(
                    child: Row(
                      children: [
                        _Medal(tier: p.def.tier, on: true),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(achievementTitle(l10n, p.def)),
                              Text(
                                DateFormat.yMMMd(
                                  context.dateLocale,
                                ).add_jm().format(p.unlockedAt!),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        ShareToSocialButton(
                          title: achievementTitle(l10n, p.def),
                          source: tr(context, 'Achievement', 'Logro'),
                          details: [
                            (tr(context, 'Tier', 'Nivel'), '${p.def.tier.name[0].toUpperCase()}${p.def.tier.name.substring(1)}'),
                            (tr(context, 'Unlocked', 'Desbloqueado'), DateFormat.yMMMd(context.dateLocale).format(p.unlockedAt!)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
          }
          return ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              NavBarInset.of(context) + 24,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: PrismTokens.contentMaxWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Medal extends StatelessWidget {
  const _Medal({required this.tier, required this.on, this.size = 36});

  final AchievementTier tier;
  final bool on;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = achievementTierColor(tier);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: prismRound(context),
        color: on ? c.withValues(alpha: 0.2) : Colors.transparent,
        border: Border.all(
          color: on ? c : Theme.of(context).colorScheme.outlineVariant,
          width: 2,
        ),
      ),
      child: Icon(
        on ? AppIcons.navAchievementsActive : AppIcons.navAchievements,
        size: size * 0.5,
        color: on ? c : Theme.of(context).colorScheme.outline,
      ),
    );
  }
}

class _NextTile extends StatelessWidget {
  const _NextTile({required this.p});

  final AchievementProgress p;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: PrismSurface(
        child: Row(
          children: [
            _Medal(tier: p.def.tier, on: false, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(achievementTitle(l10n, p.def)),
                  const SizedBox(height: 4),
                  TrackerBar(
                    value: p.fraction,
                    color: achievementTierColor(p.def.tier),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.achProgressOf(p.current, p.def.target),
                    style: Theme.of(context).textTheme.bodySmall,
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

class _LadderCard extends StatelessWidget {
  const _LadderCard({required this.ladder});

  final List<AchievementProgress> ladder;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final first = ladder.first;
    final next = ladder.where((p) => !p.unlocked).firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PrismSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    achievementMetricLabel(l10n, first.def.metric),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${first.current}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            Text(
              achievementCategoryLabel(l10n, first.def.category),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                for (final p in ladder)
                  Tooltip(
                    message: p.unlockedAt != null
                        ? l10n.achUnlockedOn(
                            achievementTitle(l10n, p.def),
                            DateFormat.yMMMd(
                              context.dateLocale,
                            ).format(p.unlockedAt!),
                          )
                        : achievementTitle(l10n, p.def),
                    child: Column(
                      children: [
                        _Medal(tier: p.def.tier, on: p.unlocked),
                        const SizedBox(height: 2),
                        Text(
                          NumberFormat.compact().format(p.def.target),
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (next != null) ...[
              const SizedBox(height: 10),
              TrackerBar(
                value: next.fraction,
                color: achievementTierColor(next.def.tier),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.achNextTier(
                  achievementTierLabel(l10n, next.def.tier),
                  next.def.target - next.current,
                ),
                style: theme.textTheme.bodySmall,
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.achLadderComplete,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
