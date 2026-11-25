import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart' show HapticFeedback;

import 'package:prism_plurality/features/cozy/data/cozy_data.dart';
import 'package:prism_plurality/features/games/content/prompt_bank.dart';
import 'package:prism_plurality/features/games/core/games_data.dart';
import 'package:prism_plurality/features/games/engines/ambience_synth.dart';
import 'package:prism_plurality/features/games/engines/tone_player.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

enum _Tool { breathe, sounds, ground, timer, jar, fidget }

class ComfortView extends StatefulWidget {
  const ComfortView({super.key});
  @override
  State<ComfortView> createState() => _ComfortViewState();
}

class _ComfortViewState extends State<ComfortView> {
  _Tool _tool = _Tool.breathe;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(
            context,
            'A quiet corner for hard moments or just slowing down. Nothing here is tracked.',
            'Un rincón tranquilo para momentos difíciles o para ir más despacio. Aquí no se registra nada.',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (t, l) in [
              (_Tool.breathe, tr(context, '🫧 Breathe', '🫧 Respirar')),
              (_Tool.sounds, tr(context, '🌧️ Sounds', '🌧️ Sonidos')),
              (_Tool.ground, tr(context, '🖐️ Grounding', '🖐️ Anclaje')),
              (_Tool.timer, tr(context, '⏳ Timer', '⏳ Temporizador')),
              (
                _Tool.jar,
                tr(context, '🫙 Message jar', '🫙 Tarro de mensajes'),
              ),
              (_Tool.fidget, tr(context, '🫧 Bubble pop', '🫧 Burbujas')),
            ])
              PrismChip(
                label: l,
                selected: _tool == t,
                onTap: () => setState(() => _tool = t),
              ),
          ],
        ),
        const SizedBox(height: 12),
        switch (_tool) {
          _Tool.breathe => const _Breathe(),
          _Tool.sounds => const _Sounds(),
          _Tool.ground => const _Grounding(),
          _Tool.timer => const _CalmTimer(),
          _Tool.jar => const _MessageJar(),
          _Tool.fidget => const _BubblePop(),
        },
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _Breathe extends StatefulWidget {
  const _Breathe();
  @override
  State<_Breathe> createState() => _BreatheState();
}

