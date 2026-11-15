import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/domain/repositories/entity_repository.dart';
import 'package:prism_plurality/features/prism_social/social_core.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';

/// In-memory stand-in for the synced tracker table.
class _Repo implements EntityRepository<TrackerRecord> {
  final rows = <TrackerRecord>[];
  @override
  Stream<List<TrackerRecord>> watchAll() async* {
    yield [...rows];
  }

  @override
  Future<List<TrackerRecord>> getAll() async => [...rows];
  @override
  Future<TrackerRecord?> getById(String id) async => rows.where((r) => r.id == id).firstOrNull;
  @override
  Future<void> create(TrackerRecord item) async => rows.add(item);
  @override
  Future<void> update(TrackerRecord item) async => rows[rows.indexWhere((r) => r.id == item.id)] = item;
  @override
  Future<void> delete(String id) async => rows.removeWhere((r) => r.id == id);
}

Matcher _denied(String code) => isA<SocialDenied>().having((e) => e.code, 'code', code);

void main() {
  late _Repo repo;
  late ProviderContainer c;
  late SocialBackend b;

  Future<void> refresh() async {
    c.invalidate(trackerRecordsProvider);
    await c.read(trackerRecordsProvider.future);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = _Repo();
    c = ProviderContainer(overrides: [trackerRecordRepositoryProvider.overrideWithValue(repo)]);
    c.listen(trackerRecordsProvider, (_, _) {});
    b = c.read(socialBackendProvider);
  });
  tearDown(() => c.dispose());

  test('usernames are validated and unique', () async {
    await b.createProfile(username: 'Aurora.System', systemName: 'Aurora');
    await expectLater(b.createProfile(username: 'aurora.system', systemName: 'Copy'), throwsA(_denied('username_taken')));
    await expectLater(b.createProfile(username: 'no', systemName: 'Short'), throwsA(_denied('invalid')));
    await expectLater(b.createProfile(username: 'has space', systemName: 'Space'), throwsA(_denied('invalid')));
    await refresh();
    expect(c.read(socialProfilesProvider).single.username, 'aurora.system');
  });

  test('two systems: request → accept → message → read, with notifications', () async {
    final a = await b.createProfile(username: 'system_a', systemName: 'System A', primary: true);
    final bb = await b.createProfile(username: 'system_b', systemName: 'System B');
    final actA = SocialActor(a), actB = SocialActor(bb);

    await b.sendRequest(actA, bb, note: 'Hi from A');
    await expectLater(b.sendRequest(actA, bb), throwsA(_denied('duplicate')));
    await expectLater(b.sendRequest(actA, a), throwsA(_denied('self')));
    await refresh();
    final reqs = c.read(pendingRequestsProvider(bb));
    expect(reqs.incoming, hasLength(1));
    expect(c.read(pendingRequestsProvider(a)).outgoing, hasLength(1));
    expect(c.read(notificationsProvider(bb)).single.type, 'request');

    // Messages are friends-only by default.
    await expectLater(b.openConversation(actA, actB), throwsA(_denied('privacy')));
    // Only the recipient can accept.
    await expectLater(b.acceptRequest(actA, reqs.incoming.single.id), throwsA(_denied('not_owner')));
    await b.acceptRequest(actB, reqs.incoming.single.id);
    await refresh();
    expect(c.read(friendIdsProvider(a)), {bb});
    expect(c.read(friendIdsProvider(bb)), {a});
    expect(c.read(notificationsProvider(a)).single.type, 'accepted');
    await expectLater(b.sendRequest(actB, a), throwsA(_denied('already_friends')));

    final conv = await b.openConversation(actA, actB);
    expect(await b.openConversation(actA, actB), conv, reason: 'reuses the conversation');
    final m1 = await b.sendMessage(actA, conv, body: 'Hello B!');
    await refresh();
    expect(c.read(unreadMessagesProvider(bb)), 1);
    expect(c.read(unreadMessagesProvider(a)), 0);
    expect(c.read(notificationsProvider(bb)).first.type, 'message');

    // Only the sender may edit or delete.
    await expectLater(b.editMessage(actB, m1, 'hacked'), throwsA(_denied('not_owner')));
    await b.editMessage(actA, m1, 'Hello, B!');
    await b.react(actB, m1, '❤️');
    await b.sendMessage(actB, conv, body: 'Hey A', replyTo: m1);
    await b.markRead(actB, conv);
    await refresh();
    final msgs = c.read(messagesProvider(conv));
    expect(msgs, hasLength(2));
    expect(msgs.first.body, 'Hello, B!');
    expect(msgs.first.edited, isTrue);
    expect(msgs.first.reactions['❤️'], [actB.key]);
    expect(msgs.first.readBy.containsKey(bb), isTrue);
    expect(msgs.last.replyTo, m1);
    expect(c.read(unreadMessagesProvider(bb)), 0);
    expect(c.read(unreadMessagesProvider(a)), 1);

    await b.markUnread(actB, conv);
    await refresh();
    expect(c.read(unreadMessagesProvider(bb)), 1);

    await b.deleteMessage(actA, m1);
    await refresh();
    final deleted = c.read(messagesProvider(conv)).first;
    expect(deleted.deleted, isTrue);
    expect(deleted.body, isEmpty);

    // Muting stops message notifications.
    await b.toggleMute(actB, conv);
    final before = (await repo.getAll()).where((r) => r.kind == SocKind.notif && r.parentId == bb).length;
    await b.sendMessage(actA, conv, body: 'quiet');
    final after = (await repo.getAll()).where((r) => r.kind == SocKind.notif && r.parentId == bb).length;
    expect(after, before);
  });

  test('a reverse pending request becomes a friendship', () async {
    final a = await b.createProfile(username: 'aaa', systemName: 'A');
    final bb = await b.createProfile(username: 'bbb', systemName: 'B');
    await b.sendRequest(SocialActor(a), bb);
    await b.sendRequest(SocialActor(bb), a);
    await refresh();
    expect(c.read(friendIdsProvider(a)), {bb});
    expect(c.read(pendingRequestsProvider(a)).outgoing, isEmpty);
  });

  test('alter to alter messaging respects alter and system settings', () async {
    final a = await b.createProfile(username: 'sys_a', systemName: 'A');
    final bb = await b.createProfile(username: 'sys_b', systemName: 'B');
    final mira = await b.saveAlter(a, name: 'Mira');
    final kai = await b.saveAlter(bb, name: 'Kai');
    final quiet = await b.saveAlter(bb, name: 'Quiet', fields: {'canMessage': false});
    await b.sendRequest(SocialActor(a), bb);
    await refresh();
    await b.acceptRequest(SocialActor(bb), c.read(pendingRequestsProvider(bb)).incoming.single.id);

    // Acting as an alter of a system you don't manage is refused.
    await expectLater(b.openConversation(SocialActor(a, kai), SocialActor(bb)), throwsA(_denied('not_found')));

    final conv = await b.openConversation(SocialActor(a, mira), SocialActor(bb, kai));
    await b.sendMessage(SocialActor(a, mira), conv, body: 'Hi Kai, it’s Mira');
    await refresh();
    final c1 = c.read(conversationsProvider(bb)).single;
    expect(c1.me(bb), SocialActor(bb, kai));
    expect(c1.other(bb), SocialActor(a, mira));
    expect(c.read(notificationsProvider(bb)).first.type, 'alterMessage');
    expect(c.read(notificationsProvider(bb)).first.r.str('alter'), kai);
    // Speaking as the whole system in an alter conversation isn't allowed.
    await expectLater(b.sendMessage(SocialActor(a), conv, body: 'x'), throwsA(_denied('not_participant')));

    await expectLater(b.openConversation(SocialActor(a, mira), SocialActor(bb, quiet)), throwsA(_denied('alters_closed')));
    await b.updateProfile(bb, {'privacy': {'altersMessages': false}});
    await expectLater(b.openConversation(SocialActor(a), SocialActor(bb, kai)), throwsA(_denied('alters_closed')));
  });

  test('posts: audience, likes, comments, reblogs keep attribution', () async {
    final a = await b.createProfile(username: 'poster', systemName: 'Poster');
    final f = await b.createProfile(username: 'friend', systemName: 'Friend');
    final s = await b.createProfile(username: 'stranger', systemName: 'Stranger');
    await b.sendRequest(SocialActor(f), a);
    await refresh();
    await b.acceptRequest(SocialActor(a), c.read(pendingRequestsProvider(a)).incoming.single.id);

    final friendsOnly = await b.createPost(SocialActor(a), type: 'text', body: 'Friends only');
    final public = await b.createPost(SocialActor(a), type: 'text', title: 'Hello world', body: 'Public post @friend', audience: Audience.everyone);
    await refresh();
    expect(c.read(notificationsProvider(f)).first.type, 'mention');

    final recentForFriend = c.read(feedProvider((f, FeedMode.recent))).map((p) => p.id);
    final recentForStranger = c.read(feedProvider((s, FeedMode.recent))).map((p) => p.id);
    expect(recentForFriend, containsAll([friendsOnly, public]));
    expect(recentForStranger, [public]);

    await expectLater(b.toggleReact(SocialActor(s), friendsOnly, 'like'), throwsA(_denied('privacy')));
    await b.toggleReact(SocialActor(f), friendsOnly, 'like');
    await b.toggleReact(SocialActor(f), friendsOnly, 'bookmark');
    final cm = await b.comment(SocialActor(f), friendsOnly, 'Nice!');
    await b.comment(SocialActor(a), friendsOnly, 'Thanks', replyTo: cm);
    // Friends-only posts can't be reblogged; public ones can.
    await expectLater(b.reblog(SocialActor(f), friendsOnly), throwsA(_denied('privacy')));
    final rb = await b.reblog(SocialActor(s), public, note: 'Love this');
    final rb2 = await b.reblog(SocialActor(f), rb);
    await refresh();

    expect(c.read(reactsProvider(friendsOnly)).map((r) => r.str('type')), containsAll(['like', 'bookmark']));
    expect(c.read(commentsProvider(friendsOnly)), hasLength(2));
    final reblog2 = c.read(postsProvider).firstWhere((p) => p.id == rb2);
    expect(reblog2.origin!['post'], public, reason: 'a reblog of a reblog still credits the original');
    expect(SocialActor.fromJson(reblog2.origin!['author']), SocialActor(a));
    expect(c.read(reblogCountProvider(public)), 2);
    final types = c.read(notificationsProvider(a)).map((n) => n.type);
    expect(types, containsAll(['like', 'comment', 'reblog']));

    // Unliking removes it.
    await b.toggleReact(SocialActor(f), friendsOnly, 'like');
    await refresh();
    expect(c.read(reactsProvider(friendsOnly)).where((r) => r.str('type') == 'like'), isEmpty);

    // Only the author's system edits/deletes; deleting removes comments.
    await expectLater(b.editPost(SocialActor(f), friendsOnly, body: 'x'), throwsA(_denied('not_owner')));
    await b.deletePost(SocialActor(a), friendsOnly);
    await refresh();
    expect(c.read(postsProvider).any((p) => p.id == friendsOnly), isFalse);
    expect(c.read(commentsProvider(friendsOnly)), isEmpty);
  });

  test('circles limit who sees a post', () async {
    final a = await b.createProfile(username: 'owner', systemName: 'Owner');
    final f1 = await b.createProfile(username: 'inner', systemName: 'Inner');
    final f2 = await b.createProfile(username: 'outer', systemName: 'Outer');
    for (final f in [f1, f2]) {
      await b.sendRequest(SocialActor(f), a);
    }
    await refresh();
    for (final r in c.read(pendingRequestsProvider(a)).incoming) {
      await b.acceptRequest(SocialActor(a), r.id);
    }
    final circle = await b.saveCircle(SocialActor(a), name: 'Close', members: [f1]);
    final p = await b.createPost(SocialActor(a), type: 'text', body: 'Circle post', circleId: circle);
    await refresh();
    expect(c.read(feedProvider((f1, FeedMode.recent))).map((x) => x.id), contains(p));
    expect(c.read(feedProvider((f2, FeedMode.recent))).map((x) => x.id), isNot(contains(p)));
  });

  test('blocking ends the friendship and stops requests, messages and visibility', () async {
    final a = await b.createProfile(username: 'blocker', systemName: 'Blocker');
    final bb = await b.createProfile(username: 'blocked', systemName: 'Blocked');
    await b.sendRequest(SocialActor(a), bb);
    await refresh();
    await b.acceptRequest(SocialActor(bb), c.read(pendingRequestsProvider(bb)).incoming.single.id);
    final conv = await b.openConversation(SocialActor(a), SocialActor(bb));
    final post = await b.createPost(SocialActor(a), type: 'text', body: 'Public', audience: Audience.everyone);
    await b.toggleFollow(SocialActor(bb), a);

    await b.block(SocialActor(a), bb);
    await refresh();
    expect(c.read(friendIdsProvider(a)), isEmpty);
    expect(c.read(followingProvider(bb)), isEmpty);
    expect(c.read(feedProvider((bb, FeedMode.recent))).map((p) => p.id), isNot(contains(post)));
    await expectLater(b.sendRequest(SocialActor(bb), a), throwsA(_denied('blocked')));
    await expectLater(b.sendMessage(SocialActor(bb), conv, body: 'hi'), throwsA(_denied('blocked')));
    await expectLater(b.toggleReact(SocialActor(bb), post, 'like'), throwsA(_denied('privacy')));

    await b.unblock(SocialActor(a), bb);
    await refresh();
    expect(c.read(blockedIdsProvider(a)), isEmpty);
    await b.sendRequest(SocialActor(bb), a);
  });

  test('privacy: request and notification preferences are enforced', () async {
    final a = await b.createProfile(username: 'private_sys', systemName: 'Private');
    final bb = await b.createProfile(username: 'other_sys', systemName: 'Other');
    await b.updateProfile(a, {'privacy': {'requests': 'nobody'}});
    await expectLater(b.sendRequest(SocialActor(bb), a), throwsA(_denied('privacy')));

    await b.updateProfile(a, {'privacy': {'requests': 'everyone', 'messages': 'everyone'}, 'notify': {'request': false}});
    await b.sendRequest(SocialActor(bb), a);
    await refresh();
    expect(c.read(notificationsProvider(a)), isEmpty, reason: 'request notifications are off');
    // "Everyone" can message without being friends.
    await b.openConversation(SocialActor(bb), SocialActor(a));
  });

  test('profile theme toggle and acting identity', () async {
    final a = await b.createProfile(username: 'themed', systemName: 'Themed', primary: true);
    final bb = await b.createProfile(username: 'second', systemName: 'Second');
    await b.updateProfile(a, {'theme': {'accent': 0xFF7C4DFF, 'font': 'serif', 'layout': 'centered'}, 'useTheme': true});
    await refresh();
    var p = c.read(socialProfileByIdProvider(a))!;
    expect(p.useCustomTheme, isTrue);
    expect(p.theme['layout'], 'centered');
    await b.updateProfile(a, {'useTheme': false});
    await refresh();
    p = c.read(socialProfileByIdProvider(a))!;
    expect(p.useCustomTheme, isFalse);
    expect(p.theme['accent'], 0xFF7C4DFF, reason: 'turning the theme off keeps it for later');

    // Falls back to the primary system, then follows the user's choice.
    expect(c.read(actingProvider), SocialActor(a));
    await c.read(actingStoredProvider.notifier).set(SocialActor(bb));
    expect(c.read(actingProvider), SocialActor(bb));
    // A stored alter that no longer exists falls back to its system.
    await c.read(actingStoredProvider.notifier).set(SocialActor(bb, 'missing'));
    expect(c.read(actingProvider), SocialActor(bb));
  });

  test('pinning and reports', () async {
    final a = await b.createProfile(username: 'pinner', systemName: 'Pinner');
    final bb = await b.createProfile(username: 'reporter', systemName: 'Reporter');
    final post = await b.createPost(SocialActor(a), type: 'text', body: 'Pin me', audience: Audience.everyone);
    await expectLater(b.togglePinPost(SocialActor(bb), post), throwsA(_denied('not_owner')));
    await b.togglePinPost(SocialActor(a), post);
    await b.report(SocialActor(bb), targetType: 'post', targetId: post, reason: 'spam');
    await refresh();
    expect(c.read(socialProfileByIdProvider(a))!.pinnedPosts, [post]);
    expect((await repo.getAll()).where((r) => r.kind == SocKind.report).single.str('target'), post);
  });
}
