import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/models/system_settings.dart';
import 'package:prism_plurality/features/fronting/providers/fronting_providers.dart';
import 'package:prism_plurality/features/fronting/widgets/quick_front_section.dart';
import 'package:prism_plurality/features/fronting_notification/services/fronting_notification_settings_store.dart';
import 'package:prism_plurality/features/settings/providers/settings_providers.dart';
import 'package:prism_plurality/features/trackers/widgets/member_picker.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';

/// Tap a member to start (or end) their front, honouring the user's quick
/// front behaviour (add alongside, or replace).
Future<void> showQuickFrontSheet(BuildContext context) => PrismSheet.show(
  context: context,
  title: context.l10n.fnActionQuickFront,
  builder: (_) => const _QuickFrontSheet(),
);

class _QuickFrontSheet extends ConsumerWidget {
  const _QuickFrontSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final candidates =
        ref.watch(quickFrontCandidateMembersProvider).value ?? const <Member>[];
    final sessions =
        ref.watch(activeSessionsProvider).value ?? const <FrontingSession>[];
    final fronting = {
      for (final s in sessions)
        if (s.sessionType != SessionType.sleep) ?s.memberId,
    };
    final behavior = ref.watch(quickFrontDefaultBehaviorProvider);
    final notifier = ref.read(frontingNotifierProvider.notifier);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.fnQuickFrontHelp,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        if (candidates.isEmpty) Text(l10n.relNeedMembers),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in candidates)
              PrismChip(
                label: memberLabel(m),
                selected: fronting.contains(m.id),
                onTap: () async {
                  if (fronting.contains(m.id)) {
                    await notifier.endFronting([m.id]);
                  } else if (behavior == FrontStartBehavior.replace) {
                    await notifier.replaceFronting([m.id]);
                  } else {
                    await notifier.startFronting([m.id]);
                  }
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ],
    );
  }
}

/// Edit the custom status line shown in the notification.
Future<void> showFrontingStatusEditor(BuildContext context) => PrismSheet.show(
  context: context,
  title: context.l10n.fnActionStatus,
  builder: (_) => const _StatusEditor(),
);

class _StatusEditor extends ConsumerStatefulWidget {
  const _StatusEditor();

  @override
  ConsumerState<_StatusEditor> createState() => _StatusEditorState();
}

class _StatusEditorState extends ConsumerState<_StatusEditor> {
  late final _c = TextEditingController(
    text:
        ref.read(frontingNotificationSettingsProvider).value?.customStatus ??
        '',
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final n = ref.read(frontingNotificationSettingsProvider.notifier);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrismTextField(
          controller: _c,
          labelText: l10n.fnCustomStatus,
          hintText: l10n.fnCustomStatusHint,
          autofocus: true,
          maxLines: 2,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final p in [
              l10n.fnStatusPresetBusy,
              l10n.fnStatusPresetResting,
              l10n.fnStatusPresetLowSpoons,
              l10n.fnStatusPresetBlurry,
              l10n.fnStatusPresetOk,
            ])
              PrismChip(
                label: p,
                selected: _c.text == p,
                onTap: () => setState(() => _c.text = p),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            PrismButton(
              label: l10n.fnClearStatus,
              onPressed: () async {
                await n.change((s) => s.copyWith(customStatus: ''));
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
            const Spacer(),
            PrismButton(
              label: l10n.save,
              tone: PrismButtonTone.filled,
              onPressed: () async {
                await n.change((s) => s.copyWith(customStatus: _c.text.trim()));
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ],
    );
  }
}
