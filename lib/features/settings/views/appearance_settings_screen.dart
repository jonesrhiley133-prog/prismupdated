import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:prism_plurality/core/web/render_mode.dart';
import 'package:prism_plurality/core/app_icon/app_icon.dart';
import 'package:prism_plurality/features/settings/views/app_icon_maker.dart';
import 'package:prism_plurality/shared/l10n/tr.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_plurality/shared/theme/prism_shapes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/domain/models/models.dart' hide CornerStyle;
import 'package:prism_plurality/domain/models/system_settings.dart'
    hide CornerStyle;
import 'package:prism_plurality/domain/preferences/member_name_presentation.dart';
import 'package:prism_plurality/features/settings/providers/settings_providers.dart';
import 'package:prism_plurality/features/settings/views/accent_color_picker.dart';
import 'package:prism_plurality/features/settings/views/palette_settings_screen.dart';
import 'package:prism_plurality/shared/widgets/adaptive_detail_surface.dart';
import 'package:prism_plurality/features/settings/providers/terminology_provider.dart';
import 'package:prism_plurality/shared/widgets/app_shell.dart';
import 'package:prism_plurality/shared/widgets/member_avatar.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_segmented_control.dart';
import 'package:prism_plurality/shared/widgets/prism_switch_row.dart';
import 'package:prism_plurality/shared/widgets/prism_pill.dart';
import 'package:prism_plurality/shared/widgets/prism_section.dart';
import 'package:prism_plurality/shared/widgets/prism_section_card.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/widgets/prism_loading_state.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';

