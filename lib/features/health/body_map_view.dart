import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:prism_plurality/features/health/body_atlas.dart';
import 'package:prism_plurality/features/health/health_model.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

bool _es(BuildContext c) => Localizations.localeOf(c).languageCode == 'es';

String bodyViewLabel(BodyView v, bool es, [BodySide side = BodySide.right]) {
  final s = side == BodySide.left
      ? (es ? 'izquierda' : 'Left')
      : (es ? 'derecha' : 'Right');
  return switch (v) {
    BodyView.front => es ? 'Delante' : 'Front',
    BodyView.back => es ? 'Detrás' : 'Back',
    BodyView.face => es ? 'Cara' : 'Face',
    BodyView.handPalm => es ? 'Palma $s' : '$s palm',
    BodyView.handBack => es ? 'Dorso de la mano $s' : '$s back of hand',
    BodyView.footTop => es ? 'Pie $s · arriba' : '$s foot · top',
    BodyView.footSole => es ? 'Pie $s · planta' : '$s foot · sole',
    BodyView.side => es ? 'Lado $s' : '$s side',
  };
}

/// What the user picked on the map or in the region list.
class BodyPick {
  const BodyPick({
    required this.regionId,
    required this.side,
    required this.view,
    this.x,
    this.y,
  });
  final String regionId;
  final BodySide side;
  final BodyView view;

  /// Normalised position (0–1) on [view]; null when picked from the list.
  final double? x;
  final double? y;
}

/// A marker to draw: a numbered spot, or a whole highlighted region.
class MapMarker {
  const MapMarker({
    required this.id,
    required this.number,
    required this.regionId,
    required this.side,
    required this.view,
    this.x,
    this.y,
    this.spreads = const [],
  });
  final String id;
  final int number;
  final String regionId;
  final BodySide side;
  final BodyView view;
  final double? x;
  final double? y;
  final List<SpreadPoint> spreads;

  static List<MapMarker> fromSpots(List<BodySpot> spots) => [
    for (final (i, s) in spots.indexed)
      MapMarker(
        id: s.id,
        number: i + 1,
        regionId: s.regionId,
        side: s.side,
        view: s.view,
        x: s.x,
        y: s.y,
        spreads: s.spreads,
      ),
  ];
}

/// The anatomical drawing with markers. Front/back figures, or a detail
/// sheet (face, hand, foot) for [side].
class BodyMapCanvas extends StatefulWidget {
  const BodyMapCanvas({
    super.key,
    required this.view,
    this.side = BodySide.right,
    this.markers = const [],
    this.focusedId,
    this.onPick,
    this.onZoom,
    this.onMarkerTap,
    this.maxHeight = 520,
  });

  final BodyView view;
  final BodySide side;
  final List<MapMarker> markers;
  final String? focusedId;
  final ValueChanged<BodyPick>? onPick;
  final void Function(BodyView view, BodySide side)? onZoom;
  final ValueChanged<String>? onMarkerTap;
  final double maxHeight;

  @override
  State<BodyMapCanvas> createState() => _BodyMapCanvasState();
}

class _BodyMapCanvasState extends State<BodyMapCanvas> {
  RegionShape? _hover;

