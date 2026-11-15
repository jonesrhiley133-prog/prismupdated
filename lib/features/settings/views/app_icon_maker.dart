import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

import 'package:prism_plurality/core/app_icon/app_icon.dart';
import 'package:prism_plurality/core/app_icon/custom_icon.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Opens the custom icon designer.
Future<void> showAppIconMaker(BuildContext context) => PrismSheet.showFullScreen(context: context, builder: (ctx, scroll) => _Maker(scroll: scroll));

String _auraLabel(BuildContext c, IconAura a) => switch (a) {
  IconAura.none => tr(c, 'None', 'Ninguna'),
  IconAura.glow => tr(c, 'Glow', 'Brillo'),
  IconAura.halo => tr(c, 'Halo', 'Halo'),
  IconAura.rays => tr(c, 'Rays', 'Rayos'),
  IconAura.stars => tr(c, 'Stars', 'Estrellas'),
  IconAura.nebula => tr(c, 'Nebula', 'Nebulosa'),
};

const _darks = [0xFF0B0716, 0xFF120A24, 0xFF0B1A3A, 0xFF04121E, 0xFF062818, 0xFF1A0703, 0xFF2A1A08, 0xFF3B1530, 0xFF050507, 0xFF2B1B5A, 0xFF4D355B, 0xFF16325C, 0xFFF08A5D, 0xFFF7F3EE];
const _auras = [0xFFB98CFF, 0xFFFF6FB5, 0xFF6FA8FF, 0xFF2CFFB0, 0xFF3CF2E0, 0xFFFFC24A, 0xFFFF5A1F, 0xFFFFE7A8, 0xFFEAF0FF, 0xFF8A5BFF, 0xFFFF9A2E, 0xFF7BFFC0];

const _symbolColors = [0xFFFFFFFF, 0xFFF3ECFF, 0xFFFFE7A8, 0xFFFFD0E4, 0xFFC8FFF8, 0xFFDDF8FF, 0xFFD9FFE8, 0xFFB98CFF, 0xFFFF6FB5, 0xFF6FA8FF, 0xFFFFC24A, 0xFF111111];

class _Maker extends ConsumerStatefulWidget {
  const _Maker({required this.scroll});
  final ScrollController scroll;
  @override
  ConsumerState<_Maker> createState() => _MakerState();
}

