import 'package:prism_plurality/shared/icon_choices.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Row of colour swatches.
class ColorChoiceRow extends StatelessWidget {
  const ColorChoiceRow({
    super.key,
    required this.value,
    required this.onChanged,
    this.colors = colorChoices,
  });
  final int? value;
  final ValueChanged<int> onChanged;
  final List<int> colors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in colors)
          Semantics(
            button: true,
            selected: value == c,
            label: '#${c.toRadixString(16).substring(2)}',
            child: GestureDetector(
              onTap: () => onChanged(c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Color(c),
                  borderRadius: prismRound(context),
                  border: Border.all(
                    color: value == c
                        ? theme.colorScheme.onSurface
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Grid of icons from [iconChoices].
class IconChoiceGrid extends StatelessWidget {
  const IconChoiceGrid({
    super.key,
    required this.value,
    required this.onChanged,
    this.color,
    this.keys,
  });
  final String? value;
  final ValueChanged<String> onChanged;
  final Color? color;
  final List<String>? keys;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = keys ?? iconChoices.keys.toList();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final k in shown)
          InkWell(
            borderRadius: prismCorners(context, 10),
            onTap: () => onChanged(k),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: prismCorners(context, 10),
                color: value == k
                    ? (color ?? theme.colorScheme.primary).withValues(
                        alpha: 0.2,
                      )
                    : theme.colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      ),
                border: Border.all(
                  color: value == k
                      ? (color ?? theme.colorScheme.primary)
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Icon(
                iconChoices[k],
                size: 20,
                color: color ?? theme.colorScheme.onSurface,
              ),
            ),
          ),
      ],
    );
  }
}
