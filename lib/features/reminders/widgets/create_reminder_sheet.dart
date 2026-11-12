import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/models/reminder.dart';
import 'package:prism_plurality/domain/preferences/fronting_terms.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/members/utils/member_search_groups.dart';
import 'package:prism_plurality/features/settings/providers/terminology_provider.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/features/reminders/providers/reminders_providers.dart';
import 'package:prism_plurality/features/reminders/utils/reminder_times.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_glass_icon_button.dart';
import 'package:prism_plurality/shared/widgets/info_banner.dart';
import 'package:prism_plurality/shared/widgets/member_avatar.dart';
import 'package:prism_plurality/shared/widgets/member_search_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_list_row.dart';
import 'package:prism_plurality/shared/widgets/prism_loading_state.dart';
import 'package:prism_plurality/shared/widgets/prism_select.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/widgets/prism_segmented_control.dart';
import 'package:prism_plurality/shared/widgets/prism_time_picker.dart';
import 'package:prism_plurality/shared/widgets/unsaved_changes_guard.dart';
import 'package:prism_plurality/shared/widgets/weekday_picker.dart';

/// How the times of a scheduled reminder are chosen.
enum _TimesMode { specific, everyFewHours }

class CreateReminderSheet extends ConsumerStatefulWidget {
  const CreateReminderSheet({super.key, this.editing, this.scrollController});

  final Reminder? editing;
  final ScrollController? scrollController;

  @override
  ConsumerState<CreateReminderSheet> createState() =>
      _CreateReminderSheetState();
}

class _CreateReminderSheetState extends ConsumerState<CreateReminderSheet> {
  late TextEditingController _nameController;
  late TextEditingController _messageController;
  late ReminderTrigger _trigger;
  late ReminderFrequency _frequency;
  late Set<int> _weeklyDays;
  int? _intervalDays;
  late List<TimeOfDay> _times;
  _TimesMode _timesMode = _TimesMode.specific;
  int _everyMinutes = 120;
  TimeOfDay _rangeStart = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _rangeEnd = const TimeOfDay(hour: 21, minute: 0);
  int? _delayHours;
  String? _targetMemberId;
  late final String _initialName;
  late final String _initialMessage;
  late final ReminderTrigger _initialTrigger;
  late final ReminderFrequency _initialFrequency;
  late final Set<int> _initialWeeklyDays;
  late final int? _initialIntervalDays;
  late final List<TimeOfDay> _initialTimes;
  late final int? _initialDelayHours;
  late final String? _initialTargetMemberId;

  bool get _isEditing => widget.editing != null;
  bool get _canSave =>
      _nameController.text.trim().isNotEmpty &&
      !(_trigger == ReminderTrigger.scheduled &&
          _frequency == ReminderFrequency.weekly &&
          _weeklyDays.isEmpty);
  bool get _isDirty =>
      _nameController.text != _initialName ||
      _messageController.text != _initialMessage ||
      _trigger != _initialTrigger ||
      _frequency != _initialFrequency ||
      !_setEquals(_weeklyDays, _initialWeeklyDays) ||
      _intervalDays != _initialIntervalDays ||
      !_timesEqual(_effectiveTimes, _initialTimes) ||
      _delayHours != _initialDelayHours ||
      _targetMemberId != _initialTargetMemberId;

