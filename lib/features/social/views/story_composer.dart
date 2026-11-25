import 'package:prism_plurality/shared/theme/prism_shapes.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/appearance/views/look_controls.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/music/models/music_models.dart';
import 'package:prism_plurality/features/music/services/music_library.dart';
import 'package:prism_plurality/features/social/models/social.dart';
import 'package:prism_plurality/features/social/services/social_actions.dart';
import 'package:prism_plurality/features/social/services/social_data.dart';
import 'package:prism_plurality/features/social/services/social_media.dart';
import 'package:prism_plurality/features/social/views/story_viewer.dart';
import 'package:prism_plurality/features/social/widgets/post_card.dart';
import 'package:prism_plurality/features/social/widgets/social_widgets.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_switch_row.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';
import 'package:prism_plurality/shared/widgets/prism_toast.dart';

const _stickerEmoji = ['😀', '🥰', '😎', '🥺', '😭', '🔥', '✨', '💜', '🌈', '🌙', '⭐', '🎉', '🫂', '☕', '🎧', '📚', '🌸', '🐱', '🐶', '🍕', '💤', '🧠', '🦋', '👋'];
const _fonts = ['default', 'bold', 'serif', 'mono', 'script'];

class StoryComposerScreen extends ConsumerStatefulWidget {
  const StoryComposerScreen({super.key, this.author});
  final String? author;

  @override
  ConsumerState<StoryComposerScreen> createState() => _StoryComposerScreenState();
}

class _StoryComposerScreenState extends ConsumerState<StoryComposerScreen> {
  late String? _author = widget.author ?? ref.read(socialActorProvider);
  final List<StorySlide> _slides = [const StorySlide()];
  int _current = 0;
  String? _trackId;
  late Audience _audience = _author == null ? Audience.everyone : ref.read(socialDataProvider).profile(_author!).storyAudience;
  List<String> _audienceIds = const [];
  bool _archive = true;
  bool _busy = false;
  final _text = TextEditingController();
  final _caption = TextEditingController();

  StorySlide get _slide => _slides[_current];

  @override
  void initState() {
    super.initState();
    _syncFields();
  }

  @override
  void dispose() {
    _text.dispose();
    _caption.dispose();
    super.dispose();
  }

  void _syncFields() {
    _text.text = _slide.text;
    _caption.text = _slide.caption;
  }

  void _update(StorySlide s) => setState(() => _slides[_current] = s);

  void _select(int i) {
    setState(() => _current = i);
    _syncFields();
  }

  Future<void> _pickPhoto() async {
    final l10n = context.l10n;
    final f = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (f == null) return;
    final id = await ref.read(socialMediaStoreProvider).addImage(await f.readAsBytes(), owner: _author);
    if (!mounted) return;
    if (id == null) {
      PrismToast.error(context, message: l10n.socImageUnreadable(f.name));
    } else {
      _update(_slide.copyWith(image: id, clearVideo: true));
    }
  }

  Future<void> _pickCamera() async {
    final f = await ImagePicker().pickImage(source: ImageSource.camera);
    if (f == null) return;
    final id = await ref.read(socialMediaStoreProvider).addImage(await f.readAsBytes(), owner: _author);
    if (id != null && mounted) _update(_slide.copyWith(image: id, clearVideo: true));
  }

  Future<void> _pickVideo() async {
    final l10n = context.l10n;
    final r = await FilePicker.pickFiles(type: FileType.video);
    final path = r?.files.firstOrNull?.path;
    if (path == null) return;
    final res = await ref.read(socialMediaStoreProvider).addVideo(path);
    if (!mounted) return;
    if (res.id == null) {
      PrismToast.error(context, message: res.error == 'tooLarge' ? l10n.socVideoTooLarge : (res.error == 'format' ? l10n.socVideoFormat : l10n.socVideoFailed));
    } else {
      _update(_slide.copyWith(video: res.id, clearImage: true));
    }
  }

