import 'package:prism_plurality/shared/ui_kit.dart';

/// Hue, saturation and brightness sliders for one colour.
class HsvSliders extends StatelessWidget {
  const HsvSliders({super.key, required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final hsv = HSVColor.fromColor(Color(value));
    void emit(HSVColor c) => onChanged(c.toColor().toARGB32());
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        children: [
          GradientSlider(
            label: tr(context, 'Hue', 'Tono'),
            value: hsv.hue / 360,
            colors: [
              for (var h = 0; h <= 360; h += 60)
                HSVColor.fromAHSV(1, h.toDouble(), 0.85, 0.95).toColor(),
            ],
            onChanged: (v) => emit(hsv.withHue(v * 360)),
          ),
          GradientSlider(
            label: tr(context, 'Saturation', 'Saturación'),
            value: hsv.saturation,
            colors: [
              hsv.withSaturation(0).toColor(),
              hsv.withSaturation(1).toColor(),
            ],
            onChanged: (v) => emit(hsv.withSaturation(v)),
          ),
          GradientSlider(
            label: tr(context, 'Brightness', 'Brillo'),
            value: hsv.value,
            colors: [hsv.withValue(0).toColor(), hsv.withValue(1).toColor()],
            onChanged: (v) => emit(hsv.withValue(v)),
          ),
        ],
      ),
    );
  }
}

class GradientSlider extends StatelessWidget {
  const GradientSlider({
    super.key,
    required this.label,
    required this.value,
    required this.colors,
    required this.onChanged,
  });
  final String label;
  final double value;
  final List<Color> colors;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 84,
          child: Text(label, style: theme.textTheme.bodySmall),
        ),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    borderRadius: prismCorners(context, 5),
                    gradient: LinearGradient(colors: colors),
                  ),
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 10,
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                  thumbColor: Colors.white,
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 14,
                  ),
                ),
                child: Slider(
                  value: value.clamp(0.0, 1.0),
                  onChanged: onChanged,
                  semanticFormatterCallback: (v) =>
                      '$label ${(v * 100).round()}%',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