/// Screen for customising appearance: accent color, per-member colors, and a
/// live preview card.
class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(systemSettingsProvider);

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: context.l10n.appearanceTitle,
        showBackButton: true,
      ),
      bodyPadding: EdgeInsets.zero,
      body: settingsAsync.when(
        loading: () => const PrismLoadingState(),
        error: (e, _) => Center(child: Text(context.l10n.errorWithDetail(e))),
        data: (settings) {
          final selectedBrightness = ref.watch(themeBrightnessProvider);
          final selectedThemeStyle = ref.watch(themeStyleProvider);
          final namePresentation = ref.watch(memberNamePresentationProvider);
          final effectiveSettings = settings.copyWith(
            themeBrightness: selectedBrightness,
            themeStyle: selectedThemeStyle,
            paletteSource: ref.watch(paletteSourceProvider),
            paletteSeedColorHex: ref.watch(paletteSeedColorHexProvider),
            paletteMood: ref.watch(paletteMoodProvider),
            paletteContrast: ref.watch(paletteContrastProvider),
          );

          return ListView(
            padding: EdgeInsets.only(bottom: NavBarInset.of(context)),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: PrismButton(
                  label: context.l10n.apOpenStudio,
                  icon: Icons.palette_outlined,
                  tone: PrismButtonTone.filled,
                  expanded: true,
                  onPressed: () => context.push(AppRoutePaths.appearanceStudio),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: PrismButton(
                  label: context.l10n.socBannersTitle,
                  icon: Icons.panorama_outlined,
                  expanded: true,
                  onPressed: () => context.push(AppRoutePaths.headmateBanners),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: PrismButton(
                  label: Localizations.localeOf(context).languageCode == 'es'
                      ? 'Pantalla de inicio y saludo'
                      : 'Launch screen & greeting',
                  icon: Icons.auto_awesome_outlined,
                  expanded: true,
                  onPressed: () => context.push(AppRoutePaths.settingsLaunch),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: PrismButton(
                  label: Localizations.localeOf(context).languageCode == 'es'
                      ? 'Colecciones vivas'
                      : 'Living Collections',
                  icon: Icons.auto_awesome_outlined,
                  expanded: true,
                  onPressed: () => context.push(AppRoutePaths.living),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: PrismButton(
                  label: Localizations.localeOf(context).languageCode == 'es'
                      ? 'Efectos ambientales'
                      : 'Environmental effects',
                  icon: Icons.wb_twilight_outlined,
                  expanded: true,
                  onPressed: () => context.push(AppRoutePaths.environment),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: PrismButton(
                  label: Localizations.localeOf(context).languageCode == 'es'
                      ? 'Diseños'
                      : 'Layouts',
                  icon: Icons.dashboard_customize_outlined,
                  expanded: true,
                  onPressed: () => context.push(AppRoutePaths.layouts),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: PrismButton(
                  label: Localizations.localeOf(context).languageCode == 'es'
                      ? 'Salas digitales'
                      : 'Digital Rooms',
                  icon: Icons.meeting_room_outlined,
                  expanded: true,
                  onPressed: () => context.push(AppRoutePaths.digitalRooms),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: PrismButton(
                  label: Localizations.localeOf(context).languageCode == 'es'
                      ? 'Vida estacional y decoración'
                      : 'Seasonal Living & decoration',
                  icon: Icons.celebration_outlined,
                  expanded: true,
                  onPressed: () => context.push(AppRoutePaths.seasonal),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: PrismButton(
                  label: Localizations.localeOf(context).languageCode == 'es'
                      ? 'Fuentes'
                      : 'Fonts',
                  icon: Icons.font_download_outlined,
                  expanded: true,
                  onPressed: () => context.push(AppRoutePaths.settingsFonts),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: PrismButton(
                  label: Localizations.localeOf(context).languageCode == 'es'
                      ? 'Personalidad y voz'
                      : 'Personality & voice',
                  icon: Icons.record_voice_over_outlined,
                  expanded: true,
                  onPressed: () => context.push(AppRoutePaths.settingsVoice),
                ),
              ),
              PrismSection(
                title: context.l10n.appearanceBrightness,
                child: PrismSegmentedControl<ThemeBrightness>(
                  segments: ThemeBrightness.displayOrder
                      .map((b) => PrismSegment(value: b, label: b.displayName))
                      .toList(),
                  selected: selectedBrightness,
                  onChanged: (value) {
                    ref
                        .read(settingsNotifierProvider.notifier)
                        .updateThemeBrightness(value);
                  },
                ),
              ),
              PrismSection(
                title: context.l10n.appearanceStyle,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PrismSegmentedControl<ThemeStyle>(
                      segments: ThemeStyle.values
                          .map(
                            (s) => PrismSegment(
                              value: s,
                              label: appearanceThemeStyleLabel(context, s),
                            ),
                          )
                          .toList(),
                      selected: selectedThemeStyle,
                      onChanged: (value) {
                        ref
                            .read(settingsNotifierProvider.notifier)
                            .handleThemeStyleChange(value);
                      },
                    ),
                    if (selectedThemeStyle == ThemeStyle.materialYou) ...[
                      const SizedBox(height: 12),
                      _PaletteSummaryCard(settings: effectiveSettings),
                    ],
                  ],
                ),
              ),
              PrismSection(
                title: context.l10n.appearanceCornerStyleTitle,
                description: context.l10n.appearanceCornerStyleDescription,
                child: PrismSegmentedControl<CornerStyle>(
                  segments: [
                    PrismSegment(
                      value: CornerStyle.rounded,
                      label: context.l10n.appearanceCornerStyleRounded,
                    ),
                    PrismSegment(
                      value: CornerStyle.angular,
                      label: context.l10n.appearanceCornerStyleAngular,
                    ),
                  ],
                  selected: ref.watch(cornerStyleProvider),
                  onChanged: (value) {
                    ref
                        .read(settingsNotifierProvider.notifier)
                        .updateCornerStyle(value);
                  },
                ),
              ),
              PrismSection(
                title: context.l10n.appearanceMemberNamesTitle,
                description: context.l10n.appearanceMemberNamesDescription,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PrismSegmentedControl<MemberNamePrimary>(
                      segments: [
                        PrismSegment(
                          value: MemberNamePrimary.fullName,
                          label: context.l10n.appearanceMemberNamesDisplay,
                        ),
                        PrismSegment(
                          value: MemberNamePrimary.canonicalName,
                          label: context.l10n.appearanceMemberNamesLegacy,
                        ),
                      ],
                      selected: namePresentation.primary,
                      onChanged: (value) {
                        ref
                            .read(settingsNotifierProvider.notifier)
                            .updateMemberNamePresentationPrimary(value);
                      },
                    ),
                    const SizedBox(height: 12),
                    PrismSectionCard(
                      child: PrismSwitchRow(
                        title: context
                            .l10n
                            .appearanceMemberNamesShowAlternateTitle,
                        subtitle: context
                            .l10n
                            .appearanceMemberNamesShowAlternateDescription,
                        value: namePresentation.showAlternateName,
                        onChanged: (value) {
                          ref
                              .read(settingsNotifierProvider.notifier)
                              .updateMemberNamePresentationShowAlternate(value);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              if (selectedThemeStyle != ThemeStyle.materialYou)
                PrismSection(
                  title: context.l10n.appearanceAccentColor,
                  child: PrismSectionCard(
                    child: AccentColorPicker(
                      currentHex: settings.accentColorHex,
                      onChanged: (hex) => ref
                          .read(settingsNotifierProvider.notifier)
                          .updateAccentColor(hex),
                    ),
                  ),
                ),
              PrismSection(
                title: context.l10n.appearancePerMemberColors(
                  watchTerminology(context, ref).singular,
                ),
                child: PrismSectionCard(
                  child: PrismSwitchRow(
                    title: context.l10n.appearancePerMemberColorsSwitchTitle,
                    subtitle: context.l10n
                        .appearancePerMemberColorsSwitchSubtitle(
                          watchTerminology(context, ref).singularLower,
                        ),
                    value: settings.perMemberAccentColors,
                    onChanged: (value) {
                      ref
                          .read(settingsNotifierProvider.notifier)
                          .updatePerMemberAccentColors(value);
                    },
                  ),
                ),
              ),
              PrismSection(
                title: context.l10n.appearanceSyncSection,
                child: PrismSectionCard(
                  child: PrismSwitchRow(
                    title: context.l10n.appearanceSyncThemeTitle,
                    subtitle: context.l10n.appearanceSyncThemeSubtitle,
                    value: settings.syncThemeEnabled,
                    onChanged: (value) {
                      ref
                          .read(settingsNotifierProvider.notifier)
                          .updateSyncThemeEnabled(value);
                    },
                  ),
                ),
              ),
              PrismSection(
                title: context.l10n.appearanceBioMarkdownSection,
                child: PrismSectionCard(
                  child: PrismSwitchRow(
                    title: context.l10n.appearanceBioMarkdownTitle,
                    subtitle: context.l10n.appearanceBioMarkdownSubtitle,
                    value: settings.bioMarkdownEnabled,
                    onChanged: (value) {
                      ref
                          .read(settingsNotifierProvider.notifier)
                          .updateBioMarkdownEnabled(value);
                    },
                  ),
                ),
              ),
              PrismSection(
                title: context.l10n.appearanceLanguage,
                child: PrismSectionCard(
                  child: _LanguagePicker(
                    current: settings.localeOverride,
                    onChanged: (code) => ref
                        .read(settingsNotifierProvider.notifier)
                        .updateLocaleOverride(code),
                  ),
                ),
              ),
              const _AppIconSection(),
              if (kIsWeb) const _WebRenderingSection(),
              PrismSection(
                title: context.l10n.appearancePreview,
                child: _PreviewCard(settings: settings),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PaletteSummaryCard extends ConsumerWidget {
  const _PaletteSummaryCard({required this.settings});

  final SystemSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final paletteSource = ref.watch(paletteSourceProvider);
    final preview = palettePreviewForSettings(
      context,
      settings,
      source: paletteSource,
    );

    return PrismSectionCard(
      onTap: () {
        showAdaptiveDetailSurface<void>(
          context: context,
          builder: (_) => const PaletteSettingsScreen(),
          route: (context) => context.push(AppRoutePaths.settingsPalette),
        );
      },
      accentColor: preview.primary,
      child: Row(
        children: [
          PaletteDots(colors: preview.dots, size: 16),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.paletteTitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  paletteSettingsSummary(
                    context,
                    settings,
                    source: paletteSource,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            AppIcons.chevronRightRounded,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
          ),
        ],
      ),
    );
  }
}

/// Live preview showing a sample member card using current theme settings.
class _PreviewCard extends ConsumerWidget {
  const _PreviewCard({required this.settings});

  final SystemSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final terms = watchTerminology(context, ref);
    final frontingTerms = watchFrontingTerms(context, ref);

    return PrismSectionCard(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            const MemberAvatar(emoji: '\u{1F338}', size: 48),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.appearanceSampleMember(terms.singular),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.appearanceSamplePronouns,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(child: PrismPill(label: frontingTerms.activeSectionLabel)),
          ],
        ),
      ),
    );
  }
}

class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker({required this.current, required this.onChanged});

  final String? current;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LanguageRow(
          title: context.l10n.appearanceLanguageSystem,
          isSelected: current == null || current!.isEmpty,
          onTap: () => onChanged(null),
          theme: theme,
        ),
        _LanguageRow(
          title: 'English',
          isSelected: current == 'en',
          onTap: () => onChanged('en'),
          theme: theme,
        ),
        _LanguageRow(
          title: 'Español',
          isSelected: current == 'es',
          onTap: () => onChanged('es'),
          theme: theme,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            context.l10n.appearanceLanguageFooter,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.title,
    required this.isSelected,
    required this.onTap,
    required this.theme,
  });

  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PrismShapes.of(context).radius(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(child: Text(title, style: theme.textTheme.bodyLarge)),
            if (isSelected)
              Icon(AppIcons.check, color: theme.colorScheme.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Web only: GPU vs software drawing. Some graphics drivers make the web
/// app look dithered or garbled; software rendering always draws cleanly.
class _WebRenderingSection extends StatelessWidget {
  const _WebRenderingSection();
  @override
  Widget build(BuildContext context) {
    final mode = webRendererMode();
    final cpu = webUsesCpuRendering();
    final theme = Theme.of(context);
    return PrismSection(
      title: tr(context, 'Display rendering', 'Renderizado'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrismSegmentedControl<String>(
            segments: [
              PrismSegment(
                value: 'auto',
                label: tr(context, 'Automatic', 'Automático'),
              ),
              PrismSegment(
                value: 'cpu',
                label: tr(context, 'Compatibility', 'Compatibilidad'),
              ),
              PrismSegment(
                value: 'gpu',
                label: tr(context, 'Graphics card', 'Tarjeta gráfica'),
              ),
            ],
            selected: mode,
            onChanged: (v) {
              if (v != mode) setWebRendererMode(v);
            },
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              context,
              'If Prism looks grainy, dithered or garbled, choose Compatibility. It draws without the graphics card, which always looks right but can be a little slower. The page reloads to apply it. Now using: ${cpu ? 'compatibility (software)' : 'graphics card'}.',
              'Si Prism se ve granulado o corrupto, elige Compatibilidad. Dibuja sin la tarjeta gráfica: siempre se ve bien, aunque puede ir algo más lento. La página se recarga para aplicarlo. En uso: ${cpu ? 'compatibilidad (software)' : 'tarjeta gráfica'}.',
            ),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Pick the app's icon (Android launcher, browser tab on the web).
class _AppIconSection extends ConsumerWidget {
  const _AppIconSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final current = ref.watch(appIconProvider).value ?? 'classic';
    final es = Localizations.localeOf(context).languageCode == 'es';
    return PrismSection(
      title: tr(context, 'App icon', 'Icono de la app'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final plural in [false, true]) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 4),
              child: Text(
                plural
                    ? tr(context, 'Plurality', 'Pluralidad')
                    : tr(context, 'Prism', 'Prism'),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final p in appIconPresets.where((p) => p.plural == plural))
                  _IconTile(
                    preset: p,
                    label: es ? p.es : p.en,
                    selected: p.id == current,
                    enabled: appIconSupported,
                    onTap: () async {
                      if (p.id == current) return;
                      await ref.read(appIconProvider.notifier).select(p.id);
                    },
                  ),
                if (plural)
                  _CustomIconTile(
                    selected: current == 'custom',
                    enabled: appIconSupported,
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          Text(
            !appIconSupported
                ? tr(
                    context,
                    'Changing the icon isn’t available on this device yet.',
                    'Cambiar el icono aún no está disponible en este dispositivo.',
                  )
                : kIsWeb
                ? tr(
                    context,
                    'Changes the icon on this browser tab.',
                    'Cambia el icono de esta pestaña del navegador.',
                  )
                : tr(
                    context,
                    'Changes Prism’s icon on your home screen. Some launchers take a few seconds to update, and a home-screen shortcut may need to be added again.',
                    'Cambia el icono de Prism en la pantalla de inicio. Algunos lanzadores tardan unos segundos y puede que tengas que volver a añadir el acceso directo.',
                  ),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.preset,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });
  final AppIconPreset preset;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: tr(context, '$label app icon', 'Icono $label'),
      child: InkWell(
        borderRadius: prismCorners(context, 16),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 76,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: prismCorners(context, 18),
                  border: Border.all(
                    color: selected
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: Opacity(
                  opacity: enabled ? 1 : 0.5,
                  child: Image.asset(
                    preset.asset,
                    width: 60,
                    height: 60,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Custom": opens the icon designer; shows the saved custom icon.
class _CustomIconTile extends ConsumerWidget {
  const _CustomIconTile({required this.selected, required this.enabled});
  final bool selected;
  final bool enabled;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final png = ref.watch(customAppIconProvider).value;
    return Semantics(
      button: true,
      selected: selected,
      label: tr(
        context,
        'Custom app icon. Design your own',
        'Icono personalizado. Diseña el tuyo',
      ),
      child: InkWell(
        borderRadius: prismCorners(context, 16),
        onTap: enabled ? () => showAppIconMaker(context) : null,
        child: SizedBox(
          width: 76,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: prismCorners(context, 18),
                  border: Border.all(
                    color: selected
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: prismCorners(context, 14),
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: png != null
                        ? Image.memory(png, fit: BoxFit.cover)
                        : DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant,
                              ),
                              borderRadius: prismCorners(context, 14),
                              color: theme.colorScheme.surfaceContainerHigh,
                            ),
                            child: Icon(
                              Icons.brush_outlined,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tr(context, 'Custom', 'Personal'),
                maxLines: 1,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