  Future<void> _addSticker() async {
    final l10n = context.l10n;
    final choice = await PrismSheet.show<String>(
      context: context,
      title: l10n.stoStickers,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final e in _stickerEmoji)
                  InkResponse(onTap: () => Navigator.of(sheet).pop('emoji:$e'), child: Padding(padding: const EdgeInsets.all(6), child: Text(e, style: const TextStyle(fontSize: 32)))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: PrismButton(label: l10n.stoTextSticker, onPressed: () => Navigator.of(sheet).pop('text'))),
                const SizedBox(width: 8),
                Expanded(child: PrismButton(label: l10n.stoGifSticker, onPressed: () => Navigator.of(sheet).pop('gif'))),
              ],
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    StorySticker? s;
    if (choice.startsWith('emoji:')) {
      s = StorySticker(content: choice.substring(6));
    } else if (choice == 'text') {
      final t = await askText(context, title: l10n.stoTextSticker, label: l10n.stoStickerText, maxLines: 1);
      if (t != null) s = StorySticker(content: t, kind: 'text', scale: 1.4);
    } else {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (f != null) {
        final id = await ref.read(socialMediaStoreProvider).addImage(await f.readAsBytes(), owner: _author);
        if (id != null) s = StorySticker(content: id, kind: 'gif', scale: 1.6);
      }
    }
    if (s != null && mounted) _update(_slide.copyWith(stickers: [..._slide.stickers, s]));
  }

  Future<void> _pickMusic() async {
    final l10n = context.l10n;
    final lib = ref.read(musicLibraryProvider).value ?? const MusicLibrary();
    if (lib.tracks.isEmpty) {
      PrismToast.show(context, message: l10n.stoNoMusic);
      return;
    }
    final id = await PrismSheet.show<String>(
      context: context,
      title: l10n.stoAddMusic,
      builder: (sheet) => SizedBox(
        height: 420,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: [
            MenuRow(icon: Icons.music_off_rounded, label: l10n.stoNoSong, onTap: () => Navigator.of(sheet).pop('')),
            for (final t in filterTracks(lib.tracks))
              MenuRow(icon: Icons.music_note_rounded, label: t.title, hint: t.artist.isEmpty ? null : t.artist, onTap: () => Navigator.of(sheet).pop(t.id)),
          ],
        ),
      ),
    );
    if (id != null) setState(() => _trackId = id.isEmpty ? null : id);
  }

  Future<void> _post() async {
    final l10n = context.l10n;
    final slides = [for (final s in _slides) if (!s.isEmpty) s];
    if (_author == null || slides.isEmpty || _busy) return;
    setState(() => _busy = true);
    await ref.read(socialActionsProvider).postStory(
      actor: _author!,
      slides: slides,
      trackId: _trackId,
      audience: _audience,
      audienceIds: _audienceIds,
      archive: _archive,
    );
    if (!mounted) return;
    PrismToast.success(context, message: l10n.stoPosted);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final d = ref.watch(socialDataProvider);
    final members = (ref.watch(userVisibleMemberListProvider).value ?? const <Member>[]).where((m) => m.isActive).toList();
    final track = _trackId == null ? null : ref.watch(musicLibraryProvider).value?.track(_trackId);
    final canPost = _author != null && _slides.any((s) => !s.isEmpty) && !_busy;

    final preview = AspectRatio(
      aspectRatio: 9 / 16,
      child: ClipRRect(
        borderRadius: prismCorners(context, 16),
        child: LayoutBuilder(
          builder: (context, box) => StorySlideView(
            slide: _slide,
            stickerBuilder: (i, s, child) => GestureDetector(
              onPanUpdate: (e) {
                final list = [..._slide.stickers];
                list[i] = s.copyWith(x: (s.x + e.delta.dx / box.maxWidth).clamp(0, 1), y: (s.y + e.delta.dy / box.maxHeight).clamp(0, 1));
                _update(_slide.copyWith(stickers: list));
              },
              onDoubleTap: () {
                final list = [..._slide.stickers];
                list[i] = s.copyWith(scale: s.scale >= 3 ? 0.6 : s.scale + 0.4);
                _update(_slide.copyWith(stickers: list));
              },
              onLongPress: () => _update(_slide.copyWith(stickers: [..._slide.stickers]..removeAt(i))),
              child: Semantics(label: l10n.stoStickerHint, child: child),
            ),
          ),
        ),
      ),
    );

    final controls = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AlterAvatar(memberId: _author, size: 32),
            const SizedBox(width: 8),
            Expanded(child: Text(_author == null ? l10n.socPickAlter : l10n.socPostingAs(alterName(d, _author, context)), style: theme.textTheme.titleSmall)),
            PrismButton(
              label: l10n.socChange,
              density: PrismControlDensity.compact,
              onPressed: () async {
                final id = await pickAlter(context, ref, title: l10n.socWhoIsPosting);
                if (id != null) setState(() => _author = id);
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 76,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < _slides.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Semantics(
                    button: true,
                    selected: i == _current,
                    label: l10n.stoSlideOf(i + 1, _slides.length),
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: () => _select(i),
                      onLongPress: _slides.length > 1
                          ? () => setState(() {
                              _slides.removeAt(i);
                              _current = _current.clamp(0, _slides.length - 1);
                              _syncFields();
                            })
                          : null,
                      child: Container(
                        width: 44,
                        decoration: BoxDecoration(borderRadius: prismCorners(context, 8), border: Border.all(width: i == _current ? 3 : 1, color: i == _current ? theme.colorScheme.primary : theme.colorScheme.outlineVariant)),
                        child: ClipRRect(borderRadius: prismCorners(context, 6), child: StorySlideView(slide: _slides[i], mini: true)),
                      ),
                    ),
                  ),
                ),
              if (_slides.length < 10)
                Semantics(
                  button: true,
                  label: l10n.stoAddSlide,
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _slides.add(StorySlide(background: _slide.background, background2: _slide.background2, textColor: _slide.textColor, font: _slide.font));
                        _current = _slides.length - 1;
                      });
                      _syncFields();
                    },
                    child: Container(
                      width: 44,
                      decoration: BoxDecoration(borderRadius: prismCorners(context, 8), border: Border.all(color: theme.colorScheme.outlineVariant)),
                      child: const Icon(Icons.add_rounded),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Text(l10n.stoSlidesHelp, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            PrismButton(label: l10n.stoPhoto, icon: Icons.photo_outlined, onPressed: _pickPhoto),
            PrismButton(label: l10n.stoCamera, icon: Icons.photo_camera_outlined, onPressed: _pickCamera),
            PrismButton(label: l10n.stoVideo, icon: Icons.videocam_outlined, onPressed: _pickVideo),
            PrismButton(label: l10n.stoSticker, icon: Icons.emoji_emotions_outlined, onPressed: _addSticker),
            PrismButton(label: track == null ? l10n.stoAddMusic : '♪ ${track.title}', icon: Icons.music_note_outlined, onPressed: _pickMusic),
            if (_slide.image != null || _slide.video != null)
              PrismButton(label: l10n.stoRemoveMedia, tone: PrismButtonTone.destructive, onPressed: () => _update(_slide.copyWith(clearImage: true, clearVideo: true))),
          ],
        ),
        const SizedBox(height: 10),
        PrismTextField(controller: _text, labelText: l10n.stoText, minLines: 1, maxLines: 4, onChanged: (v) => _update(_slide.copyWith(text: v))),
        const SizedBox(height: 8),
        PrismTextField(controller: _caption, labelText: l10n.stoCaption, onChanged: (v) => _update(_slide.copyWith(caption: v))),
        const SizedBox(height: 8),
        Text(l10n.stoFont, style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final f in _fonts)
              PrismChip(
                label: switch (f) { 'bold' => l10n.socFontBold, 'serif' => l10n.hwFontSerif, 'mono' => l10n.hwFontMono, 'script' => l10n.stoFontScript, _ => l10n.apDefault },
                selected: _slide.font == f,
                onTap: () => _update(_slide.copyWith(font: f)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: [
            for (final a in const ['top', 'center', 'bottom'])
              PrismChip(
                label: switch (a) { 'top' => l10n.stoAlignTop, 'bottom' => l10n.stoAlignBottom, _ => l10n.stoAlignCenter },
                selected: _slide.align == a,
                onTap: () => _update(_slide.copyWith(align: a)),
              ),
          ],
        ),
        LabeledSlider(label: l10n.stoTextSize, value: _slide.textSize, min: 14, max: 56, divisions: 21, format: (v) => v.round().toString(), onChanged: (v) => _update(_slide.copyWith(textSize: v))),
        ColorChoiceRow(label: l10n.stoTextColor, value: _slide.textColor, allowDefault: false, onChanged: (v) => _update(_slide.copyWith(textColor: v))),
        ColorChoiceRow(label: l10n.stoBackground, value: _slide.background, allowDefault: false, onChanged: (v) => _update(_slide.copyWith(background: v))),
        ColorChoiceRow(
          label: l10n.stoBackground2,
          value: _slide.background2,
          onChanged: (v) => _update(v == null ? _slide.copyWith(clearBackground2: true) : _slide.copyWith(background2: v)),
        ),
        LabeledSlider(
          label: l10n.stoDuration,
          value: _slide.durationMs / 1000,
          min: 2,
          max: 20,
          divisions: 18,
          format: (v) => '${v.round()} s',
          onChanged: (v) => _update(_slide.copyWith(durationMs: (v * 1000).round())),
        ),
        const SizedBox(height: 8),
        Text(l10n.socWhoCanSee, style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [for (final a in Audience.values) PrismChip(label: audienceLabel(context, a), selected: _audience == a, onTap: () => setState(() => _audience = a))],
        ),
        if (_audience == Audience.selected)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in members)
                  if (m.id != _author)
                    PrismChip(
                      label: m.name,
                      selected: _audienceIds.contains(m.id),
                      onTap: () => setState(() => _audienceIds = _audienceIds.contains(m.id) ? ([..._audienceIds]..remove(m.id)) : [..._audienceIds, m.id]),
                    ),
              ],
            ),
          ),
        PrismSwitchRow(title: l10n.stoKeepArchive, subtitle: l10n.stoKeepArchiveHelp, value: _archive, onChanged: (v) => setState(() => _archive = v)),
        const SizedBox(height: 12),
        PrismButton(label: l10n.stoShare, tone: PrismButtonTone.filled, expanded: true, enabled: canPost, onPressed: _post),
        const SizedBox(height: 24),
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PrismSheetTopBar(title: l10n.stoNewStory),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  final wide = box.maxWidth > 760;
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: 300, child: preview)),
                        Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(8, 16, 16, 16), children: [controls])),
                      ],
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [Center(child: SizedBox(width: (box.maxWidth * 0.62).clamp(180.0, 320.0), child: preview)), const SizedBox(height: 12), controls],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
