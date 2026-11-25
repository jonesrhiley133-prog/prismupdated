import 'dart:math' as math;

import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:prism_plurality/features/voice/voice_engine.dart';
import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/features/astro/content/articles.dart';
import 'package:prism_plurality/features/astro/content/horoscope.dart';
import 'package:prism_plurality/features/astro/content/zodiac.dart';
import 'package:prism_plurality/features/astro/data/astro_model.dart';
import 'package:prism_plurality/features/astro/engine/ephemeris.dart';
import 'package:prism_plurality/features/astro/engine/events.dart';
import 'package:prism_plurality/features/astro/views/astro_widgets.dart';
import 'package:prism_plurality/features/astro/views/horoscope_view.dart';
import 'package:prism_plurality/features/astro/views/sky_calendars.dart';
import 'package:prism_plurality/features/settings/views/feature_data_screen.dart'
    show FeatureDataAction;
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

enum _HubTab { system, calendar, learn }

class AstroHubScreen extends ConsumerStatefulWidget {
  const AstroHubScreen({super.key, this.tab});
  final String? tab;

  @override
  ConsumerState<AstroHubScreen> createState() => _AstroHubScreenState();
}

class _AstroHubScreenState extends ConsumerState<AstroHubScreen> {
  late _HubTab _tab =
      _HubTab.values.where((t) => t.name == widget.tab).firstOrNull ??
      _HubTab.system;

