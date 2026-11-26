import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/features/cozy/data/cozy_data.dart';
import 'package:prism_plurality/features/cozy/views/collections_view.dart';
import 'package:prism_plurality/features/games/core/games_data.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';
import 'package:prism_plurality/shared/theme/app_theme.dart';

void main() {
  testWidgets('doodle wall opens and draws', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          doodlesProvider.overrideWithValue(const []),
          gameNamesProvider.overrideWithValue(const {}),
          gameMembersProvider.overrideWithValue(const []),
          cozyMeProvider.overrideWithValue(null),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const DoodleWallScreen(),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(tester.takeException(), isNull);
    await tester.dragFrom(const Offset(150, 300), const Offset(80, 40));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });
}
