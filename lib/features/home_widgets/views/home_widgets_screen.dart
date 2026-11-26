import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/features/home_widgets/models/widget_catalog.dart';
import 'package:prism_plurality/features/home_widgets/services/home_widget_controller.dart';
import 'package:prism_plurality/features/home_widgets/services/home_widget_data.dart';
import 'package:prism_plurality/features/home_widgets/services/home_widget_models.dart';
import 'package:prism_plurality/features/home_widgets/services/home_widget_platform.dart';
import 'package:prism_plurality/features/home_widgets/services/home_widget_store.dart';
import 'package:prism_plurality/features/home_widgets/views/widget_preview.dart';
import 'package:prism_plurality/features/trackers/widgets/tracker_widgets.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/info_banner.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_loading_state.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/shared/widgets/prism_toast.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';

/// Widgets currently on the home screen (refreshed on demand).
final placedWidgetsProvider = FutureProvider.autoDispose<List<PlacedWidget>>(
  (ref) => ref.watch(homeWidgetPlatformProvider).listWidgets(),
);

/// The Home Screen Widgets section: library, placed widgets, presets and
/// how-to for Samsung One UI.
class HomeWidgetsScreen extends ConsumerStatefulWidget {
  const HomeWidgetsScreen({super.key});

  @override
  ConsumerState<HomeWidgetsScreen> createState() => _HomeWidgetsScreenState();
}

class _HomeWidgetsScreenState extends ConsumerState<HomeWidgetsScreen>
    with WidgetsBindingObserver {
  WidgetCategory? _category;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the launcher after adding or removing a widget.
    if (state == AppLifecycleState.resumed)
      ref.invalidate(placedWidgetsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final platform = ref.watch(homeWidgetPlatformProvider);
    final async = ref.watch(homeWidgetsProvider);
    final placed =
        ref.watch(placedWidgetsProvider).value ?? const <PlacedWidget>[];
    final data = ref.watch(homeWidgetDataProvider);
    final dark = theme.brightness == Brightness.dark;
    return PrismPageScaffold(
      topBar: PrismTopBar(title: l10n.hwTopBar, showBackButton: true),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: async.when(
        loading: () => const PrismLoadingState(),
        error: (e, _) => Center(child: Text(l10n.errorWithDetail(e))),
        data: (state) {
          final types = [
            for (final t in widgetCatalog)
              if (_category == null || t.category == _category) t,
          ];
          final recent = [
            for (final r in state.recent)
              if (widgetCatalog.any((w) => w.key == r)) r,
          ];

          Future<void> pin(String type) async {
            final ok = await platform.pin(type);
            if (!context.mounted) return;
            if (!ok) PrismToast.show(context, message: l10n.hwPinUnsupported);
          }

          final children = <Widget>[
            if (!platform.isSupported)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InfoBanner(
                  icon: AppIcons.errorOutline,
                  iconColor: theme.colorScheme.tertiary,
                  title: l10n.hwUnsupportedTitle,
                  message: l10n.hwUnsupportedMessage,
                  actionsBelow: true,
                ),
              ),
            Text(
              l10n.hwIntro,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            // ---- placed
            TrackerLabel(l10n.hwOnHomeScreen),
            if (placed.isEmpty)
              PrismSurface(
                child: Text(
                  l10n.hwNonePlaced,
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else
              for (final w in placed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PrismSurface(
                    onTap: () => context.push(
                      AppRoutePaths.widgetStudio(w.type, id: w.id),
                    ),
                    child: Row(
                      children: [
                        Text(
                          widgetTypeInfo(w.type).emoji,
                          style: const TextStyle(fontSize: 26),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widgetTypeLabel(l10n, w.type),
                                style: theme.textTheme.titleMedium,
                              ),
                              Text(
                                [
                                  switch (w.size) {
                                    'small' => l10n.hwSizeSmall,
                                    'medium' => l10n.hwSizeMedium,
                                    _ => l10n.hwSizeLarge,
                                  },
                                  if (state.configs.containsKey(w.id))
                                    l10n.hwCustomized
                                  else
                                    l10n.hwUsingDefault,
                                ].join(' · '),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          AppIcons.tuneOutlined,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),

            // ---- recently used
            if (recent.isNotEmpty) ...[
              TrackerLabel(l10n.hwRecentlyUsed),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final r in recent)
                    PrismChip(
                      label:
                          '${widgetTypeInfo(r).emoji} ${widgetTypeLabel(l10n, r)}',
                      selected: false,
                      onTap: () => context.push(AppRoutePaths.widgetStudio(r)),
                    ),
                ],
              ),
            ],

            // ---- library
            TrackerLabel(l10n.hwLibrary),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                PrismChip(
                  label: l10n.hwOptAll,
                  selected: _category == null,
                  onTap: () => setState(() => _category = null),
                ),
                for (final c in WidgetCategory.values)
                  PrismChip(
                    label: widgetCategoryLabel(l10n, c),
                    selected: _category == c,
                    onTap: () => setState(() => _category = c),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            for (final t in types)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: PrismSurface(
                  onTap: () => context.push(AppRoutePaths.widgetStudio(t.key)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(t.emoji, style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widgetTypeLabel(l10n, t.key),
                                  style: theme.textTheme.titleMedium,
                                ),
                                Text(
                                  widgetTypeDescription(l10n, t.key),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (data != null) ...[
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final size in const ['small', 'medium'])
                                Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: IgnorePointer(
                                    child: WidgetPreview(
                                      model: buildWidgetModel(
                                        state.configFor(null, t.key),
                                        data,
                                        l10n,
                                        l10n.localeName,
                                      ),
                                      config: state.configFor(null, t.key),
                                      data: data,
                                      size: size,
                                      dark: dark,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          PrismButton(
                            label: l10n.hwCustomize,
                            density: PrismControlDensity.compact,
                            onPressed: () =>
                                context.push(AppRoutePaths.widgetStudio(t.key)),
                          ),
                          if (platform.isSupported)
                            PrismButton(
                              label: l10n.hwAddToHome,
                              density: PrismControlDensity.compact,
                              tone: PrismButtonTone.filled,
                              onPressed: () => pin(t.key),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // ---- presets
            if (state.presets.isNotEmpty) ...[
              TrackerLabel(l10n.hwPresets),
              for (final p in state.presets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: PrismSurface(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Text(
                          widgetTypeInfo(p.type).emoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${p.name} · ${widgetTypeLabel(l10n, p.type)}',
                          ),
                        ),
                        PrismButton(
                          label: l10n.delete,
                          density: PrismControlDensity.compact,
                          tone: PrismButtonTone.destructive,
                          onPressed: () => ref
                              .read(homeWidgetsProvider.notifier)
                              .deletePreset(p),
                        ),
                      ],
                    ),
                  ),
                ),
            ],

            // ---- how to
            TrackerLabel(l10n.hwHowToTitle),
            PrismSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, step) in [
                    l10n.hwHowTo1,
                    l10n.hwHowTo2,
                    l10n.hwHowTo3,
                    l10n.hwHowTo4,
                    l10n.hwHowTo5,
                  ].indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text(
                              '${i + 1}.',
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              step,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    l10n.hwQuickActionNote,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: PrismTokens.contentMaxWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
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
