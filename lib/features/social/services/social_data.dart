import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/social/models/social.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';

/// Indexed view of every social record, rebuilt only when the records
/// change (one pass over the list).
@immutable
class SocialData {
  SocialData(Iterable<TrackerRecord> all, {required this.members, DateTime? now}) : now = now ?? DateTime.now() {
    for (final r in all) {
      switch (r.kind) {
        case SocialKind.post:
          final p = Post(r);
          posts[p.id] = p;
        case SocialKind.comment:
          (commentsOn[r.parentId ?? ''] ??= []).add(Comment(r));
        case SocialKind.reaction:
          (reactionsOn[r.parentId ?? ''] ??= []).add(r);
        case SocialKind.vote:
          (votesOn[r.parentId ?? ''] ??= []).add(r);
        case SocialKind.follow:
          final target = r.str('target');
          if (r.memberId != null && target != null) {
            (following[r.memberId!] ??= {})[target] = r.id;
            _followTime[r.id] = r.createdAt;
            (followers[target] ??= {}).add(r.memberId!);
          }
        case SocialKind.block:
          final target = r.str('target');
          if (r.memberId != null && target != null) {
            (r.str('mode') == 'mute' ? muted : blocked)[r.memberId!] ??= {};
            (r.str('mode') == 'mute' ? muted : blocked)[r.memberId!]![target] = r.id;
          }
        case SocialKind.hide:
          if (r.memberId != null && r.parentId != null) (hidden[r.memberId!] ??= {})[r.parentId!] = r.id;
        case SocialKind.report:
          reports.add(r);
        case SocialKind.profile:
          if (r.memberId != null) profileRecords[r.memberId!] = r;
        case SocialKind.seen:
          if (r.memberId != null) seenRecords[r.memberId!] = r;
        case SocialKind.media:
          mediaRecords[r.id] = r;
        case SocialKind.story:
          final s = Story(r);
          stories[s.id] = s;
        case SocialKind.storyView:
          if (r.memberId != null && r.parentId != null) {
            (storyViews[r.parentId!] ??= {})[r.memberId!] = r.createdAt;
            (_storyViewIds[r.parentId!] ??= []).add(r.id);
          }
        case SocialKind.highlight:
          final h = Highlight(r);
          highlights[h.id] = h;
      }
    }
    for (final c in commentsOn.values) {
      c.sort((a, b) => a.at.compareTo(b.at));
    }
    for (final p in posts.values) {
      final source = p.reblogOf ?? p.quoteOf;
      if (source != null) (sharesOf[source] ??= []).add(p);
    }
  }

  final DateTime now;
  final Map<String, Member> members;
  final posts = <String, Post>{};
  final commentsOn = <String, List<Comment>>{};
  final reactionsOn = <String, List<TrackerRecord>>{};
  final votesOn = <String, List<TrackerRecord>>{};

  /// follower → {target → record id}
  final following = <String, Map<String, String>>{};
  final followers = <String, Set<String>>{};
  final blocked = <String, Map<String, String>>{};
  final muted = <String, Map<String, String>>{};
  final hidden = <String, Map<String, String>>{};
  final reports = <TrackerRecord>[];
  final profileRecords = <String, TrackerRecord>{};
  final seenRecords = <String, TrackerRecord>{};
  final mediaRecords = <String, TrackerRecord>{};
  final stories = <String, Story>{};
  final storyViews = <String, Map<String, DateTime>>{};
  final highlights = <String, Highlight>{};
  final sharesOf = <String, List<Post>>{};

  BlogProfile profile(String memberId) => BlogProfile.of(profileRecords[memberId]);

  bool isBlocked(String viewer, String other) =>
      (blocked[viewer]?.containsKey(other) ?? false) || (blocked[other]?.containsKey(viewer) ?? false);

  bool isMuted(String viewer, String other) => muted[viewer]?.containsKey(other) ?? false;

  bool follows(String viewer, String target) => following[viewer]?.containsKey(target) ?? false;

