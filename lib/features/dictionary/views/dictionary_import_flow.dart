import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/core/services/files/prism_file_dialog_service.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/dictionary/utils/dictionary_import.dart';
import 'package:prism_plurality/features/import_center/widgets/import_steps_header.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/features/trackers/widgets/tracker_widgets.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/info_banner.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_checkbox_row.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_segmented_control.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/shared/widgets/prism_switch_row.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';

final wikiClientProvider = Provider<WikiClient>((ref) => WikiClient());

enum DictImportSource { wiki, file, paste }

enum TermDuplicateAction { skip, replace, keepBoth }

Future<void> openDictionaryImport(BuildContext context) => Navigator.of(
  context,
  rootNavigator: true,
).push(MaterialPageRoute<void>(builder: (_) => const DictionaryImportFlow()));

class DictionaryImportResult {
  const DictionaryImportResult({
    this.created = 0,
    this.replaced = 0,
    this.skipped = 0,
    this.collectionsCreated = 0,
  });

  final int created;
  final int replaced;
  final int skipped;
  final int collectionsCreated;
}

/// Writes [chosen] candidates. A null [collectionId] with
/// [useSourceCategories] files each term under a collection named after its
/// source category, creating collections as needed.
Future<DictionaryImportResult> importTerms({
  required TrackerNotifier notifier,
  required List<TermCandidate> chosen,
  required List<TrackerRecord> existingTerms,
  required List<TrackerRecord> existingCollections,
  required TermDuplicateAction Function(TermCandidate) actionFor,
  String? collectionId,
  bool useSourceCategories = false,
}) async {
  final index = indexTerms(existingTerms);
  final collections = {
    for (final c in existingCollections) normalizeTerm(c.title): c.id,
  };
  var created = 0, replaced = 0, skipped = 0, newCollections = 0;
  for (final c in chosen) {
    if (!c.isValid) {
      skipped++;
      continue;
    }
    var target = collectionId;
    if (target == null && useSourceCategories && c.category != null) {
      final key = normalizeTerm(c.category!);
      target = collections[key];
      if (target == null) {
        final col = await notifier.create(
          kind: TrackerKind.dictCollection,
          title: c.category!,
          sortOrder: existingCollections.length + newCollections,
          fields: {
            DictField.color:
                trackerPalette[(existingCollections.length + newCollections) %
                    trackerPalette.length],
          },
        );
        collections[key] = target = col.id;
        newCollections++;
      }
    }
    final fields = <String, Object?>{
      DictField.collection: target,
      DictField.aliases: c.aliases.isEmpty ? null : c.aliases,
      DictField.source: c.source,
      DictField.sourceUrl: c.sourceUrl,
    };
    final dup = findDuplicateTerm(c, index);
    if (dup != null) {
      switch (actionFor(c)) {
        case TermDuplicateAction.skip:
          skipped++;
          continue;
        case TermDuplicateAction.replace:
          await notifier.save(
            dup.copyWith(body: c.definition).withFields(fields),
          );
          replaced++;
          continue;
        case TermDuplicateAction.keepBoth:
          break;
      }
    }
    final rec = await notifier.create(
      kind: TrackerKind.dictTerm,
      title: c.term,
      body: c.definition,
      fields: fields,
    );
    index.putIfAbsent(normalizeTerm(c.term), () => rec);
    created++;
  }
  return DictionaryImportResult(
    created: created,
    replaced: replaced,
    skipped: skipped,
    collectionsCreated: newCollections,
  );
}

class DictionaryImportFlow extends ConsumerStatefulWidget {
  const DictionaryImportFlow({super.key});

  @override
  ConsumerState<DictionaryImportFlow> createState() =>
      _DictionaryImportFlowState();
}

class _DictionaryImportFlowState extends ConsumerState<DictionaryImportFlow> {
  ImportStep _step = ImportStep.select;
  DictImportSource _source = DictImportSource.wiki;
  final _url = TextEditingController();
  final _paste = TextEditingController();
  bool _wholeCategory = true;
  String? _error;
  bool _loading = false;
  (int, int)? _progress;
  List<TermCandidate> _candidates = const [];
  final Set<String> _selected = {};
  final Map<String, TermDuplicateAction> _actions = {};
  TermDuplicateAction _defaultAction = TermDuplicateAction.skip;
  String? _collectionId;
  bool _useSourceCategories = true;
  DictionaryImportResult? _result;

