import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/domain/models/contact.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/calendar/providers/calendar_providers.dart';
import 'package:prism_plurality/features/chat/providers/chat_providers.dart';
import 'package:prism_plurality/features/companions/companion_screens.dart'
    show memberNamesProvider;
import 'package:prism_plurality/features/contacts/contact_extras.dart';
import 'package:prism_plurality/features/contacts/providers/contact_providers.dart';
import 'package:prism_plurality/features/contacts/views/contact_profile_screen.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';

final _now = DateTime(2026, 11, 20);

Contact _contact({
  List<String> phones = const [],
  List<String> emails = const [],
  String? birthday,
  String? notes,
}) => Contact(
  id: 'c1',
  displayName: 'Riley Park',
  phones: phones,
  emails: emails,
  birthday: birthday,
  notes: notes,
  createdAt: _now,
  modifiedAt: _now,
);

TrackerRecord _extrasRecord(ContactExtras e) => TrackerRecord(
  id: 'x1',
  kind: TrackerKind.contactProfile,
  title: 'p',
  createdAt: _now,
  modifiedAt: _now,
).withFields(e.toJson());

Future<void> _pump(
  WidgetTester tester,
  Contact c, {
  ContactExtras? extras,
  Size size = const Size(420, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        contactsProvider.overrideWith((ref) => Stream.value([c])),
        trackerKindProvider(TrackerKind.contactProfile).overrideWith(
          (ref) => AsyncValue.data(<TrackerRecord>[
            if (extras != null) _extrasRecord(extras),
          ]),
        ),
        trackerKindProvider(
          TrackerKind.journalEntry,
        ).overrideWith((ref) => const AsyncValue.data(<TrackerRecord>[])),
        trackerKindProvider(
          TrackerKind.scrapPage,
        ).overrideWith((ref) => const AsyncValue.data(<TrackerRecord>[])),
        calendarEventsProvider.overrideWith((ref) => Stream.value(const [])),
        conversationsProvider.overrideWith((ref) => Stream.value(const [])),
        memberNamesProvider.overrideWithValue({'m1': 'Sam', 'm2': 'Noor'}),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ContactProfileScreen(contactId: 'c1'),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  test('extras round-trip through JSON, including private fields', () {
    final e = const ContactExtras(contactId: 'c1').copyWith(
      nickname: 'Ri',
      pronouns: 'she/her',
      relationship: 'Sister',
      status: 'Moving soon',
      accent: 0xFF336699,
      phoneLabels: {'555': 'Mobile'},
      socials: [
        {'label': 'Site', 'url': 'https://example.com'},
      ],
      dates: [
        {'label': 'Met', 'date': '2020-05-01'},
      ],
      boundaries: 'Ask before visiting',
      safety: ['Safe person'],
      privateNotes: 'secret',
      giftIdeas: ['Tea'],
      alters: ['m1'],
      alterNotes: {'m1': 'Close'},
      links: ['journal:j1'],
      interactions: [
        {'at': '2026-11-01T10:00:00', 'note': 'Coffee'},
      ],
    );
    final back = ContactExtras.fromJson(e.toJson());
    expect(back.toJson(), e.toJson());
    expect(back.safety, ['Safe person']);
    expect(back.privateNotes, 'secret');
    expect(const ContactExtras(contactId: 'c1').isEmpty, isTrue);
    expect(e.isEmpty, isFalse);
  });

  test('hostile saved data degrades safely', () {
    final e = ContactExtras.fromJson({
      'cid': 'c',
      'soc': 'nope',
      'adr': [1, 2],
      'sf': [1, 'ok'],
      'pl': {'a': 1},
    });
    expect(e.socials, isEmpty);
    expect(e.addresses, isEmpty);
    expect(e.safety, ['ok']);
    expect(e.phoneLabels, {'a': '1'});
  });

  testWidgets('shows only the actions a contact has', (tester) async {
    await _pump(
      tester,
      _contact(phones: ['555-0100'], emails: ['r@example.com']),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Call'), findsWidgets);
    expect(find.text('Message'), findsWidgets);
    expect(find.text('Email'), findsWidgets);
    expect(find.text('Chat'), findsNothing);
    expect(find.text('Profile'), findsNothing);
  });

  testWidgets(
    'a contact with no phone or email gets no call, message or email buttons',
    (tester) async {
      await _pump(tester, _contact(birthday: '2000-03-14'));
      expect(find.text('Call'), findsNothing);
      expect(find.text('Message'), findsNothing);
      expect(find.text('Email'), findsNothing);
      expect(find.text('Riley Park'), findsOneWidget);
    },
  );

  testWidgets('social and conversation actions appear when set', (
    tester,
  ) async {
    await _pump(
      tester,
      _contact(phones: ['555']),
      extras: const ContactExtras(contactId: 'c1').copyWith(
        socials: [
          {'label': 'Site', 'url': 'https://example.com/riley'},
        ],
        conversation: 'conv1',
      ),
    );
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
  });

  testWidgets(
    'header shows nickname, pronouns, relationship and status; no stat cards',
    (tester) async {
      await _pump(
        tester,
        _contact(phones: ['555']),
        extras: const ContactExtras(contactId: 'c1').copyWith(
          nickname: 'Ri',
          pronouns: 'she/her',
          relationship: 'Sister',
          status: 'Moving soon',
        ),
      );
      expect(find.text('“Ri”'), findsOneWidget);
      expect(find.text('she/her'), findsOneWidget);
      expect(find.text('Sister'), findsOneWidget);
      expect(find.text('Moving soon'), findsOneWidget);
      // No analytics-style statistic cards.
      expect(find.textContaining('Total'), findsNothing);
      expect(find.textContaining('Streak'), findsNothing);
    },
  );

  testWidgets('sections expand and collapse', (tester) async {
    await _pump(
      tester,
      _contact(birthday: '2000-03-14'),
      extras: const ContactExtras(
        contactId: 'c1',
      ).copyWith(commPrefs: 'Texts over calls', giftIdeas: ['Loose-leaf tea']),
    );
    expect(find.text('Texts over calls'), findsNothing);
    await tester.tap(find.text('Communication'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Texts over calls'), findsOneWidget);
    await tester.tap(find.text('Communication'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Texts over calls'), findsNothing);
  });

  testWidgets(
    'private notes and safety labels show only on this page, marked private',
    (tester) async {
      await _pump(
        tester,
        _contact(phones: ['555']),
        extras: const ContactExtras(
          contactId: 'c1',
        ).copyWith(safety: ['Safe person'], privateNotes: 'only for me'),
      );
      expect(find.textContaining('private'), findsWidgets);
    },
  );

  testWidgets('works on a wide desktop window too', (tester) async {
    await _pump(
      tester,
      _contact(phones: ['555'], emails: ['a@b.co']),
      size: const Size(1400, 900),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Call'), findsWidgets);
  });

  testWidgets('works on a small phone without overflow', (tester) async {
    await _pump(
      tester,
      _contact(phones: ['555'], emails: ['a@b.co']),
      extras: const ContactExtras(contactId: 'c1').copyWith(
        socials: [
          {'label': 'Site', 'url': 'https://example.com'},
        ],
        conversation: 'c',
      ),
      size: const Size(320, 640),
    );
    expect(tester.takeException(), isNull);
  });
}
