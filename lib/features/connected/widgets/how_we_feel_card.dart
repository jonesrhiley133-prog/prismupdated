import 'package:prism_plurality/shared/theme/prism_shapes.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/mood/data/emotion_library.dart';
import 'package:prism_plurality/features/mood/providers/mood_providers.dart';
import 'package:prism_plurality/features/mood/utils/mood_stats.dart';
import 'package:prism_plurality/features/mood/widgets/mood_level.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';

/// "How We Feel": the last 7 days of system-wide mood at a glance, the
/// most-felt emotions, and how each member has been feeling.
class HowWeFeelCard extends ConsumerWidget {
  const HowWeFeelCard({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final entries = ref.watch(moodEntriesProvider).value ?? const [];
    final week = moodEntriesInLastDays(entries, 7);
    final prior = moodEntriesInLastDays(
      entries,
      14,
    ).where((e) => !week.contains(e)).toList();
    final summary = MoodSummary.of(week);
    final priorAvg = MoodSummary.of(prior).averageMood;
    final daily = dailyAverageMood(week);
    final members = ref.watch(allMemberListProvider).value ?? const <Member>[];
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    final today = moodDayKey(DateTime.now());
    final days = [
      for (var i = 6; i >= 0; i--)
        DateTime(today.year, today.month, today.day - i),
    ];

    String trend() {
      final a = summary.averageMood;
      if (a == null) return l10n.howWeFeelNoData;
      if (priorAvg == null) return l10n.howWeFeelAverage(a.toStringAsFixed(1));
      final diff = a - priorAvg;
      if (diff >= 0.4) return l10n.howWeFeelUp(a.toStringAsFixed(1));
      if (diff <= -0.4) return l10n.howWeFeelDown(a.toStringAsFixed(1));
      return l10n.howWeFeelSteady(a.toStringAsFixed(1));
    }

    final byMember =
        summary.averageMoodByMember.entries.where((e) => e.key != null).toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return PrismSurface(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.howWeFeelTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(trend(), style: theme.textTheme.bodyMedium),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final d in days)
                Expanded(
                  child: Column(
                    children: [
                      if (daily[d] != null)
                        MoodFace(level: daily[d]!, size: 28)
                      else
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            borderRadius: prismRound(context),
                            border: Border.all(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat.E(context.dateLocale).format(d),
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (summary.topEmotions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              l10n.howWeFeelTopEmotions(
                summary.topEmotions
                    .take(4)
                    .map((e) => emotionLabel(e.key))
                    .join(', '),
              ),
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (byMember.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: [
                for (final e in byMember.take(6))
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MoodFace(level: e.value, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        members
                                .firstWhereOrNull((m) => m.id == e.key)
                                ?.effectiveName(preferDisplayName: prefer) ??
                            '?',
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
