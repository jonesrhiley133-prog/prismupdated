import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/features/appearance/services/appearance_store.dart';
import 'package:prism_plurality/shared/l10n/tr.dart';
import 'package:prism_plurality/shared/theme/palette_moods.dart';
import 'package:prism_plurality/domain/models/system_settings.dart'
    hide CornerStyle;
import 'package:prism_plurality/features/settings/providers/settings_providers.dart';
import 'package:prism_plurality/features/settings/providers/terminology_provider.dart';
import 'package:prism_plurality/features/settings/views/accent_color_picker.dart';
import 'package:prism_plurality/features/settings/views/accent_color_presets.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/app_theme.dart';
import 'package:prism_plurality/shared/theme/prism_shapes.dart';
import 'package:prism_plurality/shared/widgets/app_shell.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_list_row.dart';
import 'package:prism_plurality/shared/widgets/prism_loading_state.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_pill.dart';
import 'package:prism_plurality/shared/widgets/prism_section.dart';
import 'package:prism_plurality/shared/widgets/prism_section_card.dart';
import 'package:prism_plurality/shared/widgets/prism_segmented_control.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';

String appearanceThemeStyleLabel(BuildContext context, ThemeStyle style) {
  return switch (style) {
    ThemeStyle.standard => context.l10n.appearanceStylePrism,
    ThemeStyle.oled => context.l10n.appearanceStyleOled,
    ThemeStyle.materialYou => context.l10n.appearanceStylePalette,
  };
}

String paletteSettingsSummary(
  BuildContext context,
  SystemSettings settings, {
  PaletteSource? source,
}) {
  final resolvedSource = source ?? settings.paletteSource;
  final sourceLabel = switch (resolvedSource) {
    PaletteSource.device => context.l10n.paletteSourceDeviceColors,
    PaletteSource.custom => context.l10n.paletteSummaryCustom(
      paletteSeedColorName(context, settings.paletteSeedColorHex),
    ),
  };
  return context.l10n.paletteSummary(
    sourceLabel,
    paletteMoodLabel(context, settings.paletteMood),
    paletteContrastLabel(context, settings.paletteContrast),
  );
}

PalettePreview palettePreviewForSettings(
  BuildContext context,
  SystemSettings settings, {
  PaletteSource? source,
  CustomPaletteAccents custom = CustomPaletteAccents.none,
}) {
  if ((source ?? settings.paletteSource) == PaletteSource.device) {
    return PalettePreview.fromScheme(Theme.of(context).colorScheme);
  }
  return PalettePreview.from(
    seedColor: paletteSeedColorForSettings(context, settings, source: source),
    mood: settings.paletteMood,
    contrast: settings.paletteContrast,
    brightness: Theme.of(context).brightness,
    custom: custom,
  );
}

Color paletteSeedColorForSettings(
  BuildContext context,
  SystemSettings settings, {
  PaletteSource? source,
}) {
  final resolvedSource = source ?? settings.paletteSource;
  return switch (resolvedSource) {
    PaletteSource.device => Theme.of(context).colorScheme.primary,
    PaletteSource.custom => parsePaletteHex(settings.paletteSeedColorHex),
  };
}

