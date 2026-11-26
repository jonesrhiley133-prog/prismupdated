import 'package:share_plus/share_plus.dart';

import 'package:prism_plurality/features/settings/views/feature_data_screen.dart'
    show FeatureDataAction;
import 'package:prism_plurality/features/astro/content/horoscope.dart';
import 'package:prism_plurality/features/astro/content/interpret.dart';
import 'package:prism_plurality/features/astro/content/tarot.dart';
import 'package:prism_plurality/features/astro/content/zodiac.dart';
import 'package:prism_plurality/features/astro/data/astro_model.dart';
import 'package:prism_plurality/features/astro/views/ask_astro_view.dart';
import 'package:prism_plurality/features/astro/views/astro_widgets.dart';
import 'package:prism_plurality/features/astro/views/birth_chart_view.dart';
import 'package:prism_plurality/features/astro/views/birth_details_sheet.dart';
import 'package:prism_plurality/features/astro/views/compat_view.dart';
import 'package:prism_plurality/features/astro/views/energy_journal_view.dart';
import 'package:prism_plurality/features/astro/views/horoscope_view.dart';
import 'package:prism_plurality/features/astro/views/sky_calendars.dart';
import 'package:prism_plurality/features/astro/views/tarot_view.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

enum AstroSection {
  today('☀️', ('Today', 'Hoy')),
  chart('🪐', ('Birth Chart', 'Carta natal')),
  horoscope('🔮', ('Horoscope', 'Horóscopo')),
  tarot('🃏', ('Tarot', 'Tarot')),
  compatibility('❤️', ('Compatibility', 'Compatibilidad')),
  moon('🌙', ('Moon Calendar', 'Calendario lunar')),
  sun('🌞', ('Solar Calendar', 'Calendario solar')),
  energy('⚡', ('Energy & Journal', 'Energía y diario')),
  ask('💬', ('Ask Astro', 'Pregunta a Astro'));

  const AstroSection(this.emoji, this.label);
  final String emoji;
  final (String, String) label;

  static AstroSection parse(String? v) =>
      AstroSection.values.where((s) => s.name == v).firstOrNull ??
      AstroSection.today;
}

/// Whether the current viewer may enter or change this alter's birth
/// details: the alter themself, or anyone for first-time setup (before
/// anything private exists).
bool canEditBirth(AstroAccess a) => a.isOwner || a.profile.record == null;

class AstroAlterScreen extends ConsumerStatefulWidget {
  const AstroAlterScreen({super.key, required this.memberId, this.section});
  final String memberId;
  final String? section;

  @override
  ConsumerState<AstroAlterScreen> createState() => _AstroAlterScreenState();
}

class _AstroAlterScreenState extends ConsumerState<AstroAlterScreen> {
  late AstroSection _section = AstroSection.parse(widget.section);

