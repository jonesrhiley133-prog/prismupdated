import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/shared/widgets/list_detail_layout.dart';

/// Every tab page. Used until the app shell reports which tabs are in the
/// nav bar.
const Set<String> kPrismTabRootPaths = {
  AppRoutePaths.home,
  AppRoutePaths.chat,
  AppRoutePaths.habits,
  AppRoutePaths.polls,
  AppRoutePaths.settings,
  AppRoutePaths.members,
  AppRoutePaths.reminders,
  AppRoutePaths.notes,
  AppRoutePaths.statistics,
  AppRoutePaths.timeline,
  AppRoutePaths.sleep,
  AppRoutePaths.astro,
  AppRoutePaths.games,
  AppRoutePaths.cozy,
  AppRoutePaths.experiences,
};

/// Where pages can be left from without a back button: the tabs shown in
/// the nav bar right now (set by the app shell). Every other page — a
/// feature tab you haven't added to the bar, a settings page, a detail
/// page — gets one, so nothing is a dead end. iOS web apps have no system
/// back gesture, so this matters there most.
abstract final class PrismNavRoots {
  static Set<String>? _visible;

  static Set<String> get visible => _visible ?? kPrismTabRootPaths;

  static void update(Iterable<String> roots) => _visible = roots.toSet();
}

/// Recent locations, so Back from a page with nothing underneath it (opened
/// from another tab, a widget or a link) returns to where the user was.
abstract final class PrismBackHistory {
  static final List<String> _stack = [];
  static const _max = 40;

  static void record(String location) {
    if (_stack.isNotEmpty && _stack.last == location) return;
    if (_stack.length >= 2 && _stack[_stack.length - 2] == location) {
      _stack.removeLast(); // Went back.
      return;
    }
    _stack.add(location);
    if (_stack.length > _max) _stack.removeAt(0);
  }

  /// The location before the current one, if any.
  static String? previous() =>
      _stack.length >= 2 ? _stack[_stack.length - 2] : null;

  @visibleForTesting
  static void reset() => _stack.clear();
}

/// Flows that must be finished rather than backed out of.
const Set<String> _kNoBackPaths = {AppRoutePaths.onboarding};

/// The location of the page [context] sits in (not the app's current one),
/// or null outside a router page.
String? _pageLocation(BuildContext context) {
  // GoRouterState.of walks up through every navigator when the page isn't a
  // router page, registering dependencies along the way; only ask when it is.
  if (GoRouter.maybeOf(context) == null) return null;
  if (ModalRoute.of(context)?.settings is! Page<Object?>) return null;
  try {
    return GoRouterState.of(context).matchedLocation;
  } catch (_) {
    return null;
  }
}

/// Whether the page holding [context] should offer a way back.
bool prismPageHasBack(BuildContext context) {
  final route = ModalRoute.of(context);
  // Sheets and dialogs have their own close controls.
  if (route != null && route is! PageRoute) return false;
  if (route != null && !route.isFirst) return true;
  // Not "can the navigator pop": a menu or sheet opened over this page
  // would flip that and rebuild the bar under the menu.
  final location = _pageLocation(context);
  if (location == null) return false;
  if (_kNoBackPaths.contains(location)) return false;
  return !PrismNavRoots.visible.contains(location);
}

/// Goes back from the page holding [context]: closes a detail pane, pops a
/// route, or — when the page was opened directly (a link, a reload, a
/// `go`) and there is nothing underneath — returns to the parent page or
/// Home.
void prismGoBack(BuildContext context) {
  if (!context.mounted) return;
  if (closeDetailSurface(context, routeBacked: false)) return;
  final navigator = Navigator.maybeOf(context);
  if (navigator != null && navigator.canPop()) {
    unawaited(navigator.maybePop());
    return;
  }
  final router = GoRouter.maybeOf(context);
  if (router == null) return;
  if (router.canPop()) {
    router.pop();
    return;
  }
  final location = _pageLocation(context) ?? AppRoutePaths.home;
  router.go(PrismBackHistory.previous() ?? _parentOf(location));
}

/// The nearest tab root above [location], else Home.
String _parentOf(String location) {
  var path = Uri.parse(location).path;
  while (path.contains('/') && path != '/') {
    path = path.substring(0, path.lastIndexOf('/'));
    if (path.isEmpty) break;
    if (kPrismTabRootPaths.contains(path)) return path;
  }
  return AppRoutePaths.home;
}
