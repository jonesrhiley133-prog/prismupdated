import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:uuid/uuid.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/domain/models/calendar_event.dart';
import 'package:prism_plurality/features/games/core/game_catalog.dart';
import 'package:prism_plurality/features/games/core/game_kit.dart';
import 'package:prism_plurality/features/games/core/game_screen.dart';
import 'package:prism_plurality/features/games/core/games_data.dart';
import 'package:prism_plurality/features/games/views/games_hub_screen.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Game Night list inside the Games hub.
class GameNightsView extends ConsumerWidget {
  const GameNightsView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nights = ref.watch(gameNightsProvider);
    final names = ref.watch(gameNamesProvider);
    final theme = Theme.of(context);
    final upcoming = nights.where((n) => n.status != 'done').toList();
    final past = nights.where((n) => n.status == 'done').toList();
    Widget tile(GameNight n) => PrismListRow(
      leading: Text(n.status == 'done' ? '🏁' : (n.status == 'live' ? '🎲' : (n.status == 'paused' ? '⏸️' : '🌙')), style: const TextStyle(fontSize: 24)),
      title: Text(n.title.isEmpty ? tr(context, 'Game night', 'Noche de juegos') : n.title),
      subtitle: Text(
        [if (n.when != null) DateFormat.MMMEd().add_jm().format(n.when!), '${n.games.length} ${tr(context, 'games', 'juegos')} · ${n.players.map((p) => names[p] ?? '?').join(', ')}'].join('\n'),
      ),
      showChevron: true,
      onTap: () => context.push(AppRoutePaths.gameNight(n.r.id)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(
            context,
            'Plan an evening of games with any alters — fronting or not. Pause any time and pick up later.',
            'Planea una noche de juegos con cualquier alter, esté al frente o no. Pausa cuando quieras y retoma después.',
          ),
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        PrismButton(
          tone: PrismButtonTone.filled,
          icon: PhosphorIcons.plus(),
          label: tr(context, 'Plan a game night', 'Planear una noche de juegos'),
          onPressed: () async {
            final id = await createGameNight(context, ref);
            if (id != null && context.mounted) context.push(AppRoutePaths.gameNight(id));
          },
        ),
        PrismSectionHeader(title: tr(context, 'UPCOMING & IN PROGRESS', 'PRÓXIMAS Y EN CURSO')),
        if (upcoming.isEmpty)
          EmptyState(
            icon: Icon(PhosphorIcons.moonStars()),
            title: tr(context, 'No game nights planned', 'No hay noches planeadas'),
            subtitle: tr(context, 'Whenever you feel like it.', 'Cuando os apetezca.'),
          )
        else
          PrismSurface(
            padding: EdgeInsets.zero,
            child: Column(children: [for (final n in upcoming) tile(n)]),
          ),
        if (past.isNotEmpty) ...[
          PrismSectionHeader(title: tr(context, 'PAST NIGHTS', 'NOCHES PASADAS')),
          PrismSurface(
            padding: EdgeInsets.zero,
            child: Column(children: [for (final n in past) tile(n)]),
          ),
        ],
      ],
    );
  }
}

Future<String?> createGameNight(BuildContext context, WidgetRef ref) async {
  final title = await promptText(context, title: tr(context, 'Name this game night', 'Nombra la noche de juegos'), initial: tr(context, 'Game night', 'Noche de juegos'), maxLines: 1);
  if (title == null || !context.mounted) return null;
  final players = await pickAlters(context, ref, title: tr(context, 'Who\'s coming?', '¿Quién viene?'));
  if (players == null || !context.mounted) return null;
  final now = DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: now,
    firstDate: now.subtract(const Duration(days: 1)),
    lastDate: now.add(const Duration(days: 365)),
    helpText: tr(context, 'When? (cancel for "now")', '¿Cuándo? (cancela para "ahora")'),
  );
  DateTime when = now;
  if (date != null && context.mounted) {
    final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 19, minute: 0));
    when = DateTime(date.year, date.month, date.day, t?.hour ?? 19, t?.minute ?? 0);
  }
  String? calId;
  if (date != null) {
    calId = const Uuid().v4();
    await ref
        .read(calendarRepositoryProvider)
        .create(
          CalendarEvent(
            id: calId,
            title: '🎲 $title',
            description: 'Game night in Prism',
            startAt: when,
            endAt: when.add(const Duration(hours: 2)),
            category: 'games',
            memberIds: players,
            alertMinutes: const [30],
            createdAt: now,
            modifiedAt: now,
          ),
        );
  }
  final r = await ref
      .read(trackerNotifierProvider.notifier)
      .create(kind: TrackerKind.gameNight, title: title, occurredAt: when, fields: {'players': players, 'games': const <String>[], 'status': 'planned', 'coop': false, 'calendar': calId});
  return r.id;
}

