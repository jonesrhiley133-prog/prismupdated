import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import 'package:prism_plurality/core/services/files/prism_file_dialog_service.dart';
import 'package:prism_plurality/features/companions/companion_screens.dart'
    show memberNamesProvider, pushPage;
import 'package:prism_plurality/features/experiences/color_sheet.dart';
import 'package:prism_plurality/features/experiences/export_kit.dart';
import 'package:prism_plurality/features/flags/flag_data.dart';
import 'package:prism_plurality/features/flags/flag_model.dart';
import 'package:prism_plurality/features/flags/flag_render.dart';
import 'package:prism_plurality/shared/media/prism_media.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

// ---------------------------------------------------------------------------
// Library

class FlagStudioScreen extends ConsumerStatefulWidget {
  const FlagStudioScreen({super.key});
  @override
  ConsumerState<FlagStudioScreen> createState() => _FlagStudioScreenState();
}

class _FlagStudioScreenState extends ConsumerState<FlagStudioScreen> {
  String _q = '';
  String? _collection;
  bool _favs = false;

  Future<void> _new() async {
    final pick = await PrismSheet.show<String>(
      context: context,
      title: 'Start from',
      builder: (ctx) => GridView.extent(
        shrinkWrap: true,
        padding: const EdgeInsets.all(12),
        maxCrossAxisExtent: 150,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.2,
        children: [
          for (final e in flagTemplates.entries)
            GestureDetector(
              onTap: () => Navigator.of(ctx).pop(e.key),
              child: Semantics(
                button: true,
                label: e.key,
                child: Column(
                  children: [
                    FlagView(design: e.value, width: 120),
                    const SizedBox(height: 4),
                    Text(e.key, style: Theme.of(ctx).textTheme.labelSmall),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    if (pick == null) return;
    final r = await ref
        .read(flagActionsProvider)
        .create(
          pick == 'Blank' ? 'New flag' : '$pick (mine)',
          flagTemplates[pick]!,
          collection: _collection ?? '',
        );
    if (mounted) await pushPage<void>(context, FlagEditorScreen(flagId: r.id));
  }

  Future<void> _importProject() async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json', 'prismflag', 'svg'],
      withData: true,
    );
    final f = res?.files.firstOrNull;
    if (f?.bytes == null) return;
    try {
      final text = utf8.decode(f!.bytes!);
      if (f.name.toLowerCase().endsWith('.svg')) {
        final paths = importSvg(text);
        if (paths.isEmpty) throw const FormatException('No shapes found');
        await ref
            .read(flagActionsProvider)
            .create(
              f.name.replaceAll(RegExp(r'\.svg$', caseSensitive: false), ''),
              FlagDesign(
                layers: [
                  FlagLayer(
                    id: newLayerId(),
                    kind: 'vector',
                    x: 0.5,
                    y: 0.5,
                    w: 1,
                    h: 1,
                    paths: paths,
                  ),
                ],
              ),
            );
      } else {
        final j = jsonDecode(text) as Map;
        if (j['format'] != 'prism.flag')
          throw const FormatException('Not a Prism flag project');
        final r = await ref
            .read(flagActionsProvider)
            .create(
              '${j['name'] ?? 'Imported flag'}',
              FlagDesign.fromJson(j['design']),
            );
        await ref
            .read(flagActionsProvider)
            .update(
              r.id,
              meaning: '${j['meaning'] ?? ''}',
              fields: {
                'colorMeanings': j['colorMeanings'] ?? const {},
                'creator': j['creator'] ?? '',
              },
            );
      }
      if (mounted) PrismToast.show(context, message: 'Flag imported');
    } catch (e) {
      if (mounted) PrismToast.show(context, message: 'Couldn\'t import: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(flagsProvider);
    final theme = Theme.of(context);
    final collections = {
      for (final f in all)
        if (f.collection.isNotEmpty) f.collection,
    }.toList()..sort();
    final shown = [
      for (final f in all)
        if ((!_favs || f.favorite) &&
            (_collection == null || f.collection == _collection) &&
            (_q.isEmpty ||
                f.name.toLowerCase().contains(_q.toLowerCase()) ||
                f.meaning.toLowerCase().contains(_q.toLowerCase())))
          f,
    ];
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: 'Flag Studio',
        showBackButton: true,
        actions: [
          IconButton(
            tooltip: 'Import flag or project',
            icon: const Icon(Icons.file_open_outlined),
            onPressed: _importProject,
          ),
        ],
      ),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + NavBarInset.of(context)),
          children: [
            Text(
              'Design flags for your system, headmates and identities — stripes, symbols, drawings and imported art.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            PrismButton(
              label: 'New flag',
              icon: Icons.flag_outlined,
              tone: PrismButtonTone.filled,
              expanded: true,
              onPressed: _new,
            ),
            const SizedBox(height: 10),
            PrismTextField(
              hintText: 'Search flags',
              prefixIcon: const Icon(Icons.search),
              onChanged: (v) => setState(() => _q = v),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                PrismChip(
                  label: '★ Favourites',
                  selected: _favs,
                  onTap: () => setState(() => _favs = !_favs),
                ),
                for (final c in collections)
                  PrismChip(
                    label: '📁 $c',
                    selected: _collection == c,
                    onTap: () => setState(
                      () => _collection = _collection == c ? null : c,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  all.isEmpty
                      ? 'No flags yet — make your first one.'
                      : 'No flags match.',
                  textAlign: TextAlign.center,
                ),
              ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final f in shown)
                  GestureDetector(
                    onTap: () =>
                        pushPage<void>(context, FlagInfoScreen(flagId: f.id)),
                    child: Semantics(
                      button: true,
                      label: 'Flag: ${f.name}',
                      child: SizedBox(
                        width: 150,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FlagView(design: f.design, width: 150),
                            const SizedBox(height: 4),
                            Text(
                              '${f.favorite ? '★ ' : ''}${f.name}',
                              style: theme.textTheme.labelLarge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Editor

const _palettes = <String, List<int>>{
  'Rainbow': [
    0xFFE40303,
    0xFFFF8C00,
    0xFFFFED00,
    0xFF008026,
    0xFF24408E,
    0xFF732982,
  ],
  'Trans': [0xFF5BCEFA, 0xFFF5A9B8, 0xFFFFFFFF],
  'Pastel': [0xFFFFD1DC, 0xFFFFF1BA, 0xFFC1F0C1, 0xFFBDE0FE, 0xFFE0C3FC],
  'Earthy': [0xFF6B4226, 0xFFA97C50, 0xFFD9C3A0, 0xFF6E7F52, 0xFF2F3E2E],
  'Ocean': [0xFF03045E, 0xFF0077B6, 0xFF00B4D8, 0xFF90E0EF, 0xFFCAF0F8],
  'Sunset': [0xFF5C2A9D, 0xFFB5179E, 0xFFF72585, 0xFFFF9E00, 0xFFFFD60A],
  'Night': [0xFF0B0C2A, 0xFF2B2D5C, 0xFF6C5BA8, 0xFFC9B6F2, 0xFFFFD866],
  'Mono': [0xFF000000, 0xFF555555, 0xFFAAAAAA, 0xFFFFFFFF],
};

class FlagEditorScreen extends ConsumerStatefulWidget {
  const FlagEditorScreen({super.key, required this.flagId});
  final String flagId;
  @override
  ConsumerState<FlagEditorScreen> createState() => _FlagEditorScreenState();
}

class _FlagEditorScreenState extends ConsumerState<FlagEditorScreen> {
  FlagDesign? _d;
  String? _sel;
  String _tool = 'select'; // select, brush, place
  String _panel = 'Layers';
  String _placeShape = 'star';
  int _brushColor = 0xFF222222;
  double _brushWidth = 0.02;
  int _stripe = 0;
  final List<FlagDesign> _undo = [];
  final List<FlagDesign> _redo = [];
  final List<int> _swatches = [];
  Timer? _autosave;
  bool _saved = true;

  FlagDesign get d => _d!;
  FlagLayer? get _layer => d.layers.where((l) => l.id == _sel).firstOrNull;

  @override
  void dispose() {
    if (_autosave?.isActive ?? false) {
      _autosave!.cancel();
      ref.read(flagActionsProvider).saveDesign(widget.flagId, d);
    }
    super.dispose();
  }

  void _set(FlagDesign n, {bool record = true}) {
    setState(() {
      if (record) {
        _undo.add(d);
        if (_undo.length > 80) _undo.removeAt(0);
        _redo.clear();
      }
      _d = n;
      _saved = false;
    });
    _autosave?.cancel();
    _autosave = Timer(const Duration(milliseconds: 1200), () async {
      await ref.read(flagActionsProvider).saveDesign(widget.flagId, d);
      if (mounted) setState(() => _saved = true);
    });
  }

  void _setLayer(FlagLayer l, {bool record = true}) => _set(
    d.copyWith(layers: [for (final x in d.layers) x.id == l.id ? l : x]),
    record: record,
  );

  void _addLayer(FlagLayer l) {
    _set(d.copyWith(layers: [...d.layers, l]));
    setState(() => _sel = l.id);
  }

  bool _movable(FlagLayer l) =>
      const {'shape', 'symbol', 'text', 'vector', 'image'}.contains(l.kind);

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(flagByIdProvider(widget.flagId));
    if (f == null)
      return const PrismPageScaffold(
        topBar: PrismTopBar(title: 'Flag', showBackButton: true),
        body: Center(child: Text('This flag was deleted.')),
      );
    _d ??= f.design;
    final theme = Theme.of(context);
    final l = _layer;
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: f.name,
        subtitle: _saved ? 'Saved' : 'Saving…',
        showBackButton: true,
        actions: [
          IconButton(
            tooltip: 'Undo',
            icon: const Icon(Icons.undo),
            onPressed: _undo.isEmpty
                ? null
                : () {
                    _redo.add(d);
                    _set(_undo.removeLast(), record: false);
                  },
          ),
          IconButton(
            tooltip: 'Redo',
            icon: const Icon(Icons.redo),
            onPressed: _redo.isEmpty
                ? null
                : () {
                    _undo.add(d);
                    _set(_redo.removeLast(), record: false);
                  },
          ),
          IconButton(
            tooltip: 'Versions',
            icon: const Icon(Icons.history),
            onPressed: () => _versions(f),
          ),
        ],
      ),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + NavBarInset.of(context)),
          children: [
            Center(
              child: LayoutBuilder(
                builder: (context, box) {
                  final w = box.maxWidth.clamp(200.0, 520.0);
                  final h = w / d.aspect;
                  Offset frac(Offset p) =>
                      Offset((p.dx / w).clamp(0, 1), (p.dy / h).clamp(0, 1));
                  return GestureDetector(
                    onTapUp: (e) {
                      final p = frac(e.localPosition);
                      if (_tool == 'place') {
                        _addLayer(
                          FlagLayer(
                            id: newLayerId(),
                            kind: 'shape',
                            shape: _placeShape,
                            x: p.dx,
                            y: p.dy,
                            w: 0.18,
                            h: 0.18 * d.aspect,
                            colors: [_brushColor],
                          ),
                        );
                      } else if (_tool == 'select') {
                        // Select the topmost movable layer near the tap.
                        for (final x in d.layers.reversed) {
                          if (_movable(x) &&
                              (x.x - p.dx).abs() < x.w / 2 + 0.03 &&
                              (x.y - p.dy).abs() <
                                  (x.kind == 'symbol' || x.kind == 'text'
                                          ? x.w * d.aspect / 2
                                          : x.h / 2) +
                                      0.03) {
                            setState(() => _sel = x.id);
                            return;
                          }
                        }
                        setState(() => _sel = null);
                      }
                    },
                    onPanStart: (e) {
                      final p = frac(e.localPosition);
                      if (_tool == 'brush') {
                        _addLayer(
                          FlagLayer(
                            id: newLayerId(),
                            kind: 'draw',
                            colors: [_brushColor],
                            stroke: _brushWidth,
                            points: [p],
                          ),
                        );
                      } else if (l != null && !l.locked && _movable(l)) {
                        _set(d, record: true);
                      }
                    },
                    onPanUpdate: (e) {
                      final cur = _layer;
                      if (cur == null) return;
                      if (_tool == 'brush' && cur.kind == 'draw') {
                        _setLayer(
                          cur.copyWith(
                            points: [...cur.points, frac(e.localPosition)],
                          ),
                          record: false,
                        );
                      } else if (_tool == 'select' &&
                          !cur.locked &&
                          _movable(cur)) {
                        _setLayer(
                          cur.copyWith(
                            x: (cur.x + e.delta.dx / w).clamp(0, 1),
                            y: (cur.y + e.delta.dy / h).clamp(0, 1),
                          ),
                          record: false,
                        );
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: FlagView(design: d, width: w),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                PrismChip(
                  label: '👆 Select / move',
                  selected: _tool == 'select',
                  onTap: () => setState(() => _tool = 'select'),
                ),
                PrismChip(
                  label: '🖌️ Draw',
                  selected: _tool == 'brush',
                  onTap: () => setState(() => _tool = 'brush'),
                ),
                PrismChip(
                  label: '⭐ Place shape',
                  selected: _tool == 'place',
                  onTap: () => setState(() => _tool = 'place'),
                ),
              ],
            ),
            if (_tool != 'select') ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      final c = await showPrismColorPicker(
                        context: context,
                        initial: Color(_brushColor),
                        title: 'Tool colour',
                      );
                      if (c != null) setState(() => _brushColor = c.toARGB32());
                    },
                    child: Semantics(
                      button: true,
                      label: 'Tool colour',
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: Color(_brushColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_tool == 'brush') ...[
                    const Text('Brush'),
                    Expanded(
                      child: Slider(
                        value: _brushWidth,
                        min: 0.005,
                        max: 0.1,
                        onChanged: (v) => setState(() => _brushWidth = v),
                      ),
                    ),
                  ] else
                    Expanded(
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final s in flagShapeKinds)
                            PrismChip(
                              label: s,
                              selected: _placeShape == s,
                              onTap: () => setState(() => _placeShape = s),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in const [
                  'Layers',
                  'Layout',
                  'Symbols',
                  'Colours',
                  'Import',
                  'Flag',
                ])
                  PrismChip(
                    label: p,
                    selected: _panel == p,
                    onTap: () => setState(() => _panel = p),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ...switch (_panel) {
              'Layout' => _layoutPanel(),
              'Symbols' => _symbolPanel(),
              'Colours' => _colourPanel(),
              'Import' => _importPanel(),
              'Flag' => _flagPanel(),
              _ => _layersPanel(theme),
            },
            if (l != null && _panel != 'Layers') ...[
              PrismSectionHeader(title: 'SELECTED: ${l.label.toUpperCase()}'),
              ..._layerProps(l, theme),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _layersPanel(ThemeData theme) {
    final l = _layer;
    return [
      for (final (i, x) in d.layers.indexed.toList().reversed)
        PrismListRow(
          dense: true,
          selected: x.id == _sel,
          onTap: () => setState(() => _sel = x.id),
          title: Text(
            x.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: x.visible ? null : TextStyle(color: theme.disabledColor),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: x.visible ? 'Hide' : 'Show',
                icon: Icon(
                  x.visible ? Icons.visibility : Icons.visibility_off,
                  size: 18,
                ),
                onPressed: () => _setLayer(x.copyWith(visible: !x.visible)),
              ),
              IconButton(
                tooltip: x.locked ? 'Unlock' : 'Lock',
                icon: Icon(x.locked ? Icons.lock : Icons.lock_open, size: 18),
                onPressed: () => _setLayer(x.copyWith(locked: !x.locked)),
              ),
              IconButton(
                tooltip: 'Move up',
                icon: const Icon(Icons.arrow_upward, size: 18),
                onPressed: i == d.layers.length - 1
                    ? null
                    : () => _reorder(i, 1),
              ),
              IconButton(
                tooltip: 'Move down',
                icon: const Icon(Icons.arrow_downward, size: 18),
                onPressed: i == 0 ? null : () => _reorder(i, -1),
              ),
            ],
          ),
        ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          PrismButton(
            label: 'Add text',
            icon: Icons.title,
            density: PrismControlDensity.compact,
            onPressed: () => _addLayer(
              FlagLayer(
                id: newLayerId(),
                kind: 'text',
                text: 'Text',
                w: 0.2,
                colors: [_brushColor],
              ),
            ),
          ),
          PrismButton(
            label: 'Add shape',
            icon: Icons.category_outlined,
            density: PrismControlDensity.compact,
            onPressed: () => _addLayer(
              FlagLayer(
                id: newLayerId(),
                kind: 'shape',
                shape: _placeShape,
                w: 0.2,
                h: 0.2 * d.aspect,
                colors: [_brushColor],
              ),
            ),
          ),
        ],
      ),
      if (l != null) ...[
        PrismSectionHeader(title: 'SELECTED: ${l.label.toUpperCase()}'),
        ..._layerProps(l, theme),
      ],
    ];
  }

  void _reorder(int i, int dir) {
    final ls = [...d.layers];
    final x = ls.removeAt(i);
    ls.insert(i + dir, x);
    _set(d.copyWith(layers: ls));
  }

  List<Widget> _layerProps(FlagLayer l, ThemeData theme) {
    Widget slider(
      String label,
      double v,
      double min,
      double max,
      FlagLayer Function(double) on,
    ) => Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(label, style: theme.textTheme.bodySmall),
        ),
        Expanded(
          child: Slider(
            value: v.clamp(min, max),
            min: min,
            max: max,
            onChangeStart: (_) => _set(d),
            onChanged: (x) => _setLayer(on(x), record: false),
          ),
        ),
      ],
    );
    final positioned = _movable(l);
    return [
      if (l.kind == 'text' || l.kind == 'symbol')
        PrismTextField(
          key: ValueKey('t${l.id}'),
          initialValue: l.text,
          labelText: l.kind == 'symbol' ? 'Symbol' : 'Text',
          onChanged: (v) => _setLayer(l.copyWith(text: v)),
        ),
      const SizedBox(height: 6),
      Text(
        l.kind == 'layout'
            ? 'Colours (tap one to change it; stripes can be added or removed)'
            : 'Colour',
        style: theme.textTheme.bodySmall,
      ),
      const SizedBox(height: 4),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final (i, c) in l.colors.indexed)
            GestureDetector(
              onTap: () async {
                setState(() => _stripe = i);
                final picked = await showPrismColorPicker(
                  context: context,
                  initial: Color(c),
                  title: 'Colour ${i + 1}',
                );
                if (picked != null)
                  _setLayer(
                    l.copyWith(
                      colors: [
                        for (final (j, x) in l.colors.indexed)
                          j == i ? picked.toARGB32() : x,
                      ],
                    ),
                  );
              },
              child: Semantics(
                button: true,
                label: 'Colour ${i + 1}',
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Color(c),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _stripe == i
                          ? theme.colorScheme.primary
                          : Colors.black26,
                      width: _stripe == i ? 3 : 1,
                    ),
                  ),
                ),
              ),
            ),
          if (l.kind == 'layout') ...[
            IconButton(
              tooltip: 'Add stripe / colour',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () =>
                  _setLayer(l.copyWith(colors: [...l.colors, l.colors.last])),
            ),
            IconButton(
              tooltip: 'Remove last',
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: l.colors.length <= 1
                  ? null
                  : () => _setLayer(
                      l.copyWith(
                        colors: l.colors.sublist(0, l.colors.length - 1),
                      ),
                    ),
            ),
          ],
        ],
      ),
      if (positioned) ...[
        slider('Across', l.x, 0, 1, (v) => l.copyWith(x: v)),
        slider('Down', l.y, 0, 1, (v) => l.copyWith(y: v)),
        slider(
          l.kind == 'symbol' || l.kind == 'text' ? 'Size' : 'Width',
          l.w,
          0.02,
          1.2,
          (v) => l.copyWith(w: v),
        ),
        if (l.kind != 'symbol' && l.kind != 'text')
          slider('Height', l.h, 0.02, 1.2, (v) => l.copyWith(h: v)),
        slider(
          'Rotation',
          l.rotation,
          -180,
          180,
          (v) => l.copyWith(rotation: v.roundToDouble()),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Nudge left',
              icon: const Icon(Icons.arrow_back),
              onPressed: () =>
                  _setLayer(l.copyWith(x: (l.x - 0.01).clamp(0, 1))),
            ),
            IconButton(
              tooltip: 'Nudge up',
              icon: const Icon(Icons.arrow_upward),
              onPressed: () =>
                  _setLayer(l.copyWith(y: (l.y - 0.01).clamp(0, 1))),
            ),
            IconButton(
              tooltip: 'Nudge down',
              icon: const Icon(Icons.arrow_downward),
              onPressed: () =>
                  _setLayer(l.copyWith(y: (l.y + 0.01).clamp(0, 1))),
            ),
            IconButton(
              tooltip: 'Nudge right',
              icon: const Icon(Icons.arrow_forward),
              onPressed: () =>
                  _setLayer(l.copyWith(x: (l.x + 0.01).clamp(0, 1))),
            ),
            IconButton(
              tooltip: 'Centre',
              icon: const Icon(Icons.center_focus_strong),
              onPressed: () => _setLayer(l.copyWith(x: 0.5, y: 0.5)),
            ),
          ],
        ),
      ],
      if (l.kind == 'shape')
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final s in flagShapeKinds)
              PrismChip(
                label: s,
                selected: l.shape == s,
                onTap: () => _setLayer(l.copyWith(shape: s)),
              ),
          ],
        ),
      if (l.kind == 'layout')
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final e in flagLayouts.entries)
              PrismChip(
                label: e.value,
                selected: l.layout == e.key,
                onTap: () => _setLayer(l.copyWith(layout: e.key)),
              ),
          ],
        ),
      if (l.kind == 'draw')
        slider('Thickness', l.stroke, 0.005, 0.1, (v) => l.copyWith(stroke: v)),
      slider('Opacity', l.opacity, 0.05, 1, (v) => l.copyWith(opacity: v)),
      Wrap(
        spacing: 8,
        children: [
          PrismButton(
            label: 'Duplicate',
            icon: Icons.copy,
            density: PrismControlDensity.compact,
            onPressed: () => _addLayer(
              l.copyWith(
                id: newLayerId(),
                x: (l.x + 0.04).clamp(0, 1),
                y: (l.y + 0.04).clamp(0, 1),
              ),
            ),
          ),
          PrismButton(
            label: 'Delete',
            icon: Icons.delete_outline,
            tone: PrismButtonTone.destructive,
            density: PrismControlDensity.compact,
            onPressed: () {
              _set(
                d.copyWith(
                  layers: [
                    for (final x in d.layers)
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

  List<Widget> _layoutPanel() => [
    Text(
      'Adds a layout layer — stack several (e.g. stripes + canton).',
      style: Theme.of(context).textTheme.bodySmall,
    ),
    const SizedBox(height: 6),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in flagLayouts.entries)
          GestureDetector(
            onTap: () => _addLayer(
              FlagLayer(
                id: newLayerId(),
                kind: 'layout',
                layout: e.key,
                colors: e.key.contains('stripes')
                    ? const [0xFFE40303, 0xFFFFFFFF, 0xFF24408E]
                    : const [0xFF24408E, 0xFFFFD34E],
              ),
            ),
            child: Semantics(
              button: true,
              label: e.value,
              child: Column(
                children: [
                  FlagView(
                    design: FlagDesign(
                      layers: [
                        const FlagLayer(
                          id: 'b',
                          kind: 'fill',
                          colors: [0xFFFFFFFF],
                        ),
                        FlagLayer(
                          id: 'p',
                          kind: 'layout',
                          layout: e.key,
                          colors: e.key.contains('stripes')
                              ? const [0xFFE40303, 0xFFFFFFFF, 0xFF24408E]
                              : const [0xFF24408E, 0xFFFFD34E],
                        ),
                      ],
                    ),
                    width: 90,
                  ),
                  SizedBox(
                    width: 90,
                    child: Text(
                      e.value,
                      style: Theme.of(context).textTheme.labelSmall,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  ];

  List<Widget> _symbolPanel() => [
    for (final e in flagSymbols.entries) ...[
      Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 2),
        child: Text(e.key, style: Theme.of(context).textTheme.titleSmall),
      ),
      Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final s in e.value)
            SizedBox(
              width: 40,
              height: 40,
              child: PrismButton(
                label: s,
                density: PrismControlDensity.compact,
                semanticLabel: 'Add symbol $s',
                onPressed: () => _addLayer(
                  FlagLayer(
                    id: newLayerId(),
                    kind: 'symbol',
                    text: s,
                    w: 0.3,
                    colors: [_brushColor],
                  ),
                ),
              ),
            ),
        ],
      ),
    ],
  ];

  List<Widget> _colourPanel() {
    final l = _layer;
    void apply(int c) {
      if (l == null) {
        setState(() => _brushColor = c);
        return;
      }
      final i = _stripe.clamp(0, l.colors.length - 1);
      _setLayer(
        l.copyWith(
          colors: [for (final (j, x) in l.colors.indexed) j == i ? c : x],
        ),
      );
    }

    return [
      Text(
        l == null
            ? 'Tap a colour to use it with the drawing tools.'
            : 'Tap a colour to apply it to the selected layer (colour ${_stripe + 1}).',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 6),
      PrismButton(
        label: 'Custom colour…',
        icon: Icons.colorize,
        density: PrismControlDensity.compact,
        onPressed: () async {
          final c = await showPrismColorPicker(
            context: context,
            initial: Color(l?.color ?? _brushColor),
          );
          if (c != null) {
            apply(c.toARGB32());
            setState(() => _swatches.insert(0, c.toARGB32()));
          }
        },
      ),
      if (_swatches.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text('Recent', style: Theme.of(context).textTheme.titleSmall),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [for (final c in _swatches.take(16)) _swatch(c, apply)],
        ),
      ],
      for (final e in _palettes.entries) ...[
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 2),
          child: Text(e.key, style: Theme.of(context).textTheme.titleSmall),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in e.value) _swatch(c, apply),
            if (l?.kind == 'layout')
              PrismButton(
                label: 'Use as stripes',
                density: PrismControlDensity.compact,
                onPressed: () => _setLayer(l!.copyWith(colors: e.value)),
              ),
          ],
        ),
      ],
    ];
  }

  Widget _swatch(int c, void Function(int) apply) => GestureDetector(
    onTap: () => apply(c),
    child: Semantics(
      button: true,
      label: 'Colour #${(c & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Color(c),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black26),
        ),
      ),
    ),
  );

