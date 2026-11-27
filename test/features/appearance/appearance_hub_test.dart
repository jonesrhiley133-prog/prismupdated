import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/appearance/appearance_library.dart';
import 'package:prism_plurality/features/appearance/views/appearance_hub.dart';
import 'package:prism_plurality/features/seasonal/decor_models.dart';
import 'package:prism_plurality/features/seasonal/seasonal_providers.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePrefs extends SeasonalPrefsNotifier {
  @override
  Future<void> flush() async {}
}

class _FakeLib extends AppearanceLibraryNotifier {
  @override
  Future<void> flush() async {}
}

ProviderContainer _c() => ProviderContainer(
  overrides: [
    seasonalPrefsProvider.overrideWith(_FakePrefs.new),
    appearanceLibraryProvider.overrideWith(_FakeLib.new),
    trackerKindProvider.overrideWith(
      (ref, kind) => const AsyncValue.data(<TrackerRecord>[]),
    ),
  ],
);

Widget _host(ProviderContainer c, Widget child) => UncontrolledProviderScope(
  container: c,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('hub lists every section and searches them', (t) async {
    final c = _c();
    t.view.physicalSize = const Size(420, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_host(c, const AppearanceHub()));
    await _settle(t);
    for (final id in [
      'themes',
      'colors',
      'backgrounds',
      'fonts',
      'living',
      'seasonal',
      'studio',
      'rooms',
      'icons',
      'iconStudio',
      'environment',
      'audio',
      'layouts',
      'presets',
      'imported',
      'accessibility',
      'performance',
    ]) {
      expect(find.byKey(ValueKey('hub:$id')), findsOneWidget, reason: id);
    }
    await t.enterText(find.byType(TextField).first, 'weather');
    await _settle(t);
    expect(find.byKey(const ValueKey('hub:environment')), findsOneWidget);
    expect(find.byKey(const ValueKey('hub:fonts')), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('ambient audio is off until turned on', (t) async {
    final c = _c();
    t.view.physicalSize = const Size(420, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_host(c, const AppearanceHub()));
    await _settle(t);
    expect(c.read(seasonalPrefsProvider).audioOn, isFalse);
    await t.tap(find.byKey(const ValueKey('hub:audio')));
    await _settle(t);
    await t.tap(find.text('Play ambient sound'));
    await _settle(t);
    expect(c.read(seasonalPrefsProvider).audioOn, isTrue);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('layers card turns one layer off without touching others', (
    t,
  ) async {
    final c = _c();
    c
        .read(seasonalPrefsProvider.notifier)
        .update(
          (p) => p.copyWith(
            performance: DecoPerformance.balanced,
            livingVariation: 'kawaii.1',
            layoutVariation: 'gothic.2',
          ),
        );
    t.view.physicalSize = const Size(420, 2600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_host(c, const AppearanceHub()));
    await _settle(t);
    expect(find.text('Your layers'), findsOneWidget);
    await t.tap(find.byTooltip('Turn off Living decorations'));
    await _settle(t);
    final p = c.read(seasonalPrefsProvider);
    expect(p.livingVariation, isNull);
    expect(p.layoutVariation, 'gothic.2');
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('performance screen: battery saver and limits', (t) async {
    final c = _c();
    t.view.physicalSize = const Size(420, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppearancePerformanceScreen(),
        ),
      ),
    );
    await _settle(t);
    expect(find.textContaining('0 bytes downloaded'), findsOneWidget);
    await t.tap(find.text('Battery saver'));
    await _settle(t);
    expect(c.read(seasonalPrefsProvider).integrations['batterySaver'], isTrue);
    await t.tap(find.text('Clear caches'));
    await _settle(t);
    await t.pump(const Duration(seconds: 4));
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });

  test('sizes read nicely', () {
    expect(formatBytes(512), '512 B');
    expect(formatBytes(2048), '2.0 KB');
    expect(formatBytes(3 * 1024 * 1024), '3.0 MB');
  });
}
