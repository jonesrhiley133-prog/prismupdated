import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/features/yumeships/yume_data.dart';
import 'package:prism_plurality/features/yumeships/yume_widgets.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Yumeships settings: dashboard layout, defaults, PIN, profiles, calendar.
class YumeSettingsScreen extends ConsumerWidget {
  const YumeSettingsScreen({super.key, this.initialSection});
  final String? initialSection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(yumeSettingsProvider);
    final a = ref.read(yumeActionsProvider);
    final names = ref.watch(yumeMemberNamesProvider);
    final theme = Theme.of(context);
    final dash = s.dashboard;
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(context, 'Yumeships settings', 'Ajustes de Yumeships'),
        showBackButton: true,
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            YumeSectionTitle(tr(context, 'Dashboard', 'Panel'), emoji: '🧭'),
            Text(
              tr(
                context,
                'Drag to reorder; switch off sections you don’t want.',
                'Arrastra para ordenar; apaga lo que no quieras.',
              ),
              style: theme.textTheme.bodySmall,
            ),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorder: (from, to) {
                final list = [...dash];
                if (to > from) to--;
                list.insert(to, list.removeAt(from));
                a.saveSettings({
                  'dash': [
                    for (final (id, v) in list) {'id': id, 'visible': v},
                  ],
                });
              },
              children: [
                for (var i = 0; i < dash.length; i++)
                  SwitchListTile(
                    key: ValueKey(dash[i].$1),
                    contentPadding: EdgeInsets.zero,
                    secondary: ReorderableDragStartListener(
                      index: i,
                      child: const Icon(Icons.drag_handle),
                    ),
                    title: Text(
                      tr(
                        context,
                        yumeDashSections[dash[i].$1]!.$1,
                        yumeDashSections[dash[i].$1]!.$2,
                      ),
                    ),
                    value: dash[i].$2,
                    onChanged: (v) => a.saveSettings({
                      'dash': [
                        for (final (id, on) in dash)
                          {'id': id, 'visible': id == dash[i].$1 ? v : on},
                      ],
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            PrismSelect<String>(
              labelText: tr(
                context,
                'How yumeships are shown',
                'Cómo se muestran',
              ),
              value: s.view,
              items: [
                for (final e in yumeViews.entries)
                  PrismSelectItem(
                    value: e.key,
                    label: tr(context, e.value.$1, e.value.$2),
                  ),
              ],
              onChanged: (v) => a.saveSettings({'view': v}),
            ),
            const SizedBox(height: 8),
            PrismListRow(
              padding: EdgeInsets.zero,
              title: Text(
                tr(context, 'Arrange yumeships', 'Ordenar yumeships'),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutePaths.yumeArrange),
            ),
            PrismListRow(
              padding: EdgeInsets.zero,
              title: Text(
                tr(context, 'Arrange collections', 'Ordenar colecciones'),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutePaths.yumeArrangeCollections),
            ),
            YumeSectionTitle(tr(context, 'Privacy', 'Privacidad'), emoji: '🔒'),
            PrismSelect<String>(
              labelText: tr(
                context,
                'New items are visible to',
                'Los nuevos elementos son visibles para',
              ),
              value: s.defaultVisibility,
              items: [
                for (final e in yumeVisibilities.entries)
                  PrismSelectItem(
                    value: e.key,
                    label: tr(context, e.value.$1, e.value.$2),
                    subtitle: e.value.$3,
                  ),
              ],
              onChanged: (v) => a.saveSettings({'defaultVisibility': v}),
            ),
            const SizedBox(height: 8),
            PrismListRow(
              padding: EdgeInsets.zero,
              leading: const Icon(Icons.pin_outlined),
              title: Text(
                s.hasPin
                    ? tr(
                        context,
                        'Change Yumeships PIN',
                        'Cambiar PIN de Yumeships',
                      )
                    : tr(
                        context,
                        'Set a Yumeships PIN',
                        'Crear un PIN de Yumeships',
                      ),
              ),
              subtitle: Text(
                tr(
                  context,
                  'Used for items you lock. Separate from the app lock.',
                  'Para los elementos que bloquees. Aparte del bloqueo de la app.',
                ),
              ),
              onTap: () async {
                if (s.hasPin && !await yumeUnlock(context, ref)) return;
                if (!context.mounted) return;
                final pin = await yumeAskPin(
                  context,
                  title: tr(
                    context,
                    'New PIN (4–8 digits)',
                    'Nuevo PIN (4–8 dígitos)',
                  ),
                );
                if (pin == null || !context.mounted) return;
                final again = await yumeAskPin(
                  context,
                  title: tr(context, 'Repeat the PIN', 'Repite el PIN'),
                );
                if (!context.mounted) return;
                if (again != pin) {
                  PrismToast.error(
                    context,
                    message: tr(
                      context,
                      'The PINs didn’t match',
                      'Los PIN no coinciden',
                    ),
                  );
                  return;
                }
                await a.setPin(pin);
                if (context.mounted)
                  PrismToast.success(
                    context,
                    message: tr(context, 'PIN saved', 'PIN guardado'),
                  );
              },
            ),
            if (s.hasPin)
              PrismListRow(
                padding: EdgeInsets.zero,
                leading: const Icon(Icons.no_encryption_outlined),
                title: Text(tr(context, 'Remove PIN', 'Quitar PIN')),
                subtitle: Text(
                  tr(
                    context,
                    'Locked items open without a PIN afterwards.',
                    'Después, los elementos bloqueados se abren sin PIN.',
                  ),
                ),
                onTap: () async {
                  if (!await yumeUnlock(context, ref)) return;
                  await a.setPin(null);
                },
              ),
            YumeSectionTitle(
              tr(context, 'Calendar & notifications', 'Calendario y avisos'),
              emoji: '🗓️',
            ),
            PrismSwitchRow(
              padding: EdgeInsets.zero,
              title: tr(
                context,
                'Put new dates on the calendar',
                'Poner las fechas nuevas en el calendario',
              ),
              value: s.calendarDefault,
              onChanged: (v) => a.saveSettings({'calendarDefault': v}),
            ),
            PrismSwitchRow(
              padding: EdgeInsets.zero,
              title: tr(
                context,
                'Notify for new dates',
                'Avisar de las fechas nuevas',
              ),
              subtitle: tr(
                context,
                'Off by default; every date and yumeship can choose.',
                'Apagado por defecto; cada fecha y yumeship puede elegir.',
              ),
              value: s.notifyDefault,
              onChanged: (v) => a.saveSettings({'notifyDefault': v}),
            ),
            YumeSectionTitle(
              tr(context, 'Alter profiles', 'Perfiles de alters'),
              emoji: '👤',
            ),
            Text(
              tr(
                context,
                'Show a Yumeships section on these alters’ profiles (only the ships the viewer may see).',
                'Mostrar una sección de Yumeships en estos perfiles (solo los ships que quien mira puede ver).',
              ),
              style: theme.textTheme.bodySmall,
            ),
            for (final e in names.entries)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(e.value),
                value: s.profileMembers.contains(e.key),
                onChanged: (v) => a.setProfileSection(e.key, v),
              ),
            YumeSectionTitle(
              tr(context, 'Navigation', 'Navegación'),
              emoji: '🧩',
            ),
            PrismListRow(
              padding: EdgeInsets.zero,
              title: Text(
                tr(
                  context,
                  'Show or hide Yumeships in the menu',
                  'Mostrar u ocultar Yumeships en el menú',
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutePaths.settingsNavigation),
            ),
            PrismListRow(
              padding: EdgeInsets.zero,
              title: Text(
                tr(context, 'Turn the feature off', 'Desactivar la función'),
              ),
              subtitle: Text(
                tr(
                  context,
                  'Your yumeships are kept and come back when it’s on again.',
                  'Tus yumeships se guardan y vuelven al activarla.',
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutePaths.settingsFeatures),
            ),
          ],
        ),
      ),
    );
  }
}
