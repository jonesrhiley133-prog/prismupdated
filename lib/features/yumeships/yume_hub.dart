import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/features/subsystems/hub/subsystem_data.dart';
import 'package:prism_plurality/features/yumeships/yume_collections.dart';
import 'package:prism_plurality/features/yumeships/yume_data.dart';
import 'package:prism_plurality/features/yumeships/yume_ship_editor.dart';
import 'package:prism_plurality/features/yumeships/yume_sonas.dart';
import 'package:prism_plurality/features/yumeships/yume_studio.dart';
import 'package:prism_plurality/features/yumeships/yume_widgets.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Opens a ship, asking for the PIN first when it's locked.
Future<void> yumeOpenShip(
  BuildContext context,
  WidgetRef ref,
  YumeShip s,
) async {
  if (s.locked && !ref.read(yumeUnlocksProvider.notifier).isOpen(s.id)) {
    if (!await yumeUnlock(context, ref, id: s.id)) return;
  }
  if (context.mounted) context.push(AppRoutePaths.yumeShip(s.id));
}

/// The Yumeships organizer: a personal fandom journal of featured ships,
/// collections on shelves, upcoming dates and recent creations.
class YumeshipsHubScreen extends ConsumerStatefulWidget {
  const YumeshipsHubScreen({super.key});
  @override
  ConsumerState<YumeshipsHubScreen> createState() => _YumeshipsHubScreenState();
}

