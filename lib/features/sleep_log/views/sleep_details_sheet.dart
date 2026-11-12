import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/sleep_log/providers/sleep_log_providers.dart';
import 'package:prism_plurality/features/sleep_log/utils/sleep_log.dart';
import 'package:prism_plurality/features/sleep_log/views/sleep_labels.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/features/trackers/widgets/member_picker.dart';
import 'package:prism_plurality/features/trackers/widgets/tracker_widgets.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';

Future<void> showSleepDetails(BuildContext context, FrontingSession session) =>
    PrismSheet.showFullScreen(
      context: context,
      builder: (context, scroll) =>
          SleepDetailsSheet(session: session, scroll: scroll),
    );

/// Environment and factors for one night, stored as a `sleep.log` record
/// linked to the sleep session.
class SleepDetailsSheet extends ConsumerStatefulWidget {
  const SleepDetailsSheet({super.key, required this.session, this.scroll});

  final FrontingSession session;
  final ScrollController? scroll;

  @override
  ConsumerState<SleepDetailsSheet> createState() => _SleepDetailsState();
}

class _SleepDetailsState extends ConsumerState<SleepDetailsSheet> {
  late final TrackerRecord? _log = ref
      .read(sleepLogsProvider)
      .where((l) => l.parentId == widget.session.id)
      .firstOrNull;
  late final _temp = TextEditingController(
    text: _log?.number(SleepField.temperatureC)?.toString() ?? '',
  );
  late final _latency = TextEditingController(
    text: _log?.integer(SleepField.latencyMin)?.toString() ?? '',
  );
  late final _notes = TextEditingController(text: _log?.body ?? '');
  late String? _lighting = _log?.str(SleepField.lighting);
  late String? _location = _log?.str(SleepField.location);
  late String? _noise = _log?.str(SleepField.noise);
  late String? _shared = _log?.str(SleepField.sharedWith);
  late String? _dreams = _log?.str(SleepField.dreams);
  late int? _comfort = _log?.integer(SleepField.comfort);
  late int? _wake = _log?.integer(SleepField.wakeFeeling);
  late int _interruptions = _log?.integer(SleepField.interruptions) ?? 0;
  late final Set<String> _reasons = {
    ...?_log?.strings(SleepField.interruptionReasons),
  };
  late final Set<String> _factors = {...?_log?.strings(SleepField.factors)};
  late String? _wokeAs = _log?.memberId;

  double? get _tempValue => _temp.text.trim().isEmpty
      ? null
      : double.tryParse(_temp.text.trim().replaceAll(',', '.'));
  int? get _latencyValue =>
      _latency.text.trim().isEmpty ? null : int.tryParse(_latency.text.trim());

  bool get _valid =>
      (_temp.text.trim().isEmpty ||
          (_tempValue != null && _tempValue! > -30 && _tempValue! < 60)) &&
      (_latency.text.trim().isEmpty ||
          (_latencyValue != null &&
              _latencyValue! >= 0 &&
              _latencyValue! < 24 * 60));

