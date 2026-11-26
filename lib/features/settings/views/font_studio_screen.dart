import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/shared/fonts/font_browser.dart';
import 'package:prism_plurality/shared/fonts/font_catalog.dart';
import 'package:prism_plurality/shared/fonts/font_prefs.dart';
import 'package:prism_plurality/shared/fonts/prism_fonts.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Font Studio: pick a font for the whole app or for individual places,
/// and tune weight, spacing, line height and size.
class FontStudioScreen extends ConsumerStatefulWidget {
  const FontStudioScreen({super.key});
  @override
  ConsumerState<FontStudioScreen> createState() => _FontStudioScreenState();
}

class _FontStudioScreenState extends ConsumerState<FontStudioScreen> {
  String _nameOf(FontPrefs prefs, String? key) {
    if (key == null) return tr(context, 'Default', 'Predeterminada');
    if (PrismFonts.isCatalog(key)) return PrismFonts.familyOf(key);
    final i = prefs.imported.where((f) => f.key == key).firstOrNull;
    return i?.name ?? tr(context, 'Imported font', 'Fuente importada');
  }

  Future<void> _choose(FontSurface s) async {
    final prefs = ref.read(fontPrefsProvider);
    final pick = await showPrismFontBrowser(
      context,
      current: prefs.of(s).family,
      allowDefault: true,
      defaultLabel: s == FontSurface.global
          ? tr(context, 'Prism default', 'Predeterminada de Prism')
          : tr(context, 'Same as whole app', 'Igual que toda la app'),
    );
    if (pick == null) return;
    await ref.read(fontPrefsProvider.notifier).choose(s, pick.key);
  }

  Future<void> _tune(FontSurface s) => PrismSheet.show<void>(
    context: context,
    title: tr(
      context,
      'Adjust ${s.en.toLowerCase()}',
      'Ajustar ${s.es.toLowerCase()}',
    ),
    builder: (ctx) => _TuneSheet(surface: s),
  );

  Future<void> _import() async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['ttf', 'otf', 'woff', 'woff2'],
    );
    final path = res?.files.firstOrNull?.path;
    if (path == null) return;
    final r = await PrismFonts.importFile(path);
    if (!mounted) return;
    if (r.font == null) {
      PrismToast.error(
        context,
        message: r.error ?? 'That font couldn\'t be imported.',
      );
      return;
    }
    await ref.read(fontPrefsProvider.notifier).addImported(r.font!);
    if (mounted)
      PrismToast.show(
        context,
        message: tr(
          context,
          '${r.font!.name} added',
          '${r.font!.name} añadida',
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(fontPrefsProvider);
    ref.watch(fontLoadTickProvider);
    final theme = Theme.of(context);
    final l = Localizations.localeOf(context).languageCode == 'es';

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(context, 'Fonts', 'Fuentes'),
        showBackButton: true,
      ),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + NavBarInset.of(context)),
          children: [
            PrismSurface(
              tone: PrismSurfaceTone.strong,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(context, 'Live preview', 'Vista previa'),
                    style: theme.textTheme.labelMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('Prism', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text(
                    tr(
                      context,
                      'Every part of you is welcome here. Pack my box with five dozen liquor jugs.',
                      'Cada parte de ti es bienvenida aquí.',
                    ),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            PrismSectionHeader(title: tr(context, 'FONTS', 'FUENTES')),
            for (final s in FontSurface.values) ...[
              PrismSurface(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l ? s.es : s.en,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _surfaceLabel(prefs, s),
                            style: PrismFonts.style(
                              prefs.of(s).family,
                              theme.textTheme.titleMedium,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: tr(context, 'Adjust', 'Ajustar'),
                      icon: const Icon(Icons.tune),
                      onPressed: () => _tune(s),
                    ),
                    IconButton(
                      tooltip: tr(context, 'Choose font', 'Elegir fuente'),
                      icon: const Icon(Icons.font_download_outlined),
                      onPressed: () => _choose(s),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            PrismSectionHeader(title: tr(context, 'YOUR FONTS', 'TUS FUENTES')),
            PrismButton(
              label: tr(
                context,
                'Import a font (TTF / OTF)',
                'Importar fuente (TTF / OTF)',
              ),
              icon: Icons.upload_file_outlined,
              expanded: true,
              tone: PrismButtonTone.outlined,
              onPressed: _import,
            ),
            for (final f in prefs.imported)
              PrismListRow(
                title: Text(
                  f.name,
                  style: PrismFonts.style(f.key, theme.textTheme.titleMedium),
                ),
                subtitle: Text(
                  tr(context, 'Imported font', 'Fuente importada'),
                ),
                trailing: IconButton(
                  tooltip: tr(context, 'Remove', 'Quitar'),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await PrismFonts.deleteImportedFile(f);
                    await ref
                        .read(fontPrefsProvider.notifier)
                        .removeImported(f.id);
                  },
                ),
              ),
            PrismSectionHeader(
              title: tr(context, 'ACCESSIBILITY', 'ACCESIBILIDAD'),
            ),
            PrismSurface(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: PrismSwitchRow(
                title: tr(
                  context,
                  'Plain fonts only',
                  'Solo fuentes sencillas',
                ),
                subtitle: tr(
                  context,
                  'Swaps decorative fonts (handwriting, gothic, pixel…) for Prism\'s readable font everywhere. Your choices are kept.',
                  'Cambia las fuentes decorativas por la fuente legible de Prism en todas partes. Tus elecciones se conservan.',
                ),
                value: prefs.plainOverride,
                onChanged: (v) =>
                    ref.read(fontPrefsProvider.notifier).setPlain(v),
              ),
            ),
            const SizedBox(height: 12),
            if (!prefs.isDefault)
              PrismButton(
                label: tr(context, 'Reset all fonts', 'Restablecer fuentes'),
                icon: Icons.restart_alt,
                expanded: true,
                tone: PrismButtonTone.outlined,
                onPressed: () =>
                    ref.read(fontPrefsProvider.notifier).resetAll(),
              ),
          ],
        ),
      ),
    );
  }

  String _surfaceLabel(FontPrefs prefs, FontSurface s) {
    final own = prefs.of(s).family;
    if (own != null) return _nameOf(prefs, own);
    if (s == FontSurface.global)
      return tr(context, 'Prism default', 'Predeterminada de Prism');
    final inherited = prefs.of(FontSurface.global).family;
    return inherited == null
        ? tr(context, 'Prism default', 'Predeterminada de Prism')
        : tr(
            context,
            '${_nameOf(prefs, inherited)} (whole app)',
            '${_nameOf(prefs, inherited)} (toda la app)',
          );
  }
}

