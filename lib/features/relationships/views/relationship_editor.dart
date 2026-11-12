import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/domain/models/contact.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/contacts/providers/contact_providers.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/relationships/utils/relationships.dart';
import 'package:prism_plurality/features/relationships/views/relationship_labels.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/features/trackers/widgets/member_picker.dart';
import 'package:prism_plurality/features/trackers/widgets/tracker_widgets.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_date_picker.dart';
import 'package:prism_plurality/shared/widgets/prism_dialog.dart';
import 'package:prism_plurality/shared/widgets/prism_segmented_control.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_switch_row.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';

Future<void> showRelationshipEditor(
  BuildContext context, {
  TrackerRecord? editing,
  String? memberId,
}) => PrismSheet.showFullScreen(
  context: context,
  builder: (context, scroll) => RelationshipEditorSheet(
    editing: editing,
    memberId: memberId,
    scroll: scroll,
  ),
);

class RelationshipEditorSheet extends ConsumerStatefulWidget {
  const RelationshipEditorSheet({
    super.key,
    this.editing,
    this.memberId,
    this.scroll,
  });

  final TrackerRecord? editing;
  final String? memberId;
  final ScrollController? scroll;

  @override
  ConsumerState<RelationshipEditorSheet> createState() => _RelEditorState();
}

class _RelEditorState extends ConsumerState<RelationshipEditorSheet> {
  late final TrackerRecord? _e = widget.editing;
  late String? _member =
      _e?.memberId ?? widget.memberId ?? currentFronterId(ref);
  late String _otherType = _e?.str(RelField.otherType) ?? RelOther.member;
  late String? _otherId = _e?.str(RelField.otherId);
  late final _otherName = TextEditingController(
    text: _e?.str(RelField.otherName) ?? '',
  );
  late String _type = _e?.str(RelField.type) ?? 'friend';
  late String _status = _e?.str(RelField.status) ?? 'active';
  late int? _closeness = _e?.integer(RelField.closeness);
  late int? _trust = _e?.integer(RelField.trust);
  late bool _mutual = _e?.flag(RelField.mutual) ?? true;
  late final _dynamics = TextEditingController(
    text: _e?.str(RelField.dynamics) ?? '',
  );
  late final _boundaries = TextEditingController(
    text: _e?.strings(RelField.boundaries).join('\n') ?? '',
  );
  late final _notes = TextEditingController(text: _e?.body ?? '');
  late final _tags = TextEditingController(text: _e?.tags.join(', ') ?? '');
  late DateTime? _since = _e?.occurredAt;
  late bool _private = _e?.isPrivate ?? false;

  bool get _valid =>
      _member != null &&
      switch (_otherType) {
        RelOther.person => _otherName.text.trim().isNotEmpty,
        RelOther.member => _otherId != null && _otherId != _member,
        _ => _otherId != null,
      };

  @override
  void dispose() {
    for (final c in [_otherName, _dynamics, _boundaries, _notes, _tags]) {
      c.dispose();
    }
    super.dispose();
  }

  String _otherDisplay(List<Member> members, List<Contact> contacts) =>
      switch (_otherType) {
        RelOther.member =>
          members.where((m) => m.id == _otherId).map(memberLabel).firstOrNull ??
              '',
        RelOther.contact =>
          contacts
                  .where((c) => c.id == _otherId)
                  .map((c) => c.displayName)
                  .firstOrNull ??
              '',
        _ => _otherName.text.trim(),
      };

