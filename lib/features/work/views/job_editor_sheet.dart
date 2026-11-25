import 'package:prism_plurality/shared/theme/prism_shapes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/domain/models/work.dart';
import 'package:prism_plurality/features/calendar/widgets/calendar_colors.dart';
import 'package:prism_plurality/features/work/providers/work_providers.dart';
import 'package:prism_plurality/features/work/utils/money.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_dialog.dart';
import 'package:prism_plurality/shared/widgets/prism_glass_icon_button.dart';
import 'package:prism_plurality/shared/widgets/prism_select.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_switch_row.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';

Future<void> showJobEditor(BuildContext context, {Job? editing}) {
  return PrismSheet.showFullScreen(
    context: context,
    builder: (context, scroll) =>
        JobEditorSheet(editing: editing, scrollController: scroll),
  );
}

/// Create or edit a job and its hourly wage.
class JobEditorSheet extends ConsumerStatefulWidget {
  const JobEditorSheet({super.key, this.editing, this.scrollController});

  final Job? editing;
  final ScrollController? scrollController;

  @override
  ConsumerState<JobEditorSheet> createState() => _JobEditorSheetState();
}

class _JobEditorSheetState extends ConsumerState<JobEditorSheet> {
  late final _name = TextEditingController(text: widget.editing?.name ?? '');
  late final _rate = TextEditingController(
    text: widget.editing == null
        ? ''
        : (widget.editing!.hourlyRateCents / 100).toStringAsFixed(2),
  );
  late final _notes = TextEditingController(text: widget.editing?.notes ?? '');
  late String _currency = widget.editing?.currencyCode ?? 'USD';
  late String? _color = widget.editing?.colorHex;
  late bool _archived = widget.editing?.isArchived ?? false;
  bool _saving = false;

  int? get _rateCents =>
      _rate.text.trim().isEmpty ? 0 : parseMoneyToCents(_rate.text);
  bool get _valid => _name.text.trim().isNotEmpty && _rateCents != null;

  @override
  void dispose() {
    _name.dispose();
    _rate.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    final n = ref.read(workNotifierProvider.notifier);
    final e = widget.editing;
    if (e == null) {
      await n.createJob(
        name: _name.text,
        hourlyRateCents: _rateCents!,
        currencyCode: _currency,
        colorHex: _color,
        notes: _notes.text,
      );
    } else {
      await n.saveJob(
        e.copyWith(
          name: _name.text.trim(),
          hourlyRateCents: _rateCents!,
          currencyCode: _currency,
          colorHex: _color,
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          isArchived: _archived,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: Listenable.merge([_name, _rate]),
      builder: (context, _) => SafeArea(
        child: Column(
          children: [
            PrismSheetTopBar(
              title: widget.editing == null
                  ? l10n.workNewJob
                  : l10n.workEditJob,
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
                    labelText: l10n.workJobName,
                    autofocus: widget.editing == null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: PrismTextField(
                          controller: _rate,
                          labelText: l10n.workHourlyRate,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      PrismSelect<String>.compact(
                        value: _currency,
                        menuWidth: 140,
                        items: [
                          for (final c in {...commonCurrencies, _currency})
                            PrismSelectItem(value: c, label: c),
                        ],
                        onChanged: (v) =>
                            setState(() => _currency = v ?? 'USD'),
                      ),
                    ],
                  ),
                  if (_rateCents == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        l10n.workInvalidRate,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    )
                  else if (_rateCents! > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        l10n.workRatePerHour(
                          formatMoneyCents(_rateCents!, _currency),
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  if (widget.editing != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      l10n.workRateChangeHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final hex in [null, ...calendarColorSwatches])
                        InkWell(
                          customBorder: prismCircleBorder(context),
                          onTap: () => setState(() => _color = hex),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              borderRadius: prismRound(context),
                              color:
                                  parseHexColor(hex) ??
                                  theme.colorScheme.primary,
                              border: Border.all(
                                width: 3,
                                color: _color == hex
                                    ? theme.colorScheme.onSurface
                                    : Colors.transparent,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PrismTextField(
                    controller: _notes,
                    labelText: l10n.locationsNotesLabel,
                    maxLines: 3,
                  ),
                  if (widget.editing != null) ...[
                    const SizedBox(height: 12),
                    PrismSwitchRow(
                      title: l10n.workArchived,
                      subtitle: l10n.workArchivedHint,
                      value: _archived,
                      onChanged: (v) => setState(() => _archived = v),
                    ),
                    const SizedBox(height: 24),
                    PrismButton(
                      label: l10n.delete,
                      tone: PrismButtonTone.destructive,
                      onPressed: () async {
                        final ok = await PrismDialog.confirm(
                          context: context,
                          title: l10n.workDeleteJobTitle,
                          message: l10n.workDeleteJobMessage(
                            widget.editing!.name,
                          ),
                          confirmLabel: l10n.delete,
                          cancelLabel: l10n.cancel,
                          destructive: true,
                        );
                        if (!ok) return;
                        await ref
                            .read(workNotifierProvider.notifier)
                            .deleteJob(widget.editing!.id);
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
