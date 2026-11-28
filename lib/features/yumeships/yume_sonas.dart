import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/features/links/models/record_ref.dart';
import 'package:prism_plurality/features/links/widgets/related_records.dart';
import 'package:prism_plurality/features/yumeships/yume_data.dart';
import 'package:prism_plurality/features/yumeships/yume_editing.dart';
import 'package:prism_plurality/features/yumeships/yume_hub.dart';
import 'package:prism_plurality/features/yumeships/yume_widgets.dart';
import 'package:prism_plurality/shared/media/prism_media.dart';
import 'package:prism_plurality/shared/theme/look_theme.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/utils/prism_image_picker.dart';

/// Opens a sona, asking for the PIN first when locked.
Future<void> yumeOpenSona(
  BuildContext context,
  WidgetRef ref,
  YumeSona s,
) async {
  if (s.locked && !ref.read(yumeUnlocksProvider.notifier).isOpen(s.id)) {
    if (!await yumeUnlock(context, ref, id: s.id)) return;
  }
  if (context.mounted) context.push(AppRoutePaths.yumeSona(s.id));
}

/// A round sona bubble with its name.
class YumeSonaBubble extends ConsumerWidget {
  const YumeSonaBubble({super.key, required this.sona});
  final YumeSona sona;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = yumeAccent(context, sona.accent);
    final hidden = yumeIsHidden(ref, sona.locked, sona.id);
    return SizedBox(
      width: 76,
      child: Semantics(
        button: true,
        label: hidden
            ? tr(context, 'Locked sona', 'Sona bloqueada')
            : sona.name,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => yumeOpenSona(context, ref, sona),
          child: Column(
            children: [
              hidden
                  ? CircleAvatar(
                      radius: 32,
                      child: const Icon(Icons.lock_outline),
                    )
                  : YumeAvatar(
                      media: sona.avatar,
                      symbol: sona.symbol,
                      size: 64,
                      accent: a,
                    ),
              const SizedBox(height: 6),
              Text(
                hidden ? '•••' : sona.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// All sonas and self-inserts.
class YumeSonasScreen extends ConsumerStatefulWidget {
  const YumeSonasScreen({super.key});
  @override
  ConsumerState<YumeSonasScreen> createState() => _YumeSonasScreenState();
}

class _YumeSonasScreenState extends ConsumerState<YumeSonasScreen> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.text.trim().toLowerCase();
    final sonas = [
      for (final s in ref.watch(yumeSonasProvider))
        if (q.isEmpty ||
            '${s.name} ${s.nicknames.join(' ')} ${s.tags.join(' ')}'
                .toLowerCase()
                .contains(q))
          s,
    ];
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(context, 'Sonas & self-inserts', 'Sonas y self-inserts'),
        showBackButton: true,
        actions: [
          PrismTopBarAction(
            icon: Icons.add,
            tooltip: tr(context, 'New sona', 'Nueva sona'),
            onPressed: () => showYumeSonaEditor(context),
          ),
        ],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(
              tr(
                context,
                'Sonas, personas and self-inserts are creative characters. They are separate from alters: they never appear in fronting or fronting statistics.',
                'Las sonas y self-inserts son personajes creativos, separados de los alters: nunca aparecen en el frente ni en sus estadísticas.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            PrismTextField(
              controller: _q,
              prefixIcon: const Icon(Icons.search),
              hintText: tr(context, 'Search sonas', 'Buscar sonas'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            if (sonas.isEmpty)
              EmptyState(
                icon: Icon(Icons.face_retouching_natural),
                title: tr(context, 'No sonas yet', 'Aún no hay sonas'),
                subtitle: tr(
                  context,
                  'Create a self-insert or persona.',
                  'Crea un self-insert o persona.',
                ),
                actionLabel: tr(context, 'Create a sona', 'Crear una sona'),
                onAction: () => showYumeSonaEditor(context),
              )
            else
              for (final s in sonas)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: yumeIsHidden(ref, s.locked, s.id)
                      ? YumeLockedTile(
                          onUnlock: () => yumeOpenSona(context, ref, s),
                        )
                      : YumeCard(
                          accent: yumeAccent(context, s.accent),
                          card: s.card,
                          frame: s.frame,
                          onTap: () => yumeOpenSona(context, ref, s),
                          child: Row(
                            children: [
                              YumeAvatar(
                                media: s.avatar,
                                symbol: s.symbol,
                                size: 52,
                                accent: yumeAccent(context, s.accent),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.name,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    Text(
                                      [
                                        if (s.pronouns.isNotEmpty) s.pronouns,
                                        tr(
                                          context,
                                          '${ref.watch(yumeShipsProvider).where((x) => x.sonaIds.contains(s.id)).length} ships',
                                          '${ref.watch(yumeShipsProvider).where((x) => x.sonaIds.contains(s.id)).length} ships',
                                        ),
                                      ].join(' · '),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
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

/// A sona's profile page.
class YumeSonaScreen extends ConsumerWidget {
  const YumeSonaScreen({super.key, required this.sonaId});
  final String sonaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(yumeSonaByIdProvider(sonaId));
    final viewer = ref.watch(yumeViewerProvider);
    final theme = Theme.of(context);
    if (s == null || !s.canView(viewer)) {
      return PrismPageScaffold(
        topBar: const PrismTopBar(title: '', showBackButton: true),
        body: Center(
          child: Text(
            tr(
              context,
              'This sona isn’t available.',
              'Esta sona no está disponible.',
            ),
          ),
        ),
      );
    }
    if (yumeIsHidden(ref, s.locked, s.id)) {
      return PrismPageScaffold(
        topBar: const PrismTopBar(title: '', showBackButton: true),
        body: EmptyState(
          icon: Icon(Icons.lock_outline),
          title: tr(context, 'Locked', 'Bloqueado'),
          subtitle: tr(
            context,
            'Enter your Yumeships PIN.',
            'Introduce tu PIN de Yumeships.',
          ),
          actionLabel: tr(context, 'Unlock', 'Desbloquear'),
          onAction: () => yumeUnlock(context, ref, id: s.id),
        ),
      );
    }
    final a = yumeAccent(context, s.accent);
    final canEdit = s.canEdit(viewer);
    final ships = [
      for (final x in ref.watch(yumeShipsProvider))
        if (x.sonaIds.contains(s.id)) x,
    ];
    Widget block(String title, Widget child) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [YumeSectionTitle(title), child],
    );
    Widget text(String t) => SelectableText(
      t,
      style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
    );
    final bg = s.background;
    final look = LookTheme.of(context);
    Widget page = PrismPageScaffold(
      backgroundColor: bg == null ? null : Colors.transparent,
      topBar: PrismTopBar(
        title: s.name,
        showBackButton: true,
        actions: [
          if (canEdit)
            PrismTopBarAction(
              icon: Icons.edit_outlined,
              tooltip: tr(context, 'Edit', 'Editar'),
              onPressed: () => showYumeSonaEditor(context, editing: s),
            ),
        ],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: YumeFontScope(
          font: s.font,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            children: [
              YumeCard(
                accent: a,
                card: s.card,
                frame: s.frame,
                ribbon: s.ribbon,
                stickers: s.stickers,
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (s.banner != null || s.living != null)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(18),
                        ),
                        child: SizedBox(
                          height: 130,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (s.banner != null)
                                YumeMediaImage(id: s.banner!),
                              if (s.living != null)
                                YumeLivingBanner(
                                  lookId: s.living!,
                                  height: 130,
                                ),
                            ],
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          YumeAvatar(
                            media: s.avatar,
                            symbol: s.symbol,
                            size: 72,
                            accent: a,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.name,
                                  style: theme.textTheme.headlineSmall,
                                ),
                                if (s.pronouns.isNotEmpty)
                                  Text(
                                    s.pronouns,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                if (s.nicknames.isNotEmpty)
                                  Text(
                                    '“${s.nicknames.join('”, “')}”',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                Text(
                                  tr(
                                    context,
                                    'Sona · not an alter',
                                    'Sona · no es un alter',
                                  ),
                                  style: theme.textTheme.labelSmall?.copyWith(
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
              if (s.bio.isNotEmpty)
                block(tr(context, 'Biography', 'Biografía'), text(s.bio)),
              if (s.appearance.isNotEmpty)
                block(
                  tr(context, 'Appearance', 'Apariencia'),
                  text(s.appearance),
                ),
              if (s.personality.isNotEmpty)
                block(
                  tr(context, 'Personality', 'Personalidad'),
                  text(s.personality),
                ),
              if (s.refSheet != null)
                block(
                  tr(context, 'Reference sheet', 'Hoja de referencia'),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: YumeMediaImage(id: s.refSheet!, fit: BoxFit.contain),
                  ),
                ),
              if (s.outfits.isNotEmpty)
                block(
                  tr(context, 'Outfits', 'Atuendos'),
                  YumeShelf(
                    height: 210,
                    children: [
                      for (final o in s.outfits)
                        SizedBox(
                          width: 170,
                          child: YumeCard(
                            accent: a,
                            card: s.card,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (o.media != null)
                                  SizedBox(
                                    height: 100,
                                    width: double.infinity,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: YumeMediaImage(id: o.media!),
                                    ),
                                  ),
                                const SizedBox(height: 6),
                                Text(
                                  o.title,
                                  style: theme.textTheme.titleSmall,
                                ),
                                Expanded(
                                  child: Text(
                                    o.text,
                                    overflow: TextOverflow.fade,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              if (s.lore.isNotEmpty)
                block(tr(context, 'Lore', 'Lore'), text(s.lore)),
              if (s.aus.isNotEmpty)
                block(
                  tr(context, 'Alternate universes', 'Universos alternos'),
                  Column(
                    children: [
                      for (final au in s.aus)
                        PrismListRow(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          title: Text(au.title),
                          subtitle: au.text.isEmpty ? null : Text(au.text),
                        ),
                    ],
                  ),
                ),
              if (s.gallery.isNotEmpty)
                block(
                  tr(context, 'Artwork', 'Arte'),
                  LayoutBuilder(
                    builder: (context, box) => GridView.count(
                      crossAxisCount: (box.maxWidth / 130).floor().clamp(2, 6),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      children: [
                        for (final m in s.gallery)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: YumeMediaImage(id: m),
                          ),
                      ],
                    ),
                  ),
                ),
              if (s.customFields.isNotEmpty)
                block(
                  tr(context, 'Custom fields', 'Campos propios'),
                  Column(
                    children: [
                      for (final f in s.customFields)
                        PrismListRow(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          title: Text(
                            f.title,
                            style: theme.textTheme.labelLarge,
                          ),
                          subtitle: Text(f.text),
                        ),
                    ],
                  ),
                ),
              block(
                tr(context, 'In these yumeships', 'En estos yumeships'),
                ships.isEmpty
                    ? Text(
                        tr(
                          context,
                          'Not linked to a yumeship yet.',
                          'Aún no está en ningún yumeship.',
                        ),
                        style: theme.textTheme.bodySmall,
                      )
                    : Column(
                        children: [
                          for (final x in ships)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: YumeShipRow(ship: x),
                            ),
                        ],
                      ),
              ),
              if (canEdit)
                Align(
                  alignment: Alignment.centerLeft,
                  child: YumeAction(
                    label: tr(
                      context,
                      'Link to yumeships',
                      'Vincular a yumeships',
                    ),
                    icon: Icons.link,
                    onPressed: () => _linkShips(context, ref, s),
                  ),
                ),
              block(
                tr(context, 'Connected records', 'Registros conectados'),
                RelatedRecordsSection(
                  self: RecordRef(RecordRef.rec, s.id),
                  padding: EdgeInsets.zero,
                ),
              ),
              if (canEdit) ...[
                const SizedBox(height: 20),
                PrismButton(
                  label: tr(context, 'Delete sona', 'Eliminar sona'),
                  icon: Icons.delete_outline,
                  onPressed: () async {
                    final ok = await PrismDialog.confirm(
                      context: context,
                      title: tr(
                        context,
                        'Delete ${s.name}?',
                        '¿Eliminar ${s.name}?',
                      ),
                      message: tr(
                        context,
                        'Yumeships linked to this sona are kept.',
                        'Los yumeships vinculados se conservan.',
                      ),
                      destructive: true,
                      confirmLabel: tr(context, 'Delete', 'Eliminar'),
                    );
                    if (!ok) return;
                    await ref.read(yumeActionsProvider).deleteSona(s);
                    if (context.mounted) context.pop();
                  },
                ),
              ],
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
          ),
          page,
        ],
      );
    }
    return page;
  }

  Future<void> _linkShips(BuildContext context, WidgetRef ref, YumeSona s) =>
      PrismSheet.show<void>(
        context: context,
        title: tr(
          context,
          'Yumeships with ${s.name}',
          'Yumeships con ${s.name}',
        ),
        builder: (ctx) => Consumer(
          builder: (ctx, ref, _) {
            final ships = ref.watch(yumeShipsProvider);
            final viewer = ref.watch(yumeViewerProvider);
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.6,
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final x in ships)
                    if (x.canEdit(viewer))
                      CheckboxListTile(
                        value: x.sonaIds.contains(s.id),
                        title: Text(x.name),
                        onChanged: (v) => ref
                            .read(yumeActionsProvider)
                            .setSonaOnShip(x, s.id, v ?? false),
                      ),
                ],
              ),
            );
          },
        ),
      );
}

/// Create or edit a sona.
Future<void> showYumeSonaEditor(BuildContext context, {YumeSona? editing}) =>
    PrismSheet.showFullScreen<void>(
      context: context,
      builder: (ctx, scroll) => _SonaEditor(editing: editing, scroll: scroll),
    );

class _SonaEditor extends ConsumerStatefulWidget {
  const _SonaEditor({this.editing, required this.scroll});
  final YumeSona? editing;
  final ScrollController scroll;
  @override
  ConsumerState<_SonaEditor> createState() => _SonaEditorState();
}

class _SonaEditorState extends ConsumerState<_SonaEditor> {
  late final s = widget.editing;
  String _tab = 'about';
  late final _name = TextEditingController(text: s?.r.title);
  late final _bio = TextEditingController(text: s?.bio);
  late List<String> _tags = [...?s?.tags];
  late Map<String, Object?> _d = s == null
      ? {
          'owners': [?ref.read(yumeViewerProvider)],
          'visibility': ref.read(yumeSettingsProvider).defaultVisibility,
        }
      : Map<String, Object?>.of(s!.r.fields);

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  List<String> _l(String k) => [
    for (final x in (_d[k] as List?) ?? const []) '$x',
  ];
  List<YumeEntry> _entries(String k) => [
    for (final x in (_d[k] as List?) ?? const [])
      if (x is Map) YumeEntry.fromJson(x.cast<String, Object?>()),
  ];
  void _setEntries(String k, List<YumeEntry> v) => setState(
    () => _d = {
      ..._d,
      k: [for (final x in v) x.toJson()],
    },
  );
  void _set(Map<String, Object?> c) => setState(() => _d = {..._d, ...c});

  @override
  Widget build(BuildContext context) {
    return TrackerEditorScaffold(
      title: s == null
          ? tr(context, 'New sona', 'Nueva sona')
          : tr(context, 'Edit sona', 'Editar sona'),
      canSave: _name.text.trim().isNotEmpty,
      scrollController: widget.scroll,
      onSave: () async {
        final a = ref.read(yumeActionsProvider);
        if (s == null) {
          final rec = await a.createSona(
            name: _name.text,
            owner: _l('owners').firstOrNull,
          );
          await a.saveSona(YumeSona(rec), _d, body: _bio.text, tags: _tags);
        } else {
          await a.saveSona(
            s!,
            _d,
            title: _name.text,
            body: _bio.text,
            tags: _tags,
          );
        }
        if (context.mounted) Navigator.of(context).pop();
      },
      children: [
        YumeEditorTabs(
          tabs: {
            'about': tr(context, 'About', 'Sobre'),
            'look': tr(context, 'Appearance', 'Apariencia'),
            'story': tr(context, 'Lore', 'Lore'),
            'style': tr(context, 'Page style', 'Estilo'),
            'privacy': tr(context, 'Privacy', 'Privacidad'),
          },
          selected: _tab,
          onSelected: (t) => setState(() => _tab = t),
        ),
        ...switch (_tab) {
          'look' => [
            YumeImageField(
              label: tr(context, 'Reference sheet', 'Hoja de referencia'),
              value: _d['ref'] as String?,
              spec: PrismCropSpec.free,
              onChanged: (v) => _set({'ref': v}),
            ),
            PrismTextField(
              initialValue: '${_d['appearance'] ?? ''}',
              labelText: tr(context, 'Appearance', 'Apariencia'),
              minLines: 3,
              maxLines: 10,
              onChanged: (v) => _d['appearance'] = v,
            ),
            const SizedBox(height: 10),
            YumeEntryListEditor(
              label: tr(context, 'Outfits', 'Atuendos'),
              entries: _entries('outfits'),
              titleLabel: tr(context, 'Outfit', 'Atuendo'),
              textLabel: tr(context, 'Description', 'Descripción'),
              showMedia: true,
              onChanged: (v) => _setEntries('outfits', v),
            ),
            const SizedBox(height: 10),
            TrackerLabel(tr(context, 'Artwork gallery', 'Galería de arte')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in _l('gallery'))
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 84,
                          height: 84,
                          child: YumeMediaImage(id: id),
                        ),
                      ),
                      Positioned(
                        right: -8,
                        top: -8,
                        child: IconButton(
                          tooltip: tr(context, 'Remove', 'Quitar'),
                          icon: const Icon(Icons.cancel, size: 18),
                          onPressed: () =>
                              _set({'gallery': _l('gallery')..remove(id)}),
                        ),
                      ),
                    ],
                  ),
                PrismChip(
                  label: tr(context, 'Add artwork', 'Añadir arte'),
                  selected: false,
                  avatar: const Icon(Icons.add, size: 18),
                  onTap: () async {
                    final ids = await PrismMedia.pickImages(ref);
                    if (ids.isNotEmpty)
                      _set({
                        'gallery': [..._l('gallery'), ...ids],
                      });
                  },
                ),
              ],
            ),
          ],
          'story' => [
            PrismTextField(
              initialValue: '${_d['personality'] ?? ''}',
              labelText: tr(context, 'Personality', 'Personalidad'),
              minLines: 3,
              maxLines: 10,
              onChanged: (v) => _d['personality'] = v,
            ),
            const SizedBox(height: 10),
            PrismTextField(
              initialValue: '${_d['lore'] ?? ''}',
              labelText: tr(context, 'Lore', 'Lore'),
              minLines: 3,
              maxLines: 12,
              onChanged: (v) => _d['lore'] = v,
            ),
            const SizedBox(height: 10),
            YumeEntryListEditor(
              label: tr(context, 'Alternate universes', 'Universos alternos'),
              entries: _entries('aus'),
              titleLabel: tr(context, 'AU name', 'Nombre del AU'),
              onChanged: (v) => _setEntries('aus', v),
            ),
            const SizedBox(height: 10),
            YumeEntryListEditor(
              label: tr(context, 'Custom fields', 'Campos propios'),
              entries: _entries('custom'),
              titleLabel: tr(context, 'Label', 'Etiqueta'),
              textLabel: tr(context, 'Value', 'Valor'),
              onChanged: (v) => _setEntries('custom', v),
            ),
          ],
          'style' => [
            YumeImageField(
              label: tr(context, 'Banner', 'Banner'),
              value: _d['banner'] as String?,
              spec: PrismCropSpec.banner,
              onChanged: (v) => _set({'banner': v}),
            ),
            YumeLookEditor(draft: _d, onChanged: (d) => setState(() => _d = d)),
          ],
          'privacy' => [
            YumePrivacyEditor(
              draft: _d,
              onChanged: (d) => setState(() => _d = d),
            ),
          ],
          _ => [
            YumeImageField(
              label: tr(context, 'Picture', 'Imagen'),
              value: _d['avatar'] as String?,
              spec: PrismCropSpec.avatar,
              round: true,
              onChanged: (v) => _set({'avatar': v}),
            ),
            PrismTextField(
              controller: _name,
              labelText: tr(context, 'Name', 'Nombre'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            PrismTextField(
              initialValue: '${_d['pronouns'] ?? ''}',
              labelText: tr(context, 'Pronouns', 'Pronombres'),
              onChanged: (v) => _d['pronouns'] = v,
            ),
            const SizedBox(height: 10),
            YumeStringListField(
              label: tr(context, 'Nicknames', 'Apodos'),
              values: _l('nicknames'),
              onChanged: (v) => _set({'nicknames': v}),
            ),
            const SizedBox(height: 10),
            PrismTextField(
              controller: _bio,
              labelText: tr(context, 'Biography', 'Biografía'),
              minLines: 3,
              maxLines: 12,
            ),
            const SizedBox(height: 10),
            YumeStringListField(
              label: tr(context, 'Tags', 'Tags'),
              values: _tags,
              onChanged: (v) => setState(() => _tags = v),
            ),
            PrismSwitchRow(
              padding: EdgeInsets.zero,
              title: tr(context, 'Favorite', 'Favorita'),
              value: _d['favorite'] == true,
              onChanged: (v) => _set({'favorite': v}),
            ),
          ],
        },
      ],
    );
  }
}

/// Keeps go_router imports used when pushing from hub helpers.
Future<void> yumePushSonas(BuildContext context) =>
    context.push(AppRoutePaths.yumeSonas);
