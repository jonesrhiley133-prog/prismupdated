import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Record kinds for Prism Social (system-to-system social network). They are
/// separate from the in-system feed (`social.*`).
abstract final class SocKind {
  static const profile = 'soc.profile';
  static const alter = 'soc.alter';
  static const request = 'soc.request';
  static const friendship = 'soc.friendship';
  static const follow = 'soc.follow';
  static const block = 'soc.block';
  static const circle = 'soc.circle';
  static const conversation = 'soc.conversation';
  static const message = 'soc.message';
  static const post = 'soc.post';
  static const comment = 'soc.comment';
  static const react = 'soc.react'; // like / bookmark
  static const notif = 'soc.notif';
  static const report = 'soc.report';
  static const all = [profile, alter, request, friendship, follow, block, circle, conversation, message, post, comment, react, notif, report];
}

/// Who is acting or speaking: a system, or one of its alters.
class SocialActor {
  const SocialActor(this.profileId, [this.alterId]);
  final String profileId;
  final String? alterId;
  Map<String, Object?> toJson() => {'p': profileId, 'a': ?alterId};
  static SocialActor? fromJson(Object? v) => v is Map && v['p'] is String ? SocialActor(v['p'] as String, v['a'] as String?) : null;
  String get key => alterId == null ? profileId : '$profileId/$alterId';
  @override
  bool operator ==(Object other) => other is SocialActor && other.key == key;
  @override
  int get hashCode => key.hashCode;
}

/// Who may do something.
enum Audience { everyone, friendsOfFriends, friends, nobody }

Audience _aud(Object? v, Audience d) => Audience.values.where((a) => a.name == v).firstOrNull ?? d;

/// A system's social profile (account).
class SocialProfile {
  SocialProfile(this.r);
  final TrackerRecord r;
  String get id => r.id;
  String get username => r.str('username') ?? '';
  String get systemName => r.title;
  String get description => r.body ?? '';
  String? get pronouns => r.str('pronouns');
  String? get systemType => r.str('systemType');
  bool get showSystemType => r.flag('showSystemType');
  String? get avatar => r.str('avatar');
  String? get banner => r.str('banner');
  double get bannerY => (r.fields['bannerY'] as num?)?.toDouble() ?? 0;
  List<(String, String)> get links => [
    for (final l in (r.fields['links'] as List?) ?? const [])
      if (l is Map) ('${l['label'] ?? ''}', '${l['url'] ?? ''}'),
  ];
  Map<String, Object?> get theme => (r.fields['theme'] as Map?)?.cast<String, Object?>() ?? const {};
  bool get useCustomTheme => r.fields['useTheme'] != false;
  Map<String, Object?> get privacy => (r.fields['privacy'] as Map?)?.cast<String, Object?>() ?? const {};
  Audience get whoCanRequest => _aud(privacy['requests'], Audience.everyone);
  Audience get whoCanMessage => _aud(privacy['messages'], Audience.friends);
  Audience get whoCanSeeProfile => _aud(privacy['profile'], Audience.everyone);
  Audience get whoCanSeeAlters => _aud(privacy['alters'], Audience.friends);
  Audience get defaultPostAudience => _aud(privacy['posts'], Audience.friends);
  bool get altersReceiveMessages => privacy['altersMessages'] != false;
  bool get friendsReachAlters => privacy['friendsReachAlters'] != false;
  bool get onlineVisible => privacy['online'] != false;
  bool get discoverable => privacy['discover'] != false;
  bool get readReceipts => privacy['readReceipts'] != false;
  bool get typingIndicators => privacy['typing'] != false;
  bool get showActivity => privacy['activity'] == true;
  Map<String, Object?> get notifyPrefs => (r.fields['notify'] as Map?)?.cast<String, Object?>() ?? const {};
  bool notifies(String type) => notifyPrefs[type] != false;
  bool get pushEnabled => notifyPrefs['push'] != false;
  String get status => r.str('status') ?? 'online'; // online, idle, dnd, invisible
  DateTime? get lastActive => DateTime.tryParse('${r.fields['lastActive'] ?? ''}');
  List<String> get pinnedPosts => r.strings('pinned');
}

/// An alter's social profile within a system profile.
class SocialAlter {
  SocialAlter(this.r);
  final TrackerRecord r;
  String get id => r.id;
  String get profileId => r.parentId ?? '';
  String? get memberId => r.memberId;
  String get name => r.title;
  String get description => r.body ?? '';
  String? get pronouns => r.str('pronouns');
  String? get avatar => r.str('avatar');
  String? get banner => r.str('banner');
  String? get customStatus => r.str('customStatus');
  Audience get visibility => _aud(r.fields['visibility'], Audience.friends);
  bool get canMessage => r.fields['canMessage'] != false;
  bool get canPost => r.fields['canPost'] != false;
  SocialActor get actor => SocialActor(profileId, id);
}

class SocialPost {
  SocialPost(this.r);
  final TrackerRecord r;
  String get id => r.id;
  SocialActor get author => SocialActor.fromJson(r.fields['author']) ?? const SocialActor('');
  String get type => r.str('type') ?? 'text'; // text, image, link, quote, milestone, update, question, reblog
  String get body => r.body ?? '';
  String get title => r.title;
  List<String> get media => r.strings('media');
  String? get link => r.str('link');
  String? get quoteSource => r.str('quoteSource');
  Audience get audience => _aud(r.fields['audience'], Audience.friends);
  String? get circleId => r.str('circle');
  Map<String, Object?>? get milestone => (r.fields['milestone'] as Map?)?.cast<String, Object?>();
  Map<String, Object?>? get origin => (r.fields['origin'] as Map?)?.cast<String, Object?>();
  bool get edited => r.fields['edited'] == true;
  DateTime get at => r.occurredAt ?? r.createdAt;
}

