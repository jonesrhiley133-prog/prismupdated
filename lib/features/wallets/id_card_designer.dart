import 'package:prism_plurality/features/links/widgets/related_records.dart'
    show promptText;
import 'package:prism_plurality/features/wallets/id_shapes.dart';
import 'package:prism_plurality/features/wallets/id_template_gallery.dart';
import 'package:prism_plurality/features/wallets/id_templates.dart';
import 'package:prism_plurality/shared/widgets/prism_image_crop_screen.dart'
    show PrismCropRatio;
import 'package:prism_plurality/shared/fonts/font_browser.dart';
import 'package:prism_plurality/shared/fonts/prism_fonts.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/experiences/color_sheet.dart';
import 'package:prism_plurality/features/experiences/export_kit.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/wallets/id_card_view.dart';
import 'package:prism_plurality/features/wallets/wallet_data.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Two-sided card designer: layers, snapping, undo/redo, templates.
class IdCardDesigner extends ConsumerStatefulWidget {
  const IdCardDesigner({super.key, required this.cardId});
  final String cardId;
  @override
  ConsumerState<IdCardDesigner> createState() => _IdCardDesignerState();
}

class _IdCardDesignerState extends ConsumerState<IdCardDesigner> {
  late CardFace _front;
  late CardFace _back;
  late Map<String, String> _values;
  late String _title;
  bool _loaded = false;
  double get _aspect => _front.aspect > 0 ? _front.aspect : _cardAspect;
  double _cardAspect = idCardRatio;
  bool _onBack = false;
  bool _snap = true;
  bool _grid = false;
  bool _dirty = false;
  String? _sel;
  final List<(CardFace, CardFace)> _undo = [];
  final List<(CardFace, CardFace)> _redo = [];

  CardFace get _face => _onBack ? _back : _front;
  CardLayer? get _layer => _face.layers.where((l) => l.id == _sel).firstOrNull;

  void _push() {
    _undo.add((_front, _back));
    if (_undo.length > 60) _undo.removeAt(0);
    _redo.clear();
    _dirty = true;
  }

  void _setFace(CardFace f, {bool record = true}) => setState(() {
    if (record) _push();
    if (_onBack) {
      _back = f;
    } else {
      _front = f;
    }
  });

  void _updateLayer(CardLayer l, {bool record = true}) => _setFace(
    _face.copyWith(
      layers: [for (final x in _face.layers) x.id == l.id ? l : x],
    ),
    record: record,
  );

