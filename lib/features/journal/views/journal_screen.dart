import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/features/trackers/widgets/member_picker.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/journal/utils/journal_stats.dart';
import 'package:prism_plurality/features/journal/views/journal_editor_sheet.dart';
import 'package:prism_plurality/features/journal/views/journal_entry_sheet.dart';
import 'package:prism_plurality/features/mood/widgets/mood_level.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/features/trackers/widgets/tracker_widgets.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/app_shell.dart';
import 'package:prism_plurality/shared/widgets/clamped_body.dart';
import 'package:prism_plurality/shared/widgets/empty_state.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_loading_state.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar_action.dart';

enum _JournalFilter { all, pinned, private }

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key, this.showBackButton = false});

  final bool showBackButton;

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  final _search = TextEditingController();
  _JournalFilter _filter = _JournalFilter.all;
  String? _category;
  String? _tag;
  String? _member;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(trackerKindProvider(TrackerKind.journalEntry));
    final categories =
        ref.watch(trackerKindProvider(TrackerKind.journalCategory)).value ??
        const <TrackerRecord>[];
    final catById = {for (final c in categories) c.id: c};
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: l10n.navJournal,
        showBackButton: widget.showBackButton,
        actions: [
          PrismTopBarAction(
            icon: AppIcons.add,
            tooltip: l10n.journalNewEntry,
            onPressed: () => showJournalEditor(context, categoryId: _category),
          ),
        ],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: async.when(
        loading: () => const PrismLoadingState(),
        error: (e, _) => Center(child: Text(l10n.errorWithDetail(e))),
        data: (entries) {
          if (entries.isEmpty) {
            return ClampedBody(
              child: EmptyState(
                icon: Icon(AppIcons.navJournal),
                title: l10n.journalEmptyTitle,
                subtitle: l10n.journalEmptySubtitle,
                actionLabel: l10n.journalNewEntry,
                onAction: () => showJournalEditor(context),
              ),
            );
          }
          final stats = JournalStats.of(entries, DateTime.now());
          final shown = [
            for (final e in entries)
              if (journalMatches(e, _search.text) &&
                  (_filter != _JournalFilter.pinned || e.isPinned) &&
                  (_filter != _JournalFilter.private || e.isPrivate) &&
                  (_category == null ||
                      e.str(JournalField.category) == _category) &&
                  (_tag == null || e.tags.contains(_tag)) &&
                  (_member == null || e.memberId == _member))
                e,
          ];
          final pinned = [
            for (final e in shown)
              if (e.isPinned) e,
          ];
          final rest = [
            for (final e in shown)
              if (!e.isPinned) e,
          ];
          final locale = context.dateLocale;
          final children = <Widget>[
            TrackerStatGrid(
              children: [
                TrackerStatTile(
                  label: l10n.journalStatEntries,
                  value: '${stats.total}',
                  icon: AppIcons.navJournal,
                ),
                TrackerStatTile(
                  label: l10n.journalStatThisMonth,
                  value: '${stats.thisMonth}',
                  icon: AppIcons.calendarToday,
                ),
                TrackerStatTile(
                  label: l10n.journalStatStreak(stats.longestStreak),
                  value: l10n.journalDays(stats.currentStreak),
                  icon: AppIcons.navAchievements,
                ),
                TrackerStatTile(
                  label: l10n.journalStatMood,
                  value: stats.averageMood30 == null
                      ? '–'
                      : stats.averageMood30!.toStringAsFixed(1),
                  icon: AppIcons.heartOutline,
                ),
              ],
            ),
            const SizedBox(height: 12),
            PrismTextField(
              controller: _search,
              hintText: l10n.journalSearch,
              prefixIcon: Icon(AppIcons.search),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final f in _JournalFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: PrismChip(
                        label: switch (f) {
                          _JournalFilter.all => l10n.journalFilterAll,
                          _JournalFilter.pinned => l10n.trackerPinned,
                          _JournalFilter.private => l10n.trackerPrivate,
                        },
                        selected: _filter == f,
                        onTap: () => setState(() => _filter = f),
                      ),
                    ),
                  for (final c in categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: PrismChip(
                        label: c.title,
                        selected: _category == c.id,
                        selectedColor: Color(
                          c.integer(JournalField.color) ?? trackerPalette.first,
                        ),
                        onTap: () => setState(
                          () => _category = _category == c.id ? null : c.id,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            TrackerMemberFilter(
              value: _member,
              onChanged: (m) => setState(() => _member = m),
              onlyIds: {for (final e in entries) ?e.memberId},
            ),
            if (stats.topTags.isNotEmpty) ...[
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (t, n) in stats.topTags)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: PrismChip(
                          label: '#$t · $n',
                          selected: _tag == t,
                          variant: PrismChipVariant.inline,
                          onTap: () =>
                              setState(() => _tag = _tag == t ? null : t),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text(l10n.journalNoMatches)),
              ),
            if (pinned.isNotEmpty) ...[
              TrackerLabel(l10n.trackerPinned),
              for (final e in pinned) _EntryCard(entry: e, catById: catById),
            ],
          ];
          String? month;
          for (final e in rest) {
            final d = e.occurredAt ?? e.createdAt;
            final m = DateFormat.yMMMM(locale).format(d);
            if (m != month) {
              month = m;
              children.add(TrackerLabel(m));
            }
            children.add(_EntryCard(entry: e, catById: catById));
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
                  constraints: const BoxConstraints(
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

class _EntryCard extends ConsumerWidget {
  const _EntryCard({required this.entry, required this.catById});

  final TrackerRecord entry;
  final Map<String, TrackerRecord> catById;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final author = memberNameFor(ref, entry.memberId);
    final cat = catById[entry.str(JournalField.category)];
    final mood = entry.integer(JournalField.mood);
    final d = entry.occurredAt ?? entry.createdAt;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PrismSurface(
        onTap: () => showJournalEntry(context, entry.id),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (cat != null) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Color(
                              cat.integer(JournalField.color) ??
                                  trackerPalette.first,
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          [
                            DateFormat.MMMEd(context.dateLocale).format(d),
                            DateFormat.jm(context.dateLocale).format(d),
                            ?cat?.title,
                            ?author,
                          ].join(' · '),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (entry.isPinned) ...[
                        const SizedBox(width: 4),
                        Icon(AppIcons.pin, size: 12),
                      ],
                      if (entry.isPrivate) ...[
                        const SizedBox(width: 4),
                        Icon(AppIcons.privateLock, size: 12),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  PrivateReveal(
                    isPrivate: entry.isPrivate,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title.isEmpty
                              ? l10n.journalUntitled
                              : entry.title,
                          style: theme.textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (entry.body != null)
                          Text(
                            entry.body!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        if (entry.tags.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          TagWrap(tags: entry.tags),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (mood != null) ...[
              const SizedBox(width: 8),
              MoodFace(level: mood, size: 30),
            ],
          ],
        ),
      ),
    );
  }
}
