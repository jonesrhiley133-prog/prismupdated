import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/journal/utils/journal_stats.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/mood/widgets/mood_level.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/features/trackers/widgets/tracker_widgets.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_date_picker.dart';
import 'package:prism_plurality/shared/widgets/prism_dialog.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_switch_row.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';
import 'package:prism_plurality/shared/widgets/prism_time_picker.dart';

List<String> journalPrompts(AppLocalizations l10n) => [
  l10n.journalPrompt1,
  l10n.journalPrompt2,
  l10n.journalPrompt3,
  l10n.journalPrompt4,
  l10n.journalPrompt5,
  l10n.journalPrompt6,
  l10n.journalPrompt7,
  l10n.journalPrompt8,
];

Future<void> showJournalEditor(
  BuildContext context, {
  TrackerRecord? editing,
  String? categoryId,
}) {
  return PrismSheet.showFullScreen(
    context: context,
    builder: (context, scroll) => JournalEditorSheet(
      editing: editing,
      initialCategory: categoryId,
      scrollController: scroll,
    ),
  );
}

class JournalEditorSheet extends ConsumerStatefulWidget {
  const JournalEditorSheet({
    super.key,
    this.editing,
    this.initialCategory,
    this.scrollController,
  });

  final TrackerRecord? editing;
  final String? initialCategory;
  final ScrollController? scrollController;

  @override
  ConsumerState<JournalEditorSheet> createState() => _JournalEditorSheetState();
}

class _JournalEditorSheetState extends ConsumerState<JournalEditorSheet> {
  late final TrackerRecord? _e = widget.editing;
  late final _title = TextEditingController(text: _e?.title ?? '');
  late final _body = TextEditingController(text: _e?.body ?? '');
  late final _tags = TextEditingController(text: _e?.tags.join(', ') ?? '');
  late DateTime _at = _e?.occurredAt ?? DateTime.now();
  late String? _category =
      _e?.str(JournalField.category) ?? widget.initialCategory;
  late int? _mood = _e?.integer(JournalField.mood);
  late String? _memberId = _e?.memberId;
  late bool _private = _e?.isPrivate ?? false;
  late bool _pinned = _e?.isPinned ?? false;
  late String? _prompt = _e?.str(JournalField.prompt);
  bool _saving = false;

