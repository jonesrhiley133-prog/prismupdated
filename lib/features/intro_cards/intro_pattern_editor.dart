import 'package:prism_plurality/features/experiences/color_sheet.dart';
import 'package:prism_plurality/features/intro_cards/intro_patterns.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Ready-made pattern looks to start from.
final introPatternPresets = <String, IntroPattern>{
  'Starry night': const IntroPattern(
    kind: 'stars',
    opacity: 0.28,
    density: 1.4,
    variety: 0.8,
    layer2: IntroPattern(
      kind: 'sparkles',
      opacity: 0.2,
      density: 0.5,
      scale: 1.3,
    ),
  ),
  'Cottage garden': const IntroPattern(
    kind: 'flowers',
    opacity: 0.22,
    density: 1.2,
    layer2: IntroPattern(kind: 'leaves', opacity: 0.16, density: 0.8),
  ),
  'Picnic': const IntroPattern(kind: 'gingham', opacity: 0.18, scale: 1.2),
  'Old map': const IntroPattern(
    kind: 'topographic',
    opacity: 0.2,
    stroke: 0.9,
    layer2: IntroPattern(kind: 'constellation', opacity: 0.25),
  ),
  'Art deco': const IntroPattern(
    kind: 'fans',
    opacity: 0.22,
    stroke: 1,
    placement: 'border',
  ),
  'Candy shop': const IntroPattern(
    kind: 'sprinkles',
    opacity: 0.35,
    density: 1.6,
    variety: 1,
  ),
  'Spooky': const IntroPattern(
    kind: 'bats',
    opacity: 0.25,
    density: 0.9,
    layer2: IntroPattern(kind: 'moons', opacity: 0.18, density: 0.4),
  ),
  'Ocean': const IntroPattern(
    kind: 'wavelines',
    opacity: 0.2,
    layer2: IntroPattern(
      kind: 'bubbles',
      opacity: 0.25,
      filled: false,
      density: 0.7,
    ),
  ),
  'Winter': const IntroPattern(
    kind: 'snowflakes',
    opacity: 0.3,
    density: 1.1,
    fade: 'bottom',
  ),
  'Corner flourish': const IntroPattern(
    kind: 'swirls',
    opacity: 0.3,
    placement: 'corners',
    scale: 1.6,
  ),
  'Retro sun': const IntroPattern(
    kind: 'sunburst',
    opacity: 0.12,
    density: 0.7,
    fade: 'edges',
  ),
  'Paw trail': const IntroPattern(
    kind: 'paws',
    opacity: 0.22,
    jitter: 0.3,
    rotation: -25,
  ),
};

/// Every pattern setting, with live previews. Works without precise
/// gestures: chips, sliders and buttons only.
class IntroPatternEditor extends StatefulWidget {
  const IntroPatternEditor({
    super.key,
    required this.value,
    required this.onChanged,
    required this.bg1,
    required this.bg2,
    required this.ink,
    this.allowLayer2 = true,
  });
  final IntroPattern value;
  final ValueChanged<IntroPattern> onChanged;
  final Color bg1, bg2, ink;
  final bool allowLayer2;
  @override
  State<IntroPatternEditor> createState() => _IntroPatternEditorState();
}

