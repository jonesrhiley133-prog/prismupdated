import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_plurality/features/appearance/models/look.dart'
    show BgSpec;
import 'package:prism_plurality/features/appearance/services/appearance_store.dart';
import 'package:prism_plurality/shared/theme/look_theme.dart';
import 'package:flutter/material.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/sliver_pinned_top_bar.dart';

/// Shared page scaffold for Prism screens with predictable padding and slots.
///
/// When [topBar] is provided the body is placed inside a [NestedScrollView]
/// whose header is [SliverPinnedTopBar]. The inner body scroll drives the
/// outer sliver, so content scrolls behind the bar exactly like the tab
/// screens — same gradient, same behaviour.
class PrismPageScaffold extends StatelessWidget {
  const PrismPageScaffold({
    super.key,
    required this.body,
    this.topBar,
    this.backgroundColor,
    this.bodyPadding = PrismTokens.pagePadding,
    this.extendBody = false,
    this.bottomBar,
    this.floatingActionButton,
    this.resizeToAvoidBottomInset,
    this.safeAreaBottom = true,
    this.topBarMaxWidth = double.infinity,
  });

  final Widget body;
  final PreferredSizeWidget? topBar;
  final Color? backgroundColor;
  final EdgeInsets bodyPadding;
  final bool extendBody;
  final Widget? bottomBar;
  final Widget? floatingActionButton;
  final bool? resizeToAvoidBottomInset;
  final bool safeAreaBottom;

  /// Max width of the pinned top bar surface, centered. Set to
  /// [PrismTokens.contentMaxWidth] on content-primary screens whose body is
  /// clamped, so the bar lines up with the content column.
  final double topBarMaxWidth;

  @override
  Widget build(BuildContext context) {
    final paddedBody = Padding(
      padding: bodyPadding,
      child: safeAreaBottom ? SafeArea(top: false, child: body) : body,
    );

    final scaffoldBody = topBar != null
        ? NestedScrollView(
            headerSliverBuilder: (_, _) => [
              SliverPinnedTopBar(maxWidth: topBarMaxWidth, child: topBar!),
            ],
            body: paddedBody,
          )
        : paddedBody;

    Widget scaffold(Color? color) => Scaffold(
      backgroundColor: color,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBody: extendBody,
      body: scaffoldBody,
      bottomNavigationBar: bottomBar,
      floatingActionButton: floatingActionButton,
    );

    return LookBackdrop(fixedColor: backgroundColor, builder: scaffold);
  }
}

/// Draws the user's background (app-wide or per-page) behind a page and
/// applies a page's own appearance preset. [builder] gets the colour the
/// page's Scaffold should use: transparent when a custom background is
/// showing, otherwise [fixedColor] (or null for the theme default).
///
/// Every full page should go through this — directly, or via
/// [PrismPageScaffold] — so custom backgrounds show everywhere.
class LookBackdrop extends StatelessWidget {
  const LookBackdrop({super.key, required this.builder, this.fixedColor});

  final Widget Function(Color? background) builder;

  /// A colour the page insists on (e.g. a full-screen viewer). Wins over
  /// the custom background.
  final Color? fixedColor;

  @override
  Widget build(BuildContext context) {
    final look = LookTheme.of(context);
    if (look == null) return builder(fixedColor);

    // Appearance presets: a page can have its own theme and background.
    final page = lookPageOf(context);
    return Consumer(
      builder: (context, ref, _) {
        final pageLook = ref.watch(appearancePageLookProvider(page));
        final effective = pageLook ?? look.look;
        final bg = effective.backgroundFor(page);
        if (pageLook == null && (!bg.isCustom || fixedColor != null)) {
          return builder(fixedColor);
        }
        Widget built = !bg.isCustom || fixedColor != null
            ? builder(fixedColor)
            : (bg.parallax > 0 || bg.scrolls) && !look.reduceEffects
            ? _ScrollingBackdrop(
                spec: bg,
                background: LookBackground(
                  spec: bg,
                  dir: look.backgroundDir,
                  reduceEffects: look.reduceEffects,
                  reduceTransparency: look.reduceTransparency,
                ),
                child: builder(Colors.transparent),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  LookBackground(
                    spec: bg,
                    dir: look.backgroundDir,
                    reduceEffects: look.reduceEffects,
                    reduceTransparency: look.reduceTransparency,
                  ),
                  builder(Colors.transparent),
                ],
              );
        if (pageLook != null) {
          // Built from the clean base theme that suits the page preset's
          // colours, so it never stacks on the app preset or ends up with
          // dark text on a dark page (or the reverse).
          built = Theme(
            data: look.themeFor(pageLook, Theme.of(context).brightness),
            child: Builder(
              builder: (context) => Material(
                type: MaterialType.transparency,
                textStyle: Theme.of(context).textTheme.bodyMedium,
                child: built,
              ),
            ),
          );
        }
        return built;
      },
    );
  }
}

/// The page id used for per-page backgrounds: the first path segment of
/// the current route ("/journal/…" → "journal", "/" → "home").
String? lookPageOf(BuildContext context) {
  try {
    final segments = GoRouterState.of(context).uri.pathSegments;
    if (segments.isEmpty) return 'home';
    // An alter's or subsystem's own profile can have its own background.
    if (segments.length >= 2 && segments.first == 'members') return 'profiles';
    if (segments.length >= 2 && segments.first == 'subsystems') {
      return 'subsystemProfiles';
    }
    return segments.first;
  } catch (_) {
    return null;
  }
}

/// A background that drifts behind scrolling content (parallax) or scrolls
/// away with it. Listens to the page's own scrolling; nothing else moves.
class _ScrollingBackdrop extends StatefulWidget {
  const _ScrollingBackdrop({
    required this.spec,
    required this.background,
    required this.child,
  });
  final BgSpec spec;
  final Widget background;
  final Widget child;
  @override
  State<_ScrollingBackdrop> createState() => _ScrollingBackdropState();
}

class _ScrollingBackdropState extends State<_ScrollingBackdrop> {
  final _offset = ValueNotifier<double>(0);

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth == 0 && n.metrics.axis == Axis.vertical) {
      _offset.value = n.metrics.pixels.clamp(0, double.infinity);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    return LayoutBuilder(
      builder: (context, box) {
        final h = box.maxHeight.isFinite ? box.maxHeight : 800.0;
        // Parallax needs a taller picture so the bottom never shows.
        final extra = spec.scrolls ? 0.0 : h * spec.parallax * 0.5;
        return Stack(
          fit: StackFit.expand,
          children: [
            ValueListenableBuilder<double>(
              valueListenable: _offset,
              builder: (context, o, child) {
                final dy = spec.scrolls
                    ? -o.clamp(0.0, h)
                    : -(o * spec.parallax * 0.3).clamp(0.0, extra);
                return Transform.translate(offset: Offset(0, dy), child: child);
              },
              child: OverflowBox(
                alignment: Alignment.topCenter,
                maxHeight: h + extra,
                minHeight: h + extra,
                child: widget.background,
              ),
            ),
            NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: widget.child,
            ),
          ],
        );
      },
    );
  }
}
