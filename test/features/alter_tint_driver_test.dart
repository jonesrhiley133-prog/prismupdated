import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/features/members/views/member_detail_screen.dart';
import 'package:prism_plurality/shared/theme/look_theme.dart';

const _red = Color(0xFFE5383B);

class _Pusher extends StatelessWidget {
  const _Pusher();
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ElevatedButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const AlterAccentScope(
              accent: _red,
              child: Scaffold(body: Text('profile')),
            ),
          ),
        ),
        child: const Text('open'),
      ),
    ),
  );
}

void main() {
  tearDown(() => viewedAlterAccent.value = null);

  test('fading to or from no tint keeps the hue (no grey dip)', () {
    // Simulate a change from none to red, halfway.
    final c = Color.lerp(_red.withValues(alpha: 0), _red, 0.5)!;
    expect((c.r * 255).round(), (_red.r * 255).round());
    expect(c.a, closeTo(0.5, 0.01));
  });

  testWidgets(
    'opening a profile tints quickly, and going back lets go right away',
    (t) async {
      await t.pumpWidget(const MaterialApp(builder: _driver, home: _Pusher()));
      expect(viewedAlterTintColor(viewedAlterTintProgress.value), isNull);

      await t.tap(find.text('open'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      await t.pumpAndSettle();
      expect(viewedAlterAccent.value, _red);
      expect(
        viewedAlterTintColor(viewedAlterTintProgress.value)?.a,
        closeTo(1, 0.01),
      );

      // Start going back: the tint is released at once, not after the page closes.
      final nav = t.state<NavigatorState>(find.byType(Navigator));
      nav.pop();
      await t.pump();
      await t.pump(const Duration(milliseconds: 16));
      expect(
        viewedAlterAccent.value,
        isNull,
        reason: 'released as soon as the page starts leaving',
      );
      await t.pump(const Duration(milliseconds: 260));
      final now = viewedAlterTintColor(viewedAlterTintProgress.value);
      expect(
        now == null || now.a < 0.01,
        isTrue,
        reason: 'faded out within a quarter second',
      );
      await t.pumpAndSettle();
    },
  );

  testWidgets('another page opening over the profile hands the tint back', (
    t,
  ) async {
    await t.pumpWidget(const MaterialApp(builder: _driver, home: _Pusher()));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(viewedAlterAccent.value, _red);
    t
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('other')),
          ),
        );
    await t.pump();
    await t.pump(const Duration(milliseconds: 16));
    expect(viewedAlterAccent.value, isNull);
    // Coming back to the profile tints again.
    t.state<NavigatorState>(find.byType(Navigator)).pop();
    await t.pump();
    await t.pump(const Duration(milliseconds: 16));
    expect(viewedAlterAccent.value, _red);
    await t.pumpAndSettle();
  });
}

Widget _driver(BuildContext context, Widget? child) =>
    ViewedAlterTintDriver(child: child!);
