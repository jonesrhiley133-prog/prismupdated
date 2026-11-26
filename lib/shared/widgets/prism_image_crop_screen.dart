import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crop_image/crop_image.dart';
import 'package:flutter/material.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/prism_shapes.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_spinner.dart';
import 'package:prism_plurality/shared/widgets/prism_toast.dart';
import 'package:prism_plurality/features/links/widgets/related_records.dart'
    show promptText;
import 'package:prism_plurality/shared/ui_kit.dart' show tr;

/// One selectable crop shape. [ratio] null means freeform.
class PrismCropRatio {
  const PrismCropRatio(this.id, this.label, this.ratio);
  final String id;
  final String label;
  final double? ratio;

  static const free = PrismCropRatio('free', 'Free', null);
  static const square = PrismCropRatio('1:1', '1:1', 1);
  static const portrait45 = PrismCropRatio('4:5', '4:5', 4 / 5);
  static const portrait34 = PrismCropRatio('3:4', '3:4', 3 / 4);
  static const portrait23 = PrismCropRatio('2:3', '2:3', 2 / 3);
  static const portrait916 = PrismCropRatio('9:16', '9:16', 9 / 16);
  static const landscape54 = PrismCropRatio('5:4', '5:4', 5 / 4);
  static const landscape43 = PrismCropRatio('4:3', '4:3', 4 / 3);
  static const landscape32 = PrismCropRatio('3:2', '3:2', 3 / 2);
  static const landscape169 = PrismCropRatio('16:9', '16:9', 16 / 9);
  static const banner = PrismCropRatio('3:1', '3:1', 3);

  /// The full set offered by every cropper in Prism.
  static const standard = <PrismCropRatio>[
    free,
    square,
    portrait45,
    portrait34,
    portrait23,
    portrait916,
    landscape54,
    landscape43,
    landscape32,
    landscape169,
    banner,
  ];

  /// "5:7", "16/9" or "1.5" → a ratio, or null if it isn't one.
  static double? parse(String raw) {
    final t = raw.trim().replaceAll('/', ':').replaceAll('x', ':');
    final parts = t.split(':');
    double? v;
    if (parts.length == 2) {
      final a = double.tryParse(parts[0].trim());
      final b = double.tryParse(parts[1].trim());
      if (a != null && b != null && a > 0 && b > 0) v = a / b;
    } else if (parts.length == 1) {
      v = double.tryParse(parts[0]);
    }
    if (v == null || v < 0.1 || v > 10) return null;
    return v;
  }
}

class PrismImageCropRequest {
  const PrismImageCropRequest({
    required this.sourceBytes,
    required this.title,
    required this.doneButtonTitle,
    required this.cancelButtonTitle,
    required this.aspectRatio,
    this.ratios,
    this.circlePreview = false,
    this.allowFlip = true,
    this.allowZoom = true,
  });

  final Uint8List sourceBytes;
  final String title;
  final String doneButtonTitle;
  final String cancelButtonTitle;

  /// Starting ratio. Null = freeform.
  final double? aspectRatio;

  /// Ratios the user may switch between. Null or empty keeps the crop locked
  /// to [aspectRatio], which is what avatars and banners want.
  final List<PrismCropRatio>? ratios;

  /// Show the live preview as a circle (profile pictures).
  final bool circlePreview;
  final bool allowFlip;
  final bool allowZoom;
}

Future<ui.Image?> showPrismImageCropper(
  BuildContext context,
  PrismImageCropRequest request,
) {
  return Navigator.of(context, rootNavigator: true).push<ui.Image>(
    MaterialPageRoute<ui.Image>(
      fullscreenDialog: true,
      builder: (_) => _PrismImageCropScreen(request: request),
    ),
  );
}

class _PrismImageCropScreen extends StatefulWidget {
  const _PrismImageCropScreen({required this.request});

  final PrismImageCropRequest request;

  @override
  State<_PrismImageCropScreen> createState() => _PrismImageCropScreenState();
}

class _PrismImageCropScreenState extends State<_PrismImageCropScreen> {
  late final CropController _controller = CropController(
    aspectRatio: widget.request.aspectRatio,
    defaultCrop: const Rect.fromLTRB(0, 0, 1, 1),
  );
  bool _isSaving = false;
  bool _flipH = false, _flipV = false;
  double _zoom = 1;
  String _ratioId = 'init';
  double? _customRatio;
  ui.Image? _source;

  bool get _locked => (widget.request.ratios ?? const []).isEmpty;

  @override
  void initState() {
    super.initState();
    final r = widget.request;
    final list = r.ratios ?? const <PrismCropRatio>[];
    final match = list.where((x) => x.ratio == r.aspectRatio).firstOrNull;
    _ratioId = match?.id ?? (r.aspectRatio == null ? 'free' : 'custom');
    if (match == null && r.aspectRatio != null) _customRatio = r.aspectRatio;
    ui.decodeImageFromList(r.sourceBytes, (img) {
      if (!mounted) {
        img.dispose();
        return;
      }
      setState(() => _source = img);
    });
    _controller.addListener(_onCrop);
  }

