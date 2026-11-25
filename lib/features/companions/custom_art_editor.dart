import 'package:prism_plurality/features/companions/companion_art.dart';
import 'package:prism_plurality/features/companions/companion_species.dart';
import 'package:prism_plurality/features/experiences/color_sheet.dart';
import 'package:prism_plurality/features/social/widgets/social_widgets.dart'
    show SocialImage;
import 'package:prism_plurality/shared/ui_kit.dart';

/// An uploaded companion picture placed in its square frame per [fit].
class FittedArt extends StatelessWidget {
  const FittedArt({
    super.key,
    required this.media,
    required this.fit,
    required this.size,
  });
  final String media;
  final ArtFit fit;
  final double size;

  @override
  Widget build(BuildContext context) {
    Widget img = Transform.translate(
      offset: Offset(fit.x * size, fit.y * size),
      child: Transform.rotate(
        angle: fit.rotation * 3.141592653589793 / 180,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(
            fit.mirror ? -fit.scale : fit.scale,
            fit.scale,
            1,
          ),
          child: Padding(
            padding: EdgeInsets.all(size * 0.12),
            child: SocialImage(id: media, fit: BoxFit.contain),
          ),
        ),
      ),
    );
    img = switch (fit.crop) {
      'circle' => PrismClipRound(child: img),
      'rounded' => ClipRRect(
        borderRadius: prismCorners(context, size * 0.18),
        child: img,
      ),
      _ => ClipRect(child: img),
    };
    final bg = switch (fit.background) {
      'soft' => BoxDecoration(
        gradient: RadialGradient(
          colors: [Color(fit.bgColor), Color(fit.bgColor).withValues(alpha: 0)],
        ),
      ),
      'circle' => BoxDecoration(
        borderRadius: prismRound(context),
        color: Color(fit.bgColor),
      ),
      'color' => BoxDecoration(
        color: Color(fit.bgColor),
        borderRadius: prismCorners(context, size * 0.12),
      ),
      _ => null,
    };
    return bg == null ? img : DecoratedBox(decoration: bg, child: img);
  }
}

/// Crop, place, scale, rotate and back an uploaded picture, and mark where
/// hats and scarves attach. Buttons and sliders work without dragging; you
/// can also drag the picture or the head marker.
class CustomArtEditor extends StatefulWidget {
  const CustomArtEditor({
    super.key,
    required this.media,
    required this.base,
    this.initial = const ArtFit(),
  });
  final String media;
  final Species base;
  final ArtFit initial;

  static Future<ArtFit?> open(
    BuildContext context, {
    required String media,
    required Species base,
    ArtFit initial = const ArtFit(),
  }) => Navigator.of(context, rootNavigator: true).push<ArtFit>(
    MaterialPageRoute(
      builder: (_) =>
          CustomArtEditor(media: media, base: base, initial: initial),
    ),
  );

  @override
  State<CustomArtEditor> createState() => _CustomArtEditorState();
}

