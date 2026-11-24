import 'dart:math' as math;

import 'package:intl/intl.dart' show DateFormat;
import 'package:uuid/uuid.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/domain/models/calendar_event.dart';
import 'package:prism_plurality/features/cozy/data/cozy_data.dart';
import 'package:prism_plurality/features/cozy/views/cozy_widgets.dart';
import 'package:prism_plurality/features/games/core/games_data.dart';
import 'package:prism_plurality/features/games/engines/canvas_kit.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// How a shared list behaves.
class CozyList {
  const CozyList(
    this.key,
    this.emoji,
    this.name,
    this.desc, {
    this.hint = ('Add something…', 'Añade algo…'),
    this.checkable = false,
    this.dated = false,
    this.unlock = false,
    this.detail = false,
    this.link = false,
    this.jar = false,
    this.calendar = false,
  });
  final String key;
  final String emoji;
  final (String, String) name;
  final (String, String) desc;
  final (String, String) hint;

  /// Items can be ticked off (bucket list, challenges, goals).
  final bool checkable;

  /// Items have a date (celebrations).
  final bool dated;

  /// Items stay sealed until a date (time capsules).
  final bool unlock;

  /// Items have a longer body (recipes, memories).
  final bool detail;

  /// Items have a link or artist (music, books).
  final bool link;

  /// Shown as a jar you draw from at random.
  final bool jar;

  /// Dated items can be added to the Calendar.
  final bool calendar;
}

const cozyLists = <CozyList>[
  CozyList('gratitude', '🫙', ('Gratitude jar', 'Tarro de gratitud'), ('Little things you\'re thankful for.', 'Pequeñas cosas que agradeces.'), jar: true),
  CozyList(
    'appreciation',
    '💝',
    ('Appreciation jar', 'Tarro de aprecio'),
    ('Compliments and thank-yous for each other.', 'Cumplidos y agradecimientos entre vosotros.'),
    hint: ('I appreciate… because…', 'Aprecio… porque…'),
    jar: true,
  ),
  CozyList('memories', '📸', ('Memory box', 'Caja de recuerdos'), ('Moments worth keeping.', 'Momentos que vale la pena guardar.'), detail: true),
  CozyList(
    'capsule',
    '⏳',
    ('Time capsules', 'Cápsulas del tiempo'),
    ('Sealed messages that open on a future date.', 'Mensajes sellados que se abren en una fecha futura.'),
    detail: true,
    unlock: true,
  ),
  CozyList(
    'reading',
    '📚',
    ('Reading shelf', 'Estantería de lectura'),
    ('Books read, reading and to read — with notes.', 'Libros leídos, en curso y pendientes, con notas.'),
    hint: ('Book title', 'Título del libro'),
    checkable: true,
    link: true,
  ),
  CozyList('music', '🎵', ('Music exchange', 'Intercambio musical'), ('Songs to share with each other.', 'Canciones para compartir.'), hint: ('Song — artist', 'Canción — artista'), link: true),
  CozyList(
    'playlist',
    '📀',
    ('Shared playlists', 'Listas compartidas'),
    ('Build playlists together, one song at a time.', 'Haced listas juntos, canción a canción.'),
    hint: ('Song — artist', 'Canción — artista'),
    link: true,
  ),
  CozyList(
    'checkin',
    '🌤️',
    ('Check-in cards', 'Tarjetas de ánimo'),
    ('"How are you, really?" — short check-ins.', '"¿Cómo estás, de verdad?": breves registros.'),
    hint: ('Today I feel… / I need…', 'Hoy me siento… / Necesito…'),
  ),
  CozyList('bucket', '🪣', ('Bucket list', 'Lista de deseos por cumplir'), ('Things you\'d love to do someday.', 'Cosas que os encantaría hacer algún día.'), checkable: true),
  CozyList('wishlist', '🎁', ('Wishlist', 'Lista de deseos'), ('Things alters would love to have or try.', 'Cosas que a los alters les gustaría tener o probar.'), link: true),
  CozyList('questions', '❓', ('Question jar', 'Tarro de preguntas'), ('Questions for anyone to answer.', 'Preguntas para que cualquiera responda.'), jar: true),
  CozyList('challenge', '🏅', ('Challenge board', 'Tablón de retos'), ('Gentle challenges to try together — no pressure.', 'Retos suaves para probar juntos, sin presión.'), checkable: true),
  CozyList('goals', '🎯', ('Shared goals', 'Metas compartidas'), ('Goals you\'re working towards together.', 'Metas en las que trabajáis juntos.'), checkable: true, detail: true),
  CozyList(
    'celebration',
    '🎉',
    ('Celebration calendar', 'Calendario de celebraciones'),
    ('Anniversaries, milestones and little wins.', 'Aniversarios, hitos y pequeñas victorias.'),
    dated: true,
    calendar: true,
  ),
  CozyList('recipes', '🍲', ('Recipe book', 'Recetario'), ('Comfort foods and favourite recipes.', 'Comida reconfortante y recetas favoritas.'), detail: true),
  CozyList('comfort', '🧸', ('Comfort collection', 'Colección de consuelo'), ('Things that help on hard days.', 'Cosas que ayudan en días difíciles.')),
  CozyList(
    'moodboard',
    '🖼️',
    ('Moodboards', 'Tableros de inspiración'),
    ('Colours, words and emoji that capture a feeling.', 'Colores, palabras y emojis que capturan un sentimiento.'),
    hint: ('An emoji, colour or word', 'Un emoji, color o palabra'),
  ),
  CozyList(
    'favorites',
    '💫',
    ('Favourite things', 'Cosas favoritas'),
    ('Swap favourites: foods, places, smells, shows…', 'Compartid favoritos: comidas, lugares, olores, series…'),
    hint: ('My favourite … is …', 'Mi … favorito es …'),
  ),
  CozyList(
    'interests',
    '🧩',
    ('Interests', 'Intereses'),
    ('Add your interests — Prism shows what you have in common.', 'Añade tus intereses: Prism muestra lo que tenéis en común.'),
    hint: ('An interest (e.g. "baking")', 'Un interés (p. ej. "repostería")'),
  ),
  CozyList('friendship', '🤝', ('Friendship collection', 'Colección de amistad'), ('Inside jokes, shared stories and keepsakes.', 'Bromas internas, historias y recuerdos compartidos.'), detail: true),
];

