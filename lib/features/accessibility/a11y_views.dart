import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/features/accessibility/a11y_settings.dart';
import 'package:prism_plurality/features/appearance/views/look_controls.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_dialog.dart';
import 'package:prism_plurality/shared/widgets/prism_section.dart';
import 'package:prism_plurality/shared/widgets/prism_section_card.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_switch_row.dart';

String colorVisionLabel(AppLocalizations l10n, ColorVision v) => switch (v) {
  ColorVision.standard => l10n.a11yCvStandard,
  ColorVision.protanopia => l10n.a11yCvProtan,
  ColorVision.deuteranopia => l10n.a11yCvDeutan,
  ColorVision.tritanopia => l10n.a11yCvTritan,
  ColorVision.monochrome => l10n.a11yCvMono,
};

/// Asks first when the user turned on confirmations for important actions.
Future<bool> confirmIfAsked(BuildContext context, WidgetRef ref, {required String title, String? message}) async {
  if (!ref.read(a11ySettingsProvider).confirmActions) return true;
  final l10n = context.l10n;
  return PrismDialog.confirm(context: context, title: title, message: message, confirmLabel: l10n.a11yConfirmYes, cancelLabel: l10n.cancel);
}

String _pct(double v) => '${(v * 100).round()}%';

/// The expanded accessibility sections (shown on the Accessibility page).
class A11ySections extends ConsumerWidget {
  const A11ySections({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final a = ref.watch(a11ySettingsProvider);
    final n = ref.read(a11yProvider.notifier);
    void set(A11ySettings Function(A11ySettings) f) => n.change(f);
    Widget card(List<Widget> children) => PrismSectionCard(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
    Widget pad(Widget w) => Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: w);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: PrismButton(
                  label: l10n.a11yQuickPanel,
                  icon: Icons.accessibility_new_rounded,
                  tone: PrismButtonTone.filled,
                  onPressed: () => showA11yQuickPanel(context),
                ),
              ),
              const SizedBox(width: 8),
              PrismButton(
                label: l10n.a11yResetAll,
                tone: PrismButtonTone.outlined,
                onPressed: () async {
                  final ok = await PrismDialog.confirm(
                    context: context,
                    title: l10n.a11yResetTitle,
                    message: l10n.a11yResetMessage,
                    confirmLabel: l10n.a11yResetAll,
                    cancelLabel: l10n.cancel,
                  );
                  if (ok) await n.reset();
                },
              ),
            ],
          ),
        ),
        PrismSection(
          title: l10n.a11yVisual,
          child: card([
            pad(LabeledSlider(
              label: l10n.a11yUiScale,
              value: a.uiScale,
              min: 0.85,
              max: 1.4,
              divisions: 11,
              format: _pct,
              onChanged: (v) => set((x) => x.copyWith(uiScale: v)),
            )),
            pad(LabeledSlider(
              label: l10n.a11yLineHeight,
              value: a.lineHeight,
              min: 1,
              max: 1.8,
              divisions: 8,
              format: _pct,
              onChanged: (v) => set((x) => x.copyWith(lineHeight: v)),
            )),
            pad(LabeledSlider(
              label: l10n.a11yWordSpacing,
              value: a.wordSpacing,
              min: 0,
              max: 6,
              divisions: 12,
              format: (v) => '+${v.toStringAsFixed(1)}',
              onChanged: (v) => set((x) => x.copyWith(wordSpacing: v)),
            )),
            PrismSwitchRow(title: l10n.a11yBold, value: a.boldText, onChanged: (v) => set((x) => x.copyWith(boldText: v))),
            PrismSwitchRow(
              title: l10n.a11yHighContrast,
              subtitle: l10n.a11yHighContrastHelp,
              value: a.highContrast,
              onChanged: (v) => set((x) => x.copyWith(highContrast: v)),
            ),
            if (!a.highContrast)
              pad(LabeledSlider(
                label: l10n.a11yContrast,
                value: a.contrast,
                min: 0,
                max: 1,
                divisions: 10,
                format: _pct,
                onChanged: (v) => set((x) => x.copyWith(contrast: v)),
              )),
            PrismSwitchRow(
              title: l10n.a11yReduceTransparency,
              subtitle: l10n.a11yReduceTransparencyHelp,
              value: a.reduceTransparency,
              onChanged: (v) => set((x) => x.copyWith(reduceTransparency: v)),
            ),
            PrismSwitchRow(
              title: l10n.a11yReduceEffects,
              subtitle: l10n.a11yReduceEffectsHelp,
              value: a.reduceEffects,
              onChanged: (v) => set((x) => x.copyWith(reduceEffects: v)),
            ),
            pad(Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.a11yColorVision, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 2),
                  Text(l10n.a11yColorVisionHelp, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final v in ColorVision.values)
                        PrismChip(label: colorVisionLabel(l10n, v), selected: a.colorVision == v, onTap: () => set((x) => x.copyWith(colorVision: v))),
                    ],
                  ),
                ],
              ),
            )),
            PrismSwitchRow(
              title: l10n.a11yFocus,
              subtitle: l10n.a11yFocusHelp,
              value: a.strongFocus,
              onChanged: (v) => set((x) => x.copyWith(strongFocus: v)),
            ),
            PrismSwitchRow(title: l10n.a11yLargeIcons, value: a.largeIcons, onChanged: (v) => set((x) => x.copyWith(largeIcons: v))),
          ]),
        ),
        PrismSection(
          title: l10n.a11yMotion,
          child: card([
            PrismSwitchRow(
              title: l10n.a11yReduceMotion,
              subtitle: l10n.a11yReduceMotionHelp,
              value: a.reduceMotion,
              onChanged: (v) => set((x) => x.copyWith(reduceMotion: v)),
            ),
            if (!a.reduceMotion)
              pad(LabeledSlider(
                label: l10n.a11yAnimSpeed,
                value: a.animationSpeed,
                min: 0.5,
                max: 2,
                divisions: 6,
                format: (v) => v == 1 ? l10n.a11yNormal : '${v}×',
                onChanged: (v) => set((x) => x.copyWith(animationSpeed: v)),
              )),
          ]),
        ),
        PrismSection(
          title: l10n.a11yInteraction,
          child: card([
            pad(LabeledSlider(
              label: l10n.a11yTouch,
              value: a.touchScale,
              min: 1,
              max: 1.5,
              divisions: 5,
              format: _pct,
              onChanged: (v) => set((x) => x.copyWith(touchScale: v)),
            )),
            PrismSwitchRow(title: l10n.a11yHaptics, subtitle: l10n.a11yHapticsHelp, value: a.haptics, onChanged: (v) => set((x) => x.copyWith(haptics: v))),
            PrismSwitchRow(
              title: l10n.a11yConfirm,
              subtitle: l10n.a11yConfirmHelp,
              value: a.confirmActions,
              onChanged: (v) => set((x) => x.copyWith(confirmActions: v)),
            ),
            pad(Padding(
              padding: const EdgeInsets.only(top: 6),
              child: PrismButton(
                label: l10n.a11ySimplifyNav,
                icon: Icons.view_agenda_outlined,
                onPressed: () => context.push(AppRoutePaths.settingsNavigation),
              ),
            )),
          ]),
        ),
        PrismSection(
          title: l10n.a11yReading,
          child: card([
            PrismSwitchRow(
              title: l10n.a11yAnnounce,
              subtitle: l10n.a11yAnnounceHelp,
              value: a.announce,
              onChanged: (v) => set((x) => x.copyWith(announce: v)),
            ),
            pad(Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(l10n.a11yKeyboardHelp, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            )),
          ]),
        ),
      ],
    );
  }
}

