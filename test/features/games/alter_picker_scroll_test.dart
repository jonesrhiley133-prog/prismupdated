import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/games/core/games_data.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';
import 'package:prism_plurality/shared/theme/app_theme.dart';

/// Regression: with many alters the picker sheet must scroll and keep its
/// Done button reachable on a small phone screen.
void main() {
  testWidgets('alter picker scrolls and Done stays reachable', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final members = [
      for (var i = 0; i < 60; i++)
        Member(id: 'm$i', name: 'Alter $i', createdAt: DateTime(2024)),
    ];
    List<String>? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameMembersProvider.overrideWithValue(members),
          gameNamesProvider.overrideWithValue({
            for (final m in members) m.id: m.name,
          }),
          gamePlayerDefaultProvider.overrideWithValue(null),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async =>
                      result = await pickAlters(context, ref),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'no overflow');

    final done = find.text('Continue without choosing');
    expect(done, findsOneWidget);
    final box = tester.getRect(done);
    expect(box.bottom, lessThanOrEqualTo(640), reason: 'Done button on screen');

    // The last alter is reachable by scrolling.
    await tester.scrollUntilVisible(
      find.text('Alter 59'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Alter 59'));
    await tester.pump();
    await tester.tap(find.text('Done (1)'));
    await tester.pumpAndSettle();
    expect(result, ['m59']);
  });
}
