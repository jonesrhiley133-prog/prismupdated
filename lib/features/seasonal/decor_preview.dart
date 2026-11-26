import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:prism_plurality/features/seasonal/decor_models.dart';
import 'package:prism_plurality/features/seasonal/decor_painter.dart';

/// Stand-in rectangles for parts of the interface, so decorations that
/// attach to a profile picture, widget or card can be shown and edited.
Map<DecoAnchor, Rect> mockUiAnchors(Size s) {
  final w = s.width, h = s.height;
  return {
    DecoAnchor.pageHeader: Rect.fromLTWH(0, h * 0.06, w, h * 0.1),
    DecoAnchor.calendarHeader: Rect.fromLTWH(0, h * 0.16, w, h * 0.08),
    DecoAnchor.banner: Rect.fromLTWH(w * 0.05, h * 0.18, w * 0.9, h * 0.14),
    DecoAnchor.profilePicture: Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.34),
      width: w * 0.22,
      height: w * 0.22,
    ),
    DecoAnchor.card: Rect.fromLTWH(w * 0.06, h * 0.46, w * 0.88, h * 0.12),
    DecoAnchor.widget: Rect.fromLTWH(w * 0.06, h * 0.6, w * 0.42, h * 0.14),
    DecoAnchor.divider: Rect.fromLTWH(w * 0.06, h * 0.44, w * 0.88, 4),
    DecoAnchor.companionArea: Rect.fromLTWH(
      w * 0.52,
      h * 0.6,
      w * 0.42,
      h * 0.14,
    ),
  };
}

/// A small mock of Prism's own screen, in the person's own theme colours,
/// with decorations drawn over it exactly as the real app would draw them.
class DecorPreview extends StatelessWidget {
  const DecorPreview({
    super.key,
    required this.items,
    this.layers = const DecoLayerSettings(maxAnimated: 30),
    this.device = DeviceClass.mobile,
    this.width = 180,
    this.height,
    this.t = 2.2,
    this.selected = const {},
    this.dark,
    this.lightsOn = true,
    this.showMockUi = true,
    this.images = const {},
  });

  final List<DecorItem> items;
  final DecoLayerSettings layers;
  final DeviceClass device;
  final double width;
  final double? height;

  /// Time on the animation clock for this still frame.
  final double t;
  final Set<String> selected;
  final bool? dark;
  final bool lightsOn;
  final bool showMockUi;

  /// Decoded pictures for imported decorations, by media id.
  final Map<String, ui.Image> images;

  /// The scene a preview of [size] draws, shared with the Studio's
  /// hit-testing so what you touch is what you see.
  static DecorScene sceneFor({
    required List<DecorItem> items,
    required DecoLayerSettings layers,
    required DeviceClass device,
    required Size size,
    bool lightsOn = true,
    Map<String, ui.Image> images = const {},
  }) => DecorScene(
    items: items,
    layers: layers,
    device: device,
    uiAnchors: mockUiAnchors(size),
    safe: EdgeInsets.only(top: size.height * 0.035, bottom: size.height * 0.02),
    lightsOn: lightsOn,
    images: images,
  );

  static double heightFor(DeviceClass d, double width) => switch (d) {
    DeviceClass.mobile => width * 1.78,
    DeviceClass.tablet => width * 0.75,
    DeviceClass.desktop => width * 0.6,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final h = height ?? heightFor(device, width);
    final size = Size(width, h);
    final scene = sceneFor(
      items: items,
      layers: layers,
      device: device,
      size: size,
      lightsOn: lightsOn,
      images: images,
    );
    return SizedBox(
      width: width,
      height: h,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * 0.06),
        child: ColoredBox(
          color: cs.surface,
          child: Stack(
            children: [
              if (showMockUi) ...[
                // Header
                Positioned(
                  left: width * 0.06,
                  top: h * 0.075,
                  child: Container(
                    width: width * 0.4,
                    height: h * 0.022,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                // Banner and profile picture
                Positioned(
                  left: width * 0.05,
                  top: h * 0.18,
                  width: width * 0.9,
                  height: h * 0.14,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(width * 0.04),
                    ),
                  ),
                ),
                Positioned(
                  left: width * 0.39,
                  top: h * 0.34 - width * 0.11,
                  width: width * 0.22,
                  height: width * 0.22,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: cs.surface, width: 3),
                    ),
                  ),
                ),
                // Cards
                for (var i = 0; i < 2; i++)
                  Positioned(
                    left: width * 0.06,
                    right: width * 0.06,
                    top: h * (0.46 + i * 0.0),
                    height: h * 0.12,
                    child: i == 0
                        ? DecoratedBox(
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(width * 0.04),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                Positioned(
                  left: width * 0.06,
                  width: width * 0.42,
                  top: h * 0.6,
                  height: h * 0.14,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(width * 0.04),
                    ),
                  ),
                ),
                Positioned(
                  left: width * 0.52,
                  width: width * 0.42,
                  top: h * 0.6,
                  height: h * 0.14,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.tertiaryContainer,
                      borderRadius: BorderRadius.circular(width * 0.04),
                    ),
                  ),
                ),
                Positioned(
                  left: width * 0.06,
                  right: width * 0.06,
                  top: h * 0.78,
                  height: h * 0.06,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(width * 0.03),
                    ),
                  ),
                ),
                // Bottom navigation
                Positioned(
                  left: width * 0.08,
                  right: width * 0.08,
                  bottom: h * 0.03,
                  height: h * 0.07,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(width * 0.07),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ],
              for (final layer in [
                {DecoLayer.staticDeco},
                {DecoLayer.animated},
                {DecoLayer.ambient},
              ])
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: DecorPainter(
                        scene: scene,
                        t: layer.contains(DecoLayer.staticDeco) ? 0 : t,
                        layersToDraw: layer,
                      ),
                    ),
                  ),
                ),
              // Interactive objects are drawn here as plain glyphs for the still preview.
              for (final i in items)
                if (i.enabled &&
                    i.kind == DecoKind.interactive &&
                    layers.on(DecoLayer.interactive))
                  Builder(
                    builder: (_) {
                      final b = decorItemBounds(i, size, scene);
                      return Positioned.fromRect(
                        rect: b,
                        child: IgnorePointer(
                          child: FittedBox(child: Text(i.glyph ?? '✨')),
                        ),
                      );
                    },
                  ),
              for (final id in selected)
                Builder(
                  builder: (_) {
                    final i = items.where((x) => x.id == id).firstOrNull;
                    if (i == null) return const SizedBox.shrink();
                    final b = decorItemBounds(i, size, scene).inflate(3);
                    return Positioned.fromRect(
                      rect: b,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(color: cs.primary, width: 1.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
