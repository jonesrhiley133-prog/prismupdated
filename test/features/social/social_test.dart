import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/core/database/app_database.dart' show AppDatabase;
import 'package:prism_plurality/core/database/database_provider.dart';
import 'package:prism_plurality/core/sync/prism_sync_providers.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/social/models/social.dart';
import 'package:prism_plurality/features/social/services/social_actions.dart';
import 'package:prism_plurality/features/social/services/social_data.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';

final _now = DateTime(2026, 11, 13, 12);
var _seq = 0;

TrackerRecord r(String kind, {String? member, String? parent, String title = '', String? body, Map<String, Object?>? f, DateTime? at, DateTime? created, List<String> tags = const [], bool pinned = false}) =>
    TrackerRecord(
      id: 'r${_seq++}',
      kind: kind,
      memberId: member,
      parentId: parent,
      title: title,
      body: body,
      tags: tags,
      data: f == null ? null : jsonEncode(f),
      occurredAt: at ?? _now.subtract(const Duration(hours: 1)),
      isPinned: pinned,
      createdAt: created ?? _now.subtract(const Duration(hours: 1)),
      modifiedAt: _now,
    );

Member m(String id, String name) => Member(id: id, name: name, createdAt: _now);

SocialData data(List<TrackerRecord> records) => SocialData(records, members: {for (final x in [m('a', 'Ash'), m('k', 'Kai'), m('r', 'River')]) x.id: x}, now: _now);