/// One game night: line-up, playing in order, pause/resume and recap.
class GameNightScreen extends ConsumerWidget {
  const GameNightScreen({super.key, required this.nightId});
  final String nightId;

  Future<void> _update(WidgetRef ref, GameNight n, Map<String, Object?> f) => ref.read(trackerNotifierProvider.notifier).save(n.r.withFields({...n.r.fields, ...f}));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(gameNightsProvider).where((x) => x.r.id == nightId).firstOrNull;
    final theme = Theme.of(context);
    if (n == null) {
      return PrismPageScaffold(
        topBar: PrismTopBar(title: tr(context, 'Game night', 'Noche de juegos')),
        body: EmptyState(icon: Icon(PhosphorIcons.moonStars()), title: tr(context, 'Not found', 'No encontrada'), subtitle: ''),
      );
    }
    final names = ref.watch(gameNamesProvider);
    final results = ref.watch(gameResultsProvider).where((r) => r.nightId == nightId).toList()..sort((a, b) => a.when.compareTo(b.when));
    final played = {for (final r in results) r.gameId};
    final next = n.games.where((g) => !played.contains(g)).firstOrNull;
    final totals = <String, int>{};
    for (final r in results) {
      if (r.memberId != null && r.score != null) totals[r.memberId!] = (totals[r.memberId!] ?? 0) + r.score!;
    }
    final combined = totals.values.fold(0, (a, b) => a + b);

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: n.title.isEmpty ? tr(context, 'Game night', 'Noche de juegos') : n.title,
        subtitle: n.when == null ? null : DateFormat.MMMEd().add_jm().format(n.when!),
        actions: [
          PrismTopBarAction(
            icon: PhosphorIcons.trash(),
            tooltip: tr(context, 'Delete', 'Eliminar'),
            onPressed: () async {
              await ref.read(trackerNotifierProvider.notifier).delete(n.r.id);
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
          children: [
            PrismSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(switch (n.status) {
                    'live' => tr(context, '🎲 In progress', '🎲 En curso'),
                    'paused' => tr(context, '⏸️ Paused — resume whenever you like', '⏸️ En pausa: retoma cuando quieras'),
                    'done' => tr(context, '🏁 Finished', '🏁 Terminada'),
                    _ => tr(context, '🌙 Planned', '🌙 Planeada'),
                  }, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  PrismSegmentedControl<bool>(
                    segments: [
                      PrismSegment(value: false, label: tr(context, 'Friendly scores', 'Puntos amistosos')),
                      PrismSegment(value: true, label: tr(context, 'Co-op (team total)', 'Cooperativo (total)')),
                    ],
                    selected: n.coop,
                    onChanged: (v) => _update(ref, n, {'coop': v}),
                  ),
                  const SizedBox(height: 10),
                  if (n.status != 'done')
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (next != null)
                          PrismButton(
                            tone: PrismButtonTone.filled,
                            icon: PhosphorIcons.play(),
                            label: n.status == 'paused'
                                ? tr(context, 'Resume', 'Reanudar')
                                : tr(context, 'Play next: ${trp(context, gameById(next)?.name ?? (next, next))}', 'Siguiente: ${trp(context, gameById(next)?.name ?? (next, next))}'),
                            onPressed: () async {
                              await _update(ref, n, {'status': 'live'});
                              if (context.mounted) context.push(AppRoutePaths.gamePlay(next, night: n.r.id));
                            },
                          ),
                        if (n.status == 'live') PrismButton(icon: PhosphorIcons.pause(), label: tr(context, 'Pause', 'Pausar'), onPressed: () => _update(ref, n, {'status': 'paused'})),
                        PrismButton(icon: PhosphorIcons.flagCheckered(), label: tr(context, 'End night', 'Terminar'), onPressed: () => _update(ref, n, {'status': 'done'})),
                      ],
                    ),
                ],
              ),
            ),
            PrismSectionHeader(title: tr(context, 'WHO\'S PLAYING', 'QUIÉN JUEGA')),
            AlterChips(
              ids: n.players,
              onTap: () async {
                final p = await pickAlters(context, ref, selected: n.players);
                if (p != null) await _update(ref, n, {'players': p});
              },
            ),
            PrismSectionHeader(title: tr(context, 'LINE-UP', 'PROGRAMA')),
            PrismSurface(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < n.games.length; i++)
                    PrismListRow(
                      leading: Text(gameById(n.games[i])?.emoji ?? '🎲', style: const TextStyle(fontSize: 22)),
                      title: Text(trp(context, gameById(n.games[i])?.name ?? (n.games[i], n.games[i]))),
                      subtitle: Text(played.contains(n.games[i]) ? tr(context, '✓ Played', '✓ Jugado') : (n.games[i] == next ? tr(context, 'Up next', 'Siguiente') : '')),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PrismIconButton(
                            icon: PhosphorIcons.arrowUp(),
                            tooltip: tr(context, 'Move up', 'Subir'),
                            onPressed: i == 0
                                ? () {}
                                : () {
                                    final g = [...n.games];
                                    g.insert(i - 1, g.removeAt(i));
                                    _update(ref, n, {'games': g});
                                  },
                          ),
                          PrismIconButton(
                            icon: PhosphorIcons.x(),
                            tooltip: tr(context, 'Remove', 'Quitar'),
                            onPressed: () => _update(ref, n, {
                              'games': [...n.games]..removeAt(i),
                            }),
                          ),
                        ],
                      ),
                    ),
                  PrismListRow(
                    leading: Icon(PhosphorIcons.plus()),
                    title: Text(tr(context, 'Add a game', 'Añadir un juego')),
                    onTap: () async {
                      final g = await pickGame(context, where: (g) => g.multiplayer);
                      if (g != null)
                        await _update(ref, n, {
                          'games': [...n.games, g.id],
                        });
                    },
                  ),
                  PrismListRow(
                    leading: Icon(PhosphorIcons.shuffle()),
                    title: Text(tr(context, 'Surprise line-up (3 games)', 'Programa sorpresa (3 juegos)')),
                    onTap: () {
                      final pool = gameCatalog.where((g) => g.multiplayer && !n.games.contains(g.id)).toList()..shuffle();
                      _update(ref, n, {
                        'games': [...n.games, ...pool.take(3).map((g) => g.id)],
                      });
                    },
                  ),
                ],
              ),
            ),
            if (results.isNotEmpty) ...[
              PrismSectionHeader(title: tr(context, 'RECAP', 'RESUMEN')),
              PrismSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (n.coop)
                      Text(tr(context, 'Team total: $combined points 🤝', 'Total del equipo: $combined puntos 🤝'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))
                    else
                      for (final e in (totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value))))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              AlterDot(e.key, size: 24),
                              const SizedBox(width: 8),
                              Expanded(child: Text(names[e.key] ?? '?')),
                              Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                    const Divider(height: 20),
                    for (final r in results)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '${gameById(r.gameId)?.emoji ?? ''} ${trp(context, gameById(r.gameId)?.name ?? (r.gameId, r.gameId))} — ${r.memberId == null ? '' : '${names[r.memberId]}: '}${r.summary}',
                        ),
                      ),
                    for (final r in results.where((r) => (r.memorable ?? '').isNotEmpty).take(3))
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('"${r.memorable}"', style: const TextStyle(fontStyle: FontStyle.italic)),
                      ),
                    const SizedBox(height: 10),
                    PrismButton(
                      icon: PhosphorIcons.notebook(),
                      label: tr(context, 'Save recap to Journal', 'Guardar resumen en el diario'),
                      onPressed: () async {
                        final body = [
                          n.coop ? 'Team total: $combined' : totals.entries.map((e) => '${names[e.key]}: ${e.value}').join(', '),
                          for (final r in results) '• ${gameById(r.gameId)?.name.$1 ?? r.gameId}: ${r.memberId == null ? '' : '${names[r.memberId]} — '}${r.summary}',
                        ].join('\n');
                        await ref
                            .read(trackerNotifierProvider.notifier)
                            .create(kind: TrackerKind.journalEntry, title: '🎲 ${n.title}', body: body, occurredAt: DateTime.now(), tags: const ['games', 'game-night']);
                        if (context.mounted) PrismToast.show(context, message: tr(context, 'Saved to Journal', 'Guardado en el diario'));
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Route wrapper: resolves a custom game or a game night, then hosts it.
class GamePlayRoute extends ConsumerWidget {
  const GamePlayRoute({super.key, required this.gameId, this.challengeId, this.customId, this.nightId});
  final String gameId;
  final String? challengeId;
  final String? customId;
  final String? nightId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final custom = customId == null ? null : ref.watch(customGamesProvider).where((c) => c.r.id == customId).firstOrNull;
    final night = nightId == null ? null : ref.read(gameNightsProvider).where((n) => n.r.id == nightId).firstOrNull;
    return GameScreen(
      gameId: custom?.base ?? gameId,
      challengeId: challengeId,
      custom: custom == null ? null : {...custom.content, 'title': custom.title},
      customTitle: custom?.title,
      players: night?.players,
      nightId: nightId,
    );
  }
}
