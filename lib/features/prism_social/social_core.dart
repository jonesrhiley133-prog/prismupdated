import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:prism_social_core/prism_social_core.dart' hide SAlter, SComment, SConv, SMessage, SNotification, SPost, SProfile;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

export 'package:prism_social_core/prism_social_core.dart' show Audience, SocKind, SocialActor, SocialDenied;

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

/// The social service boundary. Screens only talk to this, so on-device and
/// server modes behave the same. Rules live in `prism_social_core`.
abstract class SocialBackend {
  /// Short description shown in settings.
  String get name;

  /// Whether this backend reaches other people's devices.
  bool get reachesOtherDevices;

  Future<String> createProfile({required String username, required String systemName, String? description, bool primary = false});
  Future<void> updateProfile(String profileId, Map<String, Object?> changes, {String? systemName, String? description});
  Future<void> touch(String profileId);
  Future<String> saveAlter(String profileId, {String? editingId, String? memberId, required String name, Map<String, Object?> fields = const {}, String? description});
  Future<void> deleteAlter(String profileId, String alterId);
  Future<void> sendRequest(SocialActor from, String to, {String? note});
  Future<void> acceptRequest(SocialActor actor, String requestId);
  Future<void> declineRequest(SocialActor actor, String requestId);
  Future<void> cancelRequest(SocialActor actor, String requestId);
  Future<void> removeFriend(SocialActor actor, String other);
  Future<void> toggleFavorite(SocialActor actor, String other);
  Future<void> toggleFollow(SocialActor actor, String other);
  Future<void> block(SocialActor actor, String other);
  Future<void> unblock(SocialActor actor, String other);
  Future<void> report(SocialActor actor, {required String targetType, required String targetId, required String reason});
  Future<String> openConversation(SocialActor me, SocialActor them);
  Future<String> sendMessage(SocialActor actor, String conversationId, {String body = '', List<String> media = const [], String? replyTo});
  Future<void> editMessage(SocialActor actor, String messageId, String body);
  Future<void> deleteMessage(SocialActor actor, String messageId);
  Future<void> react(SocialActor actor, String messageId, String emoji);
  Future<void> markRead(SocialActor actor, String conversationId);
  Future<void> markUnread(SocialActor actor, String conversationId);
  Future<void> toggleMute(SocialActor actor, String conversationId);
  Future<void> togglePin(SocialActor actor, String conversationId, String messageId);
  Future<String> createPost(SocialActor actor, {required String type, String title = '', String body = '', List<String> media = const [], String? link, String? quoteSource, Map<String, Object?>? milestone, Audience? audience, String? circleId});
  Future<void> editPost(SocialActor actor, String postId, {String? title, String? body, Audience? audience});
  Future<void> deletePost(SocialActor actor, String postId);
  Future<void> toggleReact(SocialActor actor, String postId, String type);
  Future<String> comment(SocialActor actor, String postId, String body, {String? replyTo});
  Future<void> deleteComment(SocialActor actor, String commentId);
  Future<String> reblog(SocialActor actor, String postId, {String note = '', Audience? audience});
  Future<void> togglePinPost(SocialActor actor, String postId);
  Future<String> saveCircle(SocialActor actor, {String? editingId, required String name, required List<String> members});
  Future<void> deleteCircle(SocialActor actor, String circleId);
  Future<void> markNotifications(String profileId, {String? id, bool read = true});
  Future<void> deleteNotification(String profileId, String id);
}

/// The app's tracker table as a [SocialStore] (synced across your devices).
class TrackerSocialStore implements SocialStore {
  TrackerSocialStore(this.ref);
  final Ref ref;
  TrackerNotifier get _t => ref.read(trackerNotifierProvider.notifier);

  static SocRecord toSoc(TrackerRecord r) => SocRecord(id: r.id, kind: r.kind, parentId: r.parentId, title: r.title, body: r.body, memberId: r.memberId, occurredAt: r.occurredAt, createdAt: r.createdAt, modifiedAt: r.modifiedAt, fields: r.fields);

  static TrackerRecord toTracker(SocRecord r) => TrackerRecord(id: r.id, kind: r.kind, parentId: r.parentId, title: r.title, body: r.body, memberId: r.memberId, occurredAt: r.occurredAt, createdAt: r.createdAt, modifiedAt: r.modifiedAt, data: r.fields.isEmpty ? null : jsonEncode(r.fields));

  /// Fresh rows straight from the database, so duplicate checks hold even
  /// for quick repeated taps.
  @override
  Future<List<SocRecord>> all(String kind) async => [for (final r in await ref.read(trackerRecordRepositoryProvider).getAll()) if (r.kind == kind) toSoc(r)];

  @override
  Future<SocRecord> create({required String kind, String title = '', String? body, String? parentId, String? memberId, Map<String, Object?> fields = const {}, DateTime? occurredAt}) async =>
      toSoc(await _t.create(kind: kind, title: title, body: body, parentId: parentId, memberId: memberId, fields: fields, occurredAt: occurredAt));

  @override
  Future<void> save(SocRecord record) => _t.save(toTracker(record));

  @override
  Future<void> delete(String id) => _t.delete(id, children: false);
}

/// On-device mode: the shared rules run against this account's synced
/// records. Systems you manage here can befriend, message and follow each
/// other; reaching other people needs a Prism Social server.
class LocalSocialBackend extends SocialRules implements SocialBackend {
  LocalSocialBackend(Ref ref) : super(TrackerSocialStore(ref));
  @override
  String get name => 'This device (local)';
  @override
  bool get reachesOtherDevices => false;
}

final socialBackendProvider = Provider<SocialBackend>(LocalSocialBackend.new);

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
