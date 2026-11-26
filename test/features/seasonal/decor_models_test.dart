import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/features/seasonal/decor_models.dart';
import 'package:prism_plurality/features/seasonal/seasonal_calendar.dart';
import 'package:prism_plurality/features/seasonal/seasonal_catalog.dart';

DateTime d(int y, int m, int day) => DateTime(y, m, day);

SeasonalPrefs on({
  Set<String> celebrated = const {},
  bool auto = false,
  DecoPerformance mode = DecoPerformance.balanced,
}) => SeasonalPrefs(
  performance: mode,
  celebrated: celebrated,
  autoSchedule: auto,
);

void main() {
  group('opt-in scheduling', () {
    test(
      'nothing is ever active until the person turns Seasonal Living on',
      () {
        expect(
          resolveActiveSeason(d(2026, 12, 20), const SeasonalPrefs()),
          isNull,
        );
        expect(
          resolveActiveSeason(
            d(2026, 12, 20),
            on(
              celebrated: {'christmas'},
              auto: true,
              mode: DecoPerformance.off,
            ),
          ),
          isNull,
        );
      },
    );

    test(
      'automatic scheduling is off by default, even for a celebrated holiday',
      () {
        expect(
          resolveActiveSeason(d(2026, 12, 20), on(celebrated: {'christmas'})),
          isNull,
        );
      },
    );

    test(
      'with scheduling on, a celebrated holiday shows only inside its window',
      () {
        final p = on(celebrated: {'christmas'}, auto: true);
        expect(
          resolveActiveSeason(d(2026, 12, 20), p)?.variation?.collectionId,
          'christmas',
        );
        expect(
          resolveActiveSeason(d(2026, 12, 20), p)?.reason,
          ActiveReason.scheduled,
        );
        expect(resolveActiveSeason(d(2026, 7, 4), p), isNull);
      },
    );

    test('holidays you do not celebrate, or hid, never show', () {
      expect(
        resolveActiveSeason(
          d(2026, 10, 25),
          on(celebrated: {'christmas'}, auto: true),
        ),
        isNull,
      );
      final hidden = on(
        celebrated: {'halloween'},
        auto: true,
      ).copyWith(hidden: {'halloween'});
      expect(resolveActiveSeason(d(2026, 10, 25), hidden), isNull);
    });

    test('extending a collection keeps it going after the holiday', () {
      final p = on(
        celebrated: {'christmas'},
        auto: true,
      ).copyWith(extendDays: {'christmas': 10});
      expect(
        resolveActiveSeason(d(2026, 12, 30), p)?.variation?.collectionId,
        'christmas',
      );
      expect(resolveActiveSeason(d(2027, 1, 10), p), isNull);
    });

    test('custom dates override the calendar', () {
      final p = on(
        celebrated: {'christmas'},
        auto: true,
      ).copyWith(customDates: {'christmas': '2026-11-01/2026-11-05'});
      expect(
        resolveActiveSeason(d(2026, 11, 3), p)?.variation?.collectionId,
        'christmas',
      );
      expect(resolveActiveSeason(d(2026, 12, 20), p), isNull);
    });

    test('a holiday beats a long season when both apply', () {
      final p = on(
        celebrated: {'winter', 'christmas'},
        auto: true,
        mode: DecoPerformance.immersive,
      );
      expect(
        resolveActiveSeason(d(2026, 12, 20), p)?.variation?.collectionId,
        'christmas',
      );
      expect(
        resolveActiveSeason(d(2027, 1, 20), p)?.variation?.collectionId,
        'winter',
      );
    });

    test('the chosen look for a collection is used', () {
      final p = on(
        celebrated: {'christmas'},
        auto: true,
      ).copyWith(variationFor: {'christmas': 'christmas.7'});
      expect(
        resolveActiveSeason(d(2026, 12, 10), p)?.variation?.name,
        'Gothic Christmas',
      );
    });

    test('the southern hemisphere gets winter in July', () {
      final p = on(
        celebrated: {'winter'},
        auto: true,
      ).copyWith(hemisphere: Hemisphere.south);
      expect(
        resolveActiveSeason(d(2026, 7, 10), p)?.variation?.collectionId,
        'winter',
      );
      expect(resolveActiveSeason(d(2026, 12, 20), p), isNull);
    });
  });

  group('manual, permanent and custom celebrations', () {
    test('a look switched on by hand shows without any schedule', () {
      final p = on().copyWith(manualVariation: 'halloween.1');
      final a = resolveActiveSeason(d(2026, 3, 3), p)!;
      expect(a.reason, ActiveReason.manual);
      expect(a.variation!.name, 'Haunted Mansion');
    });

    test('a manual look can end on a date', () {
      final p = on().copyWith(
        manualVariation: 'halloween.1',
        manualUntil: d(2026, 3, 5),
      );
      expect(resolveActiveSeason(d(2026, 3, 5), p), isNotNull);
      expect(resolveActiveSeason(d(2026, 3, 6), p), isNull);
    });

    test('a favourite look can stay on all year', () {
      final p = on().copyWith(permanentVariation: 'autumn.0');
      expect(
        resolveActiveSeason(d(2026, 5, 5), p)?.reason,
        ActiveReason.permanent,
      );
    });

    test(
      'a manual look wins over a schedule; the schedule resumes when it ends',
      () {
        final p = on(
          celebrated: {'christmas'},
          auto: true,
        ).copyWith(manualVariation: 'halloween.0', manualUntil: d(2026, 12, 5));
        expect(
          resolveActiveSeason(d(2026, 12, 3), p)?.variation?.collectionId,
          'halloween',
        );
        expect(
          resolveActiveSeason(d(2026, 12, 20), p)?.variation?.collectionId,
          'christmas',
        );
      },
    );

    test(
      'a custom celebration appears around its date and works without scheduling',
      () {
        final c = CustomCelebration(
          id: 'a',
          name: 'System anniversary',
          month: 5,
          day: 9,
          leadDays: 2,
          extendDays: 1,
          variationId: 'spring.3',
        );
        final p = on().copyWith(celebrations: [c]);
        expect(
          resolveActiveSeason(d(2026, 5, 8), p)?.celebration?.name,
          'System anniversary',
        );
        expect(
          resolveActiveSeason(d(2026, 5, 10), p)?.variation?.name,
          'Soft Pastel Morning',
        );
        expect(resolveActiveSeason(d(2026, 5, 20), p), isNull);
      },
    );

    test('a one-off celebration only happens in its year', () {
      final c = CustomCelebration(
        id: 'g',
        name: 'Graduation',
        month: 6,
        day: 12,
        year: 2026,
        yearly: false,
      );
      final p = on().copyWith(celebrations: [c]);
      expect(resolveActiveSeason(d(2026, 6, 12), p), isNotNull);
      expect(resolveActiveSeason(d(2027, 6, 12), p), isNull);
    });

    test('Feb 29 celebrations do not crash in other years', () {
      final c = CustomCelebration(id: 'l', name: 'Leap', month: 2, day: 29);
      expect(c.rangeIn(2026), isNull);
      expect(c.rangeIn(2028), isNotNull);
      expect(
        () => resolveActiveSeason(
          d(2026, 3, 1),
          on().copyWith(celebrations: [c]),
        ),
        returnsNormally,
      );
    });
  });

  group('saving', () {
    test('preferences round-trip, including every choice', () {
      final p = on(celebrated: {'christmas', 'diwali'}, auto: true).copyWith(
        region: SeasonalRegion.southAsia,
        hemisphere: Hemisphere.north,
        hidden: {'halloween'},
        manualVariation: 'spring.2',
        manualUntil: d(2027, 1, 1),
        permanentVariation: 'autumn.4',
        variationFor: {'christmas': 'christmas.2'},
        extendDays: {'christmas': 5},
        customDates: {'diwali': '2026-11-01/2026-11-10'},
        celebrations: [
          CustomCelebration(
            id: 'a',
            name: 'Mine',
            month: 1,
            day: 2,
            greeting: 'Hi',
          ),
        ],
        alterPresets: {'m1': 'p1'},
        activePresetId: 'p9',
        reducedMotion: true,
        audioOn: true,
        audioId: 'fire',
        audioVolume: 0.2,
        integrations: {'home': false},
      );
      final back = SeasonalPrefs.fromJson(p.toJson());
      expect(back.toJson(), p.toJson());
      expect(back.integrationOn('home'), isFalse);
      expect(back.integrationOn('calendar'), isTrue);
    });

    test('default preferences are off and quiet', () {
      const p = SeasonalPrefs();
      expect(p.performance, DecoPerformance.off);
      expect(p.autoSchedule, isFalse);
      expect(p.audioOn, isFalse);
    });

    test('garbage saved data falls back to safe defaults', () {
      final p = SeasonalPrefs.fromJson({
        'pf': 'nope',
        'av': 99,
        'cb': [
          'x',
          {'m': 'q'},
        ],
        'ex': {'a': -5, 'b': 'z'},
      });
      expect(p.performance, DecoPerformance.off);
      expect(p.audioVolume, 1.0);
      expect(p.celebrations, isEmpty);
      expect(p.extendDays['a'], 0);
      expect(SeasonalPrefs.fromJson('nope').performance, DecoPerformance.off);
    });

    test('decor items round-trip with device tweaks and pages', () {
      final i = DecorItem(
        id: 'a',
        kind: DecoKind.ornament,
        variationId: 'christmas.0',
        glyph: '🔔',
        anchor: DecoAnchor.profilePicture,
        x: 0.3,
        y: 0.7,
        w: 0.1,
        rot: 12,
        opacity: 0.8,
        color: 0xFF112233,
        flipX: true,
        z: 4,
        locked: true,
        group: 'g1',
        speed: 1.5,
        frequency: 0.5,
        enabled: false,
        pages: ['/home', '/calendar'],
        tweaks: {
          'mobile': const DeviceTweak(dx: 0.1, scale: 0.8),
          'desktop': const DeviceTweak(hidden: true),
        },
      );
      final back = DecorItem.fromJson(i.toJson())!;
      expect(back.toJson(), i.toJson());
      expect(back.tweakFor(DeviceClass.mobile).scale, 0.8);
      expect(back.tweakFor(DeviceClass.desktop).hidden, isTrue);
      expect(back.tweakFor(DeviceClass.tablet).isDefault, isTrue);
    });

    test('presets round-trip', () {
      final p = DecorPreset(
        id: 'p',
        name: 'Cozy',
        description: 'Warm',
        category: 'Winter',
        items: [DecorItem(id: 'a', kind: DecoKind.garland)],
        thumbnail: 'AAAA',
        pages: ['/home'],
      );
      final back = DecorPreset.fromJson(p.toJson())!;
      expect(back.toJson(), p.toJson());
      expect(DecorPreset.fromJson('nope'), isNull);
    });

    test('unknown decoration kinds are skipped, not fatal', () {
      expect(DecorItem.fromJson({'id': 'a', 'k': 'martian'}), isNull);
      final p = DecorPreset.fromJson({
        'id': 'p',
        'it': [
          {'id': 'a', 'k': 'martian'},
          {'id': 'b', 'k': 'garland'},
        ],
      })!;
      expect(p.items.length, 1);
    });
  });

  group('showing decorations', () {
    test('pages: empty means everywhere; otherwise only the chosen pages', () {
      final all = DecorItem(id: 'a', kind: DecoKind.garland);
      final some = DecorItem(
        id: 'b',
        kind: DecoKind.garland,
        pages: ['/home', '/calendar'],
      );
      expect(all.showsOn('/anything'), isTrue);
      expect(some.showsOn('/home'), isTrue);
      expect(some.showsOn('/calendar/2026'), isTrue);
      expect(some.showsOn('/journal'), isFalse);
      expect(some.showsOn('/homework'), isFalse);
    });

    test('device classes follow screen width', () {
      expect(deviceClassFor(390), DeviceClass.mobile);
      expect(deviceClassFor(768), DeviceClass.tablet);
      expect(deviceClassFor(1440), DeviceClass.desktop);
    });

    test('performance modes cap what runs', () {
      const base = DecoLayerSettings();
      expect(base.forMode(DecoPerformance.off).enabled, isEmpty);
      final min = base.forMode(DecoPerformance.minimal);
      expect(min.on(DecoLayer.staticDeco), isTrue);
      expect(min.on(DecoLayer.animated), isFalse);
      expect(min.on(DecoLayer.ambient), isFalse);
      expect(min.particleDensity, 0);
      final bal = base.forMode(DecoPerformance.balanced);
      expect(bal.on(DecoLayer.animated), isTrue);
      expect(bal.on(DecoLayer.interactive), isFalse);
      expect(
        base.forMode(DecoPerformance.immersive).on(DecoLayer.interactive),
        isTrue,
      );
      final custom = const DecoLayerSettings(
        enabled: {DecoLayer.ambient},
        particleDensity: 0.2,
      );
      expect(custom.forMode(DecoPerformance.custom).enabled, {
        DecoLayer.ambient,
      });
    });

    test('every look makes a complete starting arrangement', () {
      for (final c in seasonalCollections) {
        for (final v in c.variations) {
          final items = arrangementForVariation(v);
          expect(
            items.any((i) => i.kind == DecoKind.garland),
            isTrue,
            reason: v.id,
          );
          expect(
            items.map((i) => i.id).toSet().length,
            items.length,
            reason: v.id,
          );
          expect(items.every((i) => i.variationId == v.id), isTrue);
        }
      }
    });

    test(
      'looks from different collections can be mixed in one arrangement',
      () {
        final a = arrangementForVariation(variationById('christmas.0')!);
        final b = arrangementForVariation(variationById('autumn.0')!);
        final mixed = [
          ...a.where((i) => i.kind == DecoKind.fairyLights),
          ...b.where((i) => i.kind == DecoKind.particles),
        ];
        expect(mixed.map((i) => i.variationId).toSet(), {
          'christmas.0',
          'autumn.0',
        });
      },
    );
  });
}