class SocialComment {
  SocialComment(this.r);
  final TrackerRecord r;
  String get id => r.id;
  String get postId => r.parentId ?? '';
  SocialActor get author => SocialActor.fromJson(r.fields['author']) ?? const SocialActor('');
  String? get replyTo => r.str('replyTo');
  String get body => r.body ?? '';
  DateTime get at => r.occurredAt ?? r.createdAt;
}

class SocialConversation {
  SocialConversation(this.r);
  final TrackerRecord r;
  String get id => r.id;
  List<SocialActor> get participants => [for (final p in (r.fields['participants'] as List?) ?? const []) ?SocialActor.fromJson(p)];
  Set<String> get mutedBy => r.strings('muted').toSet();
  List<String> get pinned => r.strings('pinned');
  Map<String, String> get unreadMarks => ((r.fields['unread'] as Map?) ?? const {}).map((k, v) => MapEntry('$k', '$v'));
  DateTime get lastAt => DateTime.tryParse('${r.fields['last'] ?? ''}') ?? r.createdAt;
  bool involvesProfile(String p) => participants.any((x) => x.profileId == p);
  SocialActor? me(String profileId) => participants.where((x) => x.profileId == profileId).firstOrNull;
  SocialActor? other(String profileId) => participants.where((x) => x.profileId != profileId).firstOrNull;
}

class SocialMessage {
  SocialMessage(this.r);
  final TrackerRecord r;
  String get id => r.id;
  String get conversationId => r.parentId ?? '';
  SocialActor get sender => SocialActor.fromJson(r.fields['sender']) ?? const SocialActor('');
  String get body => r.body ?? '';
  List<String> get media => r.strings('media');
  String? get replyTo => r.str('replyTo');
  bool get deleted => r.flag('deleted');
  bool get edited => r.flag('edited');
  Map<String, List<String>> get reactions => ((r.fields['reactions'] as Map?) ?? const {}).map((k, v) => MapEntry('$k', [for (final x in (v as List? ?? const [])) '$x']));
  Map<String, String> get readBy => ((r.fields['readBy'] as Map?) ?? const {}).map((k, v) => MapEntry('$k', '$v'));
  DateTime get at => r.occurredAt ?? r.createdAt;
}

class SocialNotification {
  SocialNotification(this.r);
  final TrackerRecord r;
  String get id => r.id;
  String get recipient => r.parentId ?? '';
  String get type => r.str('type') ?? '';
  SocialActor? get actor => SocialActor.fromJson(r.fields['actor']);
  String? get target => r.str('target');
  String? get preview => r.body;
  bool get read => r.flag('read');
  DateTime get at => r.occurredAt ?? r.createdAt;
}

/// Thrown when the backend refuses an action (permissions, privacy, blocks…).
class SocialDenied implements Exception {
  const SocialDenied(this.code, [this.detail]);

  /// self, blocked, privacy, duplicate, not_found, not_owner, not_friends,
  /// not_participant, alters_closed, username_taken, invalid.
  final String code;
  final String? detail;
  @override
  String toString() => 'SocialDenied($code)';
}

(String, String) socialDeniedText(Object e) {
  final c = e is SocialDenied ? e.code : 'invalid';
  return switch (c) {
    'self' => ('You can’t do that with your own system.', 'No puedes hacerlo con tu propio sistema.'),
    'blocked' => ('This isn’t possible because one of you has blocked the other.', 'No es posible porque uno de los dos bloqueó al otro.'),
    'privacy' => ('Their privacy settings don’t allow this.', 'Su configuración de privacidad no lo permite.'),
    'duplicate' => ('That already exists.', 'Eso ya existe.'),
    'already_friends' => ('You’re already friends.', 'Ya sois amigos.'),
    'not_found' => ('It couldn’t be found.', 'No se encontró.'),
    'not_owner' => ('Only the author can do that.', 'Solo quien lo creó puede hacerlo.'),
    'not_friends' => ('You need to be friends first.', 'Primero tenéis que ser amigos.'),
    'not_participant' => ('You’re not part of this conversation.', 'No formas parte de esta conversación.'),
    'alters_closed' => ('This alter can’t be messaged individually.', 'No se puede escribir a este alter por separado.'),
    'username_taken' => ('That username is taken.', 'Ese nombre de usuario ya existe.'),
    'not_managed' => ('You can only act as systems you manage on this device.', 'Solo puedes actuar como sistemas que gestionas en este dispositivo.'),
    _ => ('Something isn’t right with that request.', 'Algo no está bien en esa solicitud.'),
  };
}

/// The social service boundary. Every rule a server would enforce lives
/// here, so a remote backend can replace [LocalSocialBackend] without
/// changing the screens.
abstract class SocialBackend {
  /// Short description shown in settings.
  String get name;

  /// Whether this backend reaches other people's devices.
  bool get reachesOtherDevices;
}

