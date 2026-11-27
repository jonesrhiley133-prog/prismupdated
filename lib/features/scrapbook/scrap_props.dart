import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:prism_plurality/features/experiences/color_sheet.dart';
import 'package:prism_plurality/features/scrapbook/scrap_editor_core.dart';
import 'package:prism_plurality/features/scrapbook/scrap_frames.dart';
import 'package:prism_plurality/features/scrapbook/scrap_models.dart';
import 'package:prism_plurality/features/scrapbook/scrap_seasonal_ui.dart';
import 'package:prism_plurality/features/scrapbook/scrap_shapes.dart';
import 'package:prism_plurality/shared/fonts/font_browser.dart';
import 'package:prism_plurality/shared/pickers/style_pickers.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

const scrapSwatches = <int>[
  0xFFFFFFFF,
  0xFF000000,
  0xFFE74C3C,
  0xFFFF7A9C,
  0xFFF39C12,
  0xFFF1C40F,
  0xFF2ECC71,
  0xFF1ABC9C,
  0xFF3498DB,
  0xFF9B59B6,
  0xFFD4AF37,
  0xFF7A4E2D,
  0xFF2C3E50,
  0xFFFFF3A3,
];

/// A labelled slider that previews live and records one undo step on release.
class ScrapSlider extends StatelessWidget {
  const ScrapSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onEnd,
    this.display,
  });
  final String label;
  final double value, min, max;
  final ValueChanged<double> onChanged;
  final VoidCallback onEnd;
  final String? display;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 96,
        child: Text(label, style: Theme.of(context).textTheme.bodySmall),
      ),
      Expanded(
        child: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
          onChangeEnd: (_) => onEnd(),
        ),
      ),
      SizedBox(
        width: 44,
        child: Text(
          display ?? value.toStringAsFixed(1),
          textAlign: TextAlign.end,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
    ],
  );
}

/// A colour field: quick swatches, a custom picker, and an optional "none".
class ScrapColorField extends StatelessWidget {
  const ScrapColorField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.onClear,
  });
  final String label;
  final int? value;
  final ValueChanged<int> onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        ColorChoiceRow(
          value: value,
          colors: scrapSwatches,
          onChanged: onChanged,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            PrismButton(
              label: tr(context, 'Custom colour', 'Color personalizado'),
              icon: Icons.palette_outlined,
              density: PrismControlDensity.compact,
              onPressed: () async {
                final c = await showPrismColorPicker(
                  context: context,
                  initial: Color(value ?? 0xFFFFFFFF),
                );
                if (c != null) onChanged(c.toARGB32());
              },
            ),
            if (onClear != null && value != null)
              PrismButton(
                label: tr(context, 'None', 'Ninguno'),
                density: PrismControlDensity.compact,
                onPressed: onClear!,
              ),
          ],
        ),
      ],
    ),
  );
}

/// Everything you can change about one element, in one sheet — used by
/// both covers and pages.
Future<void> showScrapElementProps(
  BuildContext context,
  ScrapEditorController ctrl,
  ScrapElement e,
) => PrismSheet.show<void>(
  context: context,
  title: tr(context, 'Element settings', 'Ajustes del elemento'),
  maxHeightFactor: 0.9,
  builder: (_) => _Props(ctrl: ctrl, e: e),
);

class _Props extends StatefulWidget {
  const _Props({required this.ctrl, required this.e});
  final ScrapEditorController ctrl;
  final ScrapElement e;
  @override
  State<_Props> createState() => _PropsState();
}

class _PropsState extends State<_Props> {
  ScrapEditorController get c => widget.ctrl;
  ScrapElement get e => widget.e;

  void live(VoidCallback f) {
    f();
    c.refresh();
    setState(() {});
  }

  void done(VoidCallback f) {
    f();
    c.commit();
    setState(() {});
  }

