import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/domain/repositories/entity_repository.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/prism_social/social_core.dart';
import 'package:prism_plurality/features/prism_social/social_device_notifications.dart';
import 'package:prism_plurality/features/prism_social/social_hub_screen.dart';
import 'package:prism_plurality/features/prism_social/social_messages.dart';
import 'package:prism_plurality/features/prism_social/social_profile.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';

final _t = DateTime.now().subtract(const Duration(hours: 1));

class _Repo implements EntityRepository<TrackerRecord> {
  _Repo(List<TrackerRecord> seed) : rows = [...seed];
  final List<TrackerRecord> rows;
  final _c = StreamController<List<TrackerRecord>>.broadcast();
  void _emit() => _c.add([...rows]);
  @override
  Stream<List<TrackerRecord>> watchAll() async* {
    yield [...rows];
    yield* _c.stream;
  }

  @override
  Future<List<TrackerRecord>> getAll() async => [...rows];
  @override
  Future<TrackerRecord?> getById(String id) async => rows.where((r) => r.id == id).firstOrNull;
  @override
  Future<void> create(TrackerRecord item) async {
    rows.add(item);
    _emit();
  }

  @override
  Future<void> update(TrackerRecord item) async {
    rows[rows.indexWhere((r) => r.id == item.id)] = item;
    _emit();
  }

  @override
  Future<void> delete(String id) async {
    rows.removeWhere((r) => r.id == id);
    _emit();
  }
}

TrackerRecord _r(String id, String kind, {String title = '', String? body, String? parentId, Map<String, Object?> f = const {}}) =>
    TrackerRecord(id: id, kind: kind, title: title, body: body, parentId: parentId, occurredAt: _t, createdAt: _t, modifiedAt: _t).withFields(f);

List<TrackerRecord> _seed() => [
  _r('pa', SocKind.profile, title: 'Aurora System', body: 'We like stars.', f: {'username': 'aurora', 'primary': true, 'lastActive': DateTime.now().toIso8601String()}),
  _r('pb', SocKind.profile, title: 'Birch Collective', f: {'username': 'birch', 'lastActive': DateTime.now().toIso8601String(), 'useTheme': true, 'theme': {'accent': 0xFF2E7D32, 'layout': 'centered'}}),
  _r('pc', SocKind.profile, title: 'Cedar', f: {'username': 'cedar'}),
  _r('alt', SocKind.alter, title: 'Mira', parentId: 'pb', f: {'visibility': 'friends'}),
  _r('fr', SocKind.friendship, f: {'a': 'pa', 'b': 'pb'}),
  _r('rq', SocKind.request, body: 'Hi!', f: {'from': 'pc', 'to': 'pa', 'status': 'pending'}),
  _r('post1', SocKind.post, title: 'First light', body: 'Our first post', f: {'author': {'p': 'pb'}, 'type': 'text', 'audience': 'friends'}),
  _r('cv', SocKind.conversation, f: {'participants': [{'p': 'pa'}, {'p': 'pb', 'a': 'alt'}], 'last': _t.toIso8601String()}),
  _r('m1', SocKind.message, body: 'Hello from Mira', parentId: 'cv', f: {'sender': {'p': 'pb', 'a': 'alt'}, 'readBy': {'pb': _t.toIso8601String()}}),
  _r('n1', SocKind.notif, body: 'Hi!', parentId: 'pa', f: {'type': 'request', 'actor': {'p': 'pc'}, 'target': 'rq'}),
];