CozyList cozyListFor(String key) => cozyLists.firstWhere((l) => l.key == key, orElse: () => cozyLists.first);

void openCozyList(BuildContext context, String key) => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(builder: (_) => CozyListScreen(list: cozyListFor(key))));

void openDoodleWall(BuildContext context) => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(builder: (_) => const DoodleWallScreen()));

class CollectionsView extends ConsumerWidget {
  const CollectionsView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: PrismSurface(
                onTap: () => openDoodleWall(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🖍️', style: TextStyle(fontSize: 28)),
                    Text(tr(context, 'Doodle wall', 'Muro de dibujos'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    Text(tr(context, '${ref.watch(doodlesProvider).length} doodles', '${ref.watch(doodlesProvider).length} dibujos'), style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PrismSurface(
                onTap: () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(builder: (_) => const GiftsScreen())),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🎁', style: TextStyle(fontSize: 28)),
                    Text(tr(context, 'Gifts & surprises', 'Regalos y sorpresas'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    Text(
                      tr(context, '${ref.watch(giftsProvider).where((g) => !g.opened).length} unopened', '${ref.watch(giftsProvider).where((g) => !g.opened).length} sin abrir'),
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        PrismSectionHeader(title: tr(context, 'SHARED COLLECTIONS', 'COLECCIONES COMPARTIDAS')),
        PrismSurface(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final l in cozyLists)
                Consumer(
                  builder: (context, ref, _) {
                    final n = ref.watch(cozyListProvider(l.key)).length;
                    return PrismListRow(
                      leading: Text(l.emoji, style: const TextStyle(fontSize: 22)),
                      title: Text(cozyTr(context, l.name)),
                      subtitle: Text(cozyTr(context, l.desc)),
                      trailing: Text('$n', style: theme.textTheme.labelLarge),
                      onTap: () => openCozyList(context, l.key),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

String cozyTr(BuildContext c, (String, String) p) => tr(c, p.$1, p.$2);

class CozyListScreen extends ConsumerStatefulWidget {
  const CozyListScreen({super.key, required this.list});
  final CozyList list;
  @override
  ConsumerState<CozyListScreen> createState() => _CozyListScreenState();
}

class _CozyListScreenState extends ConsumerState<CozyListScreen> {
  TrackerRecord? _drawn;

  @override
  Widget build(BuildContext context) {
    final l = widget.list;
    final items = ref.watch(cozyListProvider(l.key));
    final names = ref.watch(gameNamesProvider);
    final theme = Theme.of(context);
    final now = DateTime.now();

    // Interests: what alters have in common.
    final common = <String, Set<String>>{};
    if (l.key == 'interests') {
      for (final i in items) {
        common.putIfAbsent(i.title.trim().toLowerCase(), () => {}).add(i.memberId ?? '');
      }
      common.removeWhere((_, v) => v.length < 2);
    }
    final sorted = l.dated ? ([...items]..sort((a, b) => _nextDate(a).compareTo(_nextDate(b)))) : items;

    return PrismPageScaffold(
      topBar: PrismTopBar(title: '${l.emoji} ${cozyTr(context, l.name)}'),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + NavBarInset.of(context)),
          children: [
            Text(cozyTr(context, l.desc), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PrismButton(tone: PrismButtonTone.filled, icon: PhosphorIcons.plus(), label: tr(context, 'Add', 'Añadir'), onPressed: () => _edit(context)),
                if (l.jar && items.isNotEmpty)
                  PrismButton(
                    icon: PhosphorIcons.handGrabbing(),
                    label: tr(context, 'Draw from the jar', 'Sacar del tarro'),
                    onPressed: () => setState(() => _drawn = items[math.Random().nextInt(items.length)]),
                  ),
              ],
            ),
            if (_drawn != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: PrismSurface(
                  tone: PrismSurfaceTone.accent,
                  child: Column(
                    children: [
                      Text(
                        _drawn!.title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text('— ${names[_drawn!.memberId] ?? tr(context, 'the system', 'el sistema')}', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            if (common.isNotEmpty) ...[
              PrismSectionHeader(title: tr(context, 'IN COMMON', 'EN COMÚN')),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final e in common.entries) PrismChip(label: '${e.key} · ${e.value.map((m) => names[m] ?? '?').join(', ')}', selected: true, onTap: () {})],
              ),
            ],
            PrismSectionHeader(title: tr(context, '${items.length} ITEMS', '${items.length} ELEMENTOS')),
            if (items.isEmpty)
              EmptyState(
                icon: Text(l.emoji, style: const TextStyle(fontSize: 32)),
                title: tr(context, 'Empty for now', 'Vacío por ahora'),
                subtitle: tr(context, 'Anyone can add to this.', 'Cualquiera puede añadir.'),
              )
            else
              for (final i in sorted)
                Builder(
                  builder: (context) {
                    final unlockAt = DateTime.tryParse('${i.fields['unlock'] ?? ''}');
                    final sealed = l.unlock && unlockAt != null && unlockAt.isAfter(now);
                    final done = i.fields['done'] == true;
                    final date = DateTime.tryParse('${i.fields['date'] ?? ''}');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: PrismSurface(
                        onTap: sealed ? null : () => _edit(context, item: i),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AuthorLine(
                              memberId: i.memberId,
                              when: i.createdAt,
                              trailing: l.checkable
                                  ? PrismIconButton(
                                      icon: done ? PhosphorIcons.checkSquare(PhosphorIconsStyle.fill) : PhosphorIcons.square(),
                                      tooltip: done ? tr(context, 'Done', 'Hecho') : tr(context, 'Mark done', 'Marcar hecho'),
                                      color: done ? theme.colorScheme.primary : null,
                                      onPressed: () => ref.read(cozyActionsProvider).setFields(i, {'done': !done, 'doneAt': !done ? DateTime.now().toIso8601String() : null}),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 6),
                            if (sealed)
                              Text(
                                tr(context, '🔒 Sealed until ${DateFormat.yMMMd().format(unlockAt)}', '🔒 Sellada hasta ${DateFormat.yMMMd().format(unlockAt)}'),
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              )
                            else ...[
                              Text(
                                '${i.fields['mood'] == null ? '' : '${i.fields['mood']} '}${i.title}',
                                style: TextStyle(fontWeight: FontWeight.w600, decoration: done ? TextDecoration.lineThrough : null),
                              ),
                              if ((i.body ?? '').isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(i.body!, maxLines: 6, overflow: TextOverflow.ellipsis, style: const TextStyle(height: 1.4)),
                                ),
                              if ('${i.fields['link'] ?? ''}'.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('🔗 ${i.fields['link']}', style: theme.textTheme.bodySmall),
                                ),
                            ],
                            if (date != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('📅 ${DateFormat.yMMMd().format(date)}${i.fields['yearly'] == true ? tr(context, ' · every year', ' · cada año') : ''}', style: theme.textTheme.bodySmall),
                              ),
                            const SizedBox(height: 6),
                            ReactionBar(record: i),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ],
        ),
      ),
    );
  }

  DateTime _nextDate(TrackerRecord r) {
    final d = DateTime.tryParse('${r.fields['date'] ?? ''}') ?? DateTime(9999);
    if (r.fields['yearly'] != true) return d;
    final now = DateTime.now();
    var n = DateTime(now.year, d.month, d.day);
    if (n.isBefore(DateTime(now.year, now.month, now.day))) n = DateTime(now.year + 1, d.month, d.day);
    return n;
  }

  Future<void> _edit(BuildContext context, {TrackerRecord? item}) => PrismSheet.show<void>(
    context: context,
    title: item == null ? tr(context, 'Add', 'Añadir') : tr(context, 'Edit', 'Editar'),
    builder: (_) => _ItemEditor(list: widget.list, item: item),
  );
}

class _ItemEditor extends ConsumerStatefulWidget {
  const _ItemEditor({required this.list, this.item});
  final CozyList list;
  final TrackerRecord? item;
  @override
  ConsumerState<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends ConsumerState<_ItemEditor> {
  late final _title = TextEditingController(text: widget.item?.title ?? '');
  late final _body = TextEditingController(text: widget.item?.body ?? '');
  late final _link = TextEditingController(text: '${widget.item?.fields['link'] ?? ''}');
  late String? _author = widget.item?.memberId ?? ref.read(cozyMeProvider);
  late DateTime? _date = DateTime.tryParse('${widget.item?.fields['date'] ?? widget.item?.fields['unlock'] ?? ''}');
  late bool _yearly = widget.item?.fields['yearly'] == true;
  late String? _mood = widget.item?.fields['mood'] as String?;
  bool _toCalendar = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _link.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.list;
    final names = ref.watch(gameNamesProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrismTextField(controller: _title, autofocus: widget.item == null, hintText: cozyTr(context, l.hint), maxLines: 2),
          if (l.detail) ...[const SizedBox(height: 8), PrismTextField(controller: _body, maxLines: 8, minLines: 3, hintText: tr(context, 'Details', 'Detalles'))],
          if (l.link) ...[const SizedBox(height: 8), PrismTextField(controller: _link, hintText: tr(context, 'Link or note (optional)', 'Enlace o nota (opcional)'))],
          if (l.dated || l.unlock)
            PrismListRow(
              dense: true,
              leading: Icon(l.unlock ? PhosphorIcons.lockKey() : PhosphorIcons.calendar()),
              title: Text(
                _date == null ? (l.unlock ? tr(context, 'Choose an opening date', 'Elige la fecha de apertura') : tr(context, 'Choose a date', 'Elige una fecha')) : DateFormat.yMMMd().format(_date!),
              ),
              onTap: () async {
                final now = DateTime.now();
                final d = await showPrismDatePicker(
                  context: context,
                  initialDate: _date ?? (l.unlock ? now.add(const Duration(days: 365)) : now),
                  firstDate: l.unlock ? now : DateTime(1900),
                  lastDate: DateTime(now.year + 50),
                );
                if (d != null) setState(() => _date = d);
              },
            ),
          if (l.dated) PrismSwitchRow(title: tr(context, 'Every year', 'Cada año'), value: _yearly, onChanged: (v) => setState(() => _yearly = v)),
          if (l.calendar && widget.item == null) PrismSwitchRow(title: tr(context, 'Add to Calendar', 'Añadir al calendario'), value: _toCalendar, onChanged: (v) => setState(() => _toCalendar = v)),
          Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(tr(context, 'Mood (optional)', 'Ánimo (opcional)'), style: Theme.of(context).textTheme.labelMedium),
              for (final m in cozyMoods) PrismChip(label: m, selected: _mood == m, onTap: () => setState(() => _mood = _mood == m ? null : m)),
            ],
          ),
          PrismListRow(
            dense: true,
            leading: AlterDot(_author, size: 24),
            title: Text(tr(context, 'From ${_author == null ? 'the system' : names[_author] ?? '?'}', 'De ${_author == null ? 'el sistema' : names[_author] ?? '?'}')),
            onTap: () async {
              final p = await pickAlters(context, ref, max: 1, selected: [?_author]);
              if (p != null) setState(() => _author = p.firstOrNull);
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (widget.item != null) ...[
                Expanded(
                  child: PrismButton(
                    label: tr(context, 'Delete', 'Eliminar'),
                    onPressed: () {
                      ref.read(cozyActionsProvider).delete(widget.item!);
                      Navigator.of(context).pop();
                    },
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: PrismButton(
                  tone: PrismButtonTone.filled,
                  label: tr(context, 'Save', 'Guardar'),
                  onPressed: () async {
                    final title = _title.text.trim();
                    if (title.isEmpty) return;
                    final fields = {
                      'list': l.key,
                      if (l.link) 'link': _link.text.trim(),
                      if (l.dated) 'date': _date?.toIso8601String(),
                      if (l.dated) 'yearly': _yearly,
                      if (l.unlock) 'unlock': _date?.toIso8601String(),
                      'mood': _mood,
                    };
                    final t = ref.read(trackerNotifierProvider.notifier);
                    if (widget.item == null) {
                      await t.create(kind: TrackerKind.cozyListItem, title: title, body: _body.text.trim(), memberId: _author, occurredAt: DateTime.now(), fields: fields);
                      if (_toCalendar && _date != null) {
                        final now = DateTime.now();
                        await ref
                            .read(calendarRepositoryProvider)
                            .create(
                              CalendarEvent(
                                id: const Uuid().v4(),
                                title: '🎉 $title',
                                startAt: _date!,
                                endAt: _date!,
                                isAllDay: true,
                                category: 'celebration',
                                recurrence: _yearly ? CalendarRecurrence.yearly : CalendarRecurrence.none,
                                memberIds: [?_author],
                                createdAt: now,
                                modifiedAt: now,
                              ),
                            );
                      }
                    } else {
                      await t.save(widget.item!.copyWith(title: title, body: _body.text.trim(), memberId: _author).withFields({...widget.item!.fields, ...fields}));
                    }
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Doodle wall: a shared canvas with layers, undo, eraser and history
// ---------------------------------------------------------------------------

class DoodleWallScreen extends ConsumerStatefulWidget {
  const DoodleWallScreen({super.key});
  @override
  ConsumerState<DoodleWallScreen> createState() => _DoodleWallScreenState();
}

class _DoodleWallScreenState extends ConsumerState<DoodleWallScreen> {
  TrackerRecord? _wall;
  late DrawingController _c = DrawingController(author: ref.read(cozyMeProvider));
  bool _dirty = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _open(TrackerRecord? wall) {
    _c.dispose();
    _c = DrawingController(strokes: wall == null ? [] : DrawingController.parse(wall.fields['strokes']), author: ref.read(cozyMeProvider));
    setState(() {
      _wall = wall;
      _dirty = false;
    });
  }

  Future<void> _save() async {
    final t = ref.read(trackerNotifierProvider.notifier);
    final fields = {'strokes': _c.toJson()};
    if (_wall == null) {
      final title = tr(context, 'Wall ${DateFormat.MMMd().format(DateTime.now())}', 'Muro ${DateFormat.MMMd().format(DateTime.now())}');
      _wall = await t.create(kind: TrackerKind.cozyDoodle, title: title, memberId: ref.read(cozyMeProvider), fields: fields);
    } else {
      await t.save(_wall!.withFields({..._wall!.fields, ...fields}));
    }
    if (mounted) {
      setState(() => _dirty = false);
      PrismToast.show(context, message: tr(context, 'Saved to the wall', 'Guardado en el muro'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final walls = ref.watch(doodlesProvider);
    final names = ref.watch(gameNamesProvider);
    final me = ref.watch(cozyMeProvider);
    _c.author = me;
    final contributors = <String?, int>{};
    for (final s in _c.strokes) {
      contributors[s.author] = (contributors[s.author] ?? 0) + 1;
    }
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(context, '🖍️ Doodle wall', '🖍️ Muro de dibujos'),
        subtitle: _wall?.title,
        actions: [PrismTopBarAction(icon: PhosphorIcons.floppyDisk(), tooltip: tr(context, 'Save', 'Guardar'), onPressed: _save)],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + NavBarInset.of(context)),
          children: [
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: PrismChip(label: tr(context, '+ New wall', '+ Muro nuevo'), selected: _wall == null, onTap: () => _open(null)),
                  ),
                  for (final w in walls)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: PrismChip(label: w.title, selected: _wall?.id == w.id, onTap: () => _open(w)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            DrawingBoard(controller: _c, aspectRatio: 1.2, onChanged: () => _dirty = true),
            const SizedBox(height: 8),
            DrawingToolbar(controller: _c, layers: 3, onChanged: () => _dirty = true),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr(context, 'Drawing as ${me == null ? 'the system' : names[me] ?? '?'}', 'Dibujando como ${me == null ? 'el sistema' : names[me] ?? '?'}'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                PrismButton(tone: _dirty ? PrismButtonTone.filled : PrismButtonTone.subtle, label: tr(context, 'Save', 'Guardar'), onPressed: _save),
              ],
            ),
            PrismSectionHeader(title: tr(context, 'CONTRIBUTIONS', 'APORTACIONES')),
            ListenableBuilder(
              listenable: _c,
              builder: (context, _) {
                final counts = <String?, int>{};
                for (final s in _c.strokes) {
                  counts[s.author] = (counts[s.author] ?? 0) + 1;
                }
                if (counts.isEmpty) return Text(tr(context, 'Nobody has drawn here yet.', 'Nadie ha dibujado aquí aún.'), style: Theme.of(context).textTheme.bodySmall);
                return Column(
                  children: [
                    for (final e in counts.entries)
                      PrismListRow(
                        dense: true,
                        leading: AlterDot(e.key, size: 24),
                        title: Text(e.key == null ? tr(context, 'The system', 'El sistema') : names[e.key] ?? '?'),
                        trailing: Text(tr(context, '${e.value} strokes', '${e.value} trazos')),
                      ),
                  ],
                );
              },
            ),
            if (contributors.isEmpty && _wall != null) const SizedBox.shrink(),
            if (_wall != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: PrismButton(
                  icon: PhosphorIcons.trash(),
                  label: tr(context, 'Delete this wall', 'Eliminar este muro'),
                  onPressed: () async {
                    await ref.read(cozyActionsProvider).delete(_wall!);
                    _open(null);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Gifts & surprises
// ---------------------------------------------------------------------------

const giftEmoji = ['🎁', '💐', '🍪', '🧸', '☕', '🌟', '🎈', '📚', '🍫', '🕯️', '🌷', '🎀', '🧁', '🪴', '💎', '🐚'];

class GiftsScreen extends ConsumerWidget {
  const GiftsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gifts = ref.watch(giftsProvider);
    final names = ref.watch(gameNamesProvider);
    final theme = Theme.of(context);
    return PrismPageScaffold(
      topBar: PrismTopBar(title: tr(context, '🎁 Gifts & surprises', '🎁 Regalos y sorpresas')),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + NavBarInset.of(context)),
          children: [
            Text(
              tr(
                context,
                'Leave a little virtual gift for another alter. Surprises stay wrapped until they open them.',
                'Deja un pequeño regalo virtual a otro alter. Las sorpresas siguen envueltas hasta que las abre.',
              ),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            PrismButton(
              tone: PrismButtonTone.filled,
              icon: PhosphorIcons.gift(),
              label: tr(context, 'Give a gift', 'Hacer un regalo'),
              onPressed: () => PrismSheet.show<void>(context: context, title: tr(context, 'Give a gift', 'Hacer un regalo'), builder: (_) => const _GiftComposer()),
            ),
            const SizedBox(height: 12),
            if (gifts.isEmpty)
              EmptyState(
                icon: const Text('🎁', style: TextStyle(fontSize: 32)),
                title: tr(context, 'No gifts yet', 'Aún no hay regalos'),
                subtitle: tr(context, 'A tiny surprise can make someone\'s day.', 'Una pequeña sorpresa puede alegrar el día.'),
              )
            else
              for (final g in gifts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PrismSurface(
                    onTap: g.opened ? null : () => ref.read(cozyActionsProvider).setFields(g.r, {'opened': true, 'openedAt': DateTime.now().toIso8601String()}),
                    child: Row(
                      children: [
                        Text(g.opened || !g.surprise ? g.emoji : '🎁', style: const TextStyle(fontSize: 34)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                g.opened || !g.surprise ? g.name : tr(context, 'A wrapped surprise — tap to open', 'Una sorpresa envuelta: toca para abrir'),
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              Text('${names[g.from] ?? tr(context, 'Someone', 'Alguien')} → ${names[g.to] ?? tr(context, 'everyone', 'todos')}', style: theme.textTheme.bodySmall),
                              if ((g.opened || !g.surprise) && g.message.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('“${g.message}”', style: const TextStyle(fontStyle: FontStyle.italic)),
                                ),
                            ],
                          ),
                        ),
                        PrismIconButton(icon: PhosphorIcons.trash(), tooltip: tr(context, 'Remove', 'Quitar'), onPressed: () => ref.read(cozyActionsProvider).delete(g.r)),
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

class _GiftComposer extends ConsumerStatefulWidget {
  const _GiftComposer();
  @override
  ConsumerState<_GiftComposer> createState() => _GiftComposerState();
}

class _GiftComposerState extends ConsumerState<_GiftComposer> {
  String _emoji = giftEmoji.first;
  final _name = TextEditingController();
  final _msg = TextEditingController();
  late String? _from = ref.read(cozyMeProvider);
  String? _to;
  bool _surprise = true;

  @override
  void dispose() {
    _name.dispose();
    _msg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final names = ref.watch(gameNamesProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 4,
            children: [for (final e in giftEmoji) PrismChip(label: e, selected: _emoji == e, onTap: () => setState(() => _emoji = e))],
          ),
          const SizedBox(height: 8),
          PrismTextField(controller: _name, hintText: tr(context, 'What is it? (e.g. "A warm cup of cocoa")', '¿Qué es? (p. ej. "Un chocolate caliente")')),
          const SizedBox(height: 8),
          PrismTextField(controller: _msg, maxLines: 3, hintText: tr(context, 'A note (optional)', 'Una nota (opcional)')),
          PrismListRow(
            dense: true,
            leading: AlterDot(_from, size: 24),
            title: Text('${tr(context, 'From', 'De')} ${names[_from] ?? tr(context, 'the system', 'el sistema')}'),
            onTap: () async {
              final p = await pickAlters(context, ref, max: 1, selected: [?_from]);
              if (p != null) setState(() => _from = p.firstOrNull);
            },
          ),
          PrismListRow(
            dense: true,
            leading: AlterDot(_to, size: 24),
            title: Text('${tr(context, 'To', 'Para')} ${_to == null ? tr(context, 'choose…', 'elige…') : names[_to] ?? '?'}'),
            onTap: () async {
              final p = await pickAlters(context, ref, max: 1, selected: [?_to]);
              if (p != null) setState(() => _to = p.firstOrNull);
            },
          ),
          PrismSwitchRow(title: tr(context, 'Wrap it as a surprise', 'Envolver como sorpresa'), value: _surprise, onChanged: (v) => setState(() => _surprise = v)),
          const SizedBox(height: 8),
          PrismButton(
            tone: PrismButtonTone.filled,
            label: tr(context, 'Give', 'Regalar'),
            onPressed: () async {
              await ref
                  .read(trackerNotifierProvider.notifier)
                  .create(
                    kind: TrackerKind.cozyGift,
                    title: _name.text.trim().isEmpty ? _emoji : _name.text.trim(),
                    body: _msg.text.trim(),
                    memberId: _from,
                    fields: {'to': _to, 'emoji': _emoji, 'surprise': _surprise, 'opened': false},
                  );
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
