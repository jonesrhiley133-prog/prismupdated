import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/domain/models/calendar_event.dart';
import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/calendar/providers/calendar_providers.dart';
import 'package:prism_plurality/features/companions/companion_screens.dart';
import 'package:prism_plurality/features/fronting/providers/fronting_providers.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/passport/passport_book.dart';
import 'package:prism_plurality/features/passport/passport_screens.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/features/wrapped/wrapped_screens.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';
import 'package:prism_plurality/shared/theme/app_theme.dart';

TrackerRecord rec(String id, String kind, {String title = '', String? parent, Map<String, Object?> fields = const {}, int order = 0}) {
  final now = DateTime(2026, 11, 20);
  return TrackerRecord(id: id, kind: kind, title: title, parentId: parent, sortOrder: order, createdAt: now, modifiedAt: now, occurredAt: now).withFields(fields);
}

final seed = [
  rec('c1', TrackerKind.companion, title: 'Pip', fields: {'species': 'fox', 'traits': ['curious'], 'ownerType': 'system', 'habitat': 'h1', 'look': {'hat': 'beanie'}}),
  rec('c2', TrackerKind.companion, title: 'Mochi', fields: {'species': 'slime', 'ownerType': 'none'}),
  rec('h1', TrackerKind.companionHabitat, fields: {'env': 'bedroom', 'items': [{'id': 'i1', 'type': 'plant', 'x': 0.2, 'y': 0.7}]}),
  rec('m1', TrackerKind.companionMemory, title: 'Adopted Pip', parent: 'c1', fields: {'kind': 'adopt', 'companions': ['c1']}),
  rec('m2', TrackerKind.companionMemory, title: 'Photo', parent: 'c1', fields: {'kind': 'photo', 'companions': ['c1'], 'scene': {'background': 'clearing', 'subjects': [{'id': 'c1'}], 'stickers': [{'e': '⭐'}]}}),
  rec('p1', TrackerKind.passport, title: 'Summer', fields: {'type': 'travel', 'ownerType': 'system', 'cover': {'material': 'leather'}}),
  rec('pg1', TrackerKind.passportPage, title: 'Stamps', parent: 'p1', fields: {'type': 'stamps'}),
  rec('pg2', TrackerKind.passportPage, title: 'Timeline', parent: 'p1', fields: {'type': 'timeline'}, order: 1),
  rec('s1', TrackerKind.passportStamp, title: 'Beach day', parent: 'p1', fields: {'category': 'places', 'design': {'shape': 'ticket', 'text': 'Beach'}}),
  rec('e1', TrackerKind.passportElement, parent: 'pg1', fields: {'type': 'stamp', 'stamp': 's1'}),
  rec('w1', TrackerKind.wrapSnapshot, title: 'November 2026', fields: {
    'period': 'monthly', 'from': '2026-11-01T00:00:00.000', 'to': '2026-12-01T00:00:00.000', 'scope': {'type': 'system', 'ids': []}, 'style': {'style': 'celestial'},
    'cards': [
      {'id': 'intro', 'kind': 'intro', 'title': 'November 2026', 'headline': '5 moments'},
      {'id': 'games', 'kind': 'games', 'title': 'Games you played', 'headline': '3 game sessions', 'items': [['Chess', '2 times', '🎮']]},
      {'id': 'closing', 'kind': 'closing', 'title': 'Thanks for being here'},
    ],
  }),
];

Widget app(Widget home) => ProviderScope(
  overrides: [
    trackerRecordsProvider.overrideWith((ref) => Stream.value(seed)),
    userVisibleMembersProvider.overrideWithValue(const AsyncData(<Member>[])),
    activeSessionsProvider.overrideWith((ref) => Stream.value(const <FrontingSession>[])),
    currentFronterProvider.overrideWith((ref) => Stream.value(null)),
    calendarEventsProvider.overrideWith((ref) => Stream.value(const <CalendarEvent>[])),
  ],
  child: MaterialApp(theme: AppTheme.light(), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, home: home),
);

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('companions hub opens and shows companions', (t) async {
    await t.pumpWidget(app(const CompanionsHubScreen()));
    await settle(t);
    expect(t.takeException(), isNull);
    expect(find.text('Mochi'), findsWidgets);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('companion profile opens', (t) async {
    await t.pumpWidget(app(const CompanionProfileScreen(companionId: 'c1')));
    await settle(t);
    expect(t.takeException(), isNull);
    expect(find.text('Pip'), findsWidgets);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('passport library and book open', (t) async {
    await t.pumpWidget(app(const PassportLibraryScreen()));
    await settle(t);
    expect(t.takeException(), isNull);
    expect(find.text('Summer'), findsWidgets);
    await t.pumpWidget(app(const PassportBookScreen(passportId: 'p1')));
    await settle(t);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('wrapped archive, studio, player and export open', (t) async {
    for (final screen in const <Widget>[WrappedHomeScreen(), WrapStudioScreen(snapshotId: 'w1'), WrapExportScreen(snapshotId: 'w1'), WrapCreateScreen(), WrapAttributionScreen(snapshotId: 'w1'), WrapSettingsScreen()]) {
      await t.pumpWidget(app(screen));
      await settle(t);
      expect(t.takeException(), isNull, reason: '$screen');
      if (screen is WrapExportScreen) expect(find.text('SHARE 3 OF 3 CARDS'), findsOneWidget);
    }
    await t.pumpWidget(app(const WrappedHomeScreen()));
    await settle(t);
    expect(find.text('November 2026'), findsWidgets);
    await t.tap(find.text('November 2026').first);
    await settle(t);
    expect(t.takeException(), isNull);
    await t.tapAt(const Offset(700, 400));
    await settle(t);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
