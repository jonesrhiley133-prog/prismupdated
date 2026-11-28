import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/domain/models/calendar_event.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/domain/repositories/calendar_repository.dart';
import 'package:prism_plurality/domain/repositories/entity_repository.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/features/yumeships/yume_data.dart';
import 'package:prism_plurality/features/yumeships/yume_studio.dart'
    show yumeCreationText, yumeToolTemplate;

class _Repo implements EntityRepository<TrackerRecord> {
  final rows = <TrackerRecord>[];
  @override
  Stream<List<TrackerRecord>> watchAll() async* {
    yield [...rows];
  }

  @override
  Future<List<TrackerRecord>> getAll() async => [...rows];
  @override
  Future<TrackerRecord?> getById(String id) async =>
      rows.where((r) => r.id == id).firstOrNull;
  @override
  Future<void> create(TrackerRecord item) async => rows.add(item);
  @override
  Future<void> update(TrackerRecord item) async =>
      rows[rows.indexWhere((r) => r.id == item.id)] = item;
  @override
  Future<void> delete(String id) async => rows.removeWhere((r) => r.id == id);
}

class _Cal implements CalendarRepository {
  final events = <CalendarEvent>[];
  @override
  Stream<List<CalendarEvent>> watchAll() async* {
    yield [...events];
  }

  @override
  Future<List<CalendarEvent>> getAll() async => [...events];
  @override
  Future<CalendarEvent?> getById(String id) async =>
      events.where((e) => e.id == id).firstOrNull;
  @override
  Future<void> create(CalendarEvent event) async => events.add(event);
  @override
  Future<void> update(CalendarEvent event) async =>
      events[events.indexWhere((e) => e.id == event.id)] = event;
  @override
  Future<void> delete(String id) async => events.removeWhere((e) => e.id == id);
}

class _Viewer extends Notifier<String?> {
  @override
  String? build() => 'alice';
  void set(String? v) => state = v;
}

final _viewer = NotifierProvider<_Viewer, String?>(_Viewer.new);

typedef _H = ({
  ProviderContainer c,
  _Repo repo,
  _Cal cal,
  Future<void> Function() refresh,
  YumeActions a,
});

_H _harness() {
  final repo = _Repo();
  final cal = _Cal();
  final c = ProviderContainer(
    overrides: [
      trackerRecordRepositoryProvider.overrideWithValue(repo),
      calendarRepositoryProvider.overrideWithValue(cal),
      yumeViewerProvider.overrideWith((ref) => ref.watch(_viewer)),
    ],
  );
  c.listen(trackerRecordsProvider, (_, _) {});
  Future<void> refresh() async {
    c.invalidate(trackerRecordsProvider);
    await c.read(trackerRecordsProvider.future);
  }

  return (
    c: c,
    repo: repo,
    cal: cal,
    refresh: refresh,
    a: c.read(yumeActionsProvider),
  );
}