String paletteMoodLabel(BuildContext context, PaletteMood mood) {
  return switch (mood) {
    PaletteMood.tonal => context.l10n.paletteMoodTonal,
    PaletteMood.vibrant => context.l10n.paletteMoodVibrant,
    PaletteMood.expressive => context.l10n.paletteMoodExpressive,
    PaletteMood.fidelity => context.l10n.paletteMoodFidelity,
    PaletteMood.monochrome => context.l10n.paletteMoodMonochrome,
    PaletteMood.neutral => tr(context, 'Neutral', 'Neutro'),
    PaletteMood.content => tr(context, 'Content', 'Contenido'),
    PaletteMood.rainbow => tr(context, 'Rainbow', 'Arcoíris'),
    PaletteMood.fruitSalad => tr(context, 'Fruit salad', 'Macedonia'),
    PaletteMood.pastel => tr(context, 'Pastel', 'Pastel'),
    PaletteMood.neon => tr(context, 'Neon', 'Neón'),
    PaletteMood.earthy => tr(context, 'Earthy', 'Terroso'),
    PaletteMood.jewel => tr(context, 'Jewel', 'Joya'),
    PaletteMood.sunset => tr(context, 'Sunset', 'Atardecer'),
    PaletteMood.ocean => tr(context, 'Ocean', 'Océano'),
    PaletteMood.forest => tr(context, 'Forest', 'Bosque'),
    PaletteMood.candy => tr(context, 'Candy', 'Caramelo'),
    PaletteMood.complementary => tr(context, 'Complementary', 'Complementario'),
    PaletteMood.analogous => tr(context, 'Analogous', 'Análogo'),
    PaletteMood.triadic => tr(context, 'Triadic', 'Triádico'),
    PaletteMood.splitComplementary => tr(
      context,
      'Split complementary',
      'Complementario dividido',
    ),
    PaletteMood.custom => tr(context, 'Custom', 'Personalizado'),
  };
}

String paletteContrastLabel(BuildContext context, PaletteContrast contrast) {
  return switch (contrast) {
    PaletteContrast.soft => context.l10n.paletteContrastSoft,
    PaletteContrast.standard => context.l10n.paletteContrastStandard,
    PaletteContrast.high => context.l10n.paletteContrastHigh,
  };
}

String paletteSeedColorName(BuildContext context, String hex) {
  return accentColorPresetName(context, hex);
}

Color parsePaletteHex(String hex) {
  final cleaned = hex.replaceFirst('#', '');
  final fallback = prismDefaultAccentColorHex.replaceFirst('#', '');
  final value =
      int.tryParse('FF$cleaned', radix: 16) ??
      int.parse('FF$fallback', radix: 16);
  return Color(value);
}