class _TuneSheet extends ConsumerWidget {
  const _TuneSheet({required this.surface});
  final FontSurface surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(fontPrefsProvider);
    final s = prefs.of(surface);
    final n = ref.read(fontPrefsProvider.notifier);
    final theme = Theme.of(context);

    Widget slider(
      String label,
      double v,
      double min,
      double max,
      String Function(double) fmt,
      SurfaceFont Function(double) on,
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
          onChanged: (x) => n.setSurface(surface, on(x)),
        ),
      ],
    );

    final key = PrismFonts.resolve(
      s.family ?? prefs.of(FontSurface.global).family,
      prefs,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            tr(
              context,
              'The quick brown fox jumps over the lazy dog',
              'El veloz murciélago hindú comía feliz cardillo y kiwi',
            ),
            style: PrismFonts.style(key, theme.textTheme.titleMedium).copyWith(
              fontWeight: s.weight == null
                  ? null
                  : FontWeight.values[(s.weight! ~/ 100 - 1).clamp(0, 8)],
              letterSpacing: s.letterSpacing,
              height: s.lineHeight == 0 ? null : s.lineHeight,
              fontSize: 18 * s.size,
            ),
          ),
        ),
        Text(
          tr(context, 'Weight', 'Grosor'),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            PrismChip(
              label: tr(context, 'Default', 'Normal'),
              selected: s.weight == null,
              onTap: () => n.setSurface(surface, s.copyWith(weight: null)),
            ),
            for (final w in const [200, 300, 400, 500, 600, 700, 800, 900])
              PrismChip(
                label: '$w',
                selected: s.weight == w,
                onTap: () => n.setSurface(surface, s.copyWith(weight: w)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        slider(
          tr(context, 'Letter spacing', 'Espaciado'),
          s.letterSpacing,
          -1,
          4,
          (v) => v.toStringAsFixed(1),
          (x) => s.copyWith(letterSpacing: x),
        ),
        slider(
          tr(context, 'Line height', 'Interlineado'),
          s.lineHeight == 0 ? 1.4 : s.lineHeight,
          0.9,
          2.4,
          (v) => s.lineHeight == 0
              ? tr(context, 'Default', 'Normal')
              : v.toStringAsFixed(2),
          (x) => s.copyWith(lineHeight: x),
        ),
        slider(
          tr(context, 'Size', 'Tamaño'),
          s.size,
          0.7,
          1.8,
          (v) => '${(v * 100).round()}%',
          (x) => s.copyWith(size: x),
        ),
        const SizedBox(height: 8),
        PrismButton(
          label: tr(context, 'Reset this', 'Restablecer'),
          icon: Icons.restart_alt,
          tone: PrismButtonTone.outlined,
          onPressed: () => n.setSurface(surface, const SurfaceFont()),
        ),
      ],
    );
  }
}