class _MakerState extends ConsumerState<_Maker> {
  CustomIconSpec _spec = const CustomIconSpec();
  Uint8List? _preview;
  final _emoji = TextEditingController(text: '✨');
  bool _busy = false;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    ref.read(appIconServiceProvider).customSpec().then((s) {
      if (!mounted) return;
      if (s != null) {
        _spec = s;
        _emoji.text = s.emoji;
      }
      _render();
    });
  }

  @override
  void dispose() {
    _emoji.dispose();
    super.dispose();
  }

  Future<void> _render() async {
    final gen = ++_gen;
    final png = await renderCustomIcon(_spec, size: 384);
    if (mounted && gen == _gen) setState(() => _preview = png);
  }

  void _update(CustomIconSpec s) {
    setState(() => _spec = s);
    _render();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget label(String t) => Padding(padding: const EdgeInsets.fromLTRB(0, 16, 0, 8), child: Text(t, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)));
    return ListView(
      controller: widget.scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(tr(context, 'Design your icon', 'Diseña tu icono'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        Center(
          child: Semantics(
            image: true,
            label: tr(context, 'Icon preview', 'Vista previa del icono'),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(44),
              child: SizedBox(
                width: 180,
                height: 180,
                child: _preview == null ? ColoredBox(color: Color(_spec.bottom)) : Image.memory(_preview!, gaplessPlayback: true, filterQuality: FilterQuality.medium),
              ),
            ),
          ),
        ),
        label(tr(context, 'Center', 'Centro')),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            PrismChip(label: tr(context, 'Prism', 'Prism'), selected: _spec.center == IconCenter.prism, onTap: () => _update(_spec.copyWith(center: IconCenter.prism))),
            PrismChip(label: tr(context, 'Symbol', 'Símbolo'), selected: _spec.center == IconCenter.symbol, onTap: () => _update(_spec.copyWith(center: IconCenter.symbol))),
            PrismChip(label: tr(context, 'Emoji', 'Emoji'), selected: _spec.center == IconCenter.emoji, onTap: () => _update(_spec.copyWith(center: IconCenter.emoji))),
            PrismChip(
              label: tr(context, 'Photo', 'Foto'),
              selected: _spec.center == IconCenter.photo,
              onTap: () async {
                final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024);
                if (x == null) return;
                _update(_spec.copyWith(center: IconCenter.photo, photo: await x.readAsBytes()));
              },
            ),
          ],
        ),
        if (_spec.center == IconCenter.symbol) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in iconSymbols.entries)
                Semantics(
                  button: true,
                  selected: _spec.symbol == e.key,
                  label: e.key,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _update(_spec.copyWith(symbol: e.key)),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: _spec.symbol == e.key ? theme.colorScheme.primary.withValues(alpha: 0.18) : theme.colorScheme.surfaceContainerHigh,
                        border: Border.all(color: _spec.symbol == e.key ? theme.colorScheme.primary : Colors.transparent, width: 2),
                      ),
                      child: Icon(e.value, size: 24),
                    ),
                  ),
                ),
            ],
          ),
          label(tr(context, 'Symbol color', 'Color del símbolo')),
          ColorChoiceRow(value: _spec.symbolColor, colors: _symbolColors, onChanged: (v) => _update(_spec.copyWith(symbolColor: v))),
          HsvSliders(value: _spec.symbolColor, onChanged: (v) => _update(_spec.copyWith(symbolColor: v))),
        ],
        if (_spec.center == IconCenter.emoji)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: PrismTextField(controller: _emoji, labelText: tr(context, 'Emoji or symbol', 'Emoji o símbolo'), maxLength: 4, onChanged: (v) => _update(_spec.copyWith(emoji: v.trim()))),
          ),
        label(tr(context, 'Aura', 'Aura')),
        Wrap(spacing: 6, runSpacing: 6, children: [for (final a in IconAura.values) PrismChip(label: _auraLabel(context, a), selected: _spec.aura == a, onTap: () => _update(_spec.copyWith(aura: a)))]),
        if (_spec.aura != IconAura.none) ...[
          const SizedBox(height: 10),
          ColorChoiceRow(value: _spec.auraColor, colors: _auras, onChanged: (v) => _update(_spec.copyWith(auraColor: v))),
          HsvSliders(value: _spec.auraColor, onChanged: (v) => _update(_spec.copyWith(auraColor: v))),
        ],
        label(tr(context, 'Background', 'Fondo')),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            PrismChip(label: tr(context, 'Gradient', 'Degradado'), selected: _spec.background == IconBackground.linear, onTap: () => _update(_spec.copyWith(background: IconBackground.linear))),
            PrismChip(label: tr(context, 'Radial', 'Radial'), selected: _spec.background == IconBackground.radial, onTap: () => _update(_spec.copyWith(background: IconBackground.radial))),
            PrismChip(label: tr(context, 'Solid', 'Sólido'), selected: _spec.background == IconBackground.solid, onTap: () => _update(_spec.copyWith(background: IconBackground.solid))),
          ],
        ),
        label(_spec.background == IconBackground.solid
            ? tr(context, 'Background color', 'Color de fondo')
            : _spec.background == IconBackground.radial
            ? tr(context, 'Background — center', 'Fondo — centro')
            : tr(context, 'Background — top', 'Fondo — arriba')),
        ColorChoiceRow(value: _spec.top, colors: _darks, onChanged: (v) => _update(_spec.copyWith(top: v))),
        HsvSliders(value: _spec.top, onChanged: (v) => _update(_spec.copyWith(top: v))),
        if (_spec.background != IconBackground.solid) ...[
          label(_spec.background == IconBackground.radial ? tr(context, 'Background — edges', 'Fondo — bordes') : tr(context, 'Background — bottom', 'Fondo — abajo')),
          ColorChoiceRow(value: _spec.bottom, colors: _darks, onChanged: (v) => _update(_spec.copyWith(bottom: v))),
          HsvSliders(value: _spec.bottom, onChanged: (v) => _update(_spec.copyWith(bottom: v))),
        ],
        const SizedBox(height: 20),
        PrismButton(
          label: kIsWeb ? tr(context, 'Use this icon', 'Usar este icono') : tr(context, 'Add to home screen', 'Añadir a la pantalla de inicio'),
          icon: PhosphorIcons.check(),
          tone: PrismButtonTone.filled,
          isLoading: _busy,
          onPressed: () async {
            setState(() => _busy = true);
            final ok = await ref.read(appIconProvider.notifier).selectCustom(_spec);
            if (!context.mounted) return;
            setState(() => _busy = false);
            PrismToast.show(
              context,
              message: ok
                  ? (kIsWeb ? tr(context, 'Icon updated', 'Icono actualizado') : tr(context, 'Confirm to add your icon to the home screen', 'Confirma para añadir tu icono a la pantalla de inicio'))
                  : tr(context, 'This launcher doesn’t support custom icons.', 'Este lanzador no admite iconos personalizados.'),
              icon: ok ? PhosphorIcons.check() : PhosphorIcons.warning(),
            );
            if (ok) Navigator.of(context).pop();
          },
        ),
        const SizedBox(height: 8),
        Text(
          kIsWeb
              ? tr(context, 'Shown on this browser tab and in the sidebar.', 'Se muestra en esta pestaña y en la barra lateral.')
              : tr(context, 'Android only lets apps switch between built-in icons, so your design is added as a home-screen shortcut that opens Prism. You can then remove the old icon from your home screen.', 'Android solo permite cambiar entre iconos incluidos, así que tu diseño se añade como acceso directo que abre Prism. Después puedes quitar el icono anterior de la pantalla de inicio.'),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
