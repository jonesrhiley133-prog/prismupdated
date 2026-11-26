import 'dart:math' as math;

import 'package:intl/intl.dart' show DateFormat;

import 'package:prism_plurality/features/astro/content/tarot.dart';
import 'package:prism_plurality/features/astro/data/astro_model.dart';
import 'package:prism_plurality/features/astro/views/astro_widgets.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

Color _suitColor(BuildContext context, TarotCard c) {
  final s = Theme.of(context).colorScheme;
  return switch (c.suit) {
    null => s.primary,
    Suit.wands => s.tertiary,
    Suit.cups => s.secondary,
    Suit.swords => s.onSurfaceVariant,
    Suit.pentacles => Color.lerp(s.tertiary, s.primary, 0.5)!,
  };
}

/// A card face drawn with theme colours.
class TarotCardTile extends StatelessWidget {
  const TarotCardTile({
    super.key,
    required this.drawn,
    this.width = 120,
    this.onTap,
    this.faceDown = false,
  });
  final DrawnCard drawn;
  final double width;
  final VoidCallback? onTap;
  final bool faceDown;

  @override
  Widget build(BuildContext context) {
    final es = astroEs(context);
    final theme = Theme.of(context);
    final c = drawn.card;
    final color = _suitColor(context, c);
    final h = width / 0.62;
    return Semantics(
      button: onTap != null,
      label: faceDown
          ? tr(context, 'Face-down card', 'Carta boca abajo')
          : '${c.name.of(es)}${drawn.reversed ? (es ? ', invertida' : ', reversed') : ''}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: width,
          height: h,
          decoration: BoxDecoration(
            borderRadius: prismCorners(context, width * 0.1),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.26),
                theme.colorScheme.surfaceContainerHigh,
                color.withValues(alpha: 0.12),
              ],
            ),
            border: Border.all(
              color: color.withValues(alpha: 0.55),
              width: 1.4,
            ),
          ),
          child: ClipRRect(
            borderRadius: prismCorners(context, width * 0.1),
            child: Stack(
              children: [
                Positioned.fill(
                  child: StarField(
                    count: 18,
                    seed: c.id.hashCode,
                    color: color,
                  ),
                ),
                if (faceDown)
                  Center(
                    child: Text(
                      '✦',
                      style: TextStyle(fontSize: width * 0.35, color: color),
                    ),
                  )
                else
                  Padding(
                    padding: EdgeInsets.all(width * 0.08),
                    child: Column(
                      children: [
                        Text(
                          c.major
                              ? (es ? 'ARCANO MAYOR' : 'MAJOR ARCANA')
                              : c.suit!.title.of(es).toUpperCase(),
                          style: TextStyle(
                            fontSize: width * 0.065,
                            letterSpacing: 1,
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Transform.rotate(
                          angle: drawn.reversed ? math.pi : 0,
                          child: Text(
                            c.symbol(),
                            style: TextStyle(
                              fontSize: c.major ? width * 0.3 : width * 0.32,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          c.name.of(es),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: TextStyle(
                            fontSize: width * 0.095,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
                        ),
                        if (drawn.reversed)
                          Text(
                            es ? 'invertida' : 'reversed',
                            style: TextStyle(
                              fontSize: width * 0.075,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
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

Future<void> showCardDetail(
  BuildContext context,
  DrawnCard d, {
  String? position,
}) => PrismSheet.show(
  context: context,
  title: d.card.name.of(astroEs(context)),
  maxHeightFactor: 0.9,
  builder: (context) {
    final es = astroEs(context);
    final theme = Theme.of(context);
    final c = d.card;
    final keys = d.reversed ? c.reversed : c.upright;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Center(child: TarotCardTile(drawn: d, width: 130)),
        const SizedBox(height: 12),
        if (position != null)
          Text(
            position,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        Text(
          d.reversed
              ? tr(context, 'Reversed', 'Invertida')
              : tr(context, 'Upright', 'Derecha'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        AstroCard(
          title: tr(context, 'Traditional meaning', 'Significado tradicional'),
          emoji: '📜',
          child: Text(
            '${c.meaningOf(d.reversed, es)}\n\n${tr(context, 'Keywords', 'Palabras clave')}: ${keys.of(es)}',
            style: const TextStyle(height: 1.45),
          ),
        ),
        const SizedBox(height: 10),
        AstroCard(
          title: tr(context, 'Relationships', 'Relaciones'),
          emoji: '❤️',
          child: Text(
            c.loveOf(d.reversed, es),
            style: const TextStyle(height: 1.45),
          ),
        ),
        const SizedBox(height: 10),
        AstroCard(
          title: tr(context, 'Personal growth', 'Crecimiento personal'),
          emoji: '🌱',
          child: Text(
            c.growthOf(d.reversed, es),
            style: const TextStyle(height: 1.45),
          ),
        ),
        const SizedBox(height: 10),
        AstroCard(
          title: tr(context, 'Reflection', 'Reflexión'),
          emoji: '🪞',
          child: Text(
            es
                ? '¿Dónde aparece hoy "${keys.es}" en tu vida?'
                : 'Where does "${keys.en}" show up in your life today?',
            style: const TextStyle(height: 1.45, fontStyle: FontStyle.italic),
          ),
        ),
        const AstroDisclaimer(tarot: true),
      ],
    );
  },
);

class TarotSection extends ConsumerStatefulWidget {
  const TarotSection({super.key, required this.access});
  final AstroAccess access;

  @override
  ConsumerState<TarotSection> createState() => _TarotSectionState();
}

class _TarotSectionState extends ConsumerState<TarotSection> {
  bool _dailyRevealed = false;
  Spread _spread = spreads.firstWhere((s) => s.id == 'three');
  List<DrawnCard>? _drawn;
  int _revealed = 0;
  final _question = TextEditingController();
  final _notes = TextEditingController();
  bool _saved = false;

  @override
  void dispose() {
    _question.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _draw() {
    setState(() {
      _drawn = drawCards(_spread.positions.length);
      _revealed = 0;
      _saved = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final es = astroEs(context);
    final theme = Theme.of(context);
    final a = widget.access;
    final daily = dailyCard(a.member.id, DateTime.now());
    final history = ref.watch(tarotReadingsProvider(a.member.id));
    final canSave =
        a.isOwner ||
        a.visibility == AstroVisibility.system ||
        a.visibility == AstroVisibility.shareable;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AstroHero(
          accent: alterAccent(context, a),
          child: Row(
            children: [
              TarotCardTile(
                drawn: daily,
                width: 104,
                faceDown: !_dailyRevealed,
                onTap: () => _dailyRevealed
                    ? showCardDetail(context, daily)
                    : setState(() => _dailyRevealed = true),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(context, 'TODAY\'S CARD', 'CARTA DEL DÍA'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (!_dailyRevealed) ...[
                      Text(
                        tr(
                          context,
                          'Tap the card to turn it over.',
                          'Toca la carta para darle la vuelta.',
                        ),
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr(
                          context,
                          'It stays the same all day.',
                          'Será la misma todo el día.',
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                    ] else ...[
                      Text(
                        daily.card.name.of(es),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        daily.reversed
                            ? tr(context, 'Reversed', 'Invertida')
                            : tr(context, 'Upright', 'Derecha'),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        daily.card.meaningOf(daily.reversed, es),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                      ),
                      const SizedBox(height: 8),
                      PrismButton(
                        density: PrismControlDensity.compact,
                        onPressed: () => showCardDetail(context, daily),
                        label: tr(context, 'Full reading', 'Lectura completa'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        PrismSectionHeader(title: tr(context, 'SPREADS', 'TIRADAS')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in spreads)
              PrismChip(
                label: '${s.name.of(es)} · ${s.positions.length}',
                selected: _spread.id == s.id,
                onTap: () => setState(() {
                  _spread = s;
                  _drawn = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 12),
        PrismTextField(
          controller: _question,
          labelText: tr(
            context,
            'Your question (optional)',
            'Tu pregunta (opcional)',
          ),
        ),
        const SizedBox(height: 12),
        PrismButton(
          label: _drawn == null
              ? tr(
                  context,
                  'Draw ${_spread.positions.length} cards',
                  'Sacar ${_spread.positions.length} cartas',
                )
              : tr(context, 'Draw again', 'Volver a sacar'),
          icon: PhosphorIcons.sparkle(),
          tone: PrismButtonTone.filled,
          onPressed: _draw,
        ),
        if (_drawn != null) ...[
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 14,
            children: [
              for (final (i, d) in _drawn!.indexed)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_spread.positions[i].emoji} ${_spread.positions[i].label.of(es)}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TarotCardTile(
                      drawn: d,
                      width: 96,
                      faceDown: i >= _revealed,
                      onTap: () => i >= _revealed
                          ? setState(
                              () => _revealed = math.max(_revealed, i + 1),
                            )
                          : showCardDetail(
                              context,
                              d,
                              position: _spread.positions[i].label.of(es),
                            ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_revealed < _drawn!.length)
            Center(
              child: PrismButton(
                density: PrismControlDensity.compact,
                onPressed: () => setState(() => _revealed = _drawn!.length),
                label: tr(context, 'Reveal all', 'Mostrar todas'),
              ),
            )
          else ...[
            const SizedBox(height: 8),
            PrismTextField(
              controller: _notes,
              labelText: tr(
                context,
                'Notes or reflection',
                'Notas o reflexión',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 10),
            PrismButton(
              label: _saved
                  ? tr(context, 'Saved', 'Guardada')
                  : tr(context, 'Save reading', 'Guardar tirada'),
              icon: _saved
                  ? PhosphorIcons.check()
                  : PhosphorIcons.bookmarkSimple(),
              enabled: !_saved && canSave,
              onPressed: () async {
                await ref
                    .read(astroActionsProvider)
                    .saveTarot(
                      memberId: a.member.id,
                      spread: _spread,
                      cards: _drawn!,
                      question: _question.text.trim(),
                      notes: _notes.text.trim(),
                      private:
                          a.visibility == AstroVisibility.private ||
                          a.visibility == AstroVisibility.hidden,
                    );
                if (mounted) setState(() => _saved = true);
              },
            ),
          ],
        ],
        if (history.isNotEmpty) ...[
          PrismSectionHeader(
            title: tr(context, 'SAVED READINGS', 'TIRADAS GUARDADAS'),
          ),
          PrismSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final r in history.take(20))
                  PrismListRow(
                    title: Text(
                      r.question.isEmpty ? r.spread.name.of(es) : r.question,
                    ),
                    subtitle: Text(
                      '${DateFormat.yMMMd(context.dateLocale).format(r.when)} · ${r.cards.map((c) => c.card.name.of(es)).join(', ')}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    showChevron: true,
                    onTap: () => PrismSheet.show(
                      context: context,
                      title: r.spread.name.of(es),
                      maxHeightFactor: 0.9,
                      builder: (ctx) => ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        children: [
                          if (r.question.isNotEmpty)
                            Text(
                              r.question,
                              style: Theme.of(ctx).textTheme.titleSmall,
                            ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 12,
                            alignment: WrapAlignment.center,
                            children: [
                              for (final (i, d) in r.cards.indexed)
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (i < r.spread.positions.length)
                                      Text(
                                        r.spread.positions[i].label.of(es),
                                        style: Theme.of(
                                          ctx,
                                        ).textTheme.labelSmall,
                                      ),
                                    TarotCardTile(
                                      drawn: d,
                                      width: 84,
                                      onTap: () => showCardDetail(
                                        ctx,
                                        d,
                                        position: i < r.spread.positions.length
                                            ? r.spread.positions[i].label.of(es)
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          if (r.notes.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            AstroCard(child: Text(r.notes)),
                          ],
                          const SizedBox(height: 12),
                          if (a.isOwner)
                            PrismButton(
                              label: tr(
                                ctx,
                                'Delete reading',
                                'Eliminar tirada',
                              ),
                              tone: PrismButtonTone.destructive,
                              icon: PhosphorIcons.trash(),
                              onPressed: () async {
                                await ref
                                    .read(astroActionsProvider)
                                    .delete(r.record);
                                if (ctx.mounted) Navigator.of(ctx).pop();
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const AstroDisclaimer(tarot: true),
      ],
    );
  }
}
