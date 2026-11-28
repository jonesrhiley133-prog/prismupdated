import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/core/graphics/decor_clock.dart';
import 'package:prism_plurality/core/graphics/graphics_engine.dart';
import 'package:prism_plurality/core/graphics/graphics_prefs.dart';

void main() {
  group('presets', () {
    test('every preset produces a real, distinct rendering budget', () {
      final q = {
        for (final p in GraphicsPreset.values)
          if (p != GraphicsPreset.custom)
            p: computeQuality(GraphicsPrefs.forPreset(p)),
      };
      final ultra = q[GraphicsPreset.ultra]!;
      final light = q[GraphicsPreset.lightweight]!;
      expect(ultra.decorFps, 0); // every display frame
      expect(ultra.shadowLevel, 3);
      expect(ultra.liveBlur, isTrue);
      expect(light.liveBlur, isFalse);
      expect(light.shadowLevel, 0);
      expect(light.decorFps, 15);
      expect(light.particleScale, lessThan(0.3));
      expect(light.textureScale, lessThan(ultra.textureScale));
      expect(light.maxAnimated, lessThan(ultra.maxAnimated));
      expect(light.animationDetail, lessThan(0.5)); // light transitions
      final perf = q[GraphicsPreset.performance]!;
      expect(
        perf.particleScale,
        lessThan(q[GraphicsPreset.balanced]!.particleScale),
      );
      expect(perf.decorFps, lessThan(q[GraphicsPreset.balanced]!.decorFps));
    });

    test('the default (Adaptive) keeps the full look until it must adapt', () {
      final q = computeQuality(const GraphicsPrefs());
      expect(q.shadowLevel, 3);
      expect(q.blurScale, 1);
      expect(q.particleScale, 1);
      expect(q.textureScale, 1);
      expect(q.decorFps, 30);
    });

    test('changing a preset keeps device-level choices', () {
      final mine = const GraphicsPrefs(
        targetFps: 60,
        renderer: RendererMode.compatibility,
        monitor: true,
      );
      final next = GraphicsPrefs.forPreset(
        GraphicsPreset.performance,
        keep: mine,
      );
      expect(next.preset, GraphicsPreset.performance);
      expect(next.targetFps, 60);
      expect(next.renderer, RendererMode.compatibility);
      expect(next.monitor, isTrue);
    });

    test('settings survive a round trip (they persist across restarts)', () {
      final p = GraphicsPrefs.forPreset(GraphicsPreset.balanced).copyWith(
        targetFps: 90,
        particles: 0.35,
        blur: Quality.low,
        decorFps: 24,
        suspendOffscreen: false,
      );
      final back = GraphicsPrefs.fromJson(p.toJson());
      expect(back.toJson(), p.toJson());
    });
  });

  group('adaptive priority', () {
    test('low priority gives way first, then medium, then blur', () {
      const p = GraphicsPrefs();
      final full = computeQuality(p);
      final mid = computeQuality(p, level: 0.6);
      final low = computeQuality(p, level: 0.35);
      // At 60 %: particles reduced more than living decorations.
      expect(
        mid.particleScale / full.particleScale,
        lessThan(mid.decorFps / full.decorFps),
      );
      expect(mid.liveBlur, isTrue);
      // At 35 %: live blur off, shadows simplified, still drawing.
      expect(low.liveBlur, isFalse);
      expect(low.shadowLevel, lessThan(full.shadowLevel));
      expect(low.decorFps, greaterThanOrEqualTo(12));
      expect(low.ambientFps, greaterThanOrEqualTo(8));
      expect(low.decorAnimates, isTrue);
    });

    test('dynamic resolution only lowers resolution when it is on', () {
      const on = GraphicsPrefs(dynamicResolution: true);
      const off = GraphicsPrefs(dynamicResolution: false);
      expect(computeQuality(on, level: 0.5).textureScale, lessThan(1));
      expect(computeQuality(off, level: 0.5).textureScale, 1);
    });

    test('shadows scale down and disappear', () {
      const s = [BoxShadow(blurRadius: 20, offset: Offset(0, 4))];
      expect(scaleShadows(s, const GraphicsQuality(shadowLevel: 3)), same(s));
      expect(
        scaleShadows(
          s,
          const GraphicsQuality(shadowLevel: 2),
        )!.first.blurRadius,
        12,
      );
      expect(
        scaleShadows(
          s,
          const GraphicsQuality(shadowLevel: 1),
        )!.first.blurRadius,
        5,
      );
      expect(scaleShadows(s, const GraphicsQuality(shadowLevel: 0)), isNull);
    });
  });

  group('decor clock', () {
    testWidgets('advances at its own rate, not the display rate', (
      tester,
    ) async {
      final clock = DecorClock.instance;
      clock.configure(mediumFps: 30, lowFps: 10, yieldToInput: false);
      var medium = 0, low = 0;
      void m() => medium++;
      void l() => low++;
      clock.medium.addListener(m);
      clock.low.addListener(l);
      // One second of a 120 Hz display.
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(microseconds: 8333));
      }
      clock.medium.removeListener(m);
      clock.low.removeListener(l);
      expect(medium, inInclusiveRange(25, 34));
      expect(low, inInclusiveRange(8, 12));
      // Nobody listening: no more updates, no frames requested.
      final before = medium;
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(medium, before);
    });

    testWidgets('steps aside while someone is touching the screen', (
      tester,
    ) async {
      InteractionTracker.instance.install();
      final clock = DecorClock.instance;
      clock.configure(mediumFps: 60, lowFps: 30);
      var medium = 0, low = 0;
      void m() => medium++;
      void l() => low++;
      clock.medium.addListener(m);
      clock.low.addListener(l);
      await tester.pumpWidget(const SizedBox.expand());
      final g = await tester.startGesture(const Offset(10, 10));
      await tester.pump(const Duration(milliseconds: 16));
      medium = 0;
      low = 0;
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      clock.medium.removeListener(m);
      clock.low.removeListener(l);
      // Ambient (low priority) holds still; living decorations drop to at
      // most 30 fps so the interface keeps its frame budget.
      expect(low, 0);
      expect(medium, lessThanOrEqualTo(34));
      clock.configure(mediumFps: 30, lowFps: 20);
    });
  });
}
