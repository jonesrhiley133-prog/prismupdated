import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/features/music/services/music_library.dart';
import 'package:prism_plurality/features/yumeships/yume_data.dart';
import 'package:prism_plurality/features/yumeships/yume_editing.dart';
import 'package:prism_plurality/features/yumeships/yume_widgets.dart';
import 'package:prism_plurality/shared/media/prism_media.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/utils/prism_image_picker.dart';

/// Create or edit a yumeship. [initialTab] opens a part straight away.
Future<void> showYumeShipEditor(
  BuildContext context, {
  YumeShip? editing,
  String initialTab = 'basics',
}) => PrismSheet.showFullScreen<void>(
  context: context,
  builder: (ctx, scroll) => _ShipEditor(
    editing: editing,
    scroll: scroll,
    initialTab: initialTab,
    // Keep go_router reachable after the sheet closes.
    openAfter: (id) {
      if (context.mounted) context.push(AppRoutePaths.yumeShip(id));
    },
  ),
);

class _ShipEditor extends ConsumerStatefulWidget {
  const _ShipEditor({
    this.editing,
    required this.scroll,
    required this.initialTab,
    required this.openAfter,
  });
  final YumeShip? editing;
  final ScrollController scroll;
  final String initialTab;
  final ValueChanged<String> openAfter;
  @override
  ConsumerState<_ShipEditor> createState() => _ShipEditorState();
}

class _ShipEditorState extends ConsumerState<_ShipEditor> {
  late final YumeShip? e = widget.editing;
  late String _tab = widget.initialTab;
  late final _name = TextEditingController(text: e?.r.title);
  late final _about = TextEditingController(text: e?.about);
  late List<String> _tags = [...?e?.tags];
  late Map<String, Object?> _d = e == null
      ? _newDraft()
      : Map<String, Object?>.of(e!.r.fields);
  late List<YumeFo> _fos = e?.fos ?? [YumeFo(id: yumeId())];
  late bool _annivCal = e == null
      ? ref.read(yumeSettingsProvider).calendarDefault
      : e!.r.fields['annivEvent'] != null;
  bool _saving = false;

  Map<String, Object?> _newDraft() {
    final viewer = ref.read(yumeViewerProvider);
    final s = ref.read(yumeSettingsProvider);
    return {
      'owners': [?viewer],
      'visibility': s.defaultVisibility,
      'relTypes': ['romantic'],
      'sharing': 'undecided',
      'notify': true,
    };
  }

