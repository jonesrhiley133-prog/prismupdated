import 'package:flutter/material.dart';

import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';

/// Presentation for the 1–5 mood scale.
abstract final class MoodLevel {
  static const _emoji = ['😞', '😕', '😐', '🙂', '😄'];
  static const _colors = [
    Color(0xFFE5604D),
    Color(0xFFF0954A),
    Color(0xFFF2C14E),
    Color(0xFF8CC269),
    Color(0xFF3FAF7A),
  ];

  static int _index(num level) => (level.round() - 1).clamp(0, 4);

  static String emoji(num level) => _emoji[_index(level)];

  /// Colour for a (possibly fractional) average, interpolated between the
  /// two nearest levels so calendar heat maps read smoothly.
  static Color color(num level) {
    final v = level.toDouble().clamp(1.0, 5.0) - 1;
    final lo = v.floor();
    final hi = v.ceil();
    if (lo == hi) return _colors[lo];
    return Color.lerp(_colors[lo], _colors[hi], v - lo)!;
  }

  static String label(BuildContext context, num level) {
    final l10n = context.l10n;
    return switch (_index(level)) {
      0 => l10n.moodLevelAwful,
      1 => l10n.moodLevelBad,
      2 => l10n.moodLevelOkay,
      3 => l10n.moodLevelGood,
      _ => l10n.moodLevelGreat,
    };
  }
}

/// Label for an optional 1–5 wellbeing scale (energy, stress, sleep).
String scaleLabel(BuildContext context, int value) {
  final l10n = context.l10n;
  return switch (value) {
    1 => l10n.moodScaleVeryLow,
    2 => l10n.moodScaleLow,
    3 => l10n.moodScaleMedium,
    4 => l10n.moodScaleHigh,
    _ => l10n.moodScaleVeryHigh,
  };
}

/// A round emoji badge tinted with the mood colour.
class MoodFace extends StatelessWidget {
  const MoodFace({super.key, required this.level, this.size = 36});

  final num level;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = MoodLevel.color(level);
    return Semantics(
      label: MoodLevel.label(context, level),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.22),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.7), width: 1.5),
        ),
        child: Text(
          MoodLevel.emoji(level),
          style: TextStyle(fontSize: size * 0.55, height: 1),
        ),
      ),
    );
  }
}
