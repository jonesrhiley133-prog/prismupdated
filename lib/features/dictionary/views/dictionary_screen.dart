import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:prism_plurality/features/settings/views/feature_data_screen.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/dictionary/utils/dictionary_import.dart';
import 'package:prism_plurality/features/dictionary/views/dictionary_import_flow.dart';
import 'package:prism_plurality/features/dictionary/views/term_editor_sheet.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/features/trackers/widgets/tracker_widgets.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/app_shell.dart';
import 'package:prism_plurality/shared/widgets/clamped_body.dart';
import 'package:prism_plurality/shared/widgets/empty_state.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_dialog.dart';
import 'package:prism_plurality/shared/widgets/prism_loading_state.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar_action.dart';

/// Case-insensitive match on term, aliases, definition and tags.
bool termMatches(TrackerRecord t, String query) {
  final q = normalizeTerm(query);
  if (q.isEmpty) return true;
  return normalizeTerm(t.title).contains(q) ||
      t.strings(DictField.aliases).any((a) => normalizeTerm(a).contains(q)) ||
      (t.body ?? '').toLowerCase().contains(q) ||
      t.tags.any((x) => x.toLowerCase().contains(q));
}

/// First letter used for A–Z grouping ("#" for non-letters).
String termInitial(String term) {
  final t = term.trim();
  if (t.isEmpty) return '#';
  final c = t.characters.first.toUpperCase();
  return RegExp(r'\p{L}', unicode: true).hasMatch(c) ? c : '#';
}

class DictionaryScreen extends ConsumerStatefulWidget {
  const DictionaryScreen({super.key, this.showBackButton = false});

  final bool showBackButton;

  @override
  ConsumerState<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends ConsumerState<DictionaryScreen> {
  final _search = TextEditingController();
  String? _collection;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(trackerKindProvider(TrackerKind.dictTerm));
    final collections =
        ref.watch(trackerKindProvider(TrackerKind.dictCollection)).value ??
        const <TrackerRecord>[];
    final sortedCollections = [...collections]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: l10n.navDictionary,
        showBackButton: widget.showBackButton,
        actions: [FeatureDataAction(featureId: 'dictionary'), 
          PrismTopBarAction(
            icon: AppIcons.navImport,
            tooltip: l10n.dictImportTitle,
            onPressed: () => openDictionaryImport(context),
          ),
          PrismTopBarAction(
            icon: AppIcons.add,
            tooltip: l10n.dictNewTerm,
            onPressed: () => showTermEditor(context, collectionId: _collection),
          ),
        ],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: async.when(
        loading: () => const PrismLoadingState(),
        error: (e, _) => Center(child: Text(l10n.errorWithDetail(e))),
        data: (terms) {
          if (terms.isEmpty) {
            return ClampedBody(
              child: EmptyState(
                icon: Icon(AppIcons.navDictionary),
                title: l10n.dictEmptyTitle,
                subtitle: l10n.dictEmptySubtitle,
                actionLabel: l10n.dictImportTitle,
                onAction: () => openDictionaryImport(context),
              ),
            );
          }
          final countBy = <String?, int>{};
          for (final t in terms) {
            final c = t.str(DictField.collection);
            countBy[c] = (countBy[c] ?? 0) + 1;
          }
          final shown =
              [
                for (final t in terms)
                  if (termMatches(t, _search.text) &&
                      (_collection == null ||
                          t.str(DictField.collection) == _collection))
                    t,
              ]..sort(
                (a, b) =>
                    a.title.toLowerCase().compareTo(b.title.toLowerCase()),
              );
          final imported = terms
              .where((t) => t.str(DictField.source) != null)
              .length;
          final children = <Widget>[
            TrackerStatGrid(
              children: [
                TrackerStatTile(
                  label: l10n.dictStatTerms,
                  value: '${terms.length}',
                  icon: AppIcons.navDictionary,
                ),
                TrackerStatTile(
                  label: l10n.dictStatCollections,
                  value: '${collections.length}',
                  icon: AppIcons.folderOutlined,
                  onTap: () => _manageCollections(context),
                ),
                TrackerStatTile(
                  label: l10n.dictStatImported,
                  value: '$imported',
                  icon: AppIcons.globe,
                ),
                TrackerStatTile(
                  label: l10n.dictStatOwn,
                  value: '${terms.length - imported}',
                  icon: AppIcons.edit,
                ),
              ],
            ),
            const SizedBox(height: 12),
            PrismTextField(
              controller: _search,
              hintText: l10n.dictSearch,
              prefixIcon: Icon(AppIcons.search),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: PrismChip(
                      label: l10n.dictAllTerms(terms.length),
                      selected: _collection == null,
                      onTap: () => setState(() => _collection = null),
                    ),
                  ),
                  for (final c in sortedCollections)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: PrismChip(
                        label: '${c.title} · ${countBy[c.id] ?? 0}',
                        selected: _collection == c.id,
                        selectedColor: Color(
                          c.integer(DictField.color) ?? trackerPalette.first,
                        ),
                        onTap: () => setState(
                          () => _collection = _collection == c.id ? null : c.id,
                        ),
                      ),
                    ),
                  PrismButton(
                    label: l10n.dictManageCollections,
                    icon: AppIcons.dashboardCustomize,
                    density: PrismControlDensity.compact,
                    onPressed: () => _manageCollections(context),
                  ),
                ],
              ),
            ),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text(l10n.dictNoMatches)),
              ),
          ];
          String? letter;
          final colById = {for (final c in collections) c.id: c};
          for (final t in shown) {
            final l = termInitial(t.title);
            if (l != letter) {
              letter = l;
              children.add(TrackerLabel(l));
            }
            children.add(
              _TermTile(
                term: t,
                collection: colById[t.str(DictField.collection)],
              ),
            );
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

  void _manageCollections(BuildContext context) => PrismSheet.show(
    context: context,
    title: context.l10n.dictManageCollections,
    builder: (_) => const _CollectionsSheet(),
  );
}