  @override
  void dispose() {
    _name.dispose();
    _about.dispose();
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

  bool get _canSave =>
      _name.text.trim().isNotEmpty || _fos.any((f) => f.name.trim().isNotEmpty);

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final actions = ref.read(yumeActionsProvider);
    final fields = {
      ..._d,
      'fos': [
        for (final f in _fos)
          if (f.name.trim().isNotEmpty || f.avatar != null) f.toJson(),
      ],
    };
    String id;
    if (e == null) {
      final rec = await actions.createShip(
        name: _name.text,
        owner: _l('owners').firstOrNull,
        body: _about.text,
        tags: _tags,
        extra: fields,
      );
      id = rec.id;
    } else {
      await actions.saveShip(
        e!,
        fields,
        title: _name.text,
        body: _about.text,
        tags: _tags,
      );
      id = e!.id;
    }
    // The anniversary on the calendar, kept in step with the ship.
    final ship = ref.read(yumeShipByIdProvider(id));
    if (ship != null) {
      final auto = ship.r.fields['annivEvent'] as String?;
      final existing = auto == null
          ? null
          : ref
                .read(yumeShipEventsProvider(id))
                .where((x) => x.id == auto)
                .firstOrNull;
      final a = ship.anniversary;
      if (_annivCal && a != null) {
        final ev = await actions.saveEvent(
          existing: existing,
          shipId: id,
          type: 'anniversary',
          title: tr(context, 'Anniversary', 'Aniversario'),
          date: a,
          repeat: 'yearly',
          onCalendar: true,
          notify:
              existing?.notify ?? ref.read(yumeSettingsProvider).notifyDefault,
          lead: existing?.lead ?? 'day',
          countdown: existing?.countdown ?? true,
        );
        if (auto != ev.id) await actions.saveShip(ship, {'annivEvent': ev.id});
      } else if (existing != null) {
        await actions.deleteEvent(existing);
        await actions.saveShip(ship, {'annivEvent': null});
      }
      await actions.resyncShip(id);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    if (e == null) widget.openAfter(id);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = {
      'basics': tr(context, 'Basics', 'Básico'),
      'characters': tr(context, 'Characters', 'Personajes'),
      'relationship': tr(context, 'Relationship', 'Relación'),
      'story': tr(context, 'Story', 'Historia'),
      'look': tr(context, 'Look', 'Aspecto'),
      'privacy': tr(context, 'Privacy', 'Privacidad'),
    };
    return TrackerEditorScaffold(
      title: e == null
          ? tr(context, 'New yumeship', 'Nuevo yumeship')
          : tr(context, 'Edit yumeship', 'Editar yumeship'),
      canSave: _canSave && !_saving,
      onSave: _save,
      scrollController: widget.scroll,
      children: [
        YumeEditorTabs(
          tabs: tabs,
          selected: _tab,
          onSelected: (t) => setState(() => _tab = t),
        ),
        ...switch (_tab) {
          'characters' => _characters(),
          'relationship' => _relationship(),
          'story' => _story(),
          'look' => _look(),
          'privacy' => _privacy(),
          _ => _basics(),
        },
      ],
    );
  }

  List<Widget> _basics() => [
    PrismTextField(
      controller: _name,
      labelText: tr(context, 'Yumeship name', 'Nombre del yumeship'),
      hintText: tr(context, 'e.g. Me & Kaito', 'p. ej. Yo y Kaito'),
      onChanged: (_) => setState(() {}),
    ),
    const SizedBox(height: 10),
    PrismTextField(
      initialValue: '${_d['shipName'] ?? ''}',
      labelText: tr(context, 'Ship name (portmanteau)', 'Nombre del ship'),
      onChanged: (v) => _d['shipName'] = v,
    ),
    const SizedBox(height: 10),
    PrismTextField(
      controller: _about,
      labelText: tr(context, 'About this ship', 'Sobre este ship'),
      minLines: 3,
      maxLines: 10,
    ),
    const SizedBox(height: 12),
    YumeImageField(
      label: tr(context, 'Profile picture', 'Imagen de perfil'),
      value: _d['avatar'] as String?,
      spec: PrismCropSpec.avatar,
      round: true,
      onChanged: (v) => _set({'avatar': v}),
    ),
    YumeImageField(
      label: tr(context, 'Banner', 'Banner'),
      value: _d['banner'] as String?,
      spec: PrismCropSpec.banner,
      onChanged: (v) => _set({'banner': v}),
    ),
    TrackerLabel(tr(context, 'Matching icons', 'Iconos a juego')),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final id in _l('icons'))
          Stack(
            children: [
              YumeAvatar(media: id, size: 56),
              Positioned(
                right: -6,
                top: -6,
                child: IconButton(
                  tooltip: tr(context, 'Remove', 'Quitar'),
                  icon: const Icon(Icons.cancel, size: 18),
                  onPressed: () => _set({'icons': _l('icons')..remove(id)}),
                ),
              ),
            ],
          ),
        PrismChip(
          label: tr(context, 'Add icon', 'Añadir icono'),
          selected: false,
          avatar: const Icon(Icons.add, size: 18),
          onTap: () async {
            final id = await yumePickImage(ref, PrismCropSpec.avatar);
            if (id != null)
              _set({
                'icons': [..._l('icons'), id],
              });
          },
        ),
      ],
    ),
    const SizedBox(height: 12),
    PrismTextField(
      initialValue: '${_d['category'] ?? ''}',
      labelText: tr(context, 'Category', 'Categoría'),
      onChanged: (v) => _d['category'] = v,
    ),
    const SizedBox(height: 10),
    YumeStringListField(
      label: tr(context, 'Labels', 'Etiquetas'),
      values: _l('labels'),
      onChanged: (v) => _set({'labels': v}),
    ),
    const SizedBox(height: 10),
    YumeStringListField(
      label: tr(context, 'Tags', 'Tags'),
      values: _tags,
      onChanged: (v) => setState(() => _tags = v),
    ),
    const SizedBox(height: 10),
    PrismSwitchRow(
      padding: EdgeInsets.zero,
      title: tr(context, 'Favorite', 'Favorito'),
      value: _d['favorite'] == true,
      onChanged: (v) => _set({'favorite': v}),
    ),
    PrismSwitchRow(
      padding: EdgeInsets.zero,
      title: tr(context, 'Archived', 'Archivado'),
      subtitle: tr(
        context,
        'Kept, but out of the way.',
        'Guardado, pero apartado.',
      ),
      value: _d['archived'] == true,
      onChanged: (v) => _set({'archived': v}),
    ),
  ];

  List<Widget> _characters() {
    final sonas = ref.watch(yumeSonasProvider);
    final linked = _l('sonaIds');
    return [
      Text(
        tr(
          context,
          'Fictional others stay inside this yumeship — they are never alters.',
          'Los personajes viven dentro de este yumeship — nunca son alters.',
        ),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      for (var i = 0; i < _fos.length; i++)
        Padding(
          key: ValueKey(_fos[i].id),
          padding: const EdgeInsets.only(bottom: 10),
          child: _FoEditor(
            fo: _fos[i],
            onChanged: (f) => setState(() => _fos[i] = f),
            onRemove: _fos.length == 1
                ? null
                : () => setState(() => _fos.removeAt(i)),
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: YumeAction(
          label: tr(context, 'Add another F/O', 'Añadir otro F/O'),
          icon: Icons.person_add_alt,
          onPressed: () => setState(() => _fos.add(YumeFo(id: yumeId()))),
        ),
      ),
      const SizedBox(height: 8),
      TrackerLabel(
        tr(context, 'Sonas & self-inserts in this ship', 'Sonas en este ship'),
      ),
      if (sonas.isEmpty)
        Text(
          tr(
            context,
            'Create sonas from the Yumeships page.',
            'Crea sonas desde la página de Yumeships.',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        )
      else
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final s in sonas)
              PrismChip(
                label: '${s.symbol} ${s.name}',
                selected: linked.contains(s.id),
                onTap: () {
                  final next = [...linked];
                  next.contains(s.id) ? next.remove(s.id) : next.add(s.id);
                  _set({'sonaIds': next});
                },
              ),
          ],
        ),
    ];
  }

  List<Widget> _relationship() {
    final rel = _l('relTypes');
    final anniv = DateTime.tryParse('${_d['anniversary'] ?? ''}');
    final sharing = (_d['sharing'] as String?) ?? 'undecided';
    return [
      TrackerLabel(tr(context, 'Relationship type', 'Tipo de relación')),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final t in yumeRelTypes.entries)
            PrismChip(
              label: '${t.value.$3} ${tr(context, t.value.$1, t.value.$2)}',
              selected: rel.contains(t.key),
              onTap: () {
                final next = [...rel];
                next.contains(t.key) ? next.remove(t.key) : next.add(t.key);
                _set({'relTypes': next});
              },
            ),
        ],
      ),
      if (rel.contains('custom')) ...[
        const SizedBox(height: 8),
        PrismTextField(
          initialValue: '${_d['relCustom'] ?? ''}',
          labelText: tr(context, 'Your own word for it', 'Tu propia palabra'),
          onChanged: (v) => _d['relCustom'] = v,
        ),
      ],
      const SizedBox(height: 12),
      PrismTextField(
        key: ValueKey('status-${_d['status']}'),
        initialValue: '${_d['status'] ?? ''}',
        labelText: tr(context, 'Status', 'Estado'),
        onChanged: (v) => _d['status'] = v,
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final s in yumeStatuses)
            PrismChip(
              label: s,
              selected: false,
              onTap: () => _set({'status': s}),
            ),
        ],
      ),
      const SizedBox(height: 12),
      PrismListRow(
        padding: EdgeInsets.zero,
        leading: const Text('💍', style: TextStyle(fontSize: 22)),
        title: Text(tr(context, 'Anniversary', 'Aniversario')),
        subtitle: Text(
          anniv == null ? tr(context, 'Not set', 'Sin fecha') : yumeDate(anniv),
        ),
        trailing: anniv == null
            ? const Icon(Icons.chevron_right)
            : IconButton(
                tooltip: tr(context, 'Clear', 'Borrar'),
                icon: const Icon(Icons.close),
                onPressed: () => _set({'anniversary': null}),
              ),
        onTap: () async {
          final d = await showPrismDatePicker(
            context: context,
            initialDate: anniv ?? DateTime.now(),
            firstDate: DateTime(1900),
            lastDate: DateTime(2200),
          );
          if (d != null) _set({'anniversary': d.toIso8601String()});
        },
      ),
      if (anniv != null)
        PrismSwitchRow(
          padding: EdgeInsets.zero,
          title: tr(
            context,
            'Show the anniversary on my calendar',
            'Mostrar el aniversario en mi calendario',
          ),
          subtitle: tr(
            context,
            'Repeats every year. Notifications are set per event.',
            'Se repite cada año. Las notificaciones se eligen por evento.',
          ),
          value: _annivCal,
          onChanged: (v) => setState(() => _annivCal = v),
        ),
      const SizedBox(height: 8),
      YumeEntryListEditor(
        label: tr(context, 'Significant dates', 'Fechas importantes'),
        entries: _entries('dates'),
        titleLabel: tr(context, 'What happened', 'Qué pasó'),
        showText: false,
        showDate: true,
        onChanged: (v) => _setEntries('dates', v),
      ),
      const SizedBox(height: 12),
      TrackerLabel(tr(context, 'Sharing boundary', 'Límite para compartir')),
      for (final s in yumeSharing.entries)
        RadioListTile<String>(
          contentPadding: EdgeInsets.zero,
          value: s.key,
          groupValue: sharing,
          title: Text(tr(context, s.value.$1, s.value.$2)),
          subtitle: Text(s.value.$3),
          onChanged: (v) => _set({'sharing': v}),
        ),
      PrismTextField(
        initialValue: '${_d['sharingNote'] ?? ''}',
        labelText: sharing == 'custom'
            ? tr(context, 'Describe your boundary', 'Describe tu límite')
            : tr(context, 'Notes on sharing (optional)', 'Notas (opcional)'),
        minLines: 2,
        maxLines: 6,
        onChanged: (v) => _d['sharingNote'] = v,
      ),
      const SizedBox(height: 10),
      PrismTextField(
        initialValue: '${_d['boundary'] ?? ''}',
        labelText: tr(context, 'Boundary notice', 'Aviso de límites'),
        helperText: tr(
          context,
          'Shown at the top of the profile and on exports.',
          'Se muestra arriba del perfil y en las exportaciones.',
        ),
        minLines: 2,
        maxLines: 6,
        onChanged: (v) => _d['boundary'] = v,
      ),
    ];
  }

  List<Widget> _story() {
    final playlists =
        ref.watch(musicLibraryProvider).value?.playlists ?? const [];
    final chosen = _l('playlists');
    return [
      PrismTextField(
        initialValue: '${_d['dynamics'] ?? ''}',
        labelText: tr(context, 'Relationship dynamics', 'Dinámicas'),
        minLines: 3,
        maxLines: 10,
        onChanged: (v) => _d['dynamics'] = v,
      ),
      const SizedBox(height: 10),
      YumeStringListField(
        label: tr(context, 'Tropes', 'Tropos'),
        values: _l('tropes'),
        suggestions: yumeTropes,
        onChanged: (v) => _set({'tropes': v}),
      ),
      const SizedBox(height: 10),
      YumeEntryListEditor(
        label: tr(context, 'Headcanons', 'Headcanons'),
        entries: _entries('headcanons'),
        titleLabel: tr(context, 'Theme (optional)', 'Tema (opcional)'),
        textLabel: tr(context, 'Headcanon', 'Headcanon'),
        onChanged: (v) => _setEntries('headcanons', v),
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
      PrismTextField(
        initialValue: '${_d['backstory'] ?? ''}',
        labelText: tr(
          context,
          'Backstory / how you met',
          'Historia / cómo se conocieron',
        ),
        minLines: 3,
        maxLines: 12,
        onChanged: (v) => _d['backstory'] = v,
      ),
      const SizedBox(height: 10),
      YumeEntryListEditor(
        label: tr(
          context,
          'Alternate universes & variations',
          'Universos alternos',
        ),
        entries: _entries('aus'),
        titleLabel: tr(context, 'AU name', 'Nombre del AU'),
        textLabel: tr(context, 'What changes', 'Qué cambia'),
        showMedia: true,
        onChanged: (v) => _setEntries('aus', v),
      ),
      const SizedBox(height: 10),
      YumeEntryListEditor(
        label: tr(context, 'Relationship timeline', 'Cronología'),
        entries: _entries('timeline'),
        titleLabel: tr(context, 'Moment', 'Momento'),
        showDate: true,
        onChanged: (v) => _setEntries('timeline', v),
      ),
      const SizedBox(height: 10),
      YumeEntryListEditor(
        label: tr(context, 'Associated songs', 'Canciones'),
        entries: _entries('songs'),
        titleLabel: tr(context, 'Song', 'Canción'),
        textLabel: tr(context, 'Artist', 'Artista'),
        multiline: false,
        showLink: true,
        onChanged: (v) => _setEntries('songs', v),
      ),
      if (playlists.isNotEmpty) ...[
        TrackerLabel(tr(context, 'Playlists from Music', 'Listas de Música')),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final p in playlists)
              PrismChip(
                label: '🎵 ${p.name}',
                selected: chosen.contains(p.id),
                onTap: () {
                  final next = [...chosen];
                  next.contains(p.id) ? next.remove(p.id) : next.add(p.id);
                  _set({'playlists': next});
                },
              ),
          ],
        ),
      ],
      const SizedBox(height: 10),
      YumeEntryListEditor(
        label: tr(context, 'Custom fields', 'Campos propios'),
        entries: _entries('custom'),
        titleLabel: tr(context, 'Label', 'Etiqueta'),
        textLabel: tr(context, 'Value', 'Valor'),
        onChanged: (v) => _setEntries('custom', v),
      ),
    ];
  }

  List<Widget> _look() {
    final sections = YumeShip(
      (e?.r ??
              TrackerRecord(
                id: '_',
                kind: TrackerKind.yumeShip,
                createdAt: DateTime(2000),
                modifiedAt: DateTime(2000),
              ))
          .replacingFields(_d),
    ).sections;
    return [
      YumeLookEditor(
        draft: _d,
        onChanged: (d) => setState(() => _d = d),
        showLayout: true,
      ),
      const SizedBox(height: 16),
      TrackerLabel(tr(context, 'Profile sections', 'Secciones del perfil')),
      Text(
        tr(
          context,
          'Drag to reorder; switch off what you don’t use.',
          'Arrastra para ordenar; apaga lo que no uses.',
        ),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        onReorder: (from, to) {
          final ids = [for (final s in sections) s.$1];
          if (to > from) to--;
          ids.insert(to, ids.removeAt(from));
          _set({'sections': ids});
        },
        children: [
          for (var i = 0; i < sections.length; i++)
            SwitchListTile(
              key: ValueKey(sections[i].$1),
              contentPadding: EdgeInsets.zero,
              secondary: ReorderableDragStartListener(
                index: i,
                child: const Icon(Icons.drag_handle),
              ),
              title: Text(
                tr(
                  context,
                  yumeShipSections[sections[i].$1]!.$1,
                  yumeShipSections[sections[i].$1]!.$2,
                ),
              ),
              value: sections[i].$2,
              onChanged: (on) {
                final hidden = _l('hidden')..remove(sections[i].$1);
                if (!on) hidden.add(sections[i].$1);
                _set({'hidden': hidden});
              },
            ),
        ],
      ),
    ];
  }

  List<Widget> _privacy() => [
    YumePrivacyEditor(draft: _d, onChanged: (d) => setState(() => _d = d)),
    const SizedBox(height: 12),
    PrismSwitchRow(
      padding: EdgeInsets.zero,
      title: tr(
        context,
        'Notifications for this yumeship',
        'Notificaciones de este yumeship',
      ),
      subtitle: tr(
        context,
        'When off, none of its events send notifications.',
        'Si está apagado, ninguno de sus eventos envía avisos.',
      ),
      value: _d['notify'] != false,
      onChanged: (v) => _set({'notify': v}),
    ),
    const SizedBox(height: 12),
    TrackerLabel(
      tr(context, 'On exported or shared profiles', 'En perfiles exportados'),
    ),
    for (final f in yumeExportFields.entries)
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: (_d['export'] is List ? _l('export').toSet() : yumeDefaultExport)
            .contains(f.key),
        title: Text(f.value),
        onChanged: (v) {
          final set = _d['export'] is List
              ? _l('export').toSet()
              : {...yumeDefaultExport};
          v == true ? set.add(f.key) : set.remove(f.key);
          _set({'export': set.toList()});
        },
      ),
  ];
}