/// Stores everything as synced Prism records on this account's devices.
/// Systems you manage here can befriend, message and follow each other;
/// reaching other people needs a server backend (see docs/prism-social-api.md).
class LocalSocialBackend implements SocialBackend {
  LocalSocialBackend(this.ref);
  final Ref ref;
  @override
  String get name => 'This device (local)';
  @override
  bool get reachesOtherDevices => false;

  TrackerNotifier get _t => ref.read(trackerNotifierProvider.notifier);

  /// Fresh records of [kind] straight from the database (no stale caches),
  /// so duplicate checks hold even for quick repeated taps.
  Future<List<TrackerRecord>> _all(String kind) async => [for (final r in await ref.read(trackerRecordRepositoryProvider).getAll()) if (r.kind == kind) r];

  Future<SocialProfile> _profile(String id) async {
    final r = (await _all(SocKind.profile)).where((p) => p.id == id).firstOrNull;
    if (r == null) throw const SocialDenied('not_found');
    return SocialProfile(r);
  }

  /// Every profile in the local store is managed by this account.
  Future<void> _managed(SocialActor a) async {
    await _profile(a.profileId);
    if (a.alterId != null) {
      final alt = (await _all(SocKind.alter)).where((x) => x.id == a.alterId && x.parentId == a.profileId).firstOrNull;
      if (alt == null) throw const SocialDenied('not_found');
    }
  }

  // ── Relationships ──

  Future<bool> isBlocked(String a, String b) async => (await _all(SocKind.block)).any((r) => (r.str('by') == a && r.str('who') == b) || (r.str('by') == b && r.str('who') == a));
  Future<TrackerRecord?> friendship(String a, String b) async => (await _all(SocKind.friendship)).where((r) => {r.str('a'), r.str('b')}.containsAll({a, b})).firstOrNull;
  Future<Set<String>> friendsOf(String p) async => {
    for (final r in await _all(SocKind.friendship))
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
    if ((await _all(SocKind.profile)).any((p) => p.str('username') == u)) throw const SocialDenied('username_taken');
    final r = await _t.create(kind: SocKind.profile, title: systemName.trim(), body: description, fields: {'username': u, 'primary': primary, 'lastActive': DateTime.now().toIso8601String()});
    return r.id;
  }

  Future<void> updateProfile(String profileId, Map<String, Object?> changes, {String? systemName, String? description}) async {
    final p = await _profile(profileId);
    if (changes['username'] is String) {
      final u = (changes['username']! as String).trim().toLowerCase();
      if (!RegExp(r'^[a-z0-9_.]{3,30}$').hasMatch(u)) throw const SocialDenied('invalid', 'username');
      if ((await _all(SocKind.profile)).any((x) => x.id != profileId && x.str('username') == u)) throw const SocialDenied('username_taken');
      changes = {...changes, 'username': u};
    }
    await _t.save(p.r.copyWith(title: systemName ?? p.r.title, body: description ?? p.r.body).withFields(changes));
  }

  Future<void> touch(String profileId) async {
    final p = await _profile(profileId);
    final last = p.lastActive;
    if (last != null && DateTime.now().difference(last).inMinutes < 2) return;
    await _t.save(p.r.withFields({'lastActive': DateTime.now().toIso8601String()}));
  }

  Future<String> saveAlter(String profileId, {TrackerRecord? editing, String? memberId, required String name, Map<String, Object?> fields = const {}, String? description}) async {
    await _profile(profileId);
    if (editing != null) {
      await _t.save(editing.copyWith(title: name, body: description, memberId: memberId).withFields(fields));
      return editing.id;
    }
    final r = await _t.create(kind: SocKind.alter, parentId: profileId, memberId: memberId, title: name, body: description, fields: {'visibility': 'friends', ...fields});
    return r.id;
  }

  // ── Friend requests ──

  Future<void> sendRequest(SocialActor from, String to, {String? note}) async {
    await _managed(from);
    if (from.profileId == to) throw const SocialDenied('self');
    final target = await _profile(to);
    if (await isBlocked(from.profileId, to)) throw const SocialDenied('blocked');
    if (await areFriends(from.profileId, to)) throw const SocialDenied('already_friends');
    final pending = [for (final r in await _all(SocKind.request)) if (r.str('status') == 'pending') r];
    if (pending.any((r) => r.str('from') == from.profileId && r.str('to') == to)) throw const SocialDenied('duplicate');
    final reverse = pending.where((r) => r.str('from') == to && r.str('to') == from.profileId).firstOrNull;
    if (reverse != null) {
      await acceptRequest(SocialActor(from.profileId), reverse.id);
      return;
    }
    if (!await allows(target.whoCanRequest == Audience.friends ? Audience.nobody : target.whoCanRequest, to, from.profileId)) throw const SocialDenied('privacy');
    final r = await _t.create(kind: SocKind.request, occurredAt: DateTime.now(), body: note, fields: {'from': from.profileId, 'to': to, 'status': 'pending'});
    await _notify(to, 'request', from, target: r.id, preview: note);
  }

