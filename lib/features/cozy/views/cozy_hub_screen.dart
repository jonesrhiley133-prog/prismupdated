import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/features/cozy/data/cozy_data.dart';
import 'package:prism_plurality/features/cozy/views/collections_view.dart';
import 'package:prism_plurality/features/cozy/views/comfort_view.dart';
import 'package:prism_plurality/features/cozy/views/cozy_widgets.dart';
import 'package:prism_plurality/features/cozy/views/garden_view.dart';
import 'package:prism_plurality/features/cozy/views/mailbox_view.dart';
import 'package:prism_plurality/features/cozy/views/together_view.dart';
import 'package:prism_plurality/features/games/content/prompt_bank.dart';
import 'package:prism_plurality/features/games/core/games_data.dart';
import 'package:prism_plurality/features/settings/views/feature_data_screen.dart' show FeatureDataAction;
import 'package:prism_plurality/features/subsystems/hub/subsystem_data.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

enum CozyTab { corner, rooms, mailbox, together, garden, comfort, collections }

extension on CozyTab {
  (String, String, String) get label => switch (this) {
    CozyTab.corner => ('☕', 'Corner', 'Rincón'),
    CozyTab.rooms => ('🚪', 'Rooms', 'Habitaciones'),
    CozyTab.mailbox => ('💌', 'Mailbox', 'Buzón'),
    CozyTab.together => ('🫶', 'Together', 'Juntos'),
    CozyTab.garden => ('🌱', 'Garden', 'Jardín'),
    CozyTab.comfort => ('🫧', 'Comfort', 'Calma'),
    CozyTab.collections => ('🫙', 'Collections', 'Colecciones'),
  };
}

class CozyHubScreen extends ConsumerStatefulWidget {
  const CozyHubScreen({super.key, this.tab});
  final String? tab;
  @override
  ConsumerState<CozyHubScreen> createState() => _CozyHubScreenState();
}

