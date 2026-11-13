import 'package:flutter/foundation.dart';

import 'package:prism_plurality/domain/models/tracker_record.dart';

/// Record kinds for the in-system social layer (Bulletin Board feed and
/// Alter Stories). Everything lives in the synced tracker store, so posts
/// follow the system to every paired device. Each record's `memberId` is
/// the authoring alter, never "whoever is fronting".
abstract final class SocialKind {
  static const post = 'social.post';
  static const comment = 'social.comment';
  static const reaction = 'social.reaction';
  static const vote = 'social.vote';
  static const follow = 'social.follow';
  static const block = 'social.block';
  static const hide = 'social.hide';
  static const report = 'social.report';
  static const profile = 'social.profile';
  static const seen = 'social.seen';
  static const media = 'social.media';
  static const story = 'story.item';
  static const storyView = 'story.view';
  static const highlight = 'story.highlight';

  static const all = {post, comment, reaction, vote, follow, block, hide, report, profile, seen, media, story, storyView, highlight};
}

enum PostType { text, image, poll, question, media }

enum PostStatus { published, draft, scheduled }

/// Who can see a post or story.
enum Audience {
  /// Every alter in the system.
  everyone,

  /// Alters who follow the author.
  followers,

  /// Only the alters picked in `audienceIds`.
  selected,

  /// Only the author.
  self,
}

T _enum<T extends Enum>(List<T> values, Object? name, T fallback) =>
    values.firstWhere((v) => v.name == name, orElse: () => fallback);

/// A post (or reblog / quote) read from a tracker record.
@immutable
class Post {
  const Post(this.r);

  final TrackerRecord r;

  String get id => r.id;
  String? get author => r.memberId;
  String get title => r.title;
  String get body => r.body ?? '';
  PostType get type => _enum(PostType.values, r.str('type'), PostType.text);
  PostStatus get status => _enum(PostStatus.values, r.str('status'), PostStatus.published);
  Audience get audience => _enum(Audience.values, r.str('audience'), Audience.everyone);
  List<String> get audienceIds => r.strings('audienceIds');
  List<String> get tags => r.tags;
  List<String> get images => r.strings('images');
  String? get video => r.str('video');
  String? get trackId => r.str('trackId');

  /// The post this one reblogs (shares, optionally with commentary).
  String? get reblogOf => r.str('reblogOf');

  /// The post this one quotes (new post embedding the original).
  String? get quoteOf => r.str('quoteOf');
  List<String> get pollOptions => r.strings('pollOptions');
  bool get pollMulti => r.flag('pollMulti');
  DateTime? get pollCloses => r.integer('pollCloses') == null ? null : DateTime.fromMillisecondsSinceEpoch(r.integer('pollCloses')!);

  /// For question posts: who it is addressed to (null = anyone).
  String? get askedTo => r.str('askedTo');
  String? get contentWarning => r.str('cw');
  bool get pinned => r.isPinned;
  DateTime get publishedAt => r.occurredAt ?? r.createdAt;
  DateTime? get editedAt => r.integer('editedAt') == null ? null : DateTime.fromMillisecondsSinceEpoch(r.integer('editedAt')!);

  /// Published, or scheduled for a time that has passed.
  bool isLive(DateTime now) => switch (status) {
    PostStatus.published => true,
    PostStatus.draft => false,
    PostStatus.scheduled => !publishedAt.isAfter(now),
  };
}

@immutable
class Comment {
  const Comment(this.r);
  final TrackerRecord r;
  String get id => r.id;
  String get target => r.parentId ?? '';
  String? get author => r.memberId;
  String get body => r.body ?? '';
  String? get replyTo => r.str('replyTo');
  DateTime get at => r.createdAt;
  DateTime? get editedAt => r.integer('editedAt') == null ? null : DateTime.fromMillisecondsSinceEpoch(r.integer('editedAt')!);
}

/// Blog customisation for one alter.
@immutable
class BlogProfile {
  const BlogProfile({
    this.recordId,
    this.bio = '',
    this.banner,
    this.bannerX = 0,
    this.bannerY = 0,
    this.accent,
    this.background,
    this.titleFont = 'default',
    this.layout = 'cards',
    this.customReactions = const [],
    this.storyAudience = Audience.everyone,
  });

  final String? recordId;
  final String bio;

  /// Media id of the blog banner (falls back to the member's profile banner).
  final String? banner;

