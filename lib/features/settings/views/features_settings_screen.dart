import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/features/feature_registry.dart';
import 'package:prism_plurality/core/features/feature_state.dart';
import 'package:prism_plurality/features/settings/views/boards_feature_settings_screen.dart';
import 'package:prism_plurality/features/settings/views/chat_feature_settings_screen.dart';
import 'package:prism_plurality/features/settings/views/feature_data_screen.dart';
import 'package:prism_plurality/features/settings/views/fronting_feature_settings_screen.dart';
import 'package:prism_plurality/features/settings/views/habits_feature_settings_screen.dart';
import 'package:prism_plurality/features/settings/views/notes_feature_settings_screen.dart';
import 'package:prism_plurality/features/settings/views/polls_feature_settings_screen.dart';
import 'package:prism_plurality/features/settings/views/reminders_feature_settings_screen.dart';
import 'package:prism_plurality/features/settings/views/sleep_feature_settings_screen.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/widgets/adaptive_detail_surface.dart';

/// Older per-feature settings pages, opened from a feature's details.
final Map<String, WidgetBuilder> _legacySettings = {
  'chat': (_) => const ChatFeatureSettingsScreen(),
  'fronting': (_) => const FrontingFeatureSettingsScreen(),
  'habits': (_) => const HabitsFeatureSettingsScreen(),
  'sleep': (_) => const SleepFeatureSettingsScreen(),
  'polls': (_) => const PollsFeatureSettingsScreen(),
  'notes': (_) => const NotesFeatureSettingsScreen(),
  'reminders': (_) => const RemindersFeatureSettingsScreen(),
  'boards': (_) => const BoardsFeatureSettingsScreen(),
};

String fName(BuildContext c, PrismFeature f) => tr(c, f.name.$1, f.name.$2);
String fDesc(BuildContext c, PrismFeature f) =>
    tr(c, f.description.$1, f.description.$2);

/// Settings › Features: every Prism feature from the registry, grouped by
/// category, with switches, presets and data management.
class FeaturesSettingsScreen extends ConsumerStatefulWidget {
  const FeaturesSettingsScreen({super.key, this.highlight});
  final String? highlight;
  @override
  ConsumerState<FeaturesSettingsScreen> createState() =>
      _FeaturesSettingsScreenState();
}

