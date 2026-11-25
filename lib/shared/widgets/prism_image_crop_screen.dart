import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crop_image/crop_image.dart';
import 'package:flutter/material.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/prism_shapes.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_image_crop_options.dart';
import 'package:prism_plurality/shared/widgets/prism_spinner.dart';
import 'package:prism_plurality/shared/widgets/prism_toast.dart';

class PrismImageCropRequest {
  const PrismImageCropRequest({
    required this.sourceBytes,
    required this.title,
    required this.doneButtonTitle,
    required this.cancelButtonTitle,
    required this.aspectRatio,
    this.options,
  });

  final Uint8List sourceBytes;
  final String title;
  final String doneButtonTitle;
  final String cancelButtonTitle;
  final double aspectRatio;

  /// Optional freeform / ratio / flip / circular-preview extensions. When
  /// omitted the cropper keeps its classic fixed-ratio behaviour so every
  /// existing call site continues to work unchanged.
  final PrismImageCropOptions? options;
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

/// Convenience entry used by the newer customization surfaces (scrapbook
/// covers, custom stickers, ID cards, decorations, …). Same cropper screen,
/// same theme integration — just a terser call shape.
Future<ui.Image?> showPrismImageCropperFor(
  BuildContext context, {
  required Uint8List bytes,
  String title = 'Crop image',
  String doneLabel = 'Done',
  String cancelLabel = 'Cancel',
  PrismImageCropOptions options = const PrismImageCropOptions(),
}) {
  return showPrismImageCropper(
    context,
    PrismImageCropRequest(
      sourceBytes: bytes,
      title: title,
      doneButtonTitle: doneLabel,
      cancelButtonTitle: cancelLabel,
      aspectRatio: options.initialRatio.ratio ?? 1,
      options: options,
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
    aspectRatio: widget.request.options?.initialRatio.ratio ?? widget.request.aspectRatio,
    defaultCrop: const Rect.fromLTRB(0, 0, 1, 1),
  );
  bool _isSaving = false;

  // Freeform-editor state (only used when `options` is provided).
  PrismCropFlip _flip = PrismCropFlip.none;
  double _rotation = 0; // quarter-turn steps applied via the rotate buttons.
  PrismCropRatio _ratio = PrismCropRatio.freeform;

  PrismImageCropOptions? get _opts => widget.request.options;

  @override
  void initState() {
    super.initState();
    final o = _opts;
    if (o != null) _ratio = o.initialRatio;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setRatio(PrismCropRatio r) {
    setState(() {
      _ratio = r;
      // crop_image uses 0 for "freeform" (no locked aspect ratio).
      _controller.aspectRatio = r.ratio ?? 0;
    });
  }

  void _rotate(int dir) {
    if (dir < 0) {
      _controller.rotateLeft();
    } else {
      _controller.rotateRight();
    }
    if (_opts != null) {
      setState(() => _rotation = (_rotation + dir * math.pi / 2) % (2 * math.pi));
    }
  }

  void _reset() {
    setState(() {
      _flip = PrismCropFlip.none;
      _rotation = 0;
      _controller.crop = const Rect.fromLTRB(0, 0, 1, 1);
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      var bitmap = await _controller.croppedBitmap();
      // Apply horizontal/vertical flips to the produced image (the live
      // texture layer cannot be wrapped in a Transform without breaking
      // `croppedBitmap`).
      final flip = _flip;
      if (flip != PrismCropFlip.none) {
        final mirrored = await _mirroredCopy(bitmap, flip);
        bitmap.dispose();
        bitmap = mirrored;
      }
      if (!mounted) {
        bitmap.dispose();
        return;
      }
      Navigator.of(context).pop(bitmap);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      PrismToast.error(
        context,
        message: context.l10n.imageCropProcessingError,
      );
    }
  }

  static Future<ui.Image> _mirroredCopy(ui.Image src, PrismCropFlip flip) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final sx = flip == PrismCropFlip.horizontal || flip == PrismCropFlip.both ? -1.0 : 1.0;
    final sy = flip == PrismCropFlip.vertical || flip == PrismCropFlip.both ? -1.0 : 1.0;
    canvas.translate(src.width / 2, src.height / 2);
    canvas.scale(sx, sy);
    canvas.drawImage(src, Offset(-src.width / 2, -src.height / 2), Paint());
    final picture = recorder.endRecording();
    final img = await picture.toImage(src.width, src.height);
    picture.dispose();
    return img;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final borderRadius = BorderRadius.circular(PrismShapes.of(context).radius(28));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: widget.request.cancelButtonTitle,
          icon: Icon(AppIcons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.request.title),
        actions: [
          IconButton(
            tooltip: widget.request.doneButtonTitle,
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? PrismSpinner(
                    size: 18,
                    color: colors.primary,
                  )
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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
                    borderRadius: borderRadius,
                  ),
                  child: ClipRRect(
                    borderRadius: borderRadius,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          // NOTE: keep `crop_image` as the single, direct child
                          // of the ClipRRect. The package's `croppedBitmap()`
                          // reads the live texture layer of its render box, so
                          // wrapping it in a Transform would break saving.
                          // Aspect ratio, rotation and repositioning are all
                          // driven through `CropController`; horizontal/
                          // vertical flips are applied to the produced bitmap
                          // in `_save`.
                          child: CropImage(
                            controller: _controller,
                            image: Image.memory(widget.request.sourceBytes),
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
                        if (_opts?.circularPreview ?? false)
                          IgnorePointer(
                            child: Center(
                              child: LayoutBuilder(
                                builder: (_, c) => SizedBox(
                                  width: math.min(c.maxWidth, c.maxHeight) * 0.62,
                                  height: math.min(c.maxWidth, c.maxHeight) * 0.62,
                                  child: CustomPaint(
                                    painter: _CircularGuidePainter(colors.primary),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_opts?.showZoomHint ?? false)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Pinch to zoom · drag inside the box to reposition',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            if (_opts != null)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  children: [
                    for (final r in _opts!.ratios) ...[
                      if (r.id != _opts!.ratios.first.id) const SizedBox(width: 8),
                      _RatioChip(
                        label: r.label,
                        selected: r.id == _ratio.id,
                        onTap: () => _setRatio(r),
                      ),
                    ],
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  PrismButton(
                    icon: AppIcons.restartAlt,
                    label: context.l10n.imageCropRotateLeft,
                    density: PrismControlDensity.compact,
                    tone: PrismButtonTone.outlined,
                    onPressed: () => _rotate(-1),
                  ),
                  PrismButton(
                    icon: AppIcons.refresh,
                    label: context.l10n.imageCropRotateRight,
                    density: PrismControlDensity.compact,
                    tone: PrismButtonTone.outlined,
                    onPressed: () => _rotate(1),
                  ),
                  if (_opts?.allowFlip ?? false) ...[
                    PrismButton(
                      icon: PhosphorIcons.flipHorizontal(),
                      label: 'Flip H',
                      density: PrismControlDensity.compact,
                      tone: _flip == PrismCropFlip.horizontal || _flip == PrismCropFlip.both
                          ? PrismButtonTone.filled
                          : PrismButtonTone.outlined,
                      onPressed: () => setState(() => _flip = _flip.toggledHorizontal()),
                    ),
                    PrismButton(
                      icon: PhosphorIcons.flipVertical(),
                      label: 'Flip V',
                      density: PrismControlDensity.compact,
                      tone: _flip == PrismCropFlip.vertical || _flip == PrismCropFlip.both
                          ? PrismButtonTone.filled
                          : PrismButtonTone.outlined,
                      onPressed: () => setState(() => _flip = _flip.toggledVertical()),
                    ),
                  ],
                  if (_opts?.allowReset ?? false)
                    PrismButton(
                      icon: PhosphorIcons.arrowCounterClockwise(),
                      label: 'Reset',
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
    );
  }
}

class _RatioChip extends StatelessWidget {
  const _RatioChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primary : colors.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? colors.onPrimary : colors.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _CircularGuidePainter extends CustomPainter {
  _CircularGuidePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.shortestSide / 2, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withValues(alpha: 0.9));
  }

  @override
  bool shouldRepaint(_CircularGuidePainter old) => old.color != color;
}
