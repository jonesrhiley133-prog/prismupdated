import 'package:prism_plurality/features/games/core/game_catalog.dart';
import 'package:prism_plurality/features/games/core/game_kit.dart';
import 'package:prism_plurality/features/games/core/games_data.dart';
import 'package:prism_plurality/features/games/views/games_hub_screen.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// A custom-game template: what it's called, which engine plays it and how
/// its content is edited.
class CustomTemplate {
  const CustomTemplate(this.type, this.base, this.emoji, this.name, this.desc, this.editor, {this.aLabel, this.bLabel});
  final String type;
  final String base;
  final String emoji;
  final (String, String) name;
  final (String, String) desc;

  /// questions | pairs | lines | personality
  final String editor;
  final (String, String)? aLabel;
  final (String, String)? bLabel;
}

const customTemplates = [
  CustomTemplate(
    'trivia',
    'trivia_general',
    '🧠',
    ('Trivia quiz', 'Quiz de trivia'),
    ('Your own questions with right and wrong answers.', 'Tus preguntas con respuestas correctas e incorrectas.'),
    'questions',
  ),
  CustomTemplate('friendship', 'who_knows_me', '💞', ('Friendship quiz', 'Quiz de amistad'), ('"How well do you know me?" questions.', 'Preguntas de "¿cuánto me conoces?".'), 'questions'),
  CustomTemplate(
    'choice',
    'would_you_rather',
    '🤔',
    ('Would You Rather / This or That', '¿Qué prefieres? / Esto o aquello'),
    ('Pairs of options to choose between.', 'Parejas de opciones para elegir.'),
    'pairs',
    aLabel: ('Option A', 'Opción A'),
    bLabel: ('Option B', 'Opción B'),
  ),
  CustomTemplate('wordsearch', 'word_search', '🔎', ('Word search', 'Sopa de letras'), ('Your own word list (3–10 letters each).', 'Tu lista de palabras (3–10 letras).'), 'lines'),
  CustomTemplate(
    'crossword',
    'mini_crossword',
    '✏️',
    ('Crossword', 'Crucigrama'),
    ('Answers and clues; Prism lays out the grid.', 'Respuestas y pistas; Prism crea la cuadrícula.'),
    'pairs',
    aLabel: ('Answer', 'Respuesta'),
    bLabel: ('Clue', 'Pista'),
  ),
  CustomTemplate('bingo', 'friendship_bingo', '🎯', ('Bingo board', 'Cartón de bingo'), ('Squares for a bingo card (up to 24).', 'Casillas para un cartón (hasta 24).'), 'lines'),
  CustomTemplate(
    'memory',
    'memory_match',
    '🃏',
    ('Memory card set', 'Juego de memoria'),
    ('Pairs of cards that match each other.', 'Parejas de cartas que se emparejan.'),
    'pairs',
    aLabel: ('Card', 'Carta'),
    bLabel: ('Its match', 'Su pareja'),
  ),
  CustomTemplate('deck', 'conversation_roulette', '🎴', ('Prompt deck', 'Baraja de preguntas'), ('Question or prompt cards to draw.', 'Cartas de preguntas o ideas.'), 'lines'),
  CustomTemplate(
    'flashcards',
    'synonym_match',
    '📇',
    ('Flashcards', 'Tarjetas de estudio'),
    ('Terms and meanings to match.', 'Términos y significados para unir.'),
    'pairs',
    aLabel: ('Term', 'Término'),
    bLabel: ('Meaning', 'Significado'),
  ),
  CustomTemplate(
    'personality',
    'trivia_general',
    '🪞',
    ('Personality quiz', 'Test de personalidad'),
    ('"Which … are you?" — answers lead to results.', '"¿Qué … eres?": las respuestas llevan a resultados.'),
    'personality',
  ),
];

CustomTemplate templateFor(String type) => customTemplates.firstWhere((t) => t.type == type, orElse: () => customTemplates.first);

