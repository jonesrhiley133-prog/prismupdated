import 'dart:async';

import 'package:prism_plurality/shared/theme/prism_shapes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/features/music/services/music_library.dart';
import 'package:prism_plurality/features/music/services/music_player.dart';
import 'package:prism_plurality/features/social/models/social.dart';
import 'package:prism_plurality/features/social/services/social_actions.dart';
import 'package:prism_plurality/features/social/services/social_data.dart';
import 'package:prism_plurality/features/social/views/social_nav.dart';
import 'package:prism_plurality/features/social/views/story_composer.dart';
import 'package:prism_plurality/features/social/widgets/post_card.dart';
import 'package:prism_plurality/features/social/widgets/social_widgets.dart';
import 'package:prism_plurality/features/social/widgets/video_tile.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_toast.dart';

TextStyle storyFont(String font, double size, Color color) {
  final base = TextStyle(
    fontSize: size,
    color: color,
    height: 1.2,
    shadows: const [Shadow(blurRadius: 8, color: Colors.black38)],
  );
  return switch (font) {
    'serif' => base.copyWith(fontFamily: 'serif', fontWeight: FontWeight.w600),
    'mono' => base.copyWith(fontFamily: 'monospace'),
    'bold' => base.copyWith(fontWeight: FontWeight.w900),
    'script' => base.copyWith(
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w300,
    ),
    _ => base.copyWith(fontWeight: FontWeight.w700),
  };
}

/// Renders one slide (background, photo or video, text, stickers, caption).
class StorySlideView extends StatelessWidget {
  const StorySlideView({
    super.key,
    required this.slide,
    this.mini = false,
    this.onVideoReady,
    this.stickerBuilder,
  });

  final StorySlide slide;
  final bool mini;
  final ValueChanged<Duration>? onVideoReady;

  /// Lets the composer make stickers draggable.
  final Widget Function(int index, StorySticker sticker, Widget child)?
  stickerBuilder;

  @override
  Widget build(BuildContext context) {
    final scale = mini ? 0.3 : 1.0;
    final bg = slide.background2 == null
        ? BoxDecoration(color: Color(slide.background))
        : BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(slide.background), Color(slide.background2!)],
            ),
          );
    return LayoutBuilder(
      builder: (context, box) => DecoratedBox(
        decoration: bg,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (slide.image != null)
              SocialImage(id: slide.image!, fit: BoxFit.cover),
            if (slide.video != null && !mini)
              VideoTile(
                id: slide.video!,
                autoplay: true,
                fill: true,
                onReady: onVideoReady,
              ),
            if (slide.video != null && mini)
              const Center(
                child: Icon(Icons.movie_outlined, color: Colors.white70),
              ),
            if (slide.text.trim().isNotEmpty)
              Align(
                alignment: switch (slide.align) {
                  'top' => const Alignment(0, -0.7),
                  'bottom' => const Alignment(0, 0.6),
                  _ => Alignment.center,
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24 * scale),
                  child: Text(
                    slide.text,
                    textAlign: TextAlign.center,
                    style: storyFont(
                      slide.font,
                      slide.textSize * scale,
                      Color(slide.textColor),
                    ),
                  ),
                ),
              ),
            for (var i = 0; i < slide.stickers.length; i++)
              Positioned(
                left:
                    slide.stickers[i].x * box.maxWidth -
                    40 * slide.stickers[i].scale * scale,
                top:
                    slide.stickers[i].y * box.maxHeight -
                    40 * slide.stickers[i].scale * scale,
                child: () {
                  final s = slide.stickers[i];
                  final child = SizedBox(
                    width: 80 * s.scale * scale,
                    height: 80 * s.scale * scale,
                    child: switch (s.kind) {
                      'gif' => ClipRRect(
                        borderRadius: prismCorners(context, 8),
                        child: SocialImage(id: s.content, fit: BoxFit.contain),
                      ),
                      'text' => FittedBox(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: prismCorners(context, 8),
                          ),
                          child: Text(
                            s.content,
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      _ => FittedBox(
                        child: Text(
                          s.content,
                          style: const TextStyle(fontSize: 64),
                        ),
                      ),
                    },
                  );
                  return stickerBuilder?.call(i, s, child) ?? child;
                }(),
              ),
            if (slide.caption.trim().isNotEmpty && !mini)
              Positioned(
                left: 16,
                right: 16,
                bottom: 90,
                child: Text(
                  slide.caption,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    shadows: [Shadow(blurRadius: 6, color: Colors.black87)],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

void openStories(BuildContext context, List<String> authors, {int start = 0}) {
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: true,
      pageBuilder: (_, _, _) =>
          StoryViewerScreen(authors: authors, startAuthor: start),
      transitionsBuilder: (_, a, _, child) =>
          FadeTransition(opacity: a, child: child),
    ),
  );
}

void openHighlight(BuildContext context, Highlight h) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => StoryViewerScreen(authors: [h.owner ?? ''], highlight: h),
    ),
  );
}

