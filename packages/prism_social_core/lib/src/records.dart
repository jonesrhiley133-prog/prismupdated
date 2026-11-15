import 'dart:convert';

/// Record kinds for Prism Social.
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

/// A stored Social record. Mirrors the app's tracker record shape so the
/// same rows work on-device and on the server.
class SocRecord {
  const SocRecord({required this.id, required this.kind, this.parentId, this.title = '', this.body, this.memberId, this.occurredAt, required this.createdAt, required this.modifiedAt, this.fields = const {}});

  final String id;
  final String kind;
  final String? parentId;
  final String title;
  final String? body;
  final String? memberId;
  final DateTime? occurredAt;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final Map<String, Object?> fields;

  String? str(String key) {
    final v = fields[key];
    return v is String && v.isNotEmpty ? v : null;
  }

  bool flag(String key) => fields[key] == true;

  List<String> strings(String key) {
    final v = fields[key];
    return v is List ? [for (final x in v) if (x is String) x] : const [];
  }

  static const _keep = Object();

  SocRecord copyWith({Object? title = _keep, Object? body = _keep, Object? memberId = _keep, DateTime? modifiedAt}) => SocRecord(
    id: id,
    kind: kind,
    parentId: parentId,
    title: identical(title, _keep) ? this.title : (title as String? ?? ''),
    body: identical(body, _keep) ? this.body : body as String?,
    memberId: identical(memberId, _keep) ? this.memberId : memberId as String?,
    occurredAt: occurredAt,
    createdAt: createdAt,
    modifiedAt: modifiedAt ?? this.modifiedAt,
    fields: fields,
  );

  /// [changes] merged into [fields] (null removes a key).
  SocRecord withFields(Map<String, Object?> changes) {
    final next = Map<String, Object?>.of(fields);
    changes.forEach((k, v) => v == null ? next.remove(k) : next[k] = v);
    return SocRecord(id: id, kind: kind, parentId: parentId, title: title, body: body, memberId: memberId, occurredAt: occurredAt, createdAt: createdAt, modifiedAt: modifiedAt, fields: next);
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind,
    'parentId': ?parentId,
    'title': title,
    'body': ?body,
    'memberId': ?memberId,
    'occurredAt': ?occurredAt?.toUtc().toIso8601String(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'modifiedAt': modifiedAt.toUtc().toIso8601String(),
    'fields': fields,
  };

  static SocRecord fromJson(Map<String, Object?> j) => SocRecord(
    id: j['id']! as String,
    kind: j['kind']! as String,
    parentId: j['parentId'] as String?,
    title: (j['title'] as String?) ?? '',
    body: j['body'] as String?,
    memberId: j['memberId'] as String?,
    occurredAt: j['occurredAt'] == null ? null : DateTime.parse(j['occurredAt']! as String).toLocal(),
    createdAt: DateTime.parse(j['createdAt']! as String).toLocal(),
    modifiedAt: DateTime.parse(j['modifiedAt']! as String).toLocal(),
    fields: ((j['fields'] as Map?) ?? const {}).cast<String, Object?>(),
  );

  String get fieldsJson => jsonEncode(fields);
}

/// Storage the rules run against (the app's tracker table, or Postgres).
abstract class SocialStore {
  /// Every live record of [kind], fresh (no stale caches).
  Future<List<SocRecord>> all(String kind);
  Future<SocRecord> create({required String kind, String title = '', String? body, String? parentId, String? memberId, Map<String, Object?> fields = const {}, DateTime? occurredAt});
  Future<void> save(SocRecord record);
  Future<void> delete(String id);
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
  @override
  String toString() => key;
}

/// Who may do something.
enum Audience { everyone, friendsOfFriends, friends, nobody }

/// Thrown when an action is refused (permissions, privacy, blocks…).
class SocialDenied implements Exception {
  const SocialDenied(this.code, [this.detail]);

  /// self, blocked, privacy, duplicate, already_friends, not_found,
  /// not_owner, not_friends, not_participant, alters_closed,
  /// username_taken, not_managed, invalid.
  final String code;
  final String? detail;
  @override
  String toString() => 'SocialDenied($code)';
}
