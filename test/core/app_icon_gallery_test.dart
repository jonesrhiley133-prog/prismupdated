import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/core/app_icon/app_icon.dart';
import 'package:prism_plurality/core/app_icon/custom_icon.dart';
import 'package:prism_plurality/core/app_icon/icon_art.dart';
import 'package:prism_plurality/core/app_icon/icon_catalog.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/appearance/appearance_library.dart';
import 'package:prism_plurality/features/seasonal/seasonal_catalog.dart';
import 'package:prism_plurality/features/settings/views/app_icon_gallery.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeLib extends AppearanceLibraryNotifier {
  @override
  Future<void> flush() async {}
}

void _paint(IconArt a) {
  final rec = ui.PictureRecorder();
  paintIconArt(Canvas(rec), 96, a);
  rec.endRecording().dispose();
}

String _res(String id) => id
    .replaceAllMapped(RegExp('([a-z])([A-Z0-9])'), (m) => '${m[1]}_${m[2]}')
    .toLowerCase();

void main() {
  test('60 permanent designs, all named, all different', () {
    final d = permanentIconDesigns;
    expect(d, hasLength(60));
    expect(d.map((x) => x.id).toSet(), hasLength(60));
    for (final name in [
      'Original',
      'Monochrome Black',
      'Frosted Glass',
      'Iridescent',
      'Saturn',
      'Cosmic Crystal',
      'Frutiger Aero',
      'Retro Computer',
      'Mushroom',
      'Rainy Window',
      'Stained Glass',
      'Paper Cutout',
      'Arcade',
      'Fairycore',
    ]) {
      expect(d.map((x) => x.en), contains(name));
    }
    String sig(IconArt a) =>
        '${a.bg}|${a.fg}|${a.logo}|${a.deco}|${a.c1}|${a.c2}|${a.c3}';
    expect(d.map((x) => sig(x.art)).toSet(), hasLength(60));
    // Not recolours: many different backdrop/figure compositions.
    expect(
      d.map((x) => '${x.art.bg}|${x.art.fg}').toSet().length,
      greaterThan(45),
    );
    for (final g in iconArtGroups) {
      expect(d.where((x) => x.group == g.$1), hasLength(10), reason: g.$1);
    }
    for (final x in d) {
      expect(iconBackgrounds, contains(x.art.bg));
      expect(iconFigures, contains(x.art.fg));
      _paint(x.art);
    }
  });

  test('15 seasonal icons per holiday and season', () {
    for (final c in seasonalCollections) {
      final list = seasonalIconDesigns(c.id);
      expect(list, hasLength(15), reason: c.id);
      expect(list.map((x) => x.id).toSet(), hasLength(15));
      expect(
        list.map((x) => '${x.art.bg}|${x.art.glyph}|${x.art.c1}').toSet(),
        hasLength(15),
        reason: c.id,
      );
      expect(iconDesignById(list[7].id)?.id, list[7].id);
    }
    _paint(seasonalIconDesigns('christmas').first.art);
    expect(
      seasonalIconDesigns('cyberpunk'),
      isEmpty,
      reason: 'living genres are not holidays',
    );
  });

  test('every launcher icon has its Android alias and art', () {
    final all = allAppIconPresets;
    expect(all, hasLength(92));
    expect(all.map((p) => p.id).toSet(), hasLength(92));
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final kotlin = File(
      'android/app/src/main/kotlin/com/prismplural/prism/AppIcon.kt',
    ).readAsStringSync();
    for (final p in all) {
      final alias = 'Launcher${p.id[0].toUpperCase()}${p.id.substring(1)}';
      expect(manifest, contains('android:name=".$alias"'), reason: p.id);
      expect(kotlin, contains('"${p.id}"'), reason: p.id);
      if (p.art != null) {
        final r = _res(p.id);
        expect(
          File(
            'android/app/src/main/res/drawable-nodpi/ic_launcher_art_$r.webp',
          ).existsSync(),
          isTrue,
          reason: r,
        );
        expect(
          File(
            'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_$r.xml',
          ).existsSync(),
          isTrue,
        );
      }
    }
  });

  test('Icon Studio settings round-trip and are bounded', () {
    const s = CustomIconSpec(
      art: 'knit',
      texture: 'kraft',
      border: 0.4,
      borderColor: 0xFF112233,
      sticker: '⭐',
      text: 'Prism',
      textColor: 0xFF000000,
      shadow: true,
      opacity: 0.6,
      overlay: 'gloss',
      shape: 'teardrop',
    );
    final b = CustomIconSpec.fromJson(s.toJson());
    expect(b.toJson(), s.toJson());
    final bad = CustomIconSpec.fromJson({
      'art': 'lava',
      'opacity': 0.01,
      'border': 9,
      'text': 'abcdefghij',
      'overlay': 'boom',
      'shape': 'hexagon',
    });
    expect(bad.art, isNull);
    expect(bad.opacity, 0.2);
    expect(bad.border, 1);
    expect(bad.text, 'abcdef');
    expect(bad.overlay, 'none');
    expect(bad.shape, 'squircle');
  });

  testWidgets('gallery shows groups, search and the seasonal library', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer(
      overrides: [
        appearanceLibraryProvider.overrideWith(_FakeLib.new),
        trackerKindProvider.overrideWith(
          (ref, kind) => const AsyncValue.data(<TrackerRecord>[]),
        ),
      ],
    );
    t.view.physicalSize = const Size(420, 3000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppIconGalleryScreen(),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('icon:saturn')), findsOneWidget);
    await t.enterText(find.byType(TextField).first, 'mush');
    await t.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('icon:mushroom')), findsOneWidget);
    expect(find.byKey(const ValueKey('icon:saturn')), findsNothing);
    await t.enterText(find.byType(TextField).first, '');
    await t.scrollUntilVisible(
      find.text('Seasonal library'),
      200,
      scrollable: find.descendant(
        of: find
            .byWidgetPredicate(
              (w) => w is ListView && w.scrollDirection == Axis.horizontal,
            )
            .first,
        matching: find.byType(Scrollable),
      ),
    );
    await t.ensureVisible(find.text('Seasonal library'));
    await t.pump(const Duration(milliseconds: 100));
    await t.tap(find.text('Seasonal library'));
    await t.pump(const Duration(milliseconds: 300));
    final first = seasonalCollections.first.id;
    expect(find.byKey(ValueKey('icon:seas.$first.0')), findsOneWidget);
    expect(find.byKey(ValueKey('icon:seas.$first.14')), findsOneWidget);
    expect(
      find.text('Change the icon for holidays automatically'),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });
}
