import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/models/mood_entry.dart';
import 'package:prism_plurality/features/fronting/providers/fronting_providers.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/members/utils/member_search_groups.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_plurality/features/mood/providers/mood_providers.dart';
import 'package:prism_plurality/features/mood/widgets/emotion_picker.dart';
import 'package:prism_plurality/features/mood/widgets/mood_level.dart';
import 'package:prism_plurality/features/settings/providers/terminology_provider.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/member_avatar.dart';
import 'package:prism_plurality/shared/widgets/member_search_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_datetime_pills.dart';
import 'package:prism_plurality/shared/widgets/prism_dialog.dart';
import 'package:prism_plurality/shared/widgets/prism_glass_icon_button.dart';
import 'package:prism_plurality/shared/widgets/prism_list_row.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';
import 'package:prism_plurality/shared/widgets/unsaved_changes_guard.dart';

/// Opens the mood check-in sheet, optionally editing [editing] or
/// pre-selecting [initialMood].
Future<void> showLogMoodSheet(
  BuildContext context, {
  MoodEntry? editing,
  int? initialMood,
}) {
  return PrismSheet.showFullScreen(
    context: context,
    builder: (context, scrollController) => LogMoodSheet(
      editing: editing,
      initialMood: initialMood,
      scrollController: scrollController,
    ),
  );
}

class LogMoodSheet extends ConsumerStatefulWidget {
  const LogMoodSheet({
    super.key,
    this.editing,
    this.initialMood,
    this.scrollController,
  });

  final MoodEntry? editing;
  final int? initialMood;
  final ScrollController? scrollController;

  @override
  ConsumerState<LogMoodSheet> createState() => _LogMoodSheetState();
}

class _LogMoodSheetState extends ConsumerState<LogMoodSheet> {
  late int _mood;
  late int _intensity;
  late EmotionSelection _emotions;
  int? _energy;
  int? _stress;
  int? _sleepQuality;
  late Set<String> _body;
  String? _memberId;
  bool _memberTouched = false;
  late DateTime _recordedAt;
  late final TextEditingController _note;
  late final String _initialSignature;
  bool _saving = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _mood = e?.mood ?? widget.initialMood ?? 3;
    _intensity = e?.intensity ?? 5;
    _emotions = decodeEmotionSelection(e?.emotions ?? const []);
    _energy = e?.energy;
    _stress = e?.stress;
    _sleepQuality = e?.sleepQuality;
    _body = {...?e?.bodySensations};
    _memberId = e?.memberId;
    _memberTouched = e != null;
    _recordedAt = e?.recordedAt ?? DateTime.now();
    _note = TextEditingController(text: e?.note ?? '');
    _initialSignature = _signature();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String _signature() => [
    _mood,
    _intensity,
    (encodeEmotionSelection(_emotions)..sort()).join(','),
    _energy,
    _stress,
    _sleepQuality,
    (_body.toList()..sort()).join(','),
    _memberId,
    _recordedAt.millisecondsSinceEpoch,
    _note.text,
  ].join('|');

  bool get _isDirty => !_isEditing || _signature() != _initialSignature;

