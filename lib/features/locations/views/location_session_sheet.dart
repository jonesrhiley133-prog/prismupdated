import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/domain/models/location.dart';
import 'package:prism_plurality/features/locations/providers/location_providers.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/extensions/duration_extensions.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_datetime_pills.dart';
import 'package:prism_plurality/shared/widgets/prism_glass_icon_button.dart';
import 'package:prism_plurality/shared/widgets/prism_select.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_switch_row.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';

/// Edit a location session, or add a past one when [editing] is null.
Future<void> showLocationSessionSheet(
  BuildContext context, {
  LocationSession? editing,
}) {
  return PrismSheet.showFullScreen(
    context: context,
    builder: (context, scroll) =>
        LocationSessionSheet(editing: editing, scrollController: scroll),
  );
}

class LocationSessionSheet extends ConsumerStatefulWidget {
  const LocationSessionSheet({super.key, this.editing, this.scrollController});

  final LocationSession? editing;
  final ScrollController? scrollController;

  @override
  ConsumerState<LocationSessionSheet> createState() =>
      _LocationSessionSheetState();
}

class _LocationSessionSheetState extends ConsumerState<LocationSessionSheet> {
  late String? _locationId = widget.editing?.locationId;
  late DateTime _start =
      widget.editing?.startedAt ??
      DateTime.now().subtract(const Duration(hours: 1));
  late DateTime? _end = widget.editing == null
      ? DateTime.now()
      : widget.editing!.endedAt;
  late final _note = TextEditingController(text: widget.editing?.note ?? '');
  bool _saving = false;

  bool get _ongoing => _end == null;
  bool get _valid =>
      _locationId != null &&
      (_ongoing ? !_start.isAfter(DateTime.now()) : _end!.isAfter(_start));

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    final n = ref.read(locationsNotifierProvider.notifier);
    final note = _note.text.trim();
    final e = widget.editing;
    if (e == null) {
      await n.addPastSession(
        locationId: _locationId!,
        startedAt: _start,
        endedAt: _end ?? DateTime.now(),
        note: note,
      );
    } else {
      await n.saveSession(
        e.copyWith(
          locationId: _locationId!,
          startedAt: _start,
          endedAt: _end,
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
    final locations = ref.watch(sortedSavedLocationsProvider);
    final known = locations.any((l) => l.id == _locationId);
    return SafeArea(
      child: Column(
        children: [
          PrismSheetTopBar(
            title: widget.editing == null
                ? l10n.locationsAddPastVisit
                : l10n.locationsEditVisit,
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
                    Expanded(child: Text(l10n.locationsPlaceLabel)),
                    PrismSelect<String>.compact(
                      value: known ? _locationId : null,
                      menuWidth: 240,
                      items: [
                        for (final l in locations)
                          PrismSelectItem(
                            value: l.id,
                            label: '${l.emoji ?? '📍'} ${l.name}',
                          ),
                      ],
                      onChanged: (v) => setState(() => _locationId = v),
                    ),
                  ],
                ),
                if (_locationId != null && !known)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      l10n.locationsDeletedPlace,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(height: 16),
                PrismDateTimePills(
                  label: l10n.locationsArrived,
                  dateTime: _start,
                  lastDate: DateTime.now(),
                  onChanged: (v) => setState(() => _start = v),
                ),
                const SizedBox(height: 12),
                if (widget.editing?.isActive ?? false)
                  PrismSwitchRow(
                    title: l10n.locationsStillHere,
                    value: _ongoing,
                    onChanged: (v) =>
                        setState(() => _end = v ? null : DateTime.now()),
                  ),
                if (!_ongoing)
                  PrismDateTimePills(
                    label: l10n.locationsLeft,
                    dateTime: _end,
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                    onChanged: (v) => setState(() => _end = v),
                  ),
                const SizedBox(height: 8),
                Text(
                  _valid
                      ? l10n.locationsDurationExact(
                          (_end ?? DateTime.now())
                              .difference(_start)
                              .toExactString(),
                        )
                      : l10n.locationsEndAfterStart,
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
                          .read(locationsNotifierProvider.notifier)
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
    );
  }
}
