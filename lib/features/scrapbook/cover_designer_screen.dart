import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/scrapbook/scrap_cover.dart';
import 'package:prism_plurality/features/scrapbook/scrap_cover_templates.dart';
import 'package:prism_plurality/features/scrapbook/scrap_edit_surface.dart';
import 'package:prism_plurality/features/scrapbook/scrap_editor_core.dart';
import 'package:prism_plurality/features/scrapbook/scrap_frames.dart';
import 'package:prism_plurality/features/scrapbook/scrap_models.dart';
import 'package:prism_plurality/features/scrapbook/scrap_props.dart';
import 'package:prism_plurality/features/scrapbook/scrap_shapes.dart';
import 'package:prism_plurality/features/scrapbook/scrap_sticker_picker.dart';
import 'package:prism_plurality/features/scrapbook/scrap_texture_painter.dart';
import 'package:prism_plurality/features/scrapbook/scrap_textures.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/shared/media/prism_media.dart';
import 'package:prism_plurality/features/experiences/color_sheet.dart';
import 'package:prism_plurality/features/scrapbook/scrap_stickers.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/utils/prism_image_picker.dart';

enum _Tab { templates, size, background, texture, add, layers, opening }

/// Designs a book's cover: shape, binding, both faces, artwork, and how it
/// opens. Changes autosave; undo and redo cover every step.
class CoverDesignerScreen extends ConsumerStatefulWidget {
  const CoverDesignerScreen({super.key, required this.book});
  final TrackerRecord book;

  @override
  ConsumerState<CoverDesignerScreen> createState() => _CoverDesignerState();
}

class _CoverDesignerState extends ConsumerState<CoverDesignerScreen> {
  late final ScrapEditorController _c;
  late final TrackerNotifier _tracker;
  bool _back = false;
  _Tab _tab = _Tab.templates;
  Timer? _autosave;
  bool _saved = true;

  static const _side = 'side';

  @override
  void initState() {
    super.initState();
    _tracker = ref.read(trackerNotifierProvider.notifier);
    final d = coverOf(widget.book.fields) ?? _legacyDesign();
    final els = <ScrapElement>[];
    var z = 0;
    for (final (side, face) in [('f', d.front), ('b', d.back)]) {
      for (final e in face.els) {
        e.setOpt(_side, side);
        e.z = z++;
        els.add(e);
      }
    }
    d.front.els = [];
    d.back.els = [];
    _c = ScrapEditorController(elements: els, meta: {'d': d.toJson()});
    _c.addListener(_changed);
  }