  List<Widget> _importPanel() => [
    Text(
      'Images become layers you can move and resize. SVGs are converted to shapes (scripts and links are removed).',
      style: Theme.of(context).textTheme.bodySmall,
    ),
    const SizedBox(height: 8),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        PrismButton(
          label: 'Upload image',
          icon: Icons.image_outlined,
          density: PrismControlDensity.compact,
          onPressed: () async {
            final id = await PrismMedia.pickImage(ref);
            if (id != null)
              _addLayer(
                FlagLayer(
                  id: newLayerId(),
                  kind: 'image',
                  media: id,
                  w: 0.4,
                  h: 0.6,
                ),
              );
          },
        ),
        PrismButton(
          label: 'Image from link',
          icon: Icons.link,
          density: PrismControlDensity.compact,
          onPressed: _fromUrl,
        ),
        PrismButton(
          label: 'SVG file',
          icon: Icons.polyline_outlined,
          density: PrismControlDensity.compact,
          onPressed: () async {
            final res = await FilePicker.pickFiles(
              type: FileType.custom,
              allowedExtensions: const ['svg'],
              withData: true,
            );
            final b = res?.files.firstOrNull?.bytes;
            if (b == null) return;
            if (b.length > 2 * 1024 * 1024) {
              if (mounted)
                PrismToast.show(
                  context,
                  message: 'That SVG is too large (2 MB max).',
                );
              return;
            }
            final paths = importSvg(utf8.decode(b, allowMalformed: true));
            if (paths.isEmpty) {
              if (mounted)
                PrismToast.show(
                  context,
                  message: 'No shapes found in that SVG.',
                );
              return;
            }
            _addLayer(
              FlagLayer(
                id: newLayerId(),
                kind: 'vector',
                x: 0.5,
                y: 0.5,
                w: 1,
                h: 1,
                paths: paths,
              ),
            );
          },
        ),
      ],
    ),
  ];

  Future<void> _fromUrl() async {
    final c = TextEditingController();
    final url = await PrismDialog.show<String>(
      context: context,
      title: 'Image or SVG from a link',
      message:
          'Prism downloads it once and keeps a copy. Only images and SVGs are accepted.',
      builder: (_) => TextField(
        controller: c,
        autofocus: true,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(hintText: 'https://…'),
      ),
      actions: [
        PrismButton(
          label: 'Add',
          tone: PrismButtonTone.filled,
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(c.text.trim()),
        ),
      ],
    );
    final uri = Uri.tryParse(url ?? '');
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) return;
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 20));
      final type = res.headers['content-type'] ?? '';
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      if (res.bodyBytes.length > 8 * 1024 * 1024)
        throw Exception('file is larger than 8 MB');
      if (type.contains('svg') || uri.path.toLowerCase().endsWith('.svg')) {
        final paths = importSvg(
          utf8.decode(res.bodyBytes, allowMalformed: true),
        );
        if (paths.isEmpty) throw Exception('no shapes found');
        _addLayer(
          FlagLayer(
            id: newLayerId(),
            kind: 'vector',
            x: 0.5,
            y: 0.5,
            w: 1,
            h: 1,
            paths: paths,
          ),
        );
      } else if (type.startsWith('image/')) {
        final id = await storeImage(ref, res.bodyBytes);
        if (id == null) throw Exception('couldn\'t store image');
        _addLayer(
          FlagLayer(id: newLayerId(), kind: 'image', media: id, w: 0.4, h: 0.6),
        );
      } else {
        throw Exception('that link isn\'t an image');
      }
    } catch (e) {
      if (mounted) PrismToast.show(context, message: 'Couldn\'t add it: $e');
    }
  }

  List<Widget> _flagPanel() => [
    Text(
      'Proportions (height : width)',
      style: Theme.of(context).textTheme.titleSmall,
    ),
    const SizedBox(height: 4),
    Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final r in flagRatios.keys)
          PrismChip(
            label: r,
            selected: d.ratio == r,
            onTap: () => _set(d.copyWith(ratio: r)),
          ),
      ],
    ),
    const SizedBox(height: 10),
    Text('Shape', style: Theme.of(context).textTheme.titleSmall),
    const SizedBox(height: 4),
    Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final e in flagShapes.entries)
          PrismChip(
            label: e.value,
            selected: d.shape == e.key,
            onTap: () => _set(d.copyWith(shape: e.key)),
          ),
      ],
    ),
  ];

  Future<void> _versions(FlagEntry f) async {
    await PrismSheet.show<void>(
      context: context,
      title: 'Versions',
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final fresh = ref.watch(flagByIdProvider(widget.flagId)) ?? f;
          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(12),
            children: [
              PrismButton(
                label: 'Save this version',
                icon: Icons.bookmark_add_outlined,
                tone: PrismButtonTone.filled,
                onPressed: () async {
                  await ref
                      .read(flagActionsProvider)
                      .saveVersion(
                        widget.flagId,
                        d,
                        label: 'Version ${fresh.versions.length + 1}',
                      );
                  if (ctx.mounted)
                    PrismToast.show(ctx, message: 'Version saved');
                },
              ),
              const SizedBox(height: 8),
              if (fresh.versions.isEmpty)
                const Text(
                  'No saved versions yet. Changes autosave; versions are snapshots you can go back to.',
                ),
              for (final (at, design, label) in fresh.versions.reversed)
                PrismListRow(
                  leading: FlagView(design: design, width: 60, border: false),
                  title: Text(label.isEmpty ? 'Version' : label),
                  subtitle: Text(
                    '${at.day}/${at.month}/${at.year} ${at.hour}:${at.minute.toString().padLeft(2, '0')}',
                  ),
                  trailing: PrismButton(
                    label: 'Restore',
                    density: PrismControlDensity.compact,
                    onPressed: () {
                      _set(design);
                      Navigator.of(ctx).pop();
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info page, previews, assignment, export

class FlagInfoScreen extends ConsumerStatefulWidget {
  const FlagInfoScreen({super.key, required this.flagId});
  final String flagId;
  @override
  ConsumerState<FlagInfoScreen> createState() => _FlagInfoScreenState();
}

class _FlagInfoScreenState extends ConsumerState<FlagInfoScreen> {
  final _key = GlobalKey();

  Future<Uint8List?> _png() => captureBoundary(_key, pixelRatio: 4);

  Future<void> _save(
    Uint8List bytes,
    String name,
    String ext,
    String mime,
  ) async {
    final out = await ref
        .read(prismFileDialogServiceProvider)
        .saveBytes(
          bytes: bytes,
          suggestedName: '$name.$ext',
          allowedExtensions: [ext],
          mimeType: mime,
        );
    if (mounted)
      PrismToast.show(
        context,
        message: (out.pathOrUri != null || out.savedDisplayName != null)
            ? 'Saved'
            : 'Not saved',
      );
  }

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(flagByIdProvider(widget.flagId));
    if (f == null)
      return const PrismPageScaffold(
        topBar: PrismTopBar(title: 'Flag', showBackButton: true),
        body: Center(child: Text('This flag was deleted.')),
      );
    final theme = Theme.of(context);
    final names = ref.watch(memberNamesProvider);
    final a = ref.read(flagActionsProvider);
    final slug = f.name.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '-');
    final palette = f.design.palette;
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: f.name,
        showBackButton: true,
        actions: [
          IconButton(
            tooltip: f.favorite ? 'Unfavourite' : 'Favourite',
            icon: Icon(f.favorite ? Icons.star : Icons.star_border),
            onPressed: () => a.update(f.id, fields: {'favorite': !f.favorite}),
          ),
          PrismPopupMenu<String>(
            tooltip: 'More',
            onSelected: (v) async {
              if (v == 'dup') await a.duplicate(f);
              if (v == 'delete' &&
                  await PrismDialog.confirm(
                    context: context,
                    title: 'Delete “${f.name}”?',
                    confirmLabel: 'Delete',
                    destructive: true,
                  )) {
                await a.delete(f);
                if (context.mounted) Navigator.of(context).pop();
              }
            },
            items: const [
              PrismMenuItem(value: 'dup', label: 'Duplicate', icon: Icons.copy),
              PrismMenuItem(
                value: 'delete',
                label: 'Delete',
                icon: Icons.delete_outline,
                destructive: true,
              ),
            ],
          ),
        ],
      ),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + NavBarInset.of(context)),
          children: [
            Center(
              child: RepaintBoundary(
                key: _key,
                child: FlagView(design: f.design, width: 300, border: false),
              ),
            ),
            const SizedBox(height: 10),
            PrismButton(
              label: 'Edit design',
              icon: Icons.brush_outlined,
              tone: PrismButtonTone.filled,
              expanded: true,
              onPressed: () =>
                  pushPage<void>(context, FlagEditorScreen(flagId: f.id)),
            ),
            PrismSectionHeader(title: 'ABOUT'),
            PrismTextField(
              key: ValueKey('n${f.id}'),
              initialValue: f.name,
              labelText: 'Name',
              onChanged: (v) => a.update(f.id, name: v),
            ),
            const SizedBox(height: 8),
            PrismTextField(
              key: ValueKey('m${f.id}'),
              initialValue: f.meaning,
              labelText: 'What it means',
              maxLines: 4,
              onChanged: (v) => a.update(f.id, meaning: v),
            ),
            const SizedBox(height: 8),
            PrismTextField(
              key: ValueKey('c${f.id}'),
              initialValue: f.creator,
              labelText: 'Made by',
              onChanged: (v) => a.update(f.id, fields: {'creator': v}),
            ),
            const SizedBox(height: 8),
            PrismTextField(
              key: ValueKey('col${f.id}'),
              initialValue: f.collection,
              labelText: 'Collection',
              hintText: 'e.g. Identity, Subsystems, Just for fun',
              onChanged: (v) =>
                  a.update(f.id, fields: {'collection': v.trim()}),
            ),
            if (palette.isNotEmpty) ...[
              PrismSectionHeader(title: 'COLOURS'),
              for (final c in palette)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Color(c),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.black26),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: PrismTextField(
                          key: ValueKey('cm$c${f.id}'),
                          initialValue: f.colorMeanings['$c'] ?? '',
                          hintText: 'What this colour stands for',
                          onChanged: (v) => a.update(
                            f.id,
                            fields: {
                              'colorMeanings': {...f.colorMeanings, '$c': v},
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            PrismSectionHeader(title: 'WHO FLIES IT'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                PrismChip(
                  label: 'The whole system',
                  selected: f.assigned.contains('system'),
                  onTap: () => a.update(
                    f.id,
                    fields: {
                      'assigned': f.assigned.contains('system')
                          ? ([...f.assigned]..remove('system'))
                          : [...f.assigned, 'system'],
                    },
                  ),
                ),
                for (final n in names.entries)
                  PrismChip(
                    label: n.value,
                    selected: f.assigned.contains(n.key),
                    onTap: () => a.update(
                      f.id,
                      fields: {
                        'assigned': f.assigned.contains(n.key)
                            ? ([...f.assigned]..remove(n.key))
                            : [...f.assigned, n.key],
                      },
                    ),
                  ),
              ],
            ),
            PrismSectionHeader(title: 'PREVIEWS'),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                WavingFlag(design: f.design, width: 170),
                Column(
                  children: [
                    ClipOval(
                      child: SizedBox(
                        width: 64,
                        height: 64,
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: FlagView(
                            design: f.design,
                            width: 110,
                            border: false,
                          ),
                        ),
                      ),
                    ),
                    Text('Badge', style: theme.textTheme.labelSmall),
                  ],
                ),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: FlagView(design: f.design, width: 56),
                    ),
                    Text('Pin', style: theme.textTheme.labelSmall),
                  ],
                ),
                Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 220,
                        height: 50,
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: FlagView(
                            design: f.design,
                            width: 220,
                            border: false,
                          ),
                        ),
                      ),
                    ),
                    Text('Profile banner', style: theme.textTheme.labelSmall),
                  ],
                ),
              ],
            ),
            PrismSectionHeader(title: 'EXPORT'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PrismButton(
                  label: 'PNG',
                  icon: Icons.image_outlined,
                  density: PrismControlDensity.compact,
                  onPressed: () async {
                    final b = await _png();
                    if (b != null) await _save(b, slug, 'png', 'image/png');
                  },
                ),
                PrismButton(
                  label: 'WebP',
                  icon: Icons.image_outlined,
                  density: PrismControlDensity.compact,
                  onPressed: () async {
                    final b = await _png();
                    if (b == null) return;
                    final decoded = img.decodePng(b);
                    if (decoded == null) return;
                    await _save(
                      Uint8List.fromList(img.encodeWebP(decoded)),
                      slug,
                      'webp',
                      'image/webp',
                    );
                  },
                ),
                PrismButton(
                  label: 'SVG',
                  icon: Icons.polyline_outlined,
                  density: PrismControlDensity.compact,
                  onPressed: () => _save(
                    Uint8List.fromList(
                      utf8.encode(exportFlagSvg(f.design, title: f.name)),
                    ),
                    slug,
                    'svg',
                    'image/svg+xml',
                  ),
                ),
                PrismButton(
                  label: 'Project file',
                  icon: Icons.save_alt,
                  density: PrismControlDensity.compact,
                  onPressed: () => _save(
                    Uint8List.fromList(
                      utf8.encode(
                        const JsonEncoder.withIndent('  ').convert({
                          'format': 'prism.flag',
                          'v': 1,
                          'name': f.name,
                          'meaning': f.meaning,
                          'creator': f.creator,
                          'colorMeanings': f.colorMeanings,
                          'design': f.design.toJson(),
                        }),
                      ),
                    ),
                    slug,
                    'json',
                    'application/json',
                  ),
                ),
              ],
            ),
            if (f.design.layers.any((l) => l.kind == 'image'))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Image layers are included in PNG/WebP, but not in SVG.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Small strip of flags assigned to someone (profile).
class FlagStrip extends ConsumerWidget {
  const FlagStrip({super.key, required this.owner});
  final String owner;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(flagsForProvider(owner));
    if (flags.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final f in flags)
            Tooltip(
              message: f.name,
              child: GestureDetector(
                onTap: () =>
                    pushPage<void>(context, FlagInfoScreen(flagId: f.id)),
                child: FlagView(design: f.design, width: 54),
              ),
            ),
        ],
      ),
    );
  }
}