class PaletteSettingsScreen extends ConsumerWidget {
  const PaletteSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(systemSettingsProvider);

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: context.l10n.paletteTitle,
        showBackButton: true,
      ),
      bodyPadding: EdgeInsets.zero,
      body: settingsAsync.when(
        loading: () => const PrismLoadingState(),
        error: (e, _) => Center(child: Text(context.l10n.errorWithDetail(e))),
        data: (settings) {
          final platform = ref.watch(targetPlatformProvider);
          final deviceSourceAvailable = paletteDeviceSourceAvailableForPlatform(
            platform,
          );
          final paletteSource = ref.watch(paletteSourceProvider);
          final viewSettings = settings.copyWith(
            paletteSource: paletteSource,
            paletteSeedColorHex: ref.watch(paletteSeedColorHexProvider),
            paletteMood: ref.watch(paletteMoodProvider),
            paletteContrast: ref.watch(paletteContrastProvider),
          );
          final notifier = ref.read(settingsNotifierProvider.notifier);
          final seedColor = paletteSeedColorForSettings(
            context,
            viewSettings,
            source: paletteSource,
          );
          final custom = ref.watch(customPaletteAccentsProvider);
          final moodPreviews = {
            for (final mood in PaletteMood.values)
              mood: PalettePreview.from(
                seedColor: seedColor,
                mood: mood,
                contrast: viewSettings.paletteContrast,
                brightness: Theme.of(context).brightness,
                custom: custom,
              ),
          };
          final selectedPreview = palettePreviewForSettings(
            context,
            viewSettings,
            source: paletteSource,
            custom: custom,
          );
          Widget moodGroup(String title, List<PaletteMood> moods) =>
              PrismSection(
                title: title,
                child: _MoodGrid(
                  children: [
                    for (final mood in moods)
                      _MoodCard(
                        mood: mood,
                        preview: moodPreviews[mood]!,
                        selected: viewSettings.paletteMood == mood,
                        onTap: () => notifier.updatePaletteMood(mood),
                      ),
                  ],
                ),
              );
          final terms = watchTerminology(context, ref);
          final frontingTerms = watchFrontingTerms(context, ref);

          return ListView(
            padding: EdgeInsets.only(bottom: NavBarInset.of(context)),
            children: [
              if (deviceSourceAvailable)
                PrismSection(
                  title: context.l10n.paletteSourceTitle,
                  child: Column(
                    children: [
                      _SourceCard(
                        title: context.l10n.paletteSourceDeviceColors,
                        subtitle: context.l10n.paletteSourceDeviceSubtitle,
                        icon: AppIcons.devicesOutlined,
                        selected: paletteSource == PaletteSource.device,
                        enabled: true,
                        onTap: () =>
                            notifier.updatePaletteSource(PaletteSource.device),
                      ),
                      const SizedBox(height: 10),
                      _SourceCard(
                        title: context.l10n.paletteSourceCustomColor,
                        subtitle: context.l10n.paletteSourceCustomSubtitle,
                        icon: AppIcons.colorize,
                        selected: paletteSource == PaletteSource.custom,
                        enabled: true,
                        onTap: () =>
                            notifier.updatePaletteSource(PaletteSource.custom),
                      ),
                    ],
                  ),
                ),
              if (paletteSource == PaletteSource.custom)
                PrismSection(
                  title: context.l10n.paletteColorTitle,
                  child: PrismSectionCard(
                    child: AccentColorPicker(
                      currentHex: viewSettings.paletteSeedColorHex,
                      onChanged: notifier.updatePaletteSeedColorHex,
                    ),
                  ),
                ),
              moodGroup(context.l10n.paletteMoodTitle, const [
                PaletteMood.tonal,
                PaletteMood.vibrant,
                PaletteMood.expressive,
                PaletteMood.fidelity,
                PaletteMood.monochrome,
                PaletteMood.neutral,
                PaletteMood.content,
                PaletteMood.rainbow,
                PaletteMood.fruitSalad,
              ]),
              moodGroup(tr(context, 'Prism moods', 'Estilos de Prism'), const [
                PaletteMood.pastel,
                PaletteMood.neon,
                PaletteMood.earthy,
                PaletteMood.jewel,
                PaletteMood.sunset,
                PaletteMood.ocean,
                PaletteMood.forest,
                PaletteMood.candy,
              ]),
              moodGroup(
                tr(context, 'Colour harmonies', 'Armonías de color'),
                const [
                  PaletteMood.complementary,
                  PaletteMood.analogous,
                  PaletteMood.triadic,
                  PaletteMood.splitComplementary,
                ],
              ),
              moodGroup(tr(context, 'Your own', 'Tuyo'), const [
                PaletteMood.custom,
              ]),
              if (viewSettings.paletteMood == PaletteMood.custom)
                _CustomAccentsSection(
                  custom: custom,
                  fallback: moodPreviews[PaletteMood.custom]!.scheme,
                ),
              PrismSection(
                title: context.l10n.paletteContrastTitle,
                child: PrismSegmentedControl<PaletteContrast>(
                  segments: PaletteContrast.values
                      .map(
                        (contrast) => PrismSegment(
                          value: contrast,
                          label: paletteContrastLabel(context, contrast),
                        ),
                      )
                      .toList(),
                  selected: viewSettings.paletteContrast,
                  onChanged: notifier.updatePaletteContrast,
                ),
              ),
              PrismSection(
                title: context.l10n.palettePreviewTitle,
                child: PrismSectionCard(
                  padding: const EdgeInsets.all(14),
                  accentColor: selectedPreview.primary,
                  child: _PaletteLivePreview(
                    preview: selectedPreview,
                    termPlural: terms.plural,
                    activePhrase: frontingTerms.currentlyActivePhrase,
                    activeLabel: frontingTerms.activeSectionLabel,
                  ),
                ),
              ),
              PrismSection(
                title: context.l10n.paletteResetTitle,
                child: PrismSectionCard(
                  padding: EdgeInsets.zero,
                  child: PrismListRow(
                    title: Text(context.l10n.paletteResetAction),
                    subtitle: Text(context.l10n.paletteResetDescription),
                    leading: Icon(
                      AppIcons.restartAlt,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onTap: () => _resetPaletteSettings(notifier),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class PalettePreview {
  const PalettePreview({
    required this.scheme,
    required this.primary,
    required this.dots,
  });

  factory PalettePreview.from({
    required Color seedColor,
    required PaletteMood mood,
    required PaletteContrast contrast,
    required Brightness brightness,
    CustomPaletteAccents custom = CustomPaletteAccents.none,
  }) {
    // The mood list shows over twenty previews: remember each one so the
    // themes are built once per colour, not on every rebuild.
    final key = (seedColor.toARGB32(), mood, contrast, brightness, custom);
    final hit = _cache[key];
    if (hit != null) return hit;
    // The same theme the app applies, so a preview matches what you get.
    final seedHex =
        '#${(seedColor.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    final scheme = switch (brightness) {
      Brightness.light => AppTheme.materialYouLight(
        null,
        paletteSource: PaletteSource.custom,
        paletteSeedColorHex: seedHex,
        paletteMood: mood,
        paletteContrast: contrast,
        paletteCustom: custom,
      ).colorScheme,
      Brightness.dark => AppTheme.materialYouDark(
        null,
        paletteSource: PaletteSource.custom,
        paletteSeedColorHex: seedHex,
        paletteMood: mood,
        paletteContrast: contrast,
        paletteCustom: custom,
      ).colorScheme,
    };
    if (_cache.length > 200) _cache.clear();
    return _cache[key] = PalettePreview(
      scheme: scheme,
      primary: scheme.primary,
      dots: [
        scheme.primary,
        scheme.secondary,
        scheme.tertiary,
        scheme.primaryContainer,
      ],
    );
  }

  static final Map<
    (int, PaletteMood, PaletteContrast, Brightness, CustomPaletteAccents),
    PalettePreview
  >
  _cache = {};

  factory PalettePreview.fromScheme(ColorScheme scheme) {
    return PalettePreview(
      scheme: scheme,
      primary: scheme.primary,
      dots: [
        scheme.primary,
        scheme.secondary,
        scheme.tertiary,
        scheme.primaryContainer,
      ],
    );
  }

  final ColorScheme scheme;
  final Color primary;
  final List<Color> dots;
}

Future<void> _resetPaletteSettings(SettingsNotifier notifier) async {
  await notifier.updatePaletteSource(PaletteSource.custom);
  await notifier.updatePaletteSeedColorHex(prismDefaultAccentColorHex);
  await notifier.updatePaletteMood(PaletteMood.tonal);
  await notifier.updatePaletteContrast(PaletteContrast.standard);
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface;

    return PrismSectionCard(
      onTap: enabled ? onTap : null,
      accentColor: tint,
      tone: selected ? PrismSurfaceTone.accent : PrismSurfaceTone.subtle,
      child: Row(
        children: [
          Icon(
            icon,
            size: 24,
            color: enabled
                ? tint
                : theme.colorScheme.onSurface.withValues(alpha: 0.35),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: enabled
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: enabled
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.55,
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (selected)
            Icon(AppIcons.check, color: theme.colorScheme.primary, size: 20),
        ],
      ),
    );
  }
}

class _MoodCard extends StatelessWidget {
  const _MoodCard({
    required this.mood,
    required this.preview,
    required this.selected,
    required this.onTap,
  });

  final PaletteMood mood;
  final PalettePreview preview;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PrismSectionCard(
      onTap: onTap,
      accentColor: preview.primary,
      tone: selected ? PrismSurfaceTone.accent : PrismSurfaceTone.subtle,
      child: Row(
        children: [
          PaletteDots(colors: preview.dots),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paletteMoodLabel(context, mood),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _moodDescription(context, mood),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (selected)
            Icon(AppIcons.check, color: theme.colorScheme.primary, size: 20),
        ],
      ),
    );
  }
}

String _moodDescription(BuildContext context, PaletteMood mood) {
  return switch (mood) {
    PaletteMood.tonal => context.l10n.paletteMoodTonalDescription,
    PaletteMood.vibrant => context.l10n.paletteMoodVibrantDescription,
    PaletteMood.expressive => context.l10n.paletteMoodExpressiveDescription,
    PaletteMood.fidelity => context.l10n.paletteMoodFidelityDescription,
    PaletteMood.monochrome => context.l10n.paletteMoodMonochromeDescription,
    PaletteMood.neutral => tr(
      context,
      'Near-grey surfaces with just a hint of your colour',
      'Superficies casi grises con un toque de tu color',
    ),
    PaletteMood.content => tr(
      context,
      'Matches your colour closely, like artwork',
      'Se ajusta mucho a tu color, como una ilustración',
    ),
    PaletteMood.rainbow => tr(
      context,
      'Accents from around the colour wheel',
      'Acentos de toda la rueda de color',
    ),
    PaletteMood.fruitSalad => tr(
      context,
      'Bold, juicy jumps between hues',
      'Saltos de tono vivos y jugosos',
    ),
    PaletteMood.pastel => tr(
      context,
      'Soft, airy accents with gentle colour',
      'Acentos suaves y ligeros',
    ),
    PaletteMood.neon => tr(
      context,
      'The brightest, most saturated accents',
      'Los acentos más brillantes y saturados',
    ),
    PaletteMood.earthy => tr(
      context,
      'Warm clay, moss and sand tones',
      'Tonos cálidos de arcilla, musgo y arena',
    ),
    PaletteMood.jewel => tr(
      context,
      'Deep, rich gemstone colours',
      'Colores intensos de piedras preciosas',
    ),
    PaletteMood.sunset => tr(
      context,
      'Coral, peach and rose accents',
      'Acentos coral, melocotón y rosa',
    ),
    PaletteMood.ocean => tr(
      context,
      'Cool blues and sea-glass teals',
      'Azules fríos y turquesas',
    ),
    PaletteMood.forest => tr(
      context,
      'Leafy greens and golden light',
      'Verdes de hoja y luz dorada',
    ),
    PaletteMood.candy => tr(
      context,
      'Sweet pinks and mint',
      'Rosas dulces y menta',
    ),
    PaletteMood.complementary => tr(
      context,
      'Accents from the opposite side of the wheel',
      'Acentos del lado opuesto de la rueda',
    ),
    PaletteMood.analogous => tr(
      context,
      'Neighbouring hues that blend smoothly',
      'Tonos vecinos que combinan con suavidad',
    ),
    PaletteMood.triadic => tr(
      context,
      'Three hues spaced evenly around the wheel',
      'Tres tonos repartidos por la rueda',
    ),
    PaletteMood.splitComplementary => tr(
      context,
      'The two hues beside your colour’s opposite',
      'Los dos tonos junto al opuesto de tu color',
    ),
    PaletteMood.custom => tr(
      context,
      'Pick the accents that go with your colour',
      'Elige los acentos que combinan con tu color',
    ),
  };
}

class PaletteDots extends StatelessWidget {
  const PaletteDots({super.key, required this.colors, this.size = 18});

  final List<Color> colors;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 2.8,
      height: size * 1.8,
      child: Stack(
        children: [
          for (var i = 0; i < colors.length; i++)
            Positioned(
              left: i * size * 0.62,
              top: i.isEven ? 0 : size * 0.55,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: colors[i],
                  borderRadius: prismRound(context),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.72),
                    width: 1.2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PaletteLivePreview extends StatelessWidget {
  const _PaletteLivePreview({
    required this.preview,
    required this.termPlural,
    required this.activePhrase,
    required this.activeLabel,
  });

  final PalettePreview preview;
  final String termPlural;
  final String activePhrase;
  final String activeLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = preview.scheme;
    final shapes = PrismShapes.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PreviewMemberRow(
          emoji: '\u{1F338}',
          title: context.l10n.palettePreviewMemberOne,
          subtitle: activePhrase,
          color: scheme.primary,
          badge: activeLabel,
        ),
        const SizedBox(height: 10),
        _PreviewMemberRow(
          emoji: '\u{2600}',
          title: context.l10n.palettePreviewMemberTwo,
          subtitle: context.l10n.palettePreviewMemberTwoDetail,
          color: scheme.tertiary,
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Theme(
              data: Theme.of(context).copyWith(colorScheme: scheme),
              child: PrismButton(
                label: context.l10n.palettePreviewButton,
                icon: AppIcons.check,
                tone: PrismButtonTone.filled,
                density: PrismControlDensity.compact,
                onPressed: () {},
              ),
            ),
            PrismPill(
              label: activeLabel,
              tone: PrismPillTone.accent,
              color: scheme.tertiary,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(shapes.radius(14)),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Text(
            context.l10n.palettePreviewInput,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.secondaryContainer.withValues(alpha: 0.52),
            borderRadius: BorderRadius.circular(shapes.radius(999)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AppIcons.navHome,
                size: 16,
                color: scheme.onSecondaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.palettePreviewNavHint(termPlural),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreviewMemberRow extends StatelessWidget {
  const _PreviewMemberRow({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    this.badge,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shapes = PrismShapes.of(context);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.18 : 0.12,
        ),
        borderRadius: BorderRadius.circular(shapes.radius(14)),
        border: Border.all(
          color: color.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.26 : 0.20,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: prismRound(context),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 21)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 10),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(shapes.radius(999)),
                ),
                child: Text(
                  badge!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}


/// Mood cards: one column on phones, two side by side on wider screens.
class _MoodGrid extends StatelessWidget {
  const _MoodGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final columns = c.maxWidth >= 640 ? 2 : 1;
        const gap = 10.0;
        final w = (c.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final child in children) SizedBox(width: w, child: child)],
        );
      },
    );
  }
}

/// Accent pickers for the Custom mood: the main colour stays the palette
/// colour above; these set the secondary and highlight accents.
class _CustomAccentsSection extends ConsumerWidget {
  const _CustomAccentsSection({required this.custom, required this.fallback});

  final CustomPaletteAccents custom;

  /// The scheme shown while an accent is still automatic.
  final ColorScheme fallback;

  static String _hex(int argb) =>
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final store = ref.read(appearanceProvider.notifier);
    Widget picker({
      required String title,
      required String help,
      required int? value,
      required Color automatic,
      required void Function(int? v) set,
    }) {
      return PrismSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        help,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (value == null)
                  _AutoSwatch(color: automatic)
                else
                  PrismButton(
                    label: tr(context, 'Automatic', 'Automático'),
                    density: PrismControlDensity.compact,
                    onPressed: () => set(null),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            AccentColorPicker(
              currentHex: _hex(value ?? automatic.toARGB32()),
              showSelection: value != null,
              showLegibilityWarning: false,
              onChanged: (hex) => set(parsePaletteHex(hex).toARGB32()),
            ),
          ],
        ),
      );
    }

    return PrismSection(
      title: tr(context, 'Custom accents', 'Acentos personalizados'),
      child: Column(
        children: [
          picker(
            title: tr(context, 'Second accent', 'Segundo acento'),
            help: tr(
              context,
              'Chips, toggles and secondary highlights',
              'Etiquetas, interruptores y realces secundarios',
            ),
            value: custom.secondary,
            automatic: fallback.secondary,
            set: (v) => store.setCustomPaletteAccents(
              secondary: v,
              tertiary: custom.tertiary,
            ),
          ),
          const SizedBox(height: 10),
          picker(
            title: tr(context, 'Highlight accent', 'Acento de realce'),
            help: tr(
              context,
              'Badges, tags and small pops of colour',
              'Insignias, etiquetas y toques de color',
            ),
            value: custom.tertiary,
            automatic: fallback.tertiary,
            set: (v) => store.setCustomPaletteAccents(
              secondary: custom.secondary,
              tertiary: v,
            ),
          ),
        ],
      ),
    );
  }
}


/// Shows the automatic accent a picker is using until one is chosen.
class _AutoSwatch extends StatelessWidget {
  const _AutoSwatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          tr(context, 'Automatic', 'Automático'),
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color,
            borderRadius: prismRound(context),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
        ),
      ],
    );
  }
}
