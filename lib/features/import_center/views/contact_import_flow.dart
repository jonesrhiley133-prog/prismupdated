import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/core/services/files/prism_file_dialog_service.dart';
import 'package:prism_plurality/domain/models/contact.dart';
import 'package:prism_plurality/features/contacts/providers/contact_providers.dart';
import 'package:prism_plurality/features/contacts/services/device_contacts_service.dart';
import 'package:prism_plurality/features/contacts/utils/birthday_json_parser.dart';
import 'package:prism_plurality/features/contacts/utils/contact_import.dart';
import 'package:prism_plurality/features/contacts/utils/vcard_parser.dart';
import 'package:prism_plurality/features/contacts/views/contact_editor_sheet.dart';
import 'package:prism_plurality/features/import_center/widgets/import_steps_header.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/info_banner.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_checkbox_row.dart';
import 'package:prism_plurality/shared/widgets/prism_loading_state.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_segmented_control.dart';
import 'package:prism_plurality/shared/widgets/prism_select.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';

/// What a contact import reads from.
enum ContactImportKind { birthdayJson, vcard, device }

/// Import Center flow for people: birthday-app JSON, vCard files, or the
/// device address book. Select → Preview → Validate → Duplicates → Import →
/// Done.
class ContactImportFlow extends ConsumerStatefulWidget {
  const ContactImportFlow({super.key, required this.kind});

  final ContactImportKind kind;

  @override
  ConsumerState<ContactImportFlow> createState() => _ContactImportFlowState();
}

class _ContactImportFlowState extends ConsumerState<ContactImportFlow> {
  ImportStep _step = ImportStep.select;
  bool _busy = false;
  String? _error;
  String? _fileName;
  String? _rawJson;
  DateOrder _order = DateOrder.monthFirst;
  int _ambiguous = 0;
  List<ContactCandidate> _candidates = const [];
  final Set<String> _selected = {};
  List<DuplicateMatch> _duplicates = const [];
  final Map<String, DuplicateAction> _actions = {};
  ContactImportResult? _result;
  final _search = TextEditingController();
  bool _permissionDenied = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _title(BuildContext context) {
    final l10n = context.l10n;
    return switch (widget.kind) {
      ContactImportKind.birthdayJson => l10n.importBirthdaysTitle,
      ContactImportKind.vcard => l10n.importVCardTitle,
      ContactImportKind.device => l10n.importDeviceContactsTitle,
    };
  }

  // ── Step 1: select ────────────────────────────────────────────────