  Future<void> acceptRequest(SocialActor actor, String requestId) async {
    final r = (await _all(SocKind.request)).where((x) => x.id == requestId).firstOrNull;
    if (r == null || r.str('status') != 'pending') throw const SocialDenied('not_found');
    if (r.str('to') != actor.profileId) throw const SocialDenied('not_owner');
    await _managed(actor);
    final from = r.str('from')!;
    if (await isBlocked(from, actor.profileId)) throw const SocialDenied('blocked');
    await _t.save(r.withFields({'status': 'accepted', 'resolved': DateTime.now().toIso8601String()}));
    if (!await areFriends(from, actor.profileId)) {
      await _t.create(kind: SocKind.friendship, occurredAt: DateTime.now(), fields: {'a': from, 'b': actor.profileId});
    }
    await _notify(from, 'accepted', SocialActor(actor.profileId), target: actor.profileId);
  }

  Future<void> declineRequest(SocialActor actor, String requestId) async {
    final r = (await _all(SocKind.request)).where((x) => x.id == requestId).firstOrNull;
    if (r == null || r.str('status') != 'pending') throw const SocialDenied('not_found');
    if (r.str('to') != actor.profileId) throw const SocialDenied('not_owner');
    await _t.save(r.withFields({'status': 'declined', 'resolved': DateTime.now().toIso8601String()}));
  }

  Future<void> cancelRequest(SocialActor actor, String requestId) async {
    final r = (await _all(SocKind.request)).where((x) => x.id == requestId).firstOrNull;
    if (r == null || r.str('status') != 'pending') throw const SocialDenied('not_found');
    if (r.str('from') != actor.profileId) throw const SocialDenied('not_owner');
    await _t.save(r.withFields({'status': 'canceled', 'resolved': DateTime.now().toIso8601String()}));
  }

  Future<void> removeFriend(SocialActor actor, String other) async {
    final f = await friendship(actor.profileId, other);
    if (f == null) throw const SocialDenied('not_friends');
    await _t.delete(f.id, children: false);
  }

  Future<void> toggleFavorite(SocialActor actor, String other) async {
    final f = await friendship(actor.profileId, other);
    if (f == null) throw const SocialDenied('not_friends');
    final favs = f.strings('fav').toSet();
    favs.contains(actor.profileId) ? favs.remove(actor.profileId) : favs.add(actor.profileId);
    await _t.save(f.withFields({'fav': favs.toList()}));
  }

  Future<void> toggleFollow(SocialActor actor, String other) async {
    await _managed(actor);
    if (actor.profileId == other) throw const SocialDenied('self');
    if (await isBlocked(actor.profileId, other)) throw const SocialDenied('blocked');
    final f = (await _all(SocKind.follow)).where((r) => r.str('by') == actor.profileId && r.str('who') == other).firstOrNull;
    if (f != null) {
      await _t.delete(f.id, children: false);
    } else {
      await _t.create(kind: SocKind.follow, fields: {'by': actor.profileId, 'who': other});
    }
  }

  /// Blocking ends the friendship, cancels requests and stops follows.
  Future<void> block(SocialActor actor, String other) async {
    await _managed(actor);
    if (actor.profileId == other) throw const SocialDenied('self');
    if ((await _all(SocKind.block)).any((r) => r.str('by') == actor.profileId && r.str('who') == other)) return;
    await _t.create(kind: SocKind.block, occurredAt: DateTime.now(), fields: {'by': actor.profileId, 'who': other});
    final f = await friendship(actor.profileId, other);
    if (f != null) await _t.delete(f.id, children: false);
    for (final r in await _all(SocKind.request)) {
      if (r.str('status') == 'pending' && {r.str('from'), r.str('to')}.containsAll({actor.profileId, other})) await _t.save(r.withFields({'status': 'canceled'}));
    }
    for (final r in await _all(SocKind.follow)) {
      if ({r.str('by'), r.str('who')}.containsAll({actor.profileId, other})) await _t.delete(r.id, children: false);
    }
  }

  Future<void> unblock(SocialActor actor, String other) async {
    for (final r in await _all(SocKind.block)) {
      if (r.str('by') == actor.profileId && r.str('who') == other) await _t.delete(r.id, children: false);
    }
  }