class _YumeshipsHubScreenState extends ConsumerState<YumeshipsHubScreen> {
  final _search = TextEditingController();
  String? _alter, _subsystem, _source, _rel;
  bool _showArchived = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _newMenu() async {
    final choice = await PrismSheet.show<String>(
      context: context,
      title: tr(context, 'Create', 'Crear'),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrismListRow(
            leading: const Text('💞', style: TextStyle(fontSize: 22)),
            title: Text(tr(ctx, 'Yumeship', 'Yumeship')),
            subtitle: Text(
              tr(
                ctx,
                'A ship with one or more F/Os',
                'Un ship con uno o más F/Os',
              ),
            ),
            onTap: () => Navigator.of(ctx).pop('ship'),
          ),
          PrismListRow(
            leading: const Text('🪞', style: TextStyle(fontSize: 22)),
            title: Text(tr(ctx, 'Sona or self-insert', 'Sona o self-insert')),
            subtitle: Text(
              tr(
                ctx,
                'A creative persona — never an alter',
                'Una persona creativa — nunca un alter',
              ),
            ),
            onTap: () => Navigator.of(ctx).pop('sona'),
          ),
          PrismListRow(
            leading: const Text('📚', style: TextStyle(fontSize: 22)),
            title: Text(tr(ctx, 'Collection', 'Colección')),
            subtitle: Text(
              tr(ctx, 'Group ships on a shelf', 'Agrupa ships en un estante'),
            ),
            onTap: () => Navigator.of(ctx).pop('collection'),
          ),
          PrismListRow(
            leading: const Text('🎨', style: TextStyle(fontSize: 22)),
            title: Text(tr(ctx, 'Creative entry', 'Entrada creativa')),
            subtitle: Text(
              tr(ctx, 'Open the Creative Studio', 'Abrir el Estudio creativo'),
            ),
            onTap: () => Navigator.of(ctx).pop('studio'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'ship':
        await showYumeShipEditor(context);
      case 'sona':
        await showYumeSonaEditor(context);
      case 'collection':
        await showYumeCollectionEditor(context);
      case 'studio':
        await context.push(AppRoutePaths.yumeStudio());
    }
  }

  List<YumeShip> _filtered(List<YumeShip> all) {
    final q = _search.text.trim().toLowerCase();
    final subMembers = _subsystem == null
        ? null
        : {
            for (final m in ref.read(subMembershipsProvider))
              if (m.subsystemId == _subsystem) m.memberId,
          };
    final list = all.where((s) {
      if (!_showArchived && s.archived) return false;
      if (_alter != null &&
          !s.owners.contains(_alter) &&
          !s.collaborators.contains(_alter))
        return false;
      if (subMembers != null &&
          !s.owners.any(subMembers.contains) &&
          !s.collaborators.any(subMembers.contains))
        return false;
      if (_source != null && !s.sources.contains(_source)) return false;
      if (_rel != null && !s.relTypes.contains(_rel)) return false;
      if (q.isNotEmpty && !s.searchText().contains(q)) return false;
      return true;
    }).toList();
    final sort = ref.read(yumeSettingsProvider).sort;
    final now = DateTime.now();
    int nextDays(YumeShip s) {
      final a = s.anniversary;
      if (a == null) return 9999;
      var n = DateTime(now.year, a.month, a.day);
      if (n.isBefore(DateTime(now.year, now.month, now.day)))
        n = DateTime(now.year + 1, a.month, a.day);
      return n.difference(now).inDays;
    }

    switch (sort) {
      case 'name':
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case 'recent':
        list.sort(
          (a, b) => (b.lastOpened ?? b.r.modifiedAt).compareTo(
            a.lastOpened ?? a.r.modifiedAt,
          ),
        );
      case 'anniversary':
        list.sort((a, b) => nextDays(a).compareTo(nextDays(b)));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final ships = ref.watch(yumeShipsProvider);
    final settings = ref.watch(yumeSettingsProvider);
    final theme = Theme.of(context);
    final filtered = _filtered(ships);
    final sections = [
      for (final (id, on) in settings.dashboard)
        if (on) id,
    ];
    final hasPin = settings.hasPin;
    final unlockedAll = ref.watch(yumeUnlocksProvider).contains('*');

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: 'Yumeships',
        actions: [
          if (hasPin)
            PrismTopBarAction(
              icon: unlockedAll ? Icons.lock_open : Icons.lock_outline,
              tooltip: unlockedAll
                  ? tr(context, 'Lock again', 'Bloquear de nuevo')
                  : tr(context, 'Unlock everything', 'Desbloquear todo'),
              onPressed: () => unlockedAll
                  ? ref.read(yumeUnlocksProvider.notifier).lockAll()
                  : yumeUnlock(context, ref),
            ),
          PrismTopBarAction(
            icon: Icons.palette_outlined,
            tooltip: tr(context, 'Creative Studio', 'Estudio creativo'),
            onPressed: () => context.push(AppRoutePaths.yumeStudio()),
          ),
          PrismTopBarAction(
            icon: Icons.tune,
            tooltip: tr(context, 'Yumeships settings', 'Ajustes de Yumeships'),
            onPressed: () => context.push(AppRoutePaths.yumeSettings()),
          ),
          PrismTopBarAction(
            icon: Icons.add,
            tooltip: tr(context, 'Create', 'Crear'),
            onPressed: _newMenu,
          ),
        ],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 32 + NavBarInset.of(context)),
          children: [
            if (ref.watch(yumeAllShipsProvider).isEmpty &&
                ref.watch(yumeAllSonasProvider).isEmpty)
              _Welcome(onCreate: () => showYumeShipEditor(context))
            else
              for (final id in sections)
                ...switch (id) {
                  'featured' => _featured(ships),
                  'upcoming' => _upcoming(),
                  'collections' => _collections(),
                  'ships' => _shipsSection(filtered, ships, settings),
                  'sonas' => _sonas(),
                  'recent' => _recent(),
                  _ => const <Widget>[],
                },
            const SizedBox(height: 16),
            Center(
              child: YumeAction(
                label: tr(
                  context,
                  'Customize this page',
                  'Personalizar esta página',
                ),
                icon: Icons.dashboard_customize_outlined,
                onPressed: () => context.push(
                  AppRoutePaths.yumeSettings(section: 'dashboard'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                tr(
                  context,
                  'Fictional others and sonas live only here — they never appear as alters or in fronting.',
                  'Los personajes y sonas viven solo aquí — nunca aparecen como alters ni en el frente.',
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _featured(List<YumeShip> ships) {
    final featured = [
      for (final s in ships)
        if (!s.archived && (s.pinned || s.favorite)) s,
    ];
    final list = featured.isEmpty
        ? ships.where((s) => !s.archived).take(3).toList()
        : featured;
    if (list.isEmpty) return const [];
    return [
      YumeSectionTitle(tr(context, 'Featured', 'Destacados'), emoji: '💫'),
      YumeShelf(
        height: 210,
        children: [
          for (final s in list)
            SizedBox(width: 290, child: YumeFeaturedCard(ship: s)),
        ],
      ),
    ];
  }

  List<Widget> _upcoming() {
    final up = ref.watch(yumeUpcomingProvider);
    if (up.isEmpty) return const [];
    final now = DateTime.now();
    final countdowns = [
      for (final u in up)
        if (u.event?.countdown ?? false) u,
    ];
    return [
      YumeSectionTitle(
        tr(context, 'Upcoming dates', 'Próximas fechas'),
        emoji: '🗓️',
      ),
      if (countdowns.isNotEmpty)
        YumeShelf(
          height: 118,
          children: [
            for (final u in countdowns.take(6))
              SizedBox(width: 170, child: _CountdownCard(u: u)),
          ],
        ),
      for (final u in up.take(4))
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: YumeCard(
            accent: yumeAccent(context, u.ship.accent),
            card: 'flat',
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            onTap: () => yumeOpenShip(context, ref, u.ship),
            child: Row(
              children: [
                Text(u.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u.label,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        '${u.ship.name} · ${yumeDate(u.on, noYear: true)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                YumeCountdownPill(
                  days: u.daysFrom(now),
                  accent: yumeAccent(context, u.ship.accent),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  List<Widget> _collections() {
    final cols = ref.watch(yumeCollectionsProvider);
    return [
      YumeSectionTitle(
        tr(context, 'Collections', 'Colecciones'),
        emoji: '📚',
        trailing: YumeAction(
          label: tr(context, 'New', 'Nueva'),
          onPressed: () => showYumeCollectionEditor(context),
        ),
      ),
      if (cols.isEmpty)
        Text(
          tr(
            context,
            'Shelve your ships — romantic, platonic, comfort characters, by source, or anything you like.',
            'Ordena tus ships en estantes — románticos, platónicos, de consuelo, por obra o como quieras.',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        )
      else
        YumeShelf(
          height: 170,
          children: [
            for (final c in cols)
              SizedBox(width: 132, child: YumeCollectionCover(c: c)),
          ],
        ),
    ];
  }

  List<Widget> _sonas() {
    final sonas = ref.watch(yumeSonasProvider);
    return [
      YumeSectionTitle(
        tr(context, 'Sonas & self-inserts', 'Sonas y self-inserts'),
        emoji: '🪞',
        trailing: YumeAction(
          label: tr(context, 'All', 'Todas'),
          onPressed: () => context.push(AppRoutePaths.yumeSonas),
        ),
      ),
      if (sonas.isEmpty)
        Align(
          alignment: Alignment.centerLeft,
          child: PrismButton(
            label: tr(context, 'Create a sona', 'Crear una sona'),
            icon: Icons.add,
            onPressed: () => showYumeSonaEditor(context),
          ),
        )
      else
        YumeShelf(
          height: 112,
          children: [
            for (final s in sonas) YumeSonaBubble(sona: s),
            _AddBubble(onTap: () => showYumeSonaEditor(context)),
          ],
        ),
    ];
  }

  List<Widget> _recent() {
    final list = ref.watch(yumeCreationsProvider).take(8).toList();
    return [
      YumeSectionTitle(
        tr(context, 'Recent creations', 'Creaciones recientes'),
        emoji: '🎨',
        trailing: YumeAction(
          label: tr(context, 'Studio', 'Estudio'),
          onPressed: () => context.push(AppRoutePaths.yumeStudio()),
        ),
      ),
      if (list.isEmpty)
        Text(
          tr(
            context,
            'Intro cards, bingo, questionnaires, moodboards, fic trackers and more live in the Creative Studio.',
            'Tarjetas, bingo, cuestionarios, moodboards, fics y más viven en el Estudio creativo.',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        )
      else
        YumeShelf(
          height: 120,
          children: [
            for (final c in list)
              SizedBox(width: 160, child: YumeCreationTile(c: c)),
          ],
        ),
    ];
  }

  List<Widget> _shipsSection(
    List<YumeShip> filtered,
    List<YumeShip> all,
    YumeSettings settings,
  ) {
    final members = ref.watch(yumeMemberNamesProvider);
    final owners = {
      for (final s in all) ...s.owners,
      for (final s in all) ...s.collaborators,
    }.where(members.containsKey).toList();
    final sources = {for (final s in all) ...s.sources}.toList()..sort();
    final subsystems = ref.watch(subsystemsProvider);
    final actions = ref.read(yumeActionsProvider);
    return [
      YumeSectionTitle(
        tr(context, 'Yumeships', 'Yumeships'),
        emoji: '💞',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: tr(context, 'View', 'Vista'),
              icon: const Icon(Icons.view_module_outlined),
              onPressed: () async {
                final v = await yumeChoose(
                  context,
                  title: tr(context, 'View', 'Vista'),
                  selected: settings.view,
                  options: {
                    for (final e in yumeViews.entries)
                      e.key: tr(context, e.value.$1, e.value.$2),
                  },
                );
                if (v != null) await actions.saveSettings({'view': v});
              },
            ),
            IconButton(
              tooltip: tr(context, 'Sort', 'Ordenar'),
              icon: const Icon(Icons.sort),
              onPressed: () async {
                final v = await yumeChoose(
                  context,
                  title: tr(context, 'Sort', 'Ordenar'),
                  selected: settings.sort,
                  options: {
                    'manual': tr(context, 'My order', 'Mi orden'),
                    'name': tr(context, 'Name', 'Nombre'),
                    'recent': tr(
                      context,
                      'Recently opened',
                      'Abiertos recientemente',
                    ),
                    'anniversary': tr(
                      context,
                      'Next anniversary',
                      'Próximo aniversario',
                    ),
                    'arrange': tr(
                      context,
                      'Arrange by dragging…',
                      'Ordenar arrastrando…',
                    ),
                  },
                );
                if (!context.mounted || v == null) return;
                if (v == 'arrange') {
                  await context.push(AppRoutePaths.yumeArrange);
                } else {
                  await actions.saveSettings({'sort': v});
                }
              },
            ),
          ],
        ),
      ),
      PrismTextField(
        controller: _search,
        hintText: tr(
          context,
          'Search ships, F/Os, sources, tags…',
          'Busca ships, F/Os, obras, etiquetas…',
        ),
        prefixIcon: const Icon(Icons.search),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final e in yumeRelTypes.entries.where(
              (e) => e.key != 'custom',
            ))
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: PrismChip(
                  label: '${e.value.$3} ${tr(context, e.value.$1, e.value.$2)}',
                  selected: _rel == e.key,
                  onTap: () =>
                      setState(() => _rel = _rel == e.key ? null : e.key),
                ),
              ),
            if (owners.isNotEmpty)
              _FilterMenu(
                label: _alter == null
                    ? tr(context, 'Any alter', 'Cualquier alter')
                    : members[_alter] ?? '',
                active: _alter != null,
                options: {for (final o in owners) o: members[o] ?? o},
                onSelected: (v) => setState(() => _alter = v),
              ),
            if (subsystems.isNotEmpty)
              _FilterMenu(
                label: _subsystem == null
                    ? tr(context, 'Any subsystem', 'Cualquier subsistema')
                    : subsystems
                              .where((s) => s.id == _subsystem)
                              .firstOrNull
                              ?.title ??
                          '',
                active: _subsystem != null,
                options: {for (final s in subsystems) s.id: s.title},
                onSelected: (v) => setState(() => _subsystem = v),
              ),
            if (sources.isNotEmpty)
              _FilterMenu(
                label: _source ?? tr(context, 'Any source', 'Cualquier obra'),
                active: _source != null,
                options: {for (final s in sources) s: s},
                onSelected: (v) => setState(() => _source = v),
              ),
            PrismChip(
              label: tr(context, 'Archived', 'Archivados'),
              selected: _showArchived,
              onTap: () => setState(() => _showArchived = !_showArchived),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (filtered.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            all.isEmpty
                ? tr(context, 'No yumeships yet.', 'Aún no hay yumeships.')
                : tr(
                    context,
                    'Nothing matches these filters.',
                    'Nada coincide con estos filtros.',
                  ),
            textAlign: TextAlign.center,
          ),
        )
      else
        YumeShipViews(ships: filtered, view: settings.view),
    ];
  }
}

/// Opens a page on the root navigator.
Future<T?> pushYumePage<T>(BuildContext context, Widget page) => Navigator.of(
  context,
  rootNavigator: true,
).push<T>(MaterialPageRoute(builder: (_) => page));

class _FilterMenu extends StatelessWidget {
  const _FilterMenu({
    required this.label,
    required this.active,
    required this.options,
    required this.onSelected,
  });
  final String label;
  final bool active;
  final Map<String, String> options;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: PrismChip(
      label: '$label ▾',
      selected: active,
      onTap: () async {
        final v = await yumeChoose(
          context,
          title: label,
          options: {'': tr(context, 'Any', 'Cualquiera'), ...options},
        );
        if (v != null) onSelected(v.isEmpty ? null : v);
      },
    ),
  );
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          const ExcludeSemantics(
            child: Text('💌', style: TextStyle(fontSize: 54)),
          ),
          const SizedBox(height: 12),
          Text(
            tr(context, 'Your yumeship journal', 'Tu diario de yumeships'),
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              context,
              'Document your F/Os and ships, develop sonas, keep fanart with its credits, remember anniversaries and make things in the Creative Studio. Each yumeship belongs to the alters you choose.',
              'Documenta tus F/Os y ships, desarrolla sonas, guarda fanart con sus créditos, recuerda aniversarios y crea en el Estudio creativo. Cada yumeship pertenece a los alters que elijas.',
            ),
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          PrismButton(
            label: tr(context, 'Create a yumeship', 'Crear un yumeship'),
            icon: Icons.add,
            tone: PrismButtonTone.filled,
            onPressed: onCreate,
          ),
          const SizedBox(height: 8),
          PrismButton(
            label: tr(context, 'Create a sona instead', 'Crear una sona'),
            onPressed: () => showYumeSonaEditor(context),
          ),
        ],
      ),
    );
  }
}

class _CountdownCard extends ConsumerWidget {
  const _CountdownCard({required this.u});
  final YumeUpcoming u;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = yumeAccent(context, u.ship.accent);
    final days = u.daysFrom(DateTime.now());
    final theme = Theme.of(context);
    return YumeCard(
      accent: a,
      card: u.ship.card,
      onTap: () => yumeOpenShip(context, ref, u.ship),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(u.emoji, style: const TextStyle(fontSize: 18)),
          const Spacer(),
          Text(
            days == 0 ? tr(context, 'Today!', '¡Hoy!') : '$days',
            style: theme.textTheme.headlineSmall?.copyWith(color: a),
          ),
          Text(
            days == 0
                ? u.label
                : tr(context, 'days · ${u.label}', 'días · ${u.label}'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _AddBubble extends StatelessWidget {
  const _AddBubble({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 76,
    child: Column(
      children: [
        Material(
          shape: const CircleBorder(),
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 64,
              height: 64,
              child: Icon(
                Icons.add,
                semanticLabel: tr(context, 'New sona', 'Nueva sona'),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// A big decorative card for featured ships.
class YumeFeaturedCard extends ConsumerWidget {
  const YumeFeaturedCard({super.key, required this.ship});
  final YumeShip ship;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (yumeIsHidden(ref, ship.locked, ship.id))
      return YumeLockedTile(onUnlock: () => yumeOpenShip(context, ref, ship));
    final a = yumeAccent(context, ship.accent);
    final theme = Theme.of(context);
    final fos = ship.fos;
    return YumeFontScope(
      font: ship.font,
      child: YumeCard(
        accent: a,
        card: ship.card,
        frame: ship.frame,
        ribbon: ship.ribbon,
        stickers: ship.stickers,
        padding: EdgeInsets.zero,
        onTap: () => yumeOpenShip(context, ref, ship),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 92,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                child: ship.banner != null
                    ? YumeImage(id: ship.banner!)
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              a.withValues(alpha: 0.35),
                              a.withValues(alpha: 0.08),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Text(
                            ship.symbol,
                            style: const TextStyle(fontSize: 34),
                          ),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Row(
                children: [
                  YumePairAvatars(
                    left: ship.avatar,
                    right: fos.firstOrNull?.avatar,
                    accent: a,
                    symbol: ship.symbol,
                    size: 40,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ship.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          [
                            if (ship.shipName.isNotEmpty) ship.shipName,
                            ...ship.sources,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                        if (ship.status.isNotEmpty)
                          Text(
                            '${ship.symbol} ${ship.status}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: a,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A stored picture by media id.
class YumeImage extends StatelessWidget {
  const YumeImage({super.key, required this.id, this.fit = BoxFit.cover});
  final String id;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) => YumeMediaImage(id: id, fit: fit);
}

/// All the ways to browse ships.
class YumeShipViews extends ConsumerWidget {
  const YumeShipViews({super.key, required this.ships, required this.view});
  final List<YumeShip> ships;
  final String view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (view) {
      case 'list':
        return Column(
          children: [
            for (final s in ships)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: YumeShipRow(ship: s),
              ),
          ],
        );
      case 'cards':
        return Column(
          children: [
            for (final s in ships)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: YumeShipDetailCard(ship: s),
              ),
          ],
        );
      case 'shelves':
        final cols = ref.watch(yumeCollectionsProvider);
        final placed = <String>{};
        final shelves = <Widget>[];
        for (final c in cols) {
          final inShelf = [
            for (final s in ref.watch(yumeCollectionShipsProvider(c.id)))
              if (ships.any((x) => x.id == s.id)) s,
          ];
          if (inShelf.isEmpty) continue;
          placed.addAll(inShelf.map((s) => s.id));
          shelves.add(_Shelf(title: '${c.emoji} ${c.name}', ships: inShelf));
        }
        final rest = [
          for (final s in ships)
            if (!placed.contains(s.id)) s,
        ];
        if (rest.isNotEmpty)
          shelves.add(
            _Shelf(
              title: tr(context, 'Not on a shelf', 'Sin estante'),
              ships: rest,
            ),
          );
        return Column(children: shelves);
      default:
        final scrap = view == 'scrapbook';
        return LayoutBuilder(
          builder: (context, box) {
            final cols = (box.maxWidth / (scrap ? 190 : 170)).floor().clamp(
              2,
              6,
            );
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: scrap ? 18 : 12,
              crossAxisSpacing: scrap ? 14 : 12,
              childAspectRatio: scrap ? 0.78 : 0.82,
              children: [
                for (var i = 0; i < ships.length; i++)
                  scrap
                      ? Transform.rotate(
                          angle: MediaQuery.of(context).disableAnimations
                              ? 0
                              : ((i % 3) - 1) * 0.035,
                          child: YumeShipTile(ship: ships[i], polaroid: true),
                        )
                      : YumeShipTile(ship: ships[i]),
              ],
            );
          },
        );
    }
  }
}

class _Shelf extends StatelessWidget {
  const _Shelf({required this.title, required this.ships});
  final String title;
  final List<YumeShip> ships;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 4),
        child: Text(title, style: Theme.of(context).textTheme.titleSmall),
      ),
      YumeShelf(
        height: 196,
        children: [
          for (final s in ships)
            SizedBox(width: 150, child: YumeShipTile(ship: s)),
        ],
      ),
      Divider(color: Theme.of(context).colorScheme.outlineVariant),
    ],
  );
}

/// Gallery / scrapbook tile.
class YumeShipTile extends ConsumerWidget {
  const YumeShipTile({super.key, required this.ship, this.polaroid = false});
  final YumeShip ship;
  final bool polaroid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (yumeIsHidden(ref, ship.locked, ship.id))
      return YumeLockedTile(onUnlock: () => yumeOpenShip(context, ref, ship));
    final a = yumeAccent(context, ship.accent);
    final theme = Theme.of(context);
    final pic = ship.banner ?? ship.avatar ?? ship.fos.firstOrNull?.avatar;
    return YumeFontScope(
      font: ship.font,
      child: YumeCard(
        accent: a,
        card: polaroid ? 'paper' : ship.card,
        frame: polaroid ? 'tape' : ship.frame,
        ribbon: ship.ribbon,
        stickers: polaroid ? ship.stickers.take(1).toList() : const [],
        padding: EdgeInsets.all(polaroid ? 8 : 0),
        radius: polaroid ? 6 : 18,
        onTap: () => yumeOpenShip(context, ref, ship),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: polaroid
                    ? BorderRadius.circular(3)
                    : const BorderRadius.vertical(top: Radius.circular(18)),
                child: pic != null
                    ? YumeImage(id: pic)
                    : ColoredBox(
                        color: a.withValues(alpha: 0.14),
                        child: Center(
                          child: Text(
                            ship.symbol,
                            style: const TextStyle(fontSize: 38),
                          ),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                polaroid ? 2 : 10,
                8,
                polaroid ? 2 : 10,
                polaroid ? 4 : 10,
              ),
              child: Column(
                crossAxisAlignment: polaroid
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: polaroid
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    children: [
                      if (ship.favorite)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(Icons.star_rounded, size: 14, color: a),
                        ),
                      Flexible(
                        child: Text(
                          ship.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                  if (ship.sources.isNotEmpty)
                    Text(
                      ship.sources.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact list row.
class YumeShipRow extends ConsumerWidget {
  const YumeShipRow({super.key, required this.ship, this.trailing});
  final YumeShip ship;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (yumeIsHidden(ref, ship.locked, ship.id))
      return YumeLockedTile(onUnlock: () => yumeOpenShip(context, ref, ship));
    final a = yumeAccent(context, ship.accent);
    return YumeCard(
      accent: a,
      card: 'flat',
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      onTap: () => yumeOpenShip(context, ref, ship),
      child: Row(
        children: [
          YumeAvatar(
            media: ship.avatar ?? ship.fos.firstOrNull?.avatar,
            symbol: ship.symbol,
            size: 38,
            accent: a,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ship.name, style: Theme.of(context).textTheme.titleSmall),
                Text(
                  [
                    for (final t in ship.relTypes) yumeRelTypes[t]?.$1 ?? t,
                    ...ship.sources,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (ship.locked) const Icon(Icons.lock_outline, size: 16),
          if (ship.favorite) Icon(Icons.star_rounded, size: 18, color: a),
          ?trailing,
        ],
      ),
    );
  }
}

/// Detailed card with status, type, tropes and the next date.
class YumeShipDetailCard extends ConsumerWidget {
  const YumeShipDetailCard({super.key, required this.ship});
  final YumeShip ship;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (yumeIsHidden(ref, ship.locked, ship.id))
      return YumeLockedTile(onUnlock: () => yumeOpenShip(context, ref, ship));
    final a = yumeAccent(context, ship.accent);
    final theme = Theme.of(context);
    final names = ref.watch(yumeMemberNamesProvider);
    final next = ref
        .watch(yumeUpcomingProvider)
        .where((u) => u.ship.id == ship.id)
        .firstOrNull;
    return YumeFontScope(
      font: ship.font,
      child: YumeCard(
        accent: a,
        card: ship.card,
        frame: ship.frame,
        ribbon: ship.ribbon,
        stickers: ship.stickers,
        onTap: () => yumeOpenShip(context, ref, ship),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                YumePairAvatars(
                  left: ship.avatar,
                  right: ship.fos.firstOrNull?.avatar,
                  accent: a,
                  symbol: ship.symbol,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ship.name, style: theme.textTheme.titleMedium),
                      if (ship.shipName.isNotEmpty)
                        Text(ship.shipName, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                if (next != null)
                  YumeCountdownPill(
                    days: next.daysFrom(DateTime.now()),
                    accent: a,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in ship.relTypes)
                  _Pill(
                    '${yumeRelTypes[t]?.$3 ?? ''} ${t == 'custom' && ship.relCustom.isNotEmpty ? ship.relCustom : yumeRelTypes[t]?.$1 ?? t}',
                    a,
                  ),
                if (ship.status.isNotEmpty) _Pill(ship.status, a),
                for (final s in ship.sources) _Pill('📚 $s', a),
                for (final t in ship.tropes.take(4)) _Pill(t, a),
              ],
            ),
            if (ship.about.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(ship.about, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            if (ship.owners.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                ship.owners
                    .map((o) => names[o] ?? '')
                    .where((n) => n.isNotEmpty)
                    .join(', '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.accent);
  final String text;
  final Color accent;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(text.trim(), style: Theme.of(context).textTheme.labelSmall),
  );
}

/// Drag ships into your own order.
class YumeArrangeScreen extends ConsumerStatefulWidget {
  const YumeArrangeScreen({super.key});
  @override
  ConsumerState<YumeArrangeScreen> createState() => _YumeArrangeScreenState();
}

class _YumeArrangeScreenState extends ConsumerState<YumeArrangeScreen> {
  List<YumeShip>? _order;

  @override
  Widget build(BuildContext context) {
    final List<YumeShip> ships = _order ?? ref.watch(yumeShipsProvider);
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(context, 'Arrange yumeships', 'Ordenar yumeships'),
        showBackButton: true,
      ),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          itemCount: ships.length,
          onReorder: (from, to) async {
            final list = [...ships];
            if (to > from) to--;
            list.insert(to, list.removeAt(from));
            setState(() => _order = list);
            final actions = ref.read(yumeActionsProvider);
            await actions.reorderShips(list);
            await actions.saveSettings({'sort': 'manual'});
          },
          itemBuilder: (context, i) => Padding(
            key: ValueKey(ships[i].id),
            padding: const EdgeInsets.only(bottom: 6),
            child: YumeShipRow(
              ship: ships[i],
              trailing: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.drag_handle),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
