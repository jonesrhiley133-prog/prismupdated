import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/features/settings/views/font_studio_screen.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';
import 'package:prism_plurality/shared/fonts/font_catalog.dart';
import 'package:prism_plurality/shared/fonts/font_prefs.dart';
import 'package:prism_plurality/shared/fonts/prism_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('choices round-trip through JSON', () {
    final prefs = FontPrefs(
      surfaces: {
        FontSurface.global: const SurfaceFont(
          family: 'g:Poppins',
          weight: 600,
          letterSpacing: 0.5,
          lineHeight: 1.6,
          size: 1.1,
        ),
        FontSurface.bio: const SurfaceFont(family: 'imp:abc123'),
      },
      favorites: ['g:Caveat'],
      recents: ['g:Poppins'],
      imported: [const ImportedFont('abc123', 'My font', '/tmp/x.ttf')],
      plainOverride: true,
    );
    final back = FontPrefs.fromJson(prefs.toJson());
    expect(back.of(FontSurface.global), prefs.of(FontSurface.global));
    expect(back.of(FontSurface.bio).family, 'imp:abc123');
    expect(back.favorites, ['g:Caveat']);
    expect(back.imported.single.name, 'My font');
    expect(back.plainOverride, isTrue);
  });

  test('bad or hostile saved data falls back safely', () {
    expect(FontPrefs.fromJson('nope').isDefault, isTrue);
    final p = FontPrefs.fromJson({
      'surfaces': {
        'global': {'w': 5000, 'ls': 999, 's': 99},
        'madeUp': {'f': 'x'},
      },
      'fav': [1, 'g:Lora'],
    });
    expect(p.of(FontSurface.global).weight, 900);
    expect(p.of(FontSurface.global).letterSpacing, 6);
    expect(p.of(FontSurface.global).size, 1.8);
    expect(p.favorites, ['g:Lora']);
  });

  test('inherit: a surface without its own font uses the whole-app font', () {
    const prefs = FontPrefs(
      surfaces: {
        FontSurface.global: SurfaceFont(family: 'g:Lora'),
        FontSurface.bio: SurfaceFont(family: 'g:Caveat'),
      },
    );
    expect(prefs.effectiveFamily(FontSurface.journal), 'g:Lora');
    expect(prefs.effectiveFamily(FontSurface.bio), 'g:Caveat');
  });

  test(
    'accessibility override swaps decorative fonts but keeps plain ones',
    () {
      const on = FontPrefs(plainOverride: true);
      expect(PrismFonts.resolve('g:Caveat', on), isNull); // handwriting
      expect(PrismFonts.resolve('g:Pixelify Sans', on), isNull);
      expect(PrismFonts.resolve('g:Inter', on), 'g:Inter');
      expect(PrismFonts.resolve('g:Caveat', const FontPrefs()), 'g:Caveat');
      expect(PrismFonts.resolve('serif', on), 'serif'); // legacy keys untouched
    },
  );

  test('weight, spacing, line height and size reach the theme', () {
    final base = ThemeData(
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontSize: 14),
        headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w400),
      ),
    );
    final themed = PrismFonts.applyTheme(
      base,
      const FontPrefs(
        surfaces: {
          FontSurface.body: SurfaceFont(
            weight: 700,
            letterSpacing: 1,
            lineHeight: 1.9,
            size: 1.5,
          ),
        },
      ),
    );
    final b = themed.textTheme.bodyMedium!;
    expect(b.fontWeight, FontWeight.w700);
    expect(b.height, 1.9);
    expect(
      b.letterSpacing,
      closeTo((base.textTheme.bodyMedium!.letterSpacing ?? 0) + 1, 1e-9),
    );
    expect(
      b.fontSize,
      closeTo(base.textTheme.bodyMedium!.fontSize! * 1.5, 1e-9),
    );
    // Headings were not touched.
    expect(
      themed.textTheme.headlineMedium!.fontWeight,
      base.textTheme.headlineMedium!.fontWeight,
    );
  });

  test('default prefs leave the theme untouched', () {
    final base = ThemeData();
    expect(
      identical(PrismFonts.applyTheme(base, const FontPrefs()), base),
      isTrue,
    );
  });

  test('font files are validated before import', () async {
    final dir = await Directory.systemTemp.createTemp('fonts-test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final woff = File('${dir.path}/a.woff2')..writeAsBytesSync([1, 2, 3]);
    expect(
      (await PrismFonts.importFile(woff.path)).error,
      contains('TTF or OTF'),
    );
    final txt = File('${dir.path}/a.txt')..writeAsStringSync('hello');
    expect((await PrismFonts.importFile(txt.path)).font, isNull);
    final fake = File('${dir.path}/fake.ttf')..writeAsBytesSync(Uint8List(64));
    expect((await PrismFonts.importFile(fake.path)).error, isNotNull);
    expect(
      PrismFonts.looksLikeFont(
        Uint8List.fromList([0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
      ),
      isTrue,
    );
    expect(
      PrismFonts.looksLikeFont(Uint8List.fromList('OTTO0000....'.codeUnits)),
      isTrue,
    );
    expect(
      PrismFonts.looksLikeFont(Uint8List.fromList('<html>0000000'.codeUnits)),
      isFalse,
    );
  });

  testWidgets(
    'Font Studio lists every place fonts can change and opens the browser',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(500, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const FontStudioScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      for (final s in FontSurface.values) {
        expect(find.text(s.en), findsOneWidget, reason: s.en);
      }
      expect(find.text('Plain fonts only'), findsOneWidget);
      expect(find.text('Import a font (TTF / OTF)'), findsOneWidget);
      expect(fontCatalog.length, greaterThanOrEqualTo(150));
    },
  );
}
