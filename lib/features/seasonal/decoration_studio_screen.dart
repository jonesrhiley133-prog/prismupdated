import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/experiences/color_sheet.dart';
import 'package:prism_plurality/features/scrapbook/scrap_textures.dart';
import 'package:prism_plurality/features/seasonal/decor_assets.dart';
import 'package:prism_plurality/features/seasonal/decor_models.dart';
import 'package:prism_plurality/features/seasonal/living_environment.dart';
import 'package:prism_plurality/features/seasonal/living_screens.dart';
import 'package:prism_plurality/features/seasonal/decor_painter.dart';
import 'package:prism_plurality/features/seasonal/decor_preview.dart';
import 'package:prism_plurality/features/seasonal/decor_presets_screen.dart'
    show decorPages;
import 'package:prism_plurality/features/seasonal/seasonal_catalog.dart';
import 'package:prism_plurality/features/seasonal/seasonal_models.dart';
import 'package:prism_plurality/features/seasonal/seasonal_providers.dart';
import 'package:prism_plurality/features/social/services/social_media.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/shared/media/prism_media.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/widgets/prism_spinner.dart';

enum _Tab { add, edit, layers, place, save }

String _uid() =>
    'd${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${math.Random().nextInt(1 << 16).toRadixString(36)}';

/// The Decoration Studio: decorate Prism almost as freely as a room.
///
/// Drag, pinch and twist decorations on a live preview of Prism's own
/// layout; give each one its own colour, motion, place and pages; keep
/// separate positions for phones, tablets and desktops; group, lock and
/// layer them; undo and redo; and save the result as an arrangement. A draft
/// is kept as you go.
class DecorationStudioScreen extends ConsumerStatefulWidget {
  const DecorationStudioScreen({super.key, this.seed});

  /// null: continue the draft · `preset:<id>`: edit that arrangement ·
  /// anything else: a look id to pick parts from.
  final String? seed;

  @override
  ConsumerState<DecorationStudioScreen> createState() =>
      _DecorationStudioScreenState();
}

