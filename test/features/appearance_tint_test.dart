import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/features/appearance/models/look.dart';
import 'package:prism_plurality/shared/theme/look_theme.dart';

void main() {
  testWidgets('built-in backgrounds render with and without an alter accent', (t) async {
    await t.pumpWidget(const MaterialApp(home: LookBackground(spec: BgSpec(kind: BgKind.builtin, builtin: 'aurora'))));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await t.pump();
    expect(t.takeException(), isNull);
    viewedAlterAccent.value = const Color(0xFFE5383B);
    await t.pump(const Duration(milliseconds: 500));
    expect(t.takeException(), isNull);
    viewedAlterAccent.value = null;
    await t.pump(const Duration(milliseconds: 500));
    expect(t.takeException(), isNull);
  });

  test('tint modes', () {
    final theme = ThemeData.light();
    const b = BgSpec(kind: BgKind.builtin);
    expect(b.effectiveTint, 'accent');
    expect(const BgSpec(kind: BgKind.image).effectiveTint, 'original');
    expect(backgroundTint(b, theme, null), isNull);
    expect(backgroundTint(b, theme, const Color(0xFFFF0000))!.$1!.a, closeTo(0.55, 0.01));
    expect(backgroundTint(b.copyWith(tintMode: 'gradient'), theme, null)!.$2, isNotNull);
    expect(backgroundTint(b.copyWith(tintMode: 'none'), theme, const Color(0xFFFF0000)), isNull);
    final rt = BgSpec.fromJson(b.copyWith(tintMode: 'custom', tintStrength: 0.3, tintColor: 0xFF123456).toJson());
    expect([rt.tintMode, rt.tintStrength, rt.tintColor], ['custom', 0.3, 0xFF123456]);
  });
}
