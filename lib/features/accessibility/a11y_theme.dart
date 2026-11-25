import 'dart:ui' as ui;

import 'package:prism_plurality/shared/theme/prism_shapes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/features/accessibility/a11y_settings.dart';
import 'package:prism_plurality/features/music/services/music_player.dart';

/// Accessibility values Prism's own widgets read from the theme.
@immutable
class A11yTheme extends ThemeExtension<A11yTheme> {
  const A11yTheme({this.touchScale = 1, this.strongFocus = false});

  final double touchScale;
  final bool strongFocus;

  static A11yTheme of(BuildContext context) => Theme.of(context).extension<A11yTheme>() ?? const A11yTheme();

  @override
  A11yTheme copyWith() => this;

  @override
  A11yTheme lerp(ThemeExtension<A11yTheme>? other, double t) => other is A11yTheme && t >= 0.5 ? other : this;
}

/// Palettes that stay distinguishable with each type of colour vision
/// (based on the Okabe–Ito and Tol sets).
({Color primary, Color secondary, Color tertiary, Color error})? colorVisionPalette(ColorVision v, {required bool dark}) => switch (v) {
  ColorVision.standard => null,
  ColorVision.protanopia || ColorVision.deuteranopia => (
    primary: dark ? const Color(0xFF56B4E9) : const Color(0xFF0072B2),
    secondary: dark ? const Color(0xFFF0C24B) : const Color(0xFFB37A00),
    tertiary: dark ? const Color(0xFFCC9FD0) : const Color(0xFF8E4C97),
    error: dark ? const Color(0xFFFF9D5C) : const Color(0xFFD55E00),
  ),
  ColorVision.tritanopia => (
    primary: dark ? const Color(0xFFFF7FB0) : const Color(0xFFC2185B),
    secondary: dark ? const Color(0xFF4DD0C1) : const Color(0xFF00796B),
    tertiary: dark ? const Color(0xFFBDBDBD) : const Color(0xFF555555),
    error: dark ? const Color(0xFFFF8A80) : const Color(0xFFB71C1C),
  ),
  ColorVision.monochrome => (
    primary: dark ? const Color(0xFFF2F2F2) : const Color(0xFF1A1A1A),
    secondary: dark ? const Color(0xFFCFCFCF) : const Color(0xFF444444),
    tertiary: dark ? const Color(0xFFAAAAAA) : const Color(0xFF6A6A6A),
    error: dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
  ),
};

Color _on(Color c) => ThemeData.estimateBrightnessForColor(c) == Brightness.dark ? Colors.white : Colors.black;

class _NoTransitions extends PageTransitionsBuilder {
  const _NoTransitions();

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) => child;
}

/// Applies accessibility settings on top of a theme.
ThemeData applyAccessibility(ThemeData base, A11ySettings a) {
  final ext = A11yTheme(touchScale: a.touchScale, strongFocus: a.strongFocus);
  if (a.isDefault) return base.copyWith(extensions: [...base.extensions.values.where((e) => e is! A11yTheme), ext]);
  final dark = base.brightness == Brightness.dark;
  var scheme = base.colorScheme;
  var t = base;

  final palette = colorVisionPalette(a.colorVision, dark: dark);
  if (palette != null) {
    scheme = scheme.copyWith(
      primary: palette.primary,
      onPrimary: _on(palette.primary),
      secondary: palette.secondary,
      onSecondary: _on(palette.secondary),
      tertiary: palette.tertiary,
      onTertiary: _on(palette.tertiary),
      error: palette.error,
      onError: _on(palette.error),
    );
  }

  final c = a.highContrast ? 1.0 : a.contrast;
  if (c > 0) {
    final strong = a.highContrast ? (dark ? Colors.white : Colors.black) : scheme.onSurface;
    scheme = scheme.copyWith(
      onSurface: strong,
      onSurfaceVariant: Color.lerp(scheme.onSurfaceVariant, strong, c),
      outline: Color.lerp(scheme.outline, strong, c * 0.85),
      outlineVariant: Color.lerp(scheme.outlineVariant, strong, c * 0.6),
    );
    t = t.copyWith(dividerColor: Color.lerp(t.dividerColor, strong, c * 0.6));
  }

  var text = t.textTheme;
  if (c > 0) text = text.apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  if (a.lineHeight != 1 || a.wordSpacing != 0 || a.boldText) {
    TextStyle? adj(TextStyle? s) => s?.copyWith(
      height: a.lineHeight == 1 ? null : (s.height ?? 1.25) * a.lineHeight,
      wordSpacing: a.wordSpacing == 0 ? null : a.wordSpacing,
      fontWeight: a.boldText && (s.fontWeight ?? FontWeight.w400).value < FontWeight.w600.value ? FontWeight.w600 : null,
    );
    text = text.copyWith(
      displayLarge: adj(text.displayLarge),
      displayMedium: adj(text.displayMedium),
      displaySmall: adj(text.displaySmall),
      headlineLarge: adj(text.headlineLarge),
      headlineMedium: adj(text.headlineMedium),
      headlineSmall: adj(text.headlineSmall),
      titleLarge: adj(text.titleLarge),
      titleMedium: adj(text.titleMedium),
      titleSmall: adj(text.titleSmall),
      bodyLarge: adj(text.bodyLarge),
      bodyMedium: adj(text.bodyMedium),
      bodySmall: adj(text.bodySmall),
      labelLarge: adj(text.labelLarge),
      labelMedium: adj(text.labelMedium),
      labelSmall: adj(text.labelSmall),
    );
  }

  return t.copyWith(
    colorScheme: scheme,
    textTheme: text,
    iconTheme: a.largeIcons ? t.iconTheme.copyWith(size: 28) : null,
    materialTapTargetSize: a.touchScale > 1 ? MaterialTapTargetSize.padded : null,
    visualDensity: a.touchScale > 1 ? VisualDensity(horizontal: (a.touchScale - 1) * 4, vertical: (a.touchScale - 1) * 4) : null,
    focusColor: a.strongFocus ? scheme.primary.withValues(alpha: 0.32) : null,
    splashFactory: a.reduceMotion ? NoSplash.splashFactory : null,
    pageTransitionsTheme: a.reduceMotion
        ? PageTransitionsTheme(builders: {for (final p in TargetPlatform.values) p: const _NoTransitions()})
        : null,
    extensions: [...t.extensions.values.where((e) => e is! A11yTheme), ext],
  );
}