void main() {
  group('privacy', () {
    test('owners, collaborators and chosen alters', () {
      bool can(String vis, String? viewer) => yumeCanView(
        visibility: vis,
        owners: const ['alice'],
        collaborators: const ['bea'],
        shared: const ['cal'],
        viewer: viewer,
      );
      expect(can('private', 'alice'), isTrue);
      expect(can('private', 'bea'), isTrue);
      expect(can('private', 'cal'), isFalse);
      expect(can('private', null), isFalse);
      expect(can('selective', 'cal'), isTrue);
      expect(can('selective', 'dan'), isFalse);
      expect(can('system', 'dan'), isTrue);
      expect(can('system', null), isTrue);
      // No owners: it belongs to the whole system.
      expect(
        yumeCanView(
          visibility: 'private',
          owners: const [],
          collaborators: const [],
          shared: const [],
          viewer: null,
        ),
        isTrue,
      );
    });

    test('private ships are hidden from other alters', () async {
      final h = _harness();
      addTearDown(h.c.dispose);
      await h.a.createShip(
        name: 'Me & Kaito',
        owner: 'alice',
        extra: {'visibility': 'private'},
      );
      await h.refresh();
      expect(h.c.read(yumeShipsProvider), hasLength(1));
      h.c.read(_viewer.notifier).set('dan');
      expect(h.c.read(yumeShipsProvider), isEmpty);
      // Private items are flagged private on the record too.
      expect(h.repo.rows.single.isPrivate, isTrue);
      h.c.read(_viewer.notifier).set('alice');
      final s = h.c.read(yumeAllShipsProvider).single;
      await h.a.saveShip(s, {'visibility': 'system'});
      expect(h.repo.rows.single.isPrivate, isFalse);
    });

    test('saving an older copy never undoes newer changes', () async {
      final h = _harness();
      addTearDown(h.c.dispose);
      final rec = await h.a.createShip(name: 'Us', body: 'About us');
      await h.refresh();
      final stale = h.c.read(yumeShipByIdProvider(rec.id))!;
      await h.a.saveShip(stale, {'status': 'Dating'});
      await h.a.markOpened(stale);
      final row = h.repo.rows.single;
      expect(row.body, 'About us');
      expect(row.fields['status'], 'Dating');
      expect(row.fields['opened'], isNotNull);
    });

    test('PIN is stored salted and checked', () async {
      final h = _harness();
      addTearDown(h.c.dispose);
      await h.a.setPin('2468');
      await h.refresh();
      final s = h.c.read(yumeSettingsProvider);
      expect(s.hasPin, isTrue);
      expect(s.checkPin('2468'), isTrue);
      expect(s.checkPin('1357'), isFalse);
      expect(h.repo.rows.single.fields['pinHash'], isNot('2468'));
      await h.a.setPin(null);
      await h.refresh();
      expect(h.c.read(yumeSettingsProvider).hasPin, isFalse);
    });
  });

  test('a ship keeps several F/Os, sonas and its own sections', () async {
    final h = _harness();
    addTearDown(h.c.dispose);
    final rec = await h.a.createShip(
      name: '',
      owner: 'alice',
      fos: const [
        YumeFo(id: 'f1', name: 'Kaito', source: 'Starfall'),
        YumeFo(id: 'f2', name: 'Ren', source: 'Starfall'),
      ],
      preset: 'celestial',
    );
    final sona = await h.a.createSona(name: 'Moonlit Me', owner: 'alice');
    await h.refresh();
    var ship = h.c.read(yumeShipByIdProvider(rec.id))!;
    expect(ship.name, 'Kaito & Ren');
    expect(ship.sources, {'Starfall'});
    expect(ship.font, 'g:Cinzel');
    expect(ship.symbol, '🌙');
    await h.a.setSonaOnShip(ship, sona.id, true);
    await h.refresh();
    ship = h.c.read(yumeShipByIdProvider(rec.id))!;
    await h.a.saveShip(ship, {
      'sections': ['headcanons', 'about'],
      'hidden': ['links'],
    });
    await h.refresh();
    ship = h.c.read(yumeShipByIdProvider(rec.id))!;
    expect(ship.sonaIds, [sona.id]);
    expect(ship.sections.first, ('headcanons', true));
    expect(ship.sections[1], ('about', true));
    expect(ship.sections.firstWhere((s) => s.$1 == 'links').$2, isFalse);
    // Deleting the sona unlinks it but keeps the ship.
    await h.a.deleteSona(h.c.read(yumeSonaByIdProvider(sona.id))!);
    await h.refresh();
    expect(h.c.read(yumeShipByIdProvider(rec.id))!.sonaIds, isEmpty);
  });

  test('smart collections fill themselves; hand-picked order wins', () async {
    final h = _harness();
    addTearDown(h.c.dispose);
    final a = await h.a.createShip(
      name: 'A',
      extra: {
        'relTypes': ['romantic'],
        'fos': [
          {'id': 'x', 'name': 'X', 'source': 'Book One'},
        ],
      },
    );
    final b = await h.a.createShip(
      name: 'B',
      extra: {
        'relTypes': ['platonic'],
      },
    );
    final c = await h.a.createShip(
      name: 'C',
      extra: {
        'relTypes': ['romantic'],
        'archived': true,
      },
    );
    final romantic = await h.a.createCollection(
      name: 'Romance',
      type: 'romantic',
    );
    final bySource = await h.a.createCollection(
      name: 'Book One',
      type: 'source',
      source: 'book one',
    );
    final custom = await h.a.createCollection(name: 'Mine', type: 'custom');
    await h.refresh();
    expect(
      [
        for (final s in h.c.read(yumeCollectionShipsProvider(romantic.id)))
          s.id,
      ],
      [a.id],
    );
    expect(
      [
        for (final s in h.c.read(yumeCollectionShipsProvider(bySource.id)))
          s.id,
      ],
      [a.id],
    );
    final col = h.c.read(yumeCollectionByIdProvider(custom.id))!;
    await h.a.saveCollection(col, {
      'shipIds': [c.id, b.id],
    });
    await h.refresh();
    expect(
      [for (final s in h.c.read(yumeCollectionShipsProvider(custom.id))) s.id],
      [c.id, b.id],
    );
  });

  group('dates', () {
    YumeEvent ev(DateTime d, String repeat) => YumeEvent(
      TrackerRecord(
        id: 'e',
        kind: TrackerKind.yumeEvent,
        occurredAt: d,
        createdAt: d,
        modifiedAt: d,
      ).withFields({'repeat': repeat}),
    );

    test('next occurrence for each repeat', () {
      final now = DateTime(2026, 11, 28, 15);
      expect(
        ev(DateTime(2020, 2, 14), 'yearly').nextOn(now),
        DateTime(2027, 2, 14),
      );
      expect(
        ev(DateTime(2020, 12, 1), 'yearly').nextOn(now),
        DateTime(2026, 12, 1),
      );
      expect(
        ev(DateTime(2026, 11, 28), 'none').nextOn(now),
        DateTime(2026, 11, 28),
      );
      expect(ev(DateTime(2025, 1, 1), 'none').nextOn(now), isNull);
      expect(
        ev(DateTime(2026, 1, 31), 'monthly').nextOn(now),
        DateTime(2026, 11, 30),
      );
      expect(
        ev(DateTime(2026, 11, 2), 'weekly').nextOn(now),
        DateTime(2026, 11, 30),
      );
      // Leap-day anniversaries land on the 28th in other years.
      expect(
        ev(DateTime(2024, 2, 29), 'yearly').nextOn(now),
        DateTime(2027, 2, 28),
      );
    });

    test('calendar entries and notifications follow your choices', () async {
      final h = _harness();
      addTearDown(h.c.dispose);
      final ship = await h.a.createShip(
        name: 'Us',
        owner: 'alice',
        extra: {'accent': 0xFFE26D8A},
      );
      await h.refresh();
      var e = await h.a.saveEvent(
        shipId: ship.id,
        type: 'anniversary',
        title: 'Anniversary',
        date: DateTime(2024, 6, 1),
        repeat: 'yearly',
        onCalendar: true,
        notify: true,
        lead: 'dayBefore',
      );
      await h.refresh();
      expect(h.cal.events, hasLength(1));
      final c = h.cal.events.single;
      expect(c.isAllDay, isTrue);
      expect(c.recurrence, CalendarRecurrence.yearly);
      expect(c.alertMinutes, [900]);
      expect(c.category, 'Yumeship');
      expect(c.colorHex, '#E26D8A');
      expect(c.memberIds, ['alice']);
      expect(e.calId, c.id);

      // Notifications off for the whole ship: the calendar entry stays quiet.
      await h.a.saveShip(h.c.read(yumeShipByIdProvider(ship.id))!, {
        'notify': false,
      });
      await h.refresh();
      await h.a.resyncShip(ship.id);
      expect(h.cal.events.single.alertMinutes, isEmpty);

      // Off the calendar: the entry is removed.
      e = h.c.read(yumeShipEventsProvider(ship.id)).single;
      e = await h.a.saveEvent(
        existing: e,
        shipId: ship.id,
        type: 'anniversary',
        title: 'Anniversary',
        date: DateTime(2024, 6, 1),
        repeat: 'yearly',
        onCalendar: false,
        notify: false,
      );
      expect(h.cal.events, isEmpty);
      expect(e.calId, isNull);

      // Back on, then deleting the ship removes it from the calendar too.
      await h.refresh();
      await h.a.saveEvent(
        existing: h.c.read(yumeShipEventsProvider(ship.id)).single,
        shipId: ship.id,
        type: 'anniversary',
        title: 'Anniversary',
        date: DateTime(2024, 6, 1),
        onCalendar: true,
        notify: false,
      );
      expect(h.cal.events, hasLength(1));
      await h.refresh();
      await h.a.deleteShip(h.c.read(yumeShipByIdProvider(ship.id))!);
      expect(h.cal.events, isEmpty);
      expect(
        h.repo.rows.where((r) => r.kind == TrackerKind.yumeEvent),
        isEmpty,
      );
    });

    test('upcoming includes a ship anniversary without an event', () async {
      final h = _harness();
      addTearDown(h.c.dispose);
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      await h.a.createShip(
        name: 'Us',
        extra: {
          'anniversary': DateTime(
            2020,
            tomorrow.month,
            tomorrow.day,
          ).toIso8601String(),
        },
      );
      await h.refresh();
      final up = h.c.read(yumeUpcomingProvider);
      expect(up, hasLength(1));
      expect(up.single.daysFrom(DateTime.now()), 1);
    });
  });

  test('duplicate for another alter and transfer', () async {
    final h = _harness();
    addTearDown(h.c.dispose);
    final ship = await h.a.createShip(
      name: 'Us',
      owner: 'alice',
      extra: {
        'collab': ['bea'],
      },
    );
    await h.refresh();
    await h.a.addMedia(
      ship.id,
      type: 'art',
      artist: 'Someone',
      link: 'https://example.com',
    );
    await h.refresh();
    final copy = await h.a.duplicateShip(
      h.c.read(yumeShipByIdProvider(ship.id))!,
      toOwner: 'cal',
    );
    await h.refresh();
    final dup = h.c.read(yumeShipByIdProvider(copy.id))!;
    expect(dup.owners, ['cal']);
    expect(dup.collaborators, isEmpty);
    expect(h.c.read(yumeShipMediaProvider(copy.id)).single.artist, 'Someone');
    await h.a.transferShip(h.c.read(yumeShipByIdProvider(ship.id))!, 'bea');
    await h.refresh();
    final moved = h.c.read(yumeShipByIdProvider(ship.id))!;
    expect(moved.owners, ['bea']);
    expect(moved.collaborators, isEmpty);
    expect(h.c.read(yumeShipsForMemberProvider('bea')).map((s) => s.id), [
      ship.id,
    ]);
  });

  test('studio templates and text export', () {
    final bingo = yumeToolTemplate('bingo');
    expect((bingo['cells'] as List), hasLength(25));
    final chart = yumeToolTemplate('chart');
    expect((chart['rows'] as List), isNotEmpty);
    final text = yumeCreationText('Ideas', 'prompts', {
      'items': [
        {'title': 'Rainy day', 'done': true},
        {'title': 'Picnic', 'done': false},
      ],
    });
    expect(text, contains('✅ Rainy day'));
    expect(text, contains('⬜ Picnic'));
    final fic = yumeCreationText('Fics', 'fic', {
      'items': [
        {'title': 'Starlight', 'status': 'Drafting', 'text': 'A slow burn'},
      ],
    });
    expect(fic, contains('Starlight [Drafting]'));
    expect(fic, contains('A slow burn'));
  });
}