  void _onCrop() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onCrop);
    _controller.dispose();
    _source?.dispose();
    super.dispose();
  }

  /// Size of the image after rotation, in pixels.
  Size? get _rotatedSize {
    final src = _source;
    if (src == null) return null;
    final odd =
        _controller.rotation == CropRotation.right ||
        _controller.rotation == CropRotation.left;
    return odd
        ? Size(src.height.toDouble(), src.width.toDouble())
        : Size(src.width.toDouble(), src.height.toDouble());
  }

  /// Largest crop rectangle (normalised) for [ratio] that fits the image.
  Rect _maxCrop(double? ratio) {
    final size = _rotatedSize;
    if (ratio == null || size == null) return const Rect.fromLTRB(0, 0, 1, 1);
    final ia = size.width / size.height;
    final w = ia >= ratio ? ratio / ia : 1.0;
    final h = ia >= ratio ? 1.0 : ia / ratio;
    return Rect.fromCenter(center: const Offset(.5, .5), width: w, height: h);
  }

  void _applyZoom(double zoom, {Offset? around}) {
    final max = _maxCrop(_controller.aspectRatio);
    final center = around ?? _controller.crop.center;
    final w = max.width / zoom, h = max.height / zoom;
    final cx = center.dx.clamp(w / 2, 1 - w / 2);
    final cy = center.dy.clamp(h / 2, 1 - h / 2);
    _controller.crop = Rect.fromCenter(
      center: Offset(cx, cy),
      width: w,
      height: h,
    );
  }

  void _setRatio(PrismCropRatio r) {
    setState(() {
      _ratioId = r.id;
      _zoom = 1;
      _customRatio = null;
    });
    _controller.aspectRatio = r.ratio;
    _controller.crop = _maxCrop(r.ratio);
  }

  Future<void> _custom() async {
    final raw = await promptText(
      context,
      tr(context, 'Custom ratio (e.g. 5:7)', 'Proporción propia (p. ej. 5:7)'),
      initial: '',
    );
    if (raw == null) return;
    final v = PrismCropRatio.parse(raw);
    if (v == null) {
      if (mounted) {
        PrismToast.error(
          context,
          message: tr(
            context,
            'Use a ratio like 5:7 or 16:9.',
            'Usa una proporción como 5:7 o 16:9.',
          ),
        );
      }
      return;
    }
    setState(() {
      _ratioId = 'custom';
      _customRatio = v;
      _zoom = 1;
    });
    _controller.aspectRatio = v;
    _controller.crop = _maxCrop(v);
  }

  void _reset() {
    setState(() {
      _flipH = false;
      _flipV = false;
      _zoom = 1;
    });
    _controller.rotation = CropRotation.up;
    _controller.aspectRatio = _locked
        ? widget.request.aspectRatio
        : (_ratioId == 'custom' ? _customRatio : _currentRatio());
    _controller.crop = _maxCrop(_controller.aspectRatio);
  }

  double? _currentRatio() {
    final list = widget.request.ratios ?? const <PrismCropRatio>[];
    return list.where((x) => x.id == _ratioId).firstOrNull?.ratio ??
        widget.request.aspectRatio;
  }

  Future<ui.Image> _flipped(ui.Image img) async {
    if (!_flipH && !_flipV) return img;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.translate(
      _flipH ? img.width.toDouble() : 0,
      _flipV ? img.height.toDouble() : 0,
    );
    c.scale(_flipH ? -1 : 1, _flipV ? -1 : 1);
    c.drawImage(img, Offset.zero, Paint()..filterQuality = FilterQuality.high);
    final out = await rec.endRecording().toImage(img.width, img.height);
    img.dispose();
    return out;
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final raw = await _controller.croppedBitmap();
      final bitmap = await _flipped(raw);
      if (!mounted) {
        bitmap.dispose();
        return;
      }
      Navigator.of(context).pop(bitmap);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      PrismToast.error(context, message: context.l10n.imageCropProcessingError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final borderRadius = prismCorners(context, 28);
    final req = widget.request;
    final ratios = req.ratios ?? const <PrismCropRatio>[];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: req.cancelButtonTitle,
          icon: Icon(AppIcons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(req.title),
        actions: [
          IconButton(
            tooltip: req.doneButtonTitle,
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? PrismSpinner(size: 18, color: colors.primary)
                : Icon(AppIcons.check),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(
                      alpha: 0.45,
                    ),
                    borderRadius: borderRadius,
                  ),
                  child: ClipRRect(
                    borderRadius: borderRadius,
                    child: CropImage(
                      controller: _controller,
                      image: Image.memory(req.sourceBytes),
                      paddingSize: 24,
                      minimumImageSize: 72,
                      gridColor: colors.onSurface.withValues(alpha: 0.88),
                      gridInnerColor: colors.onSurface.withValues(alpha: 0.52),
                      gridCornerColor: colors.primary,
                      scrimColor: colors.scrim.withValues(alpha: 0.7),
                      gridCornerSize: 28,
                      gridThinWidth: 1.5,
                      gridThickWidth: 3.5,
                    ),
                  ),
                ),
              ),
            ),
            if (ratios.isNotEmpty)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    for (final r in ratios)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: PrismChip(
                          label: r.id == 'free'
                              ? tr(context, 'Free', 'Libre')
                              : r.label,
                          selected: _ratioId == r.id,
                          onTap: () => _setRatio(r),
                        ),
                      ),
                    PrismChip(
                      label: _customRatio == null
                          ? tr(context, 'Custom…', 'Otra…')
                          : tr(context, 'Custom', 'Otra'),
                      selected: _ratioId == 'custom',
                      onTap: _custom,
                    ),
                  ],
                ),
              ),
            if (req.allowZoom)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Row(
                  children: [
                    Icon(
                      Icons.zoom_out,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                    Expanded(
                      child: Slider(
                        value: _zoom,
                        min: 1,
                        max: 5,
                        onChanged: (v) {
                          setState(() => _zoom = v);
                          _applyZoom(v);
                        },
                      ),
                    ),
                    Icon(
                      Icons.zoom_in,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _CropPreview(
                    source: _source,
                    crop: _controller.crop,
                    rotation: _controller.rotation,
                    flipH: _flipH,
                    flipV: _flipV,
                    circle: req.circlePreview,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        PrismButton(
                          icon: AppIcons.restartAlt,
                          label: context.l10n.imageCropRotateLeft,
                          density: PrismControlDensity.compact,
                          tone: PrismButtonTone.outlined,
                          onPressed: _controller.rotateLeft,
                        ),
                        PrismButton(
                          icon: AppIcons.refresh,
                          label: context.l10n.imageCropRotateRight,
                          density: PrismControlDensity.compact,
                          tone: PrismButtonTone.outlined,
                          onPressed: _controller.rotateRight,
                        ),
                        if (req.allowFlip) ...[
                          PrismButton(
                            icon: Icons.flip,
                            label: tr(context, 'Flip ↔', 'Voltear ↔'),
                            density: PrismControlDensity.compact,
                            tone: _flipH
                                ? PrismButtonTone.filled
                                : PrismButtonTone.outlined,
                            onPressed: () => setState(() => _flipH = !_flipH),
                          ),
                          PrismButton(
                            icon: Icons.flip,
                            label: tr(context, 'Flip ↕', 'Voltear ↕'),
                            density: PrismControlDensity.compact,
                            tone: _flipV
                                ? PrismButtonTone.filled
                                : PrismButtonTone.outlined,
                            onPressed: () => setState(() => _flipV = !_flipV),
                          ),
                        ],
                        PrismButton(
                          icon: AppIcons.refresh,
                          label: tr(context, 'Reset', 'Restablecer'),
                          density: PrismControlDensity.compact,
                          tone: PrismButtonTone.outlined,
                          onPressed: _reset,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Live preview of exactly what will be saved: the crop, rotation and flips,
/// drawn straight from the source image so it updates as you drag.
class _CropPreview extends StatelessWidget {
  const _CropPreview({
    required this.source,
    required this.crop,
    required this.rotation,
    required this.flipH,
    required this.flipV,
    required this.circle,
  });

  final ui.Image? source;
  final Rect crop;
  final CropRotation rotation;
  final bool flipH, flipV, circle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shape = circle
        ? prismCircleBorder(context)
        : prismCorners(context, 12);
    final box = SizedBox(
      width: 88,
      height: 88,
      child: CustomPaint(
        painter: _PreviewPainter(source, crop, rotation, flipH, flipV),
      ),
    );
    return Semantics(
      label: 'Preview',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: circle ? null : shape as BorderRadius,
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
        ),
        child: circle
            ? ClipOval(child: box)
            : ClipRRect(borderRadius: shape as BorderRadius, child: box),
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter(this.src, this.crop, this.rotation, this.flipH, this.flipV);
  final ui.Image? src;
  final Rect crop;
  final CropRotation rotation;
  final bool flipH, flipV;

  @override
  void paint(Canvas canvas, Size size) {
    final img = src;
    if (img == null) return;
    final turns = rotation.degrees ~/ 90;
    final rw = (turns.isOdd ? img.height : img.width).toDouble();
    final rh = (turns.isOdd ? img.width : img.height).toDouble();
    final cw = crop.width * rw, ch = crop.height * rh;
    if (cw <= 0 || ch <= 0) return;
    // Fit the crop inside the square preview (contain), so non-square
    // crops show their true proportions.
    final s = math.min(size.width / cw, size.height / ch);
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(flipH ? -s : s, flipV ? -s : s);
    canvas.translate(-crop.center.dx * rw, -crop.center.dy * rh);
    canvas.translate(rw / 2, rh / 2);
    canvas.rotate(turns * math.pi / 2);
    canvas.translate(-img.width / 2, -img.height / 2);
    canvas.drawImage(
      img,
      Offset.zero,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_PreviewPainter o) =>
      o.src != src ||
      o.crop != crop ||
      o.rotation != rotation ||
      o.flipH != flipH ||
      o.flipV != flipV;
}