  /// A starting design for a book that only has the old colour/emoji/picture cover.
  CoverDesign _legacyDesign() {
    final b = widget.book;
    final theme = themeById(b.str('theme'));
    final color = b.integer('color') ?? theme.$4;
    final d = coverTemplateById('blank')!.build();
    d.front.color = color;
    d.back.color = color;
    final img = b.str('cover');
    if (img != null) {
      d.front.base = 'image';
      d.front.image = img;
    }
    d.front.els = [
      ScrapElement(
        type: ScrapType.text,
        text: '{title}',
        font: 'g:Pacifico',
        color: 0xFFFFFFFF,
        size: 2.4,
        x: 0.1,
        y: 0.62,
        w: 0.8,
        h: 0.2,
        opts: {'ta': 'center', 'shrink': true, 'shd': 0.6},
      ),
      if (img == null)
        ScrapElement(
          type: ScrapType.sticker,
          text: b.str('emoji') ?? '📖',
          x: 0.3,
          y: 0.22,
          w: 0.4,
          h: 0.29,
        ),
    ];
    return d;
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
    // Selection, undo state and the selection bar all follow the controller.
    if (mounted) setState(() {});
    if (!_c.changed) return;
    _saved = false;
    _autosave?.cancel();
    _autosave = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() {});
      unawaited(_persist());
    });
  }

  // ── Design state ───────────────────────────────────────────────────────
  CoverDesign get _d =>
      CoverDesign.fromJson(_c.meta['d']) ?? coverTemplateById('blank')!.build();
  CoverFace _face(CoverDesign d) => _back ? d.back : d.front;

  void _set(CoverDesign d, {bool live = false}) {
    d.front.els = [];
    d.back.els = [];
    _c.meta['d'] = d.toJson();
    live ? _c.refresh() : _c.commit();
  }

  void _edit(void Function(CoverDesign d) f, {bool live = false}) {
    final d = _d;
    f(d);
    _set(d, live: live);
  }

  void _editFace(void Function(CoverFace f) f, {bool live = false}) =>
      _edit((d) => f(_face(d)), live: live);

  CoverDesign _compose() {
    final d = _d;
    List<ScrapElement> side(String s) => [
      for (final e in ([..._c.els]..sort((a, b) => a.z.compareTo(b.z))))
        if (e.opt<String>(_side, 'f') == s)
          ScrapElement.fromJson(e.toJson())!..opts.remove(_side),
    ];
    d.front.els = side('f');
    d.back.els = side('b');
    return d;
  }

  Future<void> _persist() async {
    try {
      final fields = {'cover2': _compose().toJson()};
      await _tracker.save(widget.book.withFields(fields));
      _saved = true;
      _c.markSaved();
      if (mounted) setState(() {});
    } catch (_) {
      // The next change retries.
    }
  }

  bool _onSide(ScrapElement e) =>
      e.opt<String>(_side, 'f') == (_back ? 'b' : 'f');

  void _add(ScrapElement e) {
    e.setOpt(_side, _back ? 'b' : 'f');
    _c.add(e);
  }

  // ── Adding things ──────────────────────────────────────────────────────
  Future<void> _addSticker() async {
    final s = await showScrapStickerPicker(context);
    if (s == null) return;
    _add(
      ScrapElement(
        type: ScrapType.sticker,
        text: s.id,
        media: s.media,
        x: 0.35,
        y: 0.3,
        w: 0.3,
        h: 0.22,
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
          h: 0.22,
        ),
      );
  }

  Future<void> _addPhoto() async {
    final id = await PrismMedia.pickImage(ref);
    if (id != null)
      _add(
        ScrapElement(
          type: ScrapType.photo,
          media: id,
          x: 0.15,
          y: 0.15,
          w: 0.7,
          h: 0.45,
          opts: {'fr2': 'polaroid'},
        ),
      );
  }

  void _addText({
    String text = '',
    String font = 'g:Pacifico',
    bool title = false,
  }) => _add(
    ScrapElement(
      type: ScrapType.text,
      text: text,
      font: font,
      color: 0xFFFFFFFF,
      size: title ? 2.4 : 1.6,
      x: 0.1,
      y: title ? 0.4 : 0.55,
      w: 0.8,
      h: title ? 0.2 : 0.12,
      opts: {'ta': 'center', 'shrink': true, 'shd': 0.5},
    ),
  );

  void _addBorder() => _add(
    ScrapElement(
      type: ScrapType.shape,
      text: 'rrect',
      color: 0xFFD4AF37,
      x: 0.05,
      y: 0.036,
      w: 0.9,
      h: 0.928,
      opts: {'nf': true, 'bc': 0xFFD4AF37, 'bw': 2.0},
    ),
  );

  void _addTape() => _add(
    ScrapElement(
      type: ScrapType.tape,
      color: 0xFFF8B6C9,
      x: 0.3,
      y: 0.02,
      w: 0.4,
      h: 0.06,
      rot: -0.1,
    ),
  );

  // ── UI ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final d = _d;
    final book = widget.book;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_saved) unawaited(_persist());
      },
      child: PrismPageScaffold(
        topBar: PrismTopBar(
          title: tr(context, 'Cover designer', 'Diseñador de portada'),
          showBackButton: true,
          actions: [
            PrismTopBarAction(
              icon: Icons.undo,
              tooltip: tr(context, 'Undo', 'Deshacer'),
              onPressed: _c.canUndo ? _c.undo : () {},
            ),
            PrismTopBarAction(
              icon: Icons.redo,
              tooltip: tr(context, 'Redo', 'Rehacer'),
              onPressed: _c.canRedo ? _c.redo : () {},
            ),
            PrismTopBarAction(
              icon: Icons.play_circle_outline,
              tooltip: tr(
                context,
                'Preview opening',
                'Vista previa de apertura',
              ),
              onPressed: () => _previewOpening(book.title),
            ),
          ],
        ),
        bodyPadding: EdgeInsets.zero,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  PrismChip(
                    label: tr(context, 'Front', 'Frente'),
                    selected: !_back,
                    onTap: () => setState(() {
                      _back = false;
                      _c.select(null);
                    }),
                  ),
                  const SizedBox(width: 8),
                  PrismChip(
                    label: tr(context, 'Back', 'Reverso'),
                    selected: _back,
                    onTap: () => setState(() {
                      _back = true;
                      _c.select(null);
                    }),
                  ),
                  const Spacer(),
                  Text(
                    _saved
                        ? tr(context, 'Saved', 'Guardado')
                        : tr(context, 'Saving…', 'Guardando…'),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            Expanded(child: _preview(d, book)),
            if (_c.selected.isNotEmpty) _selectionBar(),
            _tabs(),
            SizedBox(height: 250, child: _panel(d)),
          ],
        ),
      ),
    );
  }

  Widget _preview(CoverDesign d, TrackerRecord book) {
    final subtitle = book.str('subtitle') ?? '';
    return LayoutBuilder(
      builder: (context, box) {
        final fitW = (box.maxWidth - 48).clamp(120.0, 900.0);
        final fitH = (box.maxHeight - 40 - 48).clamp(120.0, 1400.0);
        final w = (fitW < fitH * d.aspect ? fitW : fitH * d.aspect) * _c.zoom;
        final h = w / d.aspect;
        final cover = SizedBox(
          width: w,
          height: h,
          child: ScrapCoverView(
            design: d,
            title: book.title,
            subtitle: subtitle,
            back: _back,
            elementsBuilder: (face, bw, bh) => SizedBox(
              width: bw,
              height: bh,
              child: ScrapEditSurface(
                controller: _c,
                filter: _onSide,
                onEdit: (e) => showScrapElementProps(context, _c, e),
                resolve: (e) =>
                    e.type == ScrapType.text &&
                        (e.text == '{title}' || e.text == '{subtitle}')
                    ? (ScrapElement.fromJson({
                        ...e.toJson(),
                        'tx': e.text == '{title}' ? book.title : subtitle,
                      })!)
                    : e,
              ),
            ),
          ),
        );
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: box.maxWidth,
                      minHeight: box.maxHeight - 40,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: cover,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 36,
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(
                    Icons.zoom_out,
                    size: 18,
                    color: Theme.of(context).hintColor,
                  ),
                  Expanded(
                    child: Slider(
                      value: _c.zoom,
                      min: 0.5,
                      max: 3,
                      onChanged: _c.setZoom,
                    ),
                  ),
                  Icon(
                    Icons.zoom_in,
                    size: 18,
                    color: Theme.of(context).hintColor,
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _tool(
    IconData icon,
    String tip,
    VoidCallback? onTap, {
    bool on = false,
  }) => IconButton(
    tooltip: tip,
    icon: Icon(
      icon,
      size: 20,
      color: on ? Theme.of(context).colorScheme.primary : null,
    ),
    onPressed: onTap,
  );

  Widget _selectionBar() {
    final one = _c.single;
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          if (one != null)
            _tool(
              Icons.tune,
              tr(context, 'Settings', 'Ajustes'),
              () => showScrapElementProps(context, _c, one),
            ),
          _tool(Icons.copy, tr(context, 'Copy', 'Copiar'), _c.copySelected),
          _tool(
            Icons.paste,
            tr(context, 'Paste', 'Pegar'),
            _c.canPaste ? _c.paste : null,
          ),
          _tool(
            Icons.control_point_duplicate,
            tr(context, 'Duplicate', 'Duplicar'),
            _c.duplicateSelected,
          ),
          _tool(
            Icons.group_work_outlined,
            tr(context, 'Group', 'Agrupar'),
            _c.canGroup ? _c.group : null,
          ),
          _tool(
            Icons.workspaces_outline,
            tr(context, 'Ungroup', 'Desagrupar'),
            _c.canUngroup ? _c.ungroup : null,
          ),
          _tool(
            _c.allLocked ? Icons.lock : Icons.lock_open,
            tr(context, 'Lock', 'Bloquear'),
            _c.toggleLock,
            on: _c.allLocked,
          ),
          _tool(
            Icons.flip_to_front,
            tr(context, 'Bring to front', 'Traer al frente'),
            _c.toFront,
          ),
          _tool(
            Icons.arrow_upward,
            tr(context, 'Forward', 'Subir'),
            _c.forward,
          ),
          _tool(
            Icons.arrow_downward,
            tr(context, 'Backward', 'Bajar'),
            _c.backward,
          ),
          _tool(
            Icons.flip_to_back,
            tr(context, 'Send to back', 'Enviar al fondo'),
            _c.toBack,
          ),
          _tool(
            Icons.align_horizontal_left,
            tr(context, 'Align left', 'Alinear izquierda'),
            () => _c.align(ScrapAlign.left),
          ),
          _tool(
            Icons.align_horizontal_center,
            tr(context, 'Align centre', 'Centrar'),
            () => _c.align(ScrapAlign.hCenter),
          ),
          _tool(
            Icons.align_horizontal_right,
            tr(context, 'Align right', 'Alinear derecha'),
            () => _c.align(ScrapAlign.right),
          ),
          _tool(
            Icons.align_vertical_top,
            tr(context, 'Align top', 'Alinear arriba'),
            () => _c.align(ScrapAlign.top),
          ),
          _tool(
            Icons.align_vertical_center,
            tr(context, 'Align middle', 'Centrar vertical'),
            () => _c.align(ScrapAlign.vCenter),
          ),
          _tool(
            Icons.align_vertical_bottom,
            tr(context, 'Align bottom', 'Alinear abajo'),
            () => _c.align(ScrapAlign.bottom),
          ),
          _tool(
            Icons.horizontal_distribute,
            tr(context, 'Space evenly across', 'Distribuir horizontal'),
            () => _c.distribute(horizontal: true),
          ),
          _tool(
            Icons.vertical_distribute,
            tr(context, 'Space evenly down', 'Distribuir vertical'),
            () => _c.distribute(horizontal: false),
          ),
          _tool(Icons.delete_outline, tr(context, 'Delete', 'Eliminar'), () {
            if (_c.deleteSelected() == 0)
              PrismToast.show(
                context,
                message: tr(
                  context,
                  'Locked items can’t be deleted — unlock them first.',
                  'Los elementos bloqueados no se pueden eliminar.',
                ),
              );
          }),
        ],
      ),
    );
  }

  Widget _tabs() {
    String label(_Tab t) => switch (t) {
      _Tab.templates => tr(context, 'Templates', 'Plantillas'),
      _Tab.size => tr(context, 'Shape & binding', 'Forma y encuadernado'),
      _Tab.background => tr(context, 'Background', 'Fondo'),
      _Tab.texture => tr(context, 'Texture', 'Textura'),
      _Tab.add => tr(context, 'Add', 'Añadir'),
      _Tab.layers => tr(context, 'Layers', 'Capas'),
      _Tab.opening => tr(context, 'Opening', 'Apertura'),
    };
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final t in _Tab.values)
            Padding(
              padding: const EdgeInsets.only(right: 6, top: 4, bottom: 4),
              child: PrismChip(
                label: label(t),
                selected: _tab == t,
                onTap: () => setState(() => _tab = t),
              ),
            ),
        ],
      ),
    );
  }

  Widget _panel(CoverDesign d) => switch (_tab) {
    _Tab.templates => _templates(),
    _Tab.size => _size(d),
    _Tab.background => _background(d),
    _Tab.texture => _texture(d),
    _Tab.add => _addPanel(),
    _Tab.layers => _layers(),
    _Tab.opening => _opening(d),
  };

  EdgeInsets get _pad => const EdgeInsets.fromLTRB(16, 4, 16, 16);

  // Templates ---------------------------------------------------------------
  Widget _templates() => ListView(
    padding: _pad,
    scrollCacheExtent: const ScrollCacheExtent.pixels(4000),
    children: [
      Text(
        tr(
          context,
          'Start from a template, or choose Blank and design it all yourself. Choosing one replaces the cover.',
          'Empieza con una plantilla o elige En blanco. Elegir una reemplaza la portada.',
        ),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 150,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final t in coverTemplates)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Semantics(
                  button: true,
                  label: t.name,
                  child: GestureDetector(
                    onTap: () => _applyTemplate(t),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 118,
                          child: ScrapCoverView(
                            design: t.build(),
                            title: widget.book.title,
                            subtitle: widget.book.str('subtitle') ?? '',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.name,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );

  void _applyTemplate(CoverTemplate t) {
    final d = t.build();
    _c.els.clear();
    var z = 0;
    for (final (side, face) in [('f', d.front), ('b', d.back)]) {
      for (final e in face.els) {
        e.setOpt(_side, side);
        e.z = z++;
        _c.els.add(e);
      }
    }
    _c.selected.clear();
    _set(d);
  }

  // Shape, binding ----------------------------------------------------------
  Widget _size(CoverDesign d) => ListView(
    padding: _pad,
    scrollCacheExtent: const ScrollCacheExtent.pixels(4000),
    children: [
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final (n, a) in [
            (tr(context, 'Portrait', 'Vertical'), 0.72),
            (tr(context, 'Tall', 'Alto'), 0.5),
            (tr(context, 'Pocket', 'Bolsillo'), 0.62),
            (tr(context, 'Square', 'Cuadrado'), 1.0),
            (tr(context, 'Landscape', 'Horizontal'), 1.4),
            (tr(context, 'Wide', 'Ancho'), 1.7),
          ])
            PrismChip(
              label: n,
              selected: (d.aspect - a).abs() < 0.01,
              onTap: () => _edit((x) => x.aspect = a),
            ),
        ],
      ),
      ScrapSlider(
        label: tr(context, 'Proportions', 'Proporciones'),
        value: d.aspect,
        min: CoverDesign.minAspect,
        max: CoverDesign.maxAspect,
        onChanged: (v) => _edit((x) => x.aspect = v, live: true),
        onEnd: _c.commit,
        display: d.aspect.toStringAsFixed(2),
      ),
      ScrapSlider(
        label: tr(context, 'Thickness', 'Grosor'),
        value: d.thickness,
        min: 0,
        max: 1,
        onChanged: (v) => _edit((x) => x.thickness = v, live: true),
        onEnd: _c.commit,
      ),
      ScrapSlider(
        label: tr(context, 'Corner rounding', 'Esquinas'),
        value: d.corner,
        min: 0,
        max: 0.5,
        onChanged: (v) => _edit((x) => x.corner = v, live: true),
        onEnd: _c.commit,
      ),
      ScrapSlider(
        label: tr(context, 'Spine corners', 'Esquinas del lomo'),
        value: d.spineCorner,
        min: 0,
        max: 0.3,
        onChanged: (v) => _edit((x) => x.spineCorner = v, live: true),
        onEnd: _c.commit,
      ),
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(
          tr(context, 'Binding', 'Encuadernado'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final b in coverBindings.entries)
            PrismChip(
              label: b.value,
              selected: d.binding == b.key,
              onTap: () => _edit((x) => x.binding = b.key),
            ),
        ],
      ),
      ScrapColorField(
        label: tr(context, 'Spine & binding colour', 'Color del lomo'),
        value: d.spineColor,
        onChanged: (v) => _edit((x) => x.spineColor = v),
        onClear: () => _edit((x) => x.spineColor = null),
      ),
    ],
  );

  // Background --------------------------------------------------------------
  Widget _background(CoverDesign d) {
    final f = _face(d);
    return ListView(
      padding: _pad,
      scrollCacheExtent: const ScrollCacheExtent.pixels(4000),
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (k, n) in [
              ('color', tr(context, 'Colour', 'Color')),
              ('gradient', tr(context, 'Gradient', 'Degradado')),
              ('material', tr(context, 'Material', 'Material')),
              ('image', tr(context, 'Picture', 'Imagen')),
            ])
              PrismChip(
                label: n,
                selected: f.base == k,
                onTap: () => _editFace((x) => x.base = k),
              ),
            PrismChip(
              label: tr(
                context,
                'Match back to front',
                'Igualar reverso al frente',
              ),
              selected: false,
              onTap: () => _edit((x) => x.back = x.front.copy()..els = []),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (f.base == 'color')
          ScrapColorField(
            label: tr(context, 'Colour', 'Color'),
            value: f.color,
            onChanged: (v) => _editFace((x) => x.color = v),
          ),
        if (f.base == 'gradient') ...[
          Text(
            tr(context, 'Colours (2 to 5)', 'Colores (2 a 5)'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < f.gradient.length; i++)
                GestureDetector(
                  onTap: () async {
                    final c = await showPrismColorPicker(
                      context: context,
                      initial: Color(f.gradient[i]),
                    );
                    if (c != null)
                      _editFace((x) => x.gradient[i] = c.toARGB32());
                  },
                  onLongPress: f.gradient.length > 2
                      ? () => _editFace((x) => x.gradient.removeAt(i))
                      : null,
                  child: Semantics(
                    label: tr(
                      context,
                      'Gradient colour ${i + 1}',
                      'Color ${i + 1}',
                    ),
                    button: true,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(f.gradient[i]),
                        borderRadius: prismRound(context),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                  ),
                ),
              if (f.gradient.length < 5)
                PrismButton(
                  label: tr(context, 'Add colour', 'Añadir color'),
                  icon: Icons.add,
                  density: PrismControlDensity.compact,
                  onPressed: () =>
                      _editFace((x) => x.gradient.add(x.gradient.last)),
                ),
            ],
          ),
          Text(
            tr(
              context,
              'Tap to change · long-press to remove',
              'Toca para cambiar · mantén para quitar',
            ),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          ScrapSlider(
            label: tr(context, 'Angle', 'Ángulo'),
            value: f.angle,
            min: 0,
            max: 360,
            onChanged: (v) => _editFace((x) => x.angle = v, live: true),
            onEnd: _c.commit,
            display: '${f.angle.round()}°',
          ),
        ],
        if (f.base == 'material') ...[
          SizedBox(
            height: 112,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final m in scrapMaterials)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Semantics(
                      button: true,
                      selected: f.material == m.id,
                      label: m.name,
                      child: GestureDetector(
                        onTap: () => _editFace((x) {
                          x.material = m.id;
                          x.tint = null;
                        }),
                        child: Column(
                          children: [
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: f.material == m.id
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.transparent,
                                  width: 3,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: CustomPaint(
                                  painter: ScrapTexturePainter(
                                    kind: m.kind,
                                    c1: m.c1,
                                    c2: m.c2,
                                    seed: m.seed,
                                    scale: m.scale,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 76,
                              child: Text(
                                m.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelSmall,
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
          ScrapColorField(
            label: tr(context, 'Tint (changes the base colour)', 'Tinte'),
            value: f.tint,
            onChanged: (v) => _editFace((x) => x.tint = v),
            onClear: () => _editFace((x) => x.tint = null),
          ),
          ScrapSlider(
            label: tr(context, 'Texture strength', 'Intensidad'),
            value: f.matIntensity,
            min: 0,
            max: 2,
            onChanged: (v) => _editFace((x) => x.matIntensity = v, live: true),
            onEnd: _c.commit,
          ),
          ScrapSlider(
            label: tr(context, 'Texture size', 'Tamaño'),
            value: f.matScale,
            min: 0.3,
            max: 4,
            onChanged: (v) => _editFace((x) => x.matScale = v, live: true),
            onEnd: _c.commit,
          ),
        ],
        if (f.base == 'image') ...[
          Row(
            children: [
              PrismButton(
                label: f.image == null
                    ? tr(context, 'Choose a picture', 'Elegir imagen')
                    : tr(context, 'Change picture', 'Cambiar imagen'),
                icon: Icons.image_outlined,
                onPressed: () async {
                  final id = await PrismMedia.pickImage(
                    ref,
                    spec: PrismCropSpec.background,
                  );
                  if (id != null)
                    _editFace((x) {
                      x.image = id;
                      x.fit = const ScrapImageFit();
                    });
                },
              ),
            ],
          ),
          if (f.image != null) ...[
            ScrapSlider(
              label: tr(context, 'Zoom', 'Zoom'),
              value: f.fit.zoom,
              min: 1,
              max: 4,
              onChanged: (v) => _editFace(
                (x) =>
                    x.fit = ScrapImageFit(zoom: v, dx: x.fit.dx, dy: x.fit.dy),
                live: true,
              ),
              onEnd: _c.commit,
            ),
            ScrapSlider(
              label: tr(context, 'Move ←→', 'Mover ←→'),
              value: f.fit.dx,
              min: -1,
              max: 1,
              onChanged: (v) => _editFace(
                (x) => x.fit = ScrapImageFit(
                  zoom: x.fit.zoom,
                  dx: v,
                  dy: x.fit.dy,
                ),
                live: true,
              ),
              onEnd: _c.commit,
            ),
            ScrapSlider(
              label: tr(context, 'Move ↑↓', 'Mover ↑↓'),
              value: f.fit.dy,
              min: -1,
              max: 1,
              onChanged: (v) => _editFace(
                (x) => x.fit = ScrapImageFit(
                  zoom: x.fit.zoom,
                  dx: x.fit.dx,
                  dy: v,
                ),
                live: true,
              ),
              onEnd: _c.commit,
            ),
          ],
        ],
      ],
    );
  }

  // Texture overlay ---------------------------------------------------------
  Widget _texture(CoverDesign d) {
    final f = _face(d);
    final o = f.overlay;
    void setO(
      ScrapTextureStyle Function(ScrapTextureStyle s) m, {
      bool live = false,
    }) => _editFace((x) => x.overlay = m(x.overlay), live: live);
    return ListView(
      padding: _pad,
      scrollCacheExtent: const ScrollCacheExtent.pixels(4000),
      children: [
        Text(
          tr(
            context,
            'A texture laid over the background. Mix it with blend modes, or import your own picture.',
            'Una textura sobre el fondo. Mézclala o importa tu imagen.',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: PrismChip(
                    label: tr(context, 'None', 'Ninguna'),
                    selected: o.id == 'plain' && o.custom == null,
                    onTap: () => setO((s) => const ScrapTextureStyle()),
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
                        (s) => s.copyWith(
                          id: t.id,
                          clearCustom: true,
                          opacity: s.id == 'plain' && s.opacity == 1
                              ? 0.7
                              : s.opacity,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: o.id == t.id
                                    ? Theme.of(context).colorScheme.primary
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
                            width: 62,
                            child: Text(
                              t.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelSmall,
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
        Row(
          children: [
            PrismButton(
              label: tr(context, 'Import texture picture', 'Importar textura'),
              icon: Icons.add_photo_alternate_outlined,
              density: PrismControlDensity.compact,
              onPressed: () async {
                final id = await PrismMedia.pickImage(ref, crop: false);
                if (id != null)
                  setO(
                    (s) => s.copyWith(
                      id: 'plain',
                      custom: id,
                      opacity: s.opacity == 1 ? 0.7 : s.opacity,
                    ),
                  );
              },
            ),
          ],
        ),
        if (o.id != 'plain' || o.custom != null) ...[
          ScrapSlider(
            label: tr(context, 'Strength', 'Intensidad'),
            value: o.intensity,
            min: 0,
            max: 2,
            onChanged: (v) => setO((s) => s.copyWith(intensity: v), live: true),
            onEnd: _c.commit,
          ),
          ScrapSlider(
            label: tr(context, 'Size', 'Tamaño'),
            value: o.scale,
            min: 0.3,
            max: 4,
            onChanged: (v) => setO((s) => s.copyWith(scale: v), live: true),
            onEnd: _c.commit,
          ),
          ScrapSlider(
            label: tr(context, 'Opacity', 'Opacidad'),
            value: o.opacity,
            min: 0.05,
            max: 1,
            onChanged: (v) => setO((s) => s.copyWith(opacity: v), live: true),
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
                  onTap: () => setO((s) => s.copyWith(blend: b)),
                ),
            ],
          ),
          if (o.custom == null) ...[
            ScrapColorField(
              label: tr(context, 'Base colour', 'Color base'),
              value: o.color,
              onChanged: (v) => setO((s) => s.copyWith(color: v)),
            ),
            ScrapColorField(
              label: tr(context, 'Ink colour', 'Color de tinta'),
              value: o.color2,
              onChanged: (v) => setO((s) => s.copyWith(color2: v)),
              onClear: () => setO((s) => s.copyWith(clearColors: true)),
            ),
          ],
        ],
      ],
    );
  }

  // Add ---------------------------------------------------------------------
  Widget _addPanel() => ListView(
    padding: _pad,
    scrollCacheExtent: const ScrollCacheExtent.pixels(4000),
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          PrismButton(
            label: tr(context, 'Title', 'Título'),
            icon: Icons.title,
            onPressed: () => _addText(text: '{title}', title: true),
          ),
          PrismButton(
            label: tr(context, 'Subtitle', 'Subtítulo'),
            icon: Icons.subtitles_outlined,
            onPressed: () => _addText(text: '{subtitle}', font: 'g:Caveat'),
          ),
          PrismButton(
            label: tr(context, 'Text', 'Texto'),
            icon: Icons.text_fields,
            onPressed: () =>
                _addText(text: tr(context, 'Your words', 'Tus palabras')),
          ),
          PrismButton(
            label: tr(context, 'Sticker', 'Pegatina'),
            icon: Icons.emoji_emotions_outlined,
            onPressed: _addSticker,
          ),
          PrismButton(
            label: tr(context, 'Shape', 'Forma'),
            icon: Icons.category_outlined,
            onPressed: _addShape,
          ),
          PrismButton(
            label: tr(context, 'Picture', 'Imagen'),
            icon: Icons.image_outlined,
            onPressed: _addPhoto,
          ),
          PrismButton(
            label: tr(context, 'Border', 'Borde'),
            icon: Icons.crop_square,
            onPressed: _addBorder,
          ),
          PrismButton(
            label: tr(context, 'Washi tape', 'Cinta washi'),
            icon: Icons.horizontal_rule,
            onPressed: _addTape,
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        tr(
          context,
          'Import your own decorations (PNG, SVG, GIF, WebP) from the Sticker picker. Double-tap anything to change its settings.',
          'Importa tus decoraciones desde el selector de pegatinas. Toca dos veces para cambiar sus ajustes.',
        ),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );

  // Layers ------------------------------------------------------------------
  Widget _layers() {
    final list = [
      for (final e in _c.els)
        if (_onSide(e)) e,
    ]..sort((a, b) => b.z.compareTo(a.z));
    if (list.isEmpty)
      return Center(
        child: Padding(
          padding: _pad,
          child: Text(
            tr(
              context,
              'Nothing on this side yet.',
              'Nada en este lado todavía.',
            ),
          ),
        ),
      );
    String name(ScrapElement e) => switch (e.type) {
      ScrapType.text =>
        e.text == '{title}'
            ? tr(context, 'Title', 'Título')
            : e.text == '{subtitle}'
            ? tr(context, 'Subtitle', 'Subtítulo')
            : (e.text?.isEmpty ?? true
                  ? tr(context, 'Text', 'Texto')
                  : e.text!),
      ScrapType.sticker => scrapStickerName(e.text),
      ScrapType.shape => scrapShapeName(e.text ?? 'heart'),
      ScrapType.photo => tr(context, 'Picture', 'Imagen'),
      ScrapType.tape => tr(context, 'Washi tape', 'Cinta washi'),
      _ => e.type.name,
    };
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      itemCount: list.length,
      onReorder: (from, to) {
        if (to > from) to--;
        final zs = [for (final e in list) e.z]..sort((a, b) => b.compareTo(a));
        final moved = list.removeAt(from);
        list.insert(to, moved);
        for (var i = 0; i < list.length; i++) {
          list[i].z = zs[i];
        }
        _c.commit();
      },
      itemBuilder: (_, i) {
        final e = list[i];
        final on = _c.selected.contains(e.id);
        return ListTile(
          key: ValueKey(e.id),
          dense: true,
          selected: on,
          title: Text(name(e), maxLines: 1, overflow: TextOverflow.ellipsis),
          leading: Icon(
            e.group != null ? Icons.group_work_outlined : Icons.layers_outlined,
          ),
          trailing: IconButton(
            tooltip: e.locked
                ? tr(context, 'Unlock', 'Desbloquear')
                : tr(context, 'Lock', 'Bloquear'),
            icon: Icon(e.locked ? Icons.lock : Icons.lock_open, size: 18),
            onPressed: () {
              e.locked = !e.locked;
              _c.commit();
            },
          ),
          onTap: () => _c.select(e.id),
        );
      },
    );
  }

  // Opening -----------------------------------------------------------------
  Widget _opening(CoverDesign d) => ListView(
    padding: _pad,
    scrollCacheExtent: const ScrollCacheExtent.pixels(4000),
    children: [
      Text(
        tr(
          context,
          'How this book opens when you tap its cover. Reduced-motion devices skip it.',
          'Cómo se abre este álbum al tocar su portada.',
        ),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final a in coverAnimations.entries)
            PrismChip(
              label: a.value,
              selected: d.anim == a.key,
              onTap: () {
                _edit((x) => x.anim = a.key);
                if (a.key != 'none') _previewOpening(widget.book.title);
              },
            ),
        ],
      ),
      const SizedBox(height: 8),
      PrismButton(
        label: tr(context, 'Preview', 'Vista previa'),
        icon: Icons.play_arrow,
        onPressed: () => _previewOpening(widget.book.title),
      ),
    ],
  );

  Future<void> _previewOpening(String title) async {
    final d = _compose();
    if (d.anim == 'none') return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black38,
      transitionDuration: Duration.zero,
      pageBuilder: (ctx, _, _) => ScrapCoverOpening(
        design: d,
        title: title,
        subtitle: widget.book.str('subtitle') ?? '',
        onDone: () {
          if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
        },
      ),
    );
  }
}