  @override
  void dispose() {
    _temp.dispose();
    _latency.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final fields = <String, Object?>{
      SleepField.temperatureC: _tempValue,
      SleepField.latencyMin: _latencyValue,
      SleepField.lighting: _lighting,
      SleepField.location: _location,
      SleepField.noise: _noise,
      SleepField.sharedWith: _shared,
      SleepField.dreams: _dreams,
      SleepField.comfort: _comfort,
      SleepField.wakeFeeling: _wake,
      SleepField.interruptions: _interruptions == 0 ? null : _interruptions,
      SleepField.interruptionReasons: _reasons.isEmpty
          ? null
          : _reasons.toList(),
      SleepField.factors: _factors.isEmpty ? null : _factors.toList(),
    };
    final n = ref.read(trackerNotifierProvider.notifier);
    final l = _log;
    if (l == null) {
      await n.create(
        kind: TrackerKind.sleepLog,
        parentId: widget.session.id,
        body: _notes.text,
        occurredAt: widget.session.startTime,
        endedAt: widget.session.endTime,
        memberId: _wokeAs,
        fields: fields,
      );
    } else {
      await n.save(
        l
            .copyWith(
              body: _notes.text,
              memberId: _wokeAs,
              occurredAt: widget.session.startTime,
              endedAt: widget.session.endTime,
            )
            .withFields(fields),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Widget _single(
    String label,
    List<String> options,
    String? value,
    ValueChanged<String?> onChanged,
  ) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TrackerLabel(label),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final o in options)
              PrismChip(
                label: sleepOptionLabel(l10n, o),
                selected: value == o,
                onTap: () => onChanged(value == o ? null : o),
              ),
          ],
        ),
      ],
    );
  }

  Widget _scale(String label, int? value, ValueChanged<int?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TrackerLabel(label),
        Wrap(
          spacing: 6,
          children: [
            for (var i = 1; i <= 5; i++)
              PrismChip(
                label: '$i',
                selected: value == i,
                onTap: () => onChanged(value == i ? null : i),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = widget.session;
    final fmt = DateFormat.MMMEd(context.dateLocale).add_jm();
    return ListenableBuilder(
      listenable: Listenable.merge([_temp, _latency]),
      builder: (context, _) => TrackerEditorScaffold(
        title: l10n.slpDetailsTitle,
        canSave: _valid,
        onSave: _save,
        scrollController: widget.scroll,
        children: [
          Text(
            s.endTime == null
                ? fmt.format(s.startTime)
                : '${fmt.format(s.startTime)} → ${fmt.format(s.endTime!)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PrismTextField(
                  controller: _temp,
                  labelText: l10n.slpTemperature,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PrismTextField(
                  controller: _latency,
                  labelText: l10n.slpLatency,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          if (!_valid)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                l10n.slpInvalidNumbers,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          _single(
            l10n.slpLighting,
            sleepLightingOptions,
            _lighting,
            (v) => setState(() => _lighting = v),
          ),
          _single(
            l10n.slpWhere,
            sleepLocationOptions,
            _location,
            (v) => setState(() => _location = v),
          ),
          _single(
            l10n.slpNoise,
            sleepNoiseOptions,
            _noise,
            (v) => setState(() => _noise = v),
          ),
          _single(
            l10n.slpSharedWith,
            sleepSharedOptions,
            _shared,
            (v) => setState(() => _shared = v),
          ),
          _scale(
            l10n.slpComfort,
            _comfort,
            (v) => setState(() => _comfort = v),
          ),
          TrackerLabel(l10n.slpInterruptions(_interruptions)),
          Wrap(
            spacing: 6,
            children: [
              for (var i = 0; i <= 6; i++)
                PrismChip(
                  label: i == 6 ? '6+' : '$i',
                  selected: _interruptions == i,
                  onTap: () => setState(() => _interruptions = i),
                ),
            ],
          ),
          if (_interruptions > 0) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final r in sleepInterruptionOptions)
                  PrismChip(
                    label: sleepOptionLabel(l10n, r),
                    selected: _reasons.contains(r),
                    onTap: () => setState(
                      () => _reasons.contains(r)
                          ? _reasons.remove(r)
                          : _reasons.add(r),
                    ),
                  ),
              ],
            ),
          ],
          TrackerLabel(l10n.slpBeforeBed),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final f in sleepFactorOptions)
                PrismChip(
                  label: sleepOptionLabel(l10n, f),
                  selected: _factors.contains(f),
                  onTap: () => setState(
                    () => _factors.contains(f)
                        ? _factors.remove(f)
                        : _factors.add(f),
                  ),
                ),
            ],
          ),
          _single(
            l10n.slpDreams,
            sleepDreamOptions,
            _dreams,
            (v) => setState(() => _dreams = v),
          ),
          _scale(l10n.slpWakeFeeling, _wake, (v) => setState(() => _wake = v)),
          TrackerMemberPicker(
            label: l10n.slpWokeUpAs,
            value: _wokeAs,
            noneLabel: l10n.slpNotSure,
            onChanged: (v) => setState(() => _wokeAs = v),
          ),
          const SizedBox(height: 12),
          PrismTextField(
            controller: _notes,
            labelText: l10n.finNote,
            maxLines: 4,
          ),
        ],
      ),
    );
  }
}