void main() {
  group('visibility and feeds', () {
    test('audiences, blocking, muting and hiding', () {
      final everyone = r(SocialKind.post, member: 'a', body: 'hi all', f: {'audience': 'everyone'});
      final followers = r(SocialKind.post, member: 'a', body: 'followers only', f: {'audience': 'followers'});
      final selected = r(SocialKind.post, member: 'a', body: 'for River', f: {'audience': 'selected', 'audienceIds': ['r']});
      final self = r(SocialKind.post, member: 'a', body: 'diary', f: {'audience': 'self'});
      final follow = r(SocialKind.follow, member: 'k', f: {'target': 'a'});
      final d = data([everyone, followers, selected, self, follow]);
      Set<String> seen(String? viewer) => {for (final p in d.feed(viewer)) p.body};
      expect(seen('a'), {'hi all', 'followers only', 'for River', 'diary'});
      expect(seen('k'), {'hi all', 'followers only'});
      expect(seen('r'), {'hi all', 'for River'});
      expect(seen(null), {'hi all'});
      expect(d.feed('k', mode: 'following').length, 2);
      expect(d.feed('r', mode: 'following'), isEmpty);

      final blocked = data([everyone, r(SocialKind.block, member: 'r', f: {'target': 'a', 'mode': 'block'})]);
      expect(blocked.feed('r'), isEmpty, reason: 'blocker does not see');
      expect(blocked.canSeePost(Post(everyone), 'r'), isFalse);
      final muted = data([everyone, r(SocialKind.block, member: 'k', f: {'target': 'a', 'mode': 'mute'})]);
      expect(muted.feed('k'), isEmpty);
      expect(muted.blog('a', 'k').length, 1, reason: 'muting hides from feeds, not the blog');
      final hidden = data([everyone, r(SocialKind.hide, member: 'k', parent: everyone.id)]);
      expect(hidden.feed('k'), isEmpty);
      expect(hidden.feed('r').length, 1);
    });

    test('drafts and scheduled posts only go live when due', () {
      final draft = r(SocialKind.post, member: 'a', body: 'draft', f: {'status': 'draft'});
      final later = r(SocialKind.post, member: 'a', body: 'later', f: {'status': 'scheduled'}, at: _now.add(const Duration(hours: 2)));
      final due = r(SocialKind.post, member: 'a', body: 'due', f: {'status': 'scheduled'}, at: _now.subtract(const Duration(minutes: 5)));
      final d = data([draft, later, due]);
      expect(d.feed('k').map((p) => p.body), ['due']);
      expect(d.drafts('a').single.body, 'draft');
      expect(d.scheduled('a').single.body, 'later');
    });

    test('reblogs resolve to the original, search and tags work', () {
      final original = r(SocialKind.post, member: 'a', body: 'Painted the #headspace lake', tags: ['headspace', 'art']);
      final reblog = r(SocialKind.post, member: 'k', body: 'so pretty', f: {'reblogOf': original.id}, at: _now);
      final rr = r(SocialKind.post, member: 'r', f: {'reblogOf': reblog.id}, at: _now);
      final quote = r(SocialKind.post, member: 'r', body: 'love this', f: {'quoteOf': original.id}, at: _now);
      final d = data([original, reblog, rr, quote]);
      expect(d.original(Post(rr))!.id, original.id);
      expect(d.feed('a', tag: '#Headspace').length, 3, reason: 'original + two reblogs');
      expect(d.feed('a', query: 'lake').length, greaterThanOrEqualTo(3));
      expect(d.sharesOf[original.id]!.length, 2);
      expect(d.trendingTags('a').first.$1, anyOf('headspace', 'art'));
      // A reblog of a deleted post disappears.
      final orphan = data([reblog]);
      expect(orphan.feed('a'), isEmpty);
    });

    test('blog shows pinned posts first', () {
      final old = r(SocialKind.post, member: 'a', body: 'old pinned', pinned: true, at: _now.subtract(const Duration(days: 3)));
      final fresh = r(SocialKind.post, member: 'a', body: 'fresh', at: _now);
      expect(data([old, fresh]).blog('a', 'k').map((p) => p.body), ['old pinned', 'fresh']);
    });

    test('for-you ranking boosts followed authors and interaction', () {
      final quiet = r(SocialKind.post, member: 'r', body: 'quiet', at: _now.subtract(const Duration(minutes: 30)));
      final popular = r(SocialKind.post, member: 'a', body: 'popular', at: _now.subtract(const Duration(hours: 2)));
      final records = [
        quiet,
        popular,
        r(SocialKind.follow, member: 'k', f: {'target': 'a'}),
        for (final who in ['r', 'a', 'k']) r(SocialKind.reaction, member: who, parent: popular.id, title: '❤️'),
        r(SocialKind.comment, member: 'r', parent: popular.id, body: 'nice'),
      ];
      expect(data(records).feed('k', mode: 'forYou').first.body, 'popular');
      expect(data(records).feed('k').first.body, 'quiet', reason: 'chronological stays chronological');
    });
  });

  test('polls count votes per alter', () {
    final poll = r(SocialKind.post, member: 'a', f: {'type': 'poll', 'pollOptions': ['Tea', 'Coffee'], 'pollMulti': true});
    final d = data([
      poll,
      r(SocialKind.vote, member: 'k', parent: poll.id, f: {'options': ['0', '1']}),
      r(SocialKind.vote, member: 'r', parent: poll.id, f: {'options': ['1']}),
    ]);
    final res = d.poll(Post(poll), 'k');
    expect(res.counts, [1, 2]);
    expect(res.mine, {0, 1});
    expect(res.voters, 2);
  });

  test('notifications cover reactions, replies, reblogs, mentions, follows and questions', () {
    final mine = r(SocialKind.post, member: 'a', body: 'hello');
    final myComment = r(SocialKind.comment, member: 'a', parent: mine.id, body: 'thanks', created: _now.subtract(const Duration(minutes: 50)));
    final records = [
      mine,
      myComment,
      r(SocialKind.reaction, member: 'k', parent: mine.id, title: '🔥', created: _now.subtract(const Duration(minutes: 40))),
      r(SocialKind.reaction, member: 'a', parent: mine.id, title: '❤️'),
      r(SocialKind.comment, member: 'k', parent: mine.id, body: 'reply', f: {'replyTo': myComment.id}, created: _now.subtract(const Duration(minutes: 30))),
      r(SocialKind.post, member: 'r', body: 'hey @Ash look', at: _now.subtract(const Duration(minutes: 20))),
      r(SocialKind.post, member: 'r', f: {'reblogOf': mine.id}, at: _now.subtract(const Duration(minutes: 10))),
      r(SocialKind.post, member: 'k', body: 'what is your favourite colour?', f: {'type': 'question', 'askedTo': 'a'}, at: _now.subtract(const Duration(minutes: 5))),
      r(SocialKind.follow, member: 'r', f: {'target': 'a'}, created: _now.subtract(const Duration(minutes: 1))),
    ];
    final d = data(records);
    final kinds = d.notifications('a').map((n) => n.kind).toList();
    expect(kinds, containsAll(['reactPost', 'comment', 'mention', 'reblog', 'question', 'follow']));
    expect(kinds.where((k) => k == 'reactPost').length, 1, reason: 'own reactions are not notifications');
    expect(d.unreadCount('a'), kinds.length);
    final read = data([...records, r(SocialKind.seen, member: 'a', at: _now)]);
    expect(read.unreadCount('a'), 0);
    final blocked = data([...records, r(SocialKind.block, member: 'a', f: {'target': 'k', 'mode': 'block'})]);
    expect(blocked.notifications('a').any((n) => n.actor == 'k'), isFalse);
  });

  test('stories expire after 24 hours, archive and track views', () {
    final fresh = r(SocialKind.story, member: 'k', f: {'slides': [const StorySlide(text: 'hi').toJson()]}, at: _now.subtract(const Duration(hours: 2)));
    final old = r(SocialKind.story, member: 'k', f: {'slides': [const StorySlide(text: 'old').toJson()], 'archive': true}, at: _now.subtract(const Duration(hours: 30)));
    final gone = r(SocialKind.story, member: 'k', f: {'slides': [const StorySlide(text: 'gone').toJson()], 'archive': false}, at: _now.subtract(const Duration(hours: 30)));
    final private = r(SocialKind.story, member: 'r', f: {'slides': [const StorySlide(text: 'secret').toJson()], 'audience': 'selected', 'audienceIds': ['a']});
    final view = r(SocialKind.storyView, member: 'a', parent: fresh.id);
    final d = data([fresh, old, gone, private, view]);
    expect(d.activeStories('a').keys.toSet(), {'k', 'r'});
    expect(d.activeStories('k').keys.toSet(), {'k'}, reason: 'River\'s story is only for Ash');
    expect(d.activeStories('a')['k']!.single.id, fresh.id);
    expect(d.hasSeen(fresh.id, 'a'), isTrue);
    expect(d.hasSeen(fresh.id, 'r'), isFalse);
    expect(d.archive('k').single.id, old.id);
  });

  test('slides and stickers round-trip with clamping', () {
    const slide = StorySlide(text: 'Hello', background2: 0xFF000000, stickers: [StorySticker(content: '🌈', x: 0.2, y: 0.8, scale: 2)], durationMs: 7000);
    final back = StorySlide.fromJson(jsonDecode(jsonEncode(slide.toJson())));
    expect(back.text, 'Hello');
    expect(back.stickers.single.content, '🌈');
    expect(back.stickers.single.scale, 2);
    expect(StorySlide.fromJson({'ms': 1, 'size': 999}).durationMs, 2000);
    expect(StorySticker.fromJson({'c': 'x', 'x': 5})!.x, 1);
  });

  test('tags and mentions are extracted', () {
    expect(extractTags('Loving #Art and #art and #headspace_maps!'), ['art', 'headspace_maps']);
    expect(normalizeTag('##Spoons '), 'spoons');
  });

  group('actions write to the synced store under the chosen alter', () {
    late AppDatabase db;
    late ProviderContainer c;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      c = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db), prismSyncHandleProvider.overrideWithBuild((ref, n) => null)]);
      c.listen(trackerRecordsProvider, (_, _) {});
    });

    tearDown(() async {
      c.dispose();
      await db.close();
    });

    Future<SocialData> settle() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await c.read(trackerRecordsProvider.future);
      return c.read(socialDataProvider);
    }

    test('post, react, comment, reblog, follow, block, delete', () async {
      final a = c.read(socialActionsProvider);
      final post = await a.createPost(actor: 'a', body: 'First post #hello', audience: Audience.everyone);
      await settle();
      expect(post.memberId, 'a', reason: 'authored by the chosen alter, not the fronter');
      expect(post.tags, ['hello']);
      await a.toggleReaction(actor: 'k', targetId: post.id, emoji: '❤️');
      final comment = await a.comment(actor: 'k', targetId: post.id, body: 'yay');
      await a.comment(actor: 'a', targetId: post.id, body: 'thanks', replyTo: comment.id);
      await settle();
      final p = c.read(socialDataProvider).posts[post.id]!;
      await a.reblog(actor: 'r', post: p, comment: 'nice');
      await a.toggleFollow(actor: 'k', target: 'a');
      var d = await settle();
      expect(d.reactions(post.id, 'k').mine, {'❤️'});
      expect(d.commentsOn[post.id]!.length, 2);
      expect(d.sharesOf[post.id]!.single.author, 'r');
      expect(d.follows('k', 'a'), isTrue);
      await a.toggleReaction(actor: 'k', targetId: post.id, emoji: '❤️');
      await a.toggleBlock(actor: 'a', target: 'k');
      d = await settle();
      expect(d.reactions(post.id, 'k').mine, isEmpty);
      expect(d.follows('k', 'a'), isFalse, reason: 'blocking ends follows');
      await a.deleteComment(d.commentsOn[post.id]!.firstWhere((x) => x.replyTo == null));
      d = await settle();
      expect(d.commentsOn[post.id] ?? const [], isEmpty, reason: 'replies go with their comment');
      await a.deletePost(post.id);
      d = await settle();
      expect(d.posts.containsKey(post.id), isFalse);
      expect(d.feed('r'), isEmpty, reason: 'the reblog disappears with its original');
    });

    test('drafts publish, edits are marked, votes toggle', () async {
      final a = c.read(socialActionsProvider);
      final draft = await a.createPost(actor: 'a', body: 'draft', status: PostStatus.draft);
      await settle();
      await a.updatePost(c.read(socialDataProvider).posts[draft.id]!, status: PostStatus.published);
      var d = await settle();
      expect(d.posts[draft.id]!.status, PostStatus.published);
      expect(d.posts[draft.id]!.editedAt, isNull);
      await a.updatePost(d.posts[draft.id]!, body: 'edited');
      d = await settle();
      expect(d.posts[draft.id]!.editedAt, isNotNull);
      final poll = await a.createPost(actor: 'a', type: PostType.poll, pollOptions: ['x', 'y']);
      d = await settle();
      await a.vote(actor: 'k', post: d.posts[poll.id]!, option: 0);
      d = await settle();
      await a.vote(actor: 'k', post: d.posts[poll.id]!, option: 1);
      d = await settle();
      expect(d.poll(d.posts[poll.id]!, 'k').mine, {1}, reason: 'single choice switches');
    });

    test('stories: post, view once, highlight keeps them', () async {
      final a = c.read(socialActionsProvider);
      final story = await a.postStory(actor: 'r', slides: const [StorySlide(text: 'hi')], archive: false);
      var d = await settle();
      final s = d.stories[story.id]!;
      await a.markViewed(viewer: 'a', story: s);
      d = await settle();
      await a.markViewed(viewer: 'a', story: d.stories[story.id]!);
      await a.markViewed(viewer: 'r', story: d.stories[story.id]!);
      d = await settle();
      expect(d.storyViews[story.id]!.keys, ['a'], reason: 'one view per alter; the author is not counted');
      final h = await a.createHighlight(owner: 'r', title: 'Faves', category: 'Mood');
      d = await settle();
      await a.addToHighlight(d.highlights[h.id]!, d.stories[story.id]!);
      d = await settle();
      expect(d.stories[story.id]!.archived, isTrue);
      expect(d.highlights[h.id]!.storyIds, [story.id]);
      await a.deleteStory(d.stories[story.id]!);
      d = await settle();
      expect(d.highlights[h.id]!.storyIds, isEmpty);
      expect(d.storyViews[story.id], isNull);
    });
  });
}
