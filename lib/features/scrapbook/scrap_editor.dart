import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/links/widgets/related_records.dart'
    show promptText;
import 'package:prism_plurality/features/scrapbook/scrap_draw.dart';
import 'package:prism_plurality/features/scrapbook/scrap_edit_surface.dart';
import 'package:prism_plurality/features/scrapbook/scrap_editor_core.dart';
import 'package:prism_plurality/features/scrapbook/scrap_models.dart';
import 'package:prism_plurality/features/scrapbook/scrap_page.dart';
import 'package:prism_plurality/features/scrapbook/scrap_panels.dart';
import 'package:prism_plurality/features/scrapbook/scrap_props.dart';
import 'package:prism_plurality/features/scrapbook/scrap_seasonal_ui.dart';
import 'package:prism_plurality/features/scrapbook/scrap_rentry.dart';
import 'package:prism_plurality/features/scrapbook/scrap_shapes.dart';
import 'package:prism_plurality/features/scrapbook/scrap_sticker_picker.dart';
import 'package:prism_plurality/features/scrapbook/scrap_texture_painter.dart';
import 'package:prism_plurality/features/scrapbook/scrap_textures.dart';
import 'package:prism_plurality/features/scrapbook/scrap_washi.dart';
import 'package:prism_plurality/features/social/services/social_media.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/features/trackers/widgets/member_picker.dart';
import 'package:prism_plurality/shared/fonts/prism_fonts.dart';
import 'package:prism_plurality/shared/media/prism_media.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';

const _handwritingFonts = <String, String>{
  'g:Caveat': 'Caveat',
  'g:Shadows Into Light': 'Shadows Into Light',
  'g:Dancing Script': 'Dancing Script',
  'g:Pacifico': 'Pacifico',
  'g:Satisfy': 'Satisfy',
  'g:Great Vibes': 'Great Vibes',
  'g:Permanent Marker': 'Permanent Marker',
  'g:Indie Flower': 'Indie Flower',
  'g:Kalam': 'Kalam',
  'g:Reenie Beanie': 'Reenie Beanie',
};

/// The page editor: everything on a page can be placed, resized, rotated,
/// layered, grouped and locked; the page itself has a background, texture,
/// size, spread and transition. Changes autosave as you go.
class ScrapPageEditor extends ConsumerStatefulWidget {
  const ScrapPageEditor({super.key, required this.book, required this.page});
  final TrackerRecord book, page;

  @override
  ConsumerState<ScrapPageEditor> createState() => _ScrapPageEditorState();
}

enum _PageTab { background, texture, size, transition, templates }

class _ScrapPageEditorState extends ConsumerState<ScrapPageEditor> {
  late final ScrapEditorController _c;
  late final TrackerNotifier _tracker;
  Timer? _autosave;
  bool _saved = true;

  @override
  void initState() {
    super.initState();
    _tracker = ref.read(trackerNotifierProvider.notifier);
    _c = ScrapEditorController(
      elements: elementsOf(widget.page),
      meta: {'s': ScrapPageStyle.of(widget.book, widget.page).toJson()},
    );
    _c.addListener(_changed);
  }

  @override
  void dispose() {
    _autosave?.cancel();
    _c.removeListener(_changed);
    if (!_saved) unawaited(_persist());
    _c.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
    if (!_c.changed) return;
    _saved = false;
    _autosave?.cancel();
    _autosave = Timer(
      const Duration(milliseconds: 900),
      () => unawaited(_persist()),
    );
  }

  Future<void> _persist() async {
    try {
      await _tracker.save(
        widget.page.withFields({
          ..._style.toFields(),
          'els': [
            for (final e in ([..._c.els]..sort((a, b) => a.z.compareTo(b.z))))
              e.toJson(),
          ],
        }),
      );
      _saved = true;
      _c.markSaved();
      if (mounted) setState(() {});
    } catch (_) {
      // The next change retries.
    }
  }

  // ── Page style ─────────────────────────────────────────────────────────
  ScrapPageStyle get _style =>
      ScrapPageStyle.fromJson(Map<String, Object?>.from(_c.meta['s'] as Map));

  void _setStyle(void Function(ScrapPageStyle s) f, {bool live = false}) {
    final s = _style;
    f(s);
    _c.meta['s'] = s.toJson();
    live ? _c.refresh() : _c.commit();
  }