Widget _app(Widget home, _Repo repo) => ProviderScope(
  overrides: [
    trackerRecordRepositoryProvider.overrideWithValue(repo),
    allMemberListProvider.overrideWith((ref) => Stream.value(const <Member>[])),
    memberNamePreferDisplayProvider.overrideWithValue(false),
  ],
  child: MaterialApp(localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: const [Locale('en')], home: home),
);

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _section(WidgetTester t, String label) async {
  final f = find.text(label).first;
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await _settle(t);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('hub shows every section for the acting system', (t) async {
    t.view.physicalSize = const Size(1200, 2400);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app(const SocialHubScreen(), _Repo(_seed())));
    await _settle(t);
    expect(find.text('First light'), findsOneWidget, reason: 'friend’s friends-only post is in the feed');

    await _section(t, 'Friends');
    await _settle(t);
    expect(find.text('Birch Collective'), findsOneWidget);
    expect(find.text('Cedar'), findsNothing);

    await _section(t, 'Requests · 1');
    await _settle(t);
    expect(find.text('Cedar'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);

    await _section(t, 'Messages · 1');
    await _settle(t);
    expect(find.text('Mira'), findsOneWidget);
    expect(find.text('alter'), findsOneWidget, reason: 'alters are always labelled');
    expect(find.textContaining('from Birch Collective'), findsOneWidget);

    await _section(t, 'Discover');
    await _settle(t);
    expect(find.text('Cedar'), findsWidgets);

    await _section(t, 'Notifications · 1');
    await _settle(t);
    expect(find.text('Cedar sent you a friend request'), findsOneWidget);

    await _section(t, 'My profile');
    await _settle(t);
    expect(find.text('Aurora System'), findsWidgets);
    expect(find.text('Edit profile'), findsOneWidget);
  });

  testWidgets('without a profile, onboarding is shown honestly', (t) async {
    await t.pumpWidget(_app(const SocialHubScreen(), _Repo(const [])));
    await _settle(t);
    expect(find.text('Create profile'), findsOneWidget);
    expect(find.textContaining('nothing here pretends otherwise'), findsOneWidget);
  });

  testWidgets('a friend’s profile uses their custom theme', (t) async {
    t.view.physicalSize = const Size(1200, 2400);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app(const SocialProfileScreen(profileId: 'pb'), _Repo(_seed())));
    await _settle(t);
    expect(find.text('Birch Collective'), findsWidgets);
    expect(find.text('Mira'), findsOneWidget, reason: 'alters visible to friends');
    final ctx = t.element(find.text('First light'));
    final scheme = Theme.of(ctx).colorScheme;
    expect(scheme.primary, ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32), brightness: Brightness.light).primary);
  });

  testWidgets('conversation shows who you speak as and marks read', (t) async {
    final repo = _Repo(_seed());
    await t.pumpWidget(_app(const SocialConversationScreen(conversationId: 'cv'), repo));
    await _settle(t);
    expect(find.text('Hello from Mira'), findsOneWidget);
    expect(find.textContaining('You’re speaking as Aurora System'), findsOneWidget);
    final m = repo.rows.firstWhere((r) => r.id == 'm1');
    expect(SocialMessage(m).readBy.containsKey('pa'), isTrue);
  });

  test('device notifications skip your own actions, old and read items', () {
    final since = DateTime.now().subtract(const Duration(minutes: 5));
    final profiles = [SocialProfile(_r('pa', SocKind.profile, f: {'username': 'a'})), SocialProfile(_r('pb', SocKind.profile, f: {'username': 'b', 'notify': {'push': false}}))];
    TrackerRecord n(String id, String to, String actor, {bool read = false, DateTime? at}) =>
        TrackerRecord(id: id, kind: SocKind.notif, title: '', parentId: to, occurredAt: at ?? DateTime.now(), createdAt: DateTime.now(), modifiedAt: DateTime.now()).withFields({'type': 'like', 'actor': {'p': actor}, 'read': read});
    final rows = [
      n('ok', 'pa', 'pc'),
      n('mine', 'pa', 'pb'),
      n('read', 'pa', 'pc', read: true),
      n('old', 'pa', 'pc', at: since.subtract(const Duration(minutes: 1))),
      n('muted', 'pb', 'pc'),
    ];
    expect(pushable(rows: rows, profiles: profiles, since: since, shown: {}, actingProfile: 'pb').map((x) => x.id), ['ok']);
    expect(pushable(rows: rows, profiles: profiles, since: since, shown: {'ok'}, actingProfile: 'pb'), isEmpty);
  });
}
