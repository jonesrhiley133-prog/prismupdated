import 'package:prism_social_core/prism_social_core.dart';
import 'package:test/test.dart';

Matcher _denied(String code) => isA<SocialDenied>().having((e) => e.code, 'code', code);

void main() {
  late MemorySocialStore store;
  // Two separate people (server accounts), each with one system.
  late SocialRules alice, bob, carol;

  setUp(() {
    store = MemorySocialStore();
    alice = SocialRules(store, account: 'acct-alice');
    bob = SocialRules(store, account: 'acct-bob');
    carol = SocialRules(store, account: 'acct-carol');
  });

  Future<Set<String>> ids(Set<String> mine, String kind) async => {for (final r in await visibleTo(store, mine)) if (r.kind == kind) r.id};

  test('accounts can only act as their own systems and alters', () async {
    final a = await alice.createProfile(username: 'aurora', systemName: 'Aurora');
    final b = await bob.createProfile(username: 'birch', systemName: 'Birch');
    final mira = await bob.saveAlter(b, name: 'Mira');
    await expectLater(alice.updateProfile(b, {'status': 'dnd'}), throwsA(_denied('not_managed')));
    await expectLater(alice.sendRequest(SocialActor(b), a), throwsA(_denied('not_managed')));
    await expectLater(alice.createPost(SocialActor(b, mira), type: 'text', body: 'impersonation'), throwsA(_denied('not_managed')));
    await expectLater(alice.saveAlter(b, name: 'Fake'), throwsA(_denied('not_managed')));
    await expectLater(alice.saveAlter(a, editingId: mira, name: 'Stolen'), throwsA(_denied('not_owner')));
    await expectLater(alice.deleteAlter(b, mira), throwsA(_denied('not_managed')));
    // Owner and primary can't be changed through updates.
    await bob.updateProfile(b, {'owner': 'acct-alice'});
    expect((await store.all(SocKind.profile)).firstWhere((p) => p.id == b).str('owner'), 'acct-bob');
  });

  test('full flow between two people, alter to alter', () async {
    final a = await alice.createProfile(username: 'aurora', systemName: 'Aurora');
    final b = await bob.createProfile(username: 'birch', systemName: 'Birch');
    final sol = await alice.saveAlter(a, name: 'Sol');
    final mira = await bob.saveAlter(b, name: 'Mira');

    await alice.sendRequest(SocialActor(a), b, note: 'hi');
    final req = (await store.all(SocKind.request)).single;
    await expectLater(alice.acceptRequest(SocialActor(a), req.id), throwsA(_denied('not_owner')));
    await bob.acceptRequest(SocialActor(b), req.id);
    expect(await alice.areFriends(a, b), isTrue);

    final conv = await alice.openConversation(SocialActor(a, sol), SocialActor(b, mira));
    await alice.sendMessage(SocialActor(a, sol), conv, body: 'Hi Mira');
    await expectLater(bob.sendMessage(SocialActor(a, sol), conv, body: 'spoof'), throwsA(_denied('not_managed')));
    await bob.sendMessage(SocialActor(b, mira), conv, body: 'Hi Sol');
    await bob.markRead(SocialActor(b, mira), conv);

    final post = await bob.createPost(SocialActor(b), type: 'text', body: 'Hello friends');
    await alice.toggleReact(SocialActor(a), post, 'like');
    await alice.comment(SocialActor(a, sol), post, 'Lovely');

    // Bob's snapshot has the conversation, both messages, the post and the
    // notifications addressed to Bob only.
    expect(await ids({b}, SocKind.message), hasLength(2));
    expect(await ids({b}, SocKind.post), {post});
    final notifTypes = {for (final r in await visibleTo(store, {b})) if (r.kind == SocKind.notif) r.str('type')};
    expect(notifTypes, containsAll(['request', 'alterMessage', 'like', 'comment']));
    expect((await visibleTo(store, {a})).where((r) => r.kind == SocKind.notif).map((r) => r.str('type')), containsAll(['accepted', 'alterMessage']));
  });

  test('snapshots hide private data and strangers’ friends-only posts', () async {
    final a = await alice.createProfile(username: 'aurora', systemName: 'Aurora');
    final b = await bob.createProfile(username: 'birch', systemName: 'Birch');
    final c = await carol.createProfile(username: 'cedar', systemName: 'Cedar');
    await bob.saveAlter(b, name: 'Mira', memberId: 'member-123');
    await alice.sendRequest(SocialActor(a), b);
    await bob.acceptRequest(SocialActor(b), (await store.all(SocKind.request)).single.id);
    final friendsOnly = await bob.createPost(SocialActor(b), type: 'text', body: 'friends only');
    final public = await bob.createPost(SocialActor(b), type: 'text', body: 'public', audience: Audience.everyone);
    await alice.toggleReact(SocialActor(a), public, 'bookmark');
    await bob.updateProfile(b, {'notify': {'like': false}});

    expect(await ids({c}, SocKind.post), {public});
    expect(await ids({a}, SocKind.post), {friendsOnly, public});
    // Carol can't see Bob's alters (friends only) and nobody else sees
    // bookmarks, notification settings, owners or member ids.
    expect(await ids({c}, SocKind.alter), isEmpty);
    final aliceView = await visibleTo(store, {a});
    final bobForAlice = aliceView.firstWhere((r) => r.id == b);
    expect(bobForAlice.fields.containsKey('notify'), isFalse);
    expect(bobForAlice.fields.containsKey('owner'), isFalse);
    expect(aliceView.firstWhere((r) => r.kind == SocKind.alter).memberId, isNull);
    expect((await visibleTo(store, {b})).where((r) => r.kind == SocKind.react), isEmpty, reason: 'Alice’s bookmark is private');
    expect((await visibleTo(store, {c})).any((r) => r.kind == SocKind.profile && r.id == a), isTrue, reason: 'discoverable');
  });

  test('blocks hide both sides without revealing the block', () async {
    final a = await alice.createProfile(username: 'aurora', systemName: 'Aurora');
    final b = await bob.createProfile(username: 'birch', systemName: 'Birch');
    final post = await bob.createPost(SocialActor(b), type: 'text', body: 'public', audience: Audience.everyone);
    await alice.block(SocialActor(a), b);
    final bobView = await visibleTo(store, {b});
    expect(bobView.any((r) => r.id == a), isFalse);
    expect(bobView.any((r) => r.kind == SocKind.block), isFalse, reason: 'Bob is not told');
    final aliceView = await visibleTo(store, {a});
    expect(aliceView.any((r) => r.id == post), isFalse);
    expect(aliceView.where((r) => r.kind == SocKind.block), hasLength(1));
    await expectLater(bob.sendRequest(SocialActor(b), a), throwsA(_denied('blocked')));
  });

  test('profile privacy: limited card for people who may not view it', () async {
    final a = await alice.createProfile(username: 'aurora', systemName: 'Aurora', description: 'secret bio');
    final c = await carol.createProfile(username: 'cedar', systemName: 'Cedar');
    await alice.updateProfile(a, {'privacy': {'profile': 'friends'}, 'pronouns': 'they/them'});
    final card = (await visibleTo(store, {c})).firstWhere((r) => r.id == a);
    expect(card.body, isNull);
    expect(card.str('pronouns'), isNull);
    expect(card.str('username'), 'aurora');
    await alice.updateProfile(a, {'privacy': {'profile': 'friends', 'discover': false}});
    expect((await visibleTo(store, {c})).any((r) => r.id == a), isFalse);
  });

  test('circle posts reach members only, without exposing the circle', () async {
    final a = await alice.createProfile(username: 'aurora', systemName: 'Aurora');
    final b = await bob.createProfile(username: 'birch', systemName: 'Birch');
    final c = await carol.createProfile(username: 'cedar', systemName: 'Cedar');
    for (final (r, p) in [(bob, b), (carol, c)]) {
      await r.sendRequest(SocialActor(p), a);
    }
    for (final q in await store.all(SocKind.request)) {
      await alice.acceptRequest(SocialActor(a), q.id);
    }
    final circle = await alice.saveCircle(SocialActor(a), name: 'Close friends', members: [b]);
    final p = await alice.createPost(SocialActor(a), type: 'text', body: 'inner', circleId: circle);
    expect(await ids({b}, SocKind.post), contains(p));
    expect(await ids({c}, SocKind.post), isNot(contains(p)));
    final stripped = (await visibleTo(store, {b})).firstWhere((r) => r.kind == SocKind.circle);
    expect(stripped.title, isEmpty);
    expect(stripped.strings('members'), [b]);
    await expectLater(bob.deleteCircle(SocialActor(b), circle), throwsA(_denied('not_owner')));
  });
}