  // ── Adding ─────────────────────────────────────────────────────────────
  void _add(ScrapElement e) {
    e.by = currentFronterId(ref);
    _c.add(e);
  }

  Future<void> _addPhoto({String? frame}) async {
    final id = await PrismMedia.pickImage(ref, owner: currentFronterId(ref));
    if (id == null) return;
    // An empty photo box from a template gets the first picture.
    final empty = _c.els
        .where((e) => e.type == ScrapType.photo && e.media == null)
        .firstOrNull;
    if (empty != null && frame == null) {
      empty.media = id;
      _c.select(empty.id);
      _c.commit();
      return;
    }
    _add(
      ScrapElement(
        type: ScrapType.photo,
        media: id,
        x: 0.2,
        y: 0.25,
        w: 0.6,
        h: 0.4,
        opts: {'fr2': frame ?? 'polaroid'},
      ),
    );
  }

  Future<void> _addVideo() async {
    final res = await PrismMedia.pickVideoResult(ref);
    if (res.error != null && mounted) {
      PrismToast.error(
        context,
        message: switch (res.error) {
          'tooLarge' => tr(
            context,
            'That video is too large (200 MB max).',
            'Ese vídeo es demasiado grande (máx. 200 MB).',
          ),
          'format' => tr(
            context,
            'That video format isn\'t supported.',
            'Ese formato de vídeo no es compatible.',
          ),
          'unsupported' => tr(
            context,
            'Videos can\'t be stored on this device.',
            'No se pueden guardar vídeos en este dispositivo.',
          ),
          _ => tr(
            context,
            'Couldn\'t add that video.',
            'No se pudo añadir ese vídeo.',
          ),
        },
      );
    }
    if (res.id != null)
      _add(
        ScrapElement(
          type: ScrapType.video,
          media: res.id,
          x: 0.2,
          y: 0.25,
          w: 0.6,
          h: 0.4,
        ),
      );
  }

  Future<void> _addAudio() async {
    final id = await PrismMedia.recordAudio(context);
    if (id != null)
      _add(
        ScrapElement(
          type: ScrapType.audio,
          media: id,
          x: 0.2,
          y: 0.25,
          w: 0.5,
          h: 0.08,
        ),
      );
  }

  Future<void> _addSticker() async {
    final s = await showScrapStickerPicker(context);
    if (s != null)
      _add(
        ScrapElement(
          type: ScrapType.sticker,
          text: s.id,
          media: s.media,
          x: 0.4,
          y: 0.4,
          w: 0.2,
          h: 0.14,
        ),
      );
  }

