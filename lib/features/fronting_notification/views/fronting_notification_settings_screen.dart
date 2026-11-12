import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/core/services/local_notification_service.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/fronting_notification/models/fronting_notification_settings.dart';
import 'package:prism_plurality/features/fronting_notification/services/fronting_notification_controller.dart';
import 'package:prism_plurality/features/fronting_notification/services/fronting_notification_settings_store.dart';
import 'package:prism_plurality/features/fronting_notification/services/fronting_notification_snapshot.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/trackers/widgets/member_picker.dart';
import 'package:prism_plurality/features/trackers/widgets/tracker_widgets.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/info_banner.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_checkbox_row.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_color_picker_dialog.dart';
import 'package:prism_plurality/shared/widgets/prism_loading_state.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_segmented_control.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/shared/widgets/prism_switch_row.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';

String fnInfoLabel(AppLocalizations l10n, String k) => switch (k) {
  FnInfo.fronters => l10n.fnInfoFronters,
  FnInfo.cofronters => l10n.fnInfoCofronters,
  FnInfo.pronouns => l10n.fnInfoPronouns,
  FnInfo.duration => l10n.fnInfoDuration,
  FnInfo.status => l10n.fnInfoStatus,
  FnInfo.customStatus => l10n.fnInfoCustomStatus,
  FnInfo.mood => l10n.fnInfoMood,
  FnInfo.emotions => l10n.fnInfoEmotions,
  FnInfo.location => l10n.fnInfoLocation,
  FnInfo.activity => l10n.fnInfoActivity,
  _ => l10n.fnInfoCustom,
};

String fnActionLabel(AppLocalizations l10n, String a) => switch (a) {
  FnAction.quickFront => l10n.fnActionQuickFront,
  FnAction.switchFronter => l10n.fnActionSwitch,
  FnAction.open => l10n.fnActionOpen,
  FnAction.mood => l10n.fnActionMood,
  FnAction.status => l10n.fnActionStatus,
  _ => l10n.fnActionDetails,
};

IconData fnSmallIconData(String k) => switch (k) {
  'group' => AppIcons.peopleOutline,
  'heart' => AppIcons.heartOutline,
  'star' => AppIcons.navAchievements,
  'moon' => AppIcons.navSleep,
  'sparkle' => AppIcons.navInsights,
  'leaf' => AppIcons.navCycle,
  _ => AppIcons.navMembers,
};

const _swatches = <int>[
  0xFF7E57C2,
  0xFF5C6BC0,
  0xFF42A5F5,
  0xFF26A69A,
  0xFF66BB6A,
  0xFFFFCA28,
  0xFFFFA726,
  0xFFEF5350,
  0xFFEC407A,
  0xFF212121,
  0xFFFAFAFA,
];