  double _snapV(double v) {
    if (!_snap) return v.clamp(0, 1);
    if ((v - 0.5).abs() < 0.02) return 0.5;
    return ((v * 40).round() / 40).clamp(0.0, 1.0);
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  void _add(String kind) {
    final ink =
        _face.layers
            .where((l) => l.kind == 'text' || l.kind == 'field')
            .firstOrNull
            ?.color ??
        0xFF222222;
    final l = switch (kind) {
      'text' => CardLayer(
        id: _newId(),
        kind: 'text',
        text: 'New text',
        x: 0.1,
        y: 0.5,
        w: 0.6,
        color: ink,
      ),
      'field' => CardLayer(
        id: _newId(),
        kind: 'field',
        field: 'name',
        x: 0.1,
        y: 0.5,
        w: 0.6,
        color: ink,
      ),
      'emoji' => CardLayer(
        id: _newId(),
        kind: 'emoji',
        text: '⭐',
        x: 0.8,
        y: 0.3,
        w: 0.14,
        h: 0.22,
      ),
      'photo' => CardLayer(
        id: _newId(),
        kind: 'photo',
        x: 0.2,
        y: 0.5,
        w: 0.25,
        h: 0.45,
        color: ink,
      ),
      'barcode' => CardLayer(
        id: _newId(),
        kind: 'barcode',
        x: 0.5,
        y: 0.8,
        w: 0.6,
        h: 0.14,
        color: ink,
      ),
      'circle' => CardLayer(
        id: _newId(),
        kind: 'circle',
        x: 0.5,
        y: 0.5,
        w: 0.15,
        h: 0.24,
        color: ink,
      ),
      'line' => CardLayer(
        id: _newId(),
        kind: 'line',
        x: 0.5,
        y: 0.5,
        w: 0.8,
        h: 0.04,
        color: ink,
      ),
      _ => CardLayer(
        id: _newId(),
        kind: 'shape',
        text: kind.startsWith('shape:') ? kind.substring(6) : '',
        x: 0.5,
        y: 0.5,
        w: 0.4,
        h: 0.2,
        color: ink,
      ),
    };
    _setFace(_face.copyWith(layers: [..._face.layers, l]));
    setState(() => _sel = l.id);
  }

  Future<void> _save() async {
    final c = ref.read(idCardByIdProvider(widget.cardId));
    if (c == null) return;
    await ref
        .read(walletActionsProvider)
        .saveCard(
          c,
          front: _front,
          back: _back,
          values: _values,
          title: _title,
          collection: _front.tpl.isEmpty ? null : _front.tpl.split('.').first,
          layout: _front.tpl.isEmpty ? null : _front.tpl.split('.').last,
          aspect: _aspect,
        );
    if (mounted) {
      setState(() => _dirty = false);
      PrismToast.show(context, message: 'Card saved');
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = ref.watch(idCardByIdProvider(widget.cardId));
    if (card == null)
      return const PrismPageScaffold(
        topBar: PrismTopBar(title: 'Card', showBackButton: true),
        body: Center(child: Text('This card was deleted.')),
      );
    if (!_loaded) {
      _front = card.front;
      _back = card.back;
      _values = {...card.values};
      _title = card.r.title;
      _cardAspect = card.aspect;
      _loaded = true;
    }
    final theme = Theme.of(context);
    final members =
        ref.watch(userVisibleMembersProvider).value ?? const <Member>[];
    final m = members.where((x) => x.id == card.memberId).firstOrNull;
    final values = resolveCardValues(
      IdCard(card.r.withFields({...card.r.fields, 'values': _values})),
      m,
      ref.watch(systemIdentityProvider),
    );
    final photo = m?.avatarImageData == null
        ? null
        : Image.memory(m!.avatarImageData!, fit: BoxFit.cover);
    final l = _layer;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (did, _) async {
        if (did) return;
        final leave = await PrismDialog.confirm(
          context: context,
          title: 'Leave without saving?',
          message: 'Your changes to this card will be lost.',
          confirmLabel: 'Leave',
          destructive: true,
        );
        if (leave && context.mounted) {
          setState(() => _dirty = false);
          Navigator.of(context).pop();
        }
      },
      child: PrismPageScaffold(
        topBar: PrismTopBar(
          title: 'Design card',
          showBackButton: true,
          actions: [
            IconButton(
              tooltip: 'Undo',
              icon: const Icon(Icons.undo),
              onPressed: _undo.isEmpty
                  ? null
                  : () => setState(() {
                      _redo.add((_front, _back));
                      final u = _undo.removeLast();
                      _front = u.$1;
                      _back = u.$2;
                      _dirty = true;
                    }),
            ),
            IconButton(
              tooltip: 'Redo',
              icon: const Icon(Icons.redo),
              onPressed: _redo.isEmpty
                  ? null
                  : () => setState(() {
                      _undo.add((_front, _back));
                      final r = _redo.removeLast();
                      _front = r.$1;
                      _back = r.$2;
                      _dirty = true;
                    }),
            ),
            IconButton(
              tooltip: 'Export',
              icon: const Icon(Icons.ios_share),
              onPressed: () => _export(card, values, photo),
            ),
            PrismButton(
              label: 'Save',
              tone: PrismButtonTone.filled,
              density: PrismControlDensity.compact,
              enabled: _dirty,
              onPressed: _save,
            ),
          ],
        ),
        bodyPadding: EdgeInsets.zero,
        body: ClampedBody(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              32 + NavBarInset.of(context),
            ),
            children: [
              Center(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final w = box.maxWidth.clamp(200.0, 460.0);
                    return CardFaceView(
                      face: _face,
                      values: values,
                      photo: photo,
                      width: w,
                      ratio: _aspect,
                      selected: _sel,
                      showGrid: _grid,
                      onLayerTap: (id) => setState(() => _sel = id),
                      onLayerDrag: (id, d) {
                        final x = _face.layers.firstWhere((e) => e.id == id);
                        if (_undo.isEmpty || !_dragging) {
                          _push();
                          _dragging = true;
                        }
                        _updateLayer(
                          x.copyWith(
                            x: _snap
                                ? _snapV(x.x + d.dx)
                                : (x.x + d.dx).clamp(0, 1),
                            y: _snap
                                ? _snapV(x.y + d.dy)
                                : (x.y + d.dy).clamp(0, 1),
                          ),
                          record: false,
                        );
                      },
                    );
                  },
                ),
              ),
              Listener(
                onPointerUp: (_) => _dragging = false,
                child: const SizedBox(height: 8),
              ),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  PrismChip(
                    label: 'Front',
                    selected: !_onBack,
                    onTap: () => setState(() {
                      _onBack = false;
                      _sel = null;
                    }),
                  ),
                  PrismChip(
                    label: 'Back',
                    selected: _onBack,
                    onTap: () => setState(() {
                      _onBack = true;
                      _sel = null;
                    }),
                  ),
                  PrismChip(
                    label: 'Snap',
                    selected: _snap,
                    onTap: () => setState(() => _snap = !_snap),
                  ),
                  PrismChip(
                    label: 'Grid',
                    selected: _grid,
                    onTap: () => setState(() => _grid = !_grid),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PrismPopupMenu<String>(
                    icon: Icons.add_box_outlined,
                    tooltip: 'Add layer',
                    onSelected: (k) async {
                      if (k == 'shapes') {
                        final shape = await showIdShapePicker(context);
                        if (shape != null) _add('shape:$shape');
                      } else {
                        _add(k);
                      }
                    },
                    items: const [
                      PrismMenuItem(
                        value: 'text',
                        label: 'Text',
                        icon: Icons.title,
                      ),
                      PrismMenuItem(
                        value: 'field',
                        label: 'Field (name, pronouns…)',
                        icon: Icons.badge_outlined,
                      ),
                      PrismMenuItem(
                        value: 'emoji',
                        label: 'Emoji / symbol',
                        icon: Icons.emoji_emotions_outlined,
                      ),
                      PrismMenuItem(
                        value: 'photo',
                        label: 'Photo',
                        icon: Icons.portrait,
                      ),
                      PrismMenuItem(
                        value: 'shapes',
                        label: 'Shape (30 to choose)',
                        icon: Icons.category_outlined,
                      ),
                      PrismMenuItem(
                        value: 'circle',
                        label: 'Circle',
                        icon: Icons.circle_outlined,
                      ),
                      PrismMenuItem(
                        value: 'line',
                        label: 'Line',
                        icon: Icons.horizontal_rule,
                      ),
                      PrismMenuItem(
                        value: 'barcode',
                        label: 'Decorative barcode',
                        icon: Icons.qr_code_2,
                      ),
                    ],
                  ),
                  PrismButton(
                    label: 'Shape & size',
                    icon: Icons.aspect_ratio,
                    density: PrismControlDensity.compact,
                    onPressed: _cardShape,
                  ),
                  PrismButton(
                    label: 'Template',
                    icon: Icons.style_outlined,
                    density: PrismControlDensity.compact,
                    onPressed: () => _templates(card),
                  ),
                  PrismButton(
                    label: 'Details',
                    icon: Icons.edit_note,
                    density: PrismControlDensity.compact,
                    onPressed: () => _details(values),
                  ),
                  PrismButton(
                    label: 'Background',
                    icon: Icons.format_color_fill,
                    density: PrismControlDensity.compact,
                    onPressed: _background,
                  ),
                ],
              ),
              if (l != null) ...[
                PrismSectionHeader(title: 'SELECTED LAYER'),
                ..._props(l, theme),
              ],
              PrismSectionHeader(
                title: 'LAYERS (${_onBack ? 'BACK' : 'FRONT'})',
              ),
              for (final (i, x) in _face.layers.indexed.toList().reversed)
                PrismListRow(
                  dense: true,
                  selected: x.id == _sel,
                  title: Text(
                    _layerName(x),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => setState(() => _sel = x.id),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Bring forward',
                        icon: const Icon(Icons.arrow_upward, size: 18),
                        onPressed: i == _face.layers.length - 1
                            ? null
                            : () => _move(i, 1),
                      ),
                      IconButton(
                        tooltip: 'Send backward',
                        icon: const Icon(Icons.arrow_downward, size: 18),
                        onPressed: i == 0 ? null : () => _move(i, -1),
                      ),
                      IconButton(
                        tooltip: x.locked ? 'Unlock' : 'Lock',
                        icon: Icon(
                          x.locked ? Icons.lock : Icons.lock_open,
                          size: 18,
                        ),
                        onPressed: () =>
                            _updateLayer(x.copyWith(locked: !x.locked)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool _dragging = false;

  String _layerName(CardLayer x) => switch (x.kind) {
    'text' => 'Text: ${x.text}',
    'field' => 'Field: ${idFields[x.field] ?? x.field}',
    'emoji' => 'Emoji ${x.text}',
    'photo' => 'Photo',
    'barcode' => 'Barcode',
    'circle' => 'Circle',
    'line' => 'Line',
    _ => 'Rectangle',
  };

  void _move(int i, int d) {
    final ls = [..._face.layers];
    final x = ls.removeAt(i);
    ls.insert(i + d, x);
    _setFace(_face.copyWith(layers: ls));
  }

  List<Widget> _props(CardLayer l, ThemeData theme) {
    Widget slider(
      String label,
      double v,
      double min,
      double max,
      ValueChanged<double> on,
    ) => Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(label, style: theme.textTheme.bodySmall),
        ),
        Expanded(
          child: Slider(
            value: v.clamp(min, max),
            min: min,
            max: max,
            onChangeStart: (_) => _push(),
            onChanged: on,
          ),
        ),
      ],
    );
    final textual = l.kind == 'text' || l.kind == 'field';
    return [
      if (l.kind == 'text' || l.kind == 'emoji')
        PrismTextField(
          key: ValueKey('t${l.id}'),
          initialValue: l.text,
          labelText: l.kind == 'emoji' ? 'Emoji or symbol' : 'Text',
          onChanged: (v) => _updateLayer(l.copyWith(text: v)),
        ),
      if (l.kind == 'field')
        PrismSelect<String>(
          labelText: 'Shows',
          value: l.field ?? 'name',
          items: [
            for (final e in idFields.entries)
              if (e.key != 'photo' && e.key != 'barcode')
                PrismSelectItem(value: e.key, label: e.value),
          ],
          onChanged: (v) => _updateLayer(l.copyWith(field: v)),
        ),
      const SizedBox(height: 6),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Nudge left',
            icon: const Icon(Icons.arrow_back),
            onPressed: () =>
                _updateLayer(l.copyWith(x: (l.x - 0.01).clamp(0, 1))),
          ),
          IconButton(
            tooltip: 'Nudge up',
            icon: const Icon(Icons.arrow_upward),
            onPressed: () =>
                _updateLayer(l.copyWith(y: (l.y - 0.01).clamp(0, 1))),
          ),
          IconButton(
            tooltip: 'Nudge down',
            icon: const Icon(Icons.arrow_downward),
            onPressed: () =>
                _updateLayer(l.copyWith(y: (l.y + 0.01).clamp(0, 1))),
          ),
          IconButton(
            tooltip: 'Nudge right',
            icon: const Icon(Icons.arrow_forward),
            onPressed: () =>
                _updateLayer(l.copyWith(x: (l.x + 0.01).clamp(0, 1))),
          ),
          IconButton(
            tooltip: 'Centre horizontally',
            icon: const Icon(Icons.align_horizontal_center),
            onPressed: () => _updateLayer(
              l.copyWith(x: 0.5, align: textual ? 'center' : l.align),
            ),
          ),
        ],
      ),
      if (textual)
        slider(
          'Text size',
          l.size,
          0.02,
          0.16,
          (v) => _updateLayer(l.copyWith(size: v), record: false),
        ),
      slider(
        'Width',
        l.w,
        0.04,
        1,
        (v) => _updateLayer(l.copyWith(w: v), record: false),
      ),
      if (!textual)
        slider(
          'Height',
          l.h,
          0.02,
          1,
          (v) => _updateLayer(l.copyWith(h: v), record: false),
        ),
      slider(
        'Rotation',
        l.rotation,
        -180,
        180,
        (v) => _updateLayer(
          l.copyWith(rotation: v.roundToDouble()),
          record: false,
        ),
      ),
      if (l.kind == 'shape') ...[
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            PrismButton(
              label:
                  'Shape: ${idShapeKinds[l.text.isEmpty ? 'rrect' : l.text] ?? l.text}',
              icon: Icons.category_outlined,
              density: PrismControlDensity.compact,
              tone: PrismButtonTone.outlined,
              onPressed: () async {
                final k = await showIdShapePicker(
                  context,
                  current: l.text,
                  color: Color(l.color),
                );
                if (k != null) _updateLayer(l.copyWith(text: k));
              },
            ),
            PrismChip(
              label: 'Outline',
              selected: l.stroke > 0,
              onTap: () =>
                  _updateLayer(l.copyWith(stroke: l.stroke > 0 ? 0 : 0.02)),
            ),
            PrismChip(
              label: l.color2 == null ? 'Gradient' : 'Gradient on',
              selected: l.color2 != null,
              onTap: () async {
                if (l.color2 != null) {
                  _updateLayer(l.copyWith(color2: null));
                  return;
                }
                final c = await showPrismColorPicker(
                  context: context,
                  initial: Color(l.color),
                  title: 'Gradient end colour',
                );
                if (c != null) _updateLayer(l.copyWith(color2: c.toARGB32()));
              },
            ),
          ],
        ),
        if (l.stroke > 0)
          slider(
            'Line width',
            l.stroke,
            0.004,
            0.08,
            (v) => _updateLayer(l.copyWith(stroke: v), record: false),
          ),
      ],
      slider(
        'Opacity',
        l.opacity,
        0.05,
        1,
        (v) => _updateLayer(l.copyWith(opacity: v), record: false),
      ),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          GestureDetector(
            onTap: () async {
              final c = await showPrismColorPicker(
                context: context,
                initial: Color(l.color),
                title: 'Layer colour',
              );
              if (c != null) _updateLayer(l.copyWith(color: c.toARGB32()));
            },
            child: Semantics(
              button: true,
              label: 'Layer colour',
              child: PrismCircleAvatar(
                radius: 14,
                backgroundColor: Color(l.color),
              ),
            ),
          ),
          if (textual) ...[
            for (final a in const ['left', 'center', 'right'])
              PrismChip(
                label: a[0].toUpperCase() + a.substring(1),
                selected: l.align == a,
                onTap: () => _updateLayer(l.copyWith(align: a)),
              ),
            PrismChip(
              label: 'Bold',
              selected: l.bold,
              onTap: () => _updateLayer(l.copyWith(bold: !l.bold)),
            ),
            for (final f in const [
              'standard',
              'serif',
              'mono',
              'rounded',
              'script',
            ])
              PrismChip(
                label: f[0].toUpperCase() + f.substring(1),
                selected: l.font == f,
                onTap: () => _updateLayer(l.copyWith(font: f)),
              ),
            PrismChip(
              label:
                  PrismFonts.isCatalog(l.font) || PrismFonts.isImported(l.font)
                  ? (PrismFonts.isCatalog(l.font)
                        ? PrismFonts.familyOf(l.font)
                        : 'Imported')
                  : 'More fonts…',
              selected:
                  PrismFonts.isCatalog(l.font) || PrismFonts.isImported(l.font),
              onTap: () async {
                final pick = await showPrismFontBrowser(
                  context,
                  current: l.font,
                  allowDefault: false,
                );
                if (pick?.key != null)
                  _updateLayer(l.copyWith(font: pick!.key));
              },
            ),
          ],
        ],
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        children: [
          PrismButton(
            label: 'Duplicate',
            icon: Icons.copy,
            density: PrismControlDensity.compact,
            onPressed: () {
              final c = l.copyWith(
                id: _newId(),
                x: (l.x + 0.03).clamp(0, 1),
                y: (l.y + 0.03).clamp(0, 1),
              );
              _setFace(_face.copyWith(layers: [..._face.layers, c]));
              setState(() => _sel = c.id);
            },
          ),
          PrismButton(
            label: 'Delete',
            icon: Icons.delete_outline,
            tone: PrismButtonTone.destructive,
            density: PrismControlDensity.compact,
            onPressed: () {
              _setFace(
                _face.copyWith(
                  layers: [
                    for (final x in _face.layers)
                      if (x.id != l.id) x,
                  ],
                ),
              );
              setState(() => _sel = null);
            },
          ),
        ],
      ),
    ];
  }

  void _setAspect(double v) => setState(() {
    _push();
    _front = _front.copyWith(aspect: v);
    _back = _back.copyWith(aspect: v);
  });

  Future<void> _cardShape() async {
    await PrismSheet.show<void>(
      context: context,
      title: 'Card shape',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final o in const [
                  ('Landscape', 1.585),
                  ('Wide', 2.0),
                  ('Square', 1.0),
                  ('Portrait', 0.64),
                  ('Tall', 0.5),
                ])
                  PrismChip(
                    label: o.$1,
                    selected: (_aspect - o.$2).abs() < 0.01,
                    onTap: () {
                      _setAspect(o.$2);
                      set(() {});
                    },
                  ),
                PrismChip(
                  label: 'Custom…',
                  selected: false,
                  onTap: () async {
                    final raw = await promptText(
                      context,
                      'Width : height (e.g. 3:4)',
                      initial: '',
                    );
                    final v = raw == null ? null : PrismCropRatio.parse(raw);
                    if (v == null) return;
                    _setAspect(v.clamp(0.4, 3.0));
                    set(() {});
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Currently ${_aspect.toStringAsFixed(2)} : 1. Layers keep their place as fractions of the card, so check them after changing the shape.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _templates(IdCard card) async {
    final pick = await PrismSheet.showFullScreen<String>(
      context: context,
      builder: (ctx, scroll) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pick a design to see it on your card right away. Your details and anything you added yourself are kept, and you can undo.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: IdTemplateGallery(
                type: card.type,
                selected: _front.tpl,
                fields: {
                  for (final l in [..._front.layers, ..._back.layers])
                    if (l.kind == 'field') l.field!,
                  'photo',
                  'name',
                  'number',
                },
                onPick: (id) => Navigator.of(ctx).pop(id),
              ),
            ),
          ],
        ),
      ),
    );
    if (pick == null) return;
    final parts = pick.split('.');
    _applyTemplate(card, parts.first, parts.last);
  }

  /// Applies a template without losing anything the user made: their own
  /// layers (anything not generated by the previous template) are carried
  /// over on top of the new design, and field details are untouched.
  void _applyTemplate(IdCard card, String collection, String layout) {
    final fields = {
      for (final l in [..._front.layers, ..._back.layers])
        if (l.kind == 'field') l.field!,
      if ([..._front.layers].any((l) => l.kind == 'photo')) 'photo',
    };
    final (f, b) = buildAnyTemplate(
      collection,
      layout,
      type: card.type,
      fields: fields.isEmpty
          ? const {'name', 'pronouns', 'number', 'photo', 'issued', 'emoji'}
          : fields,
    );
    List<CardLayer> mine(CardFace old) => old.tpl.isEmpty
        ? const []
        : [
            for (final l in old.layers)
              if (!l.id.startsWith('t')) l,
          ];
    setState(() {
      _push();
      final ar = f.aspect > 0 ? f.aspect : idCardRatio;
      _front = f.copyWith(layers: [...f.layers, ...mine(_front)], aspect: ar);
      _back = b.copyWith(layers: [...b.layers, ...mine(_back)], aspect: ar);
      _sel = null;
    });
    PrismToast.show(context, message: 'Template applied — undo to go back');
  }

  Future<void> _details(Map<String, String> current) async {
    final ctrls = {
      for (final k in idFields.keys)
        if (k != 'photo' && k != 'barcode')
          k: TextEditingController(text: _values[k] ?? ''),
    };
    final title = TextEditingController(text: _title);
    final ok = await PrismSheet.show<bool>(
      context: context,
      title: 'Card details',
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        children: [
          PrismTextField(
            controller: title,
            labelText: 'Card title (for your wallet)',
          ),
          const SizedBox(height: 8),
          Text(
            'Leave a field empty to use the profile (shown greyed).',
            style: Theme.of(ctx).textTheme.bodySmall,
          ),
          for (final e in ctrls.entries)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: PrismTextField(
                controller: e.value,
                labelText: idFields[e.key]!,
                hintText: current[e.key],
              ),
            ),
          const SizedBox(height: 12),
          PrismButton(
            label: 'Done',
            tone: PrismButtonTone.filled,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        _values = {
          for (final e in ctrls.entries)
            if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
        };
        _title = title.text.trim();
        _dirty = true;
      });
    }
    for (final c in ctrls.values) {
      c.dispose();
    }
    title.dispose();
  }

  Future<void> _background() async {
    await PrismSheet.show<void>(
      context: context,
      title: 'Background',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (final (label, isFirst) in const [
                    ('Colour 1', true),
                    ('Colour 2', false),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () async {
                              final c = await showPrismColorPicker(
                                context: ctx,
                                initial: Color(isFirst ? _face.bg1 : _face.bg2),
                              );
                              if (c != null) {
                                _setFace(
                                  isFirst
                                      ? _face.copyWith(bg1: c.toARGB32())
                                      : _face.copyWith(bg2: c.toARGB32()),
                                );
                                set(() {});
                              }
                            },
                            child: PrismCircleAvatar(
                              radius: 18,
                              backgroundColor: Color(
                                isFirst ? _face.bg1 : _face.bg2,
                              ),
                            ),
                          ),
                          Text(
                            label,
                            style: Theme.of(ctx).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in const [
                    'none',
                    'dots',
                    'stripes',
                    'waves',
                    'stars',
                    'grid',
                    'holo',
                    'guilloche',
                  ])
                    PrismChip(
                      label: p[0].toUpperCase() + p.substring(1),
                      selected: _face.pattern == p,
                      onTap: () {
                        _setFace(_face.copyWith(pattern: p));
                        set(() {});
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _export(
    IdCard card,
    Map<String, String> values,
    Widget? photo,
  ) async {
    final key = GlobalKey();
    await PrismSheet.show<void>(
      context: context,
      title: 'Export card',
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            RepaintBoundary(
              key: key,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CardFaceView(
                      face: _front,
                      values: values,
                      photo: photo,
                      width: 300,
                      ratio: _aspect,
                    ),
                    const SizedBox(height: 10),
                    CardFaceView(
                      face: _back,
                      values: values,
                      photo: photo,
                      width: 300,
                      ratio: _aspect,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      fictionalIdNotice,
                      style: TextStyle(fontSize: 10, color: Color(0xFF555555)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Exports always include the “Personal / Fictional ID” notice.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                PrismButton(
                  label: 'Save image',
                  icon: Icons.image_outlined,
                  onPressed: () async {
                    final b = await captureBoundary(key);
                    if (b == null) return;
                    final ok = await saveImageBytes(
                      ref,
                      b,
                      'prism-card-${card.number}',
                    );
                    if (ctx.mounted)
                      PrismToast.show(ctx, message: ok ? 'Saved' : 'Not saved');
                  },
                ),
                PrismButton(
                  label: 'Save PDF',
                  icon: Icons.picture_as_pdf_outlined,
                  onPressed: () async {
                    final b = await captureBoundary(key);
                    if (b == null) return;
                    final ok = await savePdfBytes(
                      ref,
                      await imagesToPdf([
                        b,
                      ], title: '${card.title} — $fictionalIdNotice'),
                      'prism-card-${card.number}',
                    );
                    if (ctx.mounted)
                      PrismToast.show(ctx, message: ok ? 'Saved' : 'Not saved');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