  @override
  Widget build(BuildContext context) {
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: 'Astro',
        actions: [
          PrismTopBarAction(
            icon: PhosphorIcons.gear(),
            tooltip: tr(context, 'Astro settings', 'Ajustes de Astro'),
            onPressed: () => showAstroSettings(context),
          ),
          const FeatureDataAction(featureId: 'astro'),
        ],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + NavBarInset.of(context)),
          children: [
            const _TodaySky(),
            const SizedBox(height: 16),
            PrismSegmentedControl<_HubTab>(
              segments: [
                PrismSegment(
                  value: _HubTab.system,
                  label: tr(context, 'System', 'Sistema'),
                ),
                PrismSegment(
                  value: _HubTab.calendar,
                  label: tr(context, 'Calendar', 'Calendario'),
                ),
                PrismSegment(
                  value: _HubTab.learn,
                  label: tr(context, 'Learn', 'Aprender'),
                ),
              ],
              selected: _tab,
              onChanged: (t) => setState(() => _tab = t),
            ),
            const SizedBox(height: 14),
            SectionSwitcher(
              id: _tab,
              child: switch (_tab) {
                _HubTab.system => const _SystemAstro(),
                _HubTab.calendar => const _CalendarTab(),
                _HubTab.learn => const _LearnTab(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TodaySky extends StatelessWidget {
  const _TodaySky();

  @override
  Widget build(BuildContext context) {
    final es = astroEs(context);
    final theme = Theme.of(context);
    final now = DateTime.now();
    final phase = phaseForDay(now);
    final moon = moonSignForDay(now);
    final sun = signOf(longitudeOf(Body.sun, now.toUtc()));
    final retro = [
      for (final b in Body.values)
        if (positionOf(b, now.toUtc()).retrograde) b,
    ];
    final next = lunations(
      now.toUtc(),
      now.add(const Duration(days: 16)).toUtc(),
    ).firstOrNull;
    return AstroHero(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(context, 'TODAY\'S SKY', 'EL CIELO DE HOY'),
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(phase.glyph, style: const TextStyle(fontSize: 46)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${phaseName(phase, es)} ${es ? 'en' : 'in'} ${signs[moon.sign].name.of(es)}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${(moonIllumination(now.toUtc()) * 100).round()}% ${tr(context, 'lit', 'iluminada')} · ${phaseThemeTitle(phase, es)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SignChip(sun, prefix: es ? 'Sol en' : 'Sun in'),
              for (final b in retro) _RetroChip(b),
            ],
          ),
          if (next != null) ...[
            const SizedBox(height: 10),
            Text(
              '${tr(context, 'Next', 'Próxima')}: ${next.phase.glyph} ${phaseName(next.phase, es)} ${es ? 'en' : 'in'} ${signs[next.sign].name.of(es)} · ${DateFormat.MMMEd(context.dateLocale).format(next.utc.toLocal())}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _RetroChip extends StatelessWidget {
  const _RetroChip(this.body);
  final Body body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AstroGlyph(
            bodyGlyph(body),
            size: 14,
            color: theme.colorScheme.tertiary,
          ),
          const SizedBox(width: 4),
          Text(
            '${planets[body]!.name.of(astroEs(context))} ℞',
            style: theme.textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

class _SystemAstro extends ConsumerWidget {
  const _SystemAstro();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final es = astroEs(context);
    final theme = Theme.of(context);
    final all = ref.watch(astroAllProvider);
    final listed = ref.watch(astroListedProvider);
    final viewers = ref.watch(astroViewersProvider);
    final fronting = [
      for (final a in all)
        if (viewers.contains(a.member.id) && a.listed) a,
    ];

    final elements = {for (final e in AstroElement.values) e: 0};
    final modalities = {for (final m in Modality.values) m: 0};
    for (final a in listed) {
      final s = signs[a.sunSign!];
      elements[s.element] = elements[s.element]! + 1;
      modalities[s.modality] = modalities[s.modality]! + 1;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final birthdays = [
      for (final a in listed)
        () {
          var d = DateTime(now.year, a.birth!.month, a.birth!.day);
          if (d.isBefore(today))
            d = DateTime(now.year + 1, a.birth!.month, a.birth!.day);
          return (a, d);
        }(),
    ]..sort((x, y) => x.$2.compareTo(y.$2));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: VoiceText(
            VoiceContext.astroIntro,
            fallback: tr(
              context,
              'Today\'s sky, for reflection — take what fits.',
              'El cielo de hoy, para reflexionar: quédate con lo que te sirva.',
            ),
            feature: 'astro',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        if (fronting.isNotEmpty) ...[
          for (final a in fronting.take(2)) ...[
            AstroCard(
              onTap: () => context.push(AppRoutePaths.astroAlter(a.member.id)),
              child: Row(
                children: [
                  AstroAvatar(a, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          es
                              ? 'Al frente: ${a.name}'
                              : 'Currently fronting: ${a.name}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        BigThree(access: a, size: 13),
                        const SizedBox(height: 2),
                        Text(
                          '✨ ${tr(context, 'Today\'s theme', 'Tema de hoy')}: ${dailyReading(a.subject!, now, es).title}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(PhosphorIcons.caretRight(), size: 16),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
        PrismSectionHeader(
          title: tr(
            context,
            'ZODIAC CONSTELLATION',
            'CONSTELACIÓN DEL ZODIACO',
          ),
        ),
        AstroCard(
          padding: const EdgeInsets.all(8),
          child: listed.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    tr(
                      context,
                      'Alters appear here once they add a birthday and choose to share their astrology with the system. Private astrology stays private.',
                      'Los alters aparecen aquí cuando añaden un cumpleaños y eligen compartir su astrología con el sistema. La astrología privada sigue siendo privada.',
                    ),
                    style: const TextStyle(height: 1.45),
                  ),
                )
              : AspectRatio(
                  aspectRatio: 1,
                  child: _Constellation(alters: listed),
                ),
        ),
        PrismSectionHeader(title: tr(context, 'ALTERS', 'ALTERS')),
        _AlterList(all: all),
        if (listed.isNotEmpty) ...[
          PrismSectionHeader(
            title: tr(context, 'SYSTEM ASTROLOGY', 'ASTROLOGÍA DEL SISTEMA'),
          ),
          AstroCard(
            title: tr(
              context,
              'Elements & modalities',
              'Elementos y modalidades',
            ),
            emoji: '🌌',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in AstroElement.values)
                      _CountPill('${e.emoji} ${e.label.of(es)}', elements[e]!),
                    for (final m in Modality.values)
                      _CountPill(m.label.of(es), modalities[m]!),
                  ],
                ),
                const SizedBox(height: 10),
                Text(() {
                  final top = elements.entries
                      .reduce((x, y) => x.value >= y.value ? x : y)
                      .key;
                  return es
                      ? 'El elemento más común en el sistema es ${top.label.es}: ${top.meaning.es}.'
                      : 'The most common element across the system is ${top.label.en}: ${top.meaning.en}.';
                }(), style: theme.textTheme.bodySmall?.copyWith(height: 1.4)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AstroCard(
            title: tr(
              context,
              'Sun · Moon · Rising',
              'Sol · Luna · Ascendente',
            ),
            emoji: '✨',
            child: Column(
              children: [
                for (final a in listed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 110,
                          child: Text(
                            a.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(child: BigThree(access: a, size: 12)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          PrismSectionHeader(title: tr(context, 'BIRTHDAYS', 'CUMPLEAÑOS')),
          PrismSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (a, d) in birthdays.take(6))
                  PrismListRow(
                    dense: true,
                    leading: AstroAvatar(a, size: 30),
                    title: Text(a.name),
                    subtitle: Text(
                      '${DateFormat.MMMMd(context.dateLocale).format(d)} · ${signs[a.sunSign!].name.of(es)}${d == today ? ' 🎂' : ''}',
                    ),
                  ),
              ],
            ),
          ),
        ],
        PrismSectionHeader(
          title: tr(context, 'SYSTEM-WIDE THEMES', 'TEMAS DEL SISTEMA'),
        ),
        AstroFuture<List<SkyEvent>>(
          cacheKey: 'hub-events|$es|${today.toIso8601String()}',
          compute: () => skyEvents(
            today.toUtc(),
            today.add(const Duration(days: 21)).toUtc(),
            es,
          ),
          builder: (context, events) => PrismSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final e in events.take(10))
                  PrismListRow(
                    dense: true,
                    leading: SizedBox(
                      width: 40,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          e.glyph.runes.first > 0x1F000
                              ? Text(
                                  e.glyph,
                                  style: const TextStyle(fontSize: 18),
                                )
                              : AstroGlyph(e.glyph, size: 18),
                          Text(
                            DateFormat.MMMd(
                              context.dateLocale,
                            ).format(e.utc.toLocal()),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    title: Text(e.title),
                    subtitle: Text(e.detail),
                  ),
              ],
            ),
          ),
        ),
        const AstroDisclaimer(),
      ],
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill(this.label, this.count);
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$label · $count', style: theme.textTheme.labelMedium),
    );
  }
}

/// Every listed alter placed at their Sun sign around the zodiac; alters
/// sharing an element are joined like a constellation.
class _Constellation extends StatelessWidget {
  const _Constellation({required this.alters});
  final List<AstroAccess> alters;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, box) {
        final size = math.min(box.maxWidth, box.maxHeight);
        final c = Offset(size / 2, size / 2);
        final ring = size / 2 - 18;
        final bySign = <int, List<AstroAccess>>{};
        for (final a in alters) {
          (bySign[a.sunSign!] ??= []).add(a);
        }
        final positions = <AstroAccess, Offset>{};
        for (final e in bySign.entries) {
          for (final (i, a) in e.value.indexed) {
            final r = ring - 46 - i * 34.0;
            final t =
                (90 -
                    (e.key * 30 + 15) +
                    (i.isOdd ? 6 : -6) * (i > 0 ? 1 : 0)) *
                math.pi /
                180;
            positions[a] = Offset(
              c.dx + r * math.cos(t),
              c.dy - r * math.sin(t),
            );
          }
        }
        final avatar = (size * 0.1).clamp(28.0, 44.0);
        return Stack(
          children: [
            Positioned.fill(child: StarField(count: 60, seed: 3)),
            CustomPaint(
              size: Size.square(size),
              painter: _ConstellationPainter(c, ring, positions, scheme),
            ),
            for (final e in positions.entries)
              Positioned(
                left: e.value.dx - avatar / 2,
                top: e.value.dy - avatar / 2,
                child: Tooltip(
                  message:
                      '${e.key.name} · ${signs[e.key.sunSign!].name.of(astroEs(context))}',
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () =>
                        context.push(AppRoutePaths.astroAlter(e.key.member.id)),
                    child: AstroAvatar(e.key, size: avatar),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ConstellationPainter extends CustomPainter {
  _ConstellationPainter(this.c, this.ring, this.positions, this.scheme);
  final Offset c;
  final double ring;
  final Map<AstroAccess, Offset> positions;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..color = scheme.outlineVariant;
    canvas.drawCircle(c, ring, line);
    canvas.drawCircle(
      c,
      ring - 24,
      line..color = scheme.outlineVariant.withValues(alpha: 0.5),
    );
    for (var s = 0; s < 12; s++) {
      final t = (90 - s * 30) * math.pi / 180;
      canvas.drawLine(
        Offset(
          c.dx + (ring - 24) * math.cos(t),
          c.dy - (ring - 24) * math.sin(t),
        ),
        Offset(c.dx + ring * math.cos(t), c.dy - ring * math.sin(t)),
        line,
      );
      final g = (90 - (s * 30 + 15)) * math.pi / 180;
      final tp = TextPainter(
        text: TextSpan(
          text: signs[s].glyph,
          style: astroGlyphStyle(15, scheme.primary),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
              c.dx + (ring - 12) * math.cos(g),
              c.dy - (ring - 12) * math.sin(g),
            ) -
            Offset(tp.width / 2, tp.height / 2),
      );
    }
    // Join alters of the same element.
    final byElement = <AstroElement, List<Offset>>{};
    for (final e in positions.entries) {
      (byElement[signs[e.key.sunSign!].element] ??= []).add(e.value);
    }
    final join = Paint()
      ..strokeWidth = 1.2
      ..color = scheme.primary.withValues(alpha: 0.35);
    for (final pts in byElement.values) {
      for (var i = 0; i + 1 < pts.length; i++) {
        canvas.drawLine(pts[i], pts[i + 1], join);
      }
    }
  }

  @override
  bool shouldRepaint(_ConstellationPainter old) =>
      old.positions.length != positions.length ||
      old.scheme != scheme ||
      old.ring != ring;
}

class _CalendarTab extends ConsumerWidget {
  const _CalendarTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrismSectionHeader(
          title: tr(context, 'MOON CALENDAR', 'CALENDARIO LUNAR'),
        ),
        const MoonCalendar(),
        PrismSectionHeader(
          title: tr(context, 'SUN & SOLAR CALENDAR', 'SOL Y CALENDARIO SOLAR'),
        ),
        const SolarSection(),
        const AstroDisclaimer(),
      ],
    );
  }
}

class _LearnTab extends StatelessWidget {
  const _LearnTab();

  @override
  Widget build(BuildContext context) {
    final es = astroEs(context);
    final theme = Theme.of(context);
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrismSectionHeader(
          title: tr(context, 'THIS MONTH IN THE SKY', 'ESTE MES EN EL CIELO'),
        ),
        AstroFuture<List<SkyEvent>>(
          cacheKey: 'news|$es|$monthStart',
          compute: () => skyEvents(
            monthStart.toUtc(),
            DateTime(now.year, now.month + 1).toUtc(),
            es,
          ),
          builder: (context, events) => PrismSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final e in events)
                  PrismListRow(
                    dense: true,
                    leading: SizedBox(
                      width: 30,
                      child: Center(
                        child: e.glyph.runes.first > 0x1F000
                            ? Text(
                                e.glyph,
                                style: const TextStyle(fontSize: 18),
                              )
                            : AstroGlyph(e.glyph, size: 18),
                      ),
                    ),
                    title: Text(e.title),
                    subtitle: Text(
                      '${DateFormat.MMMEd(context.dateLocale).format(e.utc.toLocal())} · ${e.detail}',
                    ),
                  ),
              ],
            ),
          ),
        ),
        for (final cat in ArticleCategory.values)
          if (articles.any((a) => a.category == cat)) ...[
            PrismSectionHeader(
              title: '${cat.emoji}  ${cat.label.of(es).toUpperCase()}',
            ),
            PrismSurface(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final a in articles.where((a) => a.category == cat))
                    PrismListRow(
                      title: Text(a.title.of(es)),
                      showChevron: true,
                      onTap: () => showArticle(context, a),
                    ),
                ],
              ),
            ),
          ],
        const SizedBox(height: 14),
        Text(
          scienceNote.of(es),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

Future<void> showArticle(BuildContext context, AstroArticle a) =>
    PrismSheet.show(
      context: context,
      title: a.title.of(astroEs(context)),
      maxHeightFactor: 0.92,
      builder: (context) {
        final es = astroEs(context);
        final theme = Theme.of(context);
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text(
              '${a.category.emoji} ${a.category.label.of(es)}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            for (final p in a.paragraphs)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  p.of(es),
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
                ),
              ),
            PrismSurface(
              tone: PrismSurfaceTone.accent,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    PhosphorIcons.flask(),
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      scienceNote.of(es),
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );

Future<void> showAstroSettings(BuildContext context) => PrismSheet.show(
  context: context,
  title: tr(context, 'Astro settings', 'Ajustes de Astro'),
  maxHeightFactor: 0.9,
  builder: (_) => const _AstroSettings(),
);

class _AstroSettings extends ConsumerWidget {
  const _AstroSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(astroSettingsProvider);
    final theme = Theme.of(context);
    void save(AstroSettings n) =>
        ref.read(astroActionsProvider).saveSettings(n);
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        PrismSurface(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              PrismSwitchRow(
                icon: PhosphorIcons.house(),
                title: tr(
                  context,
                  'Fronting card on Home',
                  'Tarjeta de frente en Inicio',
                ),
                subtitle: tr(
                  context,
                  'Shows the fronting alter\'s signs and today\'s theme, if their astrology is visible.',
                  'Muestra los signos y el tema del día del alter al frente, si su astrología es visible.',
                ),
                value: s.homeCard,
                onChanged: (v) => save(
                  AstroSettings(
                    record: s.record,
                    homeCard: v,
                    insights: s.insights,
                    calendar: s.calendar,
                  ),
                ),
              ),
              PrismSwitchRow(
                icon: PhosphorIcons.lightbulb(),
                title: tr(
                  context,
                  'Astrology in Daily Insights',
                  'Astrología en Perspectivas diarias',
                ),
                value: s.insights,
                onChanged: (v) => save(
                  AstroSettings(
                    record: s.record,
                    homeCard: s.homeCard,
                    insights: v,
                    calendar: s.calendar,
                  ),
                ),
              ),
              PrismSwitchRow(
                icon: PhosphorIcons.calendarBlank(),
                title: tr(
                  context,
                  'Astrology events in Calendar',
                  'Eventos astrológicos en el Calendario',
                ),
                subtitle: tr(
                  context,
                  'Moon phases, eclipses, Sun sign changes and retrogrades.',
                  'Fases lunares, eclipses, cambios de signo solar y retrógrados.',
                ),
                value: s.calendar,
                onChanged: (v) => save(
                  AstroSettings(
                    record: s.record,
                    homeCard: s.homeCard,
                    insights: s.insights,
                    calendar: v,
                  ),
                ),
              ),
            ],
          ),
        ),
        PrismSectionHeader(title: tr(context, 'PRIVACY', 'PRIVACIDAD')),
        Text(
          tr(
            context,
            'Each alter chooses who sees their astrology in their own birth details. It\'s private by default: entering a birthday or birth time never shares it with other alters. Everything is calculated on this device.',
            'Cada alter elige quién ve su astrología en sus datos de nacimiento. Es privada por defecto: introducir un cumpleaños o una hora nunca la comparte con otros alters. Todo se calcula en este dispositivo.',
          ),
          style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
        ),
        PrismSectionHeader(
          title: tr(context, 'ABOUT & SOURCES', 'ACERCA DE Y FUENTES'),
        ),
        Text(
          tr(
            context,
            'Planetary positions are computed on the device using Paul Schlyter\'s methods (accurate to a few arcminutes, 1900–2100); Chiron is approximate. Places: GeoNames (CC BY 4.0, geonames.org). Symbols: Noto Sans Symbols (SIL Open Font License). Interpretations are written for reflection and follow common modern Western astrology and Rider–Waite–Smith tarot traditions.',
            'Las posiciones planetarias se calculan en el dispositivo con los métodos de Paul Schlyter (precisión de pocos minutos de arco, 1900–2100); Quirón es aproximado. Lugares: GeoNames (CC BY 4.0, geonames.org). Símbolos: Noto Sans Symbols (SIL Open Font License). Las interpretaciones están escritas para reflexionar y siguen las tradiciones habituales de la astrología occidental moderna y del tarot Rider–Waite–Smith.',
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            height: 1.45,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Alters with astrology first; the rest folded into one row.
class _AlterList extends StatefulWidget {
  const _AlterList({required this.all});
  final List<AstroAccess> all;

  @override
  State<_AlterList> createState() => _AlterListState();
}

class _AlterListState extends State<_AlterList> {
  bool _showRest = false;

  Widget _row(BuildContext context, AstroAccess a) {
    return PrismListRow(
      leading: AstroAvatar(a, size: 36),
      title: Text(a.name),
      subtitle: !a.canView
          ? Text('🔒 ${tr(context, 'Private', 'Privado')}')
          : !a.hasBirthday
          ? Text(tr(context, 'No birthday yet', 'Sin cumpleaños todavía'))
          : a.visibility == AstroVisibility.hidden
          ? Text('🚫 ${tr(context, 'Hidden', 'Oculto')}')
          : BigThree(access: a, size: 13),
      showChevron: true,
      onTap: () => context.push(AppRoutePaths.astroAlter(a.member.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final withData = [
      for (final a in widget.all)
        if (!a.isEmpty) a,
    ];
    final rest = [
      for (final a in widget.all)
        if (a.isEmpty) a,
    ];
    return PrismSurface(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final a in withData) _row(context, a),
          if (rest.isNotEmpty)
            PrismListRow(
              leading: Icon(
                _showRest ? PhosphorIcons.caretUp() : PhosphorIcons.caretDown(),
              ),
              title: Text(
                tr(
                  context,
                  '${rest.length} without a birthday yet',
                  '${rest.length} sin cumpleaños todavía',
                ),
              ),
              subtitle: Text(
                tr(
                  context,
                  'Add one from their Astro page.',
                  'Añádelo desde su página de Astro.',
                ),
              ),
              onTap: () => setState(() => _showRest = !_showRest),
            ),
          if (_showRest)
            for (final a in rest.take(200)) _row(context, a),
        ],
      ),
    );
  }
}
