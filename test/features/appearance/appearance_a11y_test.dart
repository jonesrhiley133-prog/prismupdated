import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:prism_plurality/features/accessibility/a11y_settings.dart';
import 'package:prism_plurality/features/accessibility/a11y_theme.dart';
import 'package:prism_plurality/features/appearance/models/look.dart';
import 'package:prism_plurality/features/appearance/services/appearance_store.dart';
import 'package:prism_plurality/shared/theme/app_theme.dart';
import 'package:prism_plurality/shared/theme/look_theme.dart';
import 'package:prism_plurality/shared/utils/haptics.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('looks survive JSON and reject junk', () {
    final aurora = builtInLooks.firstWhere((l) => l.id == 'aurora');
    final back = PrismLook.fromJson(
      jsonDecode(
        jsonEncode(
          aurora
              .withPageBackground(
                'journal',
                const BgSpec(kind: BgKind.color, color: 0xFF112233),
              )
              .toJson(),
        ),
      ),
    )!;
    expect(back.element(LookElement.card).opacity, closeTo(0.10, 1e-9));
    expect(back.background.builtin, 'aurora');
    expect(back.backgroundFor('journal').color, 0xFF112233);
    expect(back.backgroundFor('notes').kind, BgKind.builtin);
    expect(PrismLook.fromJson({'nope': 1}), isNull);
    final clamped = BgSpec.fromJson({
      'blur': 999,
      'colors': [1],
      'kind': 'weird',
    });
    expect(clamped.blur, 30);
    expect(clamped.colors.length, 2);
    expect(clamped.kind, BgKind.theme);
    expect(builtInLooks.map((l) => l.id).toSet().length, builtInLooks.length);
  });

  test(
    'presets: save, duplicate, rename, export/import, delete resets users',
    () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(appearanceProvider.future);
      final n = c.read(appearanceProvider.notifier);
      final mine = await n.saveLook(
        builtInLooks[1].copyWith(id: '', name: 'Mine'),
      );
      expect(mine.builtIn, isFalse);
      await n.activate(mine.id);
      await n.setPageLook('journal', mine.id);
      final dup = await n.duplicate(mine, 'Copy');
      await n.rename(dup.id, ' Renamed ');
      final imported = await n.import(n.export(mine));
      expect(imported!.name, 'Mine');
      expect(imported.id, isNot(mine.id));
      expect(await n.import('not json'), isNull);
      expect(
        await n.import('{"name":"x"}'),
        isNull,
        reason: 'needs the prismTheme marker',
      );
      await n.deleteLook(mine.id);
      final s = c.read(appearanceProvider).value!;
      expect(s.looks.map((l) => l.name), ['Renamed', 'Mine']);
      expect(s.activeId, 'prism');
      expect(s.pageLooks, isEmpty);
      expect(s.modifiedAt, greaterThan(0));
      // Persisted.
      final c2 = ProviderContainer();
      addTearDown(c2.dispose);
      expect((await c2.read(appearanceProvider.future)).looks.length, 2);
    },
  );

  test('automatic light/dark and live preview', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(appearanceProvider.future);
    await c
        .read(appearanceProvider.notifier)
        .setAuto(auto: true, lightId: 'sunrise', darkId: 'midnight');
    expect(c.read(activeLookProvider(false)).id, 'sunrise');
    expect(c.read(activeLookProvider(true)).id, 'midnight');
    c
        .read(lookPreviewProvider.notifier)
        .show(builtInLooks.firstWhere((l) => l.id == 'forest'));
    expect(c.read(activeLookProvider(false)).id, 'forest');
    c.read(lookPreviewProvider.notifier).show(null);
    expect(c.read(activeLookProvider(false)).id, 'sunrise');
  });

  test('applyLook restyles the theme; plain look changes nothing', () {
    final base = AppTheme.dark();
    final plain = applyLook(base, plainLook);
    expect(plain.colorScheme, base.colorScheme);
    final neon = applyLook(
      base,
      builtInLooks.firstWhere((l) => l.id == 'midnight'),
    );
    expect(neon.colorScheme.primary, const Color(0xFF00E5FF));
    expect(neon.scaffoldBackgroundColor, const Color(0xFF000000));
    expect(
      neon.extension<LookTheme>()!.fill(LookElement.card),
      const Color(0xFF0B0B10),
    );
    final solid = applyLook(
      base,
      builtInLooks.firstWhere((l) => l.id == 'aurora'),
      reduceTransparency: true,
    );
    expect(solid.extension<LookTheme>()!.fill(LookElement.card)!.a, 1);
  });

  test('colour matrix is identity at defaults', () {
    final m = adjustMatrix();
    expect(m.sublist(0, 5), [1, 0, 0, 0, 0]);
    expect(adjustMatrix(saturation: 0)[0], closeTo(0.2126, 1e-6));
  });

  test('background images are shrunk and re-encoded', () {
    final big = img.Image(width: 4000, height: 2000);
    final out = optimizeBackground(Uint8List.fromList(img.encodePng(big)))!;
    final decoded = img.decodeJpg(out)!;
    expect(decoded.width, 1600);
    expect(decoded.height, 800);
    expect(optimizeBackground(Uint8List.fromList([1, 2, 3])), isNull);
  });

  test('accessibility settings persist, clamp and drive haptics', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(a11yProvider.future);
    await c
        .read(a11yProvider.notifier)
        .change(
          (a) => a.copyWith(
            uiScale: 1.2,
            haptics: false,
            colorVision: ColorVision.deuteranopia,
          ),
        );
    expect(Haptics.enabled, isFalse);
    final c2 = ProviderContainer();
    addTearDown(c2.dispose);
    final s = await c2.read(a11yProvider.future);
    expect(s.uiScale, 1.2);
    expect(s.colorVision, ColorVision.deuteranopia);
    expect(A11ySettings.fromJson({'uiScale': 9}).uiScale, 1.4);
    await c.read(a11yProvider.notifier).reset();
    expect(Haptics.enabled, isTrue);
    expect(c.read(a11ySettingsProvider).isDefault, isTrue);
  });

  test('accessibility theme: palette, contrast, spacing, no transitions', () {
    final base = AppTheme.light();
    expect(
      applyAccessibility(base, const A11ySettings()).colorScheme,
      base.colorScheme,
    );
    final t = applyAccessibility(
      base,
      const A11ySettings(
        colorVision: ColorVision.deuteranopia,
        highContrast: true,
        lineHeight: 1.5,
        reduceMotion: true,
        largeIcons: true,
      ),
    );
    expect(t.colorScheme.primary, const Color(0xFF0072B2));
    expect(t.colorScheme.onSurface, Colors.black);
    expect(
      t.textTheme.bodyMedium!.height,
      closeTo((base.textTheme.bodyMedium!.height ?? 1.25) * 1.5, 1e-6),
    );
    expect(t.iconTheme.size, 28);
    expect(
      t.pageTransitionsTheme.builders.length,
      TargetPlatform.values.length,
    );
  });

  testWidgets('presets restyle Prism cards and buttons', (tester) async {
    final look = builtInLooks.firstWhere((l) => l.id == 'midnight');
    await tester.pumpWidget(
      MaterialApp(
        theme: applyLook(AppTheme.dark(), look),
        home: Scaffold(
          body: Column(
            children: [
              const PrismSurface(child: Text('card')),
              PrismButton(
                label: 'go',
                tone: PrismButtonTone.filled,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
    final card = tester
        .widgetList<AnimatedContainer>(
          find.descendant(
            of: find.byType(PrismSurface),
            matching: find.byType(AnimatedContainer),
          ),
        )
        .first;
    final deco = card.decoration! as BoxDecoration;
    expect(deco.color, const Color(0xFF0B0B10));
    expect((deco.borderRadius! as BorderRadius).topLeft.x, 14);
  });

  testWidgets('interface scaling and reduce motion reach every widget', (
    tester,
  ) async {
    late MediaQueryData seen;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          a11ySettingsProvider.overrideWithValue(
            const A11ySettings(uiScale: 1.25, reduceMotion: true),
          ),
        ],
        child: MaterialApp(
          home: A11yScope(
            child: Builder(
              builder: (context) {
                seen = MediaQuery.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    expect(
      seen.size.width,
      closeTo(
        tester.view.physicalSize.width / tester.view.devicePixelRatio / 1.25,
        0.5,
      ),
    );
    expect(seen.disableAnimations, isTrue);
  });

  testWidgets('backgrounds are baked once into a cached image and reused', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('bg');
    addTearDown(() => dir.deleteSync(recursive: true));
    final photo = img.Image(width: 800, height: 1200);
    img.fill(photo, color: img.ColorRgb8(200, 80, 120));
    File('${dir.path}/p.jpg').writeAsBytesSync(img.encodeJpg(photo));
    for (final spec in [
      const BgSpec(
        kind: BgKind.builtin,
        builtin: 'aurora',
        overlay: BgOverlay.vignette,
      ),
      const BgSpec(
        kind: BgKind.image,
        image: 'p.jpg',
        blur: 20,
        brightness: -0.2,
        saturation: 0.5,
        opacity: 0.8,
      ),
      const BgSpec(
        kind: BgKind.gradient,
        colors: [0xFF000000, 0xFFFFFFFF, 0xFF7C4DFF],
        gradient: GradientKind.radial,
      ),
    ]) {
      final req = BakeRequest(
        spec: spec,
        dir: dir.path,
        portrait: true,
        longestPx: 1200,
        base: 0xFF101010,
        reduceEffects: false,
        reduceTransparency: false,
      );
      final first = await tester.runAsync(() => bakeBackground(req));
      expect(first, isNotNull, reason: spec.kind.name);
      expect(
        first!.height,
        spec.blur > 0 ? 600 : 1200,
        reason: 'blurred backgrounds bake at half size',
      );
      final again = await tester.runAsync(() => bakeBackground(req));
      expect(
        identical(first, again),
        isTrue,
        reason: 'second request comes from the cache',
      );
    }
    final missing = BakeRequest(
      spec: const BgSpec(kind: BgKind.image, image: 'nope.jpg'),
      dir: dir.path,
      portrait: true,
      longestPx: 800,
      base: 0,
      reduceEffects: false,
      reduceTransparency: false,
    );
    expect(await tester.runAsync(() => bakeBackground(missing)), isNull);
  });
}
