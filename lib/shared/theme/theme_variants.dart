import 'package:flutter/material.dart';

/// Brightness a single page can ask for, independent of the app's own.
enum PageTone {
  light,
  medium,
  dark;

  /// Stored value in profile settings ('app' means follow the app).
  static PageTone? parse(String? v) => switch (v) {
    'light' => PageTone.light,
    'medium' => PageTone.medium,
    'dark' => PageTone.dark,
    _ => null,
  };
}

/// The app's finished themes for each tone. The app's own pair is ready;
/// the other dark-side tone is built (once) only when a page asks for it.
class PrismThemeVariants {
  PrismThemeVariants({
    required this.light,
    required ThemeData Function() dark,
    required ThemeData Function() medium,
    required this.appTone,
  }) : _dark = dark,
       _medium = medium;

  final ThemeData light;
  final ThemeData Function() _dark;
  final ThemeData Function() _medium;

  /// The app's fixed tone, or null when it follows the system.
  final PageTone? appTone;

  late final ThemeData dark = _dark();
  late final ThemeData medium = _medium();

  ThemeData of(PageTone tone) => switch (tone) {
    PageTone.light => light,
    PageTone.medium => medium,
    PageTone.dark => dark,
  };

  /// The tone in effect when following the app.
  PageTone currentTone(BuildContext context) =>
      appTone ??
      (MediaQuery.platformBrightnessOf(context) == Brightness.dark
          ? PageTone.dark
          : PageTone.light);
}

/// Makes [PrismThemeVariants] available below the app.
class PrismThemeVariantsScope extends InheritedWidget {
  const PrismThemeVariantsScope({
    super.key,
    required this.variants,
    required super.child,
  });

  final PrismThemeVariants variants;

  static PrismThemeVariants? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<PrismThemeVariantsScope>()
      ?.variants;

  @override
  bool updateShouldNotify(PrismThemeVariantsScope old) =>
      !identical(old.variants.light, variants.light) ||
      old.variants.appTone != variants.appTone;
}