  Widget sec(String t) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 4),
    child: Text(t, style: Theme.of(context).textTheme.titleSmall),
  );

  Future<void> _pickShape() async {
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
    if (id != null) done(() => e.text = id);
  }

  Future<void> _pickFrame() async {
    final id = await PrismSheet.show<String>(
      context: context,
      title: tr(context, 'Frames', 'Marcos'),
      maxHeightFactor: 0.9,
      builder: (ctx) => ScrapFrameBrowser(
        current: e.opt<String>('fr2', ''),
        onPick: (id) => Navigator.pop(ctx, id),
      ),
    );
    if (id == null) return;
    done(() => id.isEmpty ? e.setOpt('fr2', null) : e.setOpt('fr2', id));
  }

  @override
  Widget build(BuildContext context) {
    final isText = e.type == ScrapType.text || e.type == ScrapType.note;
    final isShape = e.type == ScrapType.shape;
    final isMedia =
        e.type == ScrapType.photo ||
        e.type == ScrapType.video ||
        e.type == ScrapType.drawing;
    final fit = ScrapImageFit.fromJson(e.opts['fit']);
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      children: [
        if (isText) ...[
          PrismTextField(
            initialValue: e.text == '{title}' || e.text == '{subtitle}'
                ? ''
                : e.text,
            labelText: e.text == '{title}'
                ? tr(
                    context,
                    'Shows the book title (type to replace)',
                    'Muestra el título (escribe para reemplazar)',
                  )
                : tr(context, 'Text', 'Texto'),
            maxLines: 4,
            minLines: 2,
            onChanged: (v) => live(() => e.text = v),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PrismButton(
                label: tr(context, 'Font', 'Fuente'),
                icon: Icons.text_fields,
                onPressed: () async {
                  final p = await showPrismFontBrowser(
                    context,
                    current: e.font,
                    allowDefault: false,
                  );
                  if (p?.key != null) done(() => e.font = p!.key);
                },
              ),
              PrismChip(
                label: tr(context, 'Bold', 'Negrita'),
                selected: e.opt<bool>('bd', false),
                onTap: () => done(
                  () => e.setOpt('bd', e.opt<bool>('bd', false) ? null : true),
                ),
              ),
              PrismChip(
                label: tr(context, 'Italic', 'Cursiva'),
                selected: e.opt<bool>('it', false),
                onTap: () => done(
                  () => e.setOpt('it', e.opt<bool>('it', false) ? null : true),
                ),
              ),
              for (final a in const ['left', 'center', 'right'])
                PrismChip(
                  label: switch (a) {
                    'left' => tr(context, 'Left', 'Izq.'),
                    'center' => tr(context, 'Centre', 'Centro'),
                    _ => tr(context, 'Right', 'Der.'),
                  },
                  selected: e.opt<String>('ta', 'left') == a,
                  onTap: () => done(() => e.setOpt('ta', a)),
                ),
            ],
          ),
          ScrapSlider(
            label: tr(context, 'Size', 'Tamaño'),
            value: e.size,
            min: 0.4,
            max: 6,
            onChanged: (v) => live(() => e.size = v),
            onEnd: c.commit,
          ),
          ScrapSlider(
            label: tr(context, 'Letter gap', 'Espaciado'),
            value: e.opt<double>('ls', 0),
            min: -2,
            max: 12,
            onChanged: (v) => live(() => e.setOpt('ls', v)),
            onEnd: c.commit,
          ),
          PrismSwitchRow(
            title: tr(context, 'Shrink to fit the box', 'Ajustar al cuadro'),
            value: e.opt<bool>('shrink', false),
            onChanged: (v) => done(() => e.setOpt('shrink', v ? true : null)),
            padding: EdgeInsets.zero,
          ),
          ScrapColorField(
            label: tr(context, 'Text colour', 'Color del texto'),
            value: e.color,
            onChanged: (v) => done(() => e.color = v),
          ),
        ],
        if (e.type == ScrapType.markdown) ...[
          ScrapSlider(
            label: tr(context, 'Text size', 'Tamaño del texto'),
            value: e.size,
            min: 0.4,
            max: 3,
            onChanged: (v) => live(() => e.size = v),
            onEnd: c.commit,
          ),
          ScrapColorField(
            label: tr(context, 'Text colour', 'Color del texto'),
            value: e.color,
            onChanged: (v) => done(() => e.color = v),
            onClear: () => done(() => e.color = null),
          ),
        ],
        if (isShape) ...[
          sec(tr(context, 'Shape', 'Forma')),
          Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: CustomPaint(
                  painter: ScrapShapePainter(
                    shape: e.text ?? 'heart',
                    fill: Color(e.color ?? 0xFFE74C3C),
                    fill2: e.opt<int>('c2', 0) == 0
                        ? null
                        : Color(e.opt<int>('c2', 0)),
                    border: e.opt<int>('bc', 0) == 0
                        ? null
                        : Color(e.opt<int>('bc', 0)),
                    borderWidth: e.opt<double>('bw', 0),
                    filled: !e.opt<bool>('nf', false),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              PrismButton(
                label: tr(context, 'Change shape', 'Cambiar forma'),
                icon: Icons.category_outlined,
                onPressed: _pickShape,
              ),
            ],
          ),
          PrismSwitchRow(
            title: tr(context, 'Outline only', 'Solo contorno'),
            value: e.opt<bool>('nf', false),
            onChanged: (v) => done(() {
              e.setOpt('nf', v ? true : null);
              if (v && e.opt<double>('bw', 0) == 0) e.setOpt('bw', 2.0);
              if (v && e.opt<int>('bc', 0) == 0)
                e.setOpt('bc', e.color ?? 0xFFE74C3C);
            }),
            padding: EdgeInsets.zero,
          ),
          if (!e.opt<bool>('nf', false))
            ScrapColorField(
              label: tr(context, 'Fill', 'Relleno'),
              value: e.color,
              onChanged: (v) => done(() => e.color = v),
            ),
          if (!e.opt<bool>('nf', false))
            ScrapColorField(
              label: tr(context, 'Gradient to', 'Degradado a'),
              value: e.opt<int>('c2', 0) == 0 ? null : e.opt<int>('c2', 0),
              onChanged: (v) => done(() => e.setOpt('c2', v)),
              onClear: () => done(() => e.setOpt('c2', null)),
            ),
          ScrapColorField(
            label: tr(context, 'Border', 'Borde'),
            value: e.opt<int>('bc', 0) == 0 ? null : e.opt<int>('bc', 0),
            onChanged: (v) => done(() {
              e.setOpt('bc', v);
              if (e.opt<double>('bw', 0) == 0) e.setOpt('bw', 2.0);
            }),
            onClear: () => done(() {
              e.setOpt('bc', null);
              e.setOpt('bw', null);
            }),
          ),
          ScrapSlider(
            label: tr(context, 'Border width', 'Grosor'),
            value: e.opt<double>('bw', 0),
            min: 0,
            max: 14,
            onChanged: (v) => live(() => e.setOpt('bw', v)),
            onEnd: c.commit,
          ),
          ScrapSlider(
            label: tr(context, 'Shadow', 'Sombra'),
            value: e.opt<double>('sh', 0),
            min: 0,
            max: 16,
            onChanged: (v) => live(() => e.setOpt('sh', v)),
            onEnd: c.commit,
          ),
        ],
        if (e.type == ScrapType.sticker || e.type == ScrapType.tape)
          ScrapColorField(
            label: tr(
              context,
              'Tint (shape and lettering stickers)',
              'Tinte (formas y letras)',
            ),
            value: e.color,
            onChanged: (v) => done(() => e.color = v),
            onClear: () => done(() => e.color = null),
          ),
        if (isMedia) ...[
          sec(tr(context, 'Frame', 'Marco')),
          Row(
            children: [
              PrismButton(
                label:
                    scrapFrameById(e.opt<String>('fr2', ''))?.name ??
                    tr(context, 'Choose a frame', 'Elegir un marco'),
                icon: Icons.crop_original,
                onPressed: _pickFrame,
              ),
              const SizedBox(width: 8),
              if (e.opt<String>('fr2', '').isNotEmpty)
                PrismButton(
                  label: tr(context, 'No frame', 'Sin marco'),
                  density: PrismControlDensity.compact,
                  onPressed: () => done(() {
                    e.setOpt('fr2', null);
                    e.setOpt('fit', null);
                  }),
                ),
            ],
          ),
          if (e.opt<String>('fr2', '').isNotEmpty) ...[
            ScrapSlider(
              label: tr(context, 'Zoom picture', 'Zoom'),
              value: fit.zoom,
              min: 1,
              max: 4,
              onChanged: (v) => live(
                () => e.setOpt(
                  'fit',
                  ScrapImageFit(zoom: v, dx: fit.dx, dy: fit.dy).toJson(),
                ),
              ),
              onEnd: c.commit,
            ),
            ScrapSlider(
              label: tr(context, 'Move left/right', 'Mover ←→'),
              value: fit.dx,
              min: -1,
              max: 1,
              onChanged: (v) => live(
                () => e.setOpt(
                  'fit',
                  ScrapImageFit(zoom: fit.zoom, dx: v, dy: fit.dy).toJson(),
                ),
              ),
              onEnd: c.commit,
            ),
            ScrapSlider(
              label: tr(context, 'Move up/down', 'Mover ↑↓'),
              value: fit.dy,
              min: -1,
              max: 1,
              onChanged: (v) => live(
                () => e.setOpt(
                  'fit',
                  ScrapImageFit(zoom: fit.zoom, dx: fit.dx, dy: v).toJson(),
                ),
              ),
              onEnd: c.commit,
            ),
          ],
        ],
        sec(tr(context, 'Look', 'Aspecto')),
        ScrapSlider(
          label: tr(context, 'Transparency', 'Opacidad'),
          value: e.opacity,
          min: 0.05,
          max: 1,
          onChanged: (v) => live(() => e.opacity = v),
          onEnd: c.commit,
          display: '${(e.opacity * 100).round()}%',
        ),
        ScrapSlider(
          label: tr(context, 'Rotation', 'Rotación'),
          value: (e.rot * 180 / math.pi) % 360,
          min: 0,
          max: 360,
          onChanged: (v) => live(() => e.rot = v * math.pi / 180),
          onEnd: c.commit,
          display: '${((e.rot * 180 / math.pi) % 360).round()}°',
        ),
        if (!isShape)
          ScrapSlider(
            label: tr(context, 'Shadow', 'Sombra'),
            value: e.opt<double>('shd', 0),
            min: 0,
            max: 3,
            onChanged: (v) => live(() => e.setOpt('shd', v)),
            onEnd: c.commit,
          ),
        if (!isShape)
          ScrapSlider(
            label: tr(context, 'Outline', 'Contorno'),
            value: e.opt<double>('ow', 0),
            min: 0,
            max: 6,
            onChanged: (v) => live(() => e.setOpt('ow', v)),
            onEnd: c.commit,
          ),
        if (!isShape && e.opt<double>('ow', 0) > 0)
          ScrapColorField(
            label: tr(context, 'Outline colour', 'Color del contorno'),
            value: e.opt<int>('oc', 0xFFFFFFFF),
            onChanged: (v) => done(() => e.setOpt('oc', v)),
          ),
      ],
    );
  }
}