class _CozyHubScreenState extends ConsumerState<CozyHubScreen> {
  late CozyTab _tab = CozyTab.values.where((t) => t.name == widget.tab).firstOrNull ?? CozyTab.corner;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(cozySettingsProvider);
    final unread = ref.watch(unreadLettersProvider);
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(context, 'Cozy', 'Acogedor'),
        subtitle: settings.name.isEmpty ? null : '${settings.emoji} ${settings.name}',
        actions: [
          PrismTopBarAction(icon: PhosphorIcons.slidersHorizontal(), tooltip: tr(context, 'Customize', 'Personalizar'), onPressed: () => _customize(context)),
          const FeatureDataAction(featureId: 'cozy'),
        ],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + NavBarInset.of(context)),
          children: [
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final t in CozyTab.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: PrismChip(
                        label: '${t.label.$1} ${tr(context, t.label.$2, t.label.$3)}${t == CozyTab.mailbox && unread > 0 ? ' · $unread' : ''}',
                        selected: _tab == t,
                        onTap: () => setState(() => _tab = t),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionSwitcher(
              id: _tab,
              child: switch (_tab) {
                CozyTab.corner => _Corner(onGo: (t) => setState(() => _tab = t)),
                CozyTab.rooms => const _Rooms(),
                CozyTab.mailbox => const MailboxView(),
                CozyTab.together => const TogetherView(),
                CozyTab.garden => const GardenView(),
                CozyTab.comfort => const ComfortView(),
                CozyTab.collections => const CollectionsView(),
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _customize(BuildContext context) => PrismSheet.show<void>(context: context, title: tr(context, 'Customize Cozy', 'Personalizar Acogedor'), builder: (_) => const _CustomizeSheet());
}

class _CustomizeSheet extends ConsumerStatefulWidget {
  const _CustomizeSheet();
  @override
  ConsumerState<_CustomizeSheet> createState() => _CustomizeSheetState();
}

class _CustomizeSheetState extends ConsumerState<_CustomizeSheet> {
  late CozySettings _s = ref.read(cozySettingsProvider);
  late final _name = TextEditingController(text: _s.name);
  static const emojis = ['☕', '🛋️', '🕯️', '🏡', '🌙', '🍵', '🧸', '🌿', '🔥', '📚', '🌸', '🪴'];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _set(CozySettings s) {
    setState(() => _s = s);
    ref.read(cozyActionsProvider).saveSettings(s);
  }

  CozySettings _copy({String? name, String? emoji, bool? q, bool? a, bool? qu, bool? w}) => CozySettings(
    record: _s.record ?? ref.read(cozySettingsProvider).record,
    name: name ?? _s.name,
    emoji: emoji ?? _s.emoji,
    showQuote: q ?? _s.showQuote,
    showAffirmation: a ?? _s.showAffirmation,
    showQuestion: qu ?? _s.showQuestion,
    showWishlist: w ?? _s.showWishlist,
  );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrismTextField(
            controller: _name,
            labelText: tr(context, 'Lounge name', 'Nombre de la sala'),
            hintText: tr(context, 'e.g. The Lantern Room', 'p. ej. La sala del farol'),
            onSubmitted: (v) => _set(_copy(name: v.trim())),
            onChanged: (v) => _s = _copy(name: v.trim()),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            children: [
              for (final e in emojis)
                PrismChip(
                  label: e,
                  selected: _s.emoji == e,
                  onTap: () => _set(_copy(emoji: e)),
                ),
            ],
          ),
          PrismSwitchRow(
            title: tr(context, 'Quote of the day', 'Cita del día'),
            value: _s.showQuote,
            onChanged: (v) => _set(_copy(q: v)),
          ),
          PrismSwitchRow(
            title: tr(context, 'Daily affirmation', 'Afirmación diaria'),
            value: _s.showAffirmation,
            onChanged: (v) => _set(_copy(a: v)),
          ),
          PrismSwitchRow(
            title: tr(context, 'Question of the day', 'Pregunta del día'),
            value: _s.showQuestion,
            onChanged: (v) => _set(_copy(qu: v)),
          ),
          PrismSwitchRow(
            title: tr(context, 'Wishlist preview', 'Vista de la lista de deseos'),
            value: _s.showWishlist,
            onChanged: (v) => _set(_copy(w: v)),
          ),
          const SizedBox(height: 8),
          PrismButton(
            tone: PrismButtonTone.filled,
            label: tr(context, 'Done', 'Hecho'),
            onPressed: () {
              _set(_copy(name: _name.text.trim()));
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Corner (the shared lounge)
// ---------------------------------------------------------------------------

class _Corner extends ConsumerWidget {
  const _Corner({required this.onGo});
  final ValueChanged<CozyTab> onGo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = ref.watch(cozySettingsProvider);
    final posts = ref.watch(cozyPostsProvider).where((p) => p.fields['room'] == null).toList();
    final participants = ref.watch(recentCozyParticipantsProvider);
    final question = dailyPick(questionCards, salt: 3);
    final todaysAnswers = posts.where((p) => p.fields['starter'] == question && DateUtils.isSameDay(p.createdAt, DateTime.now())).length;
    final (quote, author) = dailyPick(quotes, salt: 1);
    final wishes = ref.watch(cozyListProvider('wishlist'));
    final unread = ref.watch(unreadLettersProvider);
    final thirsty = ref.watch(plantsProvider).where((p) => p.thirsty).length;

    Future<void> write({String? starter}) async {
      final c = await composeSheet(context, ref, title: starter == null ? tr(context, 'Share in the lounge', 'Compartir en la sala') : tr(context, 'Answer', 'Responder'), prompt: starter);
      if (c != null) await ref.read(cozyActionsProvider).post(body: c.text, memberId: c.author, starter: starter, mood: c.mood);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrismSurface(
          tone: PrismSurfaceTone.accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${s.emoji} ${s.name.isEmpty ? tr(context, 'The Cozy Corner', 'El rincón acogedor') : s.name}', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                tr(context, 'A shared space for everyone in the system — whoever is fronting, and whoever isn\'t.', 'Un espacio compartido para todo el sistema: quien esté al frente y quien no.'),
                style: theme.textTheme.bodySmall,
              ),
              if (s.showAffirmation) ...[const SizedBox(height: 10), Text('🌼 ${dailyPick(affirmations, salt: 2)}', style: const TextStyle(fontWeight: FontWeight.w600))],
              if (unread > 0 || thirsty > 0) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (unread > 0)
                      PrismChip(
                        label: tr(context, '💌 $unread new letter${unread == 1 ? '' : 's'}', '💌 $unread carta${unread == 1 ? '' : 's'} nueva${unread == 1 ? '' : 's'}'),
                        selected: false,
                        onTap: () => onGo(CozyTab.mailbox),
                      ),
                    if (thirsty > 0)
                      PrismChip(
                        label: tr(context, '💧 $thirsty plant${thirsty == 1 ? '' : 's'} would love water', '💧 $thirsty planta${thirsty == 1 ? '' : 's'} con sed'),
                        selected: false,
                        onTap: () => onGo(CozyTab.garden),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (s.showQuestion) ...[
          PrismSectionHeader(title: tr(context, 'QUESTION OF THE DAY', 'PREGUNTA DEL DÍA')),
          PrismSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(question, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  todaysAnswers == 0
                      ? tr(context, 'No answers yet today.', 'Aún no hay respuestas hoy.')
                      : tr(context, '$todaysAnswers answer${todaysAnswers == 1 ? '' : 's'} below.', '$todaysAnswers respuesta${todaysAnswers == 1 ? '' : 's'} abajo.'),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: PrismButton(
                    density: PrismControlDensity.compact,
                    label: tr(context, 'Answer', 'Responder'),
                    onPressed: () => write(starter: question),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (s.showQuote) ...[
          const SizedBox(height: 10),
          PrismSurface(
            child: Text('“$quote”\n— $author', style: const TextStyle(fontStyle: FontStyle.italic, height: 1.4)),
          ),
        ],
        PrismSectionHeader(title: tr(context, 'RECENTLY HERE', 'POR AQUÍ HACE POCO')),
        ParticipantsRow(ids: participants),
        PrismSectionHeader(title: tr(context, 'CONVERSATION STARTERS', 'PARA EMPEZAR A CHARLAR')),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final st in [dailyPick(conversationStarters, salt: 4), dailyPick(conversationStarters, salt: 9), dailyPick(conversationStarters, salt: 15)].toSet())
              PrismChip(
                label: st,
                selected: false,
                onTap: () => write(starter: st),
              ),
          ],
        ),
        PrismSectionHeader(title: tr(context, 'QUICK GRATITUDE', 'GRATITUD RÁPIDA')),
        _GratitudeQuick(),
        if (s.showWishlist && wishes.isNotEmpty) ...[
          PrismSectionHeader(title: tr(context, 'WISHLIST', 'LISTA DE DESEOS')),
          PrismSurface(onTap: () => onGo(CozyTab.collections), child: Text(wishes.take(4).map((w) => '• ${w.title}').join('\n'))),
        ],
        PrismSectionHeader(title: tr(context, 'THE LOUNGE', 'LA SALA')),
        PrismButton(icon: PhosphorIcons.chatCircleText(), label: tr(context, 'Share something', 'Compartir algo'), onPressed: write),
        const SizedBox(height: 10),
        if (posts.isEmpty)
          EmptyState(
            icon: Icon(PhosphorIcons.coffee()),
            title: tr(context, 'The lounge is quiet', 'La sala está tranquila'),
            subtitle: tr(context, 'Say hello, share a thought, or answer today\'s question.', 'Saluda, comparte algo o responde la pregunta de hoy.'),
          )
        else
          for (final p in posts.take(40)) PostCard(post: p),
      ],
    );
  }
}

class _GratitudeQuick extends ConsumerStatefulWidget {
  @override
  ConsumerState<_GratitudeQuick> createState() => _GratitudeQuickState();
}

class _GratitudeQuickState extends ConsumerState<_GratitudeQuick> {
  final _ctl = TextEditingController();
  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = ref.watch(cozyListProvider('gratitude')).length;
    return Row(
      children: [
        Expanded(
          child: PrismTextField(controller: _ctl, hintText: tr(context, 'Something you\'re grateful for… ($count in the jar)', 'Algo que agradeces… ($count en el tarro)'), onSubmitted: (_) => _add()),
        ),
        PrismIconButton(icon: PhosphorIcons.plus(), tooltip: tr(context, 'Add to jar', 'Añadir al tarro'), onPressed: _add),
      ],
    );
  }

  Future<void> _add() async {
    final t = _ctl.text.trim();
    if (t.isEmpty) return;
    await ref.read(cozyActionsProvider).addListItem('gratitude', title: t, memberId: ref.read(cozyMeProvider));
    _ctl.clear();
    if (mounted) PrismToast.show(context, message: tr(context, 'Added to the gratitude jar 🫙', 'Añadido al tarro de gratitud 🫙'));
  }
}

// ---------------------------------------------------------------------------
// Rooms
// ---------------------------------------------------------------------------

String accessLabel(BuildContext c, String a) => switch (a) {
  'private' => tr(c, '🔒 Private', '🔒 Privada'),
  'shared' => tr(c, '👥 Shared with some', '👥 Compartida'),
  'subsystem' => tr(c, '🌌 Subsystem', '🌌 Subsistema'),
  _ => tr(c, '🌍 Everyone', '🌍 Todos'),
};

class _Rooms extends ConsumerWidget {
  const _Rooms();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(roomsProvider);
    final names = ref.watch(gameNamesProvider);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(
            context,
            'Rooms are little shared spaces with their own board, notes and checklists. Each room can be open to everyone, private, shared with chosen alters or tied to a subsystem.',
            'Las habitaciones son pequeños espacios con su propio tablero, notas y listas. Pueden ser para todos, privadas, compartidas o de un subsistema.',
          ),
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        PrismButton(tone: PrismButtonTone.filled, icon: PhosphorIcons.plus(), label: tr(context, 'New room', 'Nueva habitación'), onPressed: () => editRoom(context, ref)),
        const SizedBox(height: 12),
        if (rooms.isEmpty)
          EmptyState(
            icon: Icon(PhosphorIcons.door()),
            title: tr(context, 'No rooms yet', 'Aún no hay habitaciones'),
            subtitle: tr(context, 'A reading nook, an art studio, a quiet room…', 'Un rincón de lectura, un estudio de arte, una sala tranquila…'),
          )
        else
          LayoutBuilder(
            builder: (context, box) {
              final cols = box.maxWidth > 560 ? 3 : 2;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.15,
                children: [
                  for (final r in rooms)
                    PrismSurface(
                      onTap: () => context.push(AppRoutePaths.cozyRoom(r.r.id)),
                      accentColor: r.color == null ? null : Color(r.color!),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.emoji, style: const TextStyle(fontSize: 32)),
                          const Spacer(),
                          Text(
                            r.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(accessLabel(context, r.access), style: theme.textTheme.labelSmall),
                          if (r.owner != null) Text(tr(context, 'by ${names[r.owner] ?? '?'}', 'de ${names[r.owner] ?? '?'}'), style: theme.textTheme.labelSmall),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

Future<void> editRoom(BuildContext context, WidgetRef ref, {Room? room}) => PrismSheet.show<void>(
  context: context,
  title: room == null ? tr(context, 'New room', 'Nueva habitación') : tr(context, 'Room settings', 'Ajustes de la habitación'),
  builder: (_) => _RoomEditor(room: room),
);

class _RoomEditor extends ConsumerStatefulWidget {
  const _RoomEditor({this.room});
  final Room? room;
  @override
  ConsumerState<_RoomEditor> createState() => _RoomEditorState();
}

class _RoomEditorState extends ConsumerState<_RoomEditor> {
  late final _name = TextEditingController(text: widget.room?.name ?? '');
  late final _desc = TextEditingController(text: widget.room?.description ?? '');
  late String _emoji = widget.room?.emoji ?? '🛋️';
  late String _access = widget.room?.access ?? 'public';
  late List<String> _members = widget.room?.members ?? [];
  late String? _owner = widget.room?.owner ?? ref.read(cozyMeProvider);
  late String? _sub = widget.room?.subsystemId;
  static const emojis = ['🛋️', '📚', '🎨', '🎮', '🌿', '🕯️', '🎵', '🧸', '🍳', '🌙', '🔭', '🛁', '🧶', '🏕️'];

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final names = ref.watch(gameNamesProvider);
    final subs = ref.watch(subsystemsProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrismTextField(controller: _name, labelText: tr(context, 'Name', 'Nombre'), autofocus: widget.room == null),
          const SizedBox(height: 8),
          PrismTextField(controller: _desc, labelText: tr(context, 'Description (optional)', 'Descripción (opcional)'), maxLines: 2),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            children: [for (final e in emojis) PrismChip(label: e, selected: _emoji == e, onTap: () => setState(() => _emoji = e))],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final a in const ['public', 'private', 'shared', 'subsystem']) PrismChip(label: accessLabel(context, a), selected: _access == a, onTap: () => setState(() => _access = a)),
            ],
          ),
          const SizedBox(height: 8),
          PrismListRow(
            dense: true,
            leading: AlterDot(_owner, size: 26),
            title: Text(tr(context, 'Owner: ${_owner == null ? 'the system' : names[_owner] ?? '?'}', 'Dueño: ${_owner == null ? 'el sistema' : names[_owner] ?? '?'}')),
            onTap: () async {
              final p = await pickAlters(context, ref, max: 1, selected: [?_owner]);
              if (p != null) setState(() => _owner = p.firstOrNull);
            },
          ),
          if (_access == 'shared')
            AlterChips(
              ids: _members,
              emptyLabel: tr(context, 'Choose who can enter', 'Elige quién puede entrar'),
              onTap: () async {
                final p = await pickAlters(context, ref, selected: _members);
                if (p != null) setState(() => _members = p);
              },
            ),
          if (_access == 'subsystem')
            subs.isEmpty
                ? Text(tr(context, 'No subsystems yet — create one in Subsystems.', 'Aún no hay subsistemas: crea uno en Subsistemas.'))
                : Wrap(
                    spacing: 6,
                    children: [for (final s in subs) PrismChip(label: s.title, selected: _sub == s.id, onTap: () => setState(() => _sub = s.id))],
                  ),
          const SizedBox(height: 12),
          PrismButton(
            tone: PrismButtonTone.filled,
            label: tr(context, 'Save', 'Guardar'),
            onPressed: () async {
              final name = _name.text.trim().isEmpty ? tr(context, 'New room', 'Nueva habitación') : _name.text.trim();
              final fields = {'emoji': _emoji, 'access': _access, 'members': _members, 'subsystem': _sub};
              final t = ref.read(trackerNotifierProvider.notifier);
              if (widget.room == null) {
                await t.create(kind: TrackerKind.cozyRoom, title: name, body: _desc.text.trim(), memberId: _owner, fields: fields);
              } else {
                await t.save(widget.room!.r.copyWith(title: name, body: _desc.text.trim(), memberId: _owner).withFields({...widget.room!.r.fields, ...fields}));
              }
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

/// One room: its board of notes, checklists and posts.
class CozyRoomScreen extends ConsumerStatefulWidget {
  const CozyRoomScreen({super.key, required this.roomId});
  final String roomId;
  @override
  ConsumerState<CozyRoomScreen> createState() => _CozyRoomScreenState();
}

class _CozyRoomScreenState extends ConsumerState<CozyRoomScreen> {
  bool _knocked = false;

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(roomsProvider).where((r) => r.r.id == widget.roomId).firstOrNull;
    final theme = Theme.of(context);
    if (room == null) {
      return PrismPageScaffold(
        topBar: PrismTopBar(title: tr(context, 'Room', 'Habitación')),
        body: EmptyState(icon: Icon(PhosphorIcons.door()), title: tr(context, 'Room not found', 'Habitación no encontrada'), subtitle: ''),
      );
    }
    final allowed = ref.watch(roomAllowedProvider(room.r.id));
    final me = ref.watch(cozyMeProvider);
    final mayEnter = allowed == null || _knocked || (me != null && allowed.contains(me));
    final items = ref.watch(roomItemsProvider(room.r.id));
    final posts = ref.watch(cozyPostsProvider).where((p) => p.fields['room'] == room.r.id).toList();
    final names = ref.watch(gameNamesProvider);

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: '${room.emoji} ${room.name}',
        subtitle: accessLabel(context, room.access),
        actions: [
          if (mayEnter)
            PrismTopBarAction(
              icon: PhosphorIcons.gear(),
              tooltip: tr(context, 'Room settings', 'Ajustes'),
              onPressed: () => editRoom(context, ref, room: room),
            ),
          if (mayEnter)
            PrismTopBarAction(
              icon: PhosphorIcons.trash(),
              tooltip: tr(context, 'Delete room', 'Eliminar'),
              onPressed: () async {
                for (final i in items) {
                  await ref.read(cozyActionsProvider).delete(i);
                }
                await ref.read(cozyActionsProvider).delete(room.r);
                if (context.mounted) context.pop();
              },
            ),
        ],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + NavBarInset.of(context)),
          children: !mayEnter
              ? [
                  const SizedBox(height: 40),
                  Icon(PhosphorIcons.lock(), size: 48, color: theme.colorScheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    tr(context, 'This room is ${room.access == 'private' ? 'private' : 'for certain alters'}.', 'Esta habitación es ${room.access == 'private' ? 'privada' : 'para ciertos alters'}.'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr(context, 'It belongs to ${names[room.owner] ?? 'someone'}. Please respect their space.', 'Es de ${names[room.owner] ?? 'alguien'}. Respeta su espacio.'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: PrismButton(label: tr(context, 'I\'m allowed in', 'Tengo permiso'), onPressed: () => setState(() => _knocked = true)),
                  ),
                ]
              : [
                  if (room.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(room.description, style: theme.textTheme.bodyMedium),
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      PrismButton(icon: PhosphorIcons.note(), label: tr(context, 'Pin a note', 'Fijar una nota'), onPressed: () => _addItem(context, 'note')),
                      PrismButton(icon: PhosphorIcons.checkSquare(), label: tr(context, 'Add to-do', 'Añadir tarea'), onPressed: () => _addItem(context, 'todo')),
                      PrismButton(
                        icon: PhosphorIcons.chatCircleText(),
                        label: tr(context, 'Post', 'Publicar'),
                        onPressed: () async {
                          final c = await composeSheet(context, ref, title: room.name);
                          if (c != null) await ref.read(cozyActionsProvider).post(body: c.text, memberId: c.author, room: room.r.id, mood: c.mood);
                        },
                      ),
                    ],
                  ),
                  PrismSectionHeader(title: tr(context, 'BOARD', 'TABLERO')),
                  if (items.isEmpty)
                    Text(tr(context, 'Nothing pinned yet.', 'Nada fijado aún.'), style: theme.textTheme.bodySmall)
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final i in items)
                          SizedBox(
                            width: 160,
                            child: PrismSurface(
                              padding: const EdgeInsets.all(10),
                              fillColor: i.fields['type'] == 'note' ? const Color(0xFFFFF4C2).withValues(alpha: theme.brightness == Brightness.dark ? 0.18 : 0.9) : null,
                              onLongPress: () => ref.read(cozyActionsProvider).delete(i),
                              onTap: i.fields['type'] == 'todo' ? () => ref.read(cozyActionsProvider).setFields(i, {'done': i.fields['done'] != true}) : null,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${i.fields['type'] == 'todo' ? (i.fields['done'] == true ? '☑️ ' : '⬜ ') : ''}${i.title}',
                                    style: TextStyle(
                                      decoration: i.fields['done'] == true ? TextDecoration.lineThrough : null,
                                      color: i.fields['type'] == 'note' && theme.brightness == Brightness.light ? const Color(0xFF3B3B58) : null,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(names[i.memberId] ?? '', style: theme.textTheme.labelSmall),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  if (items.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(tr(context, 'Tap a to-do to tick it · long-press to remove', 'Toca una tarea para marcarla · mantén para quitar'), style: theme.textTheme.bodySmall),
                    ),
                  PrismSectionHeader(title: tr(context, 'CONVERSATION', 'CONVERSACIÓN')),
                  if (posts.isEmpty) Text(tr(context, 'No posts in this room yet.', 'Aún no hay publicaciones.'), style: theme.textTheme.bodySmall) else for (final p in posts) PostCard(post: p),
                ],
        ),
      ),
    );
  }

  Future<void> _addItem(BuildContext context, String type) async {
    final ctl = TextEditingController();
    final t = await PrismSheet.show<String>(
      context: context,
      title: type == 'note' ? tr(context, 'Pin a note', 'Fijar una nota') : tr(context, 'Add to-do', 'Añadir tarea'),
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PrismTextField(controller: ctl, autofocus: true, maxLines: 3),
            const SizedBox(height: 10),
            PrismButton(tone: PrismButtonTone.filled, label: tr(ctx, 'Add', 'Añadir'), onPressed: () => Navigator.of(ctx).pop(ctl.text.trim())),
          ],
        ),
      ),
    );
    ctl.dispose();
    if (t == null || t.isEmpty) return;
    await ref.read(trackerNotifierProvider.notifier).create(kind: TrackerKind.cozyRoomItem, parentId: widget.roomId, title: t, memberId: ref.read(cozyMeProvider), fields: {'type': type});
  }
}
