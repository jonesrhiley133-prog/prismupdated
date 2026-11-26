import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/social/models/social.dart';
import 'package:prism_plurality/features/social/services/social_data.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';

/// Everything that changes the in-system social layer. Every write names
/// its alter explicitly ([actor]) — it is never inferred from the front.
class SocialActions {
  SocialActions(this.ref);
  final Ref ref;

  TrackerNotifier get _t => ref.read(trackerNotifierProvider.notifier);
  SocialData get _d => ref.read(socialDataProvider);

  // ----------------------------------------------------------------- posts

  Future<TrackerRecord> createPost({
    required String actor,
    PostType type = PostType.text,
    String title = '',
    String body = '',
    List<String> tags = const [],
    List<String> images = const [],
    String? video,
    String? trackId,
    List<String> pollOptions = const [],
    bool pollMulti = false,
    DateTime? pollCloses,
    String? askedTo,
    String? cw,
    Audience audience = Audience.everyone,
    List<String> audienceIds = const [],
    PostStatus status = PostStatus.published,
    DateTime? scheduledFor,
    String? reblogOf,
    String? quoteOf,
  }) {
    final allTags = {
      ...tags.map(normalizeTag).where((t) => t.isNotEmpty),
      ...extractTags('$title $body'),
    }.toList();
    return _t.create(
      kind: SocialKind.post,
      memberId: actor,
      title: title,
      body: body,
      tags: allTags,
      occurredAt: status == PostStatus.scheduled
          ? scheduledFor
          : DateTime.now(),
      fields: {
        'type': type.name,
        'status': status.name,
        'audience': audience.name,
        if (audience == Audience.selected) 'audienceIds': audienceIds,
        if (images.isNotEmpty) 'images': images,
        'video': ?video,
        'trackId': ?trackId,
        if (pollOptions.isNotEmpty) 'pollOptions': pollOptions,
        if (pollMulti) 'pollMulti': true,
        if (pollCloses != null) 'pollCloses': pollCloses.millisecondsSinceEpoch,
        'askedTo': ?askedTo,
        if (cw != null && cw.trim().isNotEmpty) 'cw': cw.trim(),
        'reblogOf': ?reblogOf,
        'quoteOf': ?quoteOf,
      },
    );
  }