  @override
  void dispose() {
    _url.dispose();
    _paste.dispose();
    super.dispose();
  }

  void _setCandidates(List<TermCandidate> list) {
    setState(() {
      _candidates = list;
      _selected
        ..clear()
        ..addAll([
          for (final c in list)
            if (c.isValid) c.key,
        ]);
      _actions.clear();
      _error = list.isEmpty ? context.l10n.dictImportNothingFound : null;
      if (list.isNotEmpty) _step = ImportStep.preview;
    });
  }

  String _wikiError(String code) => switch (code) {
    'network' => context.l10n.dictWikiErrorNetwork,
    'not_found' => context.l10n.dictWikiErrorNotFound,
    'empty_category' => context.l10n.dictWikiErrorEmptyCategory,
    _ => context.l10n.dictWikiErrorNotWiki,
  };

  Future<void> _load() async {
    setState(() {
      _error = null;
      _loading = true;
      _progress = null;
    });
    try {
      switch (_source) {
        case DictImportSource.wiki:
          final target = parseWikiUrl(_url.text);
          if (target == null) {
            setState(() => _error = context.l10n.dictWikiErrorUrl);
            return;
          }
          final client = ref.read(wikiClientProvider);
          List<String> titles;
          String? category;
          if (target.category != null && _wholeCategory) {
            category = target.category;
            titles = await client.categoryMembers(
              target.origin,
              target.category!,
            );
          } else if (target.page != null) {
            titles = [target.page!];
          } else {
            setState(() => _error = context.l10n.dictWikiErrorUrl);
            return;
          }
          final list = await client.fetchTerms(
            target.origin,
            titles,
            category: category,
            onProgress: (d, t) {
              if (mounted) setState(() => _progress = (d, t));
            },
          );
          if (mounted) _setCandidates(list);
        case DictImportSource.file:
          final file = await ref
              .read(prismFileDialogServiceProvider)
              .pickFile(allowedExtensions: const ['json', 'csv', 'tsv', 'txt']);
          if (file == null) return;
          final bytes = await file.readAsBytes();
          if (bytes.length > 20 * 1024 * 1024) {
            setState(() => _error = context.l10n.importFileTooLarge);
            return;
          }
          _setCandidates(
            parseDictionaryText(
              utf8.decode(bytes, allowMalformed: true),
              sourceName: file.name,
            ),
          );
        case DictImportSource.paste:
          _setCandidates(parseDictionaryText(_paste.text));
      }
    } on WikiImportException catch (e) {
      if (mounted) setState(() => _error = _wikiError(e.code));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _import() async {
    setState(() => _step = ImportStep.importing);
    final terms =
        ref.read(trackerKindProvider(TrackerKind.dictTerm)).value ?? const [];
    final cols =
        ref.read(trackerKindProvider(TrackerKind.dictCollection)).value ??
        const [];
    final result = await importTerms(
      notifier: ref.read(trackerNotifierProvider.notifier),
      chosen: [
        for (final c in _candidates)
          if (_selected.contains(c.key)) c,
      ],
      existingTerms: terms,
      existingCollections: cols,
      actionFor: (c) => _actions[c.key] ?? _defaultAction,
      collectionId: _collectionId,
      useSourceCategories: _collectionId == null && _useSourceCategories,
    );
    if (mounted) {
      setState(() {
        _result = result;
        _step = ImportStep.done;
      });
    }
  }

  String _errorLabel(String code) => switch (code) {
    'missing_term' => context.l10n.dictErrorMissingTerm,
    'missing_definition' => context.l10n.dictErrorMissingDefinition,
    _ => context.l10n.dictErrorFetchFailed,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PrismPageScaffold(
      topBar: PrismTopBar(title: l10n.dictImportTitle, showBackButton: true),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: PrismTokens.contentMaxWidth,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: ImportStepsHeader(current: _step),
              ),
              Expanded(child: _body(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    switch (_step) {
      case ImportStep.select:
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PrismSegmentedControl<DictImportSource>(
              segments: [
                PrismSegment(
                  value: DictImportSource.wiki,
                  label: l10n.dictSourceWiki,
                ),
                PrismSegment(
                  value: DictImportSource.file,
                  label: l10n.dictSourceFile,
                ),
                PrismSegment(
                  value: DictImportSource.paste,
                  label: l10n.dictSourcePaste,
                ),
              ],
              selected: _source,
              onChanged: (s) => setState(() {
                _source = s;
                _error = null;
              }),
            ),
            const SizedBox(height: 16),
            if (_source == DictImportSource.wiki) ...[
              Text(l10n.dictWikiHelp, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              PrismTextField(
                controller: _url,
                labelText: l10n.dictWikiUrl,
                hintText: 'https://example.fandom.com/wiki/Category:Terms',
                keyboardType: TextInputType.url,
                prefixIcon: Icon(AppIcons.globe),
              ),
              const SizedBox(height: 8),
              PrismSwitchRow(
                title: l10n.dictWikiWholeCategory,
                subtitle: l10n.dictWikiWholeCategoryHelp(
                  WikiClient.maxCategoryPages,
                ),
                value: _wholeCategory,
                onChanged: (v) => setState(() => _wholeCategory = v),
              ),
            ],
            if (_source == DictImportSource.file)
              Text(l10n.dictFileHelp, style: theme.textTheme.bodyMedium),
            if (_source == DictImportSource.paste) ...[
              Text(l10n.dictPasteHelp, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              PrismTextField(
                controller: _paste,
                labelText: l10n.dictPasteLabel,
                hintText: 'Fronting: being in control of the body.',
                keyboardType: TextInputType.multiline,
                minLines: 6,
                maxLines: 16,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              InfoBanner(
                icon: AppIcons.errorOutline,
                iconColor: theme.colorScheme.error,
                title: l10n.dictImportProblem,
                message: _error!,
              ),
            ],
            if (_progress != null) ...[
              const SizedBox(height: 12),
              Text(l10n.dictWikiFetching(_progress!.$1, _progress!.$2)),
              const SizedBox(height: 6),
              TrackerBar(value: _progress!.$1 / _progress!.$2),
            ],
            const SizedBox(height: 16),
            PrismButton(
              label: _source == DictImportSource.file
                  ? l10n.dictChooseFile
                  : l10n.dictPreview,
              tone: PrismButtonTone.filled,
              isLoading: _loading,
              enabled: !_loading,
              onPressed: _load,
            ),
          ],
        );
      case ImportStep.preview:
      case ImportStep.validate:
      case ImportStep.duplicates:
        final terms =
            ref.watch(trackerKindProvider(TrackerKind.dictTerm)).value ??
            const <TrackerRecord>[];
        final cols =
            ref.watch(trackerKindProvider(TrackerKind.dictCollection)).value ??
            const <TrackerRecord>[];
        final index = indexTerms(terms);
        final dupCount = _candidates
            .where(
              (c) =>
                  _selected.contains(c.key) &&
                  findDuplicateTerm(c, index) != null,
            )
            .length;
        final invalid = _candidates.where((c) => !c.isValid).length;
        final hasCategories = _candidates.any((c) => c.category != null);
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Text(
                    l10n.dictImportSummary(
                      _candidates.length,
                      _selected.length,
                      invalid,
                      dupCount,
                    ),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      PrismButton(
                        label: l10n.importSelectAll,
                        density: PrismControlDensity.compact,
                        onPressed: () => setState(
                          () => _selected.addAll([
                            for (final c in _candidates)
                              if (c.isValid) c.key,
                          ]),
                        ),
                      ),
                      PrismButton(
                        label: l10n.importSelectNone,
                        density: PrismControlDensity.compact,
                        onPressed: () => setState(_selected.clear),
                      ),
                    ],
                  ),
                  if (dupCount > 0) ...[
                    TrackerLabel(l10n.dictDuplicatesAll),
                    _actionControl(
                      _defaultAction,
                      (a) => setState(() {
                        _defaultAction = a;
                        _actions.clear();
                      }),
                    ),
                  ],
                  TrackerLabel(l10n.dictCollection),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      PrismChip(
                        label: hasCategories
                            ? l10n.dictUseSourceCategories
                            : l10n.dictNoCollection,
                        selected: _collectionId == null,
                        onTap: () => setState(() {
                          _collectionId = null;
                          _useSourceCategories = true;
                        }),
                      ),
                      for (final c in cols)
                        PrismChip(
                          label: c.title,
                          selected: _collectionId == c.id,
                          onTap: () => setState(() => _collectionId = c.id),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final c in _candidates)
                    _candidateRow(c, findDuplicateTerm(c, index)),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  PrismButton(
                    label: l10n.back,
                    onPressed: () => setState(() => _step = ImportStep.select),
                  ),
                  const Spacer(),
                  PrismButton(
                    label: l10n.dictImportCount(_selected.length),
                    tone: PrismButtonTone.filled,
                    enabled: _selected.isNotEmpty,
                    onPressed: _import,
                  ),
                ],
              ),
            ),
          ],
        );
      case ImportStep.importing:
        return Center(child: Text(l10n.dictImporting));
      case ImportStep.done:
        final r = _result ?? const DictionaryImportResult();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Icon(
              AppIcons.navDictionary,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.dictImportDone,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TrackerStatGrid(
              children: [
                TrackerStatTile(
                  label: l10n.dictImportCreated,
                  value: '${r.created}',
                ),
                TrackerStatTile(
                  label: l10n.dictImportReplaced,
                  value: '${r.replaced}',
                ),
                TrackerStatTile(
                  label: l10n.dictImportSkipped,
                  value: '${r.skipped}',
                ),
                TrackerStatTile(
                  label: l10n.dictImportCollections,
                  value: '${r.collectionsCreated}',
                ),
              ],
            ),
            const SizedBox(height: 16),
            PrismButton(
              label: l10n.done,
              tone: PrismButtonTone.filled,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
    }
  }

  Widget _actionControl(
    TermDuplicateAction value,
    ValueChanged<TermDuplicateAction> onChanged,
  ) {
    final l10n = context.l10n;
    return PrismSegmentedControl<TermDuplicateAction>(
      segments: [
        PrismSegment(value: TermDuplicateAction.skip, label: l10n.dictDupSkip),
        PrismSegment(
          value: TermDuplicateAction.replace,
          label: l10n.dictDupReplace,
        ),
        PrismSegment(
          value: TermDuplicateAction.keepBoth,
          label: l10n.dictDupKeepBoth,
        ),
      ],
      selected: value,
      onChanged: onChanged,
    );
  }

  Widget _candidateRow(TermCandidate c, TrackerRecord? dup) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final subtitle = <Widget>[
      if (c.definition != null)
        Text(c.definition!, maxLines: 2, overflow: TextOverflow.ellipsis),
      if (!c.isValid)
        Text(
          _errorLabel(c.error!),
          style: TextStyle(color: theme.colorScheme.error),
        ),
      if (dup != null && c.isValid)
        Text(
          l10n.dictAlreadyHave(dup.title),
          style: TextStyle(color: theme.colorScheme.tertiary),
        ),
      if (c.category != null)
        Text(
          l10n.dictFromCategory(c.category!),
          style: theme.textTheme.labelSmall,
        ),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: PrismSurface(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            PrismCheckboxRow(
              title: Text(c.term.isEmpty ? '—' : c.term),
              subtitle: subtitle.isEmpty
                  ? null
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: subtitle,
                    ),
              value: _selected.contains(c.key),
              enabled: c.isValid,
              onChanged: (v) => setState(
                () => v ? _selected.add(c.key) : _selected.remove(c.key),
              ),
            ),
            if (dup != null && c.isValid && _selected.contains(c.key))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _actionControl(
                  _actions[c.key] ?? _defaultAction,
                  (a) => setState(() => _actions[c.key] = a),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
