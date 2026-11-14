import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

    final look = LookTheme.of(context);
    if (look == null) return scaffold(backgroundColor);

    // Appearance presets: a page can have its own theme and background.
    final page = lookPageOf(context);
    return Consumer(
      builder: (context, ref, _) {
        final pageLook = ref.watch(
          appearancePageLookProvider(page),
        );
        final effective = pageLook ?? look.look;
        final bg = effective.backgroundFor(page);
        if (pageLook == null && (!bg.isCustom || backgroundColor != null)) {
          return scaffold(backgroundColor);
        }
        Widget built = !bg.isCustom || backgroundColor != null
            ? scaffold(backgroundColor)
            : Stack(
                fit: StackFit.expand,
                children: [
                  LookBackground(
                    spec: bg,
                    dir: look.backgroundDir,
                    reduceEffects: look.reduceEffects,
                    reduceTransparency: look.reduceTransparency,
                  ),
                  scaffold(Colors.transparent),
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
    return segments.isEmpty ? 'home' : segments.first;
  } catch (_) {
    return null;
  }
}