  /// Whether [viewer] may see something with this author/audience.
  /// A null viewer (nobody picked) sees only "everyone" content.
  bool canSee({required String? author, required Audience audience, required List<String> audienceIds, required String? viewer}) {
    if (author != null && author == viewer) return true;
    if (viewer != null && author != null && isBlocked(viewer, author)) return false;
    return switch (audience) {
      Audience.everyone => true,
      Audience.followers => viewer != null && author != null && follows(viewer, author),
      Audience.selected => viewer != null && audienceIds.contains(viewer),
      Audience.self => false,
    };
  }

  bool canSeePost(Post p, String? viewer) {
    if (!p.isLive(now) && p.author != viewer) return false;
    if (!p.isLive(now)) return p.author == viewer;
    return canSee(author: p.author, audience: p.audience, audienceIds: p.audienceIds, viewer: viewer);
  }

  bool canSeeStory(Story s, String? viewer) =>
      canSee(author: s.author, audience: s.audience, audienceIds: s.audienceIds, viewer: viewer);

  /// The original a reblog points at (reblogs of reblogs resolve to the root).
  Post? original(Post p) {
    var cur = p;
    for (var i = 0; i < 20 && cur.reblogOf != null; i++) {
      final next = posts[cur.reblogOf!];
      if (next == null) return null;
      cur = next;
    }
    return cur;
  }

  /// Reaction counts by emoji, and which ones [viewer] used.
  ({Map<String, int> counts, Set<String> mine}) reactions(String targetId, String? viewer) {
    final counts = <String, int>{};
    final mine = <String>{};
    for (final r in reactionsOn[targetId] ?? const <TrackerRecord>[]) {
      counts[r.title] = (counts[r.title] ?? 0) + 1;
      if (r.memberId == viewer) mine.add(r.title);
    }
    return (counts: counts, mine: mine);
  }

  /// Poll results: votes per option index and the viewer's choices.
  ({List<int> counts, Set<int> mine, int voters}) poll(Post p, String? viewer) {
    final counts = List<int>.filled(p.pollOptions.length, 0);
    final mine = <int>{};
    final votes = votesOn[p.id] ?? const <TrackerRecord>[];
    for (final v in votes) {
      for (final s in v.strings('options')) {
        final i = int.tryParse(s);
        if (i != null && i >= 0 && i < counts.length) {
          counts[i]++;
          if (v.memberId == viewer) mine.add(i);
        }
      }
    }
    return (counts: counts, mine: mine, voters: votes.map((v) => v.memberId).toSet().length);
  }

  List<Post> sortedPosts(Iterable<Post> list) => list.toList()..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

  /// What [viewer] sees in a feed.
  ///
  /// `following`: posts by alters they follow (plus their own), newest
  /// first. `everything`: every visible post, newest first. `forYou`:
  /// everything, ranked by recency with a boost for followed authors and
  /// for posts with interaction.
  List<Post> feed(String? viewer, {String mode = 'everything', String? tag, String query = ''}) {
    final q = query.trim().toLowerCase();
    final t = tag == null ? null : normalizeTag(tag);
    final list = <Post>[];
    for (final p in posts.values) {
      if (!p.isLive(now) || !canSeePost(p, viewer)) continue;
      final author = p.author;
      if (viewer != null && author != null && author != viewer) {
        if (isMuted(viewer, author)) continue;
        if (hidden[viewer]?.containsKey(p.id) ?? false) continue;
        if (mode == 'following' && !follows(viewer, author)) continue;
      }
      final original = this.original(p);
      if (p.reblogOf != null && original == null) continue;
      if (t != null && !p.tags.contains(t) && !(original?.tags.contains(t) ?? false)) continue;
      if (q.isNotEmpty) {
        final hay = '${p.title} ${p.body} ${p.tags.join(' ')} ${original?.title ?? ''} ${original?.body ?? ''} ${members[author]?.name ?? ''}'.toLowerCase();
        if (!hay.contains(q)) continue;
      }
      list.add(p);
    }
    if (mode != 'forYou') return sortedPosts(list);
    double score(Post p) {
      final ageH = now.difference(p.publishedAt).inMinutes / 60;
      final interactions = (reactionsOn[p.id]?.length ?? 0) + (commentsOn[p.id]?.length ?? 0) * 2 + (sharesOf[p.id]?.length ?? 0) * 3;
      final followed = viewer != null && p.author != null && follows(viewer, p.author!) ? 1.5 : 1.0;
      return followed * (1 + interactions * 0.3) / (1 + ageH / 12);
    }

    return list..sort((a, b) => score(b).compareTo(score(a)));
  }

