import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/astro/content/ask.dart';
import 'package:prism_plurality/features/astro/content/compat.dart';
import 'package:prism_plurality/features/astro/content/horoscope.dart';
import 'package:prism_plurality/features/astro/content/interpret.dart';
import 'package:prism_plurality/features/astro/content/tarot.dart';
import 'package:prism_plurality/features/astro/content/zodiac.dart';
import 'package:prism_plurality/features/astro/data/astro_model.dart';
import 'package:prism_plurality/features/astro/engine/chart.dart';
import 'package:prism_plurality/features/astro/engine/ephemeris.dart';

void main() {
  final london = const BirthPlace(
    name: 'London',
    lat: 51.507,
    lon: -0.128,
    timeZone: 'Europe/London',
  );
  final full = AstroSubject(
    name: 'Bonnie',
    sunSign: 10,
    chart: NatalChart.of(
      BirthData(
        year: 1994,
        month: 2,
        day: 3,
        hour: 14,
        minute: 20,
        place: london,
      ),
    ),
  );
  final yearOnly = AstroSubject(
    name: 'Justin',
    sunSign: 6,
    chart: NatalChart.of(const BirthData(year: 1988, month: 10, day: 12)),
  );

  test('daily readings for every sign, both languages', () {
    for (final es in [false, true]) {
      for (var s = 0; s < 12; s++) {
        final r = dailyReading(
          AstroSubject(name: 'X', sunSign: s, seed: s),
          DateTime(2026, 11, 23),
          es,
        );
        expect(r.parts.length, ReadingPart.values.length);
        expect(r.parts.values.every((p) => p.trim().isNotEmpty), isTrue);
        expect(r.scores.values.every((v) => v >= 12 && v <= 96), isTrue);
        expect(r.moonHouse, inInclusiveRange(1, 12));
      }
      final f = dailyReading(full, DateTime(2026, 11, 23), es);
      expect(f.title, isNotEmpty);
    }
  });

  test('weekly, monthly and yearly readings', () {
    final w = weeklyReading(full, DateTime(2026, 11, 23), false);
    expect(w.days.length, 7);
    final m = monthlyReading(full, DateTime(2026, 11), false);
    expect(m.events.any((e) => e.kind == SkyEventKind.lunation), isTrue);
    expect(m.areas.length, 4);
    final y = yearlyReading(full, 2026, false);
    expect(y.themes.length, 3);
    expect(y.events.any((e) => e.kind == SkyEventKind.eclipse), isTrue);
    // Solar return lands near the birthday.
    expect(y.birthday!.month, 2);
    expect(y.birthday!.day, inInclusiveRange(2, 4));
  });

  test('placement readings cover every facet', () {
    for (final b in Body.values) {
      for (var s = 0; s < 12; s++) {
        final r = readBody(b, s, s.isEven, house: s + 1);
        expect(r.facets.length, Facet.values.length);
        expect(r.inHouse, isNotNull);
      }
    }
    expect(chartSummary(full.chart!, 'Bonnie', false), contains('Aquarius'));
  });

  test('tarot: 78 unique cards; daily card is stable per alter and day', () {
    expect(fullDeck.length, 78);
    expect(fullDeck.map((c) => c.id).toSet().length, 78);
    final a = dailyCard('alter-a', DateTime(2026, 11, 23, 8));
    final b = dailyCard('alter-a', DateTime(2026, 11, 23, 22));
    expect(a.card.id, b.card.id);
    final days = {
      for (var d = 1; d <= 20; d++)
        dailyCard('alter-a', DateTime(2026, 11, d)).card.id,
    };
    expect(days.length, greaterThan(10));
    for (final c in fullDeck) {
      expect(c.meaningOf(false, false), isNotEmpty);
      expect(c.meaningOf(true, true), isNotEmpty);
      expect(c.loveOf(false, false), isNotEmpty);
    }
    expect(drawCards(6).map((d) => d.card.id).toSet().length, 6);
  });

  test('compatibility uses words, never percentages', () {
    final r = compareCharts(full, yearOnly, false);
    expect(r.advanced, isTrue);
    expect(r.areas.length, CompatArea.values.length);
    final all = [
      r.headline,
      r.summary,
      for (final a in r.areas.values) a.$2,
    ].join(' ');
    expect(all.contains('%'), isFalse);
    final basic = compareCharts(
      AstroSubject(name: 'A', sunSign: 0),
      AstroSubject(name: 'B', sunSign: 4),
      true,
    );
    expect(basic.advanced, isFalse);
    expect(basic.areas[CompatArea.moon]!.$1, CompatTone.unknown);
  });

  test(
    'Ask Astro answers from the chart and never guesses the rising sign',
    () {
      expect(
        askAstro('What does my Moon sign represent?', full, false).text,
        contains('Moon in'),
      );
      expect(
        askAstro('What does Venus in Libra mean?', null, false).text,
        contains('Venus in Libra'),
      );
      expect(
        askAstro('¿Qué significa Venus en Libra?', null, true).text,
        contains('Venus en Libra'),
      );
      expect(
        askAstro('What is my rising sign?', yearOnly, false).text,
        contains('birth time'),
      );
      expect(
        askAstro('What is the 7th house?', null, false).text,
        contains('partnership'),
      );
      expect(
        askAstro(
          'Compare my chart with Justin',
          full,
          false,
          others: {'Justin': yearOnly},
        ).text,
        contains('dynamic'),
      );
      expect(askAstro('blah', full, false).suggestions, isNotEmpty);
    },
  );

  group('privacy', () {
    Member member(String id, {String? birthday}) =>
        Member(id: id, name: id, createdAt: DateTime(2020), birthday: birthday);
    AstroAccess access(
      Member m,
      AstroVisibility v,
      Set<String> viewers, {
      bool hasRecord = true,
    }) => AstroAccess(
      member: m,
      profile: AstroProfile(
        memberId: m.id,
        visibility: v,
        record: hasRecord
            ? TrackerRecord(
                id: 'r',
                kind: 'astro.profile',
                memberId: m.id,
                createdAt: DateTime(2020),
                modifiedAt: DateTime(2020),
              )
            : null,
      ),
      birth: m.birthday == null
          ? null
          : AstroProfile(memberId: m.id).birthData(m),
      viewers: viewers,
      preferDisplay: false,
    );

    test('private by default; visible only to the alter while fronting', () {
      final m = member('a', birthday: '1994-02-03');
      expect(AstroProfile(memberId: 'a').visibility, AstroVisibility.private);
      expect(access(m, AstroVisibility.private, {}).canView, isFalse);
      expect(access(m, AstroVisibility.private, {'b'}).canView, isFalse);
      expect(access(m, AstroVisibility.private, {'a'}).canView, isTrue);
      // A birthday alone (no Astro profile yet) is still private.
      expect(
        access(m, AstroVisibility.private, {}, hasRecord: false).canView,
        isFalse,
      );
    });

    test('system and shareable are visible; hidden is never listed', () {
      final m = member('a', birthday: '1994-02-03');
      expect(access(m, AstroVisibility.system, {}).listed, isTrue);
      expect(access(m, AstroVisibility.shareable, {}).listed, isTrue);
      expect(access(m, AstroVisibility.hidden, {'a'}).canView, isTrue);
      expect(access(m, AstroVisibility.hidden, {'a'}).listed, isFalse);
      expect(access(m, AstroVisibility.hidden, {}).canView, isFalse);
    });

    test('nothing entered yet: nothing to hide', () {
      final empty = access(
        member('c'),
        AstroVisibility.private,
        {},
        hasRecord: false,
      );
      expect(empty.isEmpty, isTrue);
      expect(empty.canView, isTrue);
      expect(empty.listed, isFalse);
    });

    test(
      'a hidden birth year stays out of the profile but feeds the chart',
      () {
        final m = member('a', birthday: '0004-02-03');
        final p = const AstroProfile(memberId: 'a', year: 1994);
        final b = p.birthData(m)!;
        expect(b.year, 1994);
        expect(b.month, 2);
        expect(
          const AstroProfile(memberId: 'a').birthData(m)!.hasYear,
          isFalse,
        );
      },
    );
  });

  test('every sign has text for every facet in both languages', () {
    for (final s in signs) {
      expect(s.facets.length, Facet.values.length);
      for (final f in s.facets.values) {
        expect(f.en, isNotEmpty);
        expect(f.es, isNotEmpty);
      }
    }
  });
}
