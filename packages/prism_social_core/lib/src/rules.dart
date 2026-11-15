// Generated from the app's LocalSocialBackend rules; the app and the server
// both run this code, so a rule only ever lives in one place.
import 'records.dart';
import 'wrappers.dart';

/// Every rule a Prism Social server enforces. [store] is the database; the
/// caller (app or server) decides which profiles an account may act as.
class SocialRules {
  SocialRules(this.store, {this.account, DateTime Function()? clock}) : _clock = clock ?? DateTime.now;
  final SocialStore store;

  /// The server account making the request (null on-device: every profile
  /// in the local store belongs to this person).
  final String? account;
  final DateTime Function() _clock;

  Future<SProfile> _profile(String id) async {
    final r = (await store.all(SocKind.profile)).where((p) => p.id == id).firstOrNull;
    if (r == null) throw const SocialDenied('not_found');
    return SProfile(r);
  }

  /// The actor must exist and be one of this account's profiles/alters.
  Future<void> _managed(SocialActor a) async {
    final p = await _profile(a.profileId);
    if (account != null && p.r.str('owner') != account) throw const SocialDenied('not_managed');
    if (a.alterId != null) {
      final alt = (await store.all(SocKind.alter)).where((x) => x.id == a.alterId && x.parentId == a.profileId).firstOrNull;
      if (alt == null) throw const SocialDenied('not_found');
    }
  }

  /// Checks [profileId] belongs to this account.
  Future<void> owns(String profileId) => _managed(SocialActor(profileId));

  // ── Relationships ──

  Future<bool> isBlocked(String a, String b) async => (await store.all(SocKind.block)).any((r) => (r.str('by') == a && r.str('who') == b) || (r.str('by') == b && r.str('who') == a));
  Future<SocRecord?> friendship(String a, String b) async => (await store.all(SocKind.friendship)).where((r) => {r.str('a'), r.str('b')}.containsAll({a, b})).firstOrNull;
  Future<Set<String>> friendsOf(String p) async => {
    for (final r in await store.all(SocKind.friendship))
      if (r.str('a') == p) r.str('b')! else if (r.str('b') == p) r.str('a')!,
  };
  Future<bool> areFriends(String a, String b) async => (await friendship(a, b)) != null;

  Future<bool> allows(Audience aud, String owner, String viewer) async {
    if (owner == viewer) return true;
    switch (aud) {
      case Audience.everyone:
        return true;
      case Audience.nobody:
        return false;
      case Audience.friends:
        return areFriends(owner, viewer);
      case Audience.friendsOfFriends:
        if (await areFriends(owner, viewer)) return true;
        return (await friendsOf(owner)).intersection(await friendsOf(viewer)).isNotEmpty;
    }
  }

  // ── Profiles ──

