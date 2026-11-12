import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/features/trackers/widgets/member_picker.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/dictionary/utils/dictionary_import.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/features/trackers/widgets/tracker_widgets.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_switch_row.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';

Future<void> showTermEditor(
  BuildContext context, {
  TrackerRecord? editing,
  String? collectionId,
}) {
  return PrismSheet.showFullScreen(
    context: context,
    builder: (context, scroll) => TermEditorSheet(
      editing: editing,
      initialCollection: collectionId,
      scrollController: scroll,
    ),
  );
}

class TermEditorSheet extends ConsumerStatefulWidget {
  const TermEditorSheet({
    super.key,
    this.editing,
    this.initialCollection,
    this.scrollController,
  });

  final TrackerRecord? editing;
  final String? initialCollection;
  final ScrollController? scrollController;

  @override
  ConsumerState<TermEditorSheet> createState() => _TermEditorSheetState();
}

class _TermEditorSheetState extends ConsumerState<TermEditorSheet> {
  late final TrackerRecord? _e = widget.editing;
  late final _term = TextEditingController(text: _e?.title ?? '');
  late final _def = TextEditingController(text: _e?.body ?? '');
  late final _aliases = TextEditingController(
    text: _e?.strings(DictField.aliases).join(', ') ?? '',
  );
  late final _pron = TextEditingController(
    text: _e?.str(DictField.pronunciation) ?? '',
  );
  late final _examples = TextEditingController(
    text: _e?.strings(DictField.examples).join('\n') ?? '',
  );
  late final _url = TextEditingController(
    text: _e?.str(DictField.sourceUrl) ?? '',
  );
  late final _tags = TextEditingController(text: _e?.tags.join(', ') ?? '');
  late String? _collection =
      _e?.str(DictField.collection) ?? widget.initialCollection;
  late bool _private = _e?.isPrivate ?? false;
  late String? _member = _e?.memberId;
  bool _saving = false;

  String? get _duplicateOf {
    final terms =
        ref.read(trackerKindProvider(TrackerKind.dictTerm)).value ?? const [];
    final name = normalizeTerm(_term.text);
    if (name.isEmpty) return null;
    for (final t in terms) {
      if (t.id != _e?.id && normalizeTerm(t.title) == name) return t.title;
    }
    return null;
  }

  bool get _urlValid {
    final u = _url.text.trim();
    if (u.isEmpty) return true;
    final p = Uri.tryParse(u);
    return p != null && (p.scheme == 'https' || p.scheme == 'http');
  }

  bool get _valid => _term.text.trim().isNotEmpty && _urlValid;

  @override
  void dispose() {
    for (final c in [_term, _def, _aliases, _pron, _examples, _url, _tags]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    final fields = <String, Object?>{
      DictField.collection: _collection,
      DictField.aliases: _split(_aliases.text, ',').isEmpty
          ? null
          : _split(_aliases.text, ','),
      DictField.pronunciation: _pron.text.trim().isEmpty
          ? null
          : _pron.text.trim(),
      DictField.examples: _split(_examples.text, '\n').isEmpty
          ? null
          : _split(_examples.text, '\n'),
      DictField.sourceUrl: _url.text.trim().isEmpty ? null : _url.text.trim(),
    };
    final n = ref.read(trackerNotifierProvider.notifier);
    final e = _e;
    if (e == null) {
      await n.create(
        kind: TrackerKind.dictTerm,
        title: _term.text,
        body: _def.text,
        tags: parseTagInput(_tags.text),
        isPrivate: _private,
        memberId: _member,
        fields: fields,
      );
    } else {
      await n.save(
        e
            .copyWith(
              title: _term.text.trim(),
              body: _def.text.trim().isEmpty ? null : _def.text.trim(),
              tags: parseTagInput(_tags.text),
              isPrivate: _private,
              memberId: _member,
            )
            .withFields(fields),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  static List<String> _split(String s, String sep) => [
    for (final p in s.split(sep))
      if (p.trim().isNotEmpty) p.trim(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final collections =
        ref.watch(trackerKindProvider(TrackerKind.dictCollection)).value ??
        const <TrackerRecord>[];
    return ListenableBuilder(
      listenable: Listenable.merge([_term, _url]),
      builder: (context, _) {
        final dup = _duplicateOf;
        return TrackerEditorScaffold(
          title: _e == null ? l10n.dictNewTerm : l10n.dictEditTerm,
          canSave: _valid && !_saving,
          onSave: _save,
          scrollController: widget.scrollController,
          children: [
            PrismTextField(
              controller: _term,
              labelText: l10n.dictTerm,
              autofocus: _e == null,
            ),
            if (dup != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  l10n.dictDuplicateWarning(dup),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            PrismTextField(
              controller: _def,
              labelText: l10n.dictDefinition,
              keyboardType: TextInputType.multiline,
              minLines: 4,
              maxLines: 20,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            PrismTextField(
              controller: _pron,
              labelText: l10n.dictPronunciation,
            ),
            const SizedBox(height: 12),
            PrismTextField(
              controller: _aliases,
              labelText: l10n.dictAliases,
              helperText: l10n.dictAliasesHelp,
            ),
            const SizedBox(height: 12),
            PrismTextField(
              controller: _examples,
              labelText: l10n.dictExamples,
              helperText: l10n.dictExamplesHelp,
              keyboardType: TextInputType.multiline,
              minLines: 2,
              maxLines: 8,
            ),
            const SizedBox(height: 12),
            PrismTextField(
              controller: _url,
              labelText: l10n.dictSourceUrl,
              keyboardType: TextInputType.url,
              errorText: _urlValid ? null : l10n.dictInvalidUrl,
            ),
            TrackerLabel(l10n.dictCollection),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                PrismChip(
                  label: l10n.dictNoCollection,
                  selected: _collection == null,
                  onTap: () => setState(() => _collection = null),
                ),
                for (final c in collections)
                  PrismChip(
                    label: c.title,
                    selected: _collection == c.id,
                    selectedColor: Color(
                      c.integer(DictField.color) ?? trackerPalette.first,
                    ),
                    onTap: () => setState(() => _collection = c.id),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            PrismTextField(
              controller: _tags,
              labelText: l10n.trackerTags,
              helperText: l10n.trackerTagsHelp,
            ),
            TrackerMemberPicker(
              label: l10n.dictAddedBy,
              value: _member,
              onChanged: (v) => setState(() => _member = v),
            ),
            const SizedBox(height: 12),
            PrismSwitchRow(
              title: l10n.trackerPrivate,
              subtitle: l10n.trackerPrivateHelp,
              icon: AppIcons.privateLock,
              value: _private,
              onChanged: (v) => setState(() => _private = v),
            ),
          ],
        );
      },
    );
  }
}
