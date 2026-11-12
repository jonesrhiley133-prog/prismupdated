import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/domain/models/contact.dart';
import 'package:prism_plurality/features/contacts/providers/contact_providers.dart';
import 'package:prism_plurality/features/contacts/utils/birthday_date.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_date_picker.dart';
import 'package:prism_plurality/shared/widgets/prism_dialog.dart';
import 'package:prism_plurality/shared/widgets/prism_glass_icon_button.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_switch_row.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';

Future<void> showContactEditor(BuildContext context, {Contact? editing}) {
  return PrismSheet.showFullScreen(
    context: context,
    builder: (context, scroll) =>
        ContactEditorSheet(editing: editing, scrollController: scroll),
  );
}

class ContactEditorSheet extends ConsumerStatefulWidget {
  const ContactEditorSheet({super.key, this.editing, this.scrollController});

  final Contact? editing;
  final ScrollController? scrollController;

  @override
  ConsumerState<ContactEditorSheet> createState() => _ContactEditorSheetState();
}

class _ContactEditorSheetState extends ConsumerState<ContactEditorSheet> {
  late final _name = TextEditingController(
    text: widget.editing?.displayName ?? '',
  );
  late final _phones = TextEditingController(
    text: widget.editing?.phones.join('\n') ?? '',
  );
  late final _emails = TextEditingController(
    text: widget.editing?.emails.join('\n') ?? '',
  );
  late final _notes = TextEditingController(text: widget.editing?.notes ?? '');
  late BirthdayDate? _birthday = BirthdayDate.fromStorage(
    widget.editing?.birthday,
  );
  late bool _favorite = widget.editing?.isFavorite ?? false;
  bool _saving = false;

  List<String> _lines(TextEditingController c) => c.text
      .split(RegExp(r'[\n,;]'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  bool get _emailsValid => _lines(
    _emails,
  ).every((e) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e));
  bool get _valid => _name.text.trim().isNotEmpty && _emailsValid;

  @override
  void dispose() {
    _name.dispose();
    _phones.dispose();
    _emails.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final b = _birthday;
    final picked = await showPrismDatePicker(
      context: context,
      initialDate: DateTime(b?.year ?? 2000, b?.month ?? 1, b?.day ?? 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(
        () => _birthday = BirthdayDate(
          picked.month,
          picked.day,
          _birthday?.year == null && b != null ? null : picked.year,
        ),
      );
    }
  }

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    final n = ref.read(contactsNotifierProvider.notifier);
    final e = widget.editing;
    if (e == null) {
      await n.create(
        displayName: _name.text,
        phones: _lines(_phones),
        emails: _lines(_emails),
        birthday: _birthday?.toStorage(),
        notes: _notes.text,
        isFavorite: _favorite,
      );
    } else {
      await n.save(
        e.copyWith(
          displayName: _name.text.trim(),
          phones: _lines(_phones),
          emails: _lines(_emails),
          birthday: _birthday?.toStorage(),
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          isFavorite: _favorite,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([_name, _emails]),
      builder: (context, _) => SafeArea(
        child: Column(
          children: [
            PrismSheetTopBar(
              title: widget.editing == null
                  ? l10n.contactsNew
                  : l10n.contactsEdit,
              trailing: PrismGlassIconButton(
                icon: AppIcons.check,
                tooltip: l10n.save,
                size: PrismTokens.topBarActionSize,
                tint: _valid ? theme.colorScheme.primary : null,
                accentIcon: _valid,
                onPressed: _valid && !_saving ? _save : null,
              ),
            ),
            Expanded(
              child: ListView(
                controller: widget.scrollController,
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                children: [
                  PrismTextField(
                    controller: _name,
                    labelText: l10n.contactsName,
                    autofocus: widget.editing == null,
                  ),
                  const SizedBox(height: 12),
                  PrismTextField(
                    controller: _phones,
                    labelText: l10n.contactsPhones,
                    keyboardType: TextInputType.multiline,
                    maxLines: 3,
                    minLines: 1,
                  ),
                  const SizedBox(height: 12),
                  PrismTextField(
                    controller: _emails,
                    labelText: l10n.contactsEmails,
                    keyboardType: TextInputType.multiline,
                    maxLines: 3,
                    minLines: 1,
                  ),
                  if (!_emailsValid)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        l10n.contactsInvalidEmail,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: Text(l10n.contactsBirthday)),
                      PrismButton(
                        label: _birthday == null
                            ? l10n.contactsAddBirthday
                            : formatBirthday(context, _birthday!),
                        density: PrismControlDensity.compact,
                        onPressed: _pickBirthday,
                      ),
                      if (_birthday != null)
                        IconButton(
                          tooltip: l10n.emotionsRemove,
                          icon: Icon(AppIcons.close, size: 18),
                          onPressed: () => setState(() => _birthday = null),
                        ),
                    ],
                  ),
                  if (_birthday != null)
                    PrismSwitchRow(
                      title: l10n.contactsYearUnknown,
                      value: _birthday!.year == null,
                      onChanged: (v) => setState(
                        () => _birthday = BirthdayDate(
                          _birthday!.month,
                          _birthday!.day,
                          v ? null : 2000,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  PrismTextField(
                    controller: _notes,
                    labelText: l10n.locationsNotesLabel,
                    maxLines: 4,
                    minLines: 2,
                  ),
                  const SizedBox(height: 12),
                  PrismSwitchRow(
                    title: l10n.locationsFavorite,
                    icon: AppIcons.star,
                    value: _favorite,
                    onChanged: (v) => setState(() => _favorite = v),
                  ),
                  if (widget.editing != null) ...[
                    const SizedBox(height: 24),
                    PrismButton(
                      label: l10n.delete,
                      tone: PrismButtonTone.destructive,
                      onPressed: () async {
                        final ok = await PrismDialog.confirm(
                          context: context,
                          title: l10n.contactsDeleteTitle,
                          message: l10n.contactsDeleteMessage(
                            widget.editing!.displayName,
                          ),
                          confirmLabel: l10n.delete,
                          cancelLabel: l10n.cancel,
                          destructive: true,
                        );
                        if (!ok) return;
                        await ref
                            .read(contactsNotifierProvider.notifier)
                            .delete(widget.editing!.id);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String formatBirthday(BuildContext context, BirthdayDate b) {
  final d = DateTime(b.year ?? 2000, b.month, b.day);
  return b.year == null
      ? DateFormat.MMMMd(context.dateLocale).format(d)
      : DateFormat.yMMMMd(context.dateLocale).format(d);
}
