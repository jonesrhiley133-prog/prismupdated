import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/features/links/models/record_ref.dart';
import 'package:prism_plurality/features/links/providers/link_providers.dart';
import 'package:prism_plurality/features/links/widgets/related_records.dart';
import 'package:prism_plurality/features/music/services/music_library.dart';
import 'package:prism_plurality/features/scrapbook/scrapbook_screens.dart'
    show scrapBookPath, scrapBooksProvider;
import 'package:prism_plurality/features/yumeships/yume_collections.dart';
import 'package:prism_plurality/features/yumeships/yume_data.dart';
import 'package:prism_plurality/features/yumeships/yume_events.dart';
import 'package:prism_plurality/features/yumeships/yume_gallery.dart';
import 'package:prism_plurality/features/yumeships/yume_ship_editor.dart';
import 'package:prism_plurality/features/yumeships/yume_sonas.dart';
import 'package:prism_plurality/features/yumeships/yume_studio.dart';
import 'package:prism_plurality/features/yumeships/yume_widgets.dart';
import 'package:prism_plurality/shared/theme/look_theme.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/utils/safe_link.dart';

/// A yumeship's own page: a detailed, decorated profile.
class YumeShipScreen extends ConsumerStatefulWidget {
  const YumeShipScreen({super.key, required this.shipId});
  final String shipId;
  @override
  ConsumerState<YumeShipScreen> createState() => _YumeShipScreenState();
}

class _YumeShipScreenState extends ConsumerState<YumeShipScreen> {
  bool _marked = false;

