import 'package:flutter/services.dart';
import 'package:prism_social_core/prism_social_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/account/account_core.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/online_games/online_room.dart';
import 'package:prism_plurality/features/prism_social/social_remote.dart'
    show socialConnectionProvider;
import 'package:prism_plurality/shared/ui_kit.dart';

const _serverKey = 'prism_online_games_server';

/// Play online: make a room and share its code, or join one.
class OnlineLobbyScreen extends ConsumerStatefulWidget {
  const OnlineLobbyScreen({super.key});
  @override
  ConsumerState<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends ConsumerState<OnlineLobbyScreen> {
  final _server = TextEditingController();
  final _name = TextEditingController();
  final _code = TextEditingController();
  String _game = onlineGames.first.id;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _server.text =
        ref.read(socialConnectionProvider)?.url ??
        ref.read(activeAccountProvider)?.server ??
        '';
    SharedPreferences.getInstance().then((p) {
      final saved = p.getString(_serverKey);
      if (saved != null && _server.text.isEmpty && mounted)
        setState(() => _server.text = saved);
    });
    final id = currentFronterId(ref);
    final members =
        ref.read(userVisibleMembersProvider).value ?? const <Member>[];
    _name.text =
        members
            .where((m) => m.id == id)
            .firstOrNull
            ?.effectiveName(
              preferDisplayName: ref.read(memberNamePreferDisplayProvider),
            ) ??
        '';
  }

  @override
  void dispose() {
    _server.dispose();
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _go(bool create) async {
    final server = _server.text.trim();
    if (server.isEmpty)
      return setState(
        () => _error = 'Enter the Prism server address to play online.',
      );
    if (!create && _code.text.trim().length < 4)
      return setState(() => _error = 'Enter the room code.');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final client = RoomClient(server);
      final name = _name.text.trim().isEmpty ? 'Player' : _name.text.trim();
      final room = create
          ? await client.create(_game, name)
          : await client.join(_code.text, name);
      (await SharedPreferences.getInstance()).setString(_serverKey, server);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => OnlineRoomScreen(session: RoomSession(client, room)),
        ),
      );
    } on RoomError catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PrismPageScaffold(
      topBar: const PrismTopBar(title: 'Play online', showBackButton: true),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            32 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          children: [
            Text(
              'Play with friends on other phones. Share the room code — no account needed.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            PrismTextField(
              controller: _name,
              labelText: 'Your name in the game',
            ),
            const SizedBox(height: 18),
            PrismSectionHeader(title: 'START A ROOM'),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.7,
              children: [
                for (final g in onlineGames)
                  PrismSurface(
                    onTap: () => setState(() => _game = g.id),
                    padding: const EdgeInsets.all(10),
                    borderColor: _game == g.id
                        ? theme.colorScheme.primary
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${g.emoji} ${g.name}',
                          style: theme.textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          g.blurb,
                          style: theme.textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          g.minPlayers == g.maxPlayers
                              ? '${g.minPlayers} players'
                              : '${g.minPlayers}–${g.maxPlayers} players',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            PrismButton(
              label: 'Create room',
              icon: Icons.add,
              tone: PrismButtonTone.filled,
              expanded: true,
              isLoading: _busy,
              onPressed: () => _go(true),
            ),
            const SizedBox(height: 18),
            PrismSectionHeader(title: 'JOIN A ROOM'),
            Row(
              children: [
                Expanded(
                  child: PrismTextField(
                    controller: _code,
                    hintText: 'Room code',
                    textCapitalization: TextCapitalization.characters,
                    onSubmitted: (_) => _go(false),
                  ),
                ),
                const SizedBox(width: 8),
                PrismButton(
                  label: 'Join',
                  tone: PrismButtonTone.outlined,
                  onPressed: () => _go(false),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 18),
            PrismTextField(
              controller: _server,
              labelText: 'Server',
              hintText: 'prism-social.up.railway.app',
              keyboardType: TextInputType.url,
              helperText: 'Everyone in a room must use the same server.',
            ),
          ],
        ),
      ),
    );
  }
}