  Future<void> _save(List<Member> members, List<Contact> contacts) async {
    final fields = <String, Object?>{
      RelField.otherType: _otherType,
      RelField.otherId: _otherType == RelOther.person ? null : _otherId,
      RelField.otherName: _otherDisplay(members, contacts),
      RelField.type: _type,
      RelField.status: _status,
      RelField.closeness: _closeness,
      RelField.trust: _trust,
      RelField.mutual: _otherType == RelOther.member ? _mutual : null,
      RelField.dynamics: _dynamics.text.trim().isEmpty
          ? null
          : _dynamics.text.trim(),
      RelField.boundaries: [
        for (final b in _boundaries.text.split('\n'))
          if (b.trim().isNotEmpty) b.trim(),
      ],
    };
    if ((fields[RelField.boundaries] as List).isEmpty)
      fields[RelField.boundaries] = null;
    final title =
        '${members.where((m) => m.id == _member).map((m) => m.name).firstOrNull ?? ''} ↔ ${_otherDisplay(members, contacts)}';
    final n = ref.read(trackerNotifierProvider.notifier);
    final e = _e;
    if (e == null) {
      await n.create(
        kind: TrackerKind.relationship,
        title: title,
        body: _notes.text,
        memberId: _member,
        occurredAt: _since,
        tags: parseTagInput(_tags.text),
        isPrivate: _private,
        fields: fields,
      );
    } else {
      await n.save(
        e
            .copyWith(
              title: title,
              body: _notes.text,
              memberId: _member,
              occurredAt: _since,
              tags: parseTagInput(_tags.text),
              isPrivate: _private,
            )
            .withFields(fields),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Widget _scale(String label, int? v, ValueChanged<int?> set) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TrackerLabel(label),
      Wrap(
        spacing: 6,
        children: [
          for (var i = 1; i <= 5; i++)
            PrismChip(
              label: '$i',
              selected: v == i,
              onTap: () => setState(() => set(v == i ? null : i)),
            ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final members = ref.watch(activeMembersProvider).value ?? const <Member>[];
    final contacts = ref.watch(contactsProvider).value ?? const <Contact>[];
    return ListenableBuilder(
      listenable: _otherName,
      builder: (context, _) => TrackerEditorScaffold(
        title: _e == null ? l10n.relNew : l10n.relEdit,
        canSave: _valid,
        onSave: () => _save(members, contacts),
        scrollController: widget.scroll,
        children: [
          if (members.isEmpty) Text(l10n.relNeedMembers),
          TrackerMemberPicker(
            label: l10n.relWhoseRelationship,
            value: _member,
            noneLabel: l10n.relPickMember,
            onChanged: (v) => setState(() => _member = v),
          ),
          TrackerLabel(l10n.relWith),
          PrismSegmentedControl<String>(
            segments: [
              PrismSegment(value: RelOther.member, label: l10n.relWithMember),
              PrismSegment(value: RelOther.contact, label: l10n.relWithContact),
              PrismSegment(value: RelOther.person, label: l10n.relWithPerson),
            ],
            selected: _otherType,
            onChanged: (t) => setState(() {
              _otherType = t;
              _otherId = null;
            }),
          ),
          const SizedBox(height: 8),
          if (_otherType == RelOther.member)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in members)
                  if (m.id != _member)
                    PrismChip(
                      label: memberLabel(m),
                      selected: _otherId == m.id,
                      onTap: () => setState(() => _otherId = m.id),
                    ),
              ],
            ),
          if (_otherType == RelOther.contact)
            contacts.isEmpty
                ? Text(l10n.relNoContacts)
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final c in contacts)
                        PrismChip(
                          label: c.displayName,
                          selected: _otherId == c.id,
                          onTap: () => setState(() => _otherId = c.id),
                        ),
                    ],
                  ),
          if (_otherType == RelOther.person)
            PrismTextField(
              controller: _otherName,
              labelText: l10n.relPersonName,
            ),
          if (_otherType == RelOther.member)
            PrismSwitchRow(
              title: l10n.relMutual,
              subtitle: l10n.relMutualHelp,
              value: _mutual,
              onChanged: (v) => setState(() => _mutual = v),
            ),
          TrackerLabel(l10n.relType),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in relationshipTypes)
                PrismChip(
                  label: relTypeLabel(l10n, t),
                  selected: _type == t,
                  onTap: () => setState(() => _type = t),
                ),
            ],
          ),
          TrackerLabel(l10n.relStatus),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in relationshipStatuses)
                PrismChip(
                  label: relStatusLabel(l10n, s),
                  selected: _status == s,
                  onTap: () => setState(() => _status = s),
                ),
            ],
          ),
          _scale(l10n.relCloseness, _closeness, (v) => _closeness = v),
          _scale(l10n.relTrust, _trust, (v) => _trust = v),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text(l10n.relSince)),
              PrismButton(
                label: _since == null
                    ? l10n.relUnknownDate
                    : DateFormat.yMMMd(context.dateLocale).format(_since!),
                density: PrismControlDensity.compact,
                onPressed: () async {
                  final d = await showPrismDatePicker(
                    context: context,
                    initialDate: _since ?? DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) setState(() => _since = d);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          PrismTextField(
            controller: _dynamics,
            labelText: l10n.relDynamics,
            helperText: l10n.relDynamicsHelp,
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          PrismTextField(
            controller: _boundaries,
            labelText: l10n.relBoundaries,
            helperText: l10n.relBoundariesHelp,
            maxLines: 6,
            minLines: 2,
          ),
          const SizedBox(height: 12),
          PrismTextField(
            controller: _notes,
            labelText: l10n.finNote,
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          PrismTextField(
            controller: _tags,
            labelText: l10n.trackerTags,
            helperText: l10n.trackerTagsHelp,
          ),
          const SizedBox(height: 12),
          PrismSwitchRow(
            title: l10n.trackerPrivate,
            subtitle: l10n.trackerPrivateHelp,
            icon: AppIcons.privateLock,
            value: _private,
            onChanged: (v) => setState(() => _private = v),
          ),
          if (_e != null)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: PrismButton(
                label: l10n.trackerDelete,
                icon: AppIcons.delete,
                tone: PrismButtonTone.destructive,
                onPressed: () async {
                  final ok = await PrismDialog.confirm(
                    context: context,
                    title: l10n.relDeleteTitle,
                    message: l10n.relDeleteMessage,
                    confirmLabel: l10n.trackerDelete,
                    cancelLabel: l10n.cancel,
                    destructive: true,
                  );
                  if (!ok) return;
                  await ref
                      .read(trackerNotifierProvider.notifier)
                      .delete(_e.id);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ),
        ],
      ),
    );
  }
}
