import 'package:prism_plurality/shared/theme/prism_shapes.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/features/fronting_roles/roles_data.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/models/calendar_event.dart';
import 'package:prism_plurality/features/calendar/providers/calendar_providers.dart';
import 'package:prism_plurality/features/calendar/utils/recurrence.dart';
import 'package:prism_plurality/features/calendar/views/recurring_scope_dialog.dart';
import 'package:prism_plurality/features/calendar/widgets/calendar_colors.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/members/utils/member_search_groups.dart';
import 'package:prism_plurality/features/settings/providers/terminology_provider.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/member_avatar.dart';
import 'package:prism_plurality/shared/widgets/member_search_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_date_picker.dart';
import 'package:prism_plurality/shared/widgets/prism_datetime_pills.dart';
import 'package:prism_plurality/shared/widgets/prism_glass_icon_button.dart';
import 'package:prism_plurality/shared/widgets/prism_list_row.dart';
import 'package:prism_plurality/shared/widgets/prism_select.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_switch_row.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';
import 'package:prism_plurality/shared/widgets/unsaved_changes_guard.dart';
import 'package:prism_plurality/shared/widgets/weekday_picker.dart';

/// Opens the event editor.
///
/// * New event: pass [initialStart] (and optionally [initialAllDay]).
/// * Edit a series or one-off: pass [editing].
/// * Edit one occurrence of a recurring series: pass [occurrence]; the user
///   picks the scope on save.
/// * Duplicate: pass [duplicateOf].
Future<void> showEditEventSheet(
  BuildContext context, {
  CalendarEvent? editing,
  CalendarOccurrence? occurrence,
  CalendarEvent? duplicateOf,
  DateTime? initialStart,
  bool initialAllDay = false,
}) {
  return PrismSheet.showFullScreen(
    context: context,
    builder: (context, scrollController) => EditEventSheet(
      editing: editing ?? occurrence?.event,
      occurrence: occurrence,
      duplicateOf: duplicateOf,
      initialStart: initialStart,
      initialAllDay: initialAllDay,
      scrollController: scrollController,
    ),
  );
}

enum _EndsMode { never, onDate, afterCount }

class EditEventSheet extends ConsumerStatefulWidget {
  const EditEventSheet({
    super.key,
    this.editing,
    this.occurrence,
    this.duplicateOf,
    this.initialStart,
    this.initialAllDay = false,
    this.scrollController,
  });

  final CalendarEvent? editing;
  final CalendarOccurrence? occurrence;
  final CalendarEvent? duplicateOf;
  final DateTime? initialStart;
  final bool initialAllDay;
  final ScrollController? scrollController;

  @override
  ConsumerState<EditEventSheet> createState() => _EditEventSheetState();
}

class _EditEventSheetState extends ConsumerState<EditEventSheet> {
  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _description;
  late final TextEditingController _customCategory;
  late bool _allDay;
  late DateTime _start;
  late DateTime _end;
  late CalendarRecurrence _recurrence;
  late int _interval;
  late Set<int> _weekdays;
  late _EndsMode _endsMode;
  DateTime? _until;
  int _count = 10;
  late Set<int> _alerts;
  String? _category;
  String? _colorHex;
  late Set<String> _memberIds;
  late final String _initialSignature;
  bool _saving = false;

  bool get _isEditing => widget.editing != null && widget.duplicateOf == null;

  static const _alertOptions = [0, 5, 10, 15, 30, 60, 120, 1440, 2880, 10080];