class _A11yIntent extends Intent {
  const _A11yIntent(this.action);
  final String action;
}

/// Wraps the whole app: interface zoom, motion and contrast flags for
/// every widget below, a visible keyboard-focus ring and global shortcuts.
class A11yScope extends ConsumerStatefulWidget {
  const A11yScope({super.key, required this.child, this.onOpenQuickPanel});

  final Widget child;
  final VoidCallback? onOpenQuickPanel;

  @override
  ConsumerState<A11yScope> createState() => _A11yScopeState();
}

class _A11yScopeState extends ConsumerState<A11yScope> {
  @override
  void dispose() {
    timeDilation = 1;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = ref.watch(a11ySettingsProvider);
    // Global animation speed (2× speed = half the duration).
    final dilation = a.reduceMotion ? 1.0 : 1 / a.animationSpeed;
    if (timeDilation != dilation) timeDilation = dilation;

    final mq = MediaQuery.of(context);
    Widget result = widget.child;

    if (a.strongFocus) result = _FocusRing(child: result);

    result = Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyA, alt: true, shift: true): _A11yIntent('panel'),
        SingleActivator(LogicalKeyboardKey.mediaPlayPause): _A11yIntent('toggle'),
        SingleActivator(LogicalKeyboardKey.mediaTrackNext): _A11yIntent('next'),
        SingleActivator(LogicalKeyboardKey.mediaTrackPrevious): _A11yIntent('previous'),
      },
      child: Actions(
        actions: {
          _A11yIntent: CallbackAction<_A11yIntent>(
            onInvoke: (i) {
              final music = ref.read(musicControllerProvider.notifier);
              switch (i.action) {
                case 'panel':
                  widget.onOpenQuickPanel?.call();
                case 'toggle':
                  music.toggle();
                case 'next':
                  music.next();
                case 'previous':
                  music.previous();
              }
              return null;
            },
          ),
        },
        child: result,
      ),
    );

    var data = mq.copyWith(
      disableAnimations: mq.disableAnimations || a.reduceMotion,
      highContrast: mq.highContrast || a.highContrast,
      boldText: mq.boldText || a.boldText,
    );
    final s = a.uiScale;
    if (s != 1) {
      // Lay the app out in a smaller (or larger) logical space and scale
      // it to fill the screen: everything grows together.
      data = data.copyWith(
        size: mq.size / s,
        padding: mq.padding / s,
        viewPadding: mq.viewPadding / s,
        viewInsets: mq.viewInsets / s,
        devicePixelRatio: mq.devicePixelRatio * s,
      );
      result = FittedBox(
        fit: BoxFit.fill,
        child: SizedBox(width: mq.size.width / s, height: mq.size.height / s, child: MediaQuery(data: data, child: result)),
      );
    } else {
      result = MediaQuery(data: data, child: result);
    }
    if (a.colorVision == ColorVision.monochrome) {
      result = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: result,
      );
    }
    return result;
  }
}

/// Draws a thick outline around whatever has keyboard focus.
class _FocusRing extends StatefulWidget {
  const _FocusRing({required this.child});
  final Widget child;

  @override
  State<_FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<_FocusRing> {
  Rect? _rect;
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_update);
    FocusManager.instance.addHighlightModeListener(_mode);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_update);
    FocusManager.instance.removeHighlightModeListener(_mode);
    super.dispose();
  }

  void _mode(FocusHighlightMode _) => _update();

  void _update() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Rect? next;
      final node = FocusManager.instance.primaryFocus;
      final host = _key.currentContext?.findRenderObject();
      // Only while navigating by keyboard, and only for real controls.
      if (FocusManager.instance.highlightMode == FocusHighlightMode.traditional &&
          node != null &&
          node.context != null &&
          node is! FocusScopeNode &&
          host is RenderBox) {
        final box = node.context!.findRenderObject();
        if (box is RenderBox && box.attached && box.hasSize) {
          final r = MatrixUtils.transformRect(box.getTransformTo(host), Offset.zero & box.size);
          if (r.width < host.size.width * 0.98 || r.height < host.size.height * 0.9) next = r;
        }
      }
      if (next != _rect) setState(() => _rect = next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final r = _rect;
    return Stack(
      key: _key,
      children: [
        widget.child,
        if (r != null)
          Positioned.fromRect(
            rect: r.inflate(3),
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: prismCorners(context, 10),
                  border: Border.all(color: color, width: 3),
                  boxShadow: [BoxShadow(color: _on(color), spreadRadius: 1)],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Tells screen readers about content that changed without a page change.
void announceForA11y(String message) {
  try {
    final view = ui.PlatformDispatcher.instance.views.firstOrNull;
    if (view != null) SemanticsService.sendAnnouncement(view, message, TextDirection.ltr);
  } catch (_) {}
}