/// Picks and crops one image (shared cropper).
Future<String?> yumePickImage(WidgetRef ref, PrismCropSpec spec) async {
  return PrismMedia.pickImage(ref, spec: spec);
}

class _FoEditor extends StatelessWidget {
  const _FoEditor({required this.fo, required this.onChanged, this.onRemove});
  final YumeFo fo;
  final ValueChanged<YumeFo> onChanged;
  final VoidCallback? onRemove;

  YumeFo _with({
    String? name,
    List<String>? nicknames,
    String? pronouns,
    String? source,
    String? bio,
    String? avatar,
    bool clearAvatar = false,
    DateTime? birthday,
    bool clearBirthday = false,
  }) => YumeFo(
    id: fo.id,
    name: name ?? fo.name,
    nicknames: nicknames ?? fo.nicknames,
    pronouns: pronouns ?? fo.pronouns,
    source: source ?? fo.source,
    bio: bio ?? fo.bio,
    avatar: clearAvatar ? null : (avatar ?? fo.avatar),
    birthday: clearBirthday ? null : (birthday ?? fo.birthday),
  );

  @override
  Widget build(BuildContext context) {
    return PrismSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  fo.name.isEmpty
                      ? tr(context, 'Fictional other', 'Personaje')
                      : fo.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (onRemove != null)
                IconButton(
                  tooltip: tr(context, 'Remove', 'Quitar'),
                  icon: const Icon(Icons.close),
                  onPressed: onRemove,
                ),
            ],
          ),
          YumeImageField(
            label: tr(context, 'Picture', 'Imagen'),
            value: fo.avatar,
            spec: PrismCropSpec.avatar,
            round: true,
            onChanged: (v) => onChanged(
              v == null ? _with(clearAvatar: true) : _with(avatar: v),
            ),
          ),
          PrismTextField(
            initialValue: fo.name,
            labelText: tr(context, 'Name', 'Nombre'),
            onChanged: (v) => onChanged(_with(name: v)),
          ),
          const SizedBox(height: 8),
          PrismTextField(
            initialValue: fo.pronouns,
            labelText: tr(context, 'Pronouns', 'Pronombres'),
            onChanged: (v) => onChanged(_with(pronouns: v)),
          ),
          const SizedBox(height: 8),
          PrismTextField(
            initialValue: fo.source,
            labelText: tr(
              context,
              'Source (series, game, book…)',
              'Obra (serie, juego, libro…)',
            ),
            onChanged: (v) => onChanged(_with(source: v)),
          ),
          const SizedBox(height: 8),
          YumeStringListField(
            label: tr(context, 'Nicknames', 'Apodos'),
            values: fo.nicknames,
            onChanged: (v) => onChanged(_with(nicknames: v)),
          ),
          const SizedBox(height: 8),
          PrismTextField(
            initialValue: fo.bio,
            labelText: tr(context, 'Biography', 'Biografía'),
            minLines: 2,
            maxLines: 8,
            onChanged: (v) => onChanged(_with(bio: v)),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: YumeAction(
              label: fo.birthday == null
                  ? tr(context, 'Add birthday', 'Añadir cumpleaños')
                  : '${tr(context, 'Birthday', 'Cumpleaños')}: ${yumeDate(fo.birthday!, noYear: true)}',
              icon: Icons.cake_outlined,
              onPressed: () async {
                final d = await showPrismDatePicker(
                  context: context,
                  initialDate: fo.birthday ?? DateTime(2000),
                  firstDate: DateTime(1),
                  lastDate: DateTime(2200),
                );
                if (d != null) onChanged(_with(birthday: d));
              },
            ),
          ),
        ],
      ),
    );
  }
}