  bool get _valid =>
      _title.text.trim().isNotEmpty || _body.text.trim().isNotEmpty;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showPrismDatePicker(
      context: context,
      initialDate: _at,
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) {
      setState(
        () => _at = DateTime(d.year, d.month, d.day, _at.hour, _at.minute),
      );
    }
  }

  Future<void> _pickTime() async {
    final t = await showPrismTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_at),
    );
    if (t != null) {
      setState(
        () => _at = DateTime(_at.year, _at.month, _at.day, t.hour, t.minute),
      );
    }
  }

  void _usePrompt() {
    final prompts = journalPrompts(context.l10n);
    var next = prompts[Random().nextInt(prompts.length)];
    if (prompts.length > 1) {
      while (next == _prompt) {
        next = prompts[Random().nextInt(prompts.length)];
      }
    }
    setState(() => _prompt = next);
  }

  Future<void> _newCategory() async {
    final name = TextEditingController();
    final ok = await PrismDialog.show<bool>(
      context: context,
      title: context.l10n.journalNewCategory,
      builder: (ctx) => PrismTextField(
        controller: name,
        labelText: ctx.l10n.journalCategoryName,
        autofocus: true,
      ),
      actions: [
        PrismButton(
          label: context.l10n.cancel,
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
        ),
        PrismButton(
          label: context.l10n.save,
          tone: PrismButtonTone.filled,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
        ),
      ],
    );
    final text = name.text.trim();
    name.dispose();
    if (ok != true || text.isEmpty) return;
    final existing =
        ref.read(trackerKindProvider(TrackerKind.journalCategory)).value ??
        const [];
    final c = await ref
        .read(trackerNotifierProvider.notifier)
        .create(
          kind: TrackerKind.journalCategory,
          title: text,
          sortOrder: existing.length,
          fields: {
            JournalField.color:
                trackerPalette[existing.length % trackerPalette.length],
          },
        );
    if (mounted) setState(() => _category = c.id);
  }

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    final n = ref.read(trackerNotifierProvider.notifier);
    final fields = <String, Object?>{
      JournalField.category: _category,
      JournalField.mood: _mood,
      JournalField.prompt: _prompt,
    };
    final e = _e;
    if (e == null) {
      await n.create(
        kind: TrackerKind.journalEntry,
        title: _title.text,
        body: _body.text,
        tags: parseTagInput(_tags.text),
        occurredAt: _at,
        memberId: _memberId,
        isPrivate: _private,
        isPinned: _pinned,
        fields: fields,
      );
    } else {
      final now = DateTime.now();
      final edited = e
          .copyWith(
            title: _title.text.trim(),
            body: _body.text.trim().isEmpty ? null : _body.text.trim(),
            tags: parseTagInput(_tags.text),
            occurredAt: _at,
            memberId: _memberId,
            isPrivate: _private,
            isPinned: _pinned,
          )
          .withFields(fields);
      await n.save(withRevision(e, edited, now), now: now);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final categories =
        ref.watch(trackerKindProvider(TrackerKind.journalCategory)).value ??
        const <TrackerRecord>[];
    final members = ref.watch(activeMembersProvider).value ?? const [];
    final locale = context.dateLocale;
    return ListenableBuilder(
      listenable: Listenable.merge([_title, _body]),
      builder: (context, _) => TrackerEditorScaffold(
        title: _e == null ? l10n.journalNewEntry : l10n.journalEditEntry,
        canSave: _valid && !_saving,
        onSave: _save,
        scrollController: widget.scrollController,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PrismButton(
                label: DateFormat.yMMMEd(locale).format(_at),
                icon: AppIcons.calendarToday,
                density: PrismControlDensity.compact,
                onPressed: _pickDate,
              ),
              PrismButton(
                label: DateFormat.jm(locale).format(_at),
                density: PrismControlDensity.compact,
                onPressed: _pickTime,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_prompt != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _prompt!,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.journalRemovePrompt,
                    icon: Icon(AppIcons.close, size: 18),
                    onPressed: () => setState(() => _prompt = null),
                  ),
                ],
              ),
            ),
          PrismTextField(
            controller: _title,
            labelText: l10n.journalTitle,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          PrismTextField(
            controller: _body,
            labelText: l10n.journalBody,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            minLines: 8,
            maxLines: 30,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: PrismButton(
              label: _prompt == null
                  ? l10n.journalUsePrompt
                  : l10n.journalAnotherPrompt,
              icon: AppIcons.navInsights,
              density: PrismControlDensity.compact,
              onPressed: _usePrompt,
            ),
          ),
          TrackerLabel(l10n.journalMood),
          Wrap(
            spacing: 8,
            children: [
              for (var m = 1; m <= 5; m++)
                Semantics(
                  selected: _mood == m,
                  button: true,
                  child: InkResponse(
                    radius: 24,
                    onTap: () => setState(() => _mood = _mood == m ? null : m),
                    child: Opacity(
                      opacity: _mood == null || _mood == m ? 1 : 0.35,
                      child: MoodFace(level: m, size: 40),
                    ),
                  ),
                ),
            ],
          ),
          TrackerLabel(
            l10n.journalCategory,
            trailing: PrismButton(
              label: l10n.journalNewCategory,
              icon: AppIcons.add,
              density: PrismControlDensity.compact,
              onPressed: _newCategory,
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              PrismChip(
                label: l10n.journalNoCategory,
                selected: _category == null,
                onTap: () => setState(() => _category = null),
              ),
              for (final c in categories)
                PrismChip(
                  label: c.title,
                  selected: _category == c.id,
                  selectedColor: Color(
                    c.integer(JournalField.color) ?? trackerPalette.first,
                  ),
                  onTap: () => setState(() => _category = c.id),
                ),
            ],
          ),
          const SizedBox(height: 12),
          PrismTextField(
            controller: _tags,
            labelText: l10n.trackerTags,
            helperText: l10n.trackerTagsHelp,
          ),
          if (members.isNotEmpty) ...[
            TrackerLabel(l10n.journalWrittenBy),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                PrismChip(
                  label: l10n.journalNobodyInParticular,
                  selected: _memberId == null,
                  onTap: () => setState(() => _memberId = null),
                ),
                for (final m in members)
                  PrismChip(
                    label: m.name,
                    selected: _memberId == m.id,
                    onTap: () => setState(() => _memberId = m.id),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          PrismSwitchRow(
            title: l10n.trackerPrivate,
            subtitle: l10n.trackerPrivateHelp,
            icon: AppIcons.privateLock,
            value: _private,
            onChanged: (v) => setState(() => _private = v),
          ),
          PrismSwitchRow(
            title: l10n.trackerPinned,
            icon: AppIcons.pin,
            value: _pinned,
            onChanged: (v) => setState(() => _pinned = v),
          ),
        ],
      ),
    );
  }
}