  @override
  void initState() {
    super.initState();
    final r = widget.editing;
    _nameController = TextEditingController(text: r?.name ?? '');
    _messageController = TextEditingController(text: r?.message ?? '');
    _trigger = r?.trigger ?? ReminderTrigger.scheduled;
    _frequency = r?.frequency ?? ReminderFrequency.daily;
    _weeklyDays = r?.weeklyDays?.toSet() ?? <int>{};
    // Interval dropdown now starts at 2 (1 is represented by the Daily
    // frequency). If editing a reminder that arrived here with intervalDays=1
    // under the interval frequency, bump it up to a valid option.
    final editingInterval = r?.intervalDays;
    _intervalDays =
        (_frequency == ReminderFrequency.interval &&
            (editingInterval == null || editingInterval < 2))
        ? 2
        : (editingInterval ?? 2);
    _delayHours = r?.delayHours ?? 0;
    _targetMemberId = r?.targetMemberId;
    _times = r == null
        ? const [TimeOfDay(hour: 9, minute: 0)]
        : sortedUniqueTimes(
            r.allTimesOfDay.map(parseReminderTime).whereType<TimeOfDay>(),
          );
    if (_times.isEmpty) _times = const [TimeOfDay(hour: 9, minute: 0)];
    _rangeStart = _times.first;
    if (_times.length > 1) _rangeEnd = _times.last;
    _initialName = _nameController.text;
    _initialMessage = _messageController.text;
    _initialTrigger = _trigger;
    _initialFrequency = _frequency;
    _initialWeeklyDays = Set<int>.from(_weeklyDays);
    _initialIntervalDays = _intervalDays;
    _initialTimes = List.of(_times);
    _initialDelayHours = _delayHours;
    _initialTargetMemberId = _targetMemberId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _openTargetPicker(List<Member> members) async {
    final groups = readMemberSearchGroups(ref, members);
    final frontingTerms = readFrontingTerms(context, ref);
    final result = await MemberSearchSheet.showSingle(
      context,
      members: members,
      termPlural: readTerminology(context, ref).plural,
      groups: groups,
      specialRows: [
        MemberSearchSpecialRow(
          rowKey: '__any__',
          title: frontingTerms.anyChangeLabel,
          leading: Icon(AppIcons.peopleOutline),
          result: const MemberSearchResultCleared(),
        ),
      ],
    );
    if (!mounted) return;
    switch (result) {
      case MemberSearchResultSelected(:final memberId):
        setState(() => _targetMemberId = memberId);
      case MemberSearchResultCleared():
        setState(() => _targetMemberId = null);
      case MemberSearchResultDismissed():
      case MemberSearchResultUnknown():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSave = _canSave;
    // Non-fronting picker: hide the Unknown sentinel — you don't set a
    // reminder for the placeholder member.
    final membersAsync = ref.watch(userVisibleMemberListProvider);
    final frontingTerms = watchFrontingTerms(context, ref);

    return ListenableBuilder(
      listenable: Listenable.merge([_nameController, _messageController]),
      builder: (context, _) => UnsavedChangesGuard<void>(
        hasUnsavedChanges: _isDirty,
        child: SafeArea(
          child: Column(
            children: [
              PrismSheetTopBar(
                title: _isEditing
                    ? context.l10n.remindersEditTitle
                    : context.l10n.remindersNewTitle,
                trailing: PrismGlassIconButton(
                  icon: AppIcons.check,
                  tooltip: context.l10n.save,
                  size: PrismTokens.topBarActionSize,
                  tint: canSave ? theme.colorScheme.primary : null,
                  accentIcon: canSave,
                  onPressed: canSave ? _save : null,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  controller: widget.scrollController,
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  children: [
                    PrismTextField(
                      controller: _nameController,
                      labelText: context.l10n.remindersNameLabel,
                      autofocus: !_isEditing,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),

                    PrismTextField(
                      controller: _messageController,
                      labelText: context.l10n.remindersMessageLabel,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

                    // Trigger type
                    Text(
                      context.l10n.remindersTriggerLabel,
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    PrismSegmentedControl<ReminderTrigger>(
                      segments: [
                        PrismSegment(
                          value: ReminderTrigger.scheduled,
                          label: context.l10n.remindersScheduled,
                        ),
                        PrismSegment(
                          value: ReminderTrigger.onFrontChange,
                          label: frontingTerms.changeSingular,
                        ),
                      ],
                      selected: _trigger,
                      onChanged: (value) => setState(() => _trigger = value),
                    ),
                    const SizedBox(height: 16),

                    // Conditional fields
                    if (_trigger == ReminderTrigger.scheduled) ...[
                      // Schedule section: frequency + frequency-specific fields.
                      Text(
                        context.l10n.remindersScheduleLabel,
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      PrismSegmentedControl<ReminderFrequency>(
                        segments: [
                          PrismSegment(
                            value: ReminderFrequency.daily,
                            label: context.l10n.remindersSubtitleDaily,
                          ),
                          PrismSegment(
                            value: ReminderFrequency.weekly,
                            label: context.l10n.remindersFrequencyWeekly,
                          ),
                          PrismSegment(
                            value: ReminderFrequency.interval,
                            label: context.l10n.remindersFrequencyInterval,
                          ),
                        ],
                        selected: _frequency,
                        onChanged: (value) => setState(() {
                          _frequency = value;
                          // Keep interval dropdown on a valid option when
                          // switching into the interval frequency.
                          if (value == ReminderFrequency.interval &&
                              (_intervalDays == null || _intervalDays! < 2)) {
                            _intervalDays = 2;
                          }
                        }),
                      ),
                      const SizedBox(height: 12),
                      if (_frequency == ReminderFrequency.weekly) ...[
                        WeekdayPicker(
                          selected: _weeklyDays,
                          onChanged: (days) =>
                              setState(() => _weeklyDays = days),
                        ),
                        if (_weeklyDays.isEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            context.l10n.remindersWeeklyEmptyHelper,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                      ] else if (_frequency == ReminderFrequency.interval) ...[
                        _LabeledRow(
                          label: context.l10n.remindersRepeatEveryLabel,
                          child: PrismSelect<int>.compact(
                            value: _intervalDays ?? 2,
                            menuWidth: 180,
                            items: [
                              PrismSelectItem(
                                value: 2,
                                label: context.l10n.remindersIntervalDays(2),
                              ),
                              PrismSelectItem(
                                value: 3,
                                label: context.l10n.remindersIntervalDays(3),
                              ),
                              PrismSelectItem(
                                value: 7,
                                label: context.l10n.remindersIntervalDays(7),
                              ),
                              PrismSelectItem(
                                value: 14,
                                label: context.l10n.remindersIntervalDays(14),
                              ),
                              PrismSelectItem(
                                value: 30,
                                label: context.l10n.remindersIntervalDays(30),
                              ),
                            ],
                            onChanged: (v) => setState(() => _intervalDays = v),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      // Times (all scheduled frequencies fire at one or more
                      // times of day).
                      _TimesEditor(
                        mode: _timesMode,
                        times: _times,
                        everyMinutes: _everyMinutes,
                        rangeStart: _rangeStart,
                        rangeEnd: _rangeEnd,
                        onModeChanged: (mode) =>
                            setState(() => _timesMode = mode),
                        onTimesChanged: (times) =>
                            setState(() => _times = sortedUniqueTimes(times)),
                        onEveryMinutesChanged: (v) =>
                            setState(() => _everyMinutes = v),
                        onRangeStartChanged: (v) =>
                            setState(() => _rangeStart = v),
                        onRangeEndChanged: (v) => setState(() => _rangeEnd = v),
                      ),
                    ] else ...[
                      // Delay picker for front change
                      _LabeledRow(
                        label: frontingTerms.delayAfterChangeLabel,
                        child: PrismSelect<int>.compact(
                          value: _delayHours ?? 0,
                          menuWidth: 180,
                          items: [
                            PrismSelectItem(
                              value: 0,
                              label: context.l10n.remindersImmediately,
                            ),
                            PrismSelectItem(
                              value: 1,
                              label: context.l10n.remindersDelayHours(1),
                            ),
                            PrismSelectItem(
                              value: 2,
                              label: context.l10n.remindersDelayHours(2),
                            ),
                            PrismSelectItem(
                              value: 4,
                              label: context.l10n.remindersDelayHours(4),
                            ),
                            PrismSelectItem(
                              value: 8,
                              label: context.l10n.remindersDelayHours(8),
                            ),
                            PrismSelectItem(
                              value: 12,
                              label: context.l10n.remindersDelayHours(12),
                            ),
                          ],
                          onChanged: (v) => setState(() => _delayHours = v),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Optional member target. null = any front change (current
                      // behavior). Non-null narrows firing to switches where this
                      // member is in the current fronter set.
                      Text(
                        context.l10n.remindersTargetLabel,
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      membersAsync.when(
                        loading: () => const SizedBox(
                          height: 56,
                          child: PrismLoadingState(),
                        ),
                        error: (e, _) => Text(context.l10n.errorWithDetail(e)),
                        data: (members) {
                          final selectedMember = members.firstWhereOrNull(
                            (member) => member.id == _targetMemberId,
                          );
                          watchMemberSearchGroupSources(ref);
                          final prefer = ref.watch(
                            memberNamePreferDisplayProvider,
                          );
                          final selectedName = selectedMember?.effectiveName(
                            preferDisplayName: prefer,
                          );
                          return PrismListRow(
                            leading: selectedMember != null
                                ? MemberAvatar(
                                    avatarImageData:
                                        selectedMember.avatarImageData,
                                    memberName: selectedName!,
                                    emoji: selectedMember.emoji,
                                    customColorEnabled:
                                        selectedMember.customColorEnabled,
                                    customColorHex:
                                        selectedMember.customColorHex,
                                    size: 32,
                                  )
                                : Icon(AppIcons.peopleOutline),
                            title: Text(
                              selectedName ?? frontingTerms.anyChangeLabel,
                            ),
                            subtitle: selectedMember != null
                                ? Text(context.l10n.remindersTargetLabel)
                                : null,
                            trailing: Icon(AppIcons.expandMore),
                            onTap: () => _openTargetPicker(members),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      // Honesty disclosure: Prism's relay only sees ciphertext, so
                      // front-change reminders only fire when THIS device observes
                      // the switch. That limitation applies whether the reminder
                      // targets a specific member or any front change.
                      InfoBanner(
                        icon: AppIcons.infoOutlineRounded,
                        iconColor: theme.colorScheme.primary,
                        title: frontingTerms.changeSingular,
                        message: _frontChangeReminderDisclosure(frontingTerms),
                      ),
                    ],

                    if (_isEditing) ...[
                      const SizedBox(height: 24),
                      PrismButton(
                        label: context.l10n.delete,
                        tone: PrismButtonTone.destructive,
                        onPressed: () {
                          ref
                              .read(remindersNotifierProvider.notifier)
                              .deleteReminder(widget.editing!.id);
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The times that will be saved for the current editor state.
  List<TimeOfDay> get _effectiveTimes => switch (_timesMode) {
    _TimesMode.specific => _times,
    _TimesMode.everyFewHours => evenlySpacedTimes(
      start: _rangeStart,
      end: _rangeEnd,
      everyMinutes: _everyMinutes,
    ),
  };

  bool _timesEqual(List<TimeOfDay> a, List<TimeOfDay> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _setEquals(Set<int> left, Set<int> right) =>
      left.length == right.length && left.containsAll(right);

  void _save() {
    final name = _nameController.text.trim();
    final message = _messageController.text.trim();
    if (name.isEmpty || message.isEmpty) return;

    final notifier = ref.read(remindersNotifierProvider.notifier);
    final times = _effectiveTimes.map(formatReminderTime).toList();
    final timeStr = times.isEmpty ? null : times.first;
    final extraTimes = times.length > 1 ? times.sublist(1) : null;

    final isScheduled = _trigger == ReminderTrigger.scheduled;
    final frequency = isScheduled ? _frequency : ReminderFrequency.daily;
    final weeklyDays = isScheduled && _frequency == ReminderFrequency.weekly
        ? (_weeklyDays.toList()..sort())
        : null;
    final intervalDays = isScheduled && _frequency == ReminderFrequency.interval
        ? _intervalDays
        : null;

    final targetMemberId = _trigger == ReminderTrigger.onFrontChange
        ? _targetMemberId
        : null;

    if (_isEditing) {
      notifier.updateReminder(
        widget.editing!.copyWith(
          name: name,
          message: message,
          trigger: _trigger,
          frequency: frequency,
          weeklyDays: weeklyDays,
          intervalDays: intervalDays,
          timeOfDay: isScheduled ? timeStr : null,
          additionalTimes: isScheduled ? extraTimes : null,
          delayHours: _trigger == ReminderTrigger.onFrontChange
              ? _delayHours
              : null,
          targetMemberId: targetMemberId,
        ),
      );
    } else {
      notifier.createReminder(
        name: name,
        message: message,
        trigger: _trigger,
        frequency: frequency,
        weeklyDays: weeklyDays,
        intervalDays: intervalDays,
        timeOfDay: isScheduled ? timeStr : null,
        additionalTimes: isScheduled ? extraTimes : null,
        delayHours: _trigger == ReminderTrigger.onFrontChange
            ? _delayHours
            : null,
        targetMemberId: targetMemberId,
      );
    }
    Navigator.of(context).pop();
  }
}

String _frontChangeReminderDisclosure(FrontingTermBundle frontingTerms) {
  final event = frontingTerms.switchEventLabel.toLowerCase();
  return 'Only fires when Prism is running on this device and notices the '
      '$event. If Prism is closed and the $event is logged elsewhere, this '
      'reminder will not trigger right away.';
}

class _LabeledRow extends StatelessWidget {
  const _LabeledRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        child,
      ],
    );
  }
}

/// Editor for the time(s) of day a scheduled reminder fires.
///
/// "Specific times" is a list of times the user picks one by one. "Every few
/// hours" generates evenly spaced times between a start and an end time.
class _TimesEditor extends StatelessWidget {
  const _TimesEditor({
    required this.mode,
    required this.times,
    required this.everyMinutes,
    required this.rangeStart,
    required this.rangeEnd,
    required this.onModeChanged,
    required this.onTimesChanged,
    required this.onEveryMinutesChanged,
    required this.onRangeStartChanged,
    required this.onRangeEndChanged,
  });

  final _TimesMode mode;
  final List<TimeOfDay> times;
  final int everyMinutes;
  final TimeOfDay rangeStart;
  final TimeOfDay rangeEnd;
  final ValueChanged<_TimesMode> onModeChanged;
  final ValueChanged<List<TimeOfDay>> onTimesChanged;
  final ValueChanged<int> onEveryMinutesChanged;
  final ValueChanged<TimeOfDay> onRangeStartChanged;
  final ValueChanged<TimeOfDay> onRangeEndChanged;

  static const _intervalOptions = [30, 60, 90, 120, 180, 240, 360, 480];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final generated = evenlySpacedTimes(
      start: rangeStart,
      end: rangeEnd,
      everyMinutes: everyMinutes,
    );
    final canAdd = times.length < Reminder.maxTimesPerDay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.remindersTimesPerDayLabel,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        PrismSegmentedControl<_TimesMode>(
          segments: [
            PrismSegment(
              value: _TimesMode.specific,
              label: context.l10n.remindersTimesSpecific,
            ),
            PrismSegment(
              value: _TimesMode.everyFewHours,
              label: context.l10n.remindersTimesEveryFewHours,
            ),
          ],
          selected: mode,
          onChanged: onModeChanged,
        ),
        const SizedBox(height: 12),
        if (mode == _TimesMode.specific) ...[
          for (var i = 0; i < times.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      times.length == 1
                          ? context.l10n.remindersTimeLabel
                          : context.l10n.remindersTimeNumberLabel(i + 1),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  _TimeButton(
                    time: times[i],
                    onPicked: (picked) {
                      final next = List.of(times)..[i] = picked;
                      onTimesChanged(next);
                    },
                  ),
                  if (times.length > 1)
                    IconButton(
                      tooltip: context.l10n.remindersRemoveTime,
                      icon: Icon(AppIcons.close, size: 18),
                      onPressed: () =>
                          onTimesChanged(List.of(times)..removeAt(i)),
                    ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: Builder(
              builder: (anchorContext) => PrismButton(
                label: context.l10n.remindersAddTime,
                icon: AppIcons.add,
                tone: PrismButtonTone.subtle,
                enabled: canAdd,
                onPressed: canAdd
                    ? () async {
                        final last = times.isEmpty
                            ? const TimeOfDay(hour: 9, minute: 0)
                            : times.last;
                        final suggested = TimeOfDay(
                          hour: (last.hour + 3) % 24,
                          minute: last.minute,
                        );
                        final picked = await showPrismTimePicker(
                          context: context,
                          anchorContext: anchorContext,
                          initialTime: suggested,
                        );
                        if (picked != null) {
                          onTimesChanged([...times, picked]);
                        }
                      }
                    : () {},
              ),
            ),
          ),
          if (!canAdd)
            Text(
              context.l10n.remindersMaxTimesHelper(Reminder.maxTimesPerDay),
              style: theme.textTheme.bodySmall,
            ),
        ] else ...[
          _LabeledRow(
            label: context.l10n.remindersRepeatEveryLabel,
            child: PrismSelect<int>.compact(
              value: _intervalOptions.contains(everyMinutes)
                  ? everyMinutes
                  : 120,
              menuWidth: 180,
              items: [
                for (final m in _intervalOptions)
                  PrismSelectItem(
                    value: m,
                    label: m < 60
                        ? context.l10n.remindersEveryMinutes(m)
                        : (m % 60 == 0
                              ? context.l10n.remindersEveryHours(m ~/ 60)
                              : context.l10n.remindersEveryMinutes(m)),
                  ),
              ],
              onChanged: (v) {
                if (v != null) onEveryMinutesChanged(v);
              },
            ),
          ),
          const SizedBox(height: 8),
          _LabeledRow(
            label: context.l10n.remindersFromLabel,
            child: _TimeButton(time: rangeStart, onPicked: onRangeStartChanged),
          ),
          const SizedBox(height: 8),
          _LabeledRow(
            label: context.l10n.remindersUntilLabel,
            child: _TimeButton(time: rangeEnd, onPicked: onRangeEndChanged),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.remindersGeneratedTimes(
              generated.map((t) => t.format(context)).join(', '),
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({required this.time, required this.onPicked});

  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onPicked;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (anchorContext) => PrismButton(
        label: time.format(context),
        tone: PrismButtonTone.subtle,
        onPressed: () async {
          final picked = await showPrismTimePicker(
            context: context,
            anchorContext: anchorContext,
            initialTime: time,
          );
          if (picked != null) onPicked(picked);
        },
      ),
    );
  }
}