class _TermTile extends StatelessWidget {
  const _TermTile({required this.term, this.collection});

  final TrackerRecord term;
  final TrackerRecord? collection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aliases = term.strings(DictField.aliases);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: PrismSurface(
        onTap: () => PrismSheet.showFullScreen(
          context: context,
          builder: (context, scroll) =>
              TermDetailSheet(termId: term.id, scrollController: scroll),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(term.title, style: theme.textTheme.titleMedium),
                ),
                if (term.isPrivate) Icon(AppIcons.privateLock, size: 14),
                if (term.str(DictField.source) != null) ...[
                  const SizedBox(width: 4),
                  Icon(AppIcons.globe, size: 14),
                ],
                if (collection != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Color(
                        collection!.integer(DictField.color) ??
                            trackerPalette.first,
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
            if (aliases.isNotEmpty)
              Text(
                aliases.join(', '),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (term.body != null)
              PrivateReveal(
                isPrivate: term.isPrivate,
                child: Text(
                  term.body!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class TermDetailSheet extends ConsumerWidget {
  const TermDetailSheet({
    super.key,
    required this.termId,
    this.scrollController,
  });

  final String termId;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final terms =
        ref.watch(trackerKindProvider(TrackerKind.dictTerm)).value ?? const [];
    final t = terms.where((x) => x.id == termId).firstOrNull;
    if (t == null) {
      return SafeArea(
        child: Column(
          children: [
            PrismSheetTopBar(title: l10n.navDictionary),
            Expanded(child: Center(child: Text(l10n.dictTermGone))),
          ],
        ),
      );
    }
    final col =
        (ref.watch(trackerKindProvider(TrackerKind.dictCollection)).value ??
                const <TrackerRecord>[])
            .where((c) => c.id == t.str(DictField.collection))
            .firstOrNull;
    final url = t.str(DictField.sourceUrl);
    final examples = t.strings(DictField.examples);
    final aliases = t.strings(DictField.aliases);
    final related = [
      for (final o in terms)
        if (o.id != t.id &&
            ((t.body ?? '').toLowerCase().contains(normalizeTerm(o.title)) &&
                o.title.length > 2))
          o,
    ].take(8).toList();
    return SafeArea(
      child: Column(
        children: [
          PrismSheetTopBar(title: t.title),
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
                      onPressed: () => showTermEditor(context, editing: t),
                    ),
                    PrismButton(
                      label: l10n.dictCopy,
                      icon: AppIcons.copy,
                      density: PrismControlDensity.compact,
                      onPressed: () => Clipboard.setData(
                        ClipboardData(text: '${t.title}: ${t.body ?? ''}'),
                      ),
                    ),
                    PrismButton(
                      label: l10n.trackerDelete,
                      icon: AppIcons.delete,
                      tone: PrismButtonTone.destructive,
                      density: PrismControlDensity.compact,
                      onPressed: () async {
                        final ok = await PrismDialog.confirm(
                          context: context,
                          title: l10n.dictDeleteTitle(t.title),
                          confirmLabel: l10n.trackerDelete,
                          cancelLabel: l10n.cancel,
                          destructive: true,
                        );
                        if (!ok) return;
                        await ref
                            .read(trackerNotifierProvider.notifier)
                            .delete(t.id);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (t.str(DictField.pronunciation) != null)
                  Text(
                    '/${t.str(DictField.pronunciation)}/',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (aliases.isNotEmpty)
                  Text(l10n.dictAlsoKnownAs(aliases.join(', '))),
                if (col != null) Text(l10n.dictInCollection(col.title)),
                const SizedBox(height: 12),
                PrivateReveal(
                  isPrivate: t.isPrivate,
                  child: SelectableText(
                    t.body ?? l10n.dictNoDefinition,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                if (examples.isNotEmpty) ...[
                  TrackerLabel(l10n.dictExamples),
                  for (final e in examples)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '“$e”',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
                if (t.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  TagWrap(tags: t.tags),
                ],
                if (related.isNotEmpty) ...[
                  TrackerLabel(l10n.dictMentions),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final r in related)
                        PrismChip(
                          label: r.title,
                          selected: false,
                          onTap: () => PrismSheet.showFullScreen(
                            context: context,
                            builder: (context, scroll) => TermDetailSheet(
                              termId: r.id,
                              scrollController: scroll,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                if (url != null) ...[
                  TrackerLabel(l10n.dictSource),
                  PrismButton(
                    label:
                        t.str(DictField.source) ??
                        Uri.tryParse(url)?.host ??
                        url,
                    icon: AppIcons.globe,
                    density: PrismControlDensity.compact,
                    onPressed: () => launchUrl(
                      Uri.parse(url),
                      mode: LaunchMode.externalApplication,
                    ),
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

class _CollectionsSheet extends ConsumerStatefulWidget {
  const _CollectionsSheet();

  @override
  ConsumerState<_CollectionsSheet> createState() => _CollectionsSheetState();
}

class _CollectionsSheetState extends ConsumerState<_CollectionsSheet> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _add(int count) async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    await ref
        .read(trackerNotifierProvider.notifier)
        .create(
          kind: TrackerKind.dictCollection,
          title: name,
          sortOrder: count,
          fields: {
            DictField.color: trackerPalette[count % trackerPalette.length],
          },
        );
    _name.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cols = [
      ...ref.watch(trackerKindProvider(TrackerKind.dictCollection)).value ??
          const <TrackerRecord>[],
    ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final terms =
        ref.watch(trackerKindProvider(TrackerKind.dictTerm)).value ?? const [];
    final n = ref.read(trackerNotifierProvider.notifier);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: PrismTextField(
                controller: _name,
                labelText: l10n.dictNewCollection,
                onSubmitted: (_) => _add(cols.length),
              ),
            ),
            const SizedBox(width: 8),
            PrismButton(
              label: l10n.add,
              tone: PrismButtonTone.filled,
              onPressed: () => _add(cols.length),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (cols.isEmpty) Text(l10n.dictNoCollectionsYet),
        for (var i = 0; i < cols.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: PrismSurface(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  InkWell(
                    onTap: () {
                      final cur =
                          cols[i].integer(DictField.color) ??
                          trackerPalette.first;
                      final next =
                          trackerPalette[(trackerPalette.indexOf(cur) + 1) %
                              trackerPalette.length];
                      n.save(cols[i].withFields({DictField.color: next}));
                    },
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Color(
                          cols[i].integer(DictField.color) ??
                              trackerPalette.first,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${cols[i].title} · ${terms.where((t) => t.str(DictField.collection) == cols[i].id).length}',
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.trackerMoveUp,
                    icon: Icon(AppIcons.arrowUpward, size: 18),
                    onPressed: i == 0
                        ? null
                        : () async {
                            await n.save(cols[i].copyWith(sortOrder: i - 1));
                            await n.save(cols[i - 1].copyWith(sortOrder: i));
                          },
                  ),
                  IconButton(
                    tooltip: l10n.trackerRename,
                    icon: Icon(AppIcons.edit, size: 18),
                    onPressed: () async {
                      final c = TextEditingController(text: cols[i].title);
                      final ok = await PrismDialog.show<bool>(
                        context: context,
                        title: l10n.trackerRename,
                        builder: (_) =>
                            PrismTextField(controller: c, autofocus: true),
                        actions: [
                          PrismButton(
                            label: l10n.cancel,
                            onPressed: () => Navigator.of(
                              context,
                              rootNavigator: true,
                            ).pop(false),
                          ),
                          PrismButton(
                            label: l10n.save,
                            tone: PrismButtonTone.filled,
                            onPressed: () => Navigator.of(
                              context,
                              rootNavigator: true,
                            ).pop(true),
                          ),
                        ],
                      );
                      if (ok == true && c.text.trim().isNotEmpty) {
                        await n.save(cols[i].copyWith(title: c.text.trim()));
                      }
                      c.dispose();
                    },
                  ),
                  IconButton(
                    tooltip: l10n.trackerDelete,
                    icon: Icon(AppIcons.delete, size: 18),
                    onPressed: () async {
                      final ok = await PrismDialog.confirm(
                        context: context,
                        title: l10n.dictDeleteCollectionTitle(cols[i].title),
                        message: l10n.dictDeleteCollectionMessage,
                        confirmLabel: l10n.trackerDelete,
                        cancelLabel: l10n.cancel,
                        destructive: true,
                      );
                      if (!ok) return;
                      for (final t in terms.where(
                        (t) => t.str(DictField.collection) == cols[i].id,
                      )) {
                        await n.save(
                          t.withFields({DictField.collection: null}),
                        );
                      }
                      await n.delete(cols[i].id, children: false);
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