  /// Banner focal point, −1…1 on each axis.
  final double bannerX;
  final double bannerY;
  final int? accent;
  final int? background;
  final String titleFont;

  /// 'cards' or 'compact'.
  final String layout;

  /// Extra reaction emoji this alter likes to use.
  final List<String> customReactions;
  final Audience storyAudience;

  static BlogProfile of(TrackerRecord? r) {
    if (r == null) return const BlogProfile();
    return BlogProfile(
      recordId: r.id,
      bio: r.body ?? '',
      banner: r.str('banner'),
      bannerX: r.number('bannerX') ?? 0,
      bannerY: r.number('bannerY') ?? 0,
      accent: r.integer('accent'),
      background: r.integer('background'),
      titleFont: r.str('titleFont') ?? 'default',
      layout: r.str('layout') ?? 'cards',
      customReactions: r.strings('reactions'),
      storyAudience: _enum(Audience.values, r.str('storyAudience'), Audience.everyone),
    );
  }

  Map<String, Object?> fields() => {
    'banner': banner,
    'bannerX': bannerX,
    'bannerY': bannerY,
    'accent': accent,
    'background': background,
    'titleFont': titleFont,
    'layout': layout,
    'reactions': customReactions,
    'storyAudience': storyAudience.name,
  };

  BlogProfile copyWith({
    String? bio,
    String? banner,
    bool clearBanner = false,
    double? bannerX,
    double? bannerY,
    int? accent,
    bool clearAccent = false,
    int? background,
    bool clearBackground = false,
    String? titleFont,
    String? layout,
    List<String>? customReactions,
    Audience? storyAudience,
  }) => BlogProfile(
    recordId: recordId,
    bio: bio ?? this.bio,
    banner: clearBanner ? null : (banner ?? this.banner),
    bannerX: bannerX ?? this.bannerX,
    bannerY: bannerY ?? this.bannerY,
    accent: clearAccent ? null : (accent ?? this.accent),
    background: clearBackground ? null : (background ?? this.background),
    titleFont: titleFont ?? this.titleFont,
    layout: layout ?? this.layout,
    customReactions: customReactions ?? this.customReactions,
    storyAudience: storyAudience ?? this.storyAudience,
  );
}

/// One frame of a story.
@immutable
class StorySlide {
  const StorySlide({
    this.image,
    this.video,
    this.text = '',
    this.caption = '',
    this.background = 0xFF5C6BC0,
    this.background2,
    this.textColor = 0xFFFFFFFF,
    this.font = 'default',
    this.align = 'center',
    this.textSize = 28,
    this.stickers = const [],
    this.durationMs = 5000,
  });

  final String? image;
  final String? video;
  final String text;
  final String caption;
  final int background;
  final int? background2;
  final int textColor;
  final String font;

  /// 'top', 'center' or 'bottom'.
  final String align;
  final double textSize;
  final List<StorySticker> stickers;
  final int durationMs;

  bool get isEmpty => image == null && video == null && text.trim().isEmpty && stickers.isEmpty;

  StorySlide copyWith({
    String? image,
    bool clearImage = false,
    String? video,
    bool clearVideo = false,
    String? text,
    String? caption,
    int? background,
    int? background2,
    bool clearBackground2 = false,
    int? textColor,
    String? font,
    String? align,
    double? textSize,
    List<StorySticker>? stickers,
    int? durationMs,
  }) => StorySlide(
    image: clearImage ? null : (image ?? this.image),
    video: clearVideo ? null : (video ?? this.video),
    text: text ?? this.text,
    caption: caption ?? this.caption,
    background: background ?? this.background,
    background2: clearBackground2 ? null : (background2 ?? this.background2),
    textColor: textColor ?? this.textColor,
    font: font ?? this.font,
    align: align ?? this.align,
    textSize: textSize ?? this.textSize,
    stickers: stickers ?? this.stickers,
    durationMs: durationMs ?? this.durationMs,
  );

  Map<String, Object?> toJson() => {
    'image': image,
    'video': video,
    'text': text,
    'caption': caption,
    'bg': background,
    'bg2': background2,
    'fg': textColor,
    'font': font,
    'align': align,
    'size': textSize,
    'stickers': [for (final s in stickers) s.toJson()],
    'ms': durationMs,
  };