/// The Create tab: custom games list and templates.
class CustomGamesView extends ConsumerWidget {
  const CustomGamesView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final games = ref.watch(customGamesProvider);
    final names = ref.watch(gameNamesProvider);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(
            context,
            'Make your own games and share them with the system. Anyone can play them, and you can challenge other alters with them.',
            'Crea tus propios juegos y compártelos con el sistema. Cualquiera puede jugarlos y puedes retar a otros alters.',
          ),
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        PrismSectionHeader(title: tr(context, 'YOUR GAMES', 'TUS JUEGOS')),
        if (games.isEmpty)
          EmptyState(
            icon: Icon(PhosphorIcons.magicWand()),
            title: tr(context, 'No custom games yet', 'Aún no hay juegos personalizados'),
            subtitle: tr(context, 'Pick a template below to start.', 'Elige una plantilla abajo para empezar.'),
          )
        else
          PrismSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final g in games)
                  PrismListRow(
                    leading: Text(templateFor(g.type).emoji, style: const TextStyle(fontSize: 24)),
                    title: Text(g.title.isEmpty ? trp(context, templateFor(g.type).name) : g.title),
                    subtitle: Text('${trp(context, templateFor(g.type).name)}${g.creator == null ? '' : ' · ${tr(context, 'by', 'de')} ${names[g.creator] ?? '?'}'}'),
                    onTap: () => openGame(context, g.base, custom: g.r.id),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PrismIconButton(
                          icon: PhosphorIcons.pencilSimple(),
                          tooltip: tr(context, 'Edit', 'Editar'),
                          onPressed: () => openCustomEditor(context, template: templateFor(g.type), existing: g),
                        ),
                        PrismIconButton(icon: PhosphorIcons.trash(), tooltip: tr(context, 'Delete', 'Eliminar'), onPressed: () => ref.read(trackerNotifierProvider.notifier).delete(g.r.id)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        PrismSectionHeader(title: tr(context, 'TEMPLATES', 'PLANTILLAS')),
        PrismSurface(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final t in customTemplates)
                PrismListRow(
                  leading: Text(t.emoji, style: const TextStyle(fontSize: 24)),
                  title: Text(trp(context, t.name)),
                  subtitle: Text(trp(context, t.desc)),
                  showChevron: true,
                  onTap: () => openCustomEditor(context, template: t),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

void openCustomEditor(BuildContext context, {required CustomTemplate template, CustomGame? existing}) => Navigator.of(context, rootNavigator: true).push(
  MaterialPageRoute<void>(
    builder: (_) => CustomGameEditor(template: template, existing: existing),
  ),
);

class CustomGameEditor extends ConsumerStatefulWidget {
  const CustomGameEditor({super.key, required this.template, this.existing});
  final CustomTemplate template;
  final CustomGame? existing;
  @override
  ConsumerState<CustomGameEditor> createState() => _CustomGameEditorState();
}

class _QRow {
  _QRow({String q = '', List<String> opts = const ['', '', '', ''], String explain = ''})
    : q = TextEditingController(text: q),
      opts = [for (var i = 0; i < 4; i++) TextEditingController(text: i < opts.length ? opts[i] : '')],
      explain = TextEditingController(text: explain);
  final TextEditingController q;
  final List<TextEditingController> opts;
  final TextEditingController explain;
  void dispose() {
    q.dispose();
    explain.dispose();
    for (final o in opts) {
      o.dispose();
    }
  }
}

class _PRow {
  _PRow([String a = '', String b = '']) : a = TextEditingController(text: a), b = TextEditingController(text: b);
  final TextEditingController a, b;
  void dispose() {
    a.dispose();
    b.dispose();
  }
}

class _PersQ {
  _PersQ({String q = '', List<(String, int)> opts = const []}) : q = TextEditingController(text: q), opts = [for (final (t, r) in opts) (TextEditingController(text: t), r)];
  final TextEditingController q;
  final List<(TextEditingController, int)> opts;
  void dispose() {
    q.dispose();
    for (final o in opts) {
      o.$1.dispose();
    }
  }
}

class _CustomGameEditorState extends ConsumerState<CustomGameEditor> {
  late final Map<String, Object?> _c = widget.existing?.content ?? const {};
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final List<_QRow> _qs = [
    for (final v in (_c['questions'] as List?) ?? const [])
      if (v is Map && widget.template.editor == 'questions') _QRow(q: '${v['q']}', opts: [for (final o in (v['options'] as List?) ?? const []) '$o'], explain: '${v['explain'] ?? ''}'),
  ];
  late final List<_PRow> _pairs = [
    for (final v in (_c['pairs'] as List?) ?? (_c['clues'] as List?) ?? const [])
      if (v is Map) _PRow('${v['a']}', '${v['b']}'),
  ];
  late final _lines = TextEditingController(text: [for (final v in (_c['words'] as List?) ?? (_c['squares'] as List?) ?? (_c['prompts'] as List?) ?? const []) '$v'].join('\n'));
  late final _results = TextEditingController(text: [for (final v in (_c['results'] as List?) ?? const []) '$v'].join('\n'));
  late final List<_PersQ> _pq = [
    for (final v in (_c['questions'] as List?) ?? const [])
      if (v is Map && widget.template.editor == 'personality')
        _PersQ(
          q: '${v['q']}',
          opts: [
            for (final o in (v['options'] as List?) ?? const [])
              if (o is Map) ('${o['t']}', (o['r'] as num?)?.toInt() ?? 0),
          ],
        ),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.template.editor == 'questions' && _qs.isEmpty) _qs.add(_QRow());
    if (widget.template.editor == 'pairs' && _pairs.isEmpty) _pairs.addAll([_PRow(), _PRow(), _PRow()]);
    if (widget.template.editor == 'personality' && _pq.isEmpty) _pq.add(_PersQ(opts: [('', 0), ('', 1)]));
  }

  @override
  void dispose() {
    _title.dispose();
    _lines.dispose();
    _results.dispose();
    for (final q in _qs) {
      q.dispose();
    }
    for (final p in _pairs) {
      p.dispose();
    }
    for (final p in _pq) {
      p.dispose();
    }
    super.dispose();
  }

  List<String> get _lineList => _lines.text.split('\n').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();

  Map<String, Object?> _content() {
    final t = widget.template;
    final pairs = [
      for (final p in _pairs)
        if (p.a.text.trim().isNotEmpty && p.b.text.trim().isNotEmpty) {'a': p.a.text.trim(), 'b': p.b.text.trim()},
    ];
    return switch (t.editor) {
      'questions' => {
        'type': t.type,
        'questions': [
          for (final q in _qs)
            if (q.q.text.trim().isNotEmpty && q.opts[0].text.trim().isNotEmpty && q.opts.skip(1).any((o) => o.text.trim().isNotEmpty))
              {
                'q': q.q.text.trim(),
                'options': [
                  for (final o in q.opts)
                    if (o.text.trim().isNotEmpty) o.text.trim(),
                ],
                'explain': q.explain.text.trim(),
              },
        ],
      },
      'pairs' => {'type': t.type, if (t.type == 'crossword') 'clues': pairs else 'pairs': pairs},
      'lines' => {
        'type': t.type,
        switch (t.type) {
          'wordsearch' => 'words',
          'bingo' => 'squares',
          _ => 'prompts',
        }: _lineList,
      },
      _ => {
        'type': t.type,
        'results': _results.text.split('\n').map((x) => x.trim()).where((x) => x.isNotEmpty).toList(),
        'questions': [
          for (final q in _pq)
            if (q.q.text.trim().isNotEmpty)
              {
                'q': q.q.text.trim(),
                'options': [
                  for (final (c, r) in q.opts)
                    if (c.text.trim().isNotEmpty) {'t': c.text.trim(), 'r': r},
                ],
              },
        ],
      },
    };
  }

  Future<void> _save() async {
    final t = widget.template;
    final fields = {'base': t.base, 'content': _content()};
    final title = _title.text.trim().isEmpty ? trp(context, t.name) : _title.text.trim();
    final n = ref.read(trackerNotifierProvider.notifier);
    if (widget.existing == null) {
      await n.create(kind: TrackerKind.gameCustom, title: title, memberId: ref.read(gamePlayerDefaultProvider), fields: fields);
    } else {
      await n.save(widget.existing!.r.copyWith(title: title).withFields(fields));
    }
    if (mounted) {
      PrismToast.show(context, message: tr(context, 'Saved — find it under Create', 'Guardado: está en Crear'));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.template;
    final theme = Theme.of(context);
    final results = _results.text.split('\n').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: '${t.emoji} ${trp(context, t.name)}',
        actions: [PrismTopBarAction(icon: PhosphorIcons.check(), tooltip: tr(context, 'Save', 'Guardar'), onPressed: _save)],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + NavBarInset.of(context)),
          children: [
            PrismTextField(controller: _title, labelText: tr(context, 'Name', 'Nombre'), hintText: trp(context, t.name)),
            const SizedBox(height: 6),
            Text(trp(context, t.desc), style: theme.textTheme.bodySmall),
            if (t.editor == 'questions') ...[
              for (var i = 0; i < _qs.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: PrismSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(tr(context, 'Question ${i + 1}', 'Pregunta ${i + 1}'), style: theme.textTheme.titleSmall)),
                            PrismIconButton(icon: PhosphorIcons.trash(), tooltip: tr(context, 'Remove', 'Quitar'), onPressed: () => setState(() => _qs.removeAt(i).dispose())),
                          ],
                        ),
                        PrismTextField(controller: _qs[i].q, hintText: tr(context, 'Question', 'Pregunta'), maxLines: 2),
                        const SizedBox(height: 6),
                        PrismTextField(controller: _qs[i].opts[0], hintText: tr(context, '✓ Correct answer', '✓ Respuesta correcta')),
                        for (var k = 1; k < 4; k++)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: PrismTextField(
                              controller: _qs[i].opts[k],
                              hintText: tr(context, '✗ Wrong answer ${k == 1 ? '' : '(optional)'}', '✗ Respuesta incorrecta ${k == 1 ? '' : '(opcional)'}'),
                            ),
                          ),
                        const SizedBox(height: 6),
                        PrismTextField(controller: _qs[i].explain, hintText: tr(context, 'Explanation shown after (optional)', 'Explicación (opcional)')),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              PrismButton(icon: PhosphorIcons.plus(), label: tr(context, 'Add question', 'Añadir pregunta'), onPressed: () => setState(() => _qs.add(_QRow()))),
            ],
            if (t.editor == 'pairs') ...[
              const SizedBox(height: 12),
              for (var i = 0; i < _pairs.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: PrismTextField(controller: _pairs[i].a, hintText: trp(context, t.aLabel ?? ('A', 'A'))),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: PrismTextField(controller: _pairs[i].b, hintText: trp(context, t.bLabel ?? ('B', 'B'))),
                      ),
                      PrismIconButton(icon: PhosphorIcons.x(), tooltip: tr(context, 'Remove', 'Quitar'), onPressed: () => setState(() => _pairs.removeAt(i).dispose())),
                    ],
                  ),
                ),
              PrismButton(icon: PhosphorIcons.plus(), label: tr(context, 'Add pair', 'Añadir pareja'), onPressed: () => setState(() => _pairs.add(_PRow()))),
            ],
            if (t.editor == 'lines') ...[
              const SizedBox(height: 12),
              PrismTextField(controller: _lines, maxLines: 14, minLines: 8, hintText: tr(context, 'One per line', 'Uno por línea'), onChanged: (_) => setState(() {})),
              const SizedBox(height: 4),
              Text(tr(context, '${_lineList.length} entries', '${_lineList.length} entradas'), style: theme.textTheme.bodySmall),
            ],
            if (t.editor == 'personality') ...[
              PrismSectionHeader(title: tr(context, 'RESULTS (ONE PER LINE)', 'RESULTADOS (UNO POR LÍNEA)')),
              PrismTextField(
                controller: _results,
                maxLines: 6,
                minLines: 3,
                hintText: tr(context, 'e.g. A cozy cat\nA wise owl\nA playful otter', 'p. ej. Un gato hogareño\nUn búho sabio\nUna nutria juguetona'),
                onChanged: (_) => setState(() {}),
              ),
              PrismSectionHeader(title: tr(context, 'QUESTIONS', 'PREGUNTAS')),
              for (var i = 0; i < _pq.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PrismSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: PrismTextField(controller: _pq[i].q, hintText: tr(context, 'Question ${i + 1}', 'Pregunta ${i + 1}')),
                            ),
                            PrismIconButton(icon: PhosphorIcons.trash(), tooltip: tr(context, 'Remove', 'Quitar'), onPressed: () => setState(() => _pq.removeAt(i).dispose())),
                          ],
                        ),
                        for (var k = 0; k < _pq[i].opts.length; k++) ...[
                          const SizedBox(height: 6),
                          PrismTextField(controller: _pq[i].opts[k].$1, hintText: tr(context, 'Answer', 'Respuesta')),
                          if (results.isNotEmpty)
                            Wrap(
                              spacing: 4,
                              children: [
                                Text('→ ', style: theme.textTheme.labelMedium),
                                for (var r = 0; r < results.length; r++)
                                  PrismChip(label: results[r], selected: _pq[i].opts[k].$2 == r, onTap: () => setState(() => _pq[i].opts[k] = (_pq[i].opts[k].$1, r))),
                              ],
                            ),
                        ],
                        PrismButton(
                          density: PrismControlDensity.compact,
                          icon: PhosphorIcons.plus(),
                          label: tr(context, 'Add answer', 'Añadir respuesta'),
                          onPressed: () => setState(() => _pq[i].opts.add((TextEditingController(), 0))),
                        ),
                      ],
                    ),
                  ),
                ),
              PrismButton(
                icon: PhosphorIcons.plus(),
                label: tr(context, 'Add question', 'Añadir pregunta'),
                onPressed: () => setState(() => _pq.add(_PersQ(opts: [('', 0), ('', 1)]))),
              ),
            ],
            const SizedBox(height: 20),
            PrismButton(tone: PrismButtonTone.filled, expanded: true, label: tr(context, 'Save game', 'Guardar juego'), onPressed: _save),
            const SizedBox(height: 6),
            Text(
              tr(context, 'Plays with: ${trp(context, gameById(t.base)?.name ?? (t.base, t.base))}', 'Se juega con: ${trp(context, gameById(t.base)?.name ?? (t.base, t.base))}'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