/// Frequently used adjustments in one sheet, reachable from Settings and
/// with Alt+Shift+A.
Future<void> showA11yQuickPanel(BuildContext context) => PrismSheet.show<void>(
  context: context,
  title: context.l10n.a11yQuickPanel,
  builder: (_) => const A11yQuickPanel(),
);

class A11yQuickPanel extends ConsumerWidget {
  const A11yQuickPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final a = ref.watch(a11ySettingsProvider);
    final n = ref.read(a11yProvider.notifier);
    void set(A11ySettings Function(A11ySettings) f) => n.change(f);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabeledSlider(
            label: l10n.a11yUiScale,
            value: a.uiScale,
            min: 0.85,
            max: 1.4,
            divisions: 11,
            format: _pct,
            onChanged: (v) => set((x) => x.copyWith(uiScale: v)),
          ),
          PrismSwitchRow(title: l10n.a11yHighContrast, value: a.highContrast, onChanged: (v) => set((x) => x.copyWith(highContrast: v))),
          PrismSwitchRow(title: l10n.a11yReduceMotion, value: a.reduceMotion, onChanged: (v) => set((x) => x.copyWith(reduceMotion: v))),
          PrismSwitchRow(title: l10n.a11yReduceTransparency, value: a.reduceTransparency, onChanged: (v) => set((x) => x.copyWith(reduceTransparency: v))),
          PrismSwitchRow(title: l10n.a11yBold, value: a.boldText, onChanged: (v) => set((x) => x.copyWith(boldText: v))),
          PrismSwitchRow(title: l10n.a11yLargeIcons, value: a.largeIcons, onChanged: (v) => set((x) => x.copyWith(largeIcons: v))),
          PrismSwitchRow(title: l10n.a11yFocus, value: a.strongFocus, onChanged: (v) => set((x) => x.copyWith(strongFocus: v))),
          const SizedBox(height: 8),
          PrismButton(
            label: l10n.a11yAllSettings,
            expanded: true,
            onPressed: () {
              Navigator.of(context).pop();
              context.push(AppRoutePaths.settingsAccessibility);
            },
          ),
        ],
      ),
    );
  }
}
