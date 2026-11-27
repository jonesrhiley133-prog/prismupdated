import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/appearance/appearance_library.dart';
import 'package:prism_plurality/features/appearance/models/look.dart';
import 'package:prism_plurality/features/appearance/views/background_gallery.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';
import 'package:prism_plurality/shared/theme/collection_backgrounds.dart';
import 'package:prism_plurality/shared/theme/look_theme.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

class _FakeLib extends AppearanceLibraryNotifier {
  @override
  Future<void> flush() async {}
}

void main() {
  test('120 backgrounds in 12 collections of 10, all different', () {
    final all = collectionBackgrounds;
    expect(all, hasLength(120));
    expect(all.map((b) => b.id).toSet(), hasLength(120));
    expect(all.map((b) => b.name).toSet(), hasLength(120));
    expect(
      all.map((b) => '${b.style}|${b.colors.join(',')}').toSet(),
      hasLength(120),
    );
    for (final c in backgroundCollections) {
      final inC = all.where((b) => b.collection == c.$1).toList();
      expect(inC, hasLength(10), reason: c.$1);
      expect(
        inC.map((b) => b.style).toSet().length,
        greaterThanOrEqualTo(7),
        reason: c.$1,
      );
    }
    expect(all.map((b) => b.style).toSet().length, greaterThan(70));
  });

  test('every background paints at phone and tablet sizes', () {
    for (final b in collectionBackgrounds) {
      for (final size in const [
        Size(390, 844),
        Size(1024, 768),
        Size(60, 100),
      ]) {
        final rec = ui.PictureRecorder();
        b.paint(Canvas(rec), size);
        rec.endRecording().dispose();
      }
    }
  });

  test('new background settings round-trip and are bounded', () {
    const s = BgSpec(
      kind: BgKind.builtin,
      builtin: 'milkyWay',
      temperature: 0.4,
      zoom: 1.8,
      alignX: -0.5,
      alignY: 0.3,
      repeat: true,
      parallax: 0.6,
      scrolls: true,
      texture: 'kraft',
      textureIntensity: 0.7,
      tintMode: 'complement',
    );
    final b = BgSpec.fromJson(s.toJson());
    expect(b.toJson(), s.toJson());
    expect(BgSpec.fromJson({'tintMode': 'mono'}).tintMode, 'mono');
    final bad = BgSpec.fromJson({'zoom': 9, 'temperature': -5, 'parallax': 3});
    expect([bad.zoom, bad.temperature, bad.parallax], [3.0, -1.0, 1.0]);
    // Defaults stay out of the stored JSON.
    expect(const BgSpec().toJson().keys, isNot(contains('zoom')));
  });

  test('complementary and monochrome tints', () {
    final theme = ThemeData(
      colorScheme: const ColorScheme.light(primary: Color(0xFFFF0000)),
    );
    final comp = backgroundTint(
      const BgSpec(tintMode: 'complement', tintStrength: 1),
      theme,
      null,
    )!.$1!;
    expect(HSLColor.fromColor(comp).hue, closeTo(180, 1));
    final mono = backgroundTint(
      const BgSpec(tintMode: 'mono', tintStrength: 0.2),
      theme,
      null,
    )!.$1!;
    expect(mono.a, greaterThanOrEqualTo(0.89));
  });

  test('temperature warms reds and cools blues', () {
    final warm = adjustMatrix(temperature: 1);
    expect(warm[4], greaterThan(0));
    expect(warm[14], lessThan(0));
    final neutral = adjustMatrix();
    expect(neutral[4], 0);
  });

  test('new pages can have their own background', () {
    for (final p in [
      'profiles',
      'subsystemProfiles',
      'contacts',
      'companions',
      'games',
      'settings',
    ]) {
      expect(lookPages, contains(p));
    }
  });

  testWidgets('collection backgrounds bake into images', (t) async {
    await t.runAsync(() async {
      final img = await bakeBackground(
        const BakeRequest(
          spec: BgSpec(
            kind: BgKind.builtin,
            builtin: 'neonCity',
            zoom: 1.5,
            texture: 'kraft',
            temperature: 0.3,
          ),
          dir: null,
          portrait: true,
          longestPx: 400,
          base: 0xFF000000,
          reduceEffects: false,
          reduceTransparency: false,
        ),
      );
      expect(img, isNotNull);
    });
  });

  testWidgets('gallery filters, favourites and picks', (t) async {
    final c = ProviderContainer(
      overrides: [
        appearanceLibraryProvider.overrideWith(_FakeLib.new),
        trackerKindProvider.overrideWith(
          (ref, kind) => const AsyncValue.data(<TrackerRecord>[]),
        ),
      ],
    );
    t.view.physicalSize = const Size(420, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    String? picked;
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: PrismButton(
                label: 'open',
                onPressed: () async =>
                    picked = await showBackgroundGallery(context),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 150));
    }
    await t.enterText(find.byType(TextField).first, 'vinyl');
    await t.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('bg:vinylRecords')), findsOneWidget);
    await t.longPress(find.byKey(const ValueKey('bg:vinylRecords')));
    await t.pump(const Duration(milliseconds: 200));
    expect(
      c.read(appearanceLibraryProvider).isFavorite('bg:vinylRecords'),
      isTrue,
    );
    await t.tap(find.byKey(const ValueKey('bg:vinylRecords')));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 150));
    }
    expect(picked, 'vinylRecords');
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });
}
