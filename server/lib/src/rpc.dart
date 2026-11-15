import 'package:prism_social_core/prism_social_core.dart';

/// Thrown for malformed requests.
class BadRequest implements Exception {
  const BadRequest(this.message);
  final String message;
}

SocialActor _actor(Map<String, Object?> a, String key) => SocialActor.fromJson(a[key]) ?? (throw BadRequest('missing actor "$key"'));

String _s(Map<String, Object?> a, String key) {
  final v = a[key];
  if (v is String && v.isNotEmpty) return v;
  throw BadRequest('missing "$key"');
}

String? _os(Map<String, Object?> a, String key) {
  final v = a[key];
  if (v == null) return null;
  if (v is String) return v;
  throw BadRequest('"$key" must be a string');
}

bool? _ob(Map<String, Object?> a, String key) {
  final v = a[key];
  if (v == null || v is bool) return v as bool?;
  throw BadRequest('"$key" must be a boolean');
}

Map<String, Object?> _map(Map<String, Object?> a, String key) {
  final v = a[key];
  if (v == null) return const {};
  if (v is Map) return v.cast<String, Object?>();
  throw BadRequest('"$key" must be an object');
}

List<String> _list(Map<String, Object?> a, String key) {
  final v = a[key];
  if (v == null) return const [];
  if (v is List && v.every((x) => x is String)) return v.cast<String>();
  throw BadRequest('"$key" must be a list of strings');
}

Audience? _aud(Map<String, Object?> a, String key) {
  final v = a[key];
  if (v == null) return null;
  return Audience.values.where((x) => x.name == v).firstOrNull ?? (throw BadRequest('bad audience "$v"'));
}

typedef RpcHandler = Future<Object?> Function(SocialRules r, Map<String, Object?> a);

/// Every action the app can perform. Names and arguments match the app's
/// `SocialBackend` methods one-to-one.
final Map<String, RpcHandler> rpcMethods = {
  'createProfile': (r, a) => r.createProfile(username: _s(a, 'username'), systemName: _s(a, 'systemName'), description: _os(a, 'description'), primary: _ob(a, 'primary') ?? false),
  'updateProfile': (r, a) => r.updateProfile(_s(a, 'profileId'), _map(a, 'changes'), systemName: _os(a, 'systemName'), description: _os(a, 'description')),
  'touch': (r, a) => r.touch(_s(a, 'profileId')),
  'saveAlter': (r, a) => r.saveAlter(_s(a, 'profileId'), editingId: _os(a, 'editingId'), memberId: _os(a, 'memberId'), name: _s(a, 'name'), fields: _map(a, 'fields'), description: _os(a, 'description')),
  'deleteAlter': (r, a) => r.deleteAlter(_s(a, 'profileId'), _s(a, 'alterId')),
  'sendRequest': (r, a) => r.sendRequest(_actor(a, 'from'), _s(a, 'to'), note: _os(a, 'note')),
  'acceptRequest': (r, a) => r.acceptRequest(_actor(a, 'actor'), _s(a, 'requestId')),
  'declineRequest': (r, a) => r.declineRequest(_actor(a, 'actor'), _s(a, 'requestId')),
  'cancelRequest': (r, a) => r.cancelRequest(_actor(a, 'actor'), _s(a, 'requestId')),
  'removeFriend': (r, a) => r.removeFriend(_actor(a, 'actor'), _s(a, 'other')),
  'toggleFavorite': (r, a) => r.toggleFavorite(_actor(a, 'actor'), _s(a, 'other')),
  'toggleFollow': (r, a) => r.toggleFollow(_actor(a, 'actor'), _s(a, 'other')),
  'block': (r, a) => r.block(_actor(a, 'actor'), _s(a, 'other')),
  'unblock': (r, a) => r.unblock(_actor(a, 'actor'), _s(a, 'other')),
  'report': (r, a) => r.report(_actor(a, 'actor'), targetType: _s(a, 'targetType'), targetId: _s(a, 'targetId'), reason: _s(a, 'reason')),
  'openConversation': (r, a) => r.openConversation(_actor(a, 'me'), _actor(a, 'them')),
  'sendMessage': (r, a) => r.sendMessage(_actor(a, 'actor'), _s(a, 'conversationId'), body: _os(a, 'body') ?? '', media: _list(a, 'media'), replyTo: _os(a, 'replyTo')),
  'editMessage': (r, a) => r.editMessage(_actor(a, 'actor'), _s(a, 'messageId'), _s(a, 'body')),
  'deleteMessage': (r, a) => r.deleteMessage(_actor(a, 'actor'), _s(a, 'messageId')),
  'react': (r, a) => r.react(_actor(a, 'actor'), _s(a, 'messageId'), _s(a, 'emoji')),
  'markRead': (r, a) => r.markRead(_actor(a, 'actor'), _s(a, 'conversationId')),
  'markUnread': (r, a) => r.markUnread(_actor(a, 'actor'), _s(a, 'conversationId')),
  'toggleMute': (r, a) => r.toggleMute(_actor(a, 'actor'), _s(a, 'conversationId')),
  'togglePin': (r, a) => r.togglePin(_actor(a, 'actor'), _s(a, 'conversationId'), _s(a, 'messageId')),
  'createPost': (r, a) => r.createPost(
    _actor(a, 'actor'),
    type: _s(a, 'type'),
    title: _os(a, 'title') ?? '',
    body: _os(a, 'body') ?? '',
    media: _list(a, 'media'),
    link: _os(a, 'link'),
    quoteSource: _os(a, 'quoteSource'),
    milestone: a['milestone'] == null ? null : _map(a, 'milestone'),
    audience: _aud(a, 'audience'),
    circleId: _os(a, 'circleId'),
  ),
  'editPost': (r, a) => r.editPost(_actor(a, 'actor'), _s(a, 'postId'), title: _os(a, 'title'), body: _os(a, 'body'), audience: _aud(a, 'audience')),
  'deletePost': (r, a) => r.deletePost(_actor(a, 'actor'), _s(a, 'postId')),
  'toggleReact': (r, a) {
    final type = _s(a, 'type');
    if (type != 'like' && type != 'bookmark') throw const BadRequest('type must be like or bookmark');
    return r.toggleReact(_actor(a, 'actor'), _s(a, 'postId'), type);
  },
  'comment': (r, a) => r.comment(_actor(a, 'actor'), _s(a, 'postId'), _s(a, 'body'), replyTo: _os(a, 'replyTo')),
  'deleteComment': (r, a) => r.deleteComment(_actor(a, 'actor'), _s(a, 'commentId')),
  'reblog': (r, a) => r.reblog(_actor(a, 'actor'), _s(a, 'postId'), note: _os(a, 'note') ?? '', audience: _aud(a, 'audience')),
  'togglePinPost': (r, a) => r.togglePinPost(_actor(a, 'actor'), _s(a, 'postId')),
  'saveCircle': (r, a) => r.saveCircle(_actor(a, 'actor'), editingId: _os(a, 'editingId'), name: _s(a, 'name'), members: _list(a, 'members')),
  'deleteCircle': (r, a) => r.deleteCircle(_actor(a, 'actor'), _s(a, 'circleId')),
  'markNotifications': (r, a) => r.markNotifications(_s(a, 'profileId'), id: _os(a, 'id'), read: _ob(a, 'read') ?? true),
  'deleteNotification': (r, a) => r.deleteNotification(_s(a, 'profileId'), _s(a, 'id')),
};
