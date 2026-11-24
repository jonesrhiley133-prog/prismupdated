import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as hp;
import 'package:http/testing.dart';
import 'package:prism_social_core/prism_social_core.dart';

import 'package:prism_plurality/features/online_games/online_room.dart';
import 'package:prism_plurality/features/online_games/online_screens.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';
import 'package:prism_plurality/shared/theme/app_theme.dart';

Map<String, Object?> room(Map<String, Object?> state, {int version = 3}) => {
  'code': 'ABCDE',
  'game': 'tictactoe',
  'status': 'playing',
  'version': version,
  'round': 1,
  'host': 'p1',
  'you': 'p1',
  'seat': 0,
  'players': [
    {'id': 'p1', 'name': 'Ash', 'online': true, 'wins': 0},
    {'id': 'p2', 'name': 'Bea', 'online': true, 'wins': 0},
  ],
  'state': state,
  'chat': <Object?>[],
};

void main() {
  testWidgets('room screen shows the code and sends a move', (tester) async {
    Object? sentMove;
    final mock = MockClient((req) async {
      if (req.method == 'GET') return hp.Response('', 304);
      sentMove = (jsonDecode(req.body) as Map)['move'];
      final s = const TicTacToe().apply(
        const TicTacToe().initial(2),
        0,
        sentMove,
      );
      return hp.Response(
        jsonEncode({'room': room(s, version: 4)}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final session = RoomSession(
      RoomClient('https://x.test', token: 't', http: mock),
      RoomView(room(const TicTacToe().initial(2))),
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: OnlineRoomScreen(session: session),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('ABCDE'), findsOneWidget);
    expect(find.text('Your turn'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Empty').at(4));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(sentMove, 4);
    expect(find.text("Bea's turn"), findsOneWidget);
    session.closed = true;
    await tester.pumpWidget(const SizedBox());
  });
}
