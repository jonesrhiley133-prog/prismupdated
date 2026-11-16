import 'package:drift/native.dart';
import 'package:prism_plurality/core/database/app_database.dart' as db;
import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/data/repositories/drift_tracker_record_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/health/health_data.dart';
import 'package:prism_plurality/features/health/health_screen.dart';
import 'package:prism_plurality/features/health/body_map_editor.dart';

Widget _app(
  Widget child, {
  Brightness brightness = Brightness.light,
  double scale = 1,
  DriftTrackerRecordRepository? repository,
}) => ProviderScope(
  overrides: [
    if (repository != null)
      trackerRecordRepositoryProvider.overrideWithValue(repository),
    healthRecordsProvider.overrideWithValue(const AsyncData([])),
    healthViewersProvider.overrideWithValue({'a'}),
    userVisibleMembersProvider.overrideWithValue(
      AsyncData([Member(id: 'a', name: 'Alter A', createdAt: DateTime(2026))]),
    ),
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: brightness,
      ),
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: child,
  ),
);

void main() {
  for (final width in [360.0, 1280.0])
    for (final brightness in Brightness.values) {
      testWidgets(
        'Health empty page at $width in $brightness with large text',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            _app(const HealthScreen(), brightness: brightness, scale: 1.6),
          );
          await tester.pumpAndSettle();
          expect(find.text('Log how I feel'), findsOneWidget);
          expect(find.text('Timeline'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  testWidgets(
    'region list opens correct sided region and keeps a marker after switching views',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app(const HealthBodyMapEditor(initial: [])));
      await tester.pumpAndSettle();
      final search = find.byType(TextField).first;
      await tester.ensureVisible(search);
      await tester.enterText(search, 'Left ring finger');
      await tester.pumpAndSettle();
      final region = find.widgetWithText(ListTile, 'Left ring finger').first;
      await tester.ensureVisible(region);
      await tester.pumpAndSettle();
      await tester.tap(region);
      await tester.pumpAndSettle();
      expect(find.text('Left ring finger'), findsWidgets);
      expect(tester.takeException(), isNull);
      final done = find.widgetWithText(TextButton, 'Done');
      await tester.tap(done);
      await tester.pumpAndSettle();
      // Both front and back region-only selections retain separate stable IDs.
      await tester.ensureVisible(search);
      await tester.enterText(search, 'Right Shoulder blade');
      await tester.pumpAndSettle();
      final blade = find.widgetWithText(ListTile, 'Right Shoulder blade');
      await tester.ensureVisible(blade);
      await tester.pumpAndSettle();
      await tester.tap(blade);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Done'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Left ring finger · front'), findsOneWidget);
      expect(
        find.textContaining('Right Shoulder blade · back'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'quick log prevents duplicate submissions and keeps author and subject when details are edited',
    (tester) async {
      final database = db.AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftTrackerRecordRepository(
        database.trackerRecordsDao,
        null,
      );
      await tester.pumpWidget(
        _app(const HealthScreen(), repository: repository),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log how I feel'));
      await tester.pumpAndSettle();
      final description = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.labelText == 'Symptom or short description',
      );
      await tester.enterText(description, 'A little unwell');
      final save = find.widgetWithText(TextButton, 'Save').first;
      final onSave = tester.widget<TextButton>(save).onPressed!;
      onSave();
      onSave();
      await tester.pumpAndSettle();
      final all = await repository.getAll();
      expect(all.length, 1);
      expect(all.single.str('author'), 'a');
      expect(all.single.strings('subjects'), ['a']);
      expect(all.single.isPrivate, true);
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showHealthLog(context, editing: all.single),
                child: const Text('Edit entry'),
              ),
            ),
          ),
          repository: repository,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit entry'));
      await tester.pumpAndSettle();
      await tester.enterText(description, 'Headache, with more detail');
      await tester.tap(find.widgetWithText(TextButton, 'Save').first);
      await tester.pumpAndSettle();
      final updated = (await repository.getAll()).single;
      expect(updated.id, all.single.id);
      expect(updated.title, 'Headache, with more detail');
      expect(updated.str('author'), 'a');
      expect(updated.strings('subjects'), ['a']);
      expect(tester.takeException(), isNull);
    },
  );
}