  @override
  Widget build(BuildContext context) {
    final a = ref.watch(astroAccessProvider(widget.memberId));
    final es = astroEs(context);
    if (a == null) {
      return PrismPageScaffold(
        topBar: const PrismTopBar(title: 'Astro'),
        body: EmptyState(
          icon: Icon(PhosphorIcons.userCircleMinus()),
          title: tr(context, 'Not found', 'No encontrado'),
          subtitle: tr(
            context,
            'This alter isn\'t available.',
            'Este alter no está disponible.',
          ),
        ),
      );
    }
    final accent = alterAccent(context, a);
    final shareable =
        a.canView &&
        a.visibility == AstroVisibility.shareable &&
        a.subject != null;

    Widget body;
    if (!a.canView) {
      body = Padding(
        padding: const EdgeInsets.only(top: 40),
        child: EmptyState(
          icon: Icon(PhosphorIcons.lockSimple()),
          title: es
              ? 'La astrología de ${a.name} es privada'
              : '${a.name}\'s astrology is private',
          subtitle: es
              ? 'Se muestra mientras ${a.name} está al frente. Nadie más puede verla a menos que ${a.name} la comparta.'
              : 'It shows while ${a.name} is fronting. No one else can see it unless ${a.name} shares it.',
        ),
      );
    } else if (!a.hasBirthday) {
      body = Padding(
        padding: const EdgeInsets.only(top: 40),
        child: EmptyState(
          icon: Icon(PhosphorIcons.cake()),
          title: tr(
            context,
            'Add a birthday to begin',
            'Añade un cumpleaños para empezar',
          ),
          subtitle: tr(
            context,
            'The birthday gives the Sun sign and daily readings. A birth time and birthplace unlock the full chart.',
            'El cumpleaños da el signo solar y las lecturas diarias. La hora y el lugar de nacimiento desbloquean la carta completa.',
          ),
          actionLabel: canEditBirth(a)
              ? tr(context, 'Add birth details', 'Añadir datos de nacimiento')
              : null,
          onAction: canEditBirth(a)
              ? () => showBirthDetails(context, a.member.id)
              : null,
        ),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (a.visibility == AstroVisibility.hidden)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PrismSurface(
                tone: PrismSurfaceTone.accent,
                accentColor: accent,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Text('🚫'),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tr(
                          context,
                          'Hidden: not shown on profiles, Home, the calendar or system views.',
                          'Oculto: no se muestra en perfiles, Inicio, el calendario ni las vistas del sistema.',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final s in AstroSection.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: PrismChip(
                      label: '${s.emoji} ${trp(context, s.label)}',
                      selected: _section == s,
                      selectedColor: accent,
                      labelMaxLines: 1,
                      onTap: () => setState(() => _section = s),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionSwitcher(
            id: _section,
            child: switch (_section) {
              AstroSection.today => _Today(
                access: a,
                onOpen: (s) => setState(() => _section = s),
              ),
              AstroSection.chart => BirthChartSection(access: a),
              AstroSection.horoscope => HoroscopeSection(access: a),
              AstroSection.tarot => TarotSection(access: a),
              AstroSection.compatibility => CompatSection(access: a),
              AstroSection.moon => MoonCalendar(access: a),
              AstroSection.sun => SolarSection(access: a),
              AstroSection.energy => EnergyJournalSection(access: a),
              AstroSection.ask => AskAstroSection(access: a),
            },
          ),
        ],
      );
    }

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: 'Astro',
        subtitle: a.name,
        actions: [
          if (shareable)
            PrismTopBarAction(
              icon: PhosphorIcons.shareNetwork(),
              tooltip: tr(context, 'Share', 'Compartir'),
              onPressed: () => SharePlus.instance.share(
                ShareParams(text: _shareText(a, es)),
              ),
            ),
          if (a.canView && canEditBirth(a))
            PrismTopBarAction(
              icon: PhosphorIcons.slidersHorizontal(),
              tooltip: tr(
                context,
                'Birth details & privacy',
                'Datos de nacimiento y privacidad',
              ),
              onPressed: () => showBirthDetails(context, a.member.id),
            ),
          const FeatureDataAction(featureId: 'astro'),
        ],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + NavBarInset.of(context)),
          children: [body],
        ),
      ),
    );
  }

  String _shareText(AstroAccess a, bool es) {
    final s = a.sunSign!;
    final c = a.chart;
    final lines = [
      '${a.name}: ${signs[s].glyph} ${signs[s].name.of(es)}${c != null && c.moonCertain ? ' · ☽ ${signs[c.moonSign].name.of(es)}' : ''}${c?.risingSign != null ? ' · AC ${signs[c!.risingSign!].name.of(es)}' : ''}',
      if (c != null) chartSummary(c, a.name, es) else signs[s].keywords.of(es),
      es ? '— compartido desde Prism' : '— shared from Prism',
    ];
    return lines.join('\n\n');
  }
}

class _Today extends ConsumerWidget {
  const _Today({required this.access, required this.onOpen});
  final AstroAccess access;
  final ValueChanged<AstroSection> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final es = astroEs(context);
    final theme = Theme.of(context);
    final a = access;
    final now = DateTime.now();
    final reading = dailyReading(a.subject!, now, es);
    final card = dailyCard(a.member.id, now);
    final journal = ref.watch(astroJournalProvider(a.member.id));
    final wrote = journal.any(
      (e) =>
          e.day.year == now.year &&
          e.day.month == now.month &&
          e.day.day == now.day,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DayReadingView(reading: reading, access: a),
        Row(
          children: [
            Expanded(
              child: AstroCard(
                onTap: () => onOpen(AstroSection.tarot),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🃏 ${tr(context, 'Today\'s card', 'Carta del día')}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr(context, 'Tap to reveal', 'Toca para verla'),
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      card.card.major
                          ? tr(context, 'Major Arcana', 'Arcano Mayor')
                          : card.card.suit!.title.of(es),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AstroCard(
                onTap: () => onOpen(AstroSection.energy),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📝 ${tr(context, 'Journal', 'Diario')}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      wrote
                          ? tr(
                              context,
                              'Today\'s reflection saved',
                              'Reflexión de hoy guardada',
                            )
                          : tr(
                              context,
                              'How did today feel?',
                              '¿Cómo se sintió hoy?',
                            ),
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      wrote ? '✓' : '→',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (reading.transits.isEmpty && a.chart == null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              tr(
                context,
                'Readings use solar houses counted from the Sun sign. Add a birth year, time and place for readings based on the full chart.',
                'Las lecturas usan casas solares contadas desde el signo solar. Añade año, hora y lugar de nacimiento para lecturas basadas en la carta completa.',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
