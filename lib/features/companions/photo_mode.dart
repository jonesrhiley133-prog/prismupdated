import 'package:intl/intl.dart' show DateFormat;

import 'package:prism_plurality/features/companions/companion_art.dart';
import 'package:prism_plurality/features/companions/companion_data.dart';
import 'package:prism_plurality/features/companions/companion_species.dart'
    show traitLabel;
import 'package:prism_plurality/features/companions/companion_widgets.dart';
import 'package:prism_plurality/features/experiences/color_sheet.dart';
import 'package:prism_plurality/features/experiences/export_kit.dart';
import 'package:prism_plurality/features/links/models/record_ref.dart';
import 'package:prism_plurality/features/links/providers/link_providers.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

const photoStickers = [
  '⭐',
  '💖',
  '🌸',
  '✨',
  '🎀',
  '🌙',
  '☀️',
  '🌈',
  '🍰',
  '🎈',
  '🍂',
  '❄️',
  '🎵',
  '💐',
  '🫧',
  '🦋',
  '🍀',
  '👑',
  '💌',
  '🔥',
];

CompanionPose _pose(String p) =>
    CompanionPose.values.where((x) => x.name == p).firstOrNull ??
    CompanionPose.sit;

/// Draws a saved photo scene. Companions that were removed simply aren't
/// drawn; the rest of the photo stays intact.
class PhotoSceneView extends ConsumerWidget {
  const PhotoSceneView({
    super.key,
    required this.scene,
    this.animate = true,
    this.selected,
    this.onSubjectDrag,
    this.onStickerDrag,
    this.onTapSubject,
    this.onTapSticker,
  });
  final PhotoScene scene;
  final bool animate;
  final int? selected;
  final void Function(int index, Offset delta, Size box)? onSubjectDrag;
  final void Function(int index, Offset delta, Size box)? onStickerDrag;
  final void Function(int index)? onTapSubject;
  final void Function(int index)? onTapSticker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, box) {
          final size = Size(box.maxWidth, box.maxHeight);
          final unit = box.maxWidth;
          return _Framed(
            frame: scene.frame,
            child: HabitatScene(
              env: scene.background,
              time: scene.time,
              animate: animate,
              borderRadius: scene.frame == 'round' ? unit : 0,
              children: [
                for (final (i, s) in scene.subjects.indexed)
                  if (ref.watch(companionByIdProvider(s.companionId))
                      case final c?)
                    Positioned(
                      left: s.x * unit - unit * 0.22 * s.scale,
                      top: s.y * unit - unit * 0.22 * s.scale,
                      child: GestureDetector(
                        onTap: onTapSubject == null
                            ? null
                            : () => onTapSubject!(i),
                        onPanUpdate: onSubjectDrag == null
                            ? null
                            : (d) => onSubjectDrag!(i, d.delta, size),
                        child: Container(
                          decoration: selected == i
                              ? BoxDecoration(
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  borderRadius: prismCorners(context, 12),
                                )
                              : null,
                          child: CompanionFigure(
                            companion: c,
                            size: unit * 0.44 * s.scale,
                            pose: _pose(s.pose),
                            expression: s.expression,
                            look: s.look == null
                                ? null
                                : CompanionLook.fromJson(s.look),
                            animate: animate,
                          ),
                        ),
                      ),
                    ),
                for (final (i, st) in scene.stickers.indexed)
                  Positioned(
                    left: st.x * unit - 16 * st.scale,
                    top: st.y * unit - 16 * st.scale,
                    child: GestureDetector(
                      onTap: onTapSticker == null
                          ? null
                          : () => onTapSticker!(i),
                      onPanUpdate: onStickerDrag == null
                          ? null
                          : (d) => onStickerDrag!(i, d.delta, size),
                      child: Text(
                        st.emoji,
                        style: TextStyle(fontSize: unit * 0.09 * st.scale),
                      ),
                    ),
                  ),
                if (scene.text.isNotEmpty)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: scene.frame == 'polaroid' ? 4 : 14,
                    child: Text(
                      scene.text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(scene.textColor),
                        fontSize: unit * 0.06,
                        fontWeight: FontWeight.w800,
                        shadows: const [
                          Shadow(blurRadius: 6, color: Color(0x88000000)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Framed extends StatelessWidget {
  const _Framed({required this.frame, required this.child});
  final String frame;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    switch (frame) {
      case 'polaroid':
        return Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 34),
          child: child,
        );
      case 'gold':
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD4AF37), width: 8),
          ),
          child: child,
        );
      case 'stars' || 'flowers' || 'hearts':
        final e = frame == 'stars' ? '⭐' : (frame == 'flowers' ? '🌸' : '💖');
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            IgnorePointer(
              child: LayoutBuilder(
                builder: (context, box) => Stack(
                  children: [
                    for (var i = 0; i < 8; i++)
                      Positioned(
                        left: (i % 4) * box.maxWidth / 3.6,
                        top: i < 4 ? 2 : null,
                        bottom: i >= 4 ? 2 : null,
                        child: Text(
                          e,
                          style: TextStyle(fontSize: box.maxWidth * 0.06),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      default:
        return child;
    }
  }
}

/// Compose a companion photo.
class PhotoModeScreen extends ConsumerStatefulWidget {
  const PhotoModeScreen({super.key, required this.companionIds});
  final List<String> companionIds;
  @override
  ConsumerState<PhotoModeScreen> createState() => _PhotoModeScreenState();
}

class _PhotoModeScreenState extends ConsumerState<PhotoModeScreen> {
  late PhotoScene _scene;
  int? _subject = 0;
  int? _sticker;
  String _tab = 'Pose';
  final _caption = TextEditingController();
  final _text = TextEditingController();
  final _shot = GlobalKey();

  @override
  void initState() {
    super.initState();
    final cs = [
      for (final id in widget.companionIds)
        ?ref.read(companionByIdProvider(id)),
    ];
    final habitat = cs.isEmpty
        ? null
        : ref
              .read(habitatsProvider)
              .where((h) => h.id == cs.first.habitatId)
              .firstOrNull;
    _scene = PhotoScene(
      background: habitat?.env ?? 'clearing',
      subjects: [
        for (final (i, c) in cs.indexed)
          PhotoSubject(
            c.id,
            x: cs.length == 1
                ? 0.5
                : 0.28 + i * 0.44 / (cs.length - 1).clamp(1, 9),
            y: 0.6,
            look: c.look.toJson(),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _caption.dispose();
    _text.dispose();
    super.dispose();
  }

  void _setSubject(int i, PhotoSubject Function(PhotoSubject) f) => setState(
    () => _scene = _scene.copyWith(
      subjects: [
        for (final (k, s) in _scene.subjects.indexed) k == i ? f(s) : s,
      ],
    ),
  );
  void _setSticker(int i, PhotoSticker Function(PhotoSticker) f) => setState(
    () => _scene = _scene.copyWith(
      stickers: [
        for (final (k, s) in _scene.stickers.indexed) k == i ? f(s) : s,
      ],
    ),
  );

  Future<void> _save() async {
    final ids = [for (final s in _scene.subjects) s.companionId];
    final names = [
      for (final id in ids) ref.read(companionByIdProvider(id))?.name ?? '',
    ].where((n) => n.isNotEmpty);
    await ref
        .read(companionActionsProvider)
        .addMemory(
          companionIds: ids,
          kind: 'photo',
          title: _caption.text.trim().isEmpty
              ? 'Photo of ${names.join(' & ')}'
              : _caption.text.trim(),
          caption: _caption.text.trim(),
          scene: _scene,
          by: currentFronterId(ref),
        );
    if (!mounted) return;
    PrismToast.show(context, message: 'Saved to the album');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = [
      for (final c in ref.watch(companionsProvider))
        if (!c.isEgg) c,
    ];
    final sub = _subject == null || _subject! >= _scene.subjects.length
        ? null
        : _scene.subjects[_subject!];
    Widget chips<T>(
      List<T> values,
      T current,
      String Function(T) label,
      void Function(T) onTap,
    ) => Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final v in values)
          PrismChip(
            label: label(v),
            selected: v == current,
            onTap: () => onTap(v),
          ),
      ],
    );

    final controls = switch (_tab) {
      'Pose' => [
        if (_scene.subjects.length > 1) ...[
          chips<int>(
            [for (var i = 0; i < _scene.subjects.length; i++) i],
            _subject ?? -1,
            (i) =>
                ref
                    .read(companionByIdProvider(_scene.subjects[i].companionId))
                    ?.name ??
                '?',
            (i) => setState(() => _subject = i),
          ),
          const SizedBox(height: 10),
        ],
        if (sub != null) ...[
          Text('Pose', style: theme.textTheme.labelLarge),
          chips<String>(
            CompanionPose.values.map((p) => p.name).toList(),
            sub.pose,
            traitLabel,
            (p) => _setSubject(_subject!, (s) => s.copyWith(pose: p)),
          ),
          const SizedBox(height: 10),
          Text('Expression', style: theme.textTheme.labelLarge),
          chips<String>(
            CompanionLook.expressions,
            sub.expression,
            traitLabel,
            (e) => _setSubject(_subject!, (s) => s.copyWith(expression: e)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Size', style: theme.textTheme.labelLarge),
              Expanded(
                child: Slider(
                  value: sub.scale,
                  min: 0.5,
                  max: 1.6,
                  label: 'Size',
                  onChanged: (v) =>
                      _setSubject(_subject!, (s) => s.copyWith(scale: v)),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 4,
            children: [
              for (final (icon, tip, dx, dy) in [
                (Icons.arrow_back, 'Move left', -0.05, 0.0),
                (Icons.arrow_upward, 'Move up', 0.0, -0.05),
                (Icons.arrow_downward, 'Move down', 0.0, 0.05),
                (Icons.arrow_forward, 'Move right', 0.05, 0.0),
              ])
                IconButton(
                  tooltip: tip,
                  icon: Icon(icon),
                  onPressed: () => _setSubject(
                    _subject!,
                    (s) => s.copyWith(
                      x: (s.x + dx).clamp(0, 1),
                      y: (s.y + dy).clamp(0, 1),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
      'Friends' => [
        Text('Who\'s in the photo?', style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in all)
              PrismChip(
                label: c.name,
                selected: _scene.subjects.any((s) => s.companionId == c.id),
                onTap: () => setState(() {
                  final has = _scene.subjects.any((s) => s.companionId == c.id);
                  if (has && _scene.subjects.length > 1) {
                    _scene = _scene.copyWith(
                      subjects: [
                        for (final s in _scene.subjects)
                          if (s.companionId != c.id) s,
                      ],
                    );
                  } else if (!has) {
                    _scene = _scene.copyWith(
                      subjects: [
                        ..._scene.subjects,
                        PhotoSubject(
                          c.id,
                          x: 0.2 + (_scene.subjects.length * 0.2) % 0.7,
                          y: 0.62,
                          look: c.look.toJson(),
                        ),
                      ],
                    );
                  }
                  _subject = 0;
                }),
              ),
          ],
        ),
      ],
      'Scene' => [
        Text('Background', style: theme.textTheme.labelLarge),
        chips<String>(
          [for (final e in habitatEnvs) e.id],
          _scene.background,
          (id) => '${habitatEnvById(id).emoji} ${habitatEnvById(id).name}',
          (id) => setState(() => _scene = _scene.copyWith(background: id)),
        ),
        const SizedBox(height: 10),
        Text('Time', style: theme.textTheme.labelLarge),
        chips<String>(
          const ['auto', 'morning', 'day', 'evening', 'night'],
          _scene.time,
          traitLabel,
          (t) => setState(() => _scene = _scene.copyWith(time: t)),
        ),
        const SizedBox(height: 10),
        Text('Frame', style: theme.textTheme.labelLarge),
        chips<String>(
          CompanionLook.frames,
          _scene.frame,
          traitLabel,
          (f) => setState(() => _scene = _scene.copyWith(frame: f)),
        ),
      ],
      'Stickers' => [
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final e in photoStickers)
              Semantics(
                button: true,
                label: 'Add $e sticker',
                child: InkWell(
                  onTap: () => setState(() {
                    _scene = _scene.copyWith(
                      stickers: [
                        ..._scene.stickers,
                        PhotoSticker(
                          e,
                          x: 0.15 + (_scene.stickers.length * 0.13) % 0.7,
                          y: 0.15,
                        ),
                      ],
                    );
                    _sticker = _scene.stickers.length - 1;
                  }),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: Text(e, style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (_sticker != null && _sticker! < _scene.stickers.length)
          Wrap(
            spacing: 4,
            children: [
              for (final (icon, tip, dx, dy) in [
                (Icons.arrow_back, 'Move left', -0.05, 0.0),
                (Icons.arrow_upward, 'Move up', 0.0, -0.05),
                (Icons.arrow_downward, 'Move down', 0.0, 0.05),
                (Icons.arrow_forward, 'Move right', 0.05, 0.0),
              ])
                IconButton(
                  tooltip: tip,
                  icon: Icon(icon),
                  onPressed: () => _setSticker(
                    _sticker!,
                    (s) => s.copyWith(
                      x: (s.x + dx).clamp(0, 1),
                      y: (s.y + dy).clamp(0, 1),
                    ),
                  ),
                ),
              IconButton(
                tooltip: 'Bigger',
                icon: const Icon(Icons.add),
                onPressed: () => _setSticker(
                  _sticker!,
                  (s) => s.copyWith(scale: (s.scale + 0.2).clamp(0.5, 3)),
                ),
              ),
              IconButton(
                tooltip: 'Smaller',
                icon: const Icon(Icons.remove),
                onPressed: () => _setSticker(
                  _sticker!,
                  (s) => s.copyWith(scale: (s.scale - 0.2).clamp(0.5, 3)),
                ),
              ),
              IconButton(
                tooltip: 'Remove sticker',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => setState(() {
                  _scene = _scene.copyWith(
                    stickers: [
                      for (final (k, s) in _scene.stickers.indexed)
                        if (k != _sticker) s,
                    ],
                  );
                  _sticker = null;
                }),
              ),
            ],
          ),
      ],
      _ => [
        PrismTextField(
          controller: _text,
          labelText: 'Text on the photo',
          onChanged: (v) => setState(() => _scene = _scene.copyWith(text: v)),
        ),
        const SizedBox(height: 8),
        PrismButton(
          label: 'Text colour',
          icon: Icons.palette_outlined,
          onPressed: () async {
            final c = await showPrismColorPicker(
              context: context,
              initial: Color(_scene.textColor),
            );
            if (c != null)
              setState(() => _scene = _scene.copyWith(textColor: c.toARGB32()));
          },
        ),
        const SizedBox(height: 12),
        PrismTextField(
          controller: _caption,
          labelText: 'Caption (saved with the photo)',
        ),
      ],
    };

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: 'Photo',
        showBackButton: true,
        actions: [
          PrismTopBarAction(
            icon: Icons.ios_share,
            tooltip: 'Export image',
            onPressed: () async {
              final bytes = await captureBoundary(_shot);
              if (bytes == null || !context.mounted) return;
              final ok = await saveImageBytes(
                ref,
                bytes,
                'prism-companion-${DateTime.now().millisecondsSinceEpoch}',
              );
              if (context.mounted)
                PrismToast.show(
                  context,
                  message: ok ? 'Image saved' : 'Not saved',
                );
            },
          ),
        ],
      ),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.42,
                ),
                child: RepaintBoundary(
                  key: _shot,
                  child: PhotoSceneView(
                    scene: _scene,
                    selected: _tab == 'Pose' ? _subject : null,
                    onTapSubject: (i) => setState(() {
                      _subject = i;
                      _tab = 'Pose';
                    }),
                    onTapSticker: (i) => setState(() {
                      _sticker = i;
                      _tab = 'Stickers';
                    }),
                    onSubjectDrag: (i, d, box) => _setSubject(
                      i,
                      (s) => s.copyWith(
                        x: (s.x + d.dx / box.width).clamp(0, 1),
                        y: (s.y + d.dy / box.height).clamp(0, 1),
                      ),
                    ),
                    onStickerDrag: (i, d, box) => _setSticker(
                      i,
                      (s) => s.copyWith(
                        x: (s.x + d.dx / box.width).clamp(0, 1),
                        y: (s.y + d.dy / box.height).clamp(0, 1),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final t in const [
                    'Pose',
                    'Friends',
                    'Scene',
                    'Stickers',
                    'Text',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: PrismChip(
                        label: t,
                        selected: _tab == t,
                        onTap: () => setState(() => _tab = t),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                children: controls,
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: PrismButton(
                  label: 'Save to album',
                  icon: Icons.photo_library_outlined,
                  tone: PrismButtonTone.filled,
                  expanded: true,
                  onPressed: _save,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One saved photo: export, share to the Bulletin Board, attach to the
/// journal, or delete.
class PhotoViewerScreen extends ConsumerWidget {
  const PhotoViewerScreen({super.key, required this.memoryId});
  final String memoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref
        .watch(companionMemoriesProvider)
        .where((x) => x.id == memoryId)
        .firstOrNull;
    final shot = GlobalKey();
    if (m == null || m.scene == null)
      return const PrismPageScaffold(
        topBar: PrismTopBar(title: 'Photo', showBackButton: true),
        body: EmptyState(
          icon: Icon(Icons.photo_outlined),
          title: 'Photo not found',
          subtitle: 'It may have been deleted.',
        ),
      );
    final theme = Theme.of(context);
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: m.title.isEmpty ? 'Photo' : m.title,
        showBackButton: true,
      ),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + NavBarInset.of(context)),
          children: [
            RepaintBoundary(
              key: shot,
              child: PhotoSceneView(scene: m.scene!),
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat.yMMMMd().add_jm().format(m.at),
              style: theme.textTheme.bodySmall,
            ),
            if (m.caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(m.caption),
              ),
            const SizedBox(height: 16),
            PrismButton(
              label: 'Save as image',
              icon: Icons.download_outlined,
              expanded: true,
              onPressed: () async {
                final bytes = await captureBoundary(shot);
                if (bytes == null) return;
                final ok = await saveImageBytes(
                  ref,
                  bytes,
                  'prism-photo-${m.at.millisecondsSinceEpoch}',
                );
                if (context.mounted)
                  PrismToast.show(
                    context,
                    message: ok ? 'Image saved' : 'Not saved',
                  );
              },
            ),
            const SizedBox(height: 8),
            PrismButton(
              label: 'Share to the Bulletin Board',
              icon: Icons.dynamic_feed_outlined,
              expanded: true,
              onPressed: () async {
                final actor = currentFronterId(ref);
                if (actor == null) {
                  PrismToast.show(
                    context,
                    message:
                        'Set who\'s fronting first — posts are made as a headmate.',
                  );
                  return;
                }
                final ok = await PrismDialog.confirm(
                  context: context,
                  title: 'Post this photo?',
                  message: 'It will appear on your internal Bulletin Board.',
                  confirmLabel: 'Post',
                );
                if (!ok) return;
                final bytes = await captureBoundary(shot);
                if (bytes == null) return;
                await shareImageToBoard(
                  ref,
                  bytes,
                  actor: actor,
                  title: m.title,
                  body: m.caption,
                  tags: const ['companions'],
                );
                if (context.mounted)
                  PrismToast.show(context, message: 'Posted');
              },
            ),
            const SizedBox(height: 8),
            PrismButton(
              label: 'Attach to a journal entry',
              icon: Icons.menu_book_outlined,
              expanded: true,
              onPressed: () =>
                  attachToJournal(context, ref, recordId: m.id, title: m.title),
            ),
            const SizedBox(height: 8),
            PrismButton(
              label: 'Delete photo',
              icon: Icons.delete_outline,
              tone: PrismButtonTone.destructive,
              expanded: true,
              onPressed: () async {
                final ok = await PrismDialog.confirm(
                  context: context,
                  title: 'Delete this photo?',
                  confirmLabel: 'Delete',
                  destructive: true,
                );
                if (!ok) return;
                await ref.read(companionActionsProvider).deleteMemory(m.id);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Links [recordId] to an existing or new journal entry (a link, not a copy).
Future<void> attachToJournal(
  BuildContext context,
  WidgetRef ref, {
  required String recordId,
  required String title,
}) async {
  final entries =
      [
        ...(ref.read(trackerKindProvider(TrackerKind.journalEntry)).value ??
            const <TrackerRecord>[]),
      ]..sort(
        (a, b) => (b.occurredAt ?? b.createdAt).compareTo(
          a.occurredAt ?? a.createdAt,
        ),
      );
  final pick = await PrismSheet.show<String>(
    context: context,
    title: 'Attach to…',
    builder: (ctx) => ListView(
      shrinkWrap: true,
      children: [
        PrismListRow(
          leading: const Icon(Icons.add),
          title: const Text('A new journal entry'),
          onTap: () => Navigator.of(ctx).pop('__new'),
        ),
        for (final e in entries.take(30))
          PrismListRow(
            title: Text(e.title.isEmpty ? 'Untitled entry' : e.title),
            subtitle: Text(
              DateFormat.yMMMd().format(e.occurredAt ?? e.createdAt),
            ),
            onTap: () => Navigator.of(ctx).pop(e.id),
          ),
      ],
    ),
  );
  if (pick == null) return;
  var journalId = pick;
  if (pick == '__new') {
    final rec = await ref
        .read(trackerNotifierProvider.notifier)
        .create(
          kind: TrackerKind.journalEntry,
          title: title,
          occurredAt: DateTime.now(),
          memberId: currentFronterId(ref),
        );
    journalId = rec.id;
  }
  await ref
      .read(linkActionsProvider)
      .link(
        RecordRef(RecordRef.rec, recordId),
        RecordRef(RecordRef.rec, journalId),
        note: 'Companion photo',
      );
  if (context.mounted)
    PrismToast.show(
      context,
      message: 'Attached — it shows under the entry\'s related records',
    );
}