class _FeaturesSettingsScreenState
    extends ConsumerState<FeaturesSettingsScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final states = ref.watch(featureStatesProvider);
    final on = prismFeatures.where((f) => states[f.id] ?? true).length;
    final q = _q.trim().toLowerCase();
    final hl = widget.highlight == null
        ? null
        : prismFeatureIndex[widget.highlight!];
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: context.l10n.featuresTitle,
        showBackButton: true,
      ),
      bodyPadding: EdgeInsets.zero,
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 4, 16, NavBarInset.of(context) + 32),
        children: [
          ClampedBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hl != null && !(states[hl.id] ?? true)) ...[
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: prismCorners(context, 14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            tr(
                              context,
                              '${fName(context, hl)} is turned off.',
                              '${fName(context, hl)} está desactivado.',
                            ),
                            style: TextStyle(
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                        PrismButton(
                          label: tr(context, 'Turn on', 'Activar'),
                          tone: PrismButtonTone.filled,
                          density: PrismControlDensity.compact,
                          onPressed: () =>
                              toggleFeature(context, ref, hl, true),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  tr(
                    context,
                    'Choose the Prism you want: turn features on or off at any time. Turning a feature off hides it and pauses its reminders and background work — its data is kept.',
                    'Elige tu Prism: activa o desactiva funciones cuando quieras. Al desactivar una, se oculta y se pausan sus avisos y procesos; sus datos se conservan.',
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tr(
                    context,
                    '$on of ${prismFeatures.length} features on',
                    '$on de ${prismFeatures.length} funciones activas',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                PrismSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(context, 'Presets', 'Preajustes'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          PrismButton(
                            label: tr(context, 'Minimal', 'Mínimo'),
                            icon: PhosphorIcons.minusCircle(),
                            onPressed: () => _preset(
                              ref.read(minimalPresetProvider),
                              tr(context, 'Minimal', 'Mínimo'),
                            ),
                          ),
                          PrismButton(
                            label: tr(context, 'Maximum', 'Máximo'),
                            icon: PhosphorIcons.plusCircle(),
                            onPressed: () => _preset({
                              for (final f in prismFeatures) f.id,
                            }, tr(context, 'Maximum', 'Máximo')),
                          ),
                          PrismButton(
                            label: tr(
                              context,
                              'Customise Minimal',
                              'Personalizar Mínimo',
                            ),
                            icon: AppIcons.editOutlined,
                            density: PrismControlDensity.compact,
                            onPressed: _customiseMinimal,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                PrismTextField(
                  hintText: tr(context, 'Search features', 'Buscar funciones'),
                  prefixIcon: Icon(AppIcons.search),
                  onChanged: (v) => setState(() => _q = v),
                ),
                for (final cat in FeatureCategory.values)
                  if ([
                        for (final f in prismFeatures)
                          if (f.category == cat &&
                              (q.isEmpty ||
                                  fName(context, f).toLowerCase().contains(q) ||
                                  fDesc(context, f).toLowerCase().contains(q)))
                            f,
                      ]
                      case final list when list.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
                      child: Text(
                        tr(
                          context,
                          featureCategoryName(cat),
                          featureCategoryNameEs(cat),
                        ),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.55,
                          ),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    PrismSurface(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (final (i, f) in list.indexed) ...[
                            if (i > 0)
                              Divider(
                                height: 1,
                                indent: 60,
                                color: theme.colorScheme.outlineVariant,
                              ),
                            _FeatureRow(feature: f, on: states[f.id] ?? true),
                          ],
                        ],
                      ),
                    ),
                  ],
                const SizedBox(height: 20),
                PrismSurface(
                  onTap: () => context.push('/settings/reset-history'),
                  child: Row(
                    children: [
                      Icon(
                        PhosphorIcons.clockCounterClockwise(),
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          tr(
                            context,
                            'Reset history',
                            'Historial de restablecimientos',
                          ),
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      Icon(PhosphorIcons.caretRight(), size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _preset(Set<String> enabled, String name) async {
    final states = ref.read(featureStatesProvider);
    final turnOn = [
      for (final f in prismFeatures)
        if (!f.core && enabled.contains(f.id) && !(states[f.id] ?? true)) f,
    ];
    final turnOff = [
      for (final f in prismFeatures)
        if (!f.core && !enabled.contains(f.id) && (states[f.id] ?? true)) f,
    ];
    if (turnOn.isEmpty && turnOff.isEmpty) {
      PrismToast.show(
        context,
        message: tr(context, 'Already using $name.', 'Ya usas $name.'),
      );
      return;
    }
    final ok = await PrismDialog.confirm(
      context: context,
      title: tr(context, 'Apply $name?', '¿Aplicar $name?'),
      message: [
        if (turnOn.isNotEmpty)
          tr(
            context,
            'Turns on: ${turnOn.map((f) => fName(context, f)).join(', ')}.',
            'Activa: ${turnOn.map((f) => fName(context, f)).join(', ')}.',
          ),
        if (turnOff.isNotEmpty)
          tr(
            context,
            'Turns off: ${turnOff.map((f) => fName(context, f)).join(', ')}.',
            'Desactiva: ${turnOff.map((f) => fName(context, f)).join(', ')}.',
          ),
        tr(
          context,
          'No data is deleted — you can change this any time.',
          'No se borra ningún dato: puedes cambiarlo cuando quieras.',
        ),
      ].join('\n\n'),
      confirmLabel: tr(context, 'Apply', 'Aplicar'),
      cancelLabel: context.l10n.cancel,
    );
    if (ok != true) return;
    await ref.read(featureActionsProvider).applyPreset(enabled);
    if (mounted)
      PrismToast.show(
        context,
        message: tr(context, '$name applied', '$name aplicado'),
        icon: PhosphorIcons.check(),
      );
  }

  Future<void> _customiseMinimal() async {
    final sel = {...ref.read(minimalPresetProvider)};
    await PrismSheet.showFullScreen(
      context: context,
      builder: (ctx, scroll) => StatefulBuilder(
        builder: (ctx, set) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tr(ctx, 'Minimal preset', 'Preajuste Mínimo'),
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  PrismTopBarAction(
                    icon: AppIcons.close,
                    tooltip: tr(ctx, 'Close', 'Cerrar'),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final f in prismFeatures)
                    PrismSwitchRow(
                      title: fName(ctx, f),
                      subtitle: f.core
                          ? tr(ctx, 'Always included', 'Siempre incluida')
                          : null,
                      value: f.core || sel.contains(f.id),
                      onChanged: (v) => f.core
                          ? null
                          : set(() => v ? sel.add(f.id) : sel.remove(f.id)),
                    ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    PrismButton(
                      label: tr(ctx, 'Restore default', 'Restaurar'),
                      onPressed: () => set(
                        () => sel
                          ..clear()
                          ..addAll({
                            for (final f in prismFeatures)
                              if (f.core || f.essential) f.id,
                          }),
                      ),
                    ),
                    const Spacer(),
                    PrismButton(
                      label: ctx.l10n.save,
                      tone: PrismButtonTone.filled,
                      onPressed: () async {
                        await ref
                            .read(featureActionsProvider)
                            .saveMinimalPreset(sel);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Turns a feature on or off, handling dependencies first.
Future<void> toggleFeature(
  BuildContext context,
  WidgetRef ref,
  PrismFeature f,
  bool on,
) async {
  final actions = ref.read(featureActionsProvider);
  final states = ref.read(featureStatesProvider);
  if (on) {
    final missing = [
      for (final d in f.dependsOn)
        if (!(states[d] ?? true)) prismFeatureIndex[d]!,
    ];
    if (missing.isNotEmpty) {
      final ok = await PrismDialog.confirm(
        context: context,
        title: tr(
          context,
          'Turn on ${fName(context, f)}?',
          '¿Activar ${fName(context, f)}?',
        ),
        message: tr(
          context,
          'It needs ${missing.map((m) => fName(context, m)).join(', ')}, which will be turned on too.',
          'Necesita ${missing.map((m) => fName(context, m)).join(', ')}, que también se activará.',
        ),
        confirmLabel: tr(context, 'Turn on', 'Activar'),
        cancelLabel: context.l10n.cancel,
      );
      if (ok != true) return;
      for (final m in missing) {
        await actions.setEnabled(m.id, true);
      }
    }
    await actions.setEnabled(f.id, true);
    return;
  }
  final dependents = [
    for (final d in dependentsOf(f.id))
      if (states[d.id] ?? true) d,
  ];
  if (dependents.isNotEmpty) {
    String? choice;
    await PrismSheet.show(
      context: context,
      title: tr(
        context,
        'Turn off ${fName(context, f)}?',
        '¿Desactivar ${fName(context, f)}?',
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr(
                ctx,
                '${dependents.map((d) => fName(ctx, d)).join(', ')} use${dependents.length == 1 ? 's' : ''} it. You can turn ${dependents.length == 1 ? 'it' : 'them'} off too, or keep ${dependents.length == 1 ? 'it' : 'them'} on (parts that need ${fName(ctx, f)} will be empty).',
                '${dependents.map((d) => fName(ctx, d)).join(', ')} la usa${dependents.length == 1 ? '' : 'n'}. Puedes desactivarla${dependents.length == 1 ? '' : 's'} también o mantenerla${dependents.length == 1 ? '' : 's'} (las partes que necesitan ${fName(ctx, f)} quedarán vacías).',
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                PrismButton(
                  label: ctx.l10n.cancel,
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                PrismButton(
                  label: tr(ctx, 'Only this', 'Solo esta'),
                  onPressed: () {
                    choice = 'one';
                    Navigator.of(ctx).pop();
                  },
                ),
                PrismButton(
                  label: tr(ctx, 'Turn off all', 'Desactivar todas'),
                  tone: PrismButtonTone.filled,
                  onPressed: () {
                    choice = 'all';
                    Navigator.of(ctx).pop();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (choice == 'all') {
      for (final d in dependents) {
        await actions.setEnabled(d.id, false);
      }
    }
  }
  await actions.setEnabled(f.id, false);
}

class _FeatureRow extends ConsumerWidget {
  const _FeatureRow({required this.feature, required this.on});
  final PrismFeature feature;
  final bool on;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final f = feature;
    final states = ref.watch(featureStatesProvider);
    final missingDeps = [
      for (final d in f.dependsOn)
        if (!(states[d] ?? true)) prismFeatureIndex[d]!,
    ];
    final status = f.core
        ? tr(context, 'Always on', 'Siempre activa')
        : (missingDeps.isNotEmpty
              ? tr(
                  context,
                  'Needs ${missingDeps.map((m) => fName(context, m)).join(', ')}',
                  'Necesita ${missingDeps.map((m) => fName(context, m)).join(', ')}',
                )
              : (on
                    ? tr(context, 'On', 'Activa')
                    : tr(context, 'Off', 'Desactivada')));
    return Semantics(
      label: '${fName(context, f)}, $status',
      child: InkWell(
        onTap: () => showFeatureDetails(context, ref, f),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(
                    alpha: on ? 0.14 : 0.06,
                  ),
                  borderRadius: prismCorners(context, 10),
                ),
                child: Icon(
                  f.icon,
                  size: 20,
                  color: on
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fName(context, f),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      fDesc(context, f),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      status,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: on
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (!f.core)
                Switch.adaptive(
                  value: on,
                  onChanged: (v) => toggleFeature(context, ref, f, v),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Details for one feature: dependencies, permissions, background work,
/// settings and data management.
Future<void> showFeatureDetails(
  BuildContext context,
  WidgetRef ref,
  PrismFeature f,
) => PrismSheet.show(
  context: context,
  title: fName(context, f),
  builder: (ctx) => Consumer(
    builder: (ctx, ref, _) {
      final theme = Theme.of(ctx);
      final on = ref.watch(featureEnabledProvider(f.id));
      final router = GoRouter.of(context);
      Widget line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
          ],
        ),
      );
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(fDesc(ctx, f), style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            line(
              PhosphorIcons.folders(),
              tr(
                ctx,
                featureCategoryName(f.category),
                featureCategoryNameEs(f.category),
              ),
            ),
            if (f.dependsOn.isNotEmpty)
              line(
                PhosphorIcons.link(),
                tr(
                  ctx,
                  'Needs: ${f.dependsOn.map((d) => fName(ctx, prismFeatureIndex[d]!)).join(', ')}',
                  'Necesita: ${f.dependsOn.map((d) => fName(ctx, prismFeatureIndex[d]!)).join(', ')}',
                ),
              ),
            if (dependentsOf(f.id).isNotEmpty)
              line(
                PhosphorIcons.treeStructure(),
                tr(
                  ctx,
                  'Used by: ${dependentsOf(f.id).map((d) => fName(ctx, d)).join(', ')}',
                  'La usan: ${dependentsOf(f.id).map((d) => fName(ctx, d)).join(', ')}',
                ),
              ),
            if (f.permissions != null)
              line(
                PhosphorIcons.shieldCheck(),
                tr(
                  ctx,
                  'May ask for: ${f.permissions!.$1}',
                  'Puede pedir: ${f.permissions!.$2}',
                ),
              ),
            for (final b in f.background)
              line(
                PhosphorIcons.gear(),
                tr(
                  ctx,
                  'Background: ${b.$1} (paused while off)',
                  'En segundo plano: ${b.$2} (en pausa si está desactivada)',
                ),
              ),
            if (!f.core)
              PrismSwitchRow(
                title: tr(ctx, 'Enabled', 'Activada'),
                value: on,
                onChanged: (v) => toggleFeature(ctx, ref, f, v),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (f.route != null && on)
                  PrismButton(
                    label: tr(ctx, 'Open', 'Abrir'),
                    icon: PhosphorIcons.arrowSquareOut(),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      router.go(f.route!);
                    },
                  ),
                if (_legacySettings[f.id] case final b?)
                  PrismButton(
                    label: tr(ctx, 'Settings', 'Ajustes'),
                    icon: AppIcons.navSettings,
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      showAdaptiveDetailSurface<void>(
                        context: context,
                        builder: b,
                        route: (c) => c.go(f.settingsRoute!),
                      );
                    },
                  ),
                PrismButton(
                  label: tr(ctx, 'Data management', 'Gestión de datos'),
                  icon: PhosphorIcons.database(),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    openFeatureData(context, f.id);
                  },
                ),
              ],
            ),
          ],
        ),
      );
    },
  ),
);
