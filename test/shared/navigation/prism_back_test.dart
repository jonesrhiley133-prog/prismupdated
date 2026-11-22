import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';
import 'package:prism_plurality/shared/navigation/prism_back.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';

void main() {
  setUp(() {
    PrismBackHistory.reset();
    PrismNavRoots.update(const ['/', '/settings']);
  });

  test('history follows forward moves and backs', () {
    PrismBackHistory.record('/');
    PrismBackHistory.record('/mood');
    expect(PrismBackHistory.previous(), '/');
    PrismBackHistory.record('/'); // went back
    expect(PrismBackHistory.previous(), isNull);
    PrismBackHistory.record('/members');
    PrismBackHistory.record('/statuses');
    expect(PrismBackHistory.previous(), '/members');
  });

  Future<GoRouter> pumpRouter(WidgetTester tester) async {
    Widget page(String title, {bool? back}) => Scaffold(
      body: PrismTopBar(title: title, showBackButton: back),
    );
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => page('Home', back: false)),
        GoRoute(
          path: '/settings',
          builder: (_, _) => page('Settings', back: false),
          routes: [GoRoute(path: 'about', builder: (_, _) => page('About'))],
        ),
        // A feature tab that isn't in the nav bar.
        GoRoute(path: '/mood', builder: (_, _) => page('Mood', back: false)),
      ],
    );
    router.routerDelegate.addListener(
      () => PrismBackHistory.record(router.state.uri.toString()),
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('nav-bar tabs have no back button; other pages do', (
    tester,
  ) async {
    final router = await pumpRouter(tester);
    expect(find.byTooltip('Back'), findsNothing);

    router.go('/settings/about');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Back'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/settings');
    expect(find.byTooltip('Back'), findsNothing);
  });

  testWidgets('a tab outside the nav bar goes back to where you were', (
    tester,
  ) async {
    final router = await pumpRouter(tester);
    router.go('/settings');
    await tester.pumpAndSettle();
    // Opened with go: nothing to pop, and the screen asked for no back.
    router.go('/mood');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Back'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/settings');
  });
}
