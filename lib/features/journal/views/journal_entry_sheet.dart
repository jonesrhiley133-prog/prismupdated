import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/journal/utils/journal_stats.dart';
import 'package:prism_plurality/features/journal/views/journal_editor_sheet.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/mood/widgets/mood_level.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/features/trackers/widgets/tracker_widgets.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_dialog.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';

Future<void> showJournalEntry(BuildContext context, String id) {
  return PrismSheet.showFullScreen(
    context: context,
    builder: (context, scroll) =>
        JournalEntrySheet(entryId: id, scrollController: scroll),
  );
}

/// Read view of one entry with edit, pin, version history and delete.
class JournalEntrySheet extends ConsumerWidget {
  const JournalEntrySheet({
    super.key,
    required this.entryId,
    this.scrollController,
  });

  final String entryId;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final entries =
        ref.watch(trackerKindProvider(TrackerKind.journalEntry)).value ??
        const <TrackerRecord>[];
    final entry = entries.where((e) => e.id == entryId).firstOrNull;
    if (entry == null) {
      return SafeArea(
        child: Column(
          children: [
            PrismSheetTopBar(title: l10n.navJournal),
            Expanded(child: Center(child: Text(l10n.journalEntryGone))),
          ],
        ),
      );
    }
    final categories =
        ref.watch(trackerKindProvider(TrackerKind.journalCategory)).value ??
        const <TrackerRecord>[];
    final cat = categories
        .where((c) => c.id == entry.str(JournalField.category))
        .firstOrNull;
    final member = (ref.watch(allMembersProvider).value ?? const [])
        .where((m) => m.id == entry.memberId)
        .firstOrNull;
    final mood = entry.integer(JournalField.mood);
    final history = journalHistory(entry);
    final d = entry.occurredAt ?? entry.createdAt;
    final locale = context.dateLocale;
    final n = ref.read(trackerNotifierProvider.notifier);

    return SafeArea(
      child: Column(
        children: [
          PrismSheetTopBar(title: DateFormat.yMMMMEEEEd(locale).format(d)),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    PrismButton(
                      label: l10n.edit,
                      icon: AppIcons.edit,
                      density: PrismControlDensity.compact,
                      onPressed: () =>
                          showJournalEditor(context, editing: entry),
                    ),
                    PrismButton(
                      label: entry.isPinned
                          ? l10n.trackerUnpin
                          : l10n.trackerPin,
                      icon: AppIcons.pin,
                      density: PrismControlDensity.compact,
                      onPressed: () =>
                          n.save(entry.copyWith(isPinned: !entry.isPinned)),
                    ),
                    PrismButton(
                      label: l10n.trackerDelete,
                      icon: AppIcons.delete,
                      tone: PrismButtonTone.destructive,
                      density: PrismControlDensity.compact,
                      onPressed: () async {
                        final ok = await PrismDialog.confirm(
                          context: context,
                          title: l10n.journalDeleteTitle,
                          message: l10n.journalDeleteMessage,
                          confirmLabel: l10n.trackerDelete,
                          cancelLabel: l10n.cancel,
                          destructive: true,
                        );
                        if (!ok) return;
                        await n.delete(entry.id);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                PrivateReveal(
                  isPrivate: entry.isPrivate,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (entry.str(JournalField.prompt) != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            entry.str(JournalField.prompt)!,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.title.isEmpty
                                  ? l10n.journalUntitled
                                  : entry.title,
                              style: theme.textTheme.headlineSmall,
                            ),
                          ),
                          if (mood != null) MoodFace(level: mood, size: 36),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          DateFormat.jm(locale).format(d),
                          ?cat?.title,
                          if (member != null) l10n.journalBy(member.name),
                        ].join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (entry.body != null)
                        SelectableText(
                          entry.body!,
                          style: theme.textTheme.bodyLarge,
                        ),
                      if (entry.tags.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        TagWrap(tags: entry.tags),
                      ],
                    ],
                  ),
                ),
                TrackerLabel(l10n.journalHistory(history.length)),
                if (history.isEmpty)
                  Text(
                    l10n.journalNoHistory,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                for (final r in history)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: PrismSurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  DateFormat.yMMMd(
                                    locale,
                                  ).add_jm().format(r.at),
                                  style: theme.textTheme.labelSmall,
                                ),
                              ),
                              PrismButton(
                                label: l10n.journalRestore,
                                density: PrismControlDensity.compact,
                                onPressed: () async {
                                  final now = DateTime.now();
                                  await n.save(
                                    withRevision(
                                      entry,
                                      entry.copyWith(
                                        title: r.title,
                                        body: r.body,
                                      ),
                                      now,
                                    ),
                                    now: now,
                                  );
                                },
                              ),
                            ],
                          ),
                          PrivateReveal(
                            isPrivate: entry.isPrivate,
                            child: Text(
                              [
                                if (r.title.isNotEmpty) r.title,
                                ?r.body,
                              ].join('\n'),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