  Future<void> _selectSource() async {
    setState(() {
      _busy = true;
      _error = null;
      _permissionDenied = false;
    });
    try {
      switch (widget.kind) {
        case ContactImportKind.device:
          final service = ref.read(deviceContactsServiceProvider);
          final access = await service.requestAccess();
          if (access == DeviceContactsAccess.denied ||
              access == DeviceContactsAccess.unsupported) {
            setState(() {
              _permissionDenied = access == DeviceContactsAccess.denied;
              _error = access == DeviceContactsAccess.unsupported
                  ? context.l10n.importDeviceUnsupported
                  : context.l10n.importDevicePermissionDenied;
            });
            return;
          }
          _setCandidates(await service.loadCandidates());
        case ContactImportKind.birthdayJson:
        case ContactImportKind.vcard:
          final file = await ref
              .read(prismFileDialogServiceProvider)
              .pickFile(
                allowedExtensions: widget.kind == ContactImportKind.vcard
                    ? const ['vcf', 'vcard']
                    : const ['json'],
              );
          if (file == null) return;
          final bytes = await file.readAsBytes();
          if (bytes.length > 20 * 1024 * 1024) {
            setState(() => _error = context.l10n.importFileTooLarge);
            return;
          }
          final text = utf8.decode(bytes, allowMalformed: true);
          _fileName = file.name;
          if (widget.kind == ContactImportKind.vcard) {
            final cards = parseVCards(text);
            if (cards.isEmpty) {
              setState(() => _error = context.l10n.importNoRecords);
              return;
            }
            _setCandidates([
              for (var i = 0; i < cards.length; i++)
                ContactCandidate(
                  key: 'vcf:$i',
                  displayName: cards[i].name,
                  phones: cards[i].phones,
                  emails: cards[i].emails,
                  birthday: cards[i].birthday,
                  notes: cards[i].note,
                  externalId: cards[i].uid,
                  source: ContactSource.vcard,
                  error: cards[i].name == null ? 'missing_name' : null,
                ),
            ]);
          } else {
            _rawJson = text;
            if (!_parseBirthdays()) return;
          }
      }
      setState(() => _step = ImportStep.preview);
    } catch (e) {
      setState(() => _error = context.l10n.importReadFailed('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Re-reads the birthday JSON with the chosen date order.
  bool _parseBirthdays() {
    final result = parseBirthdayJson(_rawJson!, order: _order);
    if (result.fatalError != null) {
      setState(
        () => _error = result.fatalError == 'not_json'
            ? context.l10n.importNotJson
            : context.l10n.importNoRecords,
      );
      return false;
    }
    _ambiguous = result.ambiguousCount;
    _setCandidates([
      for (final r in result.records)
        ContactCandidate(
          key: 'bday:${r.index}',
          displayName: r.name,
          birthday: r.birthday,
          externalId: r.externalId,
          source: ContactSource.birthdayImport,
          error: r.error,
          warning: r.ambiguous ? 'ambiguous_date' : null,
        ),
    ]);
    return true;
  }

  void _setCandidates(List<ContactCandidate> list) {
    _candidates = list;
    _selected
      ..clear()
      ..addAll(list.where((c) => c.isValid).map((c) => c.key));
  }

  // ── Step 4: duplicates ────────────────────────────────────────────

  void _findDuplicates() {
    final existing = ref.read(contactsProvider).value ?? const <Contact>[];
    final chosen = _candidates
        .where((c) => _selected.contains(c.key) && c.isValid)
        .toList();
    _duplicates = findContactDuplicates(chosen, existing);
    _actions.clear();
    for (final d in _duplicates) {
      // Fill in a missing birthday automatically; otherwise skip.
      _actions[d.candidate.key] =
          d.existing != null &&
              d.existing!.birthday == null &&
              d.candidate.birthday != null
          ? DuplicateAction.updateExisting
          : DuplicateAction.skip;
    }
  }

  // ── Step 5: import ────────────────────────────────────────────────

  Future<void> _runImport() async {
    setState(() {
      _step = ImportStep.importing;
      _busy = true;
    });
    final chosen = _candidates
        .where((c) => _selected.contains(c.key) && c.isValid)
        .toList();
    final result = await ref
        .read(contactsNotifierProvider.notifier)
        .importCandidates(chosen, _duplicates, _actions);
    if (!mounted) return;
    setState(() {
      _result = result;
      _busy = false;
      _step = ImportStep.done;
    });
  }

  String _errorLabel(BuildContext context, String code) {
    final l10n = context.l10n;
    return switch (code) {
      'missing_name' => l10n.importErrorMissingName,
      'missing_date' => l10n.importErrorMissingDate,
      'unreadable_date' => l10n.importErrorUnreadableDate,
      'invalid_date' => l10n.importErrorInvalidDate,
      'not_an_object' => l10n.importErrorNotRecord,
      _ => code,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PrismPageScaffold(
      topBar: PrismTopBar(title: _title(context), showBackButton: true),
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
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: InfoBanner(
                    icon: AppIcons.warningAmberRounded,
                    iconColor: Theme.of(context).colorScheme.error,
                    title: l10n.importProblem,
                    message: _error!,
                  ),
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
    final valid = _candidates.where((c) => c.isValid).toList();
    final invalid = _candidates.where((c) => !c.isValid).toList();
    final chosenCount = valid.where((c) => _selected.contains(c.key)).length;

    Widget footer(List<Widget> buttons) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: buttons,
      ),
    );

    switch (_step) {
      case ImportStep.select:
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(switch (widget.kind) {
              ContactImportKind.birthdayJson => l10n.importBirthdaysHelp,
              ContactImportKind.vcard => l10n.importVCardHelp,
              ContactImportKind.device => l10n.importDeviceHelp,
            }, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            if (_busy)
              const PrismLoadingState()
            else ...[
              PrismButton(
                label: widget.kind == ContactImportKind.device
                    ? l10n.importAllowAndLoad
                    : l10n.importChooseFile,
                icon: widget.kind == ContactImportKind.device
                    ? AppIcons.navContacts
                    : AppIcons.navImport,
                tone: PrismButtonTone.filled,
                onPressed: _selectSource,
              ),
              if (_permissionDenied) ...[
                const SizedBox(height: 8),
                PrismButton(
                  label: l10n.importOpenSettings,
                  onPressed: () =>
                      ref.read(deviceContactsServiceProvider).openSettings(),
                ),
              ],
            ],
          ],
        );

      case ImportStep.preview:
        final q = _search.text.trim().toLowerCase();
        final shown = valid
            .where((c) => q.isEmpty || c.displayName!.toLowerCase().contains(q))
            .toList();
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Text(
                    l10n.importPreviewSummary(
                      _candidates.length,
                      valid.length,
                      _fileName ?? '',
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                  if (widget.kind == ContactImportKind.birthdayJson &&
                      _ambiguous > 0) ...[
                    const SizedBox(height: 8),
                    InfoBanner(
                      icon: AppIcons.infoOutlineRounded,
                      iconColor: theme.colorScheme.primary,
                      title: l10n.importAmbiguousTitle(_ambiguous),
                      message: l10n.importAmbiguousBody,
                    ),
                    const SizedBox(height: 8),
                    PrismSegmentedControl<DateOrder>(
                      segments: [
                        PrismSegment(
                          value: DateOrder.monthFirst,
                          label: l10n.importMonthFirst,
                        ),
                        PrismSegment(
                          value: DateOrder.dayFirst,
                          label: l10n.importDayFirst,
                        ),
                      ],
                      selected: _order,
                      onChanged: (o) => setState(() {
                        _order = o;
                        _parseBirthdays();
                      }),
                    ),
                  ],
                  const SizedBox(height: 8),
                  PrismTextField(
                    controller: _search,
                    labelText: l10n.contactsSearch,
                    prefixIcon: Icon(AppIcons.search),
                    onChanged: (_) => setState(() {}),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.importSelectedCount(chosenCount),
                          style: theme.textTheme.labelLarge,
                        ),
                      ),
                      PrismButton(
                        label: l10n.importSelectAll,
                        density: PrismControlDensity.compact,
                        onPressed: () => setState(
                          () => _selected.addAll(valid.map((c) => c.key)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      PrismButton(
                        label: l10n.importSelectNone,
                        density: PrismControlDensity.compact,
                        onPressed: () => setState(_selected.clear),
                      ),
                    ],
                  ),
                  for (final c in shown)
                    PrismCheckboxRow(
                      dense: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      title: Text(c.displayName!),
                      subtitle: Text(
                        [
                          if (c.birthday != null)
                            formatBirthday(context, c.birthday!),
                          if (c.phones.isNotEmpty) c.phones.first,
                          if (c.emails.isNotEmpty) c.emails.first,
                          if (c.warning == 'ambiguous_date')
                            l10n.importAmbiguousShort,
                        ].join(' · '),
                      ),
                      value: _selected.contains(c.key),
                      onChanged: (v) => setState(
                        () =>
                            v ? _selected.add(c.key) : _selected.remove(c.key),
                      ),
                    ),
                ],
              ),
            ),
            footer([
              PrismButton(
                label: l10n.calendarPrevious,
                onPressed: () => setState(() => _step = ImportStep.select),
              ),
              PrismButton(
                label: l10n.importNext,
                tone: PrismButtonTone.filled,
                enabled: chosenCount > 0 || invalid.isNotEmpty,
                onPressed: () => setState(() => _step = ImportStep.validate),
              ),
            ]),
          ],
        );

      case ImportStep.validate:
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  PrismSurface(
                    child: Text(
                      invalid.isEmpty
                          ? l10n.importAllValid(chosenCount)
                          : l10n.importSomeInvalid(chosenCount, invalid.length),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final c in invalid)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: PrismSurface(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            Icon(
                              AppIcons.warningAmberRounded,
                              size: 18,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${c.displayName ?? l10n.importRowNumber(int.parse(c.key.split(':').last) + 1)}: '
                                '${_errorLabel(context, c.error ?? 'missing_name')}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            footer([
              PrismButton(
                label: l10n.calendarPrevious,
                onPressed: () => setState(() => _step = ImportStep.preview),
              ),
              PrismButton(
                label: l10n.importNext,
                tone: PrismButtonTone.filled,
                enabled: chosenCount > 0,
                onPressed: () => setState(() {
                  _findDuplicates();
                  _step = ImportStep.duplicates;
                }),
              ),
            ]),
          ],
        );

      case ImportStep.duplicates:
        final contacts = {
          for (final c in ref.read(contactsProvider).value ?? const <Contact>[])
            c.id: c,
        };
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Text(
                    _duplicates.isEmpty
                        ? l10n.importNoDuplicates
                        : l10n.importDuplicatesFound(_duplicates.length),
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (_duplicates.isNotEmpty)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.importApplyToAll,
                            style: theme.textTheme.labelLarge,
                          ),
                        ),
                        PrismSelect<DuplicateAction>.compact(
                          value: null,
                          menuWidth: 220,
                          items: [
                            PrismSelectItem(
                              value: DuplicateAction.skip,
                              label: l10n.importActionSkip,
                            ),
                            PrismSelectItem(
                              value: DuplicateAction.updateExisting,
                              label: l10n.importActionUpdate,
                            ),
                            PrismSelectItem(
                              value: DuplicateAction.importAnyway,
                              label: l10n.importActionAddAnyway,
                            ),
                          ],
                          onChanged: (a) => setState(() {
                            if (a == null) return;
                            for (final d in _duplicates) {
                              _actions[d.candidate.key] =
                                  (a == DuplicateAction.updateExisting &&
                                      d.existing == null)
                                  ? DuplicateAction.skip
                                  : a;
                            }
                          }),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  for (final d in _duplicates)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: PrismSurface(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.candidate.displayName!,
                              style: theme.textTheme.titleSmall,
                            ),
                            Text(
                              d.existing != null
                                  ? l10n.importMatchesExisting(
                                      contacts[d.existing!.id]?.displayName ??
                                          d.existing!.displayName,
                                    )
                                  : l10n.importRepeatedInFile,
                              style: theme.textTheme.bodySmall,
                            ),
                            if (d.conflictingBirthday)
                              Text(
                                l10n.importBirthdayConflict,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            const SizedBox(height: 6),
                            PrismSegmentedControl<DuplicateAction>(
                              segments: [
                                PrismSegment(
                                  value: DuplicateAction.skip,
                                  label: l10n.importActionSkip,
                                ),
                                if (d.existing != null)
                                  PrismSegment(
                                    value: DuplicateAction.updateExisting,
                                    label: l10n.importActionUpdate,
                                  ),
                                PrismSegment(
                                  value: DuplicateAction.importAnyway,
                                  label: l10n.importActionAddAnyway,
                                ),
                              ],
                              selected:
                                  _actions[d.candidate.key] ??
                                  DuplicateAction.skip,
                              onChanged: (a) =>
                                  setState(() => _actions[d.candidate.key] = a),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            footer([
              PrismButton(
                label: l10n.calendarPrevious,
                onPressed: () => setState(() => _step = ImportStep.validate),
              ),
              PrismButton(
                label: l10n.importRun(chosenCount),
                tone: PrismButtonTone.filled,
                onPressed: _runImport,
              ),
            ]),
          ],
        );

      case ImportStep.importing:
        return const PrismLoadingState();

      case ImportStep.done:
        final r = _result!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Icon(AppIcons.check, size: 40, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              l10n.importDoneTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.importDoneSummary(
                r.created,
                r.updated,
                r.skipped + invalid.length,
              ),
              textAlign: TextAlign.center,
            ),
            if (r.failed > 0)
              Text(
                l10n.importDoneFailed(r.failed),
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            if (widget.kind == ContactImportKind.birthdayJson) ...[
              const SizedBox(height: 8),
              Text(
                l10n.importBirthdaysRecurring,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            Center(
              child: PrismButton(
                label: l10n.done,
                tone: PrismButtonTone.filled,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        );
    }
  }
}
