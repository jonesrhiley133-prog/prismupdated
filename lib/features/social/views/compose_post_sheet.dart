import 'package:prism_plurality/shared/utils/prism_image_picker.dart';
import 'package:prism_plurality/shared/theme/prism_shapes.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/social/models/social.dart';
import 'package:prism_plurality/features/social/services/social_actions.dart';
import 'package:prism_plurality/features/social/services/social_data.dart';
import 'package:prism_plurality/features/social/services/social_media.dart';
import 'package:prism_plurality/features/social/widgets/social_widgets.dart';
import 'package:prism_plurality/features/social/widgets/video_tile.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_date_picker.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_switch_row.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';
import 'package:prism_plurality/shared/widgets/prism_time_picker.dart';
import 'package:prism_plurality/shared/widgets/prism_toast.dart';

/// Opens the composer. [quote] makes a quote post, [answer] answers a
/// question (as a quote), [edit] edits an existing post or draft.
Future<void> showComposePost(
  BuildContext context, {
  Post? quote,
  Post? edit,
  Post? answer,
  PostType? type,
}) => PrismSheet.showFullScreen<void>(
  context: context,
  builder: (context, scroll) => ComposePostSheet(
    scroll: scroll,
    quote: quote ?? answer,
    edit: edit,
    isAnswer: answer != null,
    initialType: type,
  ),
);

class ComposePostSheet extends ConsumerStatefulWidget {
  const ComposePostSheet({
    super.key,
    required this.scroll,
    this.quote,
    this.edit,
    this.isAnswer = false,
    this.initialType,
  });

  final ScrollController scroll;
  final Post? quote;
  final Post? edit;
  final bool isAnswer;
  final PostType? initialType;

  @override
  ConsumerState<ComposePostSheet> createState() => _ComposePostSheetState();
}

