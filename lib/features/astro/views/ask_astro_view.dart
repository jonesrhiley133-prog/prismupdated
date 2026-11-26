import 'package:prism_plurality/features/astro/content/ask.dart';
import 'package:prism_plurality/features/astro/content/horoscope.dart';
import 'package:prism_plurality/features/astro/data/astro_model.dart';
import 'package:prism_plurality/features/astro/views/astro_widgets.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

class _Msg {
  const _Msg(this.text, this.mine, {this.suggestions = const []});
  final String text;
  final bool mine;
  final List<String> suggestions;
}

/// Questions answered on this device from the alter's chart and Prism's
/// astrology library. The conversation isn't saved.
class AskAstroSection extends ConsumerStatefulWidget {
  const AskAstroSection({super.key, required this.access});
  final AstroAccess access;

  @override
  ConsumerState<AskAstroSection> createState() => _AskAstroSectionState();
}

class _AskAstroSectionState extends ConsumerState<AskAstroSection> {
  final _input = TextEditingController();
  final List<_Msg> _msgs = [];

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _ask(String q) {
    final text = q.trim();
    if (text.isEmpty) return;
    final es = astroEs(context);
    final a = widget.access;
    final others = <String, AstroSubject>{
      for (final x in ref.read(astroListedProvider))
        if (x.member.id != a.member.id && x.subject != null) x.name: x.subject!,
    };
    final answer = askAstro(
      text,
      a.subject,
      es,
      others: others,
      memberId: a.member.id,
    );
    setState(() {
      _msgs
        ..add(_Msg(text, true))
        ..add(_Msg(answer.text, false, suggestions: answer.suggestions));
      _input.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final es = astroEs(context);
    final theme = Theme.of(context);
    final a = widget.access;
    final accent = alterAccent(context, a);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AstroHero(
          accent: accent,
          child: Row(
            children: [
              Icon(
                PhosphorIcons.chatCircleText(PhosphorIconsStyle.fill),
                color: accent,
                size: 30,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(context, 'Ask Astro', 'Pregunta a Astro'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      es
                          ? 'Responde con la carta de ${a.name} y la biblioteca de astrología de Prism. Funciona en este dispositivo: no se envía nada a ningún servicio.'
                          : 'Answers using ${a.name}\'s chart and Prism\'s astrology library. Runs on this device — nothing is sent to any service.',
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_msgs.isEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in askExamples(es))
                PrismChip(label: s, selected: false, onTap: () => _ask(s)),
            ],
          ),
        for (final m in _msgs)
          Align(
            alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: m.mine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: m.mine
                          ? accent.withValues(alpha: 0.18)
                          : theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(m.mine ? 18 : 4),
                        bottomRight: Radius.circular(m.mine ? 4 : 18),
                      ),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    child: SelectableText(
                      m.text,
                      style: const TextStyle(height: 1.45),
                    ),
                  ),
                  if (m.suggestions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final s in m.suggestions)
                            PrismChip(
                              label: s,
                              selected: false,
                              onTap: () => _ask(s),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: PrismTextField(
                controller: _input,
                hintText: tr(
                  context,
                  'Ask about a sign, planet or this chart…',
                  'Pregunta por un signo, un planeta o esta carta…',
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: _ask,
              ),
            ),
            const SizedBox(width: 8),
            PrismIconButton(
              icon: PhosphorIcons.paperPlaneRight(PhosphorIconsStyle.fill),
              tooltip: tr(context, 'Send', 'Enviar'),
              onPressed: () => _ask(_input.text),
            ),
          ],
        ),
        const AstroDisclaimer(),
      ],
    );
  }
}