  static StorySlide fromJson(Object? j) {
    if (j is! Map) return const StorySlide();
    return StorySlide(
      image: j['image'] is String ? j['image'] as String : null,
      video: j['video'] is String ? j['video'] as String : null,
      text: j['text'] is String ? j['text'] as String : '',
      caption: j['caption'] is String ? j['caption'] as String : '',
      background: j['bg'] is int ? j['bg'] as int : 0xFF5C6BC0,
      background2: j['bg2'] is int ? j['bg2'] as int : null,
      textColor: j['fg'] is int ? j['fg'] as int : 0xFFFFFFFF,
      font: j['font'] is String ? j['font'] as String : 'default',
      align: j['align'] is String ? j['align'] as String : 'center',
      textSize: (j['size'] is num ? (j['size'] as num).toDouble() : 28.0).clamp(12, 64).toDouble(),
      stickers: [
        if (j['stickers'] is List)
          for (final s in j['stickers'] as List) ?StorySticker.fromJson(s),
      ],
      durationMs: (j['ms'] is int ? j['ms'] as int : 5000).clamp(2000, 60000),
    );
  }
}

/// An emoji, GIF or text sticker placed on a slide (x/y are fractions).
@immutable
class StorySticker {
  const StorySticker({required this.content, this.x = 0.5, this.y = 0.5, this.scale = 1, this.kind = 'emoji'});

  /// Emoji text, sticker text, or a media id for 'gif'.
  final String content;
  final double x;
  final double y;
  final double scale;

  /// 'emoji', 'text' or 'gif'.
  final String kind;

  StorySticker copyWith({double? x, double? y, double? scale}) =>
      StorySticker(content: content, x: x ?? this.x, y: y ?? this.y, scale: scale ?? this.scale, kind: kind);

  Map<String, Object?> toJson() => {'c': content, 'x': x, 'y': y, 's': scale, 'k': kind};

  static StorySticker? fromJson(Object? j) {
    if (j is! Map || j['c'] is! String) return null;
    double d(Object? v, double def) => v is num ? v.toDouble() : def;
    return StorySticker(
      content: j['c'] as String,
      x: d(j['x'], 0.5).clamp(0, 1).toDouble(),
      y: d(j['y'], 0.5).clamp(0, 1).toDouble(),
      scale: d(j['s'], 1).clamp(0.3, 4).toDouble(),
      kind: j['k'] is String ? j['k'] as String : 'emoji',
    );
  }
}

const storyLifetime = Duration(hours: 24);

@immutable
class Story {
  const Story(this.r);
  final TrackerRecord r;

  String get id => r.id;
  String? get author => r.memberId;
  List<StorySlide> get slides {
    final raw = r.fields['slides'];
    return [if (raw is List) for (final s in raw) StorySlide.fromJson(s)];
  }

  String? get trackId => r.str('trackId');
  Audience get audience => _enum(Audience.values, r.str('audience'), Audience.everyone);
  List<String> get audienceIds => r.strings('audienceIds');
  DateTime get postedAt => r.occurredAt ?? r.createdAt;
  DateTime get expiresAt => postedAt.add(storyLifetime);

  /// Kept after expiry (in the author's archive) instead of disappearing.
  bool get archived => r.flag('archive');
  bool isActive(DateTime now) => now.isBefore(expiresAt);
}

@immutable
class Highlight {
  const Highlight(this.r);
  final TrackerRecord r;
  String get id => r.id;
  String? get owner => r.memberId;
  String get title => r.title;
  String get category => r.str('category') ?? '';
  List<String> get storyIds => r.strings('stories');
  String? get cover => r.str('cover');
}

/// Hashtags (#word) and @mentions found in text.
final hashtagPattern = RegExp(r'(?<![\w#])#([\p{L}\p{N}_]{1,40})', unicode: true);
final mentionPattern = RegExp(r'(?<![\w@])@([\p{L}\p{N}_.\-]{1,40})', unicode: true);

List<String> extractTags(String text) => {
  for (final m in hashtagPattern.allMatches(text)) m.group(1)!.toLowerCase(),
}.toList();

String normalizeTag(String tag) => tag.trim().replaceAll(RegExp(r'^#+'), '').toLowerCase();

/// Default reactions offered on posts, comments and stories.
const defaultReactions = ['❤️', '😂', '😮', '😢', '🔥', '🫂', '👏', '✨'];
