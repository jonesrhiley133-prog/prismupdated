import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/features/seasonal/seasonal_catalog.dart';

void main() {
  test('every requested holiday and season exists', () {
    final names = seasonalCollections.map((c) => c.name).toSet();
    for (final n in [
      'Christmas',
      'Halloween',
      'Thanksgiving',
      "New Year's Eve",
      "New Year's Day",
      "Valentine's Day",
      'Easter',
      'Lunar New Year',
      'Mid-Autumn Festival',
      'Chuseok',
      'Seollal',
      'Diwali',
      'Holi',
      'Ramadan',
      'Eid al-Fitr',
      'Eid al-Adha',
      'Hanukkah',
      'Kwanzaa',
      'Día de los Muertos',
      'Mardi Gras',
      'Carnival',
      "St. Patrick's Day",
      'Pride Month',
      "Children's Day",
      'Earth Day',
      'Cherry Blossom Season',
      'Spring',
      'Summer',
      'Autumn',
      'Winter',
      'Rainy Season',
      'Monsoon Season',
    ]) {
      expect(names, contains(n));
    }
    expect(seasonalCollections.length, 32);
  });

  test('every collection has at least 25 looks, each with its own name', () {
    for (final c in seasonalCollections) {
      expect(c.variations.length, greaterThanOrEqualTo(25), reason: c.name);
      expect(
        c.variations.map((v) => v.name).toSet().length,
        c.variations.length,
        reason: '${c.name} repeats a look name',
      );
    }
  });

  test('looks within a collection are genuinely different, not recolours', () {
    for (final c in seasonalCollections) {
      final sigs = <String>{};
      final palettes = <String>{};
      for (final v in c.variations) {
        expect(
          sigs.add(v.signature),
          isTrue,
          reason: '${c.name}/${v.name} duplicates another look',
        );
        expect(
          palettes.add(v.palette.id),
          isTrue,
          reason: '${c.name}/${v.name} reuses palette ${v.palette.id}',
        );
      }
    }
  });

  test('look ids are unique across the whole catalogue and resolve', () {
    final ids = <String>{};
    for (final c in seasonalCollections) {
      for (final v in c.variations) {
        expect(ids.add(v.id), isTrue);
        expect(variationById(v.id)?.name, v.name);
      }
    }
    expect(variationById('nope.1'), isNull);
  });

  test('christmas and halloween use the requested looks, in order', () {
    expect(
      collectionById('christmas')!.variations.map((v) => v.name).toList(),
      [
        'Classic Christmas',
        'Cozy Cabin',
        'Snowy Village',
        'Candy Cane Wonderland',
        'Gingerbread Bakery',
        'Victorian Christmas',
        'Pastel Christmas',
        'Gothic Christmas',
        'Golden Christmas',
        'Scandinavian Winter',
        'Christmas Market',
        'Woodland Christmas',
        'Christmas Cottage',
        'Midnight Christmas',
        'Celestial Christmas',
        'Retro Christmas',
        'Kawaii Christmas',
        'Knitted Christmas',
        'Frosted Windows',
        'Nutcracker Christmas',
        'Peppermint Café',
        'Christmas Toy Workshop',
        'Elegant Silver Christmas',
        'Minimalist Christmas',
        'Tropical Christmas',
      ],
    );
    expect(
      collectionById('halloween')!.variations.map((v) => v.name).toList(),
      [
        'Classic Halloween',
        'Haunted Mansion',
        'Pumpkin Patch',
        'Cozy Witch Cottage',
        'Pastel Halloween',
        'Gothic Victorian',
        'Cute Ghosts',
        'Black Cat Café',
        'Autumn Cemetery',
        'Enchanted Forest',
        'Spooky Carnival',
        'Retro Halloween',
        'Candy Corn',
        'Moonlit Night',
        'Vampire Castle',
        'Haunted Library',
        'Mushroom Witch',
        'Pumpkin Bakery',
        'Purple Magic',
        'Skeleton Parade',
        'Ghost Town',
        'Kawaii Monsters',
        'Midnight Garden',
        'Halloween Village',
        'Minimalist Spooky',
      ],
    );
  });

  test(
    'cultural and religious collections explain themselves respectfully',
    () {
      for (final id in [
        'lunarnewyear',
        'midautumn',
        'chuseok',
        'seollal',
        'diwali',
        'holi',
        'ramadan',
        'eidfitr',
        'eidadha',
        'hanukkah',
        'kwanzaa',
        'diademuertos',
      ]) {
        final c = collectionById(id)!;
        expect(c.note, isNotNull, reason: id);
        expect(c.blurb.isNotEmpty, isTrue);
        expect(c.greetings, isNotEmpty);
      }
      // Distinct traditions are not merged into a generic festival pack.
      expect(
        collectionById('chuseok')!.blurb,
        isNot(collectionById('midautumn')!.blurb),
      );
      expect(
        collectionById('seollal')!.blurb,
        isNot(collectionById('lunarnewyear')!.blurb),
      );
    },
  );

  test('lunar and observational holidays are marked approximate', () {
    for (final id in [
      'lunarnewyear',
      'ramadan',
      'eidfitr',
      'eidadha',
      'diwali',
    ]) {
      expect(collectionById(id)!.approximateDates, isTrue, reason: id);
    }
    expect(collectionById('christmas')!.approximateDates, isFalse);
  });

  test('every collection has greetings in English and Spanish', () {
    for (final c in seasonalCollections) {
      expect(c.greetings.length, greaterThanOrEqualTo(2), reason: c.name);
      expect(c.greetingsEs, isNotEmpty, reason: c.name);
    }
  });
}