void openStoryComposer(BuildContext context, String? author) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => StoryComposerScreen(author: author),
    ),
  );
}

/// Full-screen story player. Tap the right side for next, left for
/// previous, hold to pause, swipe down to close. Viewing never changes
/// who is fronting.
class StoryViewerScreen extends ConsumerStatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.authors,
    this.startAuthor = 0,
    this.highlight,
  });

  final List<String> authors;
  final int startAuthor;
  final Highlight? highlight;

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late int _author = widget.startAuthor;
  int _index = 0;
  late final AnimationController _progress = AnimationController(vsync: this)
    ..addStatusListener(_onStatus);
  bool _paused = false;
  final _reply = TextEditingController();
  final _replyFocus = FocusNode();
  String? _startedFor;

  @override
  void initState() {
    super.initState();
    _replyFocus.addListener(() => _setPaused(_replyFocus.hasFocus));
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCurrent());
  }

  @override
  void dispose() {
    _progress.dispose();
    _reply.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  /// (story, slide) pairs for the current author.
  List<(Story, StorySlide)> _frames() {
    final d = ref.read(socialDataProvider);
    final viewer = ref.read(socialActorProvider);
    final List<Story> stories;
    if (widget.highlight != null) {
      stories = [
        for (final id in widget.highlight!.storyIds)
          if (d.stories[id] != null && d.canSeeStory(d.stories[id]!, viewer))
            d.stories[id]!,
      ];
    } else {
      if (_author >= widget.authors.length) return const [];
      stories = d.activeStories(viewer)[widget.authors[_author]] ?? const [];
    }
    return [
      for (final s in stories)
        for (final sl in s.slides) (s, sl),
    ];
  }

  void _startCurrent({Duration? duration}) {
    final frames = _frames();
    if (frames.isEmpty) {
      _nextAuthor();
      return;
    }
    if (_index >= frames.length) _index = frames.length - 1;
    final (story, slide) = frames[_index];
    final key = '${story.id}:$_index';
    if (_startedFor != key || duration != null) {
      _startedFor = key;
      _progress.duration =
          duration ??
          Duration(
            milliseconds: slide.video != null ? 15000 : slide.durationMs,
          );
      _progress.forward(from: 0);
      if (_paused) _progress.stop();
      final viewer = ref.read(socialActorProvider);
      if (viewer != null)
        unawaited(
          ref
              .read(socialActionsProvider)
              .markViewed(viewer: viewer, story: story),
        );
    }
    setState(() {});
  }

  void _onStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed) _next();
  }

  void _next() {
    final frames = _frames();
    if (_index + 1 < frames.length) {
      _index++;
      _startCurrent();
    } else {
      _nextAuthor();
    }
  }

  void _prev() {
    if (_index > 0) {
      _index--;
      _startCurrent();
    } else if (_author > 0 && widget.highlight == null) {
      _author--;
      _index = 0;
      _startCurrent();
    } else {
      _progress.forward(from: 0);
    }
  }

  void _nextAuthor() {
    if (widget.highlight == null && _author + 1 < widget.authors.length) {
      _author++;
      _index = 0;
      _startCurrent();
    } else if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  void _setPaused(bool p) {
    if (_paused == p) return;
    _paused = p;
    p ? _progress.stop() : _progress.forward();
    setState(() {});
  }

  Future<void> _sendReply(Story s) async {
    final viewer = ref.read(socialActorProvider);
    final text = _reply.text.trim();
    if (viewer == null || text.isEmpty) return;
    await ref
        .read(socialActionsProvider)
        .comment(actor: viewer, targetId: s.id, body: text);
    _reply.clear();
    _replyFocus.unfocus();
    if (mounted)
      PrismToast.success(context, message: context.l10n.stoReplySent);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final d = ref.watch(socialDataProvider);
    final viewer = ref.watch(socialActorProvider);
    final frames = _frames();
    if (frames.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            l10n.stoNothing,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
    final (story, slide) = frames[_index.clamp(0, frames.length - 1)];
    final mine = story.author == viewer;
    final views = d.storyViews[story.id] ?? const <String, DateTime>{};
    final track = story.trackId == null
        ? null
        : ref.watch(musicLibraryProvider).value?.track(story.trackId);

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowRight): _Go('next'),
        SingleActivator(LogicalKeyboardKey.arrowLeft): _Go('prev'),
        SingleActivator(LogicalKeyboardKey.space): _Go('pause'),
        SingleActivator(LogicalKeyboardKey.escape): _Go('close'),
      },
      child: Actions(
        actions: {
          _Go: CallbackAction<_Go>(
            onInvoke: (g) {
              switch (g.what) {
                case 'next':
                  _next();
                case 'prev':
                  _prev();
                case 'pause':
                  _setPaused(!_paused);
                default:
                  Navigator.of(context).maybePop();
              }
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: Colors.black,
            resizeToAvoidBottomInset: true,
            body: SafeArea(
              child: GestureDetector(
                onVerticalDragEnd: (e) {
                  if ((e.primaryVelocity ?? 0) > 400)
                    Navigator.of(context).maybePop();
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(
                      child: AspectRatio(
                        aspectRatio: 9 / 16,
                        child: ClipRRect(
                          borderRadius: prismCorners(context, 12),
                          child: Semantics(
                            label: [
                              l10n.stoSlideOf(_index + 1, frames.length),
                              if (slide.text.isNotEmpty) slide.text,
                              if (slide.caption.isNotEmpty) slide.caption,
                            ].join('. '),
                            child: StorySlideView(
                              key: ValueKey('${story.id}:$_index'),
                              slide: slide,
                              onVideoReady: (dur) => _startCurrent(
                                duration: dur.inMilliseconds > 0 ? dur : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Tap zones.
                    Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            button: true,
                            label: l10n.stoPrevious,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: _prev,
                              onLongPressStart: (_) => _setPaused(true),
                              onLongPressEnd: (_) => _setPaused(false),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Semantics(
                            button: true,
                            label: l10n.stoNext,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: _next,
                              onLongPressStart: (_) => _setPaused(true),
                              onLongPressEnd: (_) => _setPaused(false),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Progress + header.
                    Positioned(
                      left: 8,
                      right: 8,
                      top: 8,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              for (var i = 0; i < frames.length; i++)
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: prismCorners(context, 2),
                                      child: SizedBox(
                                        height: 3,
                                        child: i == _index
                                            ? AnimatedBuilder(
                                                animation: _progress,
                                                builder: (_, _) =>
                                                    LinearProgress(
                                                      value: _progress.value,
                                                    ),
                                              )
                                            : LinearProgress(
                                                value: i < _index ? 1 : 0,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              AlterAvatar(
                                memberId: story.author,
                                size: 34,
                                onTap: story.author == null
                                    ? null
                                    : () {
                                        Navigator.of(context).pop();
                                        openAlterBlog(context, story.author!);
                                      },
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${alterName(d, story.author, context)}${widget.highlight != null ? ' · ${widget.highlight!.title}' : ''}  ${relativeTime(context, story.postedAt, now: d.now)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    shadows: [Shadow(blurRadius: 4)],
                                  ),
                                ),
                              ),
                              _Btn(
                                icon: _paused
                                    ? Icons.play_arrow_rounded
                                    : Icons.pause_rounded,
                                label: _paused ? l10n.musPlay : l10n.musPause,
                                onTap: () => _setPaused(!_paused),
                              ),
                              if (mine)
                                _Btn(
                                  icon: Icons.more_vert_rounded,
                                  label: l10n.socPostOptions,
                                  onTap: () => _ownMenu(story),
                                ),
                              _Btn(
                                icon: Icons.close_rounded,
                                label: MaterialLocalizations.of(
                                  context,
                                ).closeButtonTooltip,
                                onTap: () => Navigator.of(context).maybePop(),
                              ),
                            ],
                          ),
                          if (track != null)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Semantics(
                                  button: true,
                                  label: l10n.stoPlayTrack(track.title),
                                  excludeSemantics: true,
                                  child: GestureDetector(
                                    onTap: () => ref
                                        .read(musicControllerProvider.notifier)
                                        .playTracks(
                                          [track.id],
                                          name: alterName(
                                            d,
                                            story.author,
                                            context,
                                          ),
                                        ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black45,
                                        borderRadius: prismCorners(context, 14),
                                      ),
                                      child: Text(
                                        '♪ ${track.title}${track.artist.isEmpty ? '' : ' · ${track.artist}'}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Bottom bar.
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: mine
                          ? Center(
                              child: Semantics(
                                button: true,
                                label: l10n.stoSeenBy(views.length),
                                excludeSemantics: true,
                                child: GestureDetector(
                                  onTap: () => _viewers(story),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: prismCorners(context, 20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.visibility_outlined,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          l10n.stoSeenBy(views.length),
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                        if ((d
                                                .commentsOn[story.id]
                                                ?.isNotEmpty ??
                                            false)) ...[
                                          const SizedBox(width: 10),
                                          const Icon(
                                            Icons.chat_bubble_outline_rounded,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${d.commentsOn[story.id]!.length}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : viewer == null
                          ? const SizedBox.shrink()
                          : Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _reply,
                                    focusNode: _replyFocus,
                                    style: const TextStyle(color: Colors.white),
                                    textInputAction: TextInputAction.send,
                                    onSubmitted: (_) => _sendReply(story),
                                    decoration: InputDecoration(
                                      hintText: l10n.stoReplyTo(
                                        alterName(d, story.author, context),
                                      ),
                                      hintStyle: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                      filled: true,
                                      fillColor: Colors.black38,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 10,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: prismCorners(context, 24),
                                        borderSide: const BorderSide(
                                          color: Colors.white54,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: prismCorners(context, 24),
                                        borderSide: const BorderSide(
                                          color: Colors.white54,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                for (final e in const ['❤️', '😂', '🫂'])
                                  Semantics(
                                    button: true,
                                    label: l10n.stoReactWith(e),
                                    toggled: d
                                        .reactions(story.id, viewer)
                                        .mine
                                        .contains(e),
                                    excludeSemantics: true,
                                    child: InkResponse(
                                      onTap: () => ref
                                          .read(socialActionsProvider)
                                          .toggleReaction(
                                            actor: viewer,
                                            targetId: story.id,
                                            emoji: e,
                                          ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(6),
                                        child: AnimatedScale(
                                          scale:
                                              d
                                                  .reactions(story.id, viewer)
                                                  .mine
                                                  .contains(e)
                                              ? 1.25
                                              : 1,
                                          duration: const Duration(
                                            milliseconds: 150,
                                          ),
                                          child: Text(
                                            e,
                                            style: const TextStyle(
                                              fontSize: 26,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _viewers(Story s) async {
    _setPaused(true);
    final l10n = context.l10n;
    final d = ref.read(socialDataProvider);
    final views =
        (d.storyViews[s.id] ?? const <String, DateTime>{}).entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final reactions = d.reactionsOn[s.id] ?? const [];
    final replies = d.commentsOn[s.id] ?? const <Comment>[];
    await PrismSheet.show<void>(
      context: context,
      title: l10n.stoActivity,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.stoSeenBy(views.length),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final v in views)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    AlterAvatar(memberId: v.key, size: 32),
                    const SizedBox(width: 10),
                    Expanded(child: Text(alterName(d, v.key, context))),
                    Text(
                      [
                        for (final r in reactions)
                          if (r.memberId == v.key) r.title,
                      ].join(' '),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      relativeTime(context, v.value, now: d.now),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            if (replies.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                l10n.stoReplies,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (final c in replies)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AlterAvatar(memberId: c.author, size: 28),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${alterName(d, c.author, context)}: ${c.body}',
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
    if (mounted) _setPaused(false);
  }

  Future<void> _ownMenu(Story s) async {
    _setPaused(true);
    final l10n = context.l10n;
    final d = ref.read(socialDataProvider);
    final a = ref.read(socialActionsProvider);
    final highlights = d.highlightsOf(s.author ?? '');
    await PrismSheet.show<void>(
      context: context,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MenuRow(
              icon: s.archived ? Icons.archive_rounded : Icons.archive_outlined,
              label: s.archived ? l10n.stoArchiveOn : l10n.stoArchiveOff,
              hint: l10n.stoArchiveHelp,
              onTap: () {
                Navigator.of(sheet).pop();
                a.setStoryArchived(s, !s.archived);
              },
            ),
            for (final h in highlights)
              MenuRow(
                icon: Icons.bookmark_add_outlined,
                label: l10n.stoAddToHighlight(h.title),
                onTap: () {
                  Navigator.of(sheet).pop();
                  a.addToHighlight(h, s);
                  PrismToast.success(
                    context,
                    message: l10n.stoAddedToHighlight(h.title),
                  );
                },
              ),
            MenuRow(
              icon: Icons.delete_outline_rounded,
              label: l10n.stoDelete,
              destructive: true,
              onTap: () async {
                Navigator.of(sheet).pop();
                await a.deleteStory(s);
                if (mounted) Navigator.of(context).maybePop();
              },
            ),
          ],
        ),
      ),
    );
    if (mounted) _setPaused(false);
  }
}

class _Go extends Intent {
  const _Go(this.what);
  final String what;
}

class _Btn extends StatelessWidget {
  const _Btn({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: InkResponse(
      onTap: onTap,
      radius: 22,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          color: Colors.white,
          shadows: const [Shadow(blurRadius: 4)],
        ),
      ),
    ),
  );
}

/// Thin progress segment (not the banned Material widget).
class LinearProgress extends StatelessWidget {
  const LinearProgress({super.key, required this.value});
  final double value;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const ColoredBox(color: Colors.white38),
      FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value.clamp(0, 1),
        child: const ColoredBox(color: Colors.white),
      ),
    ],
  );
}