  Future<String> createProfile({required String username, required String systemName, String? description, bool primary = false}) async {
    final u = username.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_.]{3,30}$').hasMatch(u)) throw const SocialDenied('invalid', 'username');
    if ((await store.all(SocKind.profile)).any((p) => p.str('username') == u)) throw const SocialDenied('username_taken');
    if (systemName.trim().isEmpty) throw const SocialDenied('invalid', 'systemName');
    final r = await store.create(kind: SocKind.profile, title: systemName.trim(), body: description, fields: {'username': u, 'primary': primary, 'lastActive': _clock().toIso8601String(), 'owner': ?account});
    return r.id;
  }

  Future<void> updateProfile(String profileId, Map<String, Object?> changes, {String? systemName, String? description}) async {
    await owns(profileId);
    changes = {...changes}..remove('owner')..remove('primary');
    final p = await _profile(profileId);
    if (changes['username'] is String) {
      final u = (changes['username']! as String).trim().toLowerCase();
      if (!RegExp(r'^[a-z0-9_.]{3,30}$').hasMatch(u)) throw const SocialDenied('invalid', 'username');
      if ((await store.all(SocKind.profile)).any((x) => x.id != profileId && x.str('username') == u)) throw const SocialDenied('username_taken');
      changes = {...changes, 'username': u};
    }
    await store.save(p.r.copyWith(title: systemName ?? p.r.title, body: description ?? p.r.body).withFields(changes));
  }

  Future<void> touch(String profileId) async {
    await owns(profileId);
    final p = await _profile(profileId);
    final last = p.lastActive;
    if (last != null && _clock().difference(last).inMinutes < 2) return;
    await store.save(p.r.withFields({'lastActive': _clock().toIso8601String()}));
  }

  Future<String> saveAlter(String profileId, {String? editingId, String? memberId, required String name, Map<String, Object?> fields = const {}, String? description}) async {
    await owns(profileId);
    if (name.trim().isEmpty) throw const SocialDenied('invalid', 'name');
    final editing = editingId == null ? null : (await store.all(SocKind.alter)).where((x) => x.id == editingId).firstOrNull;
    if (editingId != null && editing == null) throw const SocialDenied('not_found');
    if (editing != null && editing.parentId != profileId) throw const SocialDenied('not_owner');
    if (editing != null) {
      await store.save(editing.copyWith(title: name, body: description, memberId: memberId).withFields(fields));
      return editing.id;
    }
    final r = await store.create(kind: SocKind.alter, parentId: profileId, memberId: memberId, title: name, body: description, fields: {'visibility': 'friends', ...fields});
    return r.id;
  }

  Future<void> deleteAlter(String profileId, String alterId) async {
    await owns(profileId);
    final a = (await store.all(SocKind.alter)).where((x) => x.id == alterId).firstOrNull;
    if (a == null) throw const SocialDenied('not_found');
    if (a.parentId != profileId) throw const SocialDenied('not_owner');
    await store.delete(alterId);
  }

  // ── Friend requests ──

  Future<void> sendRequest(SocialActor from, String to, {String? note}) async {
    await _managed(from);
    if (from.profileId == to) throw const SocialDenied('self');
    final target = await _profile(to);
    if (await isBlocked(from.profileId, to)) throw const SocialDenied('blocked');
    if (await areFriends(from.profileId, to)) throw const SocialDenied('already_friends');
    final pending = [for (final r in await store.all(SocKind.request)) if (r.str('status') == 'pending') r];
    if (pending.any((r) => r.str('from') == from.profileId && r.str('to') == to)) throw const SocialDenied('duplicate');
    final reverse = pending.where((r) => r.str('from') == to && r.str('to') == from.profileId).firstOrNull;
    if (reverse != null) {
      await acceptRequest(SocialActor(from.profileId), reverse.id);
      return;
    }
    if (!await allows(target.whoCanRequest == Audience.friends ? Audience.nobody : target.whoCanRequest, to, from.profileId)) throw const SocialDenied('privacy');
    final r = await store.create(kind: SocKind.request, occurredAt: _clock(), body: note, fields: {'from': from.profileId, 'to': to, 'status': 'pending'});
    await _notify(to, 'request', from, target: r.id, preview: note);
  }

  Future<void> acceptRequest(SocialActor actor, String requestId) async {
    await _managed(actor);
    final r = (await store.all(SocKind.request)).where((x) => x.id == requestId).firstOrNull;
    if (r == null || r.str('status') != 'pending') throw const SocialDenied('not_found');
    if (r.str('to') != actor.profileId) throw const SocialDenied('not_owner');
    await _managed(actor);
    final from = r.str('from')!;
    if (await isBlocked(from, actor.profileId)) throw const SocialDenied('blocked');
    await store.save(r.withFields({'status': 'accepted', 'resolved': _clock().toIso8601String()}));
    if (!await areFriends(from, actor.profileId)) {
      await store.create(kind: SocKind.friendship, occurredAt: _clock(), fields: {'a': from, 'b': actor.profileId});
    }
    await _notify(from, 'accepted', SocialActor(actor.profileId), target: actor.profileId);
  }

  Future<void> declineRequest(SocialActor actor, String requestId) async {
    await _managed(actor);
    final r = (await store.all(SocKind.request)).where((x) => x.id == requestId).firstOrNull;
    if (r == null || r.str('status') != 'pending') throw const SocialDenied('not_found');
    if (r.str('to') != actor.profileId) throw const SocialDenied('not_owner');
    await store.save(r.withFields({'status': 'declined', 'resolved': _clock().toIso8601String()}));
  }

  Future<void> cancelRequest(SocialActor actor, String requestId) async {
    await _managed(actor);
    final r = (await store.all(SocKind.request)).where((x) => x.id == requestId).firstOrNull;
    if (r == null || r.str('status') != 'pending') throw const SocialDenied('not_found');
    if (r.str('from') != actor.profileId) throw const SocialDenied('not_owner');
    await store.save(r.withFields({'status': 'canceled', 'resolved': _clock().toIso8601String()}));
  }

  Future<void> removeFriend(SocialActor actor, String other) async {
    await _managed(actor);
    final f = await friendship(actor.profileId, other);
    if (f == null) throw const SocialDenied('not_friends');
    await store.delete(f.id);
  }

  Future<void> toggleFavorite(SocialActor actor, String other) async {
    await _managed(actor);
    final f = await friendship(actor.profileId, other);
    if (f == null) throw const SocialDenied('not_friends');
    final favs = f.strings('fav').toSet();
    favs.contains(actor.profileId) ? favs.remove(actor.profileId) : favs.add(actor.profileId);
    await store.save(f.withFields({'fav': favs.toList()}));
  }

  Future<void> toggleFollow(SocialActor actor, String other) async {
    await _managed(actor);
    if (actor.profileId == other) throw const SocialDenied('self');
    if (await isBlocked(actor.profileId, other)) throw const SocialDenied('blocked');
    final f = (await store.all(SocKind.follow)).where((r) => r.str('by') == actor.profileId && r.str('who') == other).firstOrNull;
    if (f != null) {
      await store.delete(f.id);
    } else {
      await store.create(kind: SocKind.follow, fields: {'by': actor.profileId, 'who': other});
    }
  }

  /// Blocking ends the friendship, cancels requests and stops follows.
  Future<void> block(SocialActor actor, String other) async {
    await _managed(actor);
    if (actor.profileId == other) throw const SocialDenied('self');
    if ((await store.all(SocKind.block)).any((r) => r.str('by') == actor.profileId && r.str('who') == other)) return;
    await store.create(kind: SocKind.block, occurredAt: _clock(), fields: {'by': actor.profileId, 'who': other});
    final f = await friendship(actor.profileId, other);
    if (f != null) await store.delete(f.id);
    for (final r in await store.all(SocKind.request)) {
      if (r.str('status') == 'pending' && {r.str('from'), r.str('to')}.containsAll({actor.profileId, other})) await store.save(r.withFields({'status': 'canceled'}));
    }
    for (final r in await store.all(SocKind.follow)) {
      if ({r.str('by'), r.str('who')}.containsAll({actor.profileId, other})) await store.delete(r.id);
    }
  }

  Future<void> unblock(SocialActor actor, String other) async {
    await _managed(actor);
    for (final r in await store.all(SocKind.block)) {
      if (r.str('by') == actor.profileId && r.str('who') == other) await store.delete(r.id);
    }
  }

  Future<void> report(SocialActor actor, {required String targetType, required String targetId, required String reason}) async {
    await _managed(actor);
    await store.create(kind: SocKind.report, occurredAt: _clock(), body: reason, fields: {'by': actor.profileId, 'type': targetType, 'target': targetId, 'status': 'open'});
  }

  // ── Messaging ──

  /// Opens (or reuses) a conversation between [me] and [them]. Checks the
  /// recipient's privacy, blocks and alter settings.
  Future<String> openConversation(SocialActor me, SocialActor them) async {
    await _managed(me);
    if (me.profileId == them.profileId) throw const SocialDenied('self');
    final target = await _profile(them.profileId);
    if (await isBlocked(me.profileId, them.profileId)) throw const SocialDenied('blocked');
    if (!await allows(target.whoCanMessage, them.profileId, me.profileId)) throw const SocialDenied('privacy');
    if (them.alterId != null) {
      final alt = (await store.all(SocKind.alter)).where((x) => x.id == them.alterId).map(SAlter.new).firstOrNull;
      if (alt == null) throw const SocialDenied('not_found');
      final friends = await areFriends(me.profileId, them.profileId);
      if (!target.altersReceiveMessages || !alt.canMessage || (!target.friendsReachAlters && !friends) || !await allows(alt.visibility, them.profileId, me.profileId)) throw const SocialDenied('alters_closed');
    }
    final want = {me.key, them.key};
    for (final c in (await store.all(SocKind.conversation)).map(SConv.new)) {
      if (c.participants.map((p) => p.key).toSet().containsAll(want) && c.participants.length == 2) return c.id;
    }
    final r = await store.create(kind: SocKind.conversation, occurredAt: _clock(), fields: {
      'participants': [me.toJson(), them.toJson()],
      'last': _clock().toIso8601String(),
    });
    return r.id;
  }

  Future<SConv> _conv(String id, SocialActor actor) async {
    final r = (await store.all(SocKind.conversation)).where((x) => x.id == id).firstOrNull;
    if (r == null) throw const SocialDenied('not_found');
    final c = SConv(r);
    if (!c.participants.contains(actor)) throw const SocialDenied('not_participant');
    return c;
  }

  Future<String> sendMessage(SocialActor actor, String conversationId, {String body = '', List<String> media = const [], String? replyTo}) async {
    await _managed(actor);
    final c = await _conv(conversationId, actor);
    if (body.trim().isEmpty && media.isEmpty) throw const SocialDenied('invalid');
    for (final p in c.participants.where((p) => p.profileId != actor.profileId)) {
      if (await isBlocked(actor.profileId, p.profileId)) throw const SocialDenied('blocked');
    }
    final m = await store.create(kind: SocKind.message, parentId: conversationId, occurredAt: _clock(), body: body.trim(), fields: {
      'sender': actor.toJson(),
      'media': media.isEmpty ? null : media,
      'replyTo': replyTo,
      'readBy': {actor.profileId: _clock().toIso8601String()},
    });
    final unread = {...c.unreadMarks}..remove(actor.profileId);
    await store.save(c.r.withFields({'last': _clock().toIso8601String(), 'unread': unread}));
    for (final p in c.participants.where((p) => p.profileId != actor.profileId)) {
      if (!c.mutedBy.contains(p.profileId)) await _notify(p.profileId, p.alterId == null && actor.alterId == null ? 'message' : 'alterMessage', actor, target: conversationId, preview: body.trim().isEmpty ? '📎' : body.trim(), alter: p.alterId);
    }
    return m.id;
  }

  Future<SMessage> _ownMessage(SocialActor actor, String messageId) async {
    await _managed(actor);
    final r = (await store.all(SocKind.message)).where((x) => x.id == messageId).firstOrNull;
    if (r == null) throw const SocialDenied('not_found');
    final m = SMessage(r);
    if (m.sender != actor) throw const SocialDenied('not_owner');
    return m;
  }

  Future<void> editMessage(SocialActor actor, String messageId, String body) async {
    await _managed(actor);
    final m = await _ownMessage(actor, messageId);
    if (body.trim().isEmpty) throw const SocialDenied('invalid');
    await store.save(m.r.copyWith(body: body.trim()).withFields({'edited': true}));
  }

  Future<void> deleteMessage(SocialActor actor, String messageId) async {
    await _managed(actor);
    final m = await _ownMessage(actor, messageId);
    await store.save(m.r.copyWith(body: '').withFields({'deleted': true, 'media': null}));
  }

  Future<void> react(SocialActor actor, String messageId, String emoji) async {
    await _managed(actor);
    final r = (await store.all(SocKind.message)).where((x) => x.id == messageId).firstOrNull;
    if (r == null) throw const SocialDenied('not_found');
    final m = SMessage(r);
    await _conv(m.conversationId, actor);
    final map = {for (final e in m.reactions.entries) e.key: [...e.value]};
    final list = map[emoji] ?? [];
    list.contains(actor.key) ? list.remove(actor.key) : list.add(actor.key);
    if (list.isEmpty) {
      map.remove(emoji);
    } else {
      map[emoji] = list;
    }
    await store.save(m.r.withFields({'reactions': map}));
  }

  Future<void> markRead(SocialActor actor, String conversationId) async {
    await _managed(actor);
    final c = await _conv(conversationId, actor);
    final now = _clock().toIso8601String();
    for (final r in await store.all(SocKind.message)) {
      if (r.parentId != conversationId) continue;
      final m = SMessage(r);
      if (m.sender.profileId == actor.profileId || m.readBy.containsKey(actor.profileId)) continue;
      await store.save(r.withFields({'readBy': {...m.readBy, actor.profileId: now}}));
    }
    if (c.unreadMarks.containsKey(actor.profileId)) await store.save(c.r.withFields({'unread': {...c.unreadMarks}..remove(actor.profileId)}));
  }

  Future<void> markUnread(SocialActor actor, String conversationId) async {
    await _managed(actor);
    final c = await _conv(conversationId, actor);
    await store.save(c.r.withFields({'unread': {...c.unreadMarks, actor.profileId: '1'}}));
  }

  Future<void> toggleMute(SocialActor actor, String conversationId) async {
    await _managed(actor);
    final c = await _conv(conversationId, actor);
    final m = c.mutedBy;
    m.contains(actor.profileId) ? m.remove(actor.profileId) : m.add(actor.profileId);
    await store.save(c.r.withFields({'muted': m.toList()}));
  }

  Future<void> togglePin(SocialActor actor, String conversationId, String messageId) async {
    await _managed(actor);
    final c = await _conv(conversationId, actor);
    final p = [...c.pinned];
    p.contains(messageId) ? p.remove(messageId) : p.insert(0, messageId);
    await store.save(c.r.withFields({'pinned': p}));
  }

  // ── Posts ──

  Future<String> createPost(SocialActor actor, {required String type, String title = '', String body = '', List<String> media = const [], String? link, String? quoteSource, Map<String, Object?>? milestone, Audience? audience, String? circleId}) async {
    await _managed(actor);
    final p = await _profile(actor.profileId);
    if (actor.alterId != null) {
      final alt = (await store.all(SocKind.alter)).where((x) => x.id == actor.alterId).map(SAlter.new).firstOrNull;
      if (alt == null || !alt.canPost) throw const SocialDenied('privacy');
    }
    if (body.trim().isEmpty && media.isEmpty && (link ?? '').isEmpty && milestone == null && title.trim().isEmpty) throw const SocialDenied('invalid');
    final r = await store.create(kind: SocKind.post, title: title.trim(), body: body.trim(), occurredAt: _clock(), fields: {
      'author': actor.toJson(),
      'type': type,
      'media': media.isEmpty ? null : media,
      'link': link,
      'quoteSource': quoteSource,
      'milestone': milestone,
      'audience': (audience ?? p.defaultPostAudience).name,
      'circle': circleId,
    });
    await _mentions(actor, body, r.id);
    return r.id;
  }

  Future<SPost> _post(String id) async {
    final r = (await store.all(SocKind.post)).where((x) => x.id == id).firstOrNull;
    if (r == null) throw const SocialDenied('not_found');
    return SPost(r);
  }

  Future<void> editPost(SocialActor actor, String postId, {String? title, String? body, Audience? audience}) async {
    await _managed(actor);
    final p = await _post(postId);
    if (p.author != actor) throw const SocialDenied('not_owner');
    await store.save(p.r.copyWith(title: title ?? p.r.title, body: body ?? p.r.body).withFields({'edited': true, 'audience': ?audience?.name}));
  }

  Future<void> deletePost(SocialActor actor, String postId) async {
    await _managed(actor);
    final p = await _post(postId);
    if (p.author.profileId != actor.profileId) throw const SocialDenied('not_owner');
    for (final c in await store.all(SocKind.comment)) {
      if (c.parentId == postId) await store.delete(c.id);
    }
    for (final c in await store.all(SocKind.react)) {
      if (c.parentId == postId) await store.delete(c.id);
    }
    await store.delete(postId);
  }

  /// Whether [viewer] may see [post] (audience, circles and blocks).
  Future<bool> canSee(SPost post, String viewer) async {
    final owner = post.author.profileId;
    if (owner == viewer) return true;
    if (await isBlocked(owner, viewer)) return false;
    if (post.audience == Audience.nobody) return false;
    if (post.circleId != null) {
      final c = (await store.all(SocKind.circle)).where((x) => x.id == post.circleId).firstOrNull;
      return c != null && c.strings('members').contains(viewer);
    }
    return allows(post.audience, owner, viewer);
  }

  Future<void> toggleReact(SocialActor actor, String postId, String type) async {
    await _managed(actor);
    final p = await _post(postId);
    if (!await canSee(p, actor.profileId)) throw const SocialDenied('privacy');
    final existing = (await store.all(SocKind.react)).where((r) => r.parentId == postId && r.str('by') == actor.profileId && r.str('type') == type).firstOrNull;
    if (existing != null) {
      await store.delete(existing.id);
      return;
    }
    await store.create(kind: SocKind.react, parentId: postId, occurredAt: _clock(), fields: {'by': actor.profileId, 'actor': actor.toJson(), 'type': type});
    if (type == 'like' && p.author.profileId != actor.profileId) await _notify(p.author.profileId, p.type == 'milestone' ? 'milestoneLike' : 'like', actor, target: postId, preview: p.title.isNotEmpty ? p.title : p.body);
  }

  Future<String> comment(SocialActor actor, String postId, String body, {String? replyTo}) async {
    await _managed(actor);
    final p = await _post(postId);
    if (!await canSee(p, actor.profileId)) throw const SocialDenied('privacy');
    if (body.trim().isEmpty) throw const SocialDenied('invalid');
    final c = await store.create(kind: SocKind.comment, parentId: postId, occurredAt: _clock(), body: body.trim(), fields: {'author': actor.toJson(), 'replyTo': replyTo});
    if (p.author.profileId != actor.profileId) await _notify(p.author.profileId, 'comment', actor, target: postId, preview: body.trim());
    if (replyTo != null) {
      final parent = (await store.all(SocKind.comment)).where((x) => x.id == replyTo).map(SComment.new).firstOrNull;
      if (parent != null && parent.author.profileId != actor.profileId && parent.author.profileId != p.author.profileId) await _notify(parent.author.profileId, 'reply', actor, target: postId, preview: body.trim());
    }
    await _mentions(actor, body, postId);
    return c.id;
  }

  Future<void> deleteComment(SocialActor actor, String commentId) async {
    await _managed(actor);
    final r = (await store.all(SocKind.comment)).where((x) => x.id == commentId).firstOrNull;
    if (r == null) throw const SocialDenied('not_found');
    final c = SComment(r);
    final post = await _post(c.postId);
    if (c.author.profileId != actor.profileId && post.author.profileId != actor.profileId) throw const SocialDenied('not_owner');
    await store.delete(commentId);
  }

  /// Reposts with attribution to the original author (and an optional note).
  Future<String> reblog(SocialActor actor, String postId, {String note = '', Audience? audience}) async {
    await _managed(actor);
    final p = await _post(postId);
    if (!await canSee(p, actor.profileId)) throw const SocialDenied('privacy');
    if (p.audience != Audience.everyone && p.author.profileId != actor.profileId) throw const SocialDenied('privacy', 'only public posts can be reblogged');
    final root = p.origin ?? {'post': p.id, 'author': p.author.toJson(), 'title': p.title, 'body': p.body, 'media': p.media, 'type': p.type, 'link': p.link, 'milestone': p.milestone, 'at': p.at.toIso8601String()};
    final r = await store.create(kind: SocKind.post, body: note.trim(), occurredAt: _clock(), fields: {
      'author': actor.toJson(),
      'type': 'reblog',
      'origin': root,
      'via': p.id,
      'audience': (audience ?? Audience.everyone).name,
    });
    if (p.author.profileId != actor.profileId) await _notify(p.author.profileId, 'reblog', actor, target: r.id, preview: p.title.isNotEmpty ? p.title : p.body);
    return r.id;
  }

  Future<void> togglePinPost(SocialActor actor, String postId) async {
    await _managed(actor);
    final p = await _post(postId);
    if (p.author.profileId != actor.profileId) throw const SocialDenied('not_owner');
    final prof = await _profile(actor.profileId);
    final pins = [...prof.pinnedPosts];
    pins.contains(postId) ? pins.remove(postId) : pins.insert(0, postId);
    await store.save(prof.r.withFields({'pinned': pins.take(5).toList()}));
  }

  Future<String> saveCircle(SocialActor actor, {String? editingId, required String name, required List<String> members}) async {
    await _managed(actor);
    final editing = editingId == null ? null : (await store.all(SocKind.circle)).where((x) => x.id == editingId).firstOrNull;
    if (editingId != null && editing == null) throw const SocialDenied('not_found');
    final friends = await friendsOf(actor.profileId);
    final valid = [for (final m in members) if (friends.contains(m)) m];
    if (editing != null) {
      if (editing.str('owner') != actor.profileId) throw const SocialDenied('not_owner');
      await store.save(editing.copyWith(title: name).withFields({'members': valid}));
      return editing.id;
    }
    return (await store.create(kind: SocKind.circle, title: name, fields: {'owner': actor.profileId, 'members': valid})).id;
  }

  Future<void> deleteCircle(SocialActor actor, String circleId) async {
    await _managed(actor);
    final c = (await store.all(SocKind.circle)).where((x) => x.id == circleId).firstOrNull;
    if (c == null) throw const SocialDenied('not_found');
    if (c.str('owner') != actor.profileId) throw const SocialDenied('not_owner');
    await store.delete(circleId);
  }

  // ── Notifications ──

  Future<void> _mentions(SocialActor actor, String text, String target) async {
    final names = {for (final m in RegExp(r'@([a-z0-9_.]{3,30})').allMatches(text.toLowerCase())) m.group(1)!};
    if (names.isEmpty) return;
    for (final p in (await store.all(SocKind.profile)).map(SProfile.new)) {
      if (names.contains(p.username) && p.id != actor.profileId) await _notify(p.id, 'mention', actor, target: target, preview: text);
    }
  }

  Future<void> _notify(String recipient, String type, SocialActor actor, {String? target, String? preview, String? alter}) async {
    if (await isBlocked(recipient, actor.profileId)) return;
    final p = (await store.all(SocKind.profile)).where((x) => x.id == recipient).map(SProfile.new).firstOrNull;
    if (p == null || !p.notifies(type)) return;
    await store.create(kind: SocKind.notif, parentId: recipient, occurredAt: _clock(), body: preview == null ? null : (preview.length > 140 ? '${preview.substring(0, 140)}…' : preview), fields: {'type': type, 'actor': actor.toJson(), 'target': target, 'alter': alter});
  }

  Future<void> markNotifications(String profileId, {String? id, bool read = true}) async {
    await owns(profileId);
    for (final r in await store.all(SocKind.notif)) {
      if (r.parentId == profileId && (id == null || r.id == id) && r.flag('read') != read) await store.save(r.withFields({'read': read}));
    }
  }

  Future<void> deleteNotification(String profileId, String id) async {
    await owns(profileId);
    final r = (await store.all(SocKind.notif)).where((x) => x.id == id && x.parentId == profileId).firstOrNull;
    if (r != null) await store.delete(r.id);
  }

}
