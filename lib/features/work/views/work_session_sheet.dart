import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/domain/models/work.dart';
import 'package:prism_plurality/features/work/providers/work_providers.dart';
import 'package:prism_plurality/features/work/utils/money.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/extensions/duration_extensions.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_datetime_pills.dart';
import 'package:prism_plurality/shared/widgets/prism_glass_icon_button.dart';
import 'package:prism_plurality/shared/widgets/prism_select.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';

/// Edit a work session, or add a past shift when [editing] is null.
Future<void> showWorkSessionSheet(
  BuildContext context, {
  WorkSession? editing,
}) {
  return PrismSheet.showFullScreen(
    context: context,
    builder: (context, scroll) =>
        WorkSessionSheet(editing: editing, scrollController: scroll),
  );
}

class WorkSessionSheet extends ConsumerStatefulWidget {
  const WorkSessionSheet({super.key, this.editing, this.scrollController});

  final WorkSession? editing;
  final ScrollController? scrollController;

  @override
  ConsumerState<WorkSessionSheet> createState() => _WorkSessionSheetState();
}

class _WorkSessionSheetState extends ConsumerState<WorkSessionSheet> {
  late String? _jobId = widget.editing?.jobId;
  late DateTime _start =
      widget.editing?.startedAt ??
      DateTime.now().subtract(const Duration(hours: 4));
  late DateTime? _end = widget.editing == null
      ? DateTime.now()
      : widget.editing!.endedAt;
  late final _breakMinutes = TextEditingController(
    text: widget.editing == null || widget.editing!.breakSeconds == 0
        ? ''
        : (widget.editing!.breakSeconds / 60).toStringAsFixed(
            widget.editing!.breakSeconds % 60 == 0 ? 0 : 2,
          ),
  );
  late final _rate = TextEditingController(
    text: widget.editing == null
        ? ''
        : (widget.editing!.hourlyRateCents / 100).toStringAsFixed(2),
  );
  late final _note = TextEditingController(text: widget.editing?.note ?? '');
  bool _saving = false;

  int? get _breakSeconds {
    final t = _breakMinutes.text.trim().replaceAll(',', '.');
    if (t.isEmpty) return 0;
    final v = double.tryParse(t);
    if (v == null || v < 0) return null;
    return (v * 60).round();
  }

  int? get _rateCents =>
      _rate.text.trim().isEmpty ? null : parseMoneyToCents(_rate.text);

  bool get _valid {
    if (_jobId == null || _breakSeconds == null) return false;
    if (_rate.text.trim().isNotEmpty && _rateCents == null) return false;
    final end = _end ?? DateTime.now();
    if (!end.isAfter(_start)) return false;
    return _breakSeconds! < end.difference(_start).inSeconds;
  }

  @override
  void dispose() {
    _breakMinutes.dispose();
    _rate.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    final n = ref.read(workNotifierProvider.notifier);
    final jobs = ref.read(jobByIdProvider);
    final note = _note.text.trim();
    final e = widget.editing;
    if (e == null) {
      final job = jobs[_jobId]!;
      await n.addPastSession(
        job: _rateCents == null
            ? job
            : job.copyWith(hourlyRateCents: _rateCents!),
        startedAt: _start,
        endedAt: _end ?? DateTime.now(),
        breakSeconds: _breakSeconds!,
        note: note,
      );
    } else {
      await n.saveSession(
        e.copyWith(
          jobId: _jobId!,
          startedAt: _start,
          endedAt: _end,
          breakSeconds: _breakSeconds!,
          hourlyRateCents: _rateCents ?? e.hourlyRateCents,
          note: note.isEmpty ? null : note,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final jobs = ref.watch(jobsProvider).value ?? const <Job>[];
    final job = jobs.where((j) => j.id == _jobId).firstOrNull;
    final currency = widget.editing?.currencyCode ?? job?.currencyCode ?? 'USD';
    final rateCents =
        _rateCents ??
        widget.editing?.hourlyRateCents ??
        job?.hourlyRateCents ??
        0;
    final end = _end ?? DateTime.now();
    final worked = end.difference(_start).inSeconds - (_breakSeconds ?? 0);

    return ListenableBuilder(
      listenable: Listenable.merge([_breakMinutes, _rate]),
      builder: (context, _) => SafeArea(
        child: Column(
          children: [
            PrismSheetTopBar(
              title: widget.editing == null
                  ? l10n.workAddPastShift
                  : l10n.workEditShift,
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
                  Row(
                    children: [
                      Expanded(child: Text(l10n.workJob)),
                      PrismSelect<String>.compact(
                        value: job == null ? null : _jobId,
                        menuWidth: 240,
                        items: [
                          for (final j in jobs)
                            PrismSelectItem(value: j.id, label: j.name),
                        ],
                        onChanged: (v) => setState(() => _jobId = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PrismDateTimePills(
                    label: l10n.workStarted,
                    dateTime: _start,
                    lastDate: DateTime.now(),
                    onChanged: (v) => setState(() => _start = v),
                  ),
                  const SizedBox(height: 12),
                  if (_end != null)
                    PrismDateTimePills(
                      label: l10n.workEnded,
                      dateTime: _end,
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                      onChanged: (v) => setState(() => _end = v),
                    )
                  else
                    Text(
                      l10n.workStillClockedIn,
                      style: theme.textTheme.bodyMedium,
                    ),
                  const SizedBox(height: 12),
                  PrismTextField(
                    controller: _breakMinutes,
                    labelText: l10n.workBreakMinutes,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  PrismTextField(
                    controller: _rate,
                    labelText: l10n.workRateForShift(currency),
                    hintText: job == null
                        ? null
                        : (job.hourlyRateCents / 100).toStringAsFixed(2),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _valid
                        ? l10n.workShiftSummary(
                            Duration(seconds: worked).toExactString(),
                            formatMoneyCents(
                              estimateEarningsCents(worked, rateCents),
                              currency,
                            ),
                          )
                        : l10n.workShiftInvalid,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _valid ? null : theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 16),
                  PrismTextField(
                    controller: _note,
                    labelText: l10n.locationsNotesLabel,
                    maxLines: 3,
                  ),
                  if (widget.editing != null) ...[
                    const SizedBox(height: 24),
                    PrismButton(
                      label: l10n.delete,
                      tone: PrismButtonTone.destructive,
                      onPressed: () async {
                        await ref
                            .read(workNotifierProvider.notifier)
                            .deleteSession(widget.editing!.id);
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
