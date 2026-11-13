// lib/shared/utils/haptics.dart
import 'package:flutter/services.dart';

/// Centralized haptic feedback for consistent tactile feel.
/// Wraps HapticFeedback with semantic names matching interaction types.
abstract final class Haptics {
  /// Turned off from Accessibility → Interaction feedback.
  static bool enabled = true;

  /// Light tap — button press, selection change, toggle
  static void light() {
    if (enabled) HapticFeedback.lightImpact();
  }

  /// Medium tap — completing an action, drag-and-drop
  static void medium() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  /// Heavy tap — destructive action confirmation
  static void heavy() {
    if (enabled) HapticFeedback.heavyImpact();
  }

  /// Success — fronter switched, vote cast, message sent
  static void success() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  /// Selection tick — scrolling through picker, reorder
  static void selection() {
    if (enabled) HapticFeedback.selectionClick();
  }
}