  void _onTheme() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    loadBodyMapTheme();
    bodyMapTheme.addListener(_onTheme);
  }

  @override
  void dispose() {
    bodyMapTheme.removeListener(_onTheme);
    super.dispose();
  }

  BodySheet get _sheet => sheetFor(widget.view, side: widget.side);

  Future<void> _tap(Offset local, Size box) async {
    final sheet = _sheet;
    final scale = box.width / sheet.size.width;
    final p = local / scale;
    // A marker under the finger wins.
    for (final m in widget.markers.reversed) {
      final c = _markerCenter(m, sheet);
      if (c != null && (c - p).distance <= 9) {
        widget.onMarkerTap?.call(m.id);
        return;
      }
    }
    final hit = hitTestSheet(sheet, p);
    final primary = hit.primary;
    if (primary == null) return;
    if (primary.zoomTo != null && widget.onZoom != null) {
      widget.onZoom!(
        primary.zoomTo!,
        primary.side == BodySide.center ? BodySide.right : primary.side,
      );
      return;
    }
    var chosen = primary;
    if (hit.alternatives.isNotEmpty) {
      final pick = await _disambiguate(context, [primary, ...hit.alternatives]);
      if (pick == null || !mounted) return;
      chosen = pick;
    }
    HapticFeedback.selectionClick();
    widget.onPick?.call(
      BodyPick(
        regionId: chosen.regionId,
        side: chosen.side,
        view: widget.view,
        x: p.dx / sheet.size.width,
        y: p.dy / sheet.size.height,
      ),
    );
  }

  Offset? _markerCenter(MapMarker m, BodySheet sheet) {
    if (m.view == widget.view && m.x != null && m.y != null) {
      if (!widget.view.isFigure &&
          m.side != widget.side &&
          regionById[m.regionId]?.sided == true)
        return null;
      return Offset(m.x! * sheet.size.width, m.y! * sheet.size.height);
    }
    if (widget.view.isFigure)
      return figureAnchor(m.regionId, m.side, widget.view);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final sheet = _sheet;
    final theme = Theme.of(context);
    final es = _es(context);
    final leftSide = widget.view.isFigure ? viewerLeftSide(widget.view) : null;
    return LayoutBuilder(
      builder: (context, c) {
        final aspect = sheet.size.width / sheet.size.height;
        var h = widget.maxHeight;
        var w = h * aspect;
        if (w > c.maxWidth) {
          w = c.maxWidth;
          h = w / aspect;
        }
        final size = Size(w, h);
        return Center(
          child: Semantics(
            label: es
                ? 'Mapa corporal, vista ${bodyViewLabel(widget.view, es, widget.side)}. Toca una zona o usa la lista de zonas.'
                : 'Body map, ${bodyViewLabel(widget.view, es, widget.side)} view. Tap an area, or use the region list.',
            child: MouseRegion(
              cursor: SystemMouseCursors.precise,
              onHover: (e) {
                final p = e.localPosition / (size.width / sheet.size.width);
                final hit = hitTestSheet(sheet, p, slop: 0).primary;
                if (hit?.regionId != _hover?.regionId ||
                    hit?.side != _hover?.side)
                  setState(() => _hover = hit);
              },
              onExit: (_) => setState(() => _hover = null),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _tap(d.localPosition, size),
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _BodyPainter(
                            sheet: sheet,
                            view: widget.view,
                            side: widget.side,
                            markers: widget.markers,
                            focusedId: widget.focusedId,
                            hover: _hover,
                            colors: theme.colorScheme,
                            markerCenter: (m) => _markerCenter(m, sheet),
                            labelStyle: theme.textTheme.labelSmall!.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 9.5,
                            ),
                          ),
                        ),
                      ),
                      if (leftSide != null) ...[
                        Positioned(
                          left: 0,
                          top: 0,
                          child: _SideTag(side: leftSide),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: _SideTag(
                            side: leftSide == BodySide.right
                                ? BodySide.left
                                : BodySide.right,
                          ),
                        ),
                      ],
                      if (_hover != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: IgnorePointer(
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.inverseSurface,
                                  borderRadius: prismCorners(
                                    context,
                                    PrismTokens.radiusSmall,
                                  ),
                                ),
                                child: Text(
                                  _hover!.zoomTo != null
                                      ? (es ? 'Ampliar' : 'Zoom in')
                                      : (regionById[_hover!.regionId]?.label(
                                              es,
                                              _hover!.side,
                                            ) ??
                                            ''),
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.onInverseSurface,
                                    fontWeight: FontWeight.w700,
                                  ),
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
        );
      },
    );
  }
}