class _IntroPatternEditorState extends State<IntroPatternEditor> {
  String _tab = 'Motifs';
  bool _layer2 = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = widget.value;
    final editing = _layer2 && v.layer2 != null ? v.layer2! : v;
    void put(IntroPattern p) => widget.onChanged(
      _layer2 && v.layer2 != null ? v.copyWith(layer2: p) : p,
    );
    Widget slider(
      String label,
      double value,
      double min,
      double max,
      String Function(double) fmt,
      IntroPattern Function(double) on,
    ) => Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(label, style: theme.textTheme.bodySmall),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: (x) => put(on(x)),
            semanticFormatterCallback: (x) => '$label ${fmt(x)}',
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(fmt(value), style: theme.textTheme.labelSmall),
        ),
      ],
    );
    final names = _tab == 'Motifs'
        ? introMotifs
        : (_tab == 'Tiles' ? introTiles : const <String, String>{});
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(context, 'Presets', 'Preajustes'),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 74,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final e in introPatternPresets.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => widget.onChanged(e.value),
                    child: Semantics(
                      button: true,
                      label: e.key,
                      child: Column(
                        children: [
                          IntroPatternSwatch(
                            pattern: e.value,
                            bg1: widget.bg1,
                            bg2: widget.bg2,
                            ink: widget.ink,
                          ),
                          Text(e.key, style: theme.textTheme.labelSmall),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (widget.allowLayer2) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              PrismChip(
                label: tr(context, 'Main pattern', 'Patrón principal'),
                selected: !_layer2,
                onTap: () => setState(() => _layer2 = false),
              ),
              PrismChip(
                label: v.layer2 == null
                    ? tr(context, '+ Second layer', '+ Segunda capa')
                    : tr(context, 'Second layer', 'Segunda capa'),
                selected: _layer2,
                onTap: () {
                  if (v.layer2 == null)
                    widget.onChanged(
                      v.copyWith(
                        layer2: const IntroPattern(
                          kind: 'dots',
                          opacity: 0.14,
                          density: 0.6,
                        ),
                      ),
                    );
                  setState(() => _layer2 = true);
                },
              ),
              if (_layer2 && v.layer2 != null)
                PrismButton(
                  label: tr(context, 'Remove layer', 'Quitar capa'),
                  density: PrismControlDensity.compact,
                  onPressed: () {
                    widget.onChanged(v.copyWith(clearLayer2: true));
                    setState(() => _layer2 = false);
                  },
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: [
            for (final t in const ['Motifs', 'Tiles'])
              PrismChip(
                label: t == 'Motifs'
                    ? tr(
                        context,
                        'Motifs (${introMotifs.length})',
                        'Motivos (${introMotifs.length})',
                      )
                    : tr(
                        context,
                        'Tiled (${introTiles.length})',
                        'Mosaicos (${introTiles.length})',
                      ),
                selected: _tab == t,
                onTap: () => setState(() => _tab = t),
              ),
            PrismChip(
              label: tr(context, 'None', 'Ninguno'),
              selected: editing.kind == 'none',
              onTap: () => put(editing.copyWith(kind: 'none')),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 170,
          child: GridView.extent(
            maxCrossAxisExtent: 82,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1.05,
            children: [
              for (final e in names.entries)
                GestureDetector(
                  onTap: () => put(editing.copyWith(kind: e.key)),
                  child: Semantics(
                    button: true,
                    selected: editing.kind == e.key,
                    label: e.value,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: prismCorners(context, 10),
                        border: Border.all(
                          color: editing.kind == e.key
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Column(
                        children: [
                          IntroPatternSwatch(
                            pattern: editing.copyWith(
                              kind: e.key,
                              placement: 'all',
                              fade: 'none',
                              clearLayer2: true,
                            ),
                            bg1: widget.bg1,
                            bg2: widget.bg2,
                            ink: widget.ink,
                            width: 74,
                            height: 50,
                          ),
                          Text(
                            e.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (editing.kind != 'none') ...[
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 92,
                child: Text(
                  tr(context, 'Colour', 'Color'),
                  style: theme.textTheme.bodySmall,
                ),
              ),
              GestureDetector(
                onTap: () async {
                  final c = await showPrismColorPicker(
                    context: context,
                    initial: editing.color == null
                        ? widget.ink
                        : Color(editing.color!),
                    title: tr(context, 'Pattern colour', 'Color del patrón'),
                  );
                  if (c != null) put(editing.copyWith(color: c.toARGB32()));
                },
                child: Semantics(
                  button: true,
                  label: tr(context, 'Pattern colour', 'Color del patrón'),
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: editing.color == null
                        ? widget.ink
                        : Color(editing.color!),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (editing.color != null)
                PrismButton(
                  label: tr(
                    context,
                    'Use border colour',
                    'Usar color del borde',
                  ),
                  density: PrismControlDensity.compact,
                  onPressed: () => put(editing.copyWith(clearColor: true)),
                ),
              const Spacer(),
              PrismButton(
                label: tr(context, 'Shuffle', 'Mezclar'),
                icon: Icons.shuffle,
                density: PrismControlDensity.compact,
                onPressed: () => put(editing.copyWith(seed: editing.seed + 1)),
              ),
            ],
          ),
          slider(
            tr(context, 'Opacity', 'Opacidad'),
            editing.opacity,
            0.02,
            1,
            (x) => '${(x * 100).round()}%',
            (x) => editing.copyWith(opacity: x),
          ),
          slider(
            tr(context, 'Size', 'Tamaño'),
            editing.scale,
            0.3,
            3,
            (x) => '${x.toStringAsFixed(1)}×',
            (x) => editing.copyWith(scale: x),
          ),
          slider(
            tr(context, 'Density', 'Densidad'),
            editing.density,
            0.2,
            3,
            (x) => '${x.toStringAsFixed(1)}×',
            (x) => editing.copyWith(density: x),
          ),
          slider(
            tr(context, 'Rotation', 'Rotación'),
            editing.rotation,
            -180,
            180,
            (x) => '${x.round()}°',
            (x) => editing.copyWith(rotation: x.roundToDouble()),
          ),
          slider(
            tr(context, 'Line width', 'Grosor'),
            editing.stroke,
            0.4,
            5,
            (x) => x.toStringAsFixed(1),
            (x) => editing.copyWith(stroke: x),
          ),
          if (introMotifs.containsKey(editing.kind)) ...[
            slider(
              tr(context, 'Scatter', 'Dispersión'),
              editing.jitter,
              0,
              1,
              (x) => x == 0
                  ? tr(context, 'Grid', 'Rejilla')
                  : '${(x * 100).round()}%',
              (x) => editing.copyWith(jitter: x),
            ),
            slider(
              tr(context, 'Size variety', 'Variedad'),
              editing.variety,
              0,
              1,
              (x) => '${(x * 100).round()}%',
              (x) => editing.copyWith(variety: x),
            ),
            PrismSwitchRow(
              title: tr(context, 'Filled shapes', 'Formas rellenas'),
              subtitle: tr(
                context,
                'Off draws outlines',
                'Desactivado: solo contornos',
              ),
              value: editing.filled,
              onChanged: (x) => put(editing.copyWith(filled: x)),
            ),
          ],
          const SizedBox(height: 6),
          Text(tr(context, 'Where', 'Dónde'), style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in introPlacements.entries)
                PrismChip(
                  label: e.value,
                  selected: editing.placement == e.key,
                  onTap: () => put(editing.copyWith(placement: e.key)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tr(context, 'Fade', 'Desvanecer'),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in introFades.entries)
                PrismChip(
                  label: e.value,
                  selected: editing.fade == e.key,
                  onTap: () => put(editing.copyWith(fade: e.key)),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
