import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/core/features/feature_registry.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/domain/repositories/entity_repository.dart';
import 'package:prism_plurality/features/settings/providers/settings_providers.dart';
import 'package:prism_plurality/features/settings/views/feature_data_screen.dart';
import 'package:prism_plurality/features/settings/views/features_settings_screen.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';

class _Repo implements EntityRepository<TrackerRecord> {
  _Repo([List<TrackerRecord> seed = const []]) : rows = [...seed];
  final List<TrackerRecord> rows;
  final _c = StreamController<List<TrackerRecord>>.broadcast();
  @override
  Stream<List<TrackerRecord>> watchAll() async* {
    yield [...rows];
    yield* _c.stream;
  }

  @override
  Future<List<TrackerRecord>> getAll() async => [...rows];
  @override
  Future<TrackerRecord?> getById(String id) async =>
      rows.where((r) => r.id == id).firstOrNull;
  @override
  Future<void> create(TrackerRecord item) async {
    rows.add(item);
    _c.add([...rows]);
  }

  @override
  Future<void> update(TrackerRecord item) async {
    rows[rows.indexWhere((r) => r.id == item.id)] = item;
    _c.add([...rows]);
  }

  @override
  Future<void> delete(String id) async {
    rows.removeWhere((r) => r.id == id);
    _c.add([...rows]);
  }
}

Widget _app(Widget home, _Repo repo) => ProviderScope(
  overrides: [
    trackerRecordRepositoryProvider.overrideWithValue(repo),
    featureFlagsProvider.overrideWithValue((
      chat: true,
      polls: true,
      habits: true,
      sleep: true,
      notes: true,
      reminders: true,
      boards: false,
    )),
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: const [Locale('en')],
    home: home,
  ),
);

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 5; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  for (final w in const [380.0, 1200.0]) {
    testWidgets(
      'Features page lists categories and every feature at ${w.toInt()}px',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(w, 2000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(_app(const FeaturesSettingsScreen(), _Repo()));
        await _settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('Presets'), findsOneWidget);
        expect(find.text('System management'), findsOneWidget);
        expect(
          find.textContaining(RegExp(r'^\d+ of \d+ features on')),
          findsOneWidget,
        );
        // Scroll through and find a few features.
        await tester.scrollUntilVisible(
          find.text('Relationships'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Relationships'), findsWidgets);
      },
    );
  }

  testWidgets('turning a feature off asks about dependents and saves', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(500, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _Repo();
    await tester.pumpWidget(_app(const FeaturesSettingsScreen(), repo));
    await _settle(tester);
    // Fitness has a dependent (health integration).
    final fitnessRow = find
        .ancestor(of: find.text('Fitness'), matching: find.byType(InkWell))
        .first;
    await tester.ensureVisible(fitnessRow);
    final sw = find.descendant(of: fitnessRow, matching: find.byType(Switch));
    await tester.tap(sw);
    await _settle(tester);
    expect(find.textContaining('Health app integration'), findsWidgets);
    await tester.tap(find.text('Only this'));
    await _settle(tester);
    final rec = repo.rows
        .where((r) => r.kind == TrackerKind.appFeatures)
        .single;
    expect((rec.fields['on'] as Map)['fitness'], isFalse);
    expect((rec.fields['on'] as Map).containsKey('healthIntegration'), isFalse);
  });

  testWidgets('data management explains features without dated data', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const FeatureDataScreen(featureId: 'contacts'), _Repo()),
    );
    await _settle(tester);
    expect(find.textContaining('long-term information'), findsOneWidget);
    await tester.pumpWidget(
      _app(const FeatureDataScreen(featureId: 'fitness'), _Repo()),
    );
    await _settle(tester);
    expect(find.text('Reset data'), findsOneWidget);
    expect(find.text('This week'), findsOneWidget);
    expect(find.textContaining('Clear all'), findsWidgets);
    expect(prismFeatureIndex['fitness']!.data.hasActivity, isTrue);
  });
}