class _SideTag extends StatelessWidget {
  const _SideTag({required this.side});
  final BodySide side;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final es = _es(context);
    final left = side == BodySide.left;
    return ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: prismRound(context),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Text(
              left ? (es ? 'I' : 'L') : (es ? 'D' : 'R'),
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            left
                ? (es ? 'Su izquierda' : 'Body’s left')
                : (es ? 'Su derecha' : 'Body’s right'),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _BodyPainter extends CustomPainter {
  _BodyPainter({
    required this.sheet,
    required this.view,
    required this.side,
    required this.markers,
    required this.focusedId,
    required this.hover,
    required this.colors,
    required this.markerCenter,
    required this.labelStyle,
  });

  final BodySheet sheet;
  final BodyView view;
  final BodySide side;
  final List<MapMarker> markers;
  final String? focusedId;
  final RegionShape? hover;
  final ColorScheme colors;
  final Offset? Function(MapMarker) markerCenter;
  final TextStyle labelStyle;

  /// The Body Map look when this painter was made.
  final String themeKey = bodyMapTheme.value;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / sheet.size.width;
    canvas.save();
    canvas.scale(k);
    final style = bodyMapTheme.value;
    final contrast = style == 'contrast';
    final ink = contrast
        ? (colors.brightness == Brightness.dark ? Colors.white : Colors.black)
        : colors.onSurface;
    // Body fill: a quiet neutral figure by default, or a chosen skin tone.
    final skin = switch (style) {
      'light' => const Color(0xFFF3D5C0),
      'medium' => const Color(0xFFDDAA86),
      'tan' => const Color(0xFFC08560),
      'deep' => const Color(0xFF8A5A3C),
      'outline' => Colors.transparent,
      'contrast' =>
        colors.brightness == Brightness.dark ? Colors.black : Colors.white,
      _ => Color.alphaBlend(
        colors.primary.withValues(alpha: 0.05),
        colors.surfaceContainerHigh,
      ),
    };
    canvas.drawPath(sheet.outline, Paint()..color = skin);
    canvas.save();
    canvas.clipPath(sheet.outline);
    // Highlighted regions: whole-area spots and the hovered region.
    for (final m in markers) {
      if (m.x != null) continue;
      for (final s in sheet.shapes) {
        if (s.regionId == m.regionId &&
            (s.side == m.side ||
                s.side == BodySide.center ||
                m.side == BodySide.center)) {
          canvas.drawPath(
            s.path,
            Paint()
              ..color = colors.primary.withValues(
                alpha: m.id == focusedId ? 0.34 : 0.2,
              ),
          );
        }
      }
    }
    if (hover != null) {
      canvas.drawPath(
        hover!.path,
        Paint()..color = colors.primary.withValues(alpha: 0.12),
      );
      canvas.drawPath(
        hover!.path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 / k * 1.2
          ..color = colors.primary.withValues(alpha: 0.6),
      );
    }
    for (final d in sheet.details) {
      canvas.drawPath(
        d,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7
          ..strokeCap = StrokeCap.round
          ..color = ink.withValues(alpha: 0.18),
      );
    }
    canvas.restore();
    canvas.drawPath(
      sheet.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = contrast || style == 'outline' ? 2 : 1.3
        ..strokeJoin = StrokeJoin.round
        ..color = ink.withValues(
          alpha: contrast ? 1 : (style == 'outline' ? 0.7 : 0.42),
        ),
    );

    // Spread lines.
    for (final m in markers) {
      final from = markerCenter(m);
      if (from == null) continue;
      var prev = from;
      for (final s in m.spreads) {
        final to = (s.view == view && s.x != null && s.y != null)
            ? Offset(s.x! * sheet.size.width, s.y! * sheet.size.height)
            : (view.isFigure ? figureAnchor(s.regionId, s.side, view) : null);
        if (to == null) continue;
        _dashed(
          canvas,
          prev,
          to,
          Paint()
            ..color = colors.primary.withValues(alpha: 0.7)
            ..strokeWidth = 1.2
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(
          to,
          s.stops ? 3.2 : 2.2,
          Paint()..color = colors.primary,
        );
        if (s.stops)
          canvas.drawCircle(
            to,
            5,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = colors.primary,
          );
        prev = to;
      }
    }
    // Numbered markers.
    for (final m in markers) {
      final c = markerCenter(m);
      if (c == null) continue;
      final exact = m.view == view;
      final r = exact ? 7.0 : 4.5;
      final focused = m.id == focusedId;
      if (focused)
        canvas.drawCircle(
          c,
          r + 4,
          Paint()..color = colors.primary.withValues(alpha: 0.25),
        );
      canvas.drawCircle(c, r, Paint()..color = colors.primary);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = colors.surface,
      );
      if (exact) {
        final tp = TextPainter(
          text: TextSpan(
            text: '${m.number}',
            style: labelStyle.copyWith(color: colors.onPrimary),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
      }
    }
    canvas.restore();
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint p) {
    final d = (b - a).distance;
    if (d == 0) return;
    final dir = (b - a) / d;
    for (var t = 0.0; t < d; t += 6) {
      canvas.drawLine(a + dir * t, a + dir * (t + 3.2).clamp(0, d), p);
    }
  }

  @override
  bool shouldRepaint(_BodyPainter o) =>
      o.themeKey != themeKey ||
      o.sheet != sheet ||
      o.markers != markers ||
      o.focusedId != focusedId ||
      o.hover != hover ||
      o.colors != colors ||
      o.side != side;
}

Future<RegionShape?> _disambiguate(
  BuildContext context,
  List<RegionShape> options,
) {
  final es = _es(context);
  return PrismSheet.show<RegionShape>(
    context: context,
    title: es ? '¿Qué zona?' : 'Which area?',
    subtitle: es
        ? 'Tocaste cerca de varias zonas.'
        : 'Your tap landed between areas.',
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final o in options)
          PrismListRow(
            title: Text(
              regionById[o.regionId]?.label(es, o.side) ?? o.regionId,
            ),
            leading: Icon(PhosphorIcons.mapPin()),
            onTap: () => Navigator.of(ctx).pop(o),
          ),
      ],
    ),
  );
}