class _ComposePostSheetState extends ConsumerState<ComposePostSheet> {
  late PostType _type =
      widget.edit?.type ?? widget.initialType ?? PostType.text;
  late final _title = TextEditingController(text: widget.edit?.title ?? '');
  late final _body = TextEditingController(text: widget.edit?.body ?? '');
  late final _tags = TextEditingController(
    text: widget.edit?.tags.join(' ') ?? '',
  );
  late final _cw = TextEditingController(
    text: widget.edit?.contentWarning ?? '',
  );
  late final List<TextEditingController> _options = [
    for (final o
        in (widget.edit?.pollOptions.isNotEmpty ?? false)
            ? widget.edit!.pollOptions
            : ['', ''])
      TextEditingController(text: o),
  ];
  late List<String> _images = [...?widget.edit?.images];
  late String? _video = widget.edit?.video;
  late String? _author = widget.edit?.author ?? ref.read(socialActorProvider);
  late Audience _audience = widget.edit?.audience ?? Audience.everyone;
  late List<String> _audienceIds = [...?widget.edit?.audienceIds];
  late bool _pollMulti = widget.edit?.pollMulti ?? false;
  late String? _askedTo = widget.edit?.askedTo;
  late bool _useCw = widget.edit?.contentWarning != null;
  DateTime? _schedule;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null && e.status == PostStatus.scheduled)
      _schedule = e.publishedAt;
  }

  @override
  void dispose() {
    for (final c in [_title, _body, _tags, _cw, ..._options]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _valid {
    if (_author == null) return false;
    return switch (_type) {
      PostType.text || PostType.question =>
        _body.text.trim().isNotEmpty || _title.text.trim().isNotEmpty,
      PostType.image => _images.isNotEmpty,
      PostType.media => _video != null || _images.isNotEmpty,
      PostType.poll =>
        _options.where((o) => o.text.trim().isNotEmpty).length >= 2,
    };
  }

  Future<void> _addImages() async {
    final l10n = context.l10n;
    final files = await ImagePicker().pickMultiImage(limit: 10);
    for (final f in files) {
      if (!mounted) return;
      final cropped = await PrismImageCrop.fromBytes(
        context,
        await f.readAsBytes(),
      );
      if (cropped == null) continue;
      final id = await ref
          .read(socialMediaStoreProvider)
          .addImage(
            cropped.bytes,
            owner: _author,
            original: cropped.originalId,
          );
      if (!mounted) return;
      if (id == null) {
        PrismToast.error(context, message: l10n.socImageUnreadable(f.name));
      } else {
        setState(() => _images = [..._images, id]);
      }
    }
  }

  Future<void> _addVideo() async {
    final l10n = context.l10n;
    final r = await FilePicker.pickFiles(type: FileType.video);
    final path = r?.files.firstOrNull?.path;
    if (path == null || !mounted) return;
    final res = await ref.read(socialMediaStoreProvider).addVideo(path);
    if (!mounted) return;
    if (res.id != null) {
      setState(() => _video = res.id);
    } else {
      PrismToast.error(
        context,
        message: switch (res.error) {
          'tooLarge' => l10n.socVideoTooLarge,
          'format' => l10n.socVideoFormat,
          _ => l10n.socVideoFailed,
        },
      );
    }
  }

  Future<void> _submit(PostStatus status) async {
    if (!_valid || _busy) return;
    setState(() => _busy = true);
    final a = ref.read(socialActionsProvider);
    final tags = _tags.text
        .split(RegExp(r'[\s,]+'))
        .map(normalizeTag)
        .where((t) => t.isNotEmpty)
        .toList();
    final options = [
      for (final o in _options)
        if (o.text.trim().isNotEmpty) o.text.trim(),
    ];
    final finalStatus =
        status == PostStatus.published &&
            _schedule != null &&
            _schedule!.isAfter(DateTime.now())
        ? PostStatus.scheduled
        : status;
    try {
      final e = widget.edit;
      if (e != null) {
        await a.updatePost(
          e,
          title: _title.text.trim(),
          body: _body.text.trim(),
          tags: tags,
          images: _images,
          cw: _useCw ? _cw.text : '',
          audience: _audience,
          audienceIds: _audienceIds,
          status: finalStatus,
          scheduledFor: _schedule,
        );
      } else {
        await a.createPost(
          actor: _author!,
          type: widget.quote != null && _type == PostType.question
              ? PostType.text
              : _type,
          title: _title.text.trim(),
          body: _body.text.trim(),
          tags: tags,
          images: _images,
          video: _video,
          pollOptions: _type == PostType.poll ? options : const [],
          pollMulti: _pollMulti,
          askedTo: _type == PostType.question ? _askedTo : null,
          cw: _useCw ? _cw.text : null,
          audience: _audience,
          audienceIds: _audienceIds,
          status: finalStatus,
          scheduledFor: _schedule,
          quoteOf: widget.quote?.id,
        );
      }
      if (!mounted) return;
      final l10n = context.l10n;
      PrismToast.success(
        context,
        message: switch (finalStatus) {
          PostStatus.draft => l10n.socDraftSaved,
          PostStatus.scheduled => l10n.socScheduledFor(
            MaterialLocalizations.of(context).formatMediumDate(_schedule!),
          ),
          PostStatus.published => e == null ? l10n.socPosted : l10n.socSaved,
        },
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final date = await showPrismDatePicker(
      context: context,
      initialDate: _schedule ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (date == null || !mounted) return;
    final time = await showPrismTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _schedule ?? now.add(const Duration(hours: 1)),
      ),
    );
    if (time == null) return;
    setState(
      () => _schedule = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final d = ref.watch(socialDataProvider);
    final members =
        (ref.watch(userVisibleMemberListProvider).value ?? const <Member>[])
            .where((m) => m.isActive)
            .toList();
    final editing = widget.edit != null;
    final isDraft = editing && widget.edit!.status != PostStatus.published;
    return SafeArea(
      child: Column(
        children: [
          PrismSheetTopBar(
            title: editing
                ? l10n.socEditPost
                : (widget.isAnswer
                      ? l10n.socAnswerTitle
                      : (widget.quote != null
                            ? l10n.socQuote
                            : l10n.socNewPost)),
            trailing: PrismButton(
              label: _schedule != null
                  ? l10n.socSchedule
                  : (editing && !isDraft ? l10n.save : l10n.socPost),
              tone: PrismButtonTone.filled,
              density: PrismControlDensity.compact,
              enabled: _valid && !_busy,
              onPressed: () => _submit(PostStatus.published),
            ),
          ),
          Expanded(
            child: ListView(
              controller: widget.scroll,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                // Author: always an explicit alter, whoever is fronting.
                Row(
                  children: [
                    AlterAvatar(memberId: _author, size: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _author == null
                            ? l10n.socPickAlter
                            : l10n.socPostingAs(alterName(d, _author, context)),
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    if (!editing)
                      PrismButton(
                        label: l10n.socChange,
                        density: PrismControlDensity.compact,
                        onPressed: () async {
                          final id = await pickAlter(
                            context,
                            ref,
                            title: l10n.socWhoIsPosting,
                          );
                          if (id != null) setState(() => _author = id);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!editing && widget.quote == null)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final t in PostType.values)
                        PrismChip(
                          label: switch (t) {
                            PostType.text => l10n.socTypeText,
                            PostType.image => l10n.socTypeImage,
                            PostType.poll => l10n.socTypePoll,
                            PostType.question => l10n.socTypeQuestion,
                            PostType.media => l10n.socTypeMedia,
                          },
                          selected: _type == t,
                          onTap: () => setState(() => _type = t),
                        ),
                    ],
                  ),
                if (widget.quote != null)
                  Container(
                    margin: const EdgeInsets.only(top: 4, bottom: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: prismCorners(context, 12),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      children: [
                        AlterAvatar(memberId: widget.quote!.author, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.quote!.body.isEmpty
                                ? widget.quote!.title
                                : widget.quote!.body,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                if (_type == PostType.question && widget.quote == null) ...[
                  Text(l10n.socAskWho, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      PrismChip(
                        label: l10n.socAnyone,
                        selected: _askedTo == null,
                        onTap: () => setState(() => _askedTo = null),
                      ),
                      for (final m in members)
                        if (m.id != _author)
                          PrismChip(
                            label: m.name,
                            selected: _askedTo == m.id,
                            onTap: () => setState(() => _askedTo = m.id),
                          ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                if (_type != PostType.question || widget.quote != null)
                  PrismTextField(
                    controller: _title,
                    labelText: l10n.socTitleOptional,
                    onChanged: (_) => setState(() {}),
                  ),
                const SizedBox(height: 8),
                PrismTextField(
                  controller: _body,
                  labelText: switch (_type) {
                    PostType.question when widget.quote == null =>
                      l10n.socYourQuestion,
                    PostType.image || PostType.media => l10n.socCaption,
                    _ =>
                      widget.isAnswer
                          ? l10n.socYourAnswer
                          : l10n.socWhatsOnYourMind,
                  },
                  helperText: l10n.socBodyHelp,
                  minLines: 4,
                  maxLines: 14,
                  onChanged: (_) => setState(() {}),
                ),
                if (_type == PostType.poll) ...[
                  const SizedBox(height: 12),
                  Text(l10n.socPollOptions, style: theme.textTheme.labelLarge),
                  for (var i = 0; i < _options.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: PrismTextField(
                              controller: _options[i],
                              labelText: l10n.socOptionN(i + 1),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          if (_options.length > 2)
                            Semantics(
                              button: true,
                              label: l10n.socRemoveOption,
                              excludeSemantics: true,
                              child: InkResponse(
                                onTap: () => setState(
                                  () => _options.removeAt(i).dispose(),
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Icon(
                                    Icons.remove_circle_outline_rounded,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (_options.length < 8)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: PrismButton(
                          label: l10n.socAddOption,
                          density: PrismControlDensity.compact,
                          onPressed: () => setState(
                            () => _options.add(TextEditingController()),
                          ),
                        ),
                      ),
                    ),
                  PrismSwitchRow(
                    title: l10n.socPollMultiAllow,
                    value: _pollMulti,
                    onChanged: (v) => setState(() => _pollMulti = v),
                  ),
                ],
                if (_type == PostType.image ||
                    _type == PostType.media ||
                    _type == PostType.text) ...[
                  const SizedBox(height: 12),
                  if (_images.isNotEmpty)
                    SizedBox(
                      height: 96,
                      child: ReorderableListView(
                        scrollDirection: Axis.horizontal,
                        buildDefaultDragHandles: true,
                        onReorderItem: (from, to) => setState(() {
                          final x = _images.removeAt(from);
                          _images.insert(to.clamp(0, _images.length), x);
                        }),
                        children: [
                          for (final id in _images)
                            Padding(
                              key: ValueKey(id),
                              padding: const EdgeInsets.only(right: 6),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: prismCorners(context, 10),
                                    child: SocialImage(
                                      id: id,
                                      width: 96,
                                      height: 96,
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Semantics(
                                      button: true,
                                      label: l10n.socRemoveImage,
                                      excludeSemantics: true,
                                      child: InkResponse(
                                        onTap: () => setState(
                                          () =>
                                              _images = [..._images]
                                                ..remove(id),
                                        ),
                                        child: const PrismCircleAvatar(
                                          radius: 12,
                                          backgroundColor: Colors.black54,
                                          child: Icon(
                                            Icons.close,
                                            size: 14,
                                            color: Colors.white,
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
                  if (_video != null) ...[
                    const SizedBox(height: 8),
                    VideoTile(id: _video!),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: PrismButton(
                        label: l10n.socRemoveVideo,
                        density: PrismControlDensity.compact,
                        tone: PrismButtonTone.destructive,
                        onPressed: () => setState(() => _video = null),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (!editing || _type != PostType.media)
                        PrismButton(
                          label: l10n.socAddImages,
                          icon: Icons.add_photo_alternate_outlined,
                          onPressed: _addImages,
                        ),
                      if (_type == PostType.media && _video == null && !editing)
                        PrismButton(
                          label: l10n.socAddVideo,
                          icon: Icons.video_library_outlined,
                          onPressed: _addVideo,
                        ),
                    ],
                  ),
                  if (_type == PostType.media)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        l10n.socVideoNote,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 12),
                PrismTextField(
                  controller: _tags,
                  labelText: l10n.socTags,
                  helperText: l10n.socTagsHelp,
                ),
                PrismSwitchRow(
                  title: l10n.socContentWarning,
                  value: _useCw,
                  onChanged: (v) => setState(() => _useCw = v),
                ),
                if (_useCw)
                  PrismTextField(controller: _cw, labelText: l10n.socCwText),
                const SizedBox(height: 12),
                Text(l10n.socWhoCanSee, style: theme.textTheme.labelLarge),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final a in Audience.values)
                      PrismChip(
                        label: audienceLabel(context, a),
                        selected: _audience == a,
                        onTap: () => setState(() => _audience = a),
                      ),
                  ],
                ),
                if (_audience == Audience.selected) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final m in members)
                        if (m.id != _author)
                          PrismChip(
                            label: m.name,
                            selected: _audienceIds.contains(m.id),
                            onTap: () => setState(
                              () => _audienceIds = _audienceIds.contains(m.id)
                                  ? ([..._audienceIds]..remove(m.id))
                                  : [..._audienceIds, m.id],
                            ),
                          ),
                    ],
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  l10n.socAudienceNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    PrismButton(
                      label: _schedule == null
                          ? l10n.socScheduleLater
                          : l10n.socScheduledFor(
                              MaterialLocalizations.of(
                                context,
                              ).formatMediumDate(_schedule!),
                            ),
                      icon: Icons.schedule_rounded,
                      onPressed: _pickSchedule,
                    ),
                    if (_schedule != null)
                      PrismButton(
                        label: l10n.socPostNow,
                        density: PrismControlDensity.compact,
                        onPressed: () => setState(() => _schedule = null),
                      ),
                    if (!editing || isDraft)
                      PrismButton(
                        label: l10n.socSaveDraft,
                        icon: Icons.drafts_outlined,
                        enabled: _valid && !_busy,
                        onPressed: () => _submit(PostStatus.draft),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
