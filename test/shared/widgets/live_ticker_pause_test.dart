import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/features/fronting/widgets/fronting_duration_text.dart';
import 'package:prism_plurality/shared/widgets/live_ticker.dart';

/// Hidden shell sections keep their widgets mounted with tickers off. Live
/// timers must stop ticking there and catch up the moment they show again.
void main() {
  Widget host({required bool visible, required Widget child}) => Directionality(
    textDirection: TextDirection.ltr,
    child: TickerMode(enabled: visible, child: child),
  );

  testWidgets('LiveTicker does not rebuild while hidden', (tester) async {
    var builds = 0;
    Widget ticker() => LiveTicker(
      builder: (_, now) {
        builds++;
        return const SizedBox();
      },
    );

    await tester.pumpWidget(host(visible: true, child: ticker()));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    final visibleBuilds = builds;
    expect(visibleBuilds, greaterThanOrEqualTo(3));

    await tester.pumpWidget(host(visible: false, child: ticker()));
    final afterHide = builds;
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(builds, afterHide, reason: 'no ticks while hidden');

    await tester.pumpWidget(host(visible: true, child: ticker()));
    for (var i = 0; i < 2; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(builds, greaterThan(afterHide + 1), reason: 'ticks again');
  });

  testWidgets('FrontingDurationText stops rebuilding while hidden', (
    tester,
  ) async {
    final start = DateTime.now().subtract(const Duration(seconds: 10));
    Widget text(bool visible) => host(
      visible: visible,
      child: FrontingDurationText(startTime: start),
    );
    var rebuilds = 0;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      if (element.widget is FrontingDurationText) rebuilds++;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = null);

    Future<void> seconds(int n) async {
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
    }

    await tester.pumpWidget(text(true));
    await seconds(3);
    expect(rebuilds, greaterThanOrEqualTo(3), reason: 'ticks every second');

    await tester.pumpWidget(text(false));
    final afterHide = rebuilds;
    await seconds(5);
    expect(rebuilds, afterHide, reason: 'no ticks while hidden');

    await tester.pumpWidget(text(true));
    await seconds(2);
    expect(rebuilds, greaterThan(afterHide + 1), reason: 'ticks again');
  });
}