  /// Defaults "who is feeling this" to the sole current fronter.
  String? _defaultMemberId() {
    final sessions = ref.read(activeSessionsProvider).value;
    if (sessions == null) return null;
    final ids = sessions.map((s) => s.memberId).whereType<String>().toSet();
    return ids.length == 1 ? ids.first : null;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final notifier = ref.read(moodNotifierProvider.notifier);
    final note = _note.text.trim();
    final memberId = _memberTouched ? _memberId : _defaultMemberId();
    if (_isEditing) {
      await notifier.save(
        widget.editing!.copyWith(
          mood: _mood,
          intensity: _intensity,
          emotions: encodeEmotionSelection(_emotions),
          energy: _energy,
          stress: _stress,
          sleepQuality: _sleepQuality,
          bodySensations: _body.toList(),
          memberId: memberId,
          recordedAt: _recordedAt,
          note: note.isEmpty ? null : note,
        ),
      );
    } else {
      await notifier.create(
        mood: _mood,
        intensity: _intensity,
        emotions: encodeEmotionSelection(_emotions),
        energy: _energy,
        stress: _stress,
        sleepQuality: _sleepQuality,
        bodySensations: _body.toList(),
        memberId: memberId,
        recordedAt: _recordedAt,
        note: note.isEmpty ? null : note,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await PrismDialog.confirm(
      context: context,
      title: context.l10n.moodDeleteTitle,
      message: context.l10n.moodDeleteMessage,
      confirmLabel: context.l10n.delete,
      cancelLabel: context.l10n.cancel,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await ref.read(moodNotifierProvider.notifier).delete(widget.editing!.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickMember(List<Member> members) async {
    final result = await MemberSearchSheet.showSingle(
      context,
      members: members,
      termPlural: readTerminology(context, ref).plural,
      groups: readMemberSearchGroups(ref, members),
      specialRows: [
        MemberSearchSpecialRow(
          rowKey: '__system__',
          title: context.l10n.moodWholeSystem,
          leading: Icon(AppIcons.peopleOutline),
          result: const MemberSearchResultCleared(),
        ),
      ],
    );
    if (!mounted) return;
    switch (result) {
      case MemberSearchResultSelected(:final memberId):
        setState(() {
          _memberId = memberId;
          _memberTouched = true;
        });
      case MemberSearchResultCleared():
        setState(() {
          _memberId = null;
          _memberTouched = true;
        });
      case MemberSearchResultDismissed():
      case MemberSearchResultUnknown():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return ListenableBuilder(
      listenable: _note,
      builder: (context, _) => UnsavedChangesGuard<void>(
        hasUnsavedChanges: _isDirty && !_saving,
        child: SafeArea(
          child: Column(
            children: [
              PrismSheetTopBar(
                title: _isEditing ? l10n.moodEditTitle : l10n.moodLogTitle,
                trailing: PrismGlassIconButton(
                  icon: AppIcons.check,
                  tooltip: l10n.save,
                  size: PrismTokens.topBarActionSize,
                  tint: theme.colorScheme.primary,
                  accentIcon: true,
                  onPressed: _saving ? null : _save,
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
                    Text(
                      l10n.moodHowAreYou,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _MoodSelector(
                      value: _mood,
                      onChanged: (v) => setState(() => _mood = v),
                    ),
                    const SizedBox(height: 20),
                    _SliderRow(
                      label: l10n.moodIntensityLabel,
                      value: _intensity,
                      min: MoodEntry.minIntensity,
                      max: MoodEntry.maxIntensity,
                      color: MoodLevel.color(_mood),
                      valueLabel: '$_intensity / ${MoodEntry.maxIntensity}',
                      onChanged: (v) => setState(() => _intensity = v),
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel(l10n.moodEmotionsLabel),
                    const SizedBox(height: 4),
                    Text(
                      l10n.moodEmotionsHelper,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    EmotionPicker(
                      selected: _emotions,
                      onChanged: (v) => setState(() => _emotions = v),
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel(l10n.moodWellbeingLabel),
                    const SizedBox(height: 8),
                    _ScalePicker(
                      label: l10n.moodEnergyLabel,
                      icon: AppIcons.flashOn,
                      value: _energy,
                      onChanged: (v) => setState(() => _energy = v),
                    ),
                    _ScalePicker(
                      label: l10n.moodStressLabel,
                      icon: AppIcons.warningAmberRounded,
                      value: _stress,
                      onChanged: (v) => setState(() => _stress = v),
                    ),
                    _ScalePicker(
                      label: l10n.moodSleepQualityLabel,
                      icon: AppIcons.bedtimeOutlined,
                      value: _sleepQuality,
                      onChanged: (v) => setState(() => _sleepQuality = v),
                    ),
                    const SizedBox(height: 20),
                    TextButton.icon(
                      icon: const Icon(Icons.accessibility_new),
                      label: const Text('Body Map is now in Health'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.push('/health?tab=body');
                      },
                    ),
                    _SectionLabel(l10n.moodWhoLabel),
                    const SizedBox(height: 8),
                    _MemberRow(
                      memberId: _memberTouched ? _memberId : _defaultMemberId(),
                      onTap: _pickMember,
                    ),
                    const SizedBox(height: 16),
                    PrismDateTimePills(
                      label: l10n.moodWhenLabel,
                      dateTime: _recordedAt,
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                      onChanged: (v) => setState(() => _recordedAt = v),
                    ),
                    const SizedBox(height: 16),
                    PrismTextField(
                      controller: _note,
                      labelText: l10n.moodNoteLabel,
                      maxLines: 4,
                      minLines: 2,
                    ),
                    if (_isEditing) ...[
                      const SizedBox(height: 24),
                      PrismButton(
                        label: l10n.delete,
                        tone: PrismButtonTone.destructive,
                        onPressed: _delete,
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
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.labelLarge);
}

class _MoodSelector extends StatelessWidget {
  const _MoodSelector({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var level = MoodEntry.minMood; level <= MoodEntry.maxMood; level++)
          Expanded(
            child: Semantics(
              button: true,
              selected: level == value,
              label: MoodLevel.label(context, level),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onChanged(level),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: level == value
                        ? MoodLevel.color(level).withValues(alpha: 0.22)
                        : Colors.transparent,
                    border: Border.all(
                      color: level == value
                          ? MoodLevel.color(level)
                          : theme.colorScheme.outline.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        MoodLevel.emoji(level),
                        style: const TextStyle(fontSize: 30, height: 1.1),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        MoodLevel.label(context, level),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: level == value
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.valueLabel,
    required this.onChanged,
    this.color,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final String valueLabel;
  final ValueChanged<int> onChanged;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.labelLarge)),
            Text(valueLabel, style: theme.textTheme.labelMedium),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          activeColor: color,
          label: valueLabel,
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }
}

class _ScalePicker extends StatelessWidget {
  const _ScalePicker({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          for (var i = MoodEntry.minScale; i <= MoodEntry.maxScale; i++)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Tooltip(
                message: scaleLabel(context, i),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  // Tapping the selected value again clears it.
                  onTap: () => onChanged(value == i ? null : i),
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: value != null && i <= value!
                          ? theme.colorScheme.primary.withValues(
                              alpha: 0.18 + 0.14 * i,
                            )
                          : theme.colorScheme.surfaceContainerHighest,
                      border: Border.all(
                        color: value == i
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Text('$i', style: theme.textTheme.labelMedium),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MemberRow extends ConsumerWidget {
  const _MemberRow({required this.memberId, required this.onTap});

  final String? memberId;
  final void Function(List<Member> members) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(userVisibleMemberListProvider).value ?? const [];
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    final member = members.firstWhereOrNull((m) => m.id == memberId);
    final name = member?.effectiveName(preferDisplayName: prefer);
    return PrismListRow(
      leading: member != null
          ? MemberAvatar(
              avatarImageData: member.avatarImageData,
              memberName: name!,
              emoji: member.emoji,
              customColorEnabled: member.customColorEnabled,
              customColorHex: member.customColorHex,
              size: 32,
            )
          : Icon(AppIcons.peopleOutline),
      title: Text(name ?? context.l10n.moodWholeSystem),
      trailing: Icon(AppIcons.expandMore),
      onTap: () => onTap(members),
    );
  }
}