/// Everything about the live fronting notification.
class FrontingNotificationSettingsScreen extends ConsumerWidget {
  const FrontingNotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final async = ref.watch(frontingNotificationSettingsProvider);
    final platform = ref.watch(frontingStatusPlatformProvider);
    final notifier = ref.read(frontingNotificationSettingsProvider.notifier);
    return PrismPageScaffold(
      topBar: PrismTopBar(title: l10n.fnTopBar, showBackButton: true),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: async.when(
        loading: () => const PrismLoadingState(),
        error: (e, _) => Center(child: Text(l10n.errorWithDetail(e))),
        data: (s) {
          void set(
            FrontingNotificationSettings Function(FrontingNotificationSettings)
            f,
          ) => notifier.change(f);
          final children = <Widget>[
            if (!platform.isSupported)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InfoBanner(
                  icon: AppIcons.errorOutline,
                  iconColor: theme.colorScheme.tertiary,
                  title: l10n.fnUnsupportedTitle,
                  message: l10n.fnUnsupportedMessage,
                  actionsBelow: true,
                ),
              ),
            PrismSurface(
              padding: EdgeInsets.zero,
              child: PrismSwitchRow(
                title: l10n.fnEnable,
                subtitle: l10n.fnEnableHelp,
                icon: AppIcons.notificationsOutlined,
                value: s.enabled,
                onChanged: (v) async {
                  if (v)
                    await ref
                        .read(localNotificationServiceProvider)
                        .requestPermission();
                  set((x) => x.copyWith(enabled: v));
                },
              ),
            ),
            if (s.enabled && platform.isSupported) _PermissionRow(),
            const SizedBox(height: 12),
            TrackerLabel(l10n.fnPreview),
            _Preview(settings: s),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PrismButton(
                  label: l10n.fnRefreshNow,
                  icon: AppIcons.refresh,
                  density: PrismControlDensity.compact,
                  enabled: s.enabled,
                  onPressed: () => ref
                      .read(frontingNotificationControllerProvider)
                      .schedule(force: true),
                ),
              ],
            ),
            TrackerLabel(l10n.fnContent),
            _TextSetting(
              label: l10n.fnTitleTemplate,
              helper: l10n.fnTitleTemplateHelp(
                '{fronters}, {first}, {cofronters}, {count}, {mood}, {location}',
              ),
              value: s.titleTemplate,
              onSaved: (v) => set((x) => x.copyWith(titleTemplate: v)),
            ),
            const SizedBox(height: 12),
            _TextSetting(
              label: l10n.fnGreeting,
              helper: l10n.fnGreetingHelp('Hi {first}!'),
              value: s.greeting,
              onSaved: (v) => set((x) => x.copyWith(greeting: v)),
            ),
            const SizedBox(height: 12),
            _TextSetting(
              label: l10n.fnCustomStatus,
              helper: l10n.fnCustomStatusHint,
              value: s.customStatus,
              onSaved: (v) => set((x) => x.copyWith(customStatus: v)),
            ),
            const SizedBox(height: 12),
            _TextSetting(
              label: l10n.fnCustomLines,
              helper: l10n.fnCustomLinesHelp,
              value: s.customLines.join('\n'),
              maxLines: 4,
              onSaved: (v) => set(
                (x) => x.copyWith(
                  customLines: [
                    for (final l in v.split('\n'))
                      if (l.trim().isNotEmpty) l.trim(),
                  ],
                ),
              ),
            ),
            TrackerLabel(l10n.fnInformation),
            Text(l10n.fnInformationHelp, style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            PrismSurface(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final k in [
                    ...s.info,
                    ...FnInfo.all.where((x) => !s.info.contains(x)),
                  ])
                    Row(
                      children: [
                        Expanded(
                          child: PrismCheckboxRow(
                            checkboxAffinity: PrismCheckboxAffinity.leading,
                            title: Text(fnInfoLabel(l10n, k)),
                            value: s.info.contains(k),
                            onChanged: (v) => set(
                              (x) => x.copyWith(
                                info: v
                                    ? [...x.info, k]
                                    : [
                                        for (final i in x.info)
                                          if (i != k) i,
                                      ],
                              ),
                            ),
                          ),
                        ),
                        if (s.info.contains(k)) ...[
                          IconButton(
                            tooltip: l10n.trackerMoveUp,
                            icon: Icon(AppIcons.arrowUpward, size: 18),
                            onPressed: s.info.indexOf(k) == 0
                                ? null
                                : () => set((x) {
                                    final l = [...x.info];
                                    final i = l.indexOf(k);
                                    l.insert(i - 1, l.removeAt(i));
                                    return x.copyWith(info: l);
                                  }),
                          ),
                          IconButton(
                            tooltip: l10n.pollMoveDown,
                            icon: Icon(AppIcons.arrowDownward, size: 18),
                            onPressed: s.info.indexOf(k) == s.info.length - 1
                                ? null
                                : () => set((x) {
                                    final l = [...x.info];
                                    final i = l.indexOf(k);
                                    l.insert(i + 1, l.removeAt(i));
                                    return x.copyWith(info: l);
                                  }),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
            TrackerLabel(l10n.fnIcons),
            PrismSegmentedControl<FnIconSource>(
              segments: [
                PrismSegment(
                  value: FnIconSource.avatar,
                  label: l10n.fnIconAvatar,
                ),
                PrismSegment(
                  value: FnIconSource.emoji,
                  label: l10n.fnIconEmoji,
                ),
                PrismSegment(
                  value: FnIconSource.builtIn,
                  label: l10n.fnIconBuiltIn,
                ),
                PrismSegment(value: FnIconSource.none, label: l10n.fnIconNone),
              ],
              selected: s.iconSource,
              onChanged: (v) => set((x) => x.copyWith(iconSource: v)),
            ),
            const SizedBox(height: 6),
            Text(switch (s.iconSource) {
              FnIconSource.avatar => l10n.fnIconAvatarHelp,
              FnIconSource.emoji => l10n.fnIconEmojiHelp,
              FnIconSource.builtIn => l10n.fnIconBuiltInHelp,
              FnIconSource.none => l10n.fnIconNoneHelp,
            }, style: theme.textTheme.bodySmall),
            if (s.iconSource == FnIconSource.emoji) ...[
              const SizedBox(height: 8),
              _TextSetting(
                label: l10n.fnEmoji,
                value: s.iconEmoji,
                onSaved: (v) =>
                    set((x) => x.copyWith(iconEmoji: v.isEmpty ? '🌈' : v)),
              ),
            ],
            const SizedBox(height: 8),
            Text(l10n.fnStatusBarIcon, style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final i in fnSmallIcons)
                  PrismChip(
                    label: '',
                    avatar: Icon(fnSmallIconData(i), size: 16),
                    selected: s.smallIcon == i,
                    onTap: () => set((x) => x.copyWith(smallIcon: i)),
                  ),
              ],
            ),
            TrackerLabel(l10n.fnAppearance),
            Text(l10n.fnLayout, style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final lay in FnLayout.values)
                  PrismChip(
                    label: switch (lay) {
                      FnLayout.compact => l10n.fnLayoutCompact,
                      FnLayout.expanded => l10n.fnLayoutExpanded,
                      FnLayout.minimal => l10n.fnLayoutMinimal,
                      FnLayout.detailed => l10n.fnLayoutDetailed,
                    },
                    selected: s.layout == lay,
                    onTap: () => set((x) => x.copyWith(layout: lay)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            PrismSegmentedControl<FnStyle>(
              segments: [
                PrismSegment(value: FnStyle.system, label: l10n.fnStyleSystem),
                PrismSegment(value: FnStyle.custom, label: l10n.fnStyleCustom),
              ],
              selected: s.style,
              onChanged: (v) => set((x) => x.copyWith(style: v)),
            ),
            const SizedBox(height: 6),
            Text(
              s.style == FnStyle.system
                  ? l10n.fnStyleSystemHelp
                  : l10n.fnStyleCustomHelp,
              style: theme.textTheme.bodySmall,
            ),
            _ColorRow(
              label: l10n.fnAccentColor,
              value: s.accentColor,
              onChanged: (c) => set(
                (x) => c == null
                    ? x.copyWith(clearAccent: true)
                    : x.copyWith(accentColor: c),
              ),
            ),
            if (s.style == FnStyle.custom) ...[
              _ColorRow(
                label: l10n.fnBackgroundColor,
                value: s.backgroundColor,
                onChanged: (c) => set(
                  (x) => c == null
                      ? x.copyWith(clearBackground: true)
                      : x.copyWith(backgroundColor: c),
                ),
              ),
              _ColorRow(
                label: l10n.fnTextColor,
                value: s.textColor,
                onChanged: (c) => set(
                  (x) => c == null
                      ? x.copyWith(clearText: true)
                      : x.copyWith(textColor: c),
                ),
              ),
            ],
            PrismSwitchRow(
              title: l10n.fnColorized,
              subtitle: l10n.fnColorizedHelp,
              value: s.colorized,
              onChanged: (v) => set((x) => x.copyWith(colorized: v)),
            ),
            TrackerLabel(l10n.fnActions),
            Text(l10n.fnActionsHelp, style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final a in FnAction.all)
                  PrismChip(
                    label: s.actions.contains(a)
                        ? '${s.actions.indexOf(a) + 1}. ${fnActionLabel(l10n, a)}'
                        : fnActionLabel(l10n, a),
                    selected: s.actions.contains(a),
                    onTap: () => set((x) {
                      if (x.actions.contains(a))
                        return x.copyWith(
                          actions: [
                            for (final y in x.actions)
                              if (y != a) y,
                          ],
                        );
                      if (x.actions.length >= 3) return x;
                      return x.copyWith(actions: [...x.actions, a]);
                    }),
                  ),
              ],
            ),
            TrackerLabel(l10n.fnPerMember),
            Text(l10n.fnPerMemberHelp, style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            _MemberStyles(settings: s),
            TrackerLabel(l10n.fnAdvanced),
            PrismSurface(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  PrismSwitchRow(
                    title: l10n.fnForeground,
                    subtitle: l10n.fnForegroundHelp,
                    value: s.foregroundService,
                    onChanged: (v) =>
                        set((x) => x.copyWith(foregroundService: v)),
                  ),
                  PrismSwitchRow(
                    title: l10n.fnRestore,
                    subtitle: l10n.fnRestoreHelp,
                    value: s.restoreOnBoot,
                    onChanged: (v) => set((x) => x.copyWith(restoreOnBoot: v)),
                  ),
                  PrismSwitchRow(
                    title: l10n.fnAllowDismiss,
                    subtitle: l10n.fnAllowDismissHelp,
                    value: s.allowDismiss,
                    onChanged: (v) => set((x) => x.copyWith(allowDismiss: v)),
                  ),
                  PrismSwitchRow(
                    title: l10n.fnDnd,
                    subtitle: l10n.fnDndHelp,
                    value: s.bypassDnd,
                    onChanged: (v) => set((x) => x.copyWith(bypassDnd: v)),
                  ),
                ],
              ),
            ),
            if (s.bypassDnd && platform.isSupported)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: PrismButton(
                    label: l10n.fnOpenDndSettings,
                    density: PrismControlDensity.compact,
                    onPressed: () => platform.openChannelSettings(dnd: true),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Text(l10n.fnLockScreen, style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            PrismSegmentedControl<FnLockScreen>(
              segments: [
                PrismSegment(value: FnLockScreen.show, label: l10n.fnLockShow),
                PrismSegment(
                  value: FnLockScreen.hideDetails,
                  label: l10n.fnLockHideDetails,
                ),
                PrismSegment(value: FnLockScreen.hide, label: l10n.fnLockHide),
              ],
              selected: s.lockScreen,
              onChanged: (v) => set((x) => x.copyWith(lockScreen: v)),
            ),
            const SizedBox(height: 10),
            Text(l10n.fnWhenEmpty, style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            PrismSegmentedControl<FnWhenEmpty>(
              segments: [
                PrismSegment(
                  value: FnWhenEmpty.message,
                  label: l10n.fnWhenEmptyMessage,
                ),
                PrismSegment(
                  value: FnWhenEmpty.hide,
                  label: l10n.fnWhenEmptyHide,
                ),
              ],
              selected: s.whenEmpty,
              onChanged: (v) => set((x) => x.copyWith(whenEmpty: v)),
            ),
            if (s.whenEmpty == FnWhenEmpty.message) ...[
              const SizedBox(height: 8),
              _TextSetting(
                label: l10n.fnEmptyMessage,
                helper: l10n.fnNobodyFronting,
                value: s.emptyMessage,
                onSaved: (v) => set((x) => x.copyWith(emptyMessage: v)),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              l10n.fnMoodFreshness(s.moodMaxAgeHours),
              style: theme.textTheme.labelLarge,
            ),
            Wrap(
              spacing: 6,
              children: [
                for (final h in [3, 6, 12, 24, 48])
                  PrismChip(
                    label: '${h}h',
                    selected: s.moodMaxAgeHours == h,
                    onTap: () => set((x) => x.copyWith(moodMaxAgeHours: h)),
                  ),
              ],
            ),
            if (platform.isSupported) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PrismButton(
                    label: l10n.fnChannelSettings,
                    icon: AppIcons.navSettings,
                    density: PrismControlDensity.compact,
                    onPressed: () => platform.openChannelSettings(),
                  ),
                  PrismButton(
                    label: l10n.fnBatterySettings,
                    density: PrismControlDensity.compact,
                    onPressed: platform.openBatterySettings,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(l10n.fnBatteryHelp, style: theme.textTheme.bodySmall),
            ],
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: PrismTokens.contentMaxWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PermissionRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final platform = ref.watch(frontingStatusPlatformProvider);
    return FutureBuilder<bool>(
      future: platform.notificationsEnabled(),
      builder: (context, snap) {
        if (snap.data != false) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: InfoBanner(
            icon: AppIcons.warningAmber,
            iconColor: Theme.of(context).colorScheme.error,
            title: l10n.fnPermissionTitle,
            message: l10n.fnPermissionMessage,
            buttonText: l10n.fnPermissionButton,
            onButtonPressed: () async {
              final ok = await ref
                  .read(localNotificationServiceProvider)
                  .requestPermission();
              if (!ok) await platform.openChannelSettings();
            },
            actionsBelow: true,
          ),
        );
      },
    );
  }
}

/// A text field that saves when focus leaves or Enter is pressed.
class _TextSetting extends StatefulWidget {
  const _TextSetting({
    required this.label,
    required this.value,
    required this.onSaved,
    this.helper,
    this.maxLines = 1,
  });

  final String label;
  final String? helper;
  final String value;
  final int maxLines;
  final ValueChanged<String> onSaved;

  @override
  State<_TextSetting> createState() => _TextSettingState();
}

class _TextSettingState extends State<_TextSetting> {
  late final _c = TextEditingController(text: widget.value);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _c.text != widget.value)
        widget.onSaved(_c.text.trim());
    });
  }

  @override
  void didUpdateWidget(covariant _TextSetting old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && widget.value != _c.text) _c.text = widget.value;
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PrismTextField(
    controller: _c,
    focusNode: _focus,
    labelText: widget.label,
    helperText: widget.helper,
    maxLines: widget.maxLines,
    minLines: 1,
    onSubmitted: (v) => widget.onSaved(v.trim()),
  );
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PrismChip(
                label: l10n.fnColorAuto,
                selected: value == null,
                onTap: () => onChanged(null),
              ),
              for (final c in _swatches)
                InkResponse(
                  onTap: () => onChanged(c),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                        width: value == c ? 3 : 1,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                ),
              PrismButton(
                label: l10n.fnColorCustom,
                density: PrismControlDensity.compact,
                onPressed: () async {
                  final hex = await showPrismColorPickerDialog(
                    context: context,
                    initialColor: Color(value ?? 0xFF7E57C2),
                  );
                  if (hex == null) return;
                  final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
                  if (v != null)
                    onChanged(
                      hex.replaceFirst('#', '').length <= 6
                          ? 0xFF000000 | v
                          : v,
                    );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// In-app approximation of how the notification will look.
class _Preview extends ConsumerWidget {
  const _Preview({required this.settings});

  final FrontingNotificationSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final inputs = ref.watch(frontingNotificationInputsProvider);
    if (inputs == null)
      return const SizedBox(height: 80, child: PrismLoadingState());
    final snap = buildFrontingSnapshot(
      settings,
      inputs,
      frontingNotificationStrings(l10n, context.dateLocale),
      DateTime.now(),
    );
    if (snap.hidden) {
      return PrismSurface(
        child: Text(l10n.fnPreviewHidden, style: theme.textTheme.bodySmall),
      );
    }
    final custom = settings.style == FnStyle.custom;
    final bg = custom && snap.backgroundColor != null
        ? Color(snap.backgroundColor!)
        : theme.colorScheme.surfaceContainerHigh;
    final fg = custom && snap.textColor != null
        ? Color(snap.textColor!)
        : theme.colorScheme.onSurface;
    final accent = snap.accentColor == null
        ? theme.colorScheme.primary
        : Color(snap.accentColor!);
    final primary = snap.primaryMemberId == null
        ? null
        : inputs.members[snap.primaryMemberId];
    Widget? icon;
    if (settings.layout != FnLayout.minimal) {
      if (settings.iconSource == FnIconSource.avatar &&
          primary?.avatarImageData != null &&
          settings.memberStyles[primary!.id]?.emoji == null) {
        icon = ClipOval(
          child: Image.memory(
            primary.avatarImageData!,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
          ),
        );
      } else if ((settings.iconSource == FnIconSource.avatar ||
              settings.iconSource == FnIconSource.emoji) &&
          snap.iconEmoji != null &&
          snap.iconEmoji != '❔') {
        icon = CircleAvatarLike(
          color: accent.withValues(alpha: 0.2),
          child: Text(snap.iconEmoji!, style: const TextStyle(fontSize: 22)),
        );
      }
    }
    final expanded =
        settings.layout == FnLayout.expanded ||
        settings.layout == FnLayout.detailed;
    final elapsed = snap.chronometerBase == null
        ? null
        : DateTime.now().difference(snap.chronometerBase!);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: settings.colorized ? accent.withValues(alpha: 0.85) : bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                fnSmallIconData(settings.smallIcon),
                size: 14,
                color: accent,
              ),
              const SizedBox(width: 6),
              Text(
                'Prism',
                style: theme.textTheme.labelSmall?.copyWith(color: accent),
              ),
              if (snap.subText != null)
                Text(
                  ' · ${snap.subText}',
                  style: theme.textTheme.labelSmall?.copyWith(color: fg),
                ),
              if (elapsed != null)
                Text(
                  ' · ${elapsed.inHours}:${(elapsed.inMinutes % 60).toString().padLeft(2, '0')}',
                  style: theme.textTheme.labelSmall?.copyWith(color: fg),
                ),
              const Spacer(),
              Icon(
                AppIcons.privateLock,
                size: 12,
                color: fg.withValues(alpha: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      snap.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (settings.layout != FnLayout.minimal &&
                        snap.text.isNotEmpty)
                      Text(
                        snap.text,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: fg.withValues(alpha: 0.8),
                        ),
                      ),
                    if (expanded)
                      for (final l in snap.lines)
                        if (l != snap.text)
                          Text(
                            l,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: fg.withValues(alpha: 0.8),
                            ),
                          ),
                  ],
                ),
              ),
              ?icon,
            ],
          ),
          if (snap.actions.isNotEmpty &&
              settings.layout != FnLayout.minimal) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              children: [
                for (final a in snap.actions)
                  Text(
                    a.$2.toUpperCase(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Text(
            switch (settings.lockScreen) {
              FnLockScreen.show => l10n.fnLockPreviewShow,
              FnLockScreen.hideDetails => l10n.fnLockPreviewHidden(
                snap.publicTitle,
              ),
              FnLockScreen.hide => l10n.fnLockPreviewNone,
            },
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// Round tinted badge without using the stock CircleAvatar.
class CircleAvatarLike extends StatelessWidget {
  const CircleAvatarLike({super.key, required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: child,
  );
}

class _MemberStyles extends ConsumerWidget {
  const _MemberStyles({required this.settings});

  final FrontingNotificationSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final members = ref.watch(activeMembersProvider).value ?? const <Member>[];
    if (members.isEmpty)
      return Text(
        l10n.relNeedMembers,
        style: Theme.of(context).textTheme.bodySmall,
      );
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final m in members)
          PrismChip(
            label: settings.memberStyles[m.id]?.isEmpty ?? true
                ? memberLabel(m)
                : '${memberLabel(m)} ✓',
            selected: !(settings.memberStyles[m.id]?.isEmpty ?? true),
            onTap: () => PrismSheet.showFullScreen(
              context: context,
              builder: (context, scroll) =>
                  _MemberStyleEditor(member: m, scroll: scroll),
            ),
          ),
      ],
    );
  }
}

class _MemberStyleEditor extends ConsumerStatefulWidget {
  const _MemberStyleEditor({required this.member, this.scroll});

  final Member member;
  final ScrollController? scroll;

  @override
  ConsumerState<_MemberStyleEditor> createState() => _MemberStyleEditorState();
}

class _MemberStyleEditorState extends ConsumerState<_MemberStyleEditor> {
  late final FnMemberStyle _orig =
      ref
          .read(frontingNotificationSettingsProvider)
          .value
          ?.memberStyles[widget.member.id] ??
      const FnMemberStyle();
  late final _title = TextEditingController(text: _orig.title ?? '');
  late final _greeting = TextEditingController(text: _orig.greeting ?? '');
  late final _emoji = TextEditingController(text: _orig.emoji ?? '');
  late int? _accent = _orig.accentColor;
  late int? _bg = _orig.backgroundColor;
  late int? _fg = _orig.textColor;

  @override
  void dispose() {
    _title.dispose();
    _greeting.dispose();
    _emoji.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String? t(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    return TrackerEditorScaffold(
      title: l10n.fnMemberStyleTitle(widget.member.name),
      canSave: true,
      onSave: () async {
        final style = FnMemberStyle(
          title: t(_title),
          greeting: t(_greeting),
          emoji: t(_emoji),
          accentColor: _accent,
          backgroundColor: _bg,
          textColor: _fg,
        );
        await ref.read(frontingNotificationSettingsProvider.notifier).change((
          s,
        ) {
          final m = {...s.memberStyles};
          if (style.isEmpty) {
            m.remove(widget.member.id);
          } else {
            m[widget.member.id] = style;
          }
          return s.copyWith(memberStyles: m);
        });
        if (context.mounted) Navigator.of(context).pop();
      },
      scrollController: widget.scroll,
      children: [
        Text(
          l10n.fnMemberStyleHelp,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        PrismTextField(
          controller: _title,
          labelText: l10n.fnTitleTemplate,
          helperText: l10n.fnTitleTemplateHelp(
            '{fronters}, {first}, {cofronters}, {count}, {mood}, {location}',
          ),
        ),
        const SizedBox(height: 12),
        PrismTextField(
          controller: _greeting,
          labelText: l10n.fnGreeting,
          hintText: l10n.fnGreetingMemberHint('Welcome back, {first}'),
        ),
        const SizedBox(height: 12),
        PrismTextField(controller: _emoji, labelText: l10n.fnEmoji),
        _ColorRow(
          label: l10n.fnAccentColor,
          value: _accent,
          onChanged: (c) => setState(() => _accent = c),
        ),
        _ColorRow(
          label: l10n.fnBackgroundColor,
          value: _bg,
          onChanged: (c) => setState(() => _bg = c),
        ),
        _ColorRow(
          label: l10n.fnTextColor,
          value: _fg,
          onChanged: (c) => setState(() => _fg = c),
        ),
      ],
    );
  }
}