  Future<void> _addShape() async {
    final id = await PrismSheet.show<String>(
      context: context,
      title: tr(context, 'Shapes', 'Formas'),
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          for (final g in scrapShapeGroups.entries) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(g.key, style: Theme.of(ctx).textTheme.labelLarge),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in g.value)
                  Semantics(
                    button: true,
                    label: scrapShapeName(s),
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, s),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: CustomPaint(
                          painter: ScrapShapePainter(
                            shape: s,
                            fill: Theme.of(ctx).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
    if (id != null)
      _add(
        ScrapElement(
          type: ScrapType.shape,
          text: id,
          color: 0xFFFF7A9C,
          x: 0.35,
          y: 0.35,
          w: 0.3,
          h: 0.2,
        ),
      );
  }

  Future<void> _addWashi() async {
    final id = await PrismSheet.show<String>(
      context: context,
      title: tr(context, 'Washi tape', 'Cinta washi'),
      builder: (ctx) => GridView.count(
        shrinkWrap: true,
        crossAxisCount: 2,
        childAspectRatio: 3.6,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          for (final w in washiPatterns)
            Semantics(
              button: true,
              label: w.name,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx, w.id),
                child: CustomPaint(painter: WashiPainter(w)),
              ),
            ),
        ],
      ),
    );
    if (id != null)
      _add(
        ScrapElement(
          type: ScrapType.tape,
          x: 0.28,
          y: 0.05,
          w: 0.44,
          h: 0.055,
          rot: -0.08,
          opts: {'wp': id},
        ),
      );
  }

  Future<void> _addHandwriting() async {
    final key = await PrismSheet.show<String>(
      context: context,
      title: tr(context, 'Decorative handwriting', 'Escritura decorativa'),
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          for (final f in _handwritingFonts.entries)
            PrismListRow(
              title: ValueListenableBuilder<int>(
                valueListenable: PrismFonts.loadTick,
                builder: (_, _, _) {
                  PrismFonts.ensureLoaded(f.key);
                  return Text(
                    tr(ctx, 'Hello, lovely day', 'Hola, qué día tan bonito'),
                    style: PrismFonts.style(
                      f.key,
                      const TextStyle(fontSize: 26),
                    ),
                  );
                },
              ),
              subtitle: Text(f.value),
              onTap: () => Navigator.pop(ctx, f.key),
            ),
        ],
      ),
    );
    if (key != null) {
      _add(
        ScrapElement(
          type: ScrapType.text,
          text: tr(context, 'Write something…', 'Escribe algo…'),
          font: key,
          size: 2,
          color: 0xFF2C3E50,
          x: 0.1,
          y: 0.4,
          w: 0.8,
          h: 0.2,
          opts: {'shrink': true},
        ),
      );
      final e = _c.single;
      if (e != null && mounted)
        unawaited(showScrapElementProps(context, _c, e));
    }
  }

  Future<void> _addRentry() async {
    final text = await showRentryEditor(context);
    if (text == null || text.trim().isEmpty) return;
    _add(
      ScrapElement(
        type: ScrapType.markdown,
        text: text,
        x: 0.08,
        y: 0.1,
        w: 0.84,
        h: 0.6,
      ),
    );
  }

  /// Double-tap: Rentry notes open their editor, everything else its settings.
  Future<void> _edit(ScrapElement e) async {
    if (e.type == ScrapType.markdown) {
      final text = await showRentryEditor(context, initial: e.text ?? '');
      if (text == null) return;
      e.text = text;
      _c.commit();
      return;
    }
    await showScrapElementProps(context, _c, e);
  }

  Future<void> _draw() async {
    final bytes = await ScrapDrawingPad.show(context);
    if (bytes == null) return;
    final id = await ref
        .read(socialMediaStoreProvider)
        .addImage(Uint8List.fromList(bytes), owner: currentFronterId(ref));
    if (id != null)
      _add(
        ScrapElement(
          type: ScrapType.drawing,
          media: id,
          x: 0.1,
          y: 0.2,
          w: 0.8,
          h: 0.55,
        ),
      );
  }

  Future<void> _addFramedPhoto() async {
    final id = await PrismSheet.show<String>(
      context: context,
      title: tr(context, 'Pick a frame', 'Elige un marco'),
      maxHeightFactor: 0.9,
      builder: (ctx) => ScrapFrameBrowser(
        current: '',
        onPick: (id) => Navigator.pop(ctx, id),
      ),
    );
    if (id != null) await _addPhoto(frame: id);
  }

  // ── UI ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final style = _style;
    return PopScope(
      onPopInvokedWithResult: (did, _) {
        if (did && !_saved) unawaited(_persist());
      },
      child: LookBackdrop(
        builder: (lookBg) => Scaffold(
          backgroundColor:
              lookBg ?? Theme.of(context).colorScheme.surfaceContainerLowest,
          body: SafeArea(
            child: Column(
              children: [
                PrismSheetTopBar(
                  title: tr(context, 'Edit page', 'Editar página'),
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: tr(context, 'Undo', 'Deshacer'),
                        icon: const Icon(Icons.undo),
                        onPressed: _c.canUndo ? _c.undo : null,
                      ),
                      IconButton(
                        tooltip: tr(context, 'Redo', 'Rehacer'),
                        icon: const Icon(Icons.redo),
                        onPressed: _c.canRedo ? _c.redo : null,
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: tr(
                          context,
                          'Page settings',
                          'Ajustes de página',
                        ),
                        icon: const Icon(Icons.auto_awesome_outlined),
                        onPressed: () => _pageSheet(),
                      ),
                      IconButton(
                        tooltip: tr(context, 'Done', 'Listo'),
                        icon: const Icon(Icons.check),
                        onPressed: () async {
                          await _persist();
                          if (mounted) Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(child: _canvas(style)),
                _controls(),
                if (_c.selected.isNotEmpty)
                  ScrapSelectionBar(controller: _c, extra: [_adjustButton()]),
                _addBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _adjustButton() {
    final e = _c.single;
    final framed =
        e != null && e.opt<String>('fr2', '').isNotEmpty && e.media != null;
    if (!framed) return const SizedBox.shrink();
    final on = _c.adjustId == e.id;
    return IconButton(
      tooltip: on
          ? tr(context, 'Done adjusting picture', 'Terminar ajuste')
          : tr(
              context,
              'Move the picture inside its frame',
              'Mover la imagen dentro del marco',
            ),
      icon: Icon(
        Icons.open_with,
        size: 20,
        color: on ? Theme.of(context).colorScheme.primary : null,
      ),
      onPressed: () => _c.setAdjust(on ? null : e.id),
    );
  }

  Widget _canvas(ScrapPageStyle style) {
    return LayoutBuilder(
      builder: (context, box) {
        final fitW = (box.maxWidth - 32).clamp(120.0, 1400.0);
        final fitH = (box.maxHeight - 32).clamp(120.0, 2400.0);
        final w =
            (fitW < fitH * style.drawnAspect
                ? fitW
                : fitH * style.drawnAspect) *
            _c.zoom;
        final page = SizedBox(
          width: w,
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ScrapPageBackdrop(
              style: style,
              child: ScrapEditSurface(
                controller: _c,
                widthDivisor: style.spread ? 2 : 1,
                onEdit: _edit,
              ),
            ),
          ),
        );
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: box.maxWidth,
                minHeight: box.maxHeight,
              ),
              child: Center(
                child: Padding(padding: const EdgeInsets.all(16), child: page),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _controls() {
    Widget toggle(IconData icon, String tip, bool on, VoidCallback f) =>
        IconButton(
          tooltip: tip,
          icon: Icon(
            icon,
            size: 20,
            color: on ? Theme.of(context).colorScheme.primary : null,
          ),
          onPressed: f,
        );
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          const SizedBox(width: 8),
          toggle(
            Icons.grid_goldenratio,
            tr(context, 'Snap to guides', 'Ajustar a guías'),
            _c.snapEnabled,
            () {
              _c.snapEnabled = !_c.snapEnabled;
              _c.refresh();
            },
          ),
          toggle(
            Icons.checklist,
            tr(context, 'Select several', 'Seleccionar varios'),
            _c.multi,
            () => _c.setMulti(!_c.multi),
          ),
          toggle(
            Icons.select_all,
            tr(context, 'Select all', 'Seleccionar todo'),
            false,
            _c.selectAll,
          ),
          toggle(
            Icons.layers_outlined,
            tr(context, 'Layers', 'Capas'),
            false,
            _layers,
          ),
          Icon(Icons.zoom_out, size: 18, color: Theme.of(context).hintColor),
          Expanded(
            child: Slider(
              value: _c.zoom,
              min: 0.5,
              max: 3,
              onChanged: _c.setZoom,
            ),
          ),
          Icon(Icons.zoom_in, size: 18, color: Theme.of(context).hintColor),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Future<void> _layers() => PrismSheet.show<void>(
    context: context,
    title: tr(context, 'Layers', 'Capas'),
    maxHeightFactor: 0.7,
    builder: (_) => SizedBox(
      height: 360,
      child: ListenableBuilder(
        listenable: _c,
        builder: (_, _) => ScrapLayersPanel(controller: _c),
      ),
    ),
  );

  Widget _addBar() {
    final tools = <(IconData, String, VoidCallback)>[
      (
        Icons.image_outlined,
        tr(context, 'Photo / GIF', 'Foto / GIF'),
        () => _addPhoto(),
      ),
      (
        Icons.crop_original,
        tr(context, 'Framed photo', 'Foto con marco'),
        _addFramedPhoto,
      ),
      (Icons.videocam_outlined, tr(context, 'Video', 'Vídeo'), _addVideo),
      (Icons.mic_none, tr(context, 'Audio', 'Audio'), _addAudio),
      (
        Icons.text_fields,
        tr(context, 'Text', 'Texto'),
        () => _add(
          ScrapElement(
            type: ScrapType.text,
            text: '',
            x: 0.1,
            y: 0.1,
            w: 0.8,
            h: 0.2,
            font: 'hand',
          ),
        ),
      ),
      (Icons.gesture, tr(context, 'Handwriting', 'Escritura'), _addHandwriting),
      (
        Icons.article_outlined,
        tr(context, 'Rentry note', 'Nota Rentry'),
        _addRentry,
      ),
      (
        Icons.sticky_note_2_outlined,
        tr(context, 'Note', 'Nota'),
        () => _add(
          ScrapElement(
            type: ScrapType.note,
            text: '',
            x: 0.25,
            y: 0.3,
            w: 0.5,
            h: 0.22,
            color: 0xFFFFF3A3,
            rot: 0.04,
          ),
        ),
      ),
      (
        Icons.emoji_emotions_outlined,
        tr(context, 'Sticker', 'Pegatina'),
        _addSticker,
      ),
      (Icons.brush_outlined, tr(context, 'Draw', 'Dibujar'), _draw),
      (
        Icons.horizontal_rule,
        tr(context, 'Washi tape', 'Cinta washi'),
        _addWashi,
      ),
      (Icons.category_outlined, tr(context, 'Shape', 'Forma'), _addShape),
      (
        Icons.dashboard_customize_outlined,
        tr(context, 'Templates', 'Plantillas'),
        () => _pageSheet(_PageTab.templates),
      ),
      (
        Icons.palette_outlined,
        tr(context, 'Page', 'Página'),
        () => _pageSheet(),
      ),
    ];
    return SizedBox(
      height: 72,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          for (final (icon, label, onTap) in tools)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: SizedBox(
                width: 72,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Page settings ──────────────────────────────────────────────────────
  Future<void> _pageSheet([_PageTab tab = _PageTab.background]) {
    var current = tab;
    return PrismSheet.show<void>(
      context: context,
      title: tr(context, 'Page', 'Página'),
      maxHeightFactor: 0.85,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          void both(void Function(ScrapPageStyle s) f, {bool live = false}) {
            _setStyle(f, live: live);
            set(() {});
          }

          final s = _style;
          String label(_PageTab t) => switch (t) {
            _PageTab.background => tr(ctx, 'Background', 'Fondo'),
            _PageTab.texture => tr(ctx, 'Texture', 'Textura'),
            _PageTab.size => tr(ctx, 'Size', 'Tamaño'),
            _PageTab.transition => tr(ctx, 'Transition', 'Transición'),
            _PageTab.templates => tr(ctx, 'Templates', 'Plantillas'),
          };
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final t in _PageTab.values)
                      Padding(
                        padding: const EdgeInsets.only(
                          right: 6,
                          top: 4,
                          bottom: 4,
                        ),
                        child: PrismChip(
                          label: label(t),
                          selected: current == t,
                          onTap: () => set(() => current = t),
                        ),
                      ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  scrollCacheExtent: const ScrollCacheExtent.pixels(3000),
                  children: switch (current) {
                    _PageTab.background => _backgroundTab(ctx, s, both),
                    _PageTab.texture => _textureTab(ctx, s, both),
                    _PageTab.size => _sizeTab(ctx, s, both),
                    _PageTab.transition => _transitionTab(ctx, s, both),
                    _PageTab.templates => _templatesTab(ctx, set),
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _backgroundTab(
    BuildContext ctx,
    ScrapPageStyle s,
    void Function(void Function(ScrapPageStyle) f, {bool live}) both,
  ) => [
    ScrapColorField(
      label: tr(ctx, 'Page colour', 'Color de la página'),
      value: s.color,
      onChanged: (v) => both((x) => x.color = v),
    ),
    ScrapColorField(
      label: tr(ctx, 'Gradient to', 'Degradado a'),
      value: s.color2,
      onChanged: (v) => both((x) => x.color2 = v),
      onClear: () => both((x) => x.color2 = null),
    ),
    if (s.color2 != null)
      ScrapSlider(
        label: tr(ctx, 'Angle', 'Ángulo'),
        value: s.angle,
        min: 0,
        max: 360,
        onChanged: (v) => both((x) => x.angle = v, live: true),
        onEnd: _c.commit,
        display: '${s.angle.round()}°',
      ),
    const SizedBox(height: 8),
    Text(
      tr(ctx, 'Pattern', 'Patrón'),
      style: Theme.of(ctx).textTheme.titleSmall,
    ),
    const SizedBox(height: 6),
    Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final p in scrapPatterns)
          PrismChip(
            label: p,
            selected: s.pattern == p,
            onTap: () => both((x) => x.pattern = p),
          ),
      ],
    ),
  ];

  List<Widget> _textureTab(
    BuildContext ctx,
    ScrapPageStyle s,
    void Function(void Function(ScrapPageStyle) f, {bool live}) both,
  ) {
    final o = s.texture;
    void setO(
      ScrapTextureStyle Function(ScrapTextureStyle t) m, {
      bool live = false,
    }) => both((x) => x.texture = m(x.texture), live: live);
    return [
      Text(
        tr(
          ctx,
          'A texture over the page colour. 70 to choose from, or use your own picture.',
          'Una textura sobre el color. 70 para elegir, o usa tu imagen.',
        ),
        style: Theme.of(ctx).textTheme.bodySmall,
      ),
      const SizedBox(height: 6),
      SizedBox(
        height: 100,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Align(
                alignment: Alignment.topCenter,
                child: PrismChip(
                  label: tr(ctx, 'None', 'Ninguna'),
                  selected: o.id == 'plain' && o.custom == null,
                  onTap: () => setO((_) => const ScrapTextureStyle()),
                ),
              ),
            ),
            for (final t in scrapTextures)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Semantics(
                  button: true,
                  selected: o.id == t.id,
                  label: t.name,
                  child: GestureDetector(
                    onTap: () => setO(
                      (x) => x.copyWith(
                        id: t.id,
                        clearCustom: true,
                        opacity: x.id == 'plain' && x.opacity == 1
                            ? 0.8
                            : x.opacity,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: o.id == t.id && o.custom == null
                                  ? Theme.of(ctx).colorScheme.primary
                                  : Colors.transparent,
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: CustomPaint(
                              painter: ScrapTexturePainter(
                                kind: t.kind,
                                c1: t.c1,
                                c2: t.c2,
                                seed: t.seed,
                                scale: t.scale,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 64,
                          child: Text(
                            t.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: Theme.of(ctx).textTheme.labelSmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      SeasonalTexturePicker(
        current: o.id,
        onPick: (id) => setO(
          (x) => x.copyWith(
            id: id,
            clearCustom: true,
            opacity: x.id == 'plain' && x.opacity == 1 ? 0.8 : x.opacity,
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Wrap(
          spacing: 8,
          children: [
            PrismButton(
              label: tr(ctx, 'Import texture picture', 'Importar textura'),
              icon: Icons.add_photo_alternate_outlined,
              density: PrismControlDensity.compact,
              onPressed: () async {
                final id = await PrismMedia.pickImage(ref, crop: false);
                if (id != null)
                  setO(
                    (x) => x.copyWith(
                      id: 'plain',
                      custom: id,
                      opacity: x.opacity == 1 ? 0.8 : x.opacity,
                    ),
                  );
              },
            ),
          ],
        ),
      ),
      if (o.id != 'plain' || o.custom != null) ...[
        ScrapSlider(
          label: tr(ctx, 'Strength', 'Intensidad'),
          value: o.intensity,
          min: 0,
          max: 2,
          onChanged: (v) => setO((x) => x.copyWith(intensity: v), live: true),
          onEnd: _c.commit,
        ),
        ScrapSlider(
          label: tr(ctx, 'Size', 'Tamaño'),
          value: o.scale,
          min: 0.3,
          max: 4,
          onChanged: (v) => setO((x) => x.copyWith(scale: v), live: true),
          onEnd: _c.commit,
        ),
        ScrapSlider(
          label: tr(ctx, 'Opacity', 'Opacidad'),
          value: o.opacity,
          min: 0.05,
          max: 1,
          onChanged: (v) => setO((x) => x.copyWith(opacity: v), live: true),
          onEnd: _c.commit,
          display: '${(o.opacity * 100).round()}%',
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final b in scrapBlendModes.keys)
              PrismChip(
                label: b,
                selected: o.blend == b,
                onTap: () => setO((x) => x.copyWith(blend: b)),
              ),
          ],
        ),
        if (o.custom == null) ...[
          ScrapColorField(
            label: tr(ctx, 'Base colour', 'Color base'),
            value: o.color,
            onChanged: (v) => setO((x) => x.copyWith(color: v)),
          ),
          ScrapColorField(
            label: tr(ctx, 'Ink colour', 'Color de tinta'),
            value: o.color2,
            onChanged: (v) => setO((x) => x.copyWith(color2: v)),
            onClear: () => setO((x) => x.copyWith(clearColors: true)),
          ),
        ],
      ],
    ];
  }

  List<Widget> _sizeTab(
    BuildContext ctx,
    ScrapPageStyle s,
    void Function(void Function(ScrapPageStyle) f, {bool live}) both,
  ) => [
    Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (n, a) in [
          (tr(ctx, 'Standard', 'Estándar'), scrapPageAspect),
          (tr(ctx, 'Square', 'Cuadrada'), 1.0),
          (tr(ctx, 'Landscape', 'Horizontal'), 1.4),
          (tr(ctx, 'Tall', 'Alta'), 0.55),
          (tr(ctx, 'Wide', 'Ancha'), 1.8),
          (tr(ctx, 'Postcard', 'Postal'), 1.5),
        ])
          PrismChip(
            label: n,
            selected: (s.aspect - a).abs() < 0.01,
            onTap: () => both((x) => x.aspect = a),
          ),
      ],
    ),
    ScrapSlider(
      label: tr(ctx, 'Proportions', 'Proporciones'),
      value: s.aspect,
      min: ScrapPageStyle.minAspect,
      max: ScrapPageStyle.maxAspect,
      onChanged: (v) => both((x) => x.aspect = v, live: true),
      onEnd: _c.commit,
      display: s.aspect.toStringAsFixed(2),
    ),
    PrismSwitchRow(
      title: tr(ctx, 'Two-page spread', 'Doble página'),
      subtitle: tr(
        ctx,
        'Draw this page twice as wide with a centre fold.',
        'Dibuja esta página al doble de ancho con un pliegue central.',
      ),
      value: s.spread,
      onChanged: (v) => both((x) => x.spread = v),
      padding: EdgeInsets.zero,
    ),
  ];

  List<Widget> _transitionTab(
    BuildContext ctx,
    ScrapPageStyle s,
    void Function(void Function(ScrapPageStyle) f, {bool live}) both,
  ) => [
    Text(
      tr(
        ctx,
        'How this page arrives when you swipe to it. Reduced-motion devices skip it.',
        'Cómo llega esta página al deslizar. Se omite con movimiento reducido.',
      ),
      style: Theme.of(ctx).textTheme.bodySmall,
    ),
    const SizedBox(height: 8),
    Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final t in scrapTransitions.entries)
          PrismChip(
            label: t.value,
            selected: s.transition == t.key,
            onTap: () => both((x) => x.transition = t.key),
          ),
      ],
    ),
  ];

  List<Widget> _templatesTab(BuildContext ctx, StateSetter set) {
    final saved = ref.read(savedPageTemplatesProvider);
    Widget tile(ScrapPageTemplate t) => Semantics(
      button: true,
      label: t.name,
      child: GestureDetector(
        onTap: () {
          _applyTemplate(t);
          Navigator.of(ctx).pop();
        },
        onLongPress: t.builtIn
            ? null
            : () async {
                final ok = await PrismDialog.confirm(
                  context: ctx,
                  title: tr(
                    ctx,
                    'Delete this template?',
                    '¿Eliminar esta plantilla?',
                  ),
                  destructive: true,
                  confirmLabel: tr(ctx, 'Delete', 'Eliminar'),
                  cancelLabel: tr(ctx, 'Cancel', 'Cancelar'),
                );
                if (ok) {
                  await _tracker.delete(t.recordId!);
                  set(() {});
                }
              },
        child: Column(
          children: [
            SizedBox(width: 74, height: 92, child: _TemplateThumb(t)),
            const SizedBox(height: 4),
            SizedBox(
              width: 82,
              child: Text(
                t.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
    return [
      Text(
        tr(
          ctx,
          'Choosing a template replaces what is on this page (undo brings it back).',
          'Elegir una plantilla reemplaza lo que hay en la página (deshacer lo recupera).',
        ),
        style: Theme.of(ctx).textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [for (final t in builtInPageTemplates) tile(t)],
      ),
      if (saved.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(
            tr(
              ctx,
              'My templates (long-press to delete)',
              'Mis plantillas (mantén para eliminar)',
            ),
            style: Theme.of(ctx).textTheme.titleSmall,
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [for (final t in saved) tile(t)],
        ),
      ],
      SeasonalPageTemplatePicker(
        onPick: (t) {
          _applyTemplate(t);
          Navigator.of(ctx).pop();
        },
      ),
      const SizedBox(height: 14),
      PrismButton(
        label: tr(
          ctx,
          'Save this page as a template',
          'Guardar esta página como plantilla',
        ),
        icon: Icons.bookmark_add_outlined,
        onPressed: () async {
          final name = await promptText(
            ctx,
            tr(ctx, 'Template name', 'Nombre de la plantilla'),
          );
          if (name == null || name.trim().isEmpty) return;
          await _tracker.create(
            kind: TrackerKind.scrapTemplate,
            title: name.trim(),
            fields: {
              // Photos and other media stay behind; the layout is what's reusable.
              'els': [
                for (final e in _c.els)
                  (ScrapElement.fromJson(e.toJson())!
                        ..media =
                            e.type == ScrapType.sticker &&
                                e.text != null &&
                                e.text!.startsWith('c:')
                            ? e.media
                            : null
                        ..by = null)
                      .toJson(),
              ],
              'style': _style.toJson(),
            },
          );
          set(() {});
          if (ctx.mounted)
            PrismToast.show(
              ctx,
              message: tr(ctx, 'Template saved.', 'Plantilla guardada.'),
            );
        },
      ),
    ];
  }

  void _applyTemplate(ScrapPageTemplate t) {
    final r = t.build();
    _c.els.clear();
    var z = 0;
    for (final e in r.els) {
      e.z = z++;
      _c.els.add(e);
    }
    _c.selected.clear();
    if (r.style != null) {
      final keepTransition = _style.transition;
      final s = r.style!..transition = keepTransition;
      _c.meta['s'] = s.toJson();
    }
    _c.commit();
  }
}

/// A small picture of what a template lays out.
class _TemplateThumb extends StatelessWidget {
  const _TemplateThumb(this.t);
  final ScrapPageTemplate t;

  @override
  Widget build(BuildContext context) {
    final r = t.build();
    final style = r.style ?? ScrapPageStyle();
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: ColoredBox(
          color: Color(style.color),
          child: CustomPaint(
            painter: _ThumbPainter(r.els, style.spread),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _ThumbPainter extends CustomPainter {
  _ThumbPainter(this.els, this.spread);
  final List<ScrapElement> els;
  final bool spread;
  @override
  void paint(Canvas canvas, Size size) {
    for (final e in els) {
      final r = Rect.fromLTWH(
        e.x * size.width,
        e.y * size.height,
        e.w * size.width,
        e.h * size.height,
      );
      canvas.save();
      canvas.translate(r.center.dx, r.center.dy);
      canvas.rotate(e.rot);
      final box = Rect.fromCenter(
        center: Offset.zero,
        width: r.width,
        height: r.height,
      );
      switch (e.type) {
        case ScrapType.text || ScrapType.note:
          for (var y = box.top + 2; y < box.bottom - 1; y += 4) {
            canvas.drawLine(
              Offset(box.left, y),
              Offset(box.right, y),
              Paint()
                ..color = Colors.black38
                ..strokeWidth = 1.2,
            );
          }
        case ScrapType.tape:
          canvas.drawRect(box, Paint()..color = const Color(0xAAF8B6C9));
        default:
          canvas.drawRRect(
            RRect.fromRectAndRadius(box, const Radius.circular(2)),
            Paint()..color = const Color(0xFFB8C4D6),
          );
      }
      canvas.restore();
    }
    if (spread)
      canvas.drawLine(
        Offset(size.width / 2, 0),
        Offset(size.width / 2, size.height),
        Paint()..color = Colors.black26,
      );
  }

  @override
  bool shouldRepaint(_ThumbPainter o) => true;
}
