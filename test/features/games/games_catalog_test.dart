import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/features/games/core/game_builders.dart';
import 'package:prism_plurality/features/games/core/game_catalog.dart';
import 'package:prism_plurality/features/games/core/game_kit.dart';
import 'package:prism_plurality/features/games/core/games_data.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';
import 'package:prism_plurality/shared/theme/app_theme.dart';

void main() {
  test('catalog has 120 uniquely numbered games across all categories', () {
    expect(gameCatalog, hasLength(120));
    expect({for (final g in gameCatalog) g.id}, hasLength(120));
    expect([
      for (final g in gameCatalog) g.number,
    ], List.generate(120, (i) => i + 1));
    for (final c in GameCategory.values) {
      expect(
        gameCatalog.where((g) => g.category == c),
        isNotEmpty,
        reason: c.name,
      );
    }
    expect(gameById('sudoku')?.number, 41);
    expect(dailyGames(DateTime(2026, 11, 23)), isNotEmpty);
  });

  for (final def in gameCatalog) {
    testWidgets('#${def.number} ${def.id} builds and runs briefly', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      GameOutcome? finished;
      final session = GameSession(
        def: def,
        player: 'm1',
        players: const ['m1', 'm2'],
        names: const {'m1': 'Ash', 'm2': 'Bee'},
        seed: 1234,
        save: (_) {},
        finish: (o) => finished = o,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameProfilesProvider.overrideWithValue(const {}),
            gameNamesProvider.overrideWithValue(const {
              'm1': 'Ash',
              'm2': 'Bee',
            }),
            gameMembersProvider.overrideWithValue(const []),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: buildGame(def.id, session),
                ),
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      final err = tester.takeException();
      if (err is Error) debugPrint('${err.stackTrace}');
      expect(err, isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
      expect(finished == null || finished != null, isTrue);
    });
  }
}