class _BreatheState extends State<_Breathe> {
  static const patterns = <String, List<(String, String, int)>>{
    'Box 4·4·4·4': [
      ('Breathe in', 'Inhala', 4),
      ('Hold', 'Mantén', 4),
      ('Breathe out', 'Exhala', 4),
      ('Hold', 'Mantén', 4),
    ],
    '4·7·8': [
      ('Breathe in', 'Inhala', 4),
      ('Hold', 'Mantén', 7),
      ('Breathe out', 'Exhala', 8),
    ],
    'Calm 4·6': [('Breathe in', 'Inhala', 4), ('Breathe out', 'Exhala', 6)],
    'Gentle 3·3': [('Breathe in', 'Inhala', 3), ('Breathe out', 'Exhala', 3)],
  };
  String _p = 'Calm 4·6';
  Timer? _t;
  int _step = 0, _left = 0, _cycles = 0;

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _start() {
    _t?.cancel();
    final steps = patterns[_p]!;
    setState(() {
      _step = 0;
      _left = steps[0].$3;
      _cycles = 0;
    });
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _left--;
        if (_left <= 0) {
          _step = (_step + 1) % steps.length;
          if (_step == 0) _cycles++;
          _left = steps[_step].$3;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final steps = patterns[_p]!;
    final running = _t?.isActive ?? false;
    final (en, es, secs) = steps[_step];
    final inhale = en == 'Breathe in';
    final exhale = en == 'Breathe out';
    final reduce = MediaQuery.of(context).disableAnimations;
    final scheme = Theme.of(context).colorScheme;
    final target = !running
        ? 0.6
        : (inhale ? 1.0 : (exhale ? 0.45 : (_step == 1 ? 1.0 : 0.45)));
    return PrismSurface(
      child: Column(
        children: [
          Wrap(
            spacing: 6,
            children: [
              for (final k in patterns.keys)
                PrismChip(
                  label: k,
                  selected: _p == k,
                  onTap: () => setState(() => _p = k),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: Center(
              child: AnimatedContainer(
                duration: reduce || !running
                    ? Duration.zero
                    : Duration(seconds: secs),
                curve: Curves.easeInOut,
                width: 220 * target,
                height: 220 * target,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      scheme.primary.withValues(alpha: 0.55),
                      scheme.primary.withValues(alpha: 0.12),
                    ],
                  ),
                ),
                alignment: Alignment.center,
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    running
                        ? '${tr(context, en, es)}\n$_left'
                        : tr(context, 'Ready', 'Listo'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (running)
            Text(
              tr(context, '$_cycles rounds', '$_cycles rondas'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 10),
          PrismButton(
            tone: PrismButtonTone.filled,
            label: running
                ? tr(context, 'Stop', 'Parar')
                : tr(context, 'Start', 'Empezar'),
            onPressed: () {
              if (running) {
                _t?.cancel();
                setState(() {});
              } else {
                _start();
              }
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _Sounds extends StatefulWidget {
  const _Sounds();
  @override
  State<_Sounds> createState() => _SoundsState();
}

class _SoundsState extends State<_Sounds> {
  final Map<String, TonePlayer> _players = {};
  final Map<String, double> _vol = {};

  @override
  void dispose() {
    for (final p in _players.values) {
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _toggle(String k) async {
    if (_players.containsKey(k)) {
      await _players.remove(k)!.stop();
      setState(() {});
      return;
    }
    final p = TonePlayer();
    _players[k] = p;
    setState(() {});
    await p.loop(k, volume: _vol[k] ?? 0.4);
  }

  Widget _row(BuildContext context, String k, String e, String en, String es) {
    return Row(
      children: [
        SizedBox(
          width: 190,
          child: PrismChip(
            label: '$e ${tr(context, en, es)}',
            selected: _players.containsKey(k),
            onTap: () => _toggle(k),
          ),
        ),
        Expanded(
          child: Slider(
            value: _vol[k] ?? 0.4,
            onChanged: (v) {
              setState(() => _vol[k] = v);
              _players[k]?.setVolume(v);
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PrismSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr(
              context,
              'Mix gentle sounds. They\'re made on your device and play alongside your music.',
              'Mezcla sonidos suaves. Se generan en tu dispositivo y suenan junto a tu música.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          for (final a in ambienceCatalog) ...[
            if (a == ambienceCatalog.first ||
                a.musical !=
                    ambienceCatalog[ambienceCatalog.indexOf(a) - 1].musical)
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 2),
                child: Text(
                  a.musical
                      ? tr(context, 'Peaceful music', 'Música tranquila')
                      : tr(context, 'Nature', 'Naturaleza'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            _row(context, a.id, a.emoji, a.label, a.labelEs),
          ],
          if (_players.isNotEmpty)
            PrismButton(
              label: tr(context, 'Stop all', 'Parar todo'),
              onPressed: () async {
                for (final p in _players.values) {
                  await p.stop();
                  p.dispose();
                }
                setState(_players.clear);
              },
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _Grounding extends StatefulWidget {
  const _Grounding();
  @override
  State<_Grounding> createState() => _GroundingState();
}

class _GroundingState extends State<_Grounding> {
  static const steps = [
    (5, '👀', 'things you can see', 'cosas que puedes ver'),
    (4, '✋', 'things you can touch', 'cosas que puedes tocar'),
    (3, '👂', 'things you can hear', 'cosas que puedes oír'),
    (2, '👃', 'things you can smell', 'cosas que puedes oler'),
    (1, '👅', 'thing you can taste', 'cosa que puedes saborear'),
  ];
  int _i = 0;
  int _ticks = 0;

  @override
  Widget build(BuildContext context) {
    if (_i >= steps.length) {
      return PrismSurface(
        child: Column(
          children: [
            const Text('🌿', style: TextStyle(fontSize: 44)),
            Text(
              tr(
                context,
                'You\'re here. You did that. 💛',
                'Estás aquí. Lo has hecho. 💛',
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            PrismButton(
              label: tr(context, 'Start again', 'Empezar de nuevo'),
              onPressed: () => setState(() {
                _i = 0;
                _ticks = 0;
              }),
            ),
          ],
        ),
      );
    }
    final (n, e, en, es) = steps[_i];
    return PrismSurface(
      child: Column(
        children: [
          Text(e, style: const TextStyle(fontSize: 44)),
          Text(
            '$n ${tr(context, en, es)}',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            tr(
              context,
              'Notice each one, then tap a dot.',
              'Fíjate en cada una y toca un punto.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            children: [
              for (var k = 0; k < n; k++)
                Semantics(
                  button: true,
                  label: '${k + 1}',
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _ticks = math.max(_ticks, k + 1);
                      if (_ticks >= n) {
                        _i++;
                        _ticks = 0;
                      }
                    }),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: k < _ticks
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                      ),
                    ),
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

class _CalmTimer extends StatefulWidget {
  const _CalmTimer();
  @override
  State<_CalmTimer> createState() => _CalmTimerState();
}

class _CalmTimerState extends State<_CalmTimer> {
  int _minutes = 5;
  int _left = 0;
  Timer? _t;
  final _tone = TonePlayer();

  @override
  void dispose() {
    _t?.cancel();
    _tone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final running = _t?.isActive ?? false;
    return PrismSurface(
      child: Column(
        children: [
          Text(
            tr(
              context,
              'Take a break. A soft chime plays at the end.',
              'Tómate un descanso. Al final suena un tono suave.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          if (!running)
            Wrap(
              spacing: 6,
              children: [
                for (final m in const [1, 3, 5, 10, 15, 20])
                  PrismChip(
                    label: '$m min',
                    selected: _minutes == m,
                    onTap: () => setState(() => _minutes = m),
                  ),
              ],
            ),
          if (running)
            Text(
              '${_left ~/ 60}:${(_left % 60).toString().padLeft(2, '0')}',
              style: Theme.of(
                context,
              ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w300),
            ),
          const SizedBox(height: 10),
          PrismButton(
            tone: PrismButtonTone.filled,
            label: running
                ? tr(context, 'Stop', 'Parar')
                : tr(context, 'Start', 'Empezar'),
            onPressed: () {
              if (running) {
                _t?.cancel();
                setState(() {});
                return;
              }
              setState(() => _left = _minutes * 60);
              _t = Timer.periodic(const Duration(seconds: 1), (t) {
                setState(() => _left--);
                if (_left <= 0) {
                  t.cancel();
                  _tone.play(TonePlayer.scale[4], ms: 900, volume: 0.5);
                  if (mounted)
                    PrismToast.show(
                      context,
                      message: tr(
                        context,
                        'Time\'s up — gently 🌿',
                        'Se acabó el tiempo, con calma 🌿',
                      ),
                    );
                }
              });
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _MessageJar extends ConsumerStatefulWidget {
  const _MessageJar();
  @override
  ConsumerState<_MessageJar> createState() => _MessageJarState();
}

class _MessageJarState extends ConsumerState<_MessageJar> {
  String? _drawn;
  String? _from;
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(comfortProvider);
    final names = ref.watch(gameNamesProvider);
    return PrismSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr(
              context,
              'Comforting messages from alters to whoever needs them, plus a few from Prism.',
              'Mensajes reconfortantes de los alters para quien los necesite, y algunos de Prism.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          if (_drawn != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text(
                    _drawn!,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(height: 1.35),
                  ),
                  if (_from != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '— ${names[_from] ?? ''}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          PrismButton(
            tone: PrismButtonTone.filled,
            icon: PhosphorIcons.handGrabbing(),
            label: tr(context, 'Take a message', 'Sacar un mensaje'),
            onPressed: () {
              final pool = [
                for (final r in mine) (r.title, r.memberId),
                for (final a in affirmations) (a, null),
              ];
              final pick = pool[math.Random().nextInt(pool.length)];
              setState(() {
                _drawn = pick.$1;
                _from = pick.$2;
              });
            },
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: PrismTextField(
                  controller: _ctl,
                  hintText: tr(
                    context,
                    'Leave a kind message for someone who needs it',
                    'Deja un mensaje amable para quien lo necesite',
                  ),
                ),
              ),
              PrismIconButton(
                icon: PhosphorIcons.plus(),
                tooltip: tr(context, 'Add', 'Añadir'),
                onPressed: () async {
                  final t = _ctl.text.trim();
                  if (t.isEmpty) return;
                  await ref
                      .read(trackerNotifierProvider.notifier)
                      .create(
                        kind: TrackerKind.cozyComfort,
                        title: t,
                        memberId: ref.read(cozyMeProvider),
                        fields: const {'type': 'message'},
                      );
                  _ctl.clear();
                  if (context.mounted)
                    PrismToast.show(
                      context,
                      message: tr(
                        context,
                        'Added to the jar 💛',
                        'Añadido al tarro 💛',
                      ),
                    );
                },
              ),
            ],
          ),
          Text(
            tr(
              context,
              '${mine.length} messages from the system',
              '${mine.length} mensajes del sistema',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _BubblePop extends StatefulWidget {
  const _BubblePop();
  @override
  State<_BubblePop> createState() => _BubblePopState();
}

class _BubblePopState extends State<_BubblePop> {
  final Set<int> _popped = {};
  final _tone = TonePlayer();
  bool _sound = true;

  @override
  void dispose() {
    _tone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PrismSurface(
      child: Column(
        children: [
          GridView.count(
            crossAxisCount: 6,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (var i = 0; i < 36; i++)
                Semantics(
                  button: true,
                  label: _popped.contains(i)
                      ? tr(context, 'popped', 'explotada')
                      : tr(context, 'bubble', 'burbuja'),
                  child: GestureDetector(
                    onTap: _popped.contains(i)
                        ? null
                        : () {
                            HapticFeedback.lightImpact();
                            if (_sound)
                              _tone.play(
                                TonePlayer.scale[i % TonePlayer.scale.length],
                                ms: 120,
                                volume: 0.35,
                              );
                            setState(() => _popped.add(i));
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _popped.contains(i)
                            ? scheme.surfaceContainerHighest.withValues(
                                alpha: 0.4,
                              )
                            : scheme.primary.withValues(alpha: 0.25),
                        border: Border.all(
                          color: scheme.primary.withValues(
                            alpha: _popped.contains(i) ? 0.1 : 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PrismChip(
                label: tr(context, '🔈 Sound', '🔈 Sonido'),
                selected: _sound,
                onTap: () => setState(() => _sound = !_sound),
              ),
              const SizedBox(width: 8),
              PrismButton(
                label: tr(context, 'New sheet', 'Nueva hoja'),
                onPressed: () => setState(_popped.clear),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