  /// Saves edits to a post; marks published posts as edited.
  Future<void> updatePost(
    Post p, {
    String? title,
    String? body,
    List<String>? tags,
    List<String>? images,
    String? cw,
    Audience? audience,
    List<String>? audienceIds,
    PostStatus? status,
    DateTime? scheduledFor,
  }) {
    final newStatus = status ?? p.status;
    final t = title ?? p.title, b = body ?? p.body;
    final record = p.r.copyWith(
      title: t,
      body: b,
      tags: {
        ...(tags ?? p.tags).map(normalizeTag).where((x) => x.isNotEmpty),
        ...extractTags('$t $b'),
      }.toList(),
      occurredAt: switch (newStatus) {
        PostStatus.scheduled => scheduledFor ?? p.publishedAt,
        // Publishing a draft or scheduled post now dates it now.
        PostStatus.published when p.status != PostStatus.published =>
          DateTime.now(),
        _ => p.r.occurredAt,
      },
    );
    return _t.save(
      record.withFields({
        'status': newStatus.name,
        'audience': (audience ?? p.audience).name,
        'audienceIds': (audience ?? p.audience) == Audience.selected
            ? (audienceIds ?? p.audienceIds)
            : null,
        'images': ?images,
        'cw': cw == null
            ? p.contentWarning
            : (cw.trim().isEmpty ? null : cw.trim()),
        if (p.status == PostStatus.published &&
            newStatus == PostStatus.published)
          'editedAt': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  /// Deletes a post with its comments, reactions and votes. Reblogs of it
  /// stop showing (their original is gone); quotes keep their own text.
  Future<void> deletePost(String id) async {
    final d = _d;
    for (final c in d.commentsOn[id] ?? const <Comment>[]) {
      await _deleteTarget(c.id);
    }
    await _deleteTarget(id);
    for (final v in d.votesOn[id] ?? const <TrackerRecord>[]) {
      await _t.delete(v.id, children: false);
    }
  }

  Future<void> _deleteTarget(String id) async {
    for (final r in _d.reactionsOn[id] ?? const <TrackerRecord>[]) {
      await _t.delete(r.id, children: false);
    }
    await _t.delete(id, children: false);
  }

  Future<void> togglePin(Post p) => _t.save(p.r.copyWith(isPinned: !p.pinned));

  Future<TrackerRecord> reblog({
    required String actor,
    required Post post,
    String comment = '',
    List<String> tags = const [],
  }) => createPost(
    actor: actor,
    body: comment,
    tags: tags,
    reblogOf: _d.original(post)?.id ?? post.id,
  );

  Future<TrackerRecord> quote({
    required String actor,
    required Post post,
    required String body,
    List<String> tags = const [],
  }) => createPost(actor: actor, body: body, tags: tags, quoteOf: post.id);

  // ------------------------------------------------------------ reactions

  /// Adds or removes [emoji] by [actor] on a post, comment or story.
  Future<void> toggleReaction({
    required String actor,
    required String targetId,
    required String emoji,
  }) async {
    final existing = (_d.reactionsOn[targetId] ?? const <TrackerRecord>[])
        .where((r) => r.memberId == actor && r.title == emoji)
        .firstOrNull;
    if (existing != null) {
      await _t.delete(existing.id, children: false);
    } else {
      await _t.create(
        kind: SocialKind.reaction,
        memberId: actor,
        parentId: targetId,
        title: emoji,
      );
    }
  }

  // ------------------------------------------------------------- comments

  Future<TrackerRecord> comment({
    required String actor,
    required String targetId,
    required String body,
    String? replyTo,
  }) => _t.create(
    kind: SocialKind.comment,
    memberId: actor,
    parentId: targetId,
    body: body.trim(),
    fields: {'replyTo': ?replyTo},
  );

  Future<void> editComment(Comment c, String body) => _t.save(
    c.r.copyWith(body: body.trim()).withFields({
      'editedAt': DateTime.now().millisecondsSinceEpoch,
    }),
  );

  /// Deletes a comment and the replies under it.
  Future<void> deleteComment(Comment c) async {
    final all = _d.commentsOn[c.target] ?? const <Comment>[];
    final doomed = <String>{c.id};
    var grew = true;
    while (grew) {
      grew = false;
      for (final x in all) {
        if (x.replyTo != null && doomed.contains(x.replyTo) && doomed.add(x.id))
          grew = true;
      }
    }
    for (final id in doomed) {
      await _deleteTarget(id);
    }
  }

  // ---------------------------------------------------------------- polls

  Future<void> vote({
    required String actor,
    required Post post,
    required int option,
  }) async {
    final mine = (_d.votesOn[post.id] ?? const <TrackerRecord>[])
        .where((v) => v.memberId == actor)
        .firstOrNull;
    if (post.pollCloses != null && DateTime.now().isAfter(post.pollCloses!))
      return;
    final current = mine?.strings('options').toSet() ?? <String>{};
    final key = '$option';
    final next = post.pollMulti
        ? (current.contains(key) ? (current..remove(key)) : (current..add(key)))
        : (current.contains(key) ? <String>{} : {key});
    if (mine == null) {
      if (next.isNotEmpty)
        await _t.create(
          kind: SocialKind.vote,
          memberId: actor,
          parentId: post.id,
          fields: {'options': next.toList()},
        );
    } else if (next.isEmpty) {
      await _t.delete(mine.id, children: false);
    } else {
      await _t.save(mine.withFields({'options': next.toList()}));
    }
  }

  // --------------------------------------------------------------- social

  Future<void> toggleFollow({
    required String actor,
    required String target,
  }) async {
    if (actor == target) return;
    final id = _d.following[actor]?[target];
    if (id != null) {
      await _t.delete(id, children: false);
    } else {
      await _t.create(
        kind: SocialKind.follow,
        memberId: actor,
        fields: {'target': target},
      );
    }
  }

  /// [mode] 'block' (no interaction either way) or 'mute' (hide their content).
  Future<void> toggleBlock({
    required String actor,
    required String target,
    String mode = 'block',
  }) async {
    final id = (mode == 'mute' ? _d.muted : _d.blocked)[actor]?[target];
    if (id != null) {
      await _t.delete(id, children: false);
      return;
    }
    await _t.create(
      kind: SocialKind.block,
      memberId: actor,
      fields: {'target': target, 'mode': mode},
    );
    if (mode == 'block') {
      // Blocking also ends follows in both directions.
      for (final pair in [(actor, target), (target, actor)]) {
        final f = _d.following[pair.$1]?[pair.$2];
        if (f != null) await _t.delete(f, children: false);
      }
    }
  }

  Future<void> toggleHide({
    required String actor,
    required String postId,
  }) async {
    final id = _d.hidden[actor]?[postId];
    if (id != null) {
      await _t.delete(id, children: false);
    } else {
      await _t.create(kind: SocialKind.hide, memberId: actor, parentId: postId);
    }
  }

  /// Flags a post for the system to review (Bulletin Board → Reported).
  Future<void> report({
    required String actor,
    required String targetId,
    required String reason,
  }) async {
    await _t.create(
      kind: SocialKind.report,
      memberId: actor,
      parentId: targetId,
      body: reason.trim(),
    );
    await toggleHide(actor: actor, postId: targetId);
  }

  Future<void> resolveReport(TrackerRecord report) =>
      _t.delete(report.id, children: false);

  Future<void> saveProfile(String memberId, BlogProfile profile) async {
    final existing = _d.profileRecords[memberId];
    if (existing == null) {
      await _t.create(
        kind: SocialKind.profile,
        memberId: memberId,
        body: profile.bio,
        fields: profile.fields(),
      );
    } else {
      await _t.save(
        existing.copyWith(body: profile.bio).withFields(profile.fields()),
      );
    }
  }

  /// Marks [memberId]'s notifications as read up to now.
  Future<void> markSeen(String memberId) async {
    final existing = _d.seenRecords[memberId];
    if (existing == null) {
      await _t.create(
        kind: SocialKind.seen,
        memberId: memberId,
        occurredAt: DateTime.now(),
      );
    } else {
      await _t.save(existing.copyWith(occurredAt: DateTime.now()));
    }
  }

  // -------------------------------------------------------------- stories

  Future<TrackerRecord> postStory({
    required String actor,
    required List<StorySlide> slides,
    String? trackId,
    Audience audience = Audience.everyone,
    List<String> audienceIds = const [],
    bool archive = true,
  }) => _t.create(
    kind: SocialKind.story,
    memberId: actor,
    occurredAt: DateTime.now(),
    fields: {
      'slides': [for (final s in slides) s.toJson()],
      'trackId': ?trackId,
      'audience': audience.name,
      if (audience == Audience.selected) 'audienceIds': audienceIds,
      'archive': archive,
    },
  );

  Future<void> setStoryArchived(Story s, bool archived) =>
      _t.save(s.r.withFields({'archive': archived}));

  Future<void> deleteStory(Story s) async {
    for (final h in _d.highlights.values.where(
      (h) => h.storyIds.contains(s.id),
    )) {
      await _t.save(
        h.r.withFields({
          'stories': [
            for (final x in h.storyIds)
              if (x != s.id) x,
          ],
        }),
      );
    }
    for (final c in _d.commentsOn[s.id] ?? const <Comment>[]) {
      await _deleteTarget(c.id);
    }
    await _deleteTarget(s.id);
    for (final v in _d.storyViewRecordIds(s.id)) {
      await _t.delete(v, children: false);
    }
  }

  /// Records that [viewer] watched [story] (once per alter).
  Future<void> markViewed({
    required String viewer,
    required Story story,
  }) async {
    if (story.author == viewer || _d.hasSeen(story.id, viewer)) return;
    await _t.create(
      kind: SocialKind.storyView,
      memberId: viewer,
      parentId: story.id,
    );
  }

  Future<TrackerRecord> createHighlight({
    required String owner,
    required String title,
    String category = '',
    List<String> storyIds = const [],
  }) => _t.create(
    kind: SocialKind.highlight,
    memberId: owner,
    title: title.trim(),
    sortOrder: _d.highlightsOf(owner).length,
    fields: {'category': category.trim(), 'stories': storyIds},
  );

  Future<void> updateHighlight(
    Highlight h, {
    String? title,
    String? category,
    List<String>? storyIds,
    String? cover,
  }) => _t.save(
    h.r.copyWith(title: title?.trim() ?? h.title).withFields({
      'category': category?.trim() ?? h.category,
      'stories': storyIds ?? h.storyIds,
      'cover': cover ?? h.cover,
    }),
  );

  /// Adds a story to a highlight; highlighted stories are always archived
  /// so they outlive the 24 hours.
  Future<void> addToHighlight(Highlight h, Story s) async {
    if (!s.archived) await setStoryArchived(s, true);
    if (!h.storyIds.contains(s.id))
      await updateHighlight(h, storyIds: [...h.storyIds, s.id]);
  }

  Future<void> deleteHighlight(Highlight h) => _t.delete(h.id, children: false);
}

final socialActionsProvider = Provider<SocialActions>(SocialActions.new);