class OnlineRoomScreen extends StatefulWidget {
  const OnlineRoomScreen({super.key, required this.session});
  final RoomSession session;
  @override
  State<OnlineRoomScreen> createState() => _OnlineRoomScreenState();
}

class _OnlineRoomScreenState extends State<OnlineRoomScreen> {
  RoomSession get s => widget.session;

  @override
  void initState() {
    super.initState();
    s.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    s.removeListener(_changed);
    s.dispose();
    super.dispose();
  }

  Future<bool> _confirmLeave() async {
    if (s.closed) return true;
    final ok = await PrismDialog.confirm(
      context: context,
      title: 'Leave the room?',
      message: s.room.status == 'playing'
          ? 'The game ends for everyone if too few players are left.'
          : null,
      confirmLabel: 'Leave',
    );
    if (ok) await s.leave();
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    final r = s.room;
    final theme = Theme.of(context);
    return PopScope(
      canPop: s.closed,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted)
          Navigator.of(context).pop();
      },
      child: PrismPageScaffold(
        topBar: PrismTopBar(
          title: '${r.game.emoji} ${r.game.name}',
          showBackButton: true,
        ),
        bodyPadding: EdgeInsets.zero,
        body: ClampedBody(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              32 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            children: [
              PrismSurface(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Room code', style: theme.textTheme.labelMedium),
                          SelectableText(
                            r.code,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy code',
                      icon: const Icon(Icons.copy),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: r.code));
                        PrismToast.show(context, message: 'Code copied');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < r.players.length; i++)
                    Chip(
                      avatar: Icon(
                        r.players[i]['online'] == true &&
                                r.players[i]['left'] != true
                            ? Icons.circle
                            : Icons.circle_outlined,
                        size: 12,
                        color: r.players[i]['left'] == true
                            ? theme.colorScheme.outline
                            : (r.players[i]['online'] == true
                                  ? Colors.green
                                  : theme.colorScheme.outline),
                      ),
                      label: Text(
                        '${r.players[i]['name']}${i == r.seat ? ' (you)' : ''}${(r.players[i]['wins'] as num? ?? 0) > 0 ? ' · ${r.players[i]['wins']}🏆' : ''}',
                      ),
                      side: r.turn == i
                          ? BorderSide(
                              color: theme.colorScheme.primary,
                              width: 2,
                            )
                          : null,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (r.status == 'lobby')
                _lobby(context, r)
              else ...[
                _statusLine(context, r),
                const SizedBox(height: 12),
                _board(r),
                if (r.status == 'finished' && r.isHost) ...[
                  const SizedBox(height: 14),
                  PrismButton(
                    label: 'Play again',
                    icon: Icons.replay,
                    tone: PrismButtonTone.filled,
                    expanded: true,
                    isLoading: s.busy,
                    onPressed: s.start,
                  ),
                ],
                if (r.status == 'finished' && !r.isHost)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Waiting for ${r.nameById(r.j['host'] as String?)} to start another round…',
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
              if (s.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    s.error!,
                    style: TextStyle(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 16),
              _Chat(session: s),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lobby(BuildContext context, RoomView r) {
    final enough = r.players.length >= r.game.minPlayers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          enough
              ? (r.isHost
                    ? 'Everyone here? Start when you\'re ready.'
                    : 'Waiting for the host to start…')
              : 'Share the code. Waiting for ${r.game.minPlayers - r.players.length} more player${r.game.minPlayers - r.players.length == 1 ? '' : 's'}…',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        if (r.isHost)
          PrismButton(
            label: 'Start game',
            icon: Icons.play_arrow,
            tone: PrismButtonTone.filled,
            enabled: enough,
            isLoading: s.busy,
            onPressed: s.start,
          ),
      ],
    );
  }

  Widget _statusLine(BuildContext context, RoomView r) {
    final theme = Theme.of(context);
    String text;
    if (r.status == 'finished') {
      final w = r.winners;
      text = w.isEmpty
          ? "It's a draw!"
          : (w.contains(r.seat)
                ? 'You win! 🎉'
                : '${w.map(r.nameOf).join(' & ')} wins!');
    } else if (r.game is RockPaperScissors) {
      final picks = (r.state?['picks'] as List?) ?? const [];
      text = r.seat >= 0 && r.seat < picks.length && picks[r.seat] != null
          ? 'Waiting for the other pick…'
          : 'Pick in secret';
    } else {
      text = r.myTurn ? 'Your turn' : '${r.nameOf(r.turn ?? -1)}\'s turn';
    }
    return Text(
      text,
      textAlign: TextAlign.center,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: r.myTurn ? theme.colorScheme.primary : null,
      ),
    );
  }

  Widget _board(RoomView r) => switch (r.game) {
    TicTacToe() => _GridBoard(
      room: r,
      cols: 3,
      rows: 3,
      onTap: (i) => s.move(i),
      marks: const ['✕', '◯'],
    ),
    ConnectFour() => _GridBoard(
      room: r,
      cols: ConnectFour.cols,
      rows: ConnectFour.rows,
      onTap: (i) => s.move(i % ConnectFour.cols),
      discs: true,
    ),
    RockPaperScissors() => _RpsBoard(room: r, onPick: s.move),
    WordChain() => _WordChainBoard(room: r, onWord: s.move),
    _ => const SizedBox.shrink(),
  };
}

class _GridBoard extends StatelessWidget {
  const _GridBoard({
    required this.room,
    required this.cols,
    required this.rows,
    required this.onTap,
    this.marks = const ['', ''],
    this.discs = false,
  });
  final RoomView room;
  final int cols, rows;
  final void Function(int) onTap;
  final List<String> marks;
  final bool discs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final board = [
      for (final c in (room.state?['board'] as List? ?? const []))
        (c as num).toInt(),
    ];
    final last = room.state?['last'] as int?;
    final colors = [theme.colorScheme.primary, Colors.amber.shade600];
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: discs ? 420 : 320),
        child: AspectRatio(
          aspectRatio: cols / rows,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: discs ? theme.colorScheme.primaryContainer : null,
              borderRadius: BorderRadius.circular(14),
            ),
            child: GridView.count(
              crossAxisCount: cols,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              children: [
                for (var i = 0; i < cols * rows; i++)
                  Semantics(
                    button: true,
                    label: board.length > i && board[i] >= 0
                        ? '${room.nameOf(board[i])}'
                        : 'Empty',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(discs ? 100 : 10),
                      onTap:
                          room.myTurn &&
                              board.length > i &&
                              (discs || board[i] == -1)
                          ? () => onTap(i)
                          : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          shape: discs ? BoxShape.circle : BoxShape.rectangle,
                          borderRadius: discs
                              ? null
                              : BorderRadius.circular(10),
                          color: discs
                              ? (board.length > i && board[i] >= 0
                                    ? colors[board[i] % 2]
                                    : theme.colorScheme.surface)
                              : theme.colorScheme.surfaceContainerHighest,
                          border: last == i
                              ? Border.all(
                                  color: theme.colorScheme.onSurface,
                                  width: 2,
                                )
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: discs || board.length <= i || board[i] < 0
                            ? null
                            : FittedBox(
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Text(
                                    marks[board[i] % 2],
                                    style: TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.w800,
                                      color: colors[board[i] % 2],
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RpsBoard extends StatelessWidget {
  const _RpsBoard({required this.room, required this.onPick});
  final RoomView room;
  final void Function(String) onPick;
  static const _e = {'rock': '✊', 'paper': '✋', 'scissors': '✌️'};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final st = room.state ?? const {};
    final score = (st['score'] as List? ?? const [0, 0]);
    final picks = (st['picks'] as List? ?? const [null, null]);
    final rounds = (st['rounds'] as List? ?? const []);
    final mine = room.seat >= 0 && room.seat < picks.length
        ? picks[room.seat] as String?
        : null;
    return Column(
      children: [
        Text(
          '${room.nameOf(0)} ${score[0]} – ${score[1]} ${room.nameOf(1)}',
          style: theme.textTheme.titleLarge,
        ),
        Text(
          'First to ${RockPaperScissors.target}',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final c in RockPaperScissors.choices)
              Padding(
                padding: const EdgeInsets.all(6),
                child: Material(
                  color: mine == c
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: room.status == 'playing' && mine == null
                        ? () => onPick(c)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        _e[c]!,
                        style: const TextStyle(fontSize: 34),
                        semanticsLabel: c,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (rounds.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final rd in rounds.reversed.take(4).cast<Map>())
            Text(
              '${_e[(rd['picks'] as List)[0]]}  vs  ${_e[(rd['picks'] as List)[1]]}  —  ${rd['winner'] == null ? 'tie' : '${room.nameOf((rd['winner'] as num).toInt())} takes it'}',
              style: theme.textTheme.bodyMedium,
            ),
        ],
      ],
    );
  }
}

class _WordChainBoard extends StatefulWidget {
  const _WordChainBoard({required this.room, required this.onWord});
  final RoomView room;
  final Future<void> Function(String) onWord;
  @override
  State<_WordChainBoard> createState() => _WordChainBoardState();
}

class _WordChainBoardState extends State<_WordChainBoard> {
  final _c = TextEditingController();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.room;
    final theme = Theme.of(context);
    final words = (r.state?['words'] as List? ?? const []).cast<Map>();
    final strikes = (r.state?['strikes'] as List? ?? const []);
    final lastOk = words.lastWhere(
      (w) => w['ok'] == true,
      orElse: () => const {},
    );
    final need = (lastOk['word'] as String?)?.characters.last;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < strikes.length; i++)
              Text(
                '${r.nameOf(i)} ${'✕' * (strikes[i] as num).toInt()}${(strikes[i] as num) >= 3 ? ' (out)' : ''}',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
        const SizedBox(height: 8),
        PrismSurface(
          padding: const EdgeInsets.all(12),
          child: words.isEmpty
              ? const Text('Any word to start!', textAlign: TextAlign.center)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final w in words.reversed.take(8))
                      Text(
                        '${r.nameOf((w['seat'] as num).toInt())}: ${w['word'] == '' ? '—' : w['word']}${w['ok'] == true ? '' : '  ✕ ${w['reason'] ?? ''}'}',
                        style: TextStyle(
                          color: w['ok'] == true
                              ? null
                              : theme.colorScheme.error,
                          decoration: w['ok'] == true
                              ? null
                              : TextDecoration.lineThrough,
                        ),
                      ),
                  ],
                ),
        ),
        if (r.myTurn) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: PrismTextField(
                  controller: _c,
                  autofocus: true,
                  hintText: need == null
                      ? 'Your word'
                      : 'A word starting with “$need”',
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              PrismButton(
                label: 'Play',
                tone: PrismButtonTone.filled,
                onPressed: _send,
              ),
            ],
          ),
          TextButton(
            onPressed: () => widget.onWord(''),
            child: const Text("Pass (costs a strike)"),
          ),
        ],
      ],
    );
  }

  void _send() {
    final w = _c.text.trim();
    if (w.isEmpty) return;
    _c.clear();
    widget.onWord(w);
  }
}

class _Chat extends StatefulWidget {
  const _Chat({required this.session});
  final RoomSession session;
  @override
  State<_Chat> createState() => _ChatState();
}

class _ChatState extends State<_Chat> {
  final _c = TextEditingController();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.session.room;
    final theme = Theme.of(context);
    return PrismSurface(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Room chat', style: theme.textTheme.labelLarge),
          for (final m in r.chat.reversed.take(6).toList().reversed)
            Text(
              '${r.nameById(m['from'] as String?)}: ${m['text']}',
              style: theme.textTheme.bodySmall,
            ),
          Row(
            children: [
              Expanded(
                child: PrismTextField(
                  controller: _c,
                  hintText: 'Say something',
                  onSubmitted: (_) => _send(),
                ),
              ),
              IconButton(
                tooltip: 'Send',
                icon: const Icon(Icons.send),
                onPressed: _send,
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            children: [
              for (final q in const [
                'gg! 🎉',
                'Rematch?',
                'Nice move 👀',
                'Hold on a sec',
              ])
                ActionChip(
                  label: Text(q),
                  onPressed: () => widget.session.say(q),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _send() {
    final t = _c.text.trim();
    if (t.isEmpty) return;
    _c.clear();
    widget.session.say(t);
  }
}