/// Map with view controls: Front/Back, detail sheets, and "Find a region".
class BodyMapPanel extends StatefulWidget {
  const BodyMapPanel({
    super.key,
    this.markers = const [],
    this.focusedId,
    this.onPick,
    this.onMarkerTap,
    this.initialView = BodyView.front,
    this.maxHeight = 480,
    this.allowSpecial = true,
  });

  final List<MapMarker> markers;
  final String? focusedId;
  final ValueChanged<BodyPick>? onPick;
  final ValueChanged<String>? onMarkerTap;
  final BodyView initialView;
  final double maxHeight;

  /// Offer Whole body / Hard to locate / Custom location in the list.
  final bool allowSpecial;

  @override
  State<BodyMapPanel> createState() => BodyMapPanelState();
}

class BodyMapPanelState extends State<BodyMapPanel> {
  late BodyView _view = widget.initialView;
  BodySide _side = BodySide.right;
  BodyView _figure = BodyView.front;

  /// Shows [view] (used when a marker in the list is focused).
  void show(BodyView view, BodySide side) => setState(() {
    _view = view;
    if (view.isZoom) {
      _side = side == BodySide.center ? BodySide.right : side;
    } else {
      _figure = view;
    }
  });

  Future<void> _findRegion() async {
    final pick = await showRegionList(
      context,
      allowSpecial: widget.allowSpecial,
    );
    if (pick == null || !mounted) return;
    final v = pick.view;
    if (v != _view && (regionById[pick.regionId]?.anchor != null))
      show(v, pick.side);
    widget.onPick?.call(pick);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final es = _es(context);
    final zoom = _view.isZoom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (zoom)
              PrismButton(
                label: es ? 'Cuerpo entero' : 'Full body',
                icon: PhosphorIcons.arrowLeft(),
                density: PrismControlDensity.compact,
                onPressed: () => setState(() => _view = _figure),
              )
            else
              Expanded(
                child: PrismSegmentedControl<BodyView>(
                  segments: [
                    PrismSegment(
                      value: BodyView.front,
                      label: es ? 'Delante' : 'Front',
                    ),
                    PrismSegment(
                      value: BodyView.back,
                      label: es ? 'Detrás' : 'Back',
                    ),
                    PrismSegment(
                      value: BodyView.side,
                      label: es ? 'Lado' : 'Side',
                    ),
                  ],
                  selected: _view,
                  onChanged: (v) => setState(() {
                    _view = _figure = v;
                    if (v == BodyView.side && _side == BodySide.center)
                      _side = BodySide.right;
                  }),
                ),
              ),
            if (zoom) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  bodyViewLabel(_view, es, _side),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const SizedBox(width: 8),
            PrismButton(
              label: es ? 'Buscar zona' : 'Find a region',
              icon: PhosphorIcons.magnifyingGlass(),
              density: PrismControlDensity.compact,
              onPressed: _findRegion,
            ),
          ],
        ),
        if (_view == BodyView.side) ...[
          const SizedBox(height: 8),
          PrismSegmentedControl<BodySide>(
            segments: [
              PrismSegment(
                value: BodySide.left,
                label: es ? 'Lado izquierdo' : 'Left side',
              ),
              PrismSegment(
                value: BodySide.right,
                label: es ? 'Lado derecho' : 'Right side',
              ),
            ],
            selected: _side == BodySide.left ? BodySide.left : BodySide.right,
            onChanged: (v) => setState(() => _side = v),
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: PrismPopupMenu<String>(
                  icon: PhosphorIcons.palette(),
                  tooltip: es ? 'Aspecto del cuerpo' : 'Body colours',
                  onSelected: (v) => setBodyMapTheme(v),
                  items: [
                    for (final e in bodyMapThemes.entries)
                      PrismMenuItem(
                        value: e.key,
                        label: es ? e.value.$2 : e.value.$1,
                        icon: bodyMapTheme.value == e.key
                            ? Icons.check
                            : Icons.circle_outlined,
                      ),
                  ],
                ),
              ),
              for (final (v, s, label) in [
                (BodyView.face, BodySide.right, es ? 'Cara' : 'Face'),
                (
                  BodyView.handPalm,
                  BodySide.left,
                  es ? 'Mano izq.' : 'Left hand',
                ),
                (
                  BodyView.handPalm,
                  BodySide.right,
                  es ? 'Mano der.' : 'Right hand',
                ),
                (
                  BodyView.footTop,
                  BodySide.left,
                  es ? 'Pie izq.' : 'Left foot',
                ),
                (
                  BodyView.footTop,
                  BodySide.right,
                  es ? 'Pie der.' : 'Right foot',
                ),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: PrismChip(
                    label: label,
                    selected: _view.isZoom && _matchesZoom(v, s),
                    onTap: () => show(v == BodyView.face ? v : _keepFace(v), s),
                  ),
                ),
            ],
          ),
        ),
        if (zoom && _view != BodyView.face) ...[
          const SizedBox(height: 8),
          PrismSegmentedControl<BodyView>(
            segments: _view == BodyView.handPalm || _view == BodyView.handBack
                ? [
                    PrismSegment(
                      value: BodyView.handPalm,
                      label: es ? 'Palma' : 'Palm',
                    ),
                    PrismSegment(
                      value: BodyView.handBack,
                      label: es ? 'Dorso' : 'Back of hand',
                    ),
                  ]
                : [
                    PrismSegment(
                      value: BodyView.footTop,
                      label: es ? 'Arriba' : 'Top',
                    ),
                    PrismSegment(
                      value: BodyView.footSole,
                      label: es ? 'Planta' : 'Sole',
                    ),
                  ],
            selected: _view,
            onChanged: (v) => setState(() => _view = v),
          ),
        ],
        const SizedBox(height: 12),
        BodyMapCanvas(
          view: _view,
          side: _side,
          markers: widget.markers,
          focusedId: widget.focusedId,
          maxHeight: zoom ? widget.maxHeight * 0.78 : widget.maxHeight,
          onZoom: (v, s) => show(v, s),
          onPick: widget.onPick,
          onMarkerTap: widget.onMarkerTap,
        ),
        if (zoom && _view == BodyView.face) ...[
          const SizedBox(height: 10),
          Text(
            es ? 'Dentro de la boca' : 'Inside the mouth',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final id in ['teeth', 'gums', 'tongue'])
                PrismChip(
                  label: regionById[id]!.label(es),
                  selected: widget.markers.any((m) => m.regionId == id),
                  onTap: () => widget.onPick?.call(
                    BodyPick(
                      regionId: id,
                      side: BodySide.center,
                      view: BodyView.face,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  bool _matchesZoom(BodyView v, BodySide s) {
    if (v == BodyView.face) return _view == BodyView.face;
    final hand = _view == BodyView.handPalm || _view == BodyView.handBack;
    final foot = _view == BodyView.footTop || _view == BodyView.footSole;
    final vHand = v == BodyView.handPalm || v == BodyView.handBack;
    return _side == s && ((hand && vHand) || (foot && !vHand));
  }

  /// Keep palm/back (or top/sole) when switching sides.
  BodyView _keepFace(BodyView v) {
    final hand = v == BodyView.handPalm || v == BodyView.handBack;
    if (hand && (_view == BodyView.handPalm || _view == BodyView.handBack))
      return _view;
    if (!hand && (_view == BodyView.footTop || _view == BodyView.footSole))
      return _view;
    return v;
  }
}

/// Searchable list of every region — the same choices as the map, usable
/// with a keyboard or screen reader.
Future<BodyPick?> showRegionList(
  BuildContext context, {
  bool allowSpecial = true,
}) => PrismSheet.showFullScreen<BodyPick>(
  context: context,
  builder: (ctx, scroll) =>
      _RegionList(scroll: scroll, allowSpecial: allowSpecial),
);

class _RegionList extends StatefulWidget {
  const _RegionList({required this.scroll, required this.allowSpecial});
  final ScrollController scroll;
  final bool allowSpecial;
  @override
  State<_RegionList> createState() => _RegionListState();
}

class _RegionListState extends State<_RegionList> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _pick(BodyRegion r, BodySide side) {
    Navigator.of(
      context,
    ).pop(BodyPick(regionId: r.id, side: side, view: preferredViewFor(r.id)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final es = _es(context);
    final results = searchRegions(_q.text, es)
        .where(
          (r) =>
              widget.allowSpecial ||
              r.section != RegionSection.general ||
              r.anchor != null,
        )
        .toList();
    final bySection = <RegionSection, List<BodyRegion>>{};
    for (final r in results) {
      bySection.putIfAbsent(r.section, () => []).add(r);
    }
    return SafeArea(
      child: Column(
        children: [
          PrismSheetTopBar(title: es ? 'Elegir zona' : 'Choose a region'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: PrismTextField(
              controller: _q,
              autofocus: true,
              hintText: es
                  ? 'Buscar (p. ej. muñeca, omóplato, meñique)'
                  : 'Search (e.g. wrist, shoulder blade, pinky)',
              prefixIcon: Icon(AppIcons.search),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Text(
                      es
                          ? 'Sin resultados. Prueba otra palabra o usa “Ubicación personalizada”.'
                          : 'No matches. Try another word, or use “Custom location”.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView(
                    controller: widget.scroll,
                    padding: EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      MediaQuery.viewInsetsOf(context).bottom + 24,
                    ),
                    children: [
                      for (final e in bySection.entries) ...[
                        PrismSectionHeader(
                          title: regionSectionLabel(e.key, es).toUpperCase(),
                        ),
                        PrismSurface(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              for (final (i, r) in e.value.indexed) ...[
                                if (i > 0)
                                  Divider(
                                    height: 1,
                                    indent: 16,
                                    color: theme.colorScheme.outlineVariant
                                        .withValues(alpha: 0.4),
                                  ),
                                _RegionRow(
                                  region: r,
                                  onPick: (side) => _pick(r, side),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _RegionRow extends StatelessWidget {
  const _RegionRow({required this.region, required this.onPick});
  final BodyRegion region;
  final ValueChanged<BodySide> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final es = _es(context);
    if (!region.sided) {
      return PrismListRow(
        title: Text(region.label(es)),
        onTap: () => onPick(BodySide.center),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(region.label(es), style: theme.textTheme.bodyLarge),
          ),
          for (final side in [BodySide.left, BodySide.right])
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: PrismButton(
                label: side == BodySide.left
                    ? (es ? 'Izquierda' : 'Left')
                    : (es ? 'Derecha' : 'Right'),
                density: PrismControlDensity.compact,
                semanticLabel: region.label(es, side),
                onPressed: () => onPick(side),
              ),
            ),
        ],
      ),
    );
  }
}

/// Body Map looks (device setting).
const bodyMapThemes = <String, (String, String)>{
  'soft': ('Soft (follows theme)', 'Suave (según el tema)'),
  'light': ('Light skin tone', 'Tono de piel claro'),
  'medium': ('Medium skin tone', 'Tono de piel medio'),
  'tan': ('Tan skin tone', 'Tono de piel bronceado'),
  'deep': ('Deep skin tone', 'Tono de piel oscuro'),
  'outline': ('Outline only', 'Solo contorno'),
  'contrast': ('High contrast', 'Alto contraste'),
};

final bodyMapTheme = ValueNotifier<String>('soft');
bool _bodyThemeLoaded = false;

Future<void> loadBodyMapTheme() async {
  if (_bodyThemeLoaded) return;
  _bodyThemeLoaded = true;
  try {
    final v = (await SharedPreferences.getInstance()).getString(
      'bodymap.theme',
    );
    if (v != null && bodyMapThemes.containsKey(v)) bodyMapTheme.value = v;
  } catch (_) {}
}

Future<void> setBodyMapTheme(String v) async {
  bodyMapTheme.value = v;
  try {
    await (await SharedPreferences.getInstance()).setString('bodymap.theme', v);
  } catch (_) {}
}