  Future<void> report(SocialActor actor, {required String targetType, required String targetId, required String reason}) async {
    await _managed(actor);
    await _t.create(kind: SocKind.report, occurredAt: DateTime.now(), body: reason, fields: {'by': actor.profileId, 'type': targetType, 'target': targetId, 'status': 'open'});
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
      final alt = (await _all(SocKind.alter)).where((x) => x.id == them.alterId).map(SocialAlter.new).firstOrNull;
      if (alt == null) throw const SocialDenied('not_found');
      final friends = await areFriends(me.profileId, them.profileId);
      if (!target.altersReceiveMessages || !alt.canMessage || (!target.friendsReachAlters && !friends) || !await allows(alt.visibility, them.profileId, me.profileId)) throw const SocialDenied('alters_closed');
    }
    final want = {me.key, them.key};
    for (final c in (await _all(SocKind.conversation)).map(SocialConversation.new)) {
      if (c.participants.map((p) => p.key).toSet().containsAll(want) && c.participants.length == 2) return c.id;
    }
    final r = await _t.create(kind: SocKind.conversation, occurredAt: DateTime.now(), fields: {
      'participants': [me.toJson(), them.toJson()],
      'last': DateTime.now().toIso8601String(),
    });
    return r.id;
  }

  Future<SocialConversation> _conv(String id, SocialActor actor) async {
    final r = (await _all(SocKind.conversation)).where((x) => x.id == id).firstOrNull;
    if (r == null) throw const SocialDenied('not_found');
    final c = SocialConversation(r);
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
    final m = await _t.create(kind: SocKind.message, parentId: conversationId, occurredAt: DateTime.now(), body: body.trim(), fields: {
      'sender': actor.toJson(),
      'media': media.isEmpty ? null : media,
      'replyTo': replyTo,
      'readBy': {actor.profileId: DateTime.now().toIso8601String()},
    });
    final unread = {...c.unreadMarks}..remove(actor.profileId);
    await _t.save(c.r.withFields({'last': DateTime.now().toIso8601String(), 'unread': unread}));
    for (final p in c.participants.where((p) => p.profileId != actor.profileId)) {
      if (!c.mutedBy.contains(p.profileId)) await _notify(p.profileId, p.alterId == null && actor.alterId == null ? 'message' : 'alterMessage', actor, target: conversationId, preview: body.trim().isEmpty ? '📎' : body.trim(), alter: p.alterId);
    }
    return m.id;
  }

  Future<SocialMessage> _ownMessage(SocialActor actor, String messageId) async {
    final r = (await _all(SocKind.message)).where((x) => x.id == messageId).firstOrNull;
    if (r == null) throw const SocialDenied('not_found');
    final m = SocialMessage(r);
    if (m.sender != actor) throw const SocialDenied('not_owner');
    return m;
  }

  Future<void> editMessage(SocialActor actor, String messageId, String body) async {
    final m = await _ownMessage(actor, messageId);
    if (body.trim().isEmpty) throw const SocialDenied('invalid');
    await _t.save(m.r.copyWith(body: body.trim()).withFields({'edited': true}));
  }

  Future<void> deleteMessage(SocialActor actor, String messageId) async {
    final m = await _ownMessage(actor, messageId);
    await _t.save(m.r.copyWith(body: '').withFields({'deleted': true, 'media': null}));
  }

  Future<void> react(SocialActor actor, String messageId, String emoji) async {
    final r = (await _all(SocKind.message)).where((x) => x.id == messageId).firstOrNull;
    if (r == null) throw const SocialDenied('not_found');
    final m = SocialMessage(r);
    await _conv(m.conversationId, actor);
    final map = {for (final e in m.reactions.entries) e.key: [...e.value]};
    final list = map[emoji] ?? [];
    list.contains(actor.key) ? list.remove(actor.key) : list.add(actor.key);
    if (list.isEmpty) {
      map.remove(emoji);
    } else {
      map[emoji] = list;
    }
    await _t.save(m.r.withFields({'reactions': map}));
  }

  Future<void> markRead(SocialActor actor, String conversationId) async {
    final c = await _conv(conversationId, actor);
    final now = DateTime.now().toIso8601String();
    for (final r in await _all(SocKind.message)) {
      if (r.parentId != conversationId) continue;
      final m = SocialMessage(r);
      if (m.sender.profileId == actor.profileId || m.readBy.containsKey(actor.profileId)) continue;
      await _t.save(r.withFields({'readBy': {...m.readBy, actor.profileId: now}}));
    }
    if (c.unreadMarks.containsKey(actor.profileId)) await _t.save(c.r.withFields({'unread': {...c.unreadMarks}..remove(actor.profileId)}));
  }

  Future<void> markUnread(SocialActor actor, String conversationId) async {
    final c = await _conv(conversationId, actor);
    await _t.save(c.r.withFields({'unread': {...c.unreadMarks, actor.profileId: '1'}}));
  }

  Future<void> toggleMute(SocialActor actor, String conversationId) async {
    final c = await _conv(conversationId, actor);
    final m = c.mutedBy;
    m.contains(actor.profileId) ? m.remove(actor.profileId) : m.add(actor.profileId);
    await _t.save(c.r.withFields({'muted': m.toList()}));
  }

  Future<void> togglePin(SocialActor actor, String conversationId, String messageId) async {
    final c = await _conv(conversationId, actor);
    final p = [...c.pinned];
    p.contains(messageId) ? p.remove(messageId) : p.insert(0, messageId);
    await _t.save(c.r.withFields({'pinned': p}));
  }

  // ── Posts ──

  Future<String> createPost(SocialActor actor, {required String type, String title = '', String body = '', List<String> media = const [], String? link, String? quoteSource, Map<String, Object?>? milestone, Audience? audience, String? circleId}) async {
    await _managed(actor);
    final p = await _profile(actor.profileId);
    if (actor.alterId != null) {
      final alt = (await _all(SocKind.alter)).where((x) => x.id == actor.alterId).map(SocialAlter.new).firstOrNull;
      if (alt == null || !alt.canPost) throw const SocialDenied('privacy');
    }
    if (body.trim().isEmpty && media.isEmpty && (link ?? '').isEmpty && milestone == null && title.trim().isEmpty) throw const SocialDenied('invalid');
    final r = await _t.create(kind: SocKind.post, title: title.trim(), body: body.trim(), occurredAt: DateTime.now(), fields: {
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

  Future<SocialPost> _post(String id) async {
    final r = (await _all(SocKind.post)).where((x) => x.id == id).firstOrNull;
    if (r == null) throw const SocialDenied('not_found');
    return SocialPost(r);
  }

  Future<void> editPost(SocialActor actor, String postId, {String? title, String? body, Audience? audience}) async {
    final p = await _post(postId);
    if (p.author != actor) throw const SocialDenied('not_owner');
    await _t.save(p.r.copyWith(title: title ?? p.r.title, body: body ?? p.r.body).withFields({'edited': true, 'audience': ?audience?.name}));
  }

  Future<void> deletePost(SocialActor actor, String postId) async {
    final p = await _post(postId);
    if (p.author.profileId != actor.profileId) throw const SocialDenied('not_owner');
    for (final c in await _all(SocKind.comment)) {
      if (c.parentId == postId) await _t.delete(c.id, children: false);
    }
    for (final c in await _all(SocKind.react)) {
      if (c.parentId == postId) await _t.delete(c.id, children: false);
    }
    await _t.delete(postId, children: false);
  }

  /// Whether [viewer] may see [post] (audience, circles and blocks).
  Future<bool> canSee(SocialPost post, String viewer) async {
    final owner = post.author.profileId;
    if (owner == viewer) return true;
    if (await isBlocked(owner, viewer)) return false;
    if (post.audience == Audience.nobody) return false;
    if (post.circleId != null) {
      final c = (await _all(SocKind.circle)).where((x) => x.id == post.circleId).firstOrNull;
      return c != null && c.strings('members').contains(viewer);
    }
    return allows(post.audience, owner, viewer);
  }

  Future<void> toggleReact(SocialActor actor, String postId, String type) async {
    final p = await _post(postId);
    if (!await canSee(p, actor.profileId)) throw const SocialDenied('privacy');
    final existing = (await _all(SocKind.react)).where((r) => r.parentId == postId && r.str('by') == actor.profileId && r.str('type') == type).firstOrNull;
    if (existing != null) {
      await _t.delete(existing.id, children: false);
      return;
    }
    await _t.create(kind: SocKind.react, parentId: postId, occurredAt: DateTime.now(), fields: {'by': actor.profileId, 'actor': actor.toJson(), 'type': type});
    if (type == 'like' && p.author.profileId != actor.profileId) await _notify(p.author.profileId, p.type == 'milestone' ? 'milestoneLike' : 'like', actor, target: postId, preview: p.title.isNotEmpty ? p.title : p.body);
  }

  Future<String> comment(SocialActor actor, String postId, String body, {String? replyTo}) async {
    await _managed(actor);
    final p = await _post(postId);
    if (!await canSee(p, actor.profileId)) throw const SocialDenied('privacy');
    if (body.trim().isEmpty) throw const SocialDenied('invalid');
    final c = await _t.create(kind: SocKind.comment, parentId: postId, occurredAt: DateTime.now(), body: body.trim(), fields: {'author': actor.toJson(), 'replyTo': replyTo});
    if (p.author.profileId != actor.profileId) await _notify(p.author.profileId, 'comment', actor, target: postId, preview: body.trim());
    if (replyTo != null) {
      final parent = (await _all(SocKind.comment)).where((x) => x.id == replyTo).map(SocialComment.new).firstOrNull;
      if (parent != null && parent.author.profileId != actor.profileId && parent.author.profileId != p.author.profileId) await _notify(parent.author.profileId, 'reply', actor, target: postId, preview: body.trim());
    }
    await _mentions(actor, body, postId);
    return c.id;
  }

  Future<void> deleteComment(SocialActor actor, String commentId) async {
    final r = (await _all(SocKind.comment)).where((x) => x.id == commentId).firstOrNull;
    if (r == null) throw const SocialDenied('not_found');
    final c = SocialComment(r);
    final post = await _post(c.postId);
    if (c.author.profileId != actor.profileId && post.author.profileId != actor.profileId) throw const SocialDenied('not_owner');
    await _t.delete(commentId, children: false);
  }

  /// Reposts with attribution to the original author (and an optional note).
  Future<String> reblog(SocialActor actor, String postId, {String note = '', Audience? audience}) async {
    await _managed(actor);
    final p = await _post(postId);
    if (!await canSee(p, actor.profileId)) throw const SocialDenied('privacy');
    if (p.audience != Audience.everyone && p.author.profileId != actor.profileId) throw const SocialDenied('privacy', 'only public posts can be reblogged');
    final root = p.origin ?? {'post': p.id, 'author': p.author.toJson(), 'title': p.title, 'body': p.body, 'media': p.media, 'type': p.type, 'link': p.link, 'milestone': p.milestone, 'at': p.at.toIso8601String()};
    final r = await _t.create(kind: SocKind.post, body: note.trim(), occurredAt: DateTime.now(), fields: {
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
    final p = await _post(postId);
    if (p.author.profileId != actor.profileId) throw const SocialDenied('not_owner');
    final prof = await _profile(actor.profileId);
    final pins = [...prof.pinnedPosts];
    pins.contains(postId) ? pins.remove(postId) : pins.insert(0, postId);
    await _t.save(prof.r.withFields({'pinned': pins.take(5).toList()}));
  }

  Future<String> saveCircle(SocialActor actor, {TrackerRecord? editing, required String name, required List<String> members}) async {
    await _managed(actor);
    final friends = await friendsOf(actor.profileId);
    final valid = [for (final m in members) if (friends.contains(m)) m];
    if (editing != null) {
      if (editing.str('owner') != actor.profileId) throw const SocialDenied('not_owner');
      await _t.save(editing.copyWith(title: name).withFields({'members': valid}));
      return editing.id;
    }
    return (await _t.create(kind: SocKind.circle, title: name, fields: {'owner': actor.profileId, 'members': valid})).id;
  }

  // ── Notifications ──

  Future<void> _mentions(SocialActor actor, String text, String target) async {
    final names = {for (final m in RegExp(r'@([a-z0-9_.]{3,30})').allMatches(text.toLowerCase())) m.group(1)!};
    if (names.isEmpty) return;
    for (final p in (await _all(SocKind.profile)).map(SocialProfile.new)) {
      if (names.contains(p.username) && p.id != actor.profileId) await _notify(p.id, 'mention', actor, target: target, preview: text);
    }
  }

  Future<void> _notify(String recipient, String type, SocialActor actor, {String? target, String? preview, String? alter}) async {
    if (await isBlocked(recipient, actor.profileId)) return;
    final p = (await _all(SocKind.profile)).where((x) => x.id == recipient).map(SocialProfile.new).firstOrNull;
    if (p == null || !p.notifies(type)) return;
    await _t.create(kind: SocKind.notif, parentId: recipient, occurredAt: DateTime.now(), body: preview == null ? null : (preview.length > 140 ? '${preview.substring(0, 140)}…' : preview), fields: {'type': type, 'actor': actor.toJson(), 'target': target, 'alter': alter});
  }

  Future<void> markNotifications(String profileId, {String? id, bool read = true}) async {
    for (final r in await _all(SocKind.notif)) {
      if (r.parentId == profileId && (id == null || r.id == id) && r.flag('read') != read) await _t.save(r.withFields({'read': read}));
    }
  }

  Future<void> deleteNotification(String profileId, String id) async {
    final r = (await _all(SocKind.notif)).where((x) => x.id == id && x.parentId == profileId).firstOrNull;
    if (r != null) await _t.delete(r.id, children: false);
  }
}

final socialBackendProvider = Provider<LocalSocialBackend>(LocalSocialBackend.new);

// ───────────────────────── Reading ─────────────────────────

List<TrackerRecord> _kind(Ref ref, String k) => ref.watch(trackerKindProvider(k)).value ?? const [];

final socialProfilesProvider = Provider<List<SocialProfile>>((ref) => [for (final r in _kind(ref, SocKind.profile)) SocialProfile(r)]);
final socialProfileByIdProvider = Provider.family<SocialProfile?, String>((ref, id) => ref.watch(socialProfilesProvider).where((p) => p.id == id).firstOrNull);
final socialAltersProvider = Provider<List<SocialAlter>>((ref) => [for (final r in _kind(ref, SocKind.alter)) SocialAlter(r)]);

/// The system (and optional alter) this device is acting as.
class ActingNotifier extends Notifier<SocialActor?> {
  static const _key = 'prism_social_acting';
  @override
  SocialActor? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getString(_key);
      if (v == null) return;
      final parts = v.split('/');
      state = SocialActor(parts.first, parts.length > 1 ? parts[1] : null);
    } catch (_) {}
  }

  Future<void> set(SocialActor? a) async {
    state = a;
    try {
      final p = await SharedPreferences.getInstance();
      a == null ? await p.remove(_key) : await p.setString(_key, a.key);
    } catch (_) {}
  }
}

final actingStoredProvider = NotifierProvider<ActingNotifier, SocialActor?>(ActingNotifier.new);

/// The acting identity, falling back to the first (primary) profile.
final actingProvider = Provider<SocialActor?>((ref) {
  final profiles = ref.watch(socialProfilesProvider);
  final stored = ref.watch(actingStoredProvider);
  if (stored != null && profiles.any((p) => p.id == stored.profileId)) {
    if (stored.alterId == null || ref.watch(socialAltersProvider).any((a) => a.id == stored.alterId && a.profileId == stored.profileId)) return stored;
    return SocialActor(stored.profileId);
  }
  final primary = profiles.where((p) => p.r.flag('primary')).firstOrNull ?? profiles.firstOrNull;
  return primary == null ? null : SocialActor(primary.id);
});

final friendIdsProvider = Provider.family<Set<String>, String>((ref, me) => {
  for (final r in _kind(ref, SocKind.friendship))
    if (r.str('a') == me) r.str('b')! else if (r.str('b') == me) r.str('a')!,
});

final blockedIdsProvider = Provider.family<Set<String>, String>((ref, me) => {
  for (final r in _kind(ref, SocKind.block))
    if (r.str('by') == me) r.str('who')! else if (r.str('who') == me) r.str('by')!,
});

final pendingRequestsProvider = Provider.family<({List<TrackerRecord> incoming, List<TrackerRecord> outgoing}), String>((ref, me) {
  final p = [for (final r in _kind(ref, SocKind.request)) if (r.str('status') == 'pending') r]..sort((a, b) => (b.occurredAt ?? b.createdAt).compareTo(a.occurredAt ?? a.createdAt));
  return (incoming: [for (final r in p) if (r.str('to') == me) r], outgoing: [for (final r in p) if (r.str('from') == me) r]);
});

final notificationsProvider = Provider.family<List<SocialNotification>, String>((ref, me) => [for (final r in _kind(ref, SocKind.notif)) if (r.parentId == me) SocialNotification(r)]..sort((a, b) => b.at.compareTo(a.at)));

final unreadNotificationCountProvider = Provider.family<int, String>((ref, me) => ref.watch(notificationsProvider(me)).where((n) => !n.read).length);

final conversationsProvider = Provider.family<List<SocialConversation>, String>((ref, me) => [for (final r in _kind(ref, SocKind.conversation)) if (SocialConversation(r).involvesProfile(me)) SocialConversation(r)]..sort((a, b) => b.lastAt.compareTo(a.lastAt)));

final messagesProvider = Provider.family<List<SocialMessage>, String>((ref, conv) => [for (final r in _kind(ref, SocKind.message)) if (r.parentId == conv) SocialMessage(r)]..sort((a, b) => a.at.compareTo(b.at)));

final unreadMessagesProvider = Provider.family<int, String>((ref, me) {
  var n = 0;
  for (final c in ref.watch(conversationsProvider(me))) {
    final msgs = ref.watch(messagesProvider(c.id));
    if (c.unreadMarks.containsKey(me) || msgs.any((m) => m.sender.profileId != me && !m.readBy.containsKey(me) && !m.deleted)) n++;
  }
  return n;
});

final postsProvider = Provider<List<SocialPost>>((ref) => [for (final r in _kind(ref, SocKind.post)) SocialPost(r)]..sort((a, b) => b.at.compareTo(a.at)));
final commentsProvider = Provider.family<List<SocialComment>, String>((ref, post) => [for (final r in _kind(ref, SocKind.comment)) if (r.parentId == post) SocialComment(r)]..sort((a, b) => a.at.compareTo(b.at)));
final reactsProvider = Provider.family<List<TrackerRecord>, String>((ref, post) => [for (final r in _kind(ref, SocKind.react)) if (r.parentId == post) r]);
final reblogCountProvider = Provider.family<int, String>((ref, post) => _kind(ref, SocKind.post).where((r) => r.str('via') == post || ((r.fields['origin'] as Map?)?['post'] == post)).length);
final followingProvider = Provider.family<Set<String>, String>((ref, me) => {for (final r in _kind(ref, SocKind.follow)) if (r.str('by') == me) r.str('who')!});
final circlesProvider = Provider.family<List<TrackerRecord>, String>((ref, me) => [for (final r in _kind(ref, SocKind.circle)) if (r.str('owner') == me) r]);

/// Synchronous visibility check for the UI (the backend re-checks on write).
typedef SocialReader = T Function<T>(ProviderListenable<T> provider);

bool canSeePost(SocialReader read, SocialPost p, String viewer) {
  final owner = p.author.profileId;
  if (owner == viewer) return true;
  if (read(blockedIdsProvider(viewer)).contains(owner)) return false;
  if (p.audience == Audience.nobody) return false;
  if (p.circleId != null) return read(circlesProvider(owner)).any((c) => c.id == p.circleId && c.strings('members').contains(viewer));
  final friends = read(friendIdsProvider(owner));
  return switch (p.audience) {
    Audience.everyone => true,
    Audience.friends => friends.contains(viewer),
    Audience.friendsOfFriends => friends.contains(viewer) || read(friendIdsProvider(viewer)).intersection(friends).isNotEmpty,
    Audience.nobody => false,
  };
}

enum FeedMode { following, friends, recommended, recent, popular }

/// Posts [viewer] may see for a feed mode.
final feedProvider = Provider.family<List<SocialPost>, (String, FeedMode)>((ref, key) {
  final (viewer, mode) = key;
  final friends = ref.watch(friendIdsProvider(viewer));
  final following = ref.watch(followingProvider(viewer));
  ref.watch(blockedIdsProvider(viewer));
  final all = [for (final p in ref.watch(postsProvider)) if (canSeePost(ref.read, p, viewer)) p];
  int score(SocialPost p) {
    final likes = ref.watch(reactsProvider(p.id)).where((r) => r.str('type') == 'like').length;
    return (likes + 2 * ref.watch(reblogCountProvider(p.id)) + ref.watch(commentsProvider(p.id)).length).toInt();
  }

  switch (mode) {
    case FeedMode.following:
      return [for (final p in all) if (following.contains(p.author.profileId) || friends.contains(p.author.profileId) || p.author.profileId == viewer) p];
    case FeedMode.friends:
      return [for (final p in all) if (friends.contains(p.author.profileId) || p.author.profileId == viewer) p];
    case FeedMode.recent:
      return all;
    case FeedMode.popular:
      final week = DateTime.now().subtract(const Duration(days: 7));
      return [for (final p in all) if (p.at.isAfter(week)) p]..sort((a, b) => score(b).compareTo(score(a)));
    case FeedMode.recommended:
      final fof = {for (final f in friends) ...ref.watch(friendIdsProvider(f))}..remove(viewer);
      double rank(SocialPost p) {
        final ageH = DateTime.now().difference(p.at).inMinutes / 60;
        final social = friends.contains(p.author.profileId) ? 3 : (fof.contains(p.author.profileId) ? 1.5 : 1);
        return (score(p) + 1) * social / (1 + ageH / 24);
      }

      return [...all]..sort((a, b) => rank(b).compareTo(rank(a)));
  }
});

/// Presence: only shown when the profile allows it.
String presenceOf(SocialProfile p, {required bool actingAsIt}) {
  if (!p.onlineVisible || p.status == 'invisible') return 'offline';
  if (actingAsIt) return p.status;
  final last = p.lastActive;
  if (last == null) return 'offline';
  final mins = DateTime.now().difference(last).inMinutes;
  if (mins < 5) return p.status == 'dnd' ? 'dnd' : 'online';
  if (mins < 30) return 'idle';
  return 'offline';
}
