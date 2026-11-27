import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/features/appearance/appearance_library.dart';
import 'package:prism_plurality/features/appearance/appearance_undo_banner.dart';
import 'package:prism_plurality/features/seasonal/decor_models.dart';
import 'package:prism_plurality/features/seasonal/living_layout.dart';
import 'package:prism_plurality/features/seasonal/seasonal_catalog.dart';
import 'package:prism_plurality/features/seasonal/seasonal_providers.dart';
import 'package:prism_plurality/shared/theme/layout_decor.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Turns a look's layout arrangement on (or off with null), keeping undo.
void applyLayout(WidgetRef ref, String? variationId, {String? undoMessage}) {
  final prev = ref.read(seasonalPrefsProvider).layoutVariation;
  if (undoMessage != null && prev != variationId) {
    ref
        .read(appearanceUndoProvider.notifier)
        .record(undoMessage, () => applyLayout(ref, prev));
  }
  ref
      .read(seasonalPrefsProvider.notifier)
      .update(
        (p) => p.copyWith(
          layoutVariation: variationId,
          performance:
              variationId != null && p.performance == DecoPerformance.off
              ? DecoPerformance.balanced
              : p.performance,
        ),
      );
}

/// Layout arrangements: optional ornaments on headers, cards, dividers,
/// profile pictures, the navigation bar and hanging trims. Each part has its
/// own switch, and none of them change the theme, colours, fonts, spacing
/// or background.
class LayoutsScreen extends ConsumerWidget {
  const LayoutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prefs = ref.watch(seasonalPrefsProvider);
    final v = prefs.layoutVariation == null
        ? null
        : variationById(prefs.layoutVariation!);
    final living = prefs.livingVariation == null
        ? null
        : variationById(prefs.livingVariation!);
    final parts = prefs.layoutParts ?? LayoutPart.all.toSet();
    final n = ref.read(seasonalPrefsProvider.notifier);

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(context, 'Layouts', 'Diseños'),
        showBackButton: true,
      ),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 40 + NavBarInset.of(context)),
          children: [
            const AppearanceUndoBanner(),
            Text(
              tr(
                context,
                'Every living look comes with an optional layout: small ornaments for headers, cards, dividers, profile pictures and the navigation bar. Turn on only the parts you like. Your theme, colours, fonts, spacing and background stay exactly as they are.',
                'Cada estilo vivo trae un diseño opcional: pequeños adornos para encabezados, tarjetas, divisores, fotos de perfil y la barra de navegación. Tu tema, colores, fuentes y fondo no cambian.',
              ),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (v == null) ...[
              PrismSurface(
                padding: const EdgeInsets.all(14),
                child: Text(
                  tr(
                    context,
                    'No layout is on.',
                    'No hay ningún diseño activo.',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (living != null)
                PrismButton(
                  label: tr(
                    context,
                    'Use the layout from ${living.name}',
                    'Usar el diseño de ${living.name}',
                  ),
                  icon: Icons.dashboard_customize_outlined,
                  tone: PrismButtonTone.filled,
                  expanded: true,
                  onPressed: () => applyLayout(
                    ref,
                    living.id,
                    undoMessage: tr(context, 'Layout on.', 'Diseño activado.'),
                  ),
                ),
              const SizedBox(height: 8),
              PrismButton(
                label: tr(
                  context,
                  'Choose from Living Collections',
                  'Elegir en Colecciones vivas',
                ),
                icon: Icons.auto_awesome_outlined,
                tone: PrismButtonTone.outlined,
                expanded: true,
                onPressed: () => context.push(AppRoutePaths.living),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v.name, style: theme.textTheme.titleMedium),
                        Text(
                          collectionById(v.collectionId)?.name ?? '',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  PrismButton(
                    label: tr(context, 'Turn off', 'Apagar'),
                    tone: PrismButtonTone.outlined,
                    density: PrismControlDensity.compact,
                    onPressed: () => applyLayout(
                      ref,
                      null,
                      undoMessage: tr(
                        context,
                        'Layout off.',
                        'Diseño apagado.',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // A live sample of the parts that are on.
              LayoutDecor(
                data: layoutDecorFor(v, parts),
                child: PrismSurface(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PrismSectionHeader(
                        title: tr(context, 'PREVIEW', 'VISTA PREVIA'),
                      ),
                      Row(
                        children: [
                          SizedBox.square(
                            dimension: 56,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor:
                                      theme.colorScheme.primaryContainer,
                                  child: const Text('🙂'),
                                ),
                                if (parts.contains(LayoutPart.profile))
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: LayoutRingPainter(
                                        layoutDecorFor(v, parts),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: PrismSurface(
                              padding: const EdgeInsets.all(12),
                              child: Text(tr(context, 'A card', 'Una tarjeta')),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              PrismSectionHeader(title: tr(context, 'PARTS', 'PARTES')),
              for (final part in LayoutPart.all)
                PrismSwitchRow(
                  key: ValueKey('layout-part:$part'),
                  title: layoutPartName(context, v, part),
                  value: parts.contains(part),
                  onChanged: (on) => n.update(
                    (p) => p.copyWith(
                      layoutParts: on
                          ? {...parts, part}
                          : ({...parts}..remove(part)),
                    ),
                  ),
                ),
              if (living != null && living.id != v.id)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: PrismButton(
                    label: tr(
                      context,
                      'Match my living look (${living.name})',
                      'Igualar mi estilo vivo (${living.name})',
                    ),
                    tone: PrismButtonTone.outlined,
                    expanded: true,
                    onPressed: () => applyLayout(
                      ref,
                      living.id,
                      undoMessage: tr(
                        context,
                        'Layout changed.',
                        'Diseño cambiado.',
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
