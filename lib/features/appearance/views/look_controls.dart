import 'package:prism_plurality/shared/theme/prism_shapes.dart';
import 'package:flutter/material.dart';

import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_color_picker_dialog.dart';

const lookSwatches = [
  0xFF000000, 0xFF14102B, 0xFF263238, 0xFF5C6BC0, 0xFF7E57C2, 0xFF7C4DFF, 0xFF29B6F6, 0xFF18FFFF,
  0xFF26A69A, 0xFF66BB6A, 0xFFFFCA28, 0xFFFF7043, 0xFFEC407A, 0xFFFFE9D6, 0xFFFAF6EE, 0xFFFFFFFF,
];

Future<int?> pickCustomColor(BuildContext context, int? initial) async {
  final hex = await showPrismColorPickerDialog(context: context, initialColor: Color(initial ?? 0xFF7E57C2));
  if (hex == null) return null;
  final raw = hex.replaceFirst('#', '');
  final v = int.tryParse(raw, radix: 16);
  if (v == null) return null;
  return raw.length <= 6 ? 0xFF000000 | v : v;
}

/// Label, swatches, "Custom…" and (optionally) "Default".
class ColorChoiceRow extends StatelessWidget {
  const ColorChoiceRow({super.key, required this.label, required this.value, required this.onChanged, this.allowDefault = true});

  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;
  final bool allowDefault;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
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
              if (allowDefault) PrismChip(label: l10n.apDefault, selected: value == null, onTap: () => onChanged(null)),
              for (final c in lookSwatches)
                Semantics(
                  button: true,
                  selected: value == c,
                  label: '$label #${c.toRadixString(16).substring(2).toUpperCase()}',
                  excludeSemantics: true,
                  child: InkResponse(
                    onTap: () => onChanged(c),
                    radius: 20,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Color(c),
                        borderRadius: prismRound(context),
                        border: Border.all(width: value == c ? 3 : 1, color: theme.colorScheme.outline),
                      ),
                    ),
                  ),
                ),
              if (value != null && !lookSwatches.contains(value))
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: Color(value!), borderRadius: prismRound(context), border: Border.all(width: 3, color: theme.colorScheme.outline)),
                ),
              PrismButton(
                label: l10n.fnColorCustom,
                density: PrismControlDensity.compact,
                onPressed: () async {
                  final c = await pickCustomColor(context, value);
                  if (c != null) onChanged(c);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A labelled slider that reads its value aloud in screen readers.
class LabeledSlider extends StatelessWidget {
  const LabeledSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.format,
    this.onReset,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String Function(double)? format;
  final ValueChanged<double> onChanged;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = format?.call(value) ?? value.toStringAsFixed(2);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.labelLarge)),
              ExcludeSemantics(child: Text(text, style: theme.textTheme.labelMedium)),
              if (onReset != null)
                PrismButton(label: context.l10n.apReset, density: PrismControlDensity.compact, tone: PrismButtonTone.outlined, onPressed: onReset!),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: text,
            semanticFormatterCallback: (_) => '$label $text',
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