  /// Posts on an alter's blog: pinned first, then newest.
  List<Post> blog(String memberId, String? viewer) {
    final list = [
      for (final p in posts.values)
        if (p.author == memberId && p.isLive(now) && canSeePost(p, viewer)) p,
    ];
    return list..sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.publishedAt.compareTo(a.publishedAt);
    });
  }

  List<Post> drafts(String memberId) => sortedPosts(posts.values.where((p) => p.author == memberId && p.status == PostStatus.draft));

  List<Post> scheduled(String memberId) =>
      posts.values.where((p) => p.author == memberId && p.status == PostStatus.scheduled && p.publishedAt.isAfter(now)).toList()
        ..sort((a, b) => a.publishedAt.compareTo(b.publishedAt));

  /// Tags in use, most popular first.
  List<(String, int)> trendingTags(String? viewer) {
    final counts = <String, int>{};
    for (final p in posts.values) {
      if (!p.isLive(now) || !canSeePost(p, viewer)) continue;
      for (final t in p.tags) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    return [for (final e in counts.entries) (e.key, e.value)]..sort((a, b) => b.$2.compareTo(a.$2));
  }

  // ------------------------------------------------------------ stories

  /// Active stories by author, oldest first within each author.
  Map<String, List<Story>> activeStories(String? viewer) {
    final out = <String, List<Story>>{};
    for (final s in stories.values) {
      if (s.author == null || !s.isActive(now) || !canSeeStory(s, viewer) || s.slides.isEmpty) continue;
      if (viewer != null && s.author != viewer && isMuted(viewer, s.author!)) continue;
      (out[s.author!] ??= []).add(s);
    }
    for (final l in out.values) {
      l.sort((a, b) => a.postedAt.compareTo(b.postedAt));
    }
    return out;
  }

  bool hasSeen(String storyId, String? viewer) => viewer != null && (storyViews[storyId]?.containsKey(viewer) ?? false);

  /// Expired stories the author chose to archive.
  List<Story> archive(String memberId) =>
      stories.values.where((s) => s.author == memberId && !s.isActive(now) && s.archived).toList()
        ..sort((a, b) => b.postedAt.compareTo(a.postedAt));

  List<Highlight> highlightsOf(String memberId) =>
      highlights.values.where((h) => h.owner == memberId).toList()..sort((a, b) => a.r.sortOrder.compareTo(b.r.sortOrder));

  // ------------------------------------------------------- notifications

  DateTime lastSeen(String memberId) => seenRecords[memberId]?.occurredAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  /// Activity aimed at [memberId] (newest first): reactions to their posts,
  /// comments and stories, replies, reblogs, quotes, mentions, follows,
  /// votes, story replies and questions asked to them.
  List<SocialNotification> notifications(String memberId) {
    final out = <SocialNotification>[];
    final me = members[memberId];
    final myPosts = {for (final p in posts.values) if (p.author == memberId) p.id};
    final myComments = <String>{};
    for (final list in commentsOn.values) {
      for (final c in list) {
        if (c.author == memberId) myComments.add(c.id);
      }
    }
    final myStories = {for (final s in stories.values) if (s.author == memberId) s.id};
    bool skip(String? actor) => actor == null || actor == memberId || isBlocked(memberId, actor) || isMuted(memberId, actor);

    for (final e in reactionsOn.entries) {
      final kind = myPosts.contains(e.key)
          ? 'reactPost'
          : myComments.contains(e.key)
          ? 'reactComment'
          : myStories.contains(e.key)
          ? 'reactStory'
          : null;
      if (kind == null) continue;
      for (final r in e.value) {
        if (skip(r.memberId)) continue;
        out.add(SocialNotification(kind, r.memberId!, r.createdAt, targetId: e.key, detail: r.title));
      }
    }
    for (final e in commentsOn.entries) {
      for (final c in e.value) {
        if (skip(c.author)) continue;
        if (myPosts.contains(e.key)) {
          out.add(SocialNotification('comment', c.author!, c.at, targetId: e.key, detail: c.body));
        } else if (myStories.contains(e.key)) {
          out.add(SocialNotification('storyReply', c.author!, c.at, targetId: e.key, detail: c.body));
        } else if (c.replyTo != null && myComments.contains(c.replyTo)) {
          out.add(SocialNotification('reply', c.author!, c.at, targetId: e.key, detail: c.body));
        }
      }
    }
    final mentionNames = me == null ? const <String>{} : {me.name.toLowerCase().replaceAll(' ', ''), ...?me.displayName?.split(RegExp(r'\s+')).map((x) => x.toLowerCase())};
    bool mentionsMe(String text) => mentionPattern.allMatches(text).any((m) => mentionNames.contains(m.group(1)!.toLowerCase()));
    for (final p in posts.values) {
      if (!p.isLive(now) || skip(p.author) || !canSeePost(p, memberId)) continue;
      final source = p.reblogOf ?? p.quoteOf;
      if (source != null && myPosts.contains(source)) {
        out.add(SocialNotification(p.quoteOf != null ? 'quote' : 'reblog', p.author!, p.publishedAt, targetId: p.id));
      }
      if (mentionsMe('${p.title} ${p.body}')) out.add(SocialNotification('mention', p.author!, p.publishedAt, targetId: p.id));
      if (p.type == PostType.question && p.askedTo == memberId) out.add(SocialNotification('question', p.author!, p.publishedAt, targetId: p.id));
    }
    for (final list in commentsOn.values) {
      for (final c in list) {
        if (!skip(c.author) && mentionsMe(c.body)) out.add(SocialNotification('mention', c.author!, c.at, targetId: c.target, detail: c.body));
      }
    }
    for (final f in followers[memberId] ?? const <String>{}) {
      if (skip(f)) continue;
      final id = following[f]?[memberId];
      out.add(SocialNotification('follow', f, id == null ? now : (_followTime[id] ?? now)));
    }
    for (final e in votesOn.entries) {
      if (!myPosts.contains(e.key)) continue;
      for (final v in e.value) {
        if (!skip(v.memberId)) out.add(SocialNotification('vote', v.memberId!, v.createdAt, targetId: e.key));
      }
    }
    out.sort((a, b) => b.at.compareTo(a.at));
    return out;
  }

  final _followTime = <String, DateTime>{};
  final _storyViewIds = <String, List<String>>{};

  /// Record ids of a story's views (for deleting a story).
  List<String> storyViewRecordIds(String storyId) => _storyViewIds[storyId] ?? const [];

  int unreadCount(String memberId) {
    final since = lastSeen(memberId);
    return notifications(memberId).where((n) => n.at.isAfter(since)).length;
  }
}

@immutable
class SocialNotification {
  const SocialNotification(this.kind, this.actor, this.at, {this.targetId, this.detail});

  /// reactPost, reactComment, reactStory, comment, reply, storyReply,
  /// reblog, quote, mention, question, follow, vote.
  final String kind;
  final String actor;
  final DateTime at;
  final String? targetId;
  final String? detail;
}

final socialRecordsProvider = Provider<List<TrackerRecord>>((ref) {
  final all = ref.watch(trackerRecordsProvider).value ?? const <TrackerRecord>[];
  return [for (final r in all) if (SocialKind.all.contains(r.kind)) r];
});

/// Rebuilt when social records or members change; screens select from it.
final socialDataProvider = Provider<SocialData>((ref) {
  final records = ref.watch(socialRecordsProvider);
  final members = ref.watch(allMembersProvider).value ?? const <Member>[];
  return SocialData(records, members: {for (final m in members) m.id: m});
});

/// Whether the social records have loaded at least once.
final socialLoadedProvider = Provider<bool>((ref) => ref.watch(trackerRecordsProvider).hasValue);