class _CustomArtEditorState extends State<CustomArtEditor> {
  late ArtFit _f = widget.initial;
  bool _anchors = false;
  static const _preview = CompanionLook(hat: 'beanie', neck: 'scarf');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const size = 260.0;
    Widget slider(
      String label,
      double v,
      double min,
      double max,
      String Function(double) fmt,
      ValueChanged<double> on,
    ) => Row(
      children: [
        SizedBox(
          width: 84,
          child: Text(label, style: theme.textTheme.bodySmall),
        ),
        Expanded(
          child: Slider(
            value: v.clamp(min, max),
            min: min,
            max: max,
            onChanged: on,
            semanticFormatterCallback: (x) => '$label ${fmt(x)}',
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(fmt(v), style: theme.textTheme.labelSmall),
        ),
      ],
    );
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: 'Adjust picture',
        showBackButton: true,
        actions: [
          PrismButton(
            label: 'Done',
            tone: PrismButtonTone.filled,
            density: PrismControlDensity.compact,
            onPressed: () => Navigator.of(context).pop(_f),
          ),
        ],
      ),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + NavBarInset.of(context)),
          children: [
            Center(
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: prismCorners(context, 12),
                ),
                child: GestureDetector(
                  onPanUpdate: (d) => setState(() {
                    if (_anchors) {
                      _f = _f.copyWith(
                        headX: (_f.headX + d.delta.dx / size * 100).clamp(
                          0,
                          100,
                        ),
                        headY: (_f.headY + d.delta.dy / size * 100).clamp(
                          0,
                          100,
                        ),
                      );
                    } else {
                      _f = _f.copyWith(
                        x: (_f.x + d.delta.dx / size).clamp(-0.6, 0.6),
                        y: (_f.y + d.delta.dy / size).clamp(-0.6, 0.6),
                      );
                    }
                  }),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FittedArt(media: widget.media, fit: _f, size: size),
                      IgnorePointer(
                        child: CompanionView(
                          species: widget.base,
                          look: _preview,
                          size: size,
                          accessoriesOnly: true,
                          animate: false,
                          showParticles: false,
                          fit: _f,
                        ),
                      ),
                      if (_anchors)
                        IgnorePointer(
                          child: CustomPaint(
                            painter: _AnchorGuide(
                              _f,
                              theme.colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Wrap(
                spacing: 8,
                children: [
                  PrismChip(
                    label: 'Move picture',
                    selected: !_anchors,
                    onTap: () => setState(() => _anchors = false),
                  ),
                  PrismChip(
                    label: 'Accessory anchors',
                    selected: _anchors,
                    onTap: () => setState(() => _anchors = true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (!_anchors) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Move left',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => setState(
                      () => _f = _f.copyWith(x: (_f.x - 0.02).clamp(-0.6, 0.6)),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Move up',
                    icon: const Icon(Icons.arrow_upward),
                    onPressed: () => setState(
                      () => _f = _f.copyWith(y: (_f.y - 0.02).clamp(-0.6, 0.6)),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Move down',
                    icon: const Icon(Icons.arrow_downward),
                    onPressed: () => setState(
                      () => _f = _f.copyWith(y: (_f.y + 0.02).clamp(-0.6, 0.6)),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Move right',
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: () => setState(
                      () => _f = _f.copyWith(x: (_f.x + 0.02).clamp(-0.6, 0.6)),
                    ),
                  ),
                ],
              ),
              slider(
                'Size',
                _f.scale,
                0.3,
                3,
                (v) => '${v.toStringAsFixed(2)}×',
                (v) => setState(() => _f = _f.copyWith(scale: v)),
              ),
              slider(
                'Rotation',
                _f.rotation,
                -180,
                180,
                (v) => '${v.round()}°',
                (v) => setState(
                  () => _f = _f.copyWith(rotation: v.roundToDouble()),
                ),
              ),
              Row(
                children: [
                  SizedBox(
                    width: 84,
                    child: Text('Crop', style: theme.textTheme.bodySmall),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      children: [
                        for (final (k, l) in const [
                          ('none', 'Square'),
                          ('rounded', 'Rounded'),
                          ('circle', 'Circle'),
                        ])
                          PrismChip(
                            label: l,
                            selected: _f.crop == k,
                            onTap: () =>
                                setState(() => _f = _f.copyWith(crop: k)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  SizedBox(
                    width: 84,
                    child: Text('Background', style: theme.textTheme.bodySmall),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final (k, l) in const [
                          ('none', 'None'),
                          ('soft', 'Soft glow'),
                          ('circle', 'Circle'),
                          ('color', 'Solid'),
                        ])
                          PrismChip(
                            label: l,
                            selected: _f.background == k,
                            onTap: () =>
                                setState(() => _f = _f.copyWith(background: k)),
                          ),
                        if (_f.background != 'none')
                          GestureDetector(
                            onTap: () async {
                              final c = await showPrismColorPicker(
                                context: context,
                                initial: Color(_f.bgColor),
                                title: 'Background colour',
                              );
                              if (c != null)
                                setState(
                                  () => _f = _f.copyWith(bgColor: c.toARGB32()),
                                );
                            },
                            child: PrismCircleAvatar(
                              radius: 14,
                              backgroundColor: Color(_f.bgColor),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              PrismSwitchRow(
                title: 'Mirror',
                value: _f.mirror,
                onChanged: (v) => setState(() => _f = _f.copyWith(mirror: v)),
              ),
            ] else ...[
              Text(
                'Drag the circle onto the head, or use the sliders. Hats sit on top of the circle; neckwear sits on the line.',
                style: theme.textTheme.bodySmall,
              ),
              slider(
                'Head across',
                _f.headX,
                0,
                100,
                (v) => '${v.round()}',
                (v) => setState(() => _f = _f.copyWith(headX: v)),
              ),
              slider(
                'Head height',
                _f.headY,
                0,
                100,
                (v) => '${v.round()}',
                (v) => setState(() => _f = _f.copyWith(headY: v)),
              ),
              slider(
                'Head size',
                _f.headR,
                8,
                50,
                (v) => '${v.round()}',
                (v) => setState(() => _f = _f.copyWith(headR: v)),
              ),
              slider(
                'Neck line',
                _f.neckY,
                0,
                100,
                (v) => '${v.round()}',
                (v) => setState(() => _f = _f.copyWith(neckY: v)),
              ),
            ],
            const SizedBox(height: 8),
            PrismButton(
              label: 'Reset',
              icon: Icons.restart_alt,
              onPressed: () => setState(() => _f = const ArtFit()),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnchorGuide extends CustomPainter {
  _AnchorGuide(this.f, this.color);
  final ArtFit f;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 100;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(f.headX * k, f.headY * k), f.headR * k, p);
    canvas.drawLine(
      Offset(0, f.neckY * k),
      Offset(size.width, f.neckY * k),
      p..color = color.withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(_AnchorGuide old) => old.f != f;
}
