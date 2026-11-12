import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/domain/models/contact.dart';
import 'package:prism_plurality/features/contacts/utils/birthday_date.dart';
import 'package:prism_plurality/features/contacts/utils/birthday_json_parser.dart';
import 'package:prism_plurality/features/contacts/utils/contact_import.dart';
import 'package:prism_plurality/features/contacts/utils/vcard_parser.dart';

void main() {
  group('birthday JSON', () {
    test('reads a top-level list with varied field names and formats', () {
      final r = parseBirthdayJson('''[
        {"name": "Ana", "birthday": "1990-04-02"},
        {"fullName": "Ben", "dob": "12/25/1985"},
        {"firstName": "Cara", "lastName": "Diaz", "date": "--07-14"},
        {"displayName": "Dee", "birthDate": "April 2, 1991"},
        {"title": "Eli", "day": 3, "month": "Mar", "year": 2001},
        {"name": "Fay", "bday": 638323200000},
        {"name": "Gus", "date": "2.4.1990"}
      ]''');
      expect(r.fatalError, isNull);
      final b = {for (final x in r.records) x.name: x.birthday};
      expect(b['Ana'], const BirthdayDate(4, 2, 1990));
      expect(b['Ben'], const BirthdayDate(12, 25, 1985));
      expect(b['Cara Diaz'], const BirthdayDate(7, 14));
      expect(b['Dee'], const BirthdayDate(4, 2, 1991));
      expect(b['Eli'], const BirthdayDate(3, 3, 2001));
      expect(b['Fay']!.year, 1990);
      expect(b['Gus'], const BirthdayDate(4, 2, 1990)); // dotted = day first
      expect(r.records.every((x) => x.isValid), isTrue);
    });

    test('finds records nested under a key and in sub-objects', () {
      final r = parseBirthdayJson(
        '{"version":2,"data":[{"person":{"name":"Hal"},"event_date":"2000-01-31"}]}',
      );
      expect(r.records.single.name, 'Hal');
      expect(r.records.single.birthday, const BirthdayDate(1, 31, 2000));
    });

    test('flags ambiguous dates and respects the chosen order', () {
      const json = '[{"name":"Ivy","birthday":"03/04/1995"}]';
      final m = parseBirthdayJson(json);
      expect(m.records.single.ambiguous, isTrue);
      expect(m.records.single.birthday, const BirthdayDate(3, 4, 1995));
      final d = parseBirthdayJson(json, order: DateOrder.dayFirst);
      expect(d.records.single.birthday, const BirthdayDate(4, 3, 1995));
      expect(m.ambiguousCount, 1);
    });

    test('reports invalid entries without failing the rest', () {
      final r = parseBirthdayJson('''[
        {"name": "Jo", "birthday": "1990-02-30"},
        {"birthday": "1990-01-01"},
        {"name": "Kit"},
        {"name": "Lu", "birthday": "sometime"},
        "nope",
        {"name": "Mo", "birthday": "2024-02-29"}
      ]''');
      expect(r.records.map((x) => x.error), [
        'invalid_date',
        'missing_name',
        'missing_date',
        'unreadable_date',
        'not_an_object',
        null,
      ]);
    });

    test('fatal errors for non-JSON and empty files', () {
      expect(parseBirthdayJson('not json').fatalError, 'not_json');
      expect(parseBirthdayJson('{"a": 1}').fatalError, 'no_records');
    });
  });

  group('BirthdayDate', () {
    test('storage round-trip, year-less sentinel and recurrence', () {
      expect(const BirthdayDate(4, 2).toStorage(), '0004-04-02');
      expect(BirthdayDate.fromStorage('0004-04-02'), const BirthdayDate(4, 2));
      expect(
        BirthdayDate.fromStorage('1990-04-02'),
        const BirthdayDate(4, 2, 1990),
      );
      const leap = BirthdayDate(2, 29, 2000);
      expect(leap.nextOccurrence(DateTime(2025, 1, 10)), DateTime(2025, 2, 28));
      expect(leap.nextOccurrence(DateTime(2028, 1, 10)), DateTime(2028, 2, 29));
      expect(
        const BirthdayDate(1, 5).nextOccurrence(DateTime(2026, 3, 1)),
        DateTime(2027, 1, 5),
      );
      expect(const BirthdayDate(4, 2, 1990).ageOn(DateTime(2026, 4, 2)), 36);
      expect(const BirthdayDate(2, 30).isValid, isFalse);
    });
  });

  test('vCard parsing handles folding, groups and BDAY formats', () {
    final cards = parseVCards(
      'BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Nia\r\n  Okafor\r\nN:Okafor;Nia;;;\r\n'
      'item1.TEL;TYPE=CELL:+1 555 0100\r\nEMAIL;TYPE=HOME:nia@example.com\r\n'
      'BDAY:1992-11-03\r\nUID:abc-1\r\nNOTE:Met at uni\\, 2010\r\nEND:VCARD\r\n'
      'BEGIN:VCARD\nVERSION:4.0\nN:Park;Oli;;;\nBDAY:--0612\nEND:VCARD\n',
    );
    expect(cards, hasLength(2));
    expect(cards[0].name, 'Nia Okafor');
    expect(cards[0].phones, ['+1 555 0100']);
    expect(cards[0].emails, ['nia@example.com']);
    expect(cards[0].birthday, const BirthdayDate(11, 3, 1992));
    expect(cards[0].uid, 'abc-1');
    expect(cards[0].note, 'Met at uni, 2010');
    expect(cards[1].name, 'Oli Park');
    expect(cards[1].birthday, const BirthdayDate(6, 12));
  });

  test('duplicate detection by id, phone, email, name and within file', () {
    final now = DateTime(2026);
    final existing = [
      Contact(
        id: '1',
        displayName: 'Pat Lee',
        birthday: '1990-05-01',
        createdAt: now,
        modifiedAt: now,
      ),
      Contact(
        id: '2',
        displayName: 'Q',
        phones: ['(555) 010-2000'],
        createdAt: now,
        modifiedAt: now,
      ),
      Contact(
        id: '3',
        displayName: 'R',
        emails: ['r@x.com'],
        source: 'device',
        externalId: 'dev9',
        createdAt: now,
        modifiedAt: now,
      ),
    ];
    final cands = [
      const ContactCandidate(
        key: 'a',
        displayName: 'pat  LEE',
        birthday: BirthdayDate(6, 1),
        source: 'birthday_import',
      ),
      const ContactCandidate(
        key: 'b',
        displayName: 'Quinn',
        phones: ['555-010-2000'],
        source: 'vcard',
      ),
      const ContactCandidate(
        key: 'c',
        displayName: 'Robin',
        emails: ['R@X.com'],
        source: 'vcard',
      ),
      const ContactCandidate(
        key: 'd',
        displayName: 'Other',
        externalId: 'dev9',
        source: 'device',
      ),
      const ContactCandidate(key: 'e', displayName: 'Sam', source: 'vcard'),
      const ContactCandidate(key: 'f', displayName: 'sam', source: 'vcard'),
      const ContactCandidate(
        key: 'g',
        displayName: null,
        source: 'vcard',
        error: 'missing_name',
      ),
    ];
    final dups = findContactDuplicates(cands, existing);
    final byKey = {for (final d in dups) d.candidate.key: d};
    expect(byKey['a']!.existing!.id, '1');
    expect(byKey['a']!.conflictingBirthday, isTrue);
    expect(byKey['b']!.existing!.id, '2');
    expect(byKey['c']!.existing!.id, '3');
    expect(byKey['d']!.existing!.id, '3');
    expect(byKey.containsKey('e'), isFalse);
    expect(byKey['f']!.sameFileAs, 'e');
    expect(byKey.containsKey('g'), isFalse);

    final merged = mergeContact(existing[1], cands[1], now);
    expect(merged.phones, ['(555) 010-2000', '555-010-2000']);
  });
}