  @override
  Widget build(BuildContext context) {
    final ship = ref.watch(yumeShipByIdProvider(widget.shipId));
    final viewer = ref.watch(yumeViewerProvider);
    if (ship == null) {
      return PrismPageScaffold(
        topBar: const PrismTopBar(title: 'Yumeship', showBackButton: true),
        body: Center(
          child: Text(
            tr(
              context,
              'This yumeship was deleted.',
              'Este yumeship se eliminó.',
            ),
          ),
        ),
      );
    }
    if (!ship.canView(viewer)) {
      return PrismPageScaffold(
        topBar: const PrismTopBar(title: 'Yumeship', showBackButton: true),
        body: EmptyState(
          icon: Icon(Icons.visibility_off_outlined),
          title: tr(context, 'Private yumeship', 'Yumeship privado'),
          subtitle: tr(
            context,
            'Only its owners and the alters they chose can open it.',
            'Solo sus dueños y los alters que eligieron pueden abrirlo.',
          ),
        ),
      );
    }
    if (yumeIsHidden(ref, ship.locked, ship.id)) {
      return PrismPageScaffold(
        topBar: const PrismTopBar(title: 'Yumeship', showBackButton: true),
        body: EmptyState(
          icon: Icon(Icons.lock_outline),
          title: tr(context, 'Locked', 'Bloqueado'),
          subtitle: tr(
            context,
            'Enter your Yumeships PIN to open it.',
            'Introduce tu PIN de Yumeships para abrirlo.',
          ),
          actionLabel: tr(context, 'Unlock', 'Desbloquear'),
          onAction: () => yumeUnlock(context, ref, id: ship.id),
        ),
      );
    }
    if (!_marked) {
      _marked = true;
      Future.microtask(() => ref.read(yumeActionsProvider).markOpened(ship));
    }
    final canEdit = ship.canEdit(viewer);
    final a = yumeAccent(context, ship.accent);
    final bg = ship.background;
    final look = LookTheme.of(context);

    Widget page = PrismPageScaffold(
      backgroundColor: bg == null ? null : Colors.transparent,
      topBar: PrismTopBar(
        title: ship.name,
        showBackButton: true,
        actions: [
          if (canEdit)
            PrismTopBarAction(
              icon: Icons.edit_outlined,
              tooltip: tr(context, 'Edit', 'Editar'),
              onPressed: () => showYumeShipEditor(context, editing: ship),
            ),
          PrismTopBarAction(
            icon: Icons.more_horiz,
            tooltip: tr(context, 'More', 'Más'),
            onPressed: () => _more(ship, canEdit),
          ),
        ],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: YumeFontScope(
          font: ship.font,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              4,
              16,
              40 + NavBarInset.of(context),
            ),
            children: [
              _Header(ship: ship, accent: a),
              if (ship.boundaryNotice.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: YumeCard(
                    accent: a,
                    card: 'outlined',
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: a),
                        const SizedBox(width: 10),
                        Expanded(child: Text(ship.boundaryNotice)),
                      ],
                    ),
                  ),
                ),
              ..._sections(ship, canEdit, a),
            ],
          ),
        ),
      ),
    );
    if (bg != null) {
      page = Stack(
        fit: StackFit.expand,
        children: [
          LookBackground(
            spec: bg,
            dir: look?.backgroundDir,
            reduceEffects: look?.reduceEffects ?? false,
            reduceTransparency: look?.reduceTransparency ?? false,
          ),
          page,
        ],
      );
    }
    return page;
  }

  List<Widget> _sections(YumeShip ship, bool canEdit, Color a) {
    final out = <Widget>[];
    final magazine =
        ship.layout == 'magazine' && MediaQuery.of(context).size.width > 760;
    final blocks = <Widget>[];
    for (final (id, visible) in ship.sections) {
      if (!visible) continue;
      final body = _section(id, ship, canEdit, a);
      if (body == null) continue;
      final (en, es) = yumeShipSections[id]!;
      final block = ship.layout == 'journal'
          ? Padding(
              padding: const EdgeInsets.only(top: 14),
              child: YumeCard(
                accent: a,
                card: 'paper',
                frame: ship.frame,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      tr(context, en, es),
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: a),
                    ),
                    const SizedBox(height: 8),
                    body,
                  ],
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [YumeSectionTitle(tr(context, en, es)), body],
            );
      blocks.add(block);
    }
    if (magazine) {
      out.add(
        LayoutBuilder(
          builder: (context, box) => Wrap(
            spacing: 16,
            children: [
              for (final b in blocks)
                SizedBox(width: (box.maxWidth - 16) / 2, child: b),
            ],
          ),
        ),
      );
    } else {
      out.addAll(blocks);
    }
    return out;
  }

  Widget? _section(String id, YumeShip s, bool canEdit, Color a) {
    final theme = Theme.of(context);
    Widget text(String t) => SelectableText(
      t,
      style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
    );
    Widget addLink(String label, VoidCallback onTap) => canEdit
        ? Align(
            alignment: Alignment.centerLeft,
            child: YumeAction(label: label, icon: Icons.add, onPressed: onTap),
          )
        : const SizedBox.shrink();
    switch (id) {
      case 'about':
        return s.about.isEmpty ? null : text(s.about);
      case 'fos':
        if (s.fos.isEmpty) return null;
        return Column(
          children: [
            for (final f in s.fos)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: YumeCard(
                  accent: a,
                  card: s.card,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      YumeAvatar(
                        media: f.avatar,
                        size: 60,
                        accent: a,
                        symbol: '✦',
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              f.name.isEmpty ? '—' : f.name,
                              style: theme.textTheme.titleMedium,
                            ),
                            Text(
                              [
                                if (f.pronouns.isNotEmpty) f.pronouns,
                                if (f.source.isNotEmpty) f.source,
                                if (f.birthday != null)
                                  '🎂 ${yumeDate(f.birthday!, noYear: true)}',
                              ].join(' · '),
                              style: theme.textTheme.bodySmall,
                            ),
                            if (f.nicknames.isNotEmpty)
                              Text(
                                '“${f.nicknames.join('”, “')}”',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            if (f.bio.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(f.bio),
                            ],
                            if (canEdit &&
                                f.birthday != null &&
                                !ref
                                    .watch(yumeShipEventsProvider(s.id))
                                    .any(
                                      (e) =>
                                          e.type == 'birthday' &&
                                          e.r.title.contains(f.name),
                                    ))
                              YumeAction(
                                label: tr(
                                  context,
                                  'Add birthday to dates',
                                  'Añadir cumpleaños',
                                ),
                                onPressed: () => showYumeEventEditor(
                                  context,
                                  shipId: s.id,
                                  type: 'birthday',
                                  title: tr(
                                    context,
                                    '${f.name}’s birthday',
                                    'Cumpleaños de ${f.name}',
                                  ),
                                  date: f.birthday,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      case 'sonas':
        final sonas = [
          for (final sid in s.sonaIds) ?ref.watch(yumeSonaByIdProvider(sid)),
        ];
        if (sonas.isEmpty) {
          return canEdit
              ? addLink(
                  tr(context, 'Link a sona', 'Vincular una sona'),
                  () => showYumeShipEditor(
                    context,
                    editing: s,
                    initialTab: 'characters',
                  ),
                )
              : null;
        }
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final so in sonas) YumeSonaBubble(sona: so)],
        );
      case 'relationship':
        final years = s.anniversary == null
            ? null
            : DateTime.now().difference(s.anniversary!).inDays ~/ 365;
        if (s.relTypes.isEmpty && s.status.isEmpty && s.anniversary == null)
          return null;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in s.relTypes)
              _Tag(
                '${yumeRelTypes[t]?.$3 ?? ''} ${t == 'custom' && s.relCustom.isNotEmpty ? s.relCustom : tr(context, yumeRelTypes[t]?.$1 ?? t, yumeRelTypes[t]?.$2 ?? t)}',
                a,
              ),
            if (s.status.isNotEmpty) _Tag('${s.symbol} ${s.status}', a),
            if (s.anniversary != null)
              _Tag(
                '💍 ${yumeDate(s.anniversary!)}${years != null && years > 0 ? ' · ${tr(context, '$years years', '$years años')}' : ''}',
                a,
              ),
          ],
        );
      case 'dates':
        if (s.dates.isEmpty) return null;
        return Column(
          children: [
            for (final d in s.dates)
              PrismListRow(
                padding: const EdgeInsets.symmetric(vertical: 4),
                leading: Icon(Icons.event_outlined, color: a),
                title: Text(d.title.isEmpty ? '—' : d.title),
                subtitle: d.date == null ? null : Text(yumeDate(d.date!)),
              ),
          ],
        );
      case 'boundaries':
        final (en, es, desc) = yumeSharing[s.sharing]!;
        return YumeCard(
          accent: a,
          card: 'flat',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr(context, en, es), style: theme.textTheme.titleSmall),
              Text(s.sharingNote.isEmpty ? desc : s.sharingNote),
            ],
          ),
        );
      case 'dynamics':
        if (s.dynamics.isEmpty && s.tropes.isEmpty) return null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (s.dynamics.isNotEmpty) text(s.dynamics),
            if (s.tropes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final t in s.tropes) _Tag(t, a)],
              ),
            ],
          ],
        );
      case 'headcanons':
        if (s.headcanons.isEmpty) return null;
        return Column(
          children: [
            for (final h in s.headcanons)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: YumeCard(
                  accent: a,
                  card: 'flat',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (h.title.isNotEmpty)
                        Text(
                          h.title,
                          style: theme.textTheme.labelLarge?.copyWith(color: a),
                        ),
                      Text('💭 ${h.text}'),
                    ],
                  ),
                ),
              ),
          ],
        );
      case 'lore':
        if (s.lore.isEmpty && s.backstory.isEmpty) return null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (s.backstory.isNotEmpty) ...[
              Text(
                tr(context, 'Backstory', 'Historia'),
                style: theme.textTheme.labelLarge,
              ),
              text(s.backstory),
              const SizedBox(height: 10),
            ],
            if (s.lore.isNotEmpty) ...[
              Text(
                tr(context, 'Lore', 'Lore'),
                style: theme.textTheme.labelLarge,
              ),
              text(s.lore),
            ],
          ],
        );
      case 'aus':
        if (s.aus.isEmpty) return null;
        return YumeShelf(
          height: 200,
          children: [
            for (final au in s.aus)
              SizedBox(
                width: 220,
                child: YumeCard(
                  accent: a,
                  card: s.card,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (au.media != null)
                        SizedBox(
                          height: 80,
                          width: double.infinity,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: YumeMediaImage(id: au.media!),
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        au.title.isEmpty ? 'AU' : au.title,
                        style: theme.textTheme.titleSmall,
                      ),
                      Expanded(
                        child: Text(
                          au.text,
                          overflow: TextOverflow.fade,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      case 'timeline':
        final items = [...s.timeline]
          ..sort(
            (x, y) =>
                (x.date ?? DateTime(9999)).compareTo(y.date ?? DateTime(9999)),
          );
        if (items.isEmpty) return null;
        return Column(
          children: [
            for (var i = 0; i < items.length; i++)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 24,
                      child: Column(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              color: a,
                              shape: BoxShape.circle,
                            ),
                          ),
                          if (i < items.length - 1)
                            Expanded(
                              child: Container(
                                width: 2,
                                color: a.withValues(alpha: 0.35),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (items[i].date != null)
                              Text(
                                yumeDate(items[i].date!),
                                style: theme.textTheme.labelSmall,
                              ),
                            Text(
                              items[i].title,
                              style: theme.textTheme.titleSmall,
                            ),
                            if (items[i].text.isNotEmpty) Text(items[i].text),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      case 'gallery':
        final media = ref.watch(yumeShipMediaProvider(s.id));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (media.isNotEmpty)
              LayoutBuilder(
                builder: (context, box) => GridView.count(
                  crossAxisCount: (box.maxWidth / 130).floor().clamp(2, 6),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    for (final m in media)
                      _GalleryTile(
                        m: m,
                        accent: a,
                        onTap: () =>
                            showYumeMediaView(context, m, canEdit: canEdit),
                      ),
                  ],
                ),
              ),
            addLink(
              tr(
                context,
                'Add fanart, photos, letters…',
                'Añadir fanart, fotos, cartas…',
              ),
              () => showYumeMediaEditor(context, shipId: s.id),
            ),
          ],
        );
      case 'scrapbooks':
        final books = [
          for (final b in ref.watch(scrapBooksProvider))
            if (b.str('forRef') == RecordRef(RecordRef.rec, s.id).key) b,
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (books.isNotEmpty)
              YumeShelf(
                height: 130,
                children: [
                  for (final b in books)
                    SizedBox(
                      width: 110,
                      child: YumeCard(
                        accent: b.integer('color') == null
                            ? a
                            : Color(b.integer('color')!),
                        card: 'paper',
                        onTap: () => context.push(scrapBookPath(b.id)),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              b.str('emoji') ?? '📖',
                              style: const TextStyle(fontSize: 30),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              b.title,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            addLink(
              tr(
                context,
                'New scrapbook for this ship',
                'Nuevo álbum para este ship',
              ),
              () => _newScrapbook(s),
            ),
          ],
        );
      case 'songs':
        final playlists =
            ref.watch(musicLibraryProvider).value?.playlists ?? const [];
        final linked = [
          for (final p in playlists)
            if (s.playlists.contains(p.id)) p,
        ];
        if (s.songs.isEmpty && linked.isEmpty) return null;
        return Column(
          children: [
            for (final song in s.songs)
              PrismListRow(
                padding: const EdgeInsets.symmetric(vertical: 4),
                leading: Icon(Icons.music_note_outlined, color: a),
                title: Text(song.title.isEmpty ? '—' : song.title),
                subtitle: song.text.isEmpty ? null : Text(song.text),
                trailing: song.link.isEmpty
                    ? null
                    : const Icon(Icons.open_in_new, size: 18),
                onTap: song.link.isEmpty
                    ? null
                    : () => launchSafeExternalUri(song.link),
              ),
            for (final p in linked)
              PrismListRow(
                padding: const EdgeInsets.symmetric(vertical: 4),
                leading: Icon(Icons.queue_music, color: a),
                title: Text(p.name),
                subtitle: Text(
                  tr(
                    context,
                    '${p.trackIds.length} songs in Music',
                    '${p.trackIds.length} canciones en Música',
                  ),
                ),
                onTap: () => context.go(AppRoutePaths.music),
              ),
          ],
        );
      case 'events':
        final events = ref.watch(yumeShipEventsProvider(s.id));
        final now = DateTime.now();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final e in events)
              PrismListRow(
                padding: const EdgeInsets.symmetric(vertical: 4),
                leading: Text(
                  yumeEventTypes[e.type]?.$3 ?? '✨',
                  style: const TextStyle(fontSize: 22),
                ),
                title: Text(e.title),
                subtitle: Text(
                  [
                    yumeDate(e.date, noYear: e.recurrence == 'yearly'),
                    if (e.recurrence != 'none') yumeRecurrences[e.recurrence]!,
                    if (e.onCalendar)
                      tr(context, 'on calendar', 'en el calendario'),
                    if (e.notify) '🔔',
                  ].join(' · '),
                ),
                trailing: e.nextOn(now) == null
                    ? null
                    : YumeCountdownPill(
                        days: e
                            .nextOn(now)!
                            .difference(DateTime(now.year, now.month, now.day))
                            .inDays,
                        accent: a,
                      ),
                onTap: canEdit
                    ? () => showYumeEventEditor(
                        context,
                        shipId: s.id,
                        existing: e,
                      )
                    : null,
              ),
            addLink(
              tr(
                context,
                'Add an anniversary or celebration',
                'Añadir aniversario o celebración',
              ),
              () => showYumeEventEditor(context, shipId: s.id),
            ),
          ],
        );
      case 'creations':
        final list = [
          for (final c in ref.watch(yumeCreationsProvider))
            if (c.shipIds.contains(s.id)) c,
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (list.isNotEmpty)
              YumeShelf(
                height: 120,
                children: [
                  for (final c in list)
                    SizedBox(width: 160, child: YumeCreationTile(c: c)),
                ],
              ),
            addLink(
              tr(
                context,
                'Make something in the Studio',
                'Crear algo en el Estudio',
              ),
              () => context.push(AppRoutePaths.yumeStudio(shipId: s.id)),
            ),
          ],
        );
      case 'custom':
        if (s.customFields.isEmpty) return null;
        return Column(
          children: [
            for (final f in s.customFields)
              PrismListRow(
                padding: const EdgeInsets.symmetric(vertical: 4),
                title: Text(
                  f.title.isEmpty ? '—' : f.title,
                  style: theme.textTheme.labelLarge,
                ),
                subtitle: Text(f.text),
              ),
          ],
        );
      case 'links':
        return RelatedRecordsSection(
          self: RecordRef(RecordRef.rec, s.id),
          padding: EdgeInsets.zero,
        );
    }
    return null;
  }

  Future<void> _newScrapbook(YumeShip s) async {
    final t = ref.read(trackerNotifierProvider.notifier);
    final book = await t.create(
      kind: TrackerKind.scrapBook,
      title: s.name,
      memberId: s.owners.firstOrNull,
      isPrivate: s.visibility != 'system',
      fields: {
        'theme': 'classic',
        'font': 'serif',
        'pattern': 'paper',
        'color': s.accent,
        'emoji': s.symbol,
        'contributors': [...s.owners, ...s.collaborators],
        'for': 'yumeship',
        'forRef': RecordRef(RecordRef.rec, s.id).key,
      },
    );
    await ref
        .read(linkActionsProvider)
        .link(
          RecordRef(RecordRef.rec, book.id),
          RecordRef(RecordRef.rec, s.id),
          category: 'partOf',
        );
    if (mounted) context.push(scrapBookPath(book.id));
  }

  Future<void> _more(YumeShip s, bool canEdit) async {
    final actions = ref.read(yumeActionsProvider);
    final names = ref.read(yumeMemberNamesProvider);
    final choice = await yumeChoose(
      context,
      title: s.name,
      options: {
        if (canEdit)
          'favorite': s.favorite
              ? tr(context, 'Remove from favorites', 'Quitar de favoritos')
              : tr(context, 'Add to favorites', 'Añadir a favoritos'),
        if (canEdit)
          'pin': s.pinned
              ? tr(context, 'Unpin (primary)', 'Desfijar (principal)')
              : tr(
                  context,
                  'Pin as a primary ship',
                  'Fijar como ship principal',
                ),
        'collections': tr(
          context,
          'Add to collections…',
          'Añadir a colecciones…',
        ),
        if (canEdit)
          'archive': s.archived
              ? tr(context, 'Unarchive', 'Desarchivar')
              : tr(context, 'Archive', 'Archivar'),
        'export': tr(
          context,
          'Export or share profile…',
          'Exportar o compartir…',
        ),
        if (canEdit) 'duplicate': tr(context, 'Duplicate…', 'Duplicar…'),
        if (canEdit && names.isNotEmpty)
          'transfer': tr(
            context,
            'Transfer to another alter…',
            'Transferir a otro alter…',
          ),
        if (canEdit)
          'delete': tr(context, 'Delete yumeship', 'Eliminar yumeship'),
      },
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'favorite':
        await actions.saveShip(s, {'favorite': !s.favorite});
      case 'pin':
        await actions.saveShip(s, const {}, pinned: !s.pinned);
      case 'archive':
        await actions.saveShip(s, {'archived': !s.archived});
      case 'collections':
        await showYumeAddToCollections(context, s);
      case 'export':
        await context.push(AppRoutePaths.yumeExport(s.id));
      case 'duplicate':
        final to = await yumeChoose(
          context,
          title: tr(context, 'Duplicate for…', 'Duplicar para…'),
          options: {
            '': tr(
              context,
              'The same owners (a copy)',
              'Los mismos dueños (copia)',
            ),
            ...names,
          },
        );
        if (to == null) return;
        final copy = await actions.duplicateShip(
          s,
          toOwner: to.isEmpty ? null : to,
        );
        if (mounted) {
          PrismToast.success(
            context,
            message: tr(context, 'Duplicated', 'Duplicado'),
          );
          context.push(AppRoutePaths.yumeShip(copy.id));
        }
      case 'transfer':
        final to = await yumeChoose(
          context,
          title: tr(context, 'Transfer to…', 'Transferir a…'),
          options: {
            for (final e in names.entries)
              if (!s.owners.contains(e.key)) e.key: e.value,
          },
        );
        if (to == null) return;
        await actions.transferShip(s, to);
        if (mounted)
          PrismToast.success(
            context,
            message: tr(
              context,
              'Transferred to ${names[to]}',
              'Transferido a ${names[to]}',
            ),
          );
      case 'delete':
        final ok = await PrismDialog.confirm(
          context: context,
          title: tr(context, 'Delete ${s.name}?', '¿Eliminar ${s.name}?'),
          message: tr(
            context,
            'Its gallery, dates and calendar entries go too. Scrapbooks and creative entries are kept.',
            'Su galería, fechas y entradas de calendario también se borran. Los álbumes y creaciones se conservan.',
          ),
          destructive: true,
          confirmLabel: tr(context, 'Delete', 'Eliminar'),
        );
        if (!ok) return;
        await actions.deleteShip(s);
        if (mounted) context.pop();
    }
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.ship, required this.accent});
  final YumeShip ship;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final names = ref.watch(yumeMemberNamesProvider);
    final owners = [for (final o in ship.owners) ?names[o]];
    return YumeCard(
      accent: accent,
      card: ship.card,
      frame: ship.frame,
      ribbon: ship.ribbon,
      stickers: ship.stickers,
      padding: EdgeInsets.zero,
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: SizedBox(
              height: 150,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (ship.banner != null)
                    YumeMediaImage(id: ship.banner!)
                  else
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            accent.withValues(alpha: 0.4),
                            accent.withValues(alpha: 0.06),
                          ],
                        ),
                      ),
                    ),
                  if (ship.living != null)
                    Positioned.fill(
                      child: YumeLivingBanner(
                        lookId: ship.living!,
                        height: 150,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    YumePairAvatars(
                      left: ship.avatar,
                      right: ship.fos.firstOrNull?.avatar,
                      accent: accent,
                      symbol: ship.symbol,
                      size: 56,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ship.name, style: theme.textTheme.headlineSmall),
                          if (ship.shipName.isNotEmpty)
                            Text(
                              '${ship.symbol} ${ship.shipName}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: accent,
                              ),
                            ),
                          if (ship.sources.isNotEmpty)
                            Text(
                              ship.sources.join(' · '),
                              style: theme.textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (ship.matchingIcons.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final i in ship.matchingIcons)
                        YumeAvatar(media: i, size: 44, accent: accent),
                    ],
                  ),
                ],
                if (owners.isNotEmpty ||
                    ship.labels.isNotEmpty ||
                    ship.category.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (owners.isNotEmpty)
                        _Tag('👤 ${owners.join(', ')}', accent),
                      if (ship.category.isNotEmpty) _Tag(ship.category, accent),
                      for (final l in ship.labels) _Tag(l, accent),
                      for (final t in ship.tags) _Tag('#$t', accent),
                      if (ship.visibility != 'system')
                        _Tag(
                          '🔒 ${tr(context, yumeVisibilities[ship.visibility]!.$1, yumeVisibilities[ship.visibility]!.$2)}',
                          accent,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.accent);
  final String text;
  final Color accent;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(text.trim(), style: Theme.of(context).textTheme.labelMedium),
  );
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({
    required this.m,
    required this.accent,
    required this.onTap,
  });
  final YumeMedia m;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final first = m.media.where((x) => !x.startsWith('audio:')).firstOrNull;
    return Semantics(
      button: true,
      label: m.title.isEmpty ? yumeMediaTypes[m.type]?.$1 : m.title,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (first != null)
                IgnorePointer(child: YumeMediaImage(id: first))
              else
                ColoredBox(
                  color: accent.withValues(alpha: 0.12),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          yumeMediaTypes[m.type]?.$3 ?? '✨',
                          style: const TextStyle(fontSize: 22),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Text(
                            m.title.isNotEmpty ? m.title : m.caption,
                            overflow: TextOverflow.fade,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                left: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${yumeMediaTypes[m.type]?.$3 ?? ''}${m.artist.isNotEmpty ? ' ${m.artist}' : ''}',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
