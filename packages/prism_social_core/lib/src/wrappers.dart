import 'records.dart';

Audience _aud(Object? v, Audience d) => Audience.values.where((a) => a.name == v).firstOrNull ?? d;

class SProfile {
  SProfile(this.r);
  final SocRecord r;
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
class SAlter {
  SAlter(this.r);
  final SocRecord r;
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

class SPost {
  SPost(this.r);
  final SocRecord r;
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

class SComment {
  SComment(this.r);
  final SocRecord r;
  String get id => r.id;
  String get postId => r.parentId ?? '';
  SocialActor get author => SocialActor.fromJson(r.fields['author']) ?? const SocialActor('');
  String? get replyTo => r.str('replyTo');
  String get body => r.body ?? '';
  DateTime get at => r.occurredAt ?? r.createdAt;
}

class SConv {
  SConv(this.r);
  final SocRecord r;
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

class SMessage {
  SMessage(this.r);
  final SocRecord r;
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

class SNotification {
  SNotification(this.r);
  final SocRecord r;
  String get id => r.id;
  String get recipient => r.parentId ?? '';
  String get type => r.str('type') ?? '';
  SocialActor? get actor => SocialActor.fromJson(r.fields['actor']);
  String? get target => r.str('target');
  String? get preview => r.body;
  bool get read => r.flag('read');
  DateTime get at => r.occurredAt ?? r.createdAt;
}