class _DecorationStudioScreenState
    extends ConsumerState<DecorationStudioScreen> {
  List<DecorItem> _items = [];
  DecoLayerSettings _layers = const DecoLayerSettings(maxAnimated: 30);
  final _sel = <String>{};
  DeviceClass _device = DeviceClass.mobile;
  _Tab _tab = _Tab.add;
  bool _multi = false, _snap = true, _lightsOn = true, _loaded = false;
  final _undo = <String>[];
  final _redo = <String>[];
  String? _presetId;
  final _name = TextEditingController();
  final _desc = TextEditingController();
  String _category = 'My arrangements';
  final _emoji = TextEditingController();
  final _previewKey = GlobalKey();
  Timer? _draftTimer;
  final Map<String, ui.Image> _images = {};
  final Set<String> _loadingImgs = {};
  String _lookCollection = 'christmas';
  int _lookIndex = 0;
  // Gesture state
  double _startW = 0, _startRot = 0;
  Offset? _guide;

  String get _snapshot => jsonEncode([for (final i in _items) i.toJson()]);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _flushDraft();
    _draftTimer?.cancel();
    _name.dispose();
    _desc.dispose();
    _emoji.dispose();
    for (final i in _images.values) {
      i.dispose();
    }
    super.dispose();
  }

  TrackerRecord? get _draftRecord =>
      (ref.read(trackerKindProvider(TrackerKind.seasonWorkspace)).value ??
              const <TrackerRecord>[])
          .firstOrNull;

  void _load() {
    _tracker = ref.read(trackerNotifierProvider.notifier);
    _draft = _draftRecord;
    final seed = widget.seed;
    if (seed != null && seed.startsWith('preset:')) {
      final id = seed.substring(7);
      final p = ref
          .read(decorPresetsProvider)
          .where((x) => x.id == id)
          .firstOrNull;
      if (p != null) {
        _items = [for (final i in p.items) DecorItem.fromJson(i.toJson())!];
        _layers = p.layers;
        _presetId = p.id;
        _name.text = p.name;
        _desc.text = p.description;
        _category = p.category;
      }
    } else {
      final d = _draftRecord;
      if (d != null) {
        _items = [
          if (d.fields['items'] is List)
            for (final i in d.fields['items'] as List) ?DecorItem.fromJson(i),
        ];
        _layers = DecoLayerSettings.fromJson(d.fields['layers']);
      }
      if (seed != null && seed.startsWith('asset:')) {
        final a = decorAssetById(seed.substring(6));
        if (a != null) {
          final it = decorItemForAsset(a, _uid(), variationId: _look.id);
          it.z = _topZ;
          _items.add(it);
          _sel
            ..clear()
            ..add(it.id);
        }
      } else if (seed != null) {
        final v = variationById(seed);
        if (v != null) {
          _lookCollection = v.collectionId;
          _lookIndex = v.index;
          _tab = _Tab.add;
        }
      }
    }
    _loadImages();
    setState(() => _loaded = true);
  }

  // ── Draft ───────────────────────────────────────────────────────────

  void _scheduleDraft() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 900), _flushDraft);
  }

  // Held so the draft can still be written while the screen is closing,
  // when reading providers is no longer allowed.
  TrackerNotifier? _tracker;
  TrackerRecord? _draft;

  Future<void> _flushDraft() async {
    final t = _tracker;
    if (!_loaded ||
        t == null ||
        (widget.seed != null && widget.seed!.startsWith('preset:')))
      return;
    final fields = <String, Object?>{
      'items': [for (final i in _items) i.toJson()],
      'layers': _layers.toJson(),
    };
    final d = _draft;
    if (d == null) {
      if (_items.isEmpty) return;
      _draft = await t.create(
        kind: TrackerKind.seasonWorkspace,
        title: 'Studio draft',
        fields: fields,
      );
    } else {
      final next = d.withFields(fields);
      await t.save(next);
      _draft = next;
    }
  }

  // ── History ─────────────────────────────────────────────────────────

  void _push() {
    _undo.add(_snapshot);
    if (_undo.length > 60) _undo.removeAt(0);
    _redo.clear();
  }

  void _restore(String snap) {
    final list = jsonDecode(snap) as List;
    _items = [for (final i in list) ?DecorItem.fromJson(i)];
    _sel.removeWhere((id) => !_items.any((i) => i.id == id));
    _loadImages();
  }

  void _undoNow() {
    if (_undo.isEmpty) return;
    _redo.add(_snapshot);
    setState(() => _restore(_undo.removeLast()));
    _scheduleDraft();
  }

  void _redoNow() {
    if (_redo.isEmpty) return;
    _undo.add(_snapshot);
    setState(() => _restore(_redo.removeLast()));
    _scheduleDraft();
  }

  /// Applies [change] as one undoable step.
  void _edit(void Function() change) {
    _push();
    setState(change);
    _scheduleDraft();
  }

  void _loadImages() {
    for (final i in _items) {
      final id = i.image;
      if (id == null || _images.containsKey(id) || !_loadingImgs.add(id))
        continue;
      final bytes = ref.read(socialImageProvider(id));
      if (bytes == null) {
        _loadingImgs.remove(id);
        continue;
      }
      ui.decodeImageFromList(bytes, (img) {
        if (!mounted) {
          img.dispose();
          return;
        }
        setState(() => _images[id] = img);
      });
    }
  }

  // ── Selection and gestures ──────────────────────────────────────────

  List<DecorItem> get _selected => [
    for (final i in _items)
      if (_sel.contains(i.id)) i,
  ];

  Set<String> _withGroup(Iterable<DecorItem> items) {
    final out = <String>{};
    for (final i in items) {
      out.add(i.id);
      if (i.group != null)
        out.addAll([
          for (final o in _items)
            if (o.group == i.group) o.id,
        ]);
    }
    return out;
  }

  DecorScene _scene(Size size) => DecorPreview.sceneFor(
    items: _items,
    layers: _layers,
    device: _device,
    size: size,
    lightsOn: _lightsOn,
    images: _images,
  );

  DecorItem? _hit(Offset p, Size size) {
    final scene = _scene(size);
    final order = [..._items]..sort((a, b) => b.z.compareTo(a.z));
    for (final i in order) {
      if (!i.enabled ||
          i.kind == DecoKind.border ||
          i.kind == DecoKind.particles)
        continue;
      if (decorItemBounds(i, size, scene).inflate(6).contains(p)) return i;
    }
    return null;
  }

  void _tap(Offset p, Size size) {
    final hit = _hit(p, size);
    setState(() {
      if (hit == null) {
        if (!_multi) _sel.clear();
      } else if (_multi) {
        _sel.contains(hit.id)
            ? _sel.removeAll(_withGroup([hit]))
            : _sel.addAll(_withGroup([hit]));
      } else {
        _sel
          ..clear()
          ..addAll(_withGroup([hit]));
      }
    });
  }

  bool _gestureStarted = false;

  void _scaleStart(ScaleStartDetails d, Size size) {
    final hit = _hit(d.localFocalPoint, size);
    if (hit != null && !_sel.contains(hit.id)) {
      setState(
        () => _sel
          ..clear()
          ..addAll(_withGroup([hit])),
      );
    }
    final sel = _selected;
    _gestureStarted = false;
    if (sel.length == 1) {
      _startW = sel.first.w;
      _startRot = sel.first.rot;
    }
  }

  void _scaleUpdate(ScaleUpdateDetails d, Size size) {
    final sel = _selected.where((i) => !i.locked).toList();
    if (sel.isEmpty) return;
    if (!_gestureStarted) {
      _push();
      _gestureStarted = true;
    }
    final scene = _scene(size);
    final painter = DecorPainter(scene: scene, t: 0, layersToDraw: const {});
    setState(() {
      for (final i in sel) {
        final frame = painter.frameFor(i.anchor, size);
        if (frame == null || frame.width == 0 || frame.height == 0) continue;
        final dx = d.focalPointDelta.dx / frame.width,
            dy = d.focalPointDelta.dy / frame.height;
        if (_device == DeviceClass.mobile) {
          i.x = (i.x + dx).clamp(-0.2, 1.2);
          i.y = (i.y + dy).clamp(-0.2, 1.2);
        } else {
          final t = i.tweakFor(_device);
          i.tweaks[_device.name] = DeviceTweak(
            dx: (t.dx + dx).clamp(-1.0, 1.0),
            dy: (t.dy + dy).clamp(-1.0, 1.0),
            scale: t.scale,
            hidden: t.hidden,
          );
        }
        if (sel.length == 1) {
          if (d.pointerCount >= 2) {
            if (_device == DeviceClass.mobile) {
              i.w = (_startW * d.scale).clamp(0.02, 1.5);
            } else {
              final t = i.tweakFor(_device);
              i.tweaks[_device.name] = DeviceTweak(
                dx: t.dx,
                dy: t.dy,
                scale: (t.scale * (1 + (d.scale - 1) * 0.08)).clamp(0.2, 4.0),
                hidden: t.hidden,
              );
            }
            i.rot = (_startRot + d.rotation * 180 / math.pi) % 360;
            if (i.rot > 180) i.rot -= 360;
          } else if (_snap) {
            // Gentle snapping to the centre lines, with a guide while close.
            final nearX =
                (i.x - 0.5).abs() < 0.012 && _device == DeviceClass.mobile;
            final nearY =
                (i.y - 0.5).abs() < 0.012 && _device == DeviceClass.mobile;
            if (nearX) i.x = 0.5;
            if (nearY) i.y = 0.5;
            _guide = Offset(nearX ? 0.5 : -1, nearY ? 0.5 : -1);
          }
        }
      }
    });
  }

  void _scaleEnd() {
    if (_gestureStarted) _scheduleDraft();
    setState(() => _guide = null);
  }

  // ── Adding ──────────────────────────────────────────────────────────

  int get _topZ => _items.fold(0, (a, i) => math.max(a, i.z)) + 1;

  void _add(DecorItem i) {
    _edit(() {
      i.z = _topZ;
      _items.add(i);
      _sel
        ..clear()
        ..add(i.id);
    });
  }

  SeasonalVariation get _look =>
      collectionById(_lookCollection)!.variations[_lookIndex.clamp(
        0,
        collectionById(_lookCollection)!.variations.length - 1,
      )];

  void _addPart(String part) {
    final v = _look;
    final all = arrangementForVariation(v);
    List<DecorItem> pick(bool Function(DecorItem) t) => [
      for (final i in all)
        if (t(i)) DecorItem.fromJson({...i.toJson(), 'id': _uid()})!,
    ];
    final parts = switch (part) {
      'garland' => pick((i) => i.kind == DecoKind.garland),
      'lights' => pick((i) => i.kind == DecoKind.fairyLights),
      'corners' => pick((i) => i.kind == DecoKind.corner),
      'border' => pick((i) => i.kind == DecoKind.border),
      'ornaments' => pick((i) => i.kind == DecoKind.ornament),
      'furniture' => pick((i) => i.kind == DecoKind.furniture),
      'particles' => pick((i) => i.kind == DecoKind.particles),
      'toy' => pick((i) => i.kind == DecoKind.interactive),
      _ => pick((_) => true),
    };
    if (parts.isEmpty) {
      PrismToast.show(
        context,
        message: tr(
          context,
          '${v.name} has no ${part}.',
          '${v.name} no tiene ese elemento.',
        ),
      );
      return;
    }
    _edit(() {
      for (final i in parts) {
        i.z = _topZ;
        _items.add(i);
      }
      _sel
        ..clear()
        ..addAll(parts.map((e) => e.id));
    });
  }

  void _addKind(DecoKind kind, {String? glyph}) {
    final v = _look;
    _add(
      DecorItem(
        id: _uid(),
        kind: kind,
        variationId: v.id,
        glyph:
            glyph ??
            switch (kind) {
              DecoKind.flower => '🌷',
              DecoKind.illustration => v.icons.first,
              DecoKind.furniture => v.furniture.first,
              DecoKind.interactive => v.hangers.first,
              DecoKind.ornament => v.hangers.first,
              _ => null,
            },
        anchor: switch (kind) {
          DecoKind.lantern || DecoKind.ornament => DecoAnchor.top,
          DecoKind.ribbon => DecoAnchor.top,
          _ => DecoAnchor.screen,
        },
        x: 0.5,
        y: kind == DecoKind.lantern || kind == DecoKind.ornament ? 0.1 : 0.5,
        w: switch (kind) {
          DecoKind.ribbon => 1.0,
          DecoKind.lantern => 0.1,
          DecoKind.ornament => 0.08,
          DecoKind.window => 0.28,
          DecoKind.wreath => 0.3,
          DecoKind.bow => 0.2,
          _ => 0.14,
        },
      ),
    );
  }

  Future<void> _addPicture() async {
    final id = await PrismMedia.pickImage(ref);
    if (id == null || !mounted) return;
    _add(DecorItem(id: _uid(), kind: DecoKind.sticker, image: id, w: 0.3));
    _loadImages();
  }

  // ── Selection actions ───────────────────────────────────────────────

  void _duplicate() {
    final copies = [for (final i in _selected) i.copy(newId: _uid())];
    if (copies.isEmpty) return;
    _edit(() {
      for (final c in copies) {
        c.z = _topZ;
        c.locked = false;
        _items.add(c);
      }
      _sel
        ..clear()
        ..addAll(copies.map((e) => e.id));
    });
  }

  void _delete() => _edit(() {
    _items.removeWhere((i) => _sel.contains(i.id) && !i.locked);
    _sel.clear();
  });

  void _group() {
    if (_sel.length < 2) return;
    final g = _uid();
    _edit(() {
      for (final i in _selected) {
        i.group = g;
      }
    });
  }

  void _ungroup() => _edit(() {
    for (final i in _selected) {
      i.group = null;
    }
  });

  void _lock(bool v) => _edit(() {
    for (final i in _selected) {
      i.locked = v;
    }
  });

  void _order(int dir) => _edit(() {
    for (final i in _selected) {
      i.z += dir;
    }
  });

  // ── Saving ──────────────────────────────────────────────────────────

  Future<String?> _thumbnail() async {
    try {
      final b = _previewKey.currentContext?.findRenderObject();
      if (b is! RenderRepaintBoundary) return null;
      final img = await b.toImage(pixelRatio: 0.6);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return null;
      final bytes = data.buffer.asUint8List();
      return bytes.length > 150000 ? null : base64Encode(bytes);
    } catch (_) {
      return null;
    }
  }

  Future<void> _save({required bool asNew, bool useNow = false}) async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      PrismToast.error(
        context,
        message: tr(
          context,
          'Give it a name first.',
          'Ponle un nombre primero.',
        ),
      );
      setState(() => _tab = _Tab.save);
      return;
    }
    final thumb = await _thumbnail();
    final preset = DecorPreset(
      id: asNew ? '' : (_presetId ?? ''),
      name: name,
      description: _desc.text.trim(),
      category: _category.trim().isEmpty ? 'My arrangements' : _category.trim(),
      items: [for (final i in _items) DecorItem.fromJson(i.toJson())!],
      layers: _layers,
      thumbnail: thumb,
    );
    final actions = ref.read(decorPresetActionsProvider);
    String id;
    if (asNew || _presetId == null) {
      id = await actions.create(preset);
    } else {
      await actions.update(preset);
      id = _presetId!;
    }
    _presetId = id;
    if (useNow) {
      ref
          .read(seasonalPrefsProvider.notifier)
          .update(
            (p) => p.copyWith(
              activePresetId: id,
              performance: p.performance == DecoPerformance.off
                  ? DecoPerformance.balanced
                  : p.performance,
            ),
          );
    }
    if (mounted)
      PrismToast.success(
        context,
        message: tr(
          context,
          '$name saved${useNow ? ' and on' : ''}',
          '$name guardado${useNow ? ' y activo' : ''}',
        ),
      );
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = Localizations.localeOf(context).languageCode == 'es';
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(context, 'Decoration Studio', 'Estudio de decoración'),
        showBackButton: true,
        actions: [
          IconButton(
            tooltip: tr(context, 'Undo', 'Deshacer'),
            icon: const Icon(Icons.undo),
            onPressed: _undo.isEmpty ? null : _undoNow,
          ),
          IconButton(
            tooltip: tr(context, 'Redo', 'Rehacer'),
            icon: const Icon(Icons.redo),
            onPressed: _redo.isEmpty ? null : _redoNow,
          ),
        ],
      ),
      bodyPadding: EdgeInsets.zero,
      body: !_loaded
          ? Center(
              child: PrismSpinner(color: Theme.of(context).colorScheme.primary),
            )
          : Column(
              children: [
                // Device tabs and tools
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final d in DeviceClass.values)
                        PrismChip(
                          label: switch (d) {
                            DeviceClass.mobile => tr(
                              context,
                              'Phone',
                              'Teléfono',
                            ),
                            DeviceClass.tablet => tr(
                              context,
                              'Tablet',
                              'Tableta',
                            ),
                            DeviceClass.desktop => tr(
                              context,
                              'Desktop',
                              'Escritorio',
                            ),
                          },
                          selected: _device == d,
                          onTap: () => setState(() => _device = d),
                        ),
                      PrismChip(
                        label: tr(context, 'Select several', 'Varios'),
                        selected: _multi,
                        onTap: () => setState(() => _multi = !_multi),
                      ),
                      PrismChip(
                        label: tr(context, 'Snap', 'Imán'),
                        selected: _snap,
                        onTap: () => setState(() => _snap = !_snap),
                      ),
                      PrismChip(
                        label: tr(context, 'Lights', 'Luces'),
                        selected: _lightsOn,
                        onTap: () => setState(() => _lightsOn = !_lightsOn),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final maxW = switch (_device) {
                        DeviceClass.mobile => 300.0,
                        DeviceClass.tablet => 560.0,
                        DeviceClass.desktop => 760.0,
                      };
                      var w = math.min(box.maxWidth - 24, maxW);
                      var h = DecorPreview.heightFor(_device, w);
                      if (h > box.maxHeight - 8) {
                        h = box.maxHeight - 8;
                        w = h / (DecorPreview.heightFor(_device, 1));
                      }
                      final size = Size(w, h);
                      return Center(
                        child: Stack(
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapUp: (d) => _tap(d.localPosition, size),
                              onScaleStart: (d) => _scaleStart(d, size),
                              onScaleUpdate: (d) => _scaleUpdate(d, size),
                              onScaleEnd: (_) => _scaleEnd(),
                              child: RepaintBoundary(
                                key: _previewKey,
                                child: _AnimatedPreview(
                                  items: _items,
                                  layers: _layers,
                                  device: _device,
                                  width: w,
                                  height: h,
                                  selected: _sel,
                                  lightsOn: _lightsOn,
                                  images: _images,
                                ),
                              ),
                            ),
                            if (_guide != null)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _GuidePainter(
                                      _guide!,
                                      theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (final t in _Tab.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: PrismChip(
                            label: switch (t) {
                              _Tab.add => tr(context, 'Add', 'Añadir'),
                              _Tab.edit => tr(context, 'Style', 'Estilo'),
                              _Tab.layers => tr(context, 'Layers', 'Capas'),
                              _Tab.place => tr(context, 'Place', 'Lugar'),
                              _Tab.save => tr(context, 'Save', 'Guardar'),
                            },
                            selected: _tab == t,
                            onTap: () => setState(() => _tab = t),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      4,
                      16,
                      24 + NavBarInset.of(context),
                    ),
                    children: switch (_tab) {
                      _Tab.add => _addPanel(context, l),
                      _Tab.edit => _editPanel(context),
                      _Tab.layers => _layersPanel(context, l),
                      _Tab.place => _placePanel(context),
                      _Tab.save => _savePanel(context),
                    },
                  ),
                ),
              ],
            ),
    );
  }

  // ── Panels ──────────────────────────────────────────────────────────

  List<Widget> _addPanel(BuildContext context, bool l) {
    final col = collectionById(_lookCollection)!;
    return [
      Text(
        tr(
          context,
          'Take parts from any look — mix Christmas lights with autumn leaves and gothic borders.',
          'Toma partes de cualquier estilo: mezcla luces navideñas con hojas de otoño y bordes góticos.',
        ),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      PrismSelect<String>(
        labelText: tr(context, 'Collection', 'Colección'),
        value: _lookCollection,
        items: [
          for (final c in seasonalCollections)
            PrismSelectItem(value: c.id, label: '${c.emoji} ${c.name}'),
          for (final c in livingCollections)
            PrismSelectItem(
              value: c.id,
              label: '${c.emoji} ${c.name} · ${tr(context, 'living', 'vivo')}',
            ),
        ],
        onChanged: (v) => setState(() {
          _lookCollection = v ?? _lookCollection;
          _lookIndex = 0;
        }),
      ),
      const SizedBox(height: 8),
      PrismSelect<int>(
        labelText: tr(context, 'Look', 'Estilo'),
        value: _lookIndex.clamp(0, col.variations.length - 1),
        items: [
          for (final v in col.variations)
            PrismSelectItem(value: v.index, label: v.name),
        ],
        onChanged: (v) => setState(() => _lookIndex = v ?? 0),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final p in [
            ('garland', 'Garland', 'Guirnalda'),
            ('lights', 'Fairy lights', 'Luces'),
            ('corners', 'Corners', 'Esquinas'),
            ('border', 'Border', 'Borde'),
            ('ornaments', 'Hanging ornaments', 'Adornos colgantes'),
            ('furniture', 'Furniture', 'Muebles'),
            ('particles', 'Falling things', 'Cosas que caen'),
            ('toy', 'Interactive toy', 'Juguete interactivo'),
            ('all', 'The whole look', 'El estilo completo'),
          ])
            PrismButton(
              label: l ? p.$3 : p.$2,
              icon: Icons.add,
              density: PrismControlDensity.compact,
              tone: p.$1 == 'all'
                  ? PrismButtonTone.filled
                  : PrismButtonTone.outlined,
              onPressed: () => _addPart(p.$1),
            ),
        ],
      ),
      const SizedBox(height: 12),
      PrismButton(
        label: tr(
          context,
          'Asset library (${decorAssets.length})',
          'Biblioteca de elementos (${decorAssets.length})',
        ),
        icon: Icons.category_outlined,
        tone: PrismButtonTone.filled,
        expanded: true,
        onPressed: () async {
          final a = await showDecorAssetPicker(context);
          if (a == null || !mounted) return;
          _add(decorItemForAsset(a, _uid(), variationId: _look.id));
        },
      ),
      const SizedBox(height: 12),
      Text(
        tr(context, 'Single decorations', 'Decoraciones sueltas'),
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final k in [
            DecoKind.ribbon,
            DecoKind.bow,
            DecoKind.lantern,
            DecoKind.wreath,
            DecoKind.ornament,
            DecoKind.window,
            DecoKind.flower,
            DecoKind.candle,
            DecoKind.foliage,
            DecoKind.illustration,
            DecoKind.furniture,
            DecoKind.interactive,
          ])
            PrismChip(
              label: k.label,
              selected: false,
              onTap: () => _addKind(k),
            ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          SizedBox(
            width: 90,
            child: PrismTextField(controller: _emoji, hintText: '🎄'),
          ),
          const SizedBox(width: 8),
          PrismButton(
            label: tr(context, 'Add emoji', 'Añadir emoji'),
            icon: Icons.add_reaction_outlined,
            tone: PrismButtonTone.outlined,
            onPressed: () {
              final g = _emoji.text.trim();
              if (g.isEmpty) return;
              _addKind(DecoKind.illustration, glyph: g.characters.first);
              _emoji.clear();
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: PrismButton(
              label: tr(context, 'My picture', 'Mi imagen'),
              icon: Icons.image_outlined,
              tone: PrismButtonTone.outlined,
              onPressed: _addPicture,
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _editPanel(BuildContext context) {
    final sel = _selected;
    if (sel.isEmpty)
      return [
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            tr(
              context,
              'Tap something on the preview to style it. Drag to move; pinch and twist to resize and rotate.',
              'Toca algo en la vista previa para darle estilo. Arrastra para mover; pellizca y gira para cambiar tamaño y rotación.',
            ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ];
    final i = sel.first;
    final many = sel.length > 1;
    final theme = Theme.of(context);
    Widget slider(
      String label,
      double v,
      double min,
      double max,
      String Function(double) fmt,
      void Function(double) on,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
            Text(fmt(v), style: theme.textTheme.labelMedium),
          ],
        ),
        Slider(
          value: v.clamp(min, max),
          min: min,
          max: max,
          onChangeStart: (_) => _push(),
          onChanged: (x) => setState(() => on(x)),
          onChangeEnd: (_) => _scheduleDraft(),
        ),
      ],
    );
    void all(void Function(DecorItem) f) {
      for (final x in sel) {
        if (!x.locked) f(x);
      }
    }

    return [
      Text(
        many
            ? '${sel.length} ${tr(context, 'selected', 'seleccionados')}'
            : i.kind.label,
        style: theme.textTheme.titleMedium,
      ),
      if (sel.every((x) => x.locked))
        Text(
          tr(
            context,
            'Locked — unlock it in Layers to change it.',
            'Bloqueado: desbloquéalo en Capas para cambiarlo.',
          ),
          style: theme.textTheme.bodySmall,
        ),
      slider(
        tr(context, 'Size', 'Tamaño'),
        i.w,
        0.02,
        1.5,
        (v) => '${(v * 100).round()}%',
        (v) => all((x) => x.w = v),
      ),
      slider(
        tr(context, 'Rotation', 'Rotación'),
        i.rot,
        -180,
        180,
        (v) => '${v.round()}°',
        (v) => all((x) => x.rot = v.roundToDouble()),
      ),
      slider(
        tr(context, 'Opacity', 'Opacidad'),
        i.opacity,
        0.05,
        1,
        (v) => '${(v * 100).round()}%',
        (v) => all((x) => x.opacity = v),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          PrismButton(
            label: tr(context, 'Colour', 'Color'),
            icon: Icons.palette_outlined,
            tone: PrismButtonTone.outlined,
            density: PrismControlDensity.compact,
            onPressed: () async {
              final c = await showPrismColorPicker(
                context: context,
                initial: Color(i.color ?? 0xFFB07CC6),
                title: tr(context, 'Colour', 'Color'),
              );
              if (c != null) _edit(() => all((x) => x.color = c.toARGB32()));
            },
          ),
          PrismButton(
            label: i.color2 == null
                ? tr(context, 'Gradient', 'Degradado')
                : tr(context, 'Change gradient', 'Cambiar degradado'),
            icon: Icons.gradient,
            tone: PrismButtonTone.outlined,
            density: PrismControlDensity.compact,
            onPressed: () async {
              final c = await showPrismColorPicker(
                context: context,
                initial: Color(i.color2 ?? 0xFFFFC857),
                title: tr(context, 'Second colour', 'Segundo color'),
              );
              if (c != null) _edit(() => all((x) => x.color2 = c.toARGB32()));
            },
          ),
          if (i.color != null || i.color2 != null)
            PrismButton(
              label: tr(
                context,
                'Back to the look\'s colours',
                'Volver a los colores del estilo',
              ),
              density: PrismControlDensity.compact,
              tone: PrismButtonTone.outlined,
              onPressed: () => _edit(
                () => all((x) {
                  x.color = null;
                  x.color2 = null;
                }),
              ),
            ),
          PrismChip(
            label: tr(context, 'Flip ↔', 'Voltear ↔'),
            selected: i.flipX,
            onTap: () => _edit(() => all((x) => x.flipX = !x.flipX)),
          ),
          PrismChip(
            label: tr(context, 'Flip ↕', 'Voltear ↕'),
            selected: i.flipY,
            onTap: () => _edit(() => all((x) => x.flipY = !x.flipY)),
          ),
        ],
      ),
      if (!many &&
          {
            DecoKind.illustration,
            DecoKind.furniture,
            DecoKind.ornament,
            DecoKind.interactive,
            DecoKind.flower,
          }.contains(i.kind)) ...[
        const SizedBox(height: 10),
        Row(
          children: [
            SizedBox(
              width: 90,
              child: PrismTextField(
                key: ValueKey('g-${i.id}'),
                initialValue: i.glyph ?? '',
                onChanged: (v) {
                  final g = v.trim();
                  if (g.isNotEmpty) _edit(() => i.glyph = g.characters.first);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tr(context, 'The symbol shown', 'El símbolo mostrado'),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
      const SizedBox(height: 6),
      Text(
        tr(context, 'Motion', 'Movimiento'),
        style: theme.textTheme.titleSmall,
      ),
      slider(
        tr(context, 'Animation speed', 'Velocidad'),
        i.speed,
        0.2,
        3,
        (v) => '${v.toStringAsFixed(1)}×',
        (v) => all((x) => x.speed = v),
      ),
      slider(
        tr(context, 'How often (twinkle, falling)', 'Con qué frecuencia'),
        i.frequency,
        0,
        1,
        (v) => '${(v * 100).round()}%',
        (v) => all((x) => x.frequency = v),
      ),
      PrismSwitchRow(
        title: tr(context, 'Show this decoration', 'Mostrar esta decoración'),
        value: i.enabled,
        onChanged: (v) => _edit(() => all((x) => x.enabled = v)),
      ),
      const SizedBox(height: 6),
      Text(tr(context, 'Finish', 'Acabado'), style: theme.textTheme.titleSmall),
      slider(
        tr(context, 'Shadow', 'Sombra'),
        i.shadow,
        0,
        1,
        (v) => '${(v * 100).round()}%',
        (v) => all((x) => x.shadow = v),
      ),
      slider(
        tr(context, 'Outline thickness', 'Grosor del contorno'),
        i.outline,
        0,
        8,
        (v) => '${v.toStringAsFixed(1)} px',
        (v) => all((x) => x.outline = v),
      ),
      PrismSelect<String>(
        labelText: tr(context, 'Texture', 'Textura'),
        value: i.texture ?? '',
        items: [
          PrismSelectItem(value: '', label: tr(context, 'None', 'Ninguna')),
          for (final t in scrapTextures)
            PrismSelectItem(value: t.id, label: t.name),
        ],
        onChanged: (v) => _edit(
          () => all((x) => x.texture = v == null || v.isEmpty ? null : v),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        tr(context, 'Placement', 'Colocación'),
        style: theme.textTheme.titleSmall,
      ),
      PrismSwitchRow(
        title: tr(context, 'Moves with the page', 'Se mueve con la página'),
        subtitle: tr(
          context,
          'Scrolls along with what\'s on screen instead of staying fixed.',
          'Se desplaza con el contenido en lugar de quedarse fijo.',
        ),
        value: i.scroll,
        onChanged: (v) => _edit(() => all((x) => x.scroll = v)),
      ),
      if (i.anchor == DecoAnchor.screen)
        PrismSwitchRow(
          title: tr(
            context,
            'Keep clear of notches and system bars',
            'Evitar muescas y barras del sistema',
          ),
          value: i.safeArea,
          onChanged: (v) => _edit(() => all((x) => x.safeArea = v)),
        ),
      const SizedBox(height: 6),
      Text(
        tr(context, 'Living behaviour', 'Comportamiento vivo'),
        style: theme.textTheme.titleSmall,
      ),
      PrismSelect<String>(
        labelText: tr(context, 'How it moves', 'Cómo se mueve'),
        value: i.behavior ?? 'none',
        items: [
          for (final b in AssetBehavior.values)
            PrismSelectItem(value: b.name, label: _behaviorLabel(context, b)),
        ],
        onChanged: (v) => _edit(
          () => all((x) => x.behavior = v == null || v == 'none' ? null : v),
        ),
      ),
      if (i.behavior != null) ...[
        slider(
          tr(context, 'Movement range', 'Alcance del movimiento'),
          i.range,
          0,
          0.6,
          (v) => '${(v * 100).round()}%',
          (v) => all((x) => x.range = v),
        ),
        slider(
          tr(context, 'Direction', 'Dirección'),
          i.direction,
          0,
          359,
          (v) => '${v.round()}°',
          (v) => all((x) => x.direction = v.roundToDouble()),
        ),
        PrismSwitchRow(
          title: tr(context, 'Animate', 'Animar'),
          subtitle: tr(
            context,
            'Off keeps it on screen, still.',
            'Apagado lo deja quieto en pantalla.',
          ),
          value: i.animate,
          onChanged: (v) => _edit(() => all((x) => x.animate = v)),
        ),
      ],
      PrismSelect<String>(
        labelText: tr(context, 'When idle', 'En reposo'),
        value: i.idle,
        items: [
          PrismSelectItem(value: 'none', label: tr(context, 'Nothing', 'Nada')),
          PrismSelectItem(
            value: 'breathe',
            label: tr(context, 'Breathe gently', 'Respirar suave'),
          ),
          PrismSelectItem(
            value: 'peek',
            label: tr(context, 'Peek now and then', 'Asomarse a ratos'),
          ),
        ],
        onChanged: (v) => _edit(() => all((x) => x.idle = v ?? 'none')),
      ),
      const SizedBox(height: 8),
      PrismSelect<String>(
        labelText: tr(
          context,
          'With reduced motion',
          'Con movimiento reducido',
        ),
        value: i.still,
        items: [
          PrismSelectItem(
            value: 'still',
            label: tr(context, 'Stay, without moving', 'Quedarse, sin moverse'),
          ),
          PrismSelectItem(value: 'hide', label: tr(context, 'Hide', 'Ocultar')),
        ],
        onChanged: (v) => _edit(() => all((x) => x.still = v ?? 'still')),
      ),
      PrismSwitchRow(
        title: tr(context, 'Tap to interact', 'Tocar para interactuar'),
        subtitle: tr(
          context,
          'A lamp switches, a book opens. Only turn on for things away from buttons.',
          'Una lámpara se enciende, un libro se abre. Úsalo lejos de los botones.',
        ),
        value: i.tap,
        onChanged: (v) => _edit(() => all((x) => x.tap = v)),
      ),
      if (i.tap) ...[
        slider(
          tr(context, 'Interaction sensitivity', 'Sensibilidad'),
          i.sensitivity,
          0,
          1,
          (v) => '${(v * 100).round()}%',
          (v) => all((x) => x.sensitivity = v),
        ),
        PrismSwitchRow(
          title: tr(context, 'Sound when tapped', 'Sonido al tocar'),
          value: i.sound,
          onChanged: (v) => _edit(() => all((x) => x.sound = v)),
        ),
      ],
      PrismSwitchRow(
        title: tr(
          context,
          'Companions react to it',
          'Los compañeros reaccionan',
        ),
        value: i.companion,
        onChanged: (v) => _edit(() => all((x) => x.companion = v)),
      ),
      const SizedBox(height: 4),
      Text(
        tr(context, 'Show during', 'Mostrar durante'),
        style: theme.textTheme.titleSmall,
      ),
      Text(
        tr(context, 'None selected = all day.', 'Ninguno = todo el día.'),
        style: theme.textTheme.bodySmall,
      ),
      const SizedBox(height: 4),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final ph in TimePhase.values)
            PrismChip(
              label: Localizations.localeOf(context).languageCode == 'es'
                  ? ph.es
                  : ph.en,
              selected: i.phases.contains(ph.name),
              onTap: () => _edit(
                () => all(
                  (x) => x.phases = x.phases.contains(ph.name)
                      ? [
                          for (final p in x.phases)
                            if (p != ph.name) p,
                        ]
                      : [...x.phases, ph.name],
                ),
              ),
            ),
        ],
      ),
    ];
  }

  static String _behaviorLabel(BuildContext context, AssetBehavior b) =>
      switch (b) {
        AssetBehavior.none => tr(context, 'Stays still', 'Quieto'),
        AssetBehavior.sway => tr(context, 'Sways', 'Se mece'),
        AssetBehavior.twinkle => tr(context, 'Twinkles', 'Titila'),
        AssetBehavior.bloom => tr(
          context,
          'Opens through the day',
          'Se abre con el día',
        ),
        AssetBehavior.toggle => tr(context, 'Switches on/off', 'Se enciende'),
        AssetBehavior.flicker => tr(context, 'Flickers', 'Parpadea'),
        AssetBehavior.open => tr(
          context,
          'Opens when tapped',
          'Se abre al tocar',
        ),
        AssetBehavior.play => tr(
          context,
          'Spins while music plays',
          'Gira con la música',
        ),
        AssetBehavior.bounce => tr(context, 'Bounces', 'Rebota'),
        AssetBehavior.walk => tr(context, 'Walks back and forth', 'Camina'),
        AssetBehavior.flutter => tr(context, 'Flutters', 'Revolotea'),
        AssetBehavior.swim => tr(context, 'Swims', 'Nada'),
        AssetBehavior.orbit => tr(context, 'Orbits', 'Orbita'),
        AssetBehavior.drift => tr(context, 'Drifts', 'Flota a la deriva'),
        AssetBehavior.fall => tr(context, 'Falls gently', 'Cae suave'),
        AssetBehavior.ripple => tr(context, 'Ripples', 'Ondula'),
        AssetBehavior.shimmer => tr(context, 'Shimmers', 'Brilla'),
        AssetBehavior.tick => tr(context, 'Shows the real time', 'Da la hora'),
        AssetBehavior.blink => tr(context, 'Blinks', 'Parpadea a ratos'),
        AssetBehavior.float => tr(context, 'Floats', 'Flota'),
        AssetBehavior.spin => tr(context, 'Spins', 'Gira'),
        AssetBehavior.move => tr(context, 'Moves along a track', 'Recorre'),
        AssetBehavior.steam => tr(context, 'Steams', 'Humea'),
        AssetBehavior.pulse => tr(context, 'Pulses', 'Late'),
        AssetBehavior.wave => tr(context, 'Waves', 'Saluda'),
      };

  List<Widget> _layersPanel(BuildContext context, bool l) {
    final theme = Theme.of(context);
    final sorted = [..._items]..sort((a, b) => b.z.compareTo(a.z));
    return [
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final lay in DecoLayer.values)
            PrismChip(
              label: l ? lay.es : lay.en,
              selected: _layers.on(lay),
              onTap: () {
                final set = {..._layers.enabled};
                _layers.on(lay) ? set.remove(lay) : set.add(lay);
                setState(() => _layers = _layers.copyWith(enabled: set));
                _scheduleDraft();
              },
            ),
        ],
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          PrismButton(
            label: tr(context, 'Select all', 'Todo'),
            density: PrismControlDensity.compact,
            tone: PrismButtonTone.outlined,
            onPressed: () =>
                setState(() => _sel.addAll(_items.map((i) => i.id))),
          ),
          PrismButton(
            label: tr(context, 'Duplicate', 'Duplicar'),
            icon: Icons.copy_outlined,
            density: PrismControlDensity.compact,
            tone: PrismButtonTone.outlined,
            onPressed: _sel.isEmpty ? () {} : _duplicate,
          ),
          PrismButton(
            label: tr(context, 'Group', 'Agrupar'),
            icon: Icons.group_work_outlined,
            density: PrismControlDensity.compact,
            tone: PrismButtonTone.outlined,
            onPressed: _sel.length < 2 ? () {} : _group,
          ),
          PrismButton(
            label: tr(context, 'Ungroup', 'Desagrupar'),
            density: PrismControlDensity.compact,
            tone: PrismButtonTone.outlined,
            onPressed: _sel.isEmpty ? () {} : _ungroup,
          ),
          PrismButton(
            label: tr(context, 'Lock', 'Bloquear'),
            icon: Icons.lock_outline,
            density: PrismControlDensity.compact,
            tone: PrismButtonTone.outlined,
            onPressed: _sel.isEmpty ? () {} : () => _lock(true),
          ),
          PrismButton(
            label: tr(context, 'Unlock', 'Desbloquear'),
            icon: Icons.lock_open,
            density: PrismControlDensity.compact,
            tone: PrismButtonTone.outlined,
            onPressed: _sel.isEmpty ? () {} : () => _lock(false),
          ),
          PrismButton(
            label: tr(context, 'Forward', 'Adelante'),
            icon: Icons.arrow_upward,
            density: PrismControlDensity.compact,
            tone: PrismButtonTone.outlined,
            onPressed: _sel.isEmpty ? () {} : () => _order(1),
          ),
          PrismButton(
            label: tr(context, 'Back', 'Atrás'),
            icon: Icons.arrow_downward,
            density: PrismControlDensity.compact,
            tone: PrismButtonTone.outlined,
            onPressed: _sel.isEmpty ? () {} : () => _order(-1),
          ),
          PrismButton(
            label: tr(context, 'Delete', 'Eliminar'),
            icon: Icons.delete_outline,
            density: PrismControlDensity.compact,
            tone: PrismButtonTone.destructive,
            onPressed: _sel.isEmpty ? () {} : _delete,
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (sorted.isEmpty)
        Text(
          tr(
            context,
            'Nothing here yet. Add something from the Add tab.',
            'Aún no hay nada. Añade algo desde la pestaña Añadir.',
          ),
          style: theme.textTheme.bodySmall,
        ),
      for (final i in sorted)
        PrismListRow(
          dense: true,
          selected: _sel.contains(i.id),
          leading: i.glyph != null && i.glyph!.length > 3 && i.glyph![2] == ':'
              ? DecorGlyphView(i.glyph!, size: 24)
              : Text(
                  i.glyph ?? _kindEmoji(i.kind),
                  style: const TextStyle(fontSize: 20),
                ),
          title: Text(
            '${i.kind.label}${i.variationId == null ? '' : ' · ${variationById(i.variationId!)?.name ?? ''}'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${i.anchor.label}${i.group != null ? ' · ${tr(context, 'grouped', 'agrupado')}' : ''}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: i.enabled
                    ? tr(context, 'Hide', 'Ocultar')
                    : tr(context, 'Show', 'Mostrar'),
                icon: Icon(
                  i.enabled
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => _edit(() => i.enabled = !i.enabled),
              ),
              IconButton(
                tooltip: i.locked
                    ? tr(context, 'Unlock', 'Desbloquear')
                    : tr(context, 'Lock', 'Bloquear'),
                icon: Icon(i.locked ? Icons.lock : Icons.lock_open),
                onPressed: () => _edit(() => i.locked = !i.locked),
              ),
            ],
          ),
          onTap: () => setState(() {
            if (_multi) {
              _sel.contains(i.id) ? _sel.remove(i.id) : _sel.add(i.id);
            } else {
              _sel
                ..clear()
                ..add(i.id);
            }
          }),
        ),
    ];
  }

  String _kindEmoji(DecoKind k) => switch (k) {
    DecoKind.garland => '🎀',
    DecoKind.fairyLights => '💡',
    DecoKind.ribbon => '🎗️',
    DecoKind.bow => '🎀',
    DecoKind.lantern => '🏮',
    DecoKind.wreath => '💐',
    DecoKind.ornament => '🔔',
    DecoKind.window => '🪟',
    DecoKind.flower => '🌷',
    DecoKind.candle => '🕯️',
    DecoKind.foliage => '🌿',
    DecoKind.corner => '◤',
    DecoKind.border => '▢',
    DecoKind.particles => '✨',
    DecoKind.sticker => '🖼️',
    _ => '✦',
  };

  List<Widget> _placePanel(BuildContext context) {
    final sel = _selected;
    final theme = Theme.of(context);
    if (sel.isEmpty)
      return [
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            tr(
              context,
              'Select a decoration to choose where it sits and which pages show it.',
              'Selecciona una decoración para elegir dónde va y en qué páginas aparece.',
            ),
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ];
    final i = sel.first;
    final tw = i.tweakFor(_device);
    void all(void Function(DecorItem) f) {
      for (final x in sel) {
        if (!x.locked) f(x);
      }
    }

    return [
      PrismSelect<DecoAnchor>(
        labelText: tr(context, 'Attached to', 'Unido a'),
        value: i.anchor,
        items: [
          for (final a in DecoAnchor.values)
            PrismSelectItem(value: a, label: a.label),
        ],
        onChanged: (v) {
          if (v != null) _edit(() => all((x) => x.anchor = v));
        },
      ),
      if (i.anchor.followsWidget)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            tr(
              context,
              'It follows that part of Prism wherever it appears, and is hidden when it isn\'t on screen.',
              'Sigue a esa parte de Prism donde aparezca y se oculta si no está en pantalla.',
            ),
            style: theme.textTheme.bodySmall,
          ),
        ),
      const SizedBox(height: 12),
      Text(
        tr(context, 'Show on', 'Mostrar en'),
        style: theme.textTheme.titleSmall,
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          PrismChip(
            label: tr(context, 'Everywhere', 'En todas partes'),
            selected: i.pages.isEmpty,
            onTap: () => _edit(() => all((x) => x.pages = const [])),
          ),
          for (final p in decorPages)
            PrismChip(
              label: Localizations.localeOf(context).languageCode == 'es'
                  ? p.$3
                  : p.$2,
              selected: i.pages.contains(p.$1),
              onTap: () => _edit(
                () => all(
                  (x) => x.pages = x.pages.contains(p.$1)
                      ? x.pages.where((e) => e != p.$1).toList()
                      : [...x.pages, p.$1],
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
      Text(
        tr(context, 'On this device size', 'En este tamaño de pantalla'),
        style: theme.textTheme.titleSmall,
      ),
      Text(
        _device == DeviceClass.mobile
            ? tr(
                context,
                'Phone is the base layout. Switch to Tablet or Desktop above to nudge things for those screens.',
                'El teléfono es el diseño base. Cambia a Tableta o Escritorio arriba para ajustar esas pantallas.',
              )
            : tr(
                context,
                'Moves and resizes here only affect this screen size.',
                'Los cambios aquí solo afectan a este tamaño de pantalla.',
              ),
        style: theme.textTheme.bodySmall,
      ),
      PrismSwitchRow(
        title: tr(
          context,
          'Hide on this device',
          'Ocultar en este dispositivo',
        ),
        value: tw.hidden,
        onChanged: (v) => _edit(
          () => all(
            (x) => x.tweaks[_device.name] = DeviceTweak(
              dx: x.tweakFor(_device).dx,
              dy: x.tweakFor(_device).dy,
              scale: x.tweakFor(_device).scale,
              hidden: v,
            ),
          ),
        ),
      ),
      if (!tw.isDefault)
        PrismButton(
          label: tr(
            context,
            'Reset for this device',
            'Restablecer en este dispositivo',
          ),
          icon: Icons.restart_alt,
          density: PrismControlDensity.compact,
          tone: PrismButtonTone.outlined,
          onPressed: () =>
              _edit(() => all((x) => x.tweaks.remove(_device.name))),
        ),
      const SizedBox(height: 10),
      Text(
        tr(
          context,
          'Decorations never take taps, so buttons, text fields, scrolling and navigation always work underneath them.',
          'Las decoraciones nunca reciben toques: botones, campos de texto, desplazamiento y navegación siempre funcionan debajo.',
        ),
        style: theme.textTheme.bodySmall,
      ),
    ];
  }

  List<Widget> _savePanel(BuildContext context) {
    final presets = ref.watch(decorPresetsProvider);
    final cats = {
      'My arrangements',
      'Christmas',
      'Halloween',
      'Spring',
      'Summer',
      'Autumn',
      'Winter',
      'Celebrations',
      for (final p in presets) p.category,
    };
    return [
      PrismTextField(
        controller: _name,
        labelText: tr(context, 'Name', 'Nombre'),
      ),
      const SizedBox(height: 8),
      PrismTextField(
        controller: _desc,
        labelText: tr(
          context,
          'Description (optional)',
          'Descripción (opcional)',
        ),
        maxLines: 2,
        minLines: 1,
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final c in cats)
            PrismChip(
              label: c,
              selected: _category == c,
              onTap: () => setState(() => _category = c),
            ),
        ],
      ),
      const SizedBox(height: 14),
      PrismButton(
        label: tr(context, 'Save and use it now', 'Guardar y usar ahora'),
        icon: Icons.check_circle_outline,
        tone: PrismButtonTone.filled,
        expanded: true,
        onPressed: () => _save(asNew: false, useNow: true),
      ),
      const SizedBox(height: 8),
      PrismButton(
        label: _presetId == null
            ? tr(context, 'Save as an arrangement', 'Guardar como arreglo')
            : tr(context, 'Update this arrangement', 'Actualizar este arreglo'),
        icon: Icons.bookmark_add_outlined,
        expanded: true,
        tone: PrismButtonTone.outlined,
        onPressed: () => _save(asNew: false),
      ),
      if (_presetId != null) ...[
        const SizedBox(height: 8),
        PrismButton(
          label: tr(context, 'Save as a new copy', 'Guardar como copia nueva'),
          icon: Icons.copy_outlined,
          expanded: true,
          tone: PrismButtonTone.outlined,
          onPressed: () => _save(asNew: true),
        ),
      ],
      const SizedBox(height: 8),
      PrismButton(
        label: tr(context, 'Clear the canvas', 'Vaciar el lienzo'),
        icon: Icons.layers_clear_outlined,
        expanded: true,
        tone: PrismButtonTone.destructive,
        onPressed: () => _edit(() {
          _items.clear();
          _sel.clear();
        }),
      ),
      const SizedBox(height: 8),
      Text(
        tr(
          context,
          'Your draft is kept as you work, so you can leave and come back.',
          'Tu borrador se guarda mientras trabajas; puedes salir y volver.',
        ),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ];
  }
}

/// The still preview, with its animated layers running so what you place is
/// what you'll see.
class _AnimatedPreview extends StatefulWidget {
  const _AnimatedPreview({
    required this.items,
    required this.layers,
    required this.device,
    required this.width,
    required this.height,
    required this.selected,
    required this.lightsOn,
    required this.images,
  });
  final List<DecorItem> items;
  final DecoLayerSettings layers;
  final DeviceClass device;
  final double width, height;
  final Set<String> selected;
  final bool lightsOn;
  final Map<String, ui.Image> images;

  @override
  State<_AnimatedPreview> createState() => _AnimatedPreviewState();
}

class _AnimatedPreviewState extends State<_AnimatedPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => DecorPreview(
        items: widget.items,
        layers: widget.layers,
        device: widget.device,
        width: widget.width,
        height: widget.height,
        t: reduce ? 2.2 : _c.value * 600,
        selected: widget.selected,
        lightsOn: widget.lightsOn,
        images: widget.images,
      ),
    );
  }
}

class _GuidePainter extends CustomPainter {
  _GuidePainter(this.at, this.color);
  final Offset at;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    if (at.dx >= 0)
      canvas.drawLine(
        Offset(size.width * at.dx, 0),
        Offset(size.width * at.dx, size.height),
        p,
      );
    if (at.dy >= 0)
      canvas.drawLine(
        Offset(0, size.height * at.dy),
        Offset(size.width, size.height * at.dy),
        p,
      );
  }

  @override
  bool shouldRepaint(_GuidePainter o) => o.at != at;
}