  @override
  void initState() {
    super.initState();
    final source = widget.duplicateOf ?? widget.editing;
    final occ = widget.occurrence;
    _title = TextEditingController(text: source?.title ?? '');
    _location = TextEditingController(text: source?.location ?? '');
    _description = TextEditingController(text: source?.description ?? '');
    _customCategory = TextEditingController();
    _allDay = source?.isAllDay ?? widget.initialAllDay;
    if (occ != null) {
      // Editing one occurrence: show that occurrence's dates.
      _start = occ.start;
      _end = occ.end;
    } else if (source != null) {
      _start = source.startAt;
      _end = source.endAt;
    } else {
      final base = widget.initialStart ?? _nextHalfHour(DateTime.now());
      _start = _allDay ? DateTime(base.year, base.month, base.day) : base;
      _end = _allDay ? _start : _start.add(const Duration(hours: 1));
    }
    _recurrence = source?.recurrence ?? CalendarRecurrence.none;
    _interval = source?.recurrenceInterval ?? 1;
    _weekdays = {...?source?.recurrenceWeekdays};
    if (_weekdays.isEmpty) _weekdays = {_start.weekday % 7};
    _until = source?.recurrenceUntil;
    _count = source?.recurrenceCount ?? 10;
    _endsMode = source?.recurrenceUntil != null
        ? _EndsMode.onDate
        : (source?.recurrenceCount != null
              ? _EndsMode.afterCount
              : _EndsMode.never);
    _alerts = {...?source?.alertMinutes};
    if (source == null) _alerts = {15};
    _category = source?.category;
    _colorHex = source?.colorHex;
    _memberIds = {...?source?.memberIds};
    if (source == null) {
      // New events default to whoever is Primary right now.
      try {
        final primary = ref.read(primaryFronterIdProvider);
        if (primary != null) _memberIds = {primary};
      } catch (_) {}
    }
    _initialSignature = _signature();
  }

  static DateTime _nextHalfHour(DateTime now) {
    final add = now.minute < 30 ? 30 - now.minute : 60 - now.minute;
    final t = now.add(Duration(minutes: add));
    return DateTime(t.year, t.month, t.day, t.hour, t.minute);
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _description.dispose();
    _customCategory.dispose();
    super.dispose();
  }

  String _signature() => [
    _title.text,
    _location.text,
    _description.text,
    _allDay,
    _start.millisecondsSinceEpoch,
    _end.millisecondsSinceEpoch,
    _recurrence,
    _interval,
    (_weekdays.toList()..sort()).join(','),
    _endsMode,
    _until?.millisecondsSinceEpoch,
    _count,
    (_alerts.toList()..sort()).join(','),
    _category,
    _colorHex,
    (_memberIds.toList()..sort()).join(','),
  ].join('|');

  bool get _isDirty =>
      widget.duplicateOf != null || _signature() != _initialSignature;

  bool get _canSave => _title.text.trim().isNotEmpty && !_endBeforeStart;

  bool get _endBeforeStart => _allDay
      ? DateTime(
          _end.year,
          _end.month,
          _end.day,
        ).isBefore(DateTime(_start.year, _start.month, _start.day))
      : _end.isBefore(_start);

