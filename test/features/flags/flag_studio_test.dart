import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/fronting/providers/fronting_providers.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/features/flags/flag_model.dart';
import 'package:prism_plurality/features/flags/flag_render.dart';
import 'package:prism_plurality/features/flags/flag_screens.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';
import 'package:prism_plurality/shared/theme/app_theme.dart';

void main() {
  test('designs round-trip', () {
    final d = FlagDesign(
      ratio: '1:2',
      shape: 'swallowtail',
      layers: [
        FlagLayer(
          id: 'a',
          kind: 'layout',
          layout: 'nordic',
          colors: const [1, 2],
        ),
        const FlagLayer(
          id: 'b',
          kind: 'draw',
          colors: [3],
          stroke: 0.02,
          points: [Offset(0.1, 0.2), Offset(0.3, 0.4)],
        ),
        const FlagLayer(
          id: 'c',
          kind: 'vector',
          paths: [('M0 0 L1 0 L1 1 Z', 0xFF00FF00)],
        ),
      ],
    );
    final b = FlagDesign.fromJson(d.toJson());
    expect(
      [
        b.ratio,
        b.shape,
        b.layers.length,
        b.layers[1].points.length,
        b.layers[2].paths.first.$2,
      ],
      ['1:2', 'swallowtail', 3, 2, 0xFF00FF00],
    );
  });

  test('SVG import reads shapes and ignores scripts and links', () {
    const svg = '''<svg viewBox="0 0 100 50" onload="alert(1)">
      <script>alert('x')</script>
      <foreignObject><div>hi</div></foreignObject>
      <rect x="0" y="0" width="100" height="25" fill="#ff0000"/>
      <circle cx="50" cy="25" r="10" style="fill: rgb(0,0,255)"/>
      <path d="m10 10 l20 0 l0 20 z" fill="green"/>
      <image href="https://example.com/x.png"/>
      <rect width="5" height="5" fill="none"/>
    </svg>''';
    final paths = importSvg(svg);
    expect(paths.length, 3);
    expect(paths[0].$2, 0xFFFF0000);
    expect(paths[1].$2, 0xFF0000FF);
    expect(paths[2].$1, startsWith('M0.1000 0.2000'));
  });

  test('SVG export covers every template', () {
    for (final e in flagTemplates.entries) {
      final svg = exportFlagSvg(e.value, title: e.key);
      expect(svg, startsWith('<svg'));
      expect(svg, contains('</svg>'));
      expect(svg, isNot(contains('<script')));
    }
  });

  testWidgets('studio, editor and info page open', (t) async {
    final now = DateTime(2026, 11, 20);
    final seed = [
      TrackerRecord(
        id: 'f1',
        kind: TrackerKind.flag,
        title: 'Our flag',
        createdAt: now,
        modifiedAt: now,
      ).withFields({
        'design': flagTemplates['Starry canton']!.toJson(),
        'assigned': ['system'],
      }),
    ];
    Widget app(Widget home) => ProviderScope(
      overrides: [
        trackerRecordsProvider.overrideWith((ref) => Stream.value(seed)),
        userVisibleMembersProvider.overrideWithValue(
          const AsyncData(<Member>[]),
        ),
        activeSessionsProvider.overrideWith(
          (ref) => Stream.value(const <FrontingSession>[]),
        ),
        currentFronterProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );
    for (final s in const <Widget>[
      FlagStudioScreen(),
      FlagEditorScreen(flagId: 'f1'),
      FlagInfoScreen(flagId: 'f1'),
      Scaffold(body: FlagStrip(owner: 'system')),
    ]) {
      await t.pumpWidget(app(s));
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(t.takeException(), isNull, reason: '$s');
    }
    await t.pumpWidget(app(const FlagEditorScreen(flagId: 'f1')));
    await t.pump(const Duration(milliseconds: 200));
    for (final p in [
      'Layout',
      'Symbols',
      'Colours',
      'Import',
      'Flag',
      'Layers',
    ]) {
      await t.tap(find.text(p).first);
      await t.pump(const Duration(milliseconds: 100));
      expect(t.takeException(), isNull, reason: p);
    }
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
  });
}
