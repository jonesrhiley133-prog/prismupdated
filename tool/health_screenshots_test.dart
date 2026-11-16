import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/data/repositories/drift_tracker_record_repository.dart';
import 'package:flutter/material.dart';
import 'package:prism_plurality/shared/theme/app_theme.dart';
import 'package:prism_plurality/shared/widgets/prism_segmented_control.dart';
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
  List<TrackerRecord> records = const [],
}) => ProviderScope(
  overrides: [
    if (repository != null)
      trackerRecordRepositoryProvider.overrideWithValue(repository),
    healthRecordsProvider.overrideWithValue(AsyncData(records)),
    healthViewersProvider.overrideWithValue({'a'}),
    userVisibleMembersProvider.overrideWithValue(
      AsyncData([Member(id: 'a', name: 'Alter A', createdAt: DateTime(2026))]),
    ),
  ],
  child: MaterialApp(
    key: UniqueKey(),
    debugShowCheckedModeBanner: false,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: child,
  ),
);

// Capture actual Flutter widgets with Prism themes and synthetic review data.
// Run explicitly: flutter test tool/health_screenshots_test.dart
void main() {
  setUpAll(() async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final item in manifest) {
      final loader = FontLoader(item['family'] as String);
      for (final font in item['fonts'] as List) {
        loader.addFont(
          rootBundle.load(Uri.decodeComponent(font['asset'] as String)),
        );
      }
      await loader.load();
    }
    final sdk = Platform.environment['FLUTTER_ROOT'];
    if (sdk != null) {
      final loader = FontLoader('Roboto');
      for (final weight in ['Regular', 'Medium', 'Bold']) {
        loader.addFont(
          File(
            '$sdk/bin/cache/artifacts/material_fonts/Roboto-$weight.ttf',
          ).readAsBytes().then(ByteData.sublistView),
        );
      }
      await loader.load();
    }
  });
  testWidgets('Capture Health and Body Sheet review screens', (tester) async {
    final dir = Directory(
      const String.fromEnvironment(
        'PRISM_HEALTH_SCREENSHOT_DIR',
        defaultValue: 'test-results/health-screenshots',
      ),
    );
    await tester.runAsync(() => dir.create(recursive: true));
    final key = GlobalKey();
    final at = DateTime(2026, 11, 16, 9, 30);
    final spots = <Map<String, dynamic>>[
      {
        'id': 'finger',
        'region': 'front_left_ring_finger',
        'label': 'Left ring finger',
        'side': 'left',
        'view': 'front',
        'x': .821,
        'y': .54,
        'areaMode': 'point',
        'descriptors': ['tingly', 'warm'],
        'intensity': '3',
        'time': 'This morning',
        'notes': 'Noticed after waking.',
      },
      {
        'id': 'blade',
        'region': 'back_right_shoulder_blade',
        'label': 'Right Shoulder blade',
        'side': 'right',
        'view': 'back',
        'descriptors': ['tight'],
        'intensity': '5',
        'time': 'Yesterday afternoon',
      },
    ];
    final checkin =
        TrackerRecord(
          id: 'review',
          kind: healthCheckIn,
          title: 'Shoulder tension & tingling',
          body: 'A gentle check-in after waking.',
          createdAt: at,
          modifiedAt: at,
          occurredAt: at,
          memberId: 'a',
          isPrivate: true,
        ).withFields({
          'author': 'a',
          'subjects': ['a'],
          'subjectMode': 'alters',
          'status': 'open',
          'symptoms': [
            {
              'id': 's1',
              'term': 'Tension and tingling',
              'category': 'Sensation and coordination',
              'severity': 'Mild',
              'onset': 'This morning',
              'course': 'Unchanged',
              'spots': spots,
            },
          ],
        });
    final episode =
        TrackerRecord(
          id: 'episode',
          kind: healthEpisode,
          title: 'Shoulder tension this week',
          createdAt: at,
          modifiedAt: at,
          occurredAt: at,
          memberId: 'a',
          isPrivate: true,
        ).withFields({
          'author': 'a',
          'subjects': ['a'],
          'subjectMode': 'alters',
          'status': 'improving',
        });
    Future<void> mount(
      Widget child, {
      double width = 390,
      Brightness brightness = Brightness.light,
    }) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      debugPrint('Mounting ${child.runtimeType} at $width in $brightness');
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: _app(
            KeyedSubtree(key: UniqueKey(), child: child),
            brightness: brightness,
            records: [checkin, episode],
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> capture(String name) async {
      debugPrint('Capturing $name');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${dir.path}/$name.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    await mount(const HealthScreen());
    await capture('01-health-timeline-mobile');
    await mount(const HealthScreen(initialTab: 1), brightness: Brightness.dark);
    await capture('02-health-body-map-dark');
    await mount(HealthBodyMapEditor(initial: spots));
    await capture('03-body-sheet-mobile');
    await mount(
      HealthBodyMapEditor(initial: spots),
      width: 1280,
      brightness: Brightness.dark,
    );
    await capture('04-body-sheet-desktop-dark');
    tester
        .widget<PrismSegmentedControl<String>>(
          find.byKey(const ValueKey('body-sheet-view')),
        )
        .onChanged('back');
    await tester.pumpAndSettle();
    await capture('07-body-sheet-back-desktop');
    await mount(HealthBodyMapEditor(initial: spots));
    await tester.tap(find.byTooltip('1. Left ring finger: tingly, warm'));
    await tester.pumpAndSettle();
    await capture('08-location-sensations');
    await mount(
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showHealthLog(context, editing: checkin),
            child: const Text('Open log'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open log'));
    await tester.pumpAndSettle();
    await capture('05-health-log');
    await tester.ensureVisible(find.text('Tension and tingling'));
    await tester.tap(find.text('Tension and tingling'));
    await tester.pumpAndSettle();
    await capture('06-symptom-details');
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