  CalendarEvent _build(CalendarEvent base) {
    final location = _location.text.trim();
    final description = _description.text.trim();
    return base.copyWith(
      title: _title.text.trim(),
      location: location.isEmpty ? null : location,
      description: description.isEmpty ? null : description,
      isAllDay: _allDay,
      startAt: _allDay
          ? DateTime(_start.year, _start.month, _start.day)
          : _start,
      endAt: _allDay ? DateTime(_end.year, _end.month, _end.day) : _end,
      recurrence: _recurrence,
      recurrenceInterval: _interval,
      recurrenceWeekdays: _recurrence == CalendarRecurrence.weekly
          ? (_weekdays.toList()..sort())
          : const [],
      recurrenceUntil:
          _recurrence != CalendarRecurrence.none &&
              _endsMode == _EndsMode.onDate
          ? _until
          : null,
      recurrenceCount:
          _recurrence != CalendarRecurrence.none &&
              _endsMode == _EndsMode.afterCount
          ? _count
          : null,
      alertMinutes: _alerts.toList()..sort(),
      category: _category,
      colorHex: _colorHex,
      memberIds: _memberIds.toList(),
    );
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    final notifier = ref.read(calendarNotifierProvider.notifier);
    final occ = widget.occurrence;
    if (_isEditing && occ != null && occ.event.isRecurring) {
      final scope = await showRecurringScopeDialog(
        context,
        title: context.l10n.calendarEditRecurringTitle,
      );
      if (scope == null || !mounted) return;
      setState(() => _saving = true);
      var edited = _build(occ.event);
      if (scope == RecurringEditScope.allOccurrences) {
        // Shift the series by however much this occurrence moved, keeping the
        // series' own first date.
        final shift = edited.startAt.difference(occ.start);
        final length = edited.endAt.difference(edited.startAt);
        final newStart = occ.event.startAt.add(shift);
        edited = edited.copyWith(
          startAt: newStart,
          endAt: newStart.add(length),
        );
      }
      await notifier.saveOccurrence(
        occurrence: occ,
        edited: edited,
        scope: scope,
      );
    } else if (_isEditing) {
      setState(() => _saving = true);
      await notifier.save(_build(widget.editing!));
    } else {
      setState(() => _saving = true);
      final base = notifier.newEvent(
        title: _title.text.trim(),
        startAt: _start,
        endAt: _end,
      );
      await notifier.create(_build(base));
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickMembers() async {
    final members = ref.read(userVisibleMemberListProvider).value ?? const [];
    final result = await MemberSearchSheet.showMulti(
      context,
      members: members,
      termPlural: readTerminology(context, ref).plural,
      initialSelected: _memberIds,
      allowEmptySelection: true,
      groups: readMemberSearchGroups(ref, members),
    );
    if (result != null && mounted) setState(() => _memberIds = result);
  }

  void _setStart(DateTime v) {
    final length = _end.difference(_start);
    setState(() {
      _start = v;
      _end = v.add(length.isNegative ? Duration.zero : length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final categories = ref.watch(calendarCategoriesProvider);

    return ListenableBuilder(
      listenable: Listenable.merge([_title, _location, _description]),
      builder: (context, _) => UnsavedChangesGuard<void>(
        hasUnsavedChanges: _isDirty && !_saving,
        child: SafeArea(
          child: Column(
            children: [
              PrismSheetTopBar(
                title: _isEditing
                    ? l10n.calendarEditEvent
                    : l10n.calendarNewEvent,
                trailing: PrismGlassIconButton(
                  icon: AppIcons.check,
                  tooltip: l10n.save,
                  size: PrismTokens.topBarActionSize,
                  tint: _canSave ? theme.colorScheme.primary : null,
                  accentIcon: _canSave,
                  onPressed: _canSave && !_saving ? _save : null,
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
                      controller: _title,
                      labelText: l10n.calendarTitleLabel,
                      autofocus: !_isEditing,
                    ),
                    const SizedBox(height: 12),
                    PrismSwitchRow(
                      title: l10n.calendarAllDay,
                      value: _allDay,
                      onChanged: (v) => setState(() {
                        _allDay = v;
                        if (v) {
                          _start = DateTime(
                            _start.year,
                            _start.month,
                            _start.day,
                          );
                          _end = DateTime(_end.year, _end.month, _end.day);
                        } else {
                          _start = DateTime(
                            _start.year,
                            _start.month,
                            _start.day,
                            9,
                          );
                          _end = _start.add(const Duration(hours: 1));
                        }
                      }),
                    ),
                    const SizedBox(height: 8),
                    if (_allDay) ...[
                      _DateRow(
                        label: l10n.calendarStarts,
                        date: _start,
                        onChanged: _setStart,
                      ),
                      _DateRow(
                        label: l10n.calendarEnds,
                        date: _end,
                        onChanged: (d) => setState(() => _end = d),
                      ),
                    ] else ...[
                      PrismDateTimePills(
                        label: l10n.calendarStarts,
                        dateTime: _start,
                        onChanged: _setStart,
                      ),
                      const SizedBox(height: 12),
                      PrismDateTimePills(
                        label: l10n.calendarEnds,
                        dateTime: _end,
                        onChanged: (v) => setState(() => _end = v),
                      ),
                    ],
                    if (_endBeforeStart) ...[
                      const SizedBox(height: 6),
                      Text(
                        l10n.calendarEndBeforeStart,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _Label(l10n.calendarRepeat),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final r in CalendarRecurrence.values)
                          PrismChip(
                            label: recurrenceLabel(context, r),
                            selected: _recurrence == r,
                            onTap: () => setState(() => _recurrence = r),
                          ),
                      ],
                    ),
                    if (_recurrence != CalendarRecurrence.none) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: Text(l10n.calendarRepeatEvery)),
                          PrismSelect<int>.compact(
                            value: _interval,
                            menuWidth: 200,
                            items: [
                              for (var i = 1; i <= 12; i++)
                                PrismSelectItem(
                                  value: i,
                                  label: recurrenceUnitLabel(
                                    context,
                                    _recurrence,
                                    i,
                                  ),
                                ),
                            ],
                            onChanged: (v) =>
                                setState(() => _interval = v ?? 1),
                          ),
                        ],
                      ),
                      if (_recurrence == CalendarRecurrence.weekly) ...[
                        const SizedBox(height: 12),
                        WeekdayPicker(
                          selected: _weekdays,
                          onChanged: (d) => setState(
                            () => _weekdays = d.isEmpty
                                ? {_start.weekday % 7}
                                : d,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: Text(l10n.calendarRepeatEnds)),
                          PrismSelect<_EndsMode>.compact(
                            value: _endsMode,
                            menuWidth: 200,
                            items: [
                              PrismSelectItem(
                                value: _EndsMode.never,
                                label: l10n.calendarEndsNever,
                              ),
                              PrismSelectItem(
                                value: _EndsMode.onDate,
                                label: l10n.calendarEndsOnDate,
                              ),
                              PrismSelectItem(
                                value: _EndsMode.afterCount,
                                label: l10n.calendarEndsAfterCount,
                              ),
                            ],
                            onChanged: (v) => setState(() {
                              _endsMode = v ?? _EndsMode.never;
                              if (_endsMode == _EndsMode.onDate) {
                                _until ??= DateTime(
                                  _start.year,
                                  _start.month + 3,
                                  _start.day,
                                );
                              }
                            }),
                          ),
                        ],
                      ),
                      if (_endsMode == _EndsMode.onDate)
                        _DateRow(
                          label: l10n.calendarEndsOnDate,
                          date: _until ?? _start,
                          onChanged: (d) => setState(() => _until = d),
                        ),
                      if (_endsMode == _EndsMode.afterCount)
                        Row(
                          children: [
                            Expanded(child: Text(l10n.calendarOccurrences)),
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: _count > 1
                                  ? () => setState(() => _count--)
                                  : null,
                            ),
                            Text('$_count', style: theme.textTheme.titleMedium),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: _count < 999
                                  ? () => setState(() => _count++)
                                  : null,
                            ),
                          ],
                        ),
                    ],
                    const SizedBox(height: 20),
                    _Label(l10n.calendarAlerts),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final m in _alertOptions)
                          PrismChip(
                            label: alertLabel(context, m),
                            selected: _alerts.contains(m),
                            onTap: () => setState(() {
                              if (!_alerts.remove(m)) _alerts.add(m);
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _Label(l10n.calendarCategory),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in {...categories, ?_category})
                          PrismChip(
                            label: c,
                            selected: _category == c,
                            onTap: () => setState(
                              () => _category = _category == c ? null : c,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: PrismTextField(
                            controller: _customCategory,
                            labelText: l10n.calendarCustomCategory,
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.calendarAddCategory,
                          icon: Icon(AppIcons.add),
                          onPressed: () {
                            final v = _customCategory.text.trim();
                            if (v.isEmpty) return;
                            setState(() {
                              _category = v;
                              _customCategory.clear();
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _Label(l10n.calendarColor),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _Swatch(
                          color: theme.colorScheme.primary,
                          selected: _colorHex == null,
                          onTap: () => setState(() => _colorHex = null),
                          label: l10n.calendarDefaultColor,
                        ),
                        for (final hex in calendarColorSwatches)
                          _Swatch(
                            color: parseHexColor(hex)!,
                            selected: _colorHex == hex,
                            onTap: () => setState(() => _colorHex = hex),
                            label: hex,
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    PrismTextField(
                      controller: _location,
                      labelText: l10n.calendarLocation,
                    ),
                    const SizedBox(height: 12),
                    _Label(l10n.calendarMembers),
                    const SizedBox(height: 8),
                    _MembersRow(memberIds: _memberIds, onTap: _pickMembers),
                    const SizedBox(height: 12),
                    PrismTextField(
                      controller: _description,
                      labelText: l10n.calendarNotes,
                      maxLines: 6,
                      minLines: 3,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.labelLarge);
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.date,
    required this.onChanged,
  });

  final String label;
  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Builder(
            builder: (anchor) => PrismButton(
              label: DateFormat.yMMMEd(context.dateLocale).format(date),
              tone: PrismButtonTone.subtle,
              onPressed: () async {
                final picked = await showPrismDatePicker(
                  context: context,
                  anchorContext: anchor,
                  initialDate: date,
                  firstDate: DateTime(1900),
                  lastDate: DateTime(2200),
                );
                if (picked != null) {
                  onChanged(DateTime(picked.year, picked.month, picked.day));
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
    required this.label,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        customBorder: prismCircleBorder(context),
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            borderRadius: prismRound(context),
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: 3,
            ),
          ),
          child: selected
              ? Icon(AppIcons.check, size: 16, color: onEventColor(color))
              : null,
        ),
      ),
    );
  }
}

class _MembersRow extends ConsumerWidget {
  const _MembersRow({required this.memberIds, required this.onTap});
  final Set<String> memberIds;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(userVisibleMemberListProvider).value ?? const [];
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    final selected = [
      for (final id in memberIds) ?members.firstWhereOrNull((m) => m.id == id),
    ];
    return PrismListRow(
      leading: selected.isEmpty
          ? Icon(AppIcons.peopleOutline)
          : SizedBox(
              width: 32 + 14.0 * (selected.length.clamp(1, 4) - 1),
              height: 32,
              child: Stack(
                children: [
                  for (var i = 0; i < selected.length && i < 4; i++)
                    Positioned(
                      left: 14.0 * i,
                      child: MemberAvatar(
                        avatarImageData: selected[i].avatarImageData,
                        memberName: selected[i].effectiveName(
                          preferDisplayName: prefer,
                        ),
                        emoji: selected[i].emoji,
                        customColorEnabled: selected[i].customColorEnabled,
                        customColorHex: selected[i].customColorHex,
                        size: 32,
                      ),
                    ),
                ],
              ),
            ),
      title: Text(
        selected.isEmpty
            ? context.l10n.calendarNoMembers
            : selected
                  .map((m) => m.effectiveName(preferDisplayName: prefer))
                  .join(', '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(AppIcons.expandMore),
      onTap: onTap,
    );
  }
}

String recurrenceLabel(BuildContext context, CalendarRecurrence r) {
  final l10n = context.l10n;
  return switch (r) {
    CalendarRecurrence.none => l10n.calendarRepeatNone,
    CalendarRecurrence.daily => l10n.calendarRepeatDaily,
    CalendarRecurrence.weekly => l10n.calendarRepeatWeekly,
    CalendarRecurrence.monthly => l10n.calendarRepeatMonthly,
    CalendarRecurrence.yearly => l10n.calendarRepeatYearly,
  };
}

String recurrenceUnitLabel(
  BuildContext context,
  CalendarRecurrence r,
  int count,
) {
  final l10n = context.l10n;
  return switch (r) {
    CalendarRecurrence.none => '',
    CalendarRecurrence.daily => l10n.calendarEveryNDays(count),
    CalendarRecurrence.weekly => l10n.calendarEveryNWeeks(count),
    CalendarRecurrence.monthly => l10n.calendarEveryNMonths(count),
    CalendarRecurrence.yearly => l10n.calendarEveryNYears(count),
  };
}

String alertLabel(BuildContext context, int minutes) {
  final l10n = context.l10n;
  if (minutes == 0) return l10n.calendarAlertAtStart;
  if (minutes < 60) return l10n.calendarAlertMinutes(minutes);
  if (minutes < 1440) return l10n.calendarAlertHours(minutes ~/ 60);
  if (minutes % 10080 == 0) return l10n.calendarAlertWeeks(minutes ~/ 10080);
  return l10n.calendarAlertDays(minutes ~/ 1440);
}
