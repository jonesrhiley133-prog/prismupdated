import 'package:intl/intl.dart' show DateFormat;
import 'package:flutter/foundation.dart' show SynchronousFuture;

import 'package:prism_plurality/features/astro/content/horoscope.dart';
import 'package:prism_plurality/features/astro/content/zodiac.dart';
import 'package:prism_plurality/features/astro/data/astro_model.dart';
import 'package:prism_plurality/features/astro/engine/ephemeris.dart';
import 'package:prism_plurality/features/astro/views/astro_widgets.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Runs [compute] off the first frame and caches the result per [cacheKey],
/// so switching tabs back and forth stays instant.
class AstroFuture<T> extends StatefulWidget {
  const AstroFuture({
    super.key,
    required this.cacheKey,
    required this.compute,
    required this.builder,
  });
  final String cacheKey;
  final T Function() compute;
  final Widget Function(BuildContext, T) builder;

  static final Map<String, Object?> _cache = {};

  @override
  State<AstroFuture<T>> createState() => _AstroFutureState<T>();
}

class _AstroFutureState<T> extends State<AstroFuture<T>> {
  late Future<T> _future;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(AstroFuture<T> old) {
    super.didUpdateWidget(old);
    if (old.cacheKey != widget.cacheKey) _start();
  }

  void _start() {
    final cached = AstroFuture._cache[widget.cacheKey];
    if (cached is T) {
      _future = SynchronousFuture(cached);
      return;
    }
    _future = Future<void>.delayed(const Duration(milliseconds: 16)).then((_) {
      final v = widget.compute();
      if (AstroFuture._cache.length > 60) AstroFuture._cache.clear();
      AstroFuture._cache[widget.cacheKey] = v;
      return v;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: _future,
    builder: (context, snap) {
      if (snap.hasError) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Text('${snap.error}'),
        );
      }
      if (!snap.hasData)
        return const Padding(
          padding: EdgeInsets.all(40),
          child: PrismLoadingState(),
        );
      return widget.builder(context, snap.data as T);
    },
  );
}

/// One day's reading, as used by Today and the Daily/Tomorrow horoscope.
class DayReadingView extends StatelessWidget {
  const DayReadingView({
    super.key,
    required this.reading,
    required this.access,
    this.header = true,
  });
  final DayReading reading;
  final AstroAccess access;
  final bool header;

  @override
  Widget build(BuildContext context) {
    final es = astroEs(context);
    final theme = Theme.of(context);
    final accent = alterAccent(context, access);
    final r = reading;
    final dateLabel = DateFormat.MMMMEEEEd(context.dateLocale).format(r.day);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header)
          AstroHero(
            accent: accent,
            seed: r.day.day + access.member.id.hashCode,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateLabel.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.1,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  es
                      ? 'Astrología de hoy para ${access.name}'
                      : 'Today\'s Astrology for ${access.name}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                BigThree(access: access),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _EnergyRing(value: r.energy, color: accent),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _kv(
                            context,
                            tr(context, 'Today\'s theme', 'Tema del día'),
                            r.title,
                          ),
                          _kv(
                            context,
                            tr(context, 'Emotional focus', 'Enfoque emocional'),
                            r.emotionalFocus,
                          ),
                          _kv(
                            context,
                            tr(context, 'Moon', 'Luna'),
                            '${r.phase.glyph} ${phaseName(r.phase, es)} · ${signs[r.moonSign].name.of(es)}${r.moonNextSign != null ? ' → ${signs[r.moonNextSign!].name.of(es)}' : ''}',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${tr(context, 'Relationships', 'Relaciones')}: ${r.parts[ReadingPart.relationships]}',
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        AstroCard(
          title: tr(context, 'Energy of the day', 'Energía del día'),
          emoji: '⚡',
          child: Column(
            children: [
              for (final k in EnergyKind.values)
                EnergyBar(kind: k, value: r.scores[k]!, color: accent),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PrismSurface(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (i, part) in ReadingPart.values.indexed) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.4,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          part.emoji,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              part.label.of(es),
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              r.parts[part]!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.45,
                                fontStyle:
                                    part == ReadingPart.reflection ||
                                        part == ReadingPart.message
                                    ? FontStyle.italic
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (r.transits.where((t) => t.transit != Body.moon).isNotEmpty) ...[
          PrismSectionHeader(
            title: tr(context, 'MAJOR TRANSITS', 'TRÁNSITOS PRINCIPALES'),
          ),
          PrismSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final t
                    in r.transits.where((t) => t.transit != Body.moon).take(6))
                  PrismListRow(
                    dense: true,
                    leading: SizedBox(
                      width: 30,
                      child: Center(
                        child: AstroGlyph(
                          bodyGlyph(t.transit),
                          size: 18,
                          color: t.harmonious
                              ? accent
                              : theme.colorScheme.tertiary,
                        ),
                      ),
                    ),
                    title: Text(t.label(es)),
                    subtitle: Text(t.meaning(es)),
                  ),
              ],
            ),
          ),
        ],
        const AstroDisclaimer(),
      ],
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$k: ',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            TextSpan(
              text: v,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnergyRing extends StatelessWidget {
  const _EnergyRing({required this.value, required this.color});
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '${tr(context, 'Energy', 'Energía')} $value%',
      child: SizedBox(
        width: 74,
        height: 74,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CustomPaint(
                painter: _RingPainter(
                  value / 100,
                  color,
                  theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$value%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  tr(context, 'energy', 'energía'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum HoroscopeSpan { daily, tomorrow, weekly, monthly, yearly }

class HoroscopeSection extends StatefulWidget {
  const HoroscopeSection({super.key, required this.access});
  final AstroAccess access;

  @override
  State<HoroscopeSection> createState() => _HoroscopeSectionState();
}

class _HoroscopeSectionState extends State<HoroscopeSection> {
  HoroscopeSpan _span = HoroscopeSpan.daily;

  @override
  Widget build(BuildContext context) {
    final es = astroEs(context);
    final a = widget.access;
    final subject = a.subject!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final key =
        '${a.member.id}|${a.birth.hashCode}|${a.profile.houseSystem}|$es|$today';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final s in HoroscopeSpan.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: PrismChip(
                    label: switch (s) {
                      HoroscopeSpan.daily => tr(context, 'Today', 'Hoy'),
                      HoroscopeSpan.tomorrow => tr(
                        context,
                        'Tomorrow',
                        'Mañana',
                      ),
                      HoroscopeSpan.weekly => tr(context, 'Week', 'Semana'),
                      HoroscopeSpan.monthly => tr(context, 'Month', 'Mes'),
                      HoroscopeSpan.yearly => tr(context, 'Year', 'Año'),
                    },
                    selected: _span == s,
                    onTap: () => setState(() => _span = s),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionSwitcher(
          id: _span,
          child: switch (_span) {
            HoroscopeSpan.daily => DayReadingView(
              reading: dailyReading(subject, today, es),
              access: a,
              header: true,
            ),
            HoroscopeSpan.tomorrow => _Tomorrow(
              access: a,
              day: today.add(const Duration(days: 1)),
            ),
            HoroscopeSpan.weekly => AstroFuture<WeekReading>(
              cacheKey: 'week|$key',
              compute: () => weeklyReading(
                subject,
                today.subtract(Duration(days: today.weekday - 1)),
                es,
              ),
              builder: (context, w) => _WeekView(week: w, access: a),
            ),
            HoroscopeSpan.monthly => AstroFuture<MonthReading>(
              cacheKey: 'month|$key',
              compute: () => monthlyReading(subject, today, es),
              builder: (context, m) => _MonthView(month: m, access: a),
            ),
            HoroscopeSpan.yearly => AstroFuture<YearReading>(
              cacheKey: 'year|$key',
              compute: () => yearlyReading(subject, today.year, es),
              builder: (context, y) => _YearView(year: y, access: a),
            ),
          },
        ),
      ],
    );
  }
}

class _Tomorrow extends StatelessWidget {
  const _Tomorrow({required this.access, required this.day});
  final AstroAccess access;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final es = astroEs(context);
    final r = dailyReading(access.subject!, day, es);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AstroHero(
          accent: alterAccent(context, access),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(context, 'TOMORROW\'S PREVIEW', 'AVANCE DE MAÑANA'),
                style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.1),
              ),
              const SizedBox(height: 4),
              Text(
                r.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${r.phase.glyph} ${phaseName(r.phase, es)} · ${signs[r.moonSign].name.of(es)} · ${tr(context, 'Energy', 'Energía')} ${r.energy}%',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        DayReadingView(reading: r, access: access, header: false),
      ],
    );
  }
}

class _EventList extends StatelessWidget {
  const _EventList({
    required this.events,
    required this.accent,
    this.dateFormat,
  });
  final List<SkyEvent> events;
  final Color accent;
  final DateFormat? dateFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = dateFormat ?? DateFormat.MMMd(context.dateLocale);
    if (events.isEmpty) {
      return AstroCard(
        child: Text(
          tr(
            context,
            'No major events in this period.',
            'No hay eventos importantes en este periodo.',
          ),
        ),
      );
    }
    return PrismSurface(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final e in events)
            PrismListRow(
              dense: true,
              leading: SizedBox(
                width: 44,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    e.glyph.runes.first > 0x1F000
                        ? Text(e.glyph, style: const TextStyle(fontSize: 18))
                        : AstroGlyph(
                            e.glyph,
                            size: 18,
                            color: e.personal
                                ? accent
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                    Text(
                      fmt.format(e.utc.toLocal()),
                      style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
              title: Row(
                children: [
                  Flexible(child: Text(e.title)),
                  if (e.personal) ...[
                    const SizedBox(width: 6),
                    Icon(
                      PhosphorIcons.userCircle(PhosphorIconsStyle.fill),
                      size: 14,
                      color: accent,
                    ),
                  ],
                ],
              ),
              subtitle: Text(e.detail),
            ),
        ],
      ),
    );
  }
}

class _WeekView extends StatelessWidget {
  const _WeekView({required this.week, required this.access});
  final WeekReading week;
  final AstroAccess access;

  @override
  Widget build(BuildContext context) {
    final es = astroEs(context);
    final theme = Theme.of(context);
    final accent = alterAccent(context, access);
    final today = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AstroHero(
          accent: accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(context, 'THIS WEEK', 'ESTA SEMANA'),
                style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.1),
              ),
              const SizedBox(height: 6),
              Text(
                week.summary,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AstroCard(
          title: tr(context, 'Emotional themes', 'Temas emocionales'),
          emoji: '💭',
          child: Text(week.emotional, style: const TextStyle(height: 1.45)),
        ),
        const SizedBox(height: 10),
        AstroCard(
          title: tr(context, 'Relationship themes', 'Temas de relaciones'),
          emoji: '❤️',
          child: Text(week.relationships, style: const TextStyle(height: 1.45)),
        ),
        PrismSectionHeader(title: tr(context, 'DAY BY DAY', 'DÍA A DÍA')),
        PrismSurface(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final d in week.days)
                PrismListRow(
                  selected:
                      d.day.day == today.day && d.day.month == today.month,
                  leading: SizedBox(
                    width: 44,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat.E(context.dateLocale).format(d.day),
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          d.phase.glyph,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  title: Text(d.title),
                  subtitle: Text(
                    '${signs[d.moonSign].name.of(es)} ${tr(context, 'Moon', 'Luna')} · ${tr(context, 'Energy', 'Energía')} ${d.energy}% · ${d.parts[ReadingPart.focus]}',
                  ),
                  onTap: () => PrismSheet.show(
                    context: context,
                    title: DateFormat.MMMMEEEEd(
                      context.dateLocale,
                    ).format(d.day),
                    maxHeightFactor: 0.92,
                    builder: (_) => ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      children: [
                        DayReadingView(
                          reading: d,
                          access: access,
                          header: false,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        PrismSectionHeader(
          title: tr(context, 'IMPORTANT DAYS', 'DÍAS IMPORTANTES'),
        ),
        _EventList(
          events: week.important,
          accent: accent,
          dateFormat: DateFormat.E(context.dateLocale),
        ),
        PrismSectionHeader(
          title: tr(context, 'ASTROLOGICAL EVENTS', 'EVENTOS ASTROLÓGICOS'),
        ),
        _EventList(
          events: week.events.where((e) => !e.personal).toList(),
          accent: accent,
          dateFormat: DateFormat.E(context.dateLocale),
        ),
        const AstroDisclaimer(),
      ],
    );
  }
}

class _MonthView extends StatelessWidget {
  const _MonthView({required this.month, required this.access});
  final MonthReading month;
  final AstroAccess access;

  @override
  Widget build(BuildContext context) {
    final es = astroEs(context);
    final theme = Theme.of(context);
    final accent = alterAccent(context, access);
    final emojis = ['❤️', '🎨', '📚', '🌱'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AstroHero(
          accent: accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat.yMMMM(
                  context.dateLocale,
                ).format(month.month).toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.1),
              ),
              const SizedBox(height: 6),
              Text(
                month.theme,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
              if (month.retrogrades.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final b in month.retrogrades)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiary.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: prismCorners(context, 20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AstroGlyph(
                              bodyGlyph(b),
                              size: 14,
                              color: theme.colorScheme.tertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${planets[b]!.name.of(es)} ℞',
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final (i, e) in month.areas.entries.indexed) ...[
          AstroCard(
            title: e.key,
            emoji: emojis[i % emojis.length],
            child: Text(e.value, style: const TextStyle(height: 1.45)),
          ),
          const SizedBox(height: 10),
        ],
        PrismSectionHeader(title: tr(context, 'MOON PHASES', 'FASES LUNARES')),
        _EventList(
          events: [
            for (final e in month.events)
              if (e.kind == SkyEventKind.lunation ||
                  e.kind == SkyEventKind.eclipse)
                e,
          ],
          accent: accent,
        ),
        PrismSectionHeader(
          title: tr(context, 'IMPORTANT DATES', 'FECHAS IMPORTANTES'),
        ),
        _EventList(
          events: [
            for (final e in month.events)
              if (e.kind != SkyEventKind.lunation &&
                  e.kind != SkyEventKind.eclipse)
                e,
          ],
          accent: accent,
        ),
        const AstroDisclaimer(),
      ],
    );
  }
}

class _YearView extends StatelessWidget {
  const _YearView({required this.year, required this.access});
  final YearReading year;
  final AstroAccess access;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = alterAccent(context, access);
    final byMonth = <int, List<SkyEvent>>{};
    for (final e in year.events) {
      (byMonth[e.utc.toLocal().month] ??= []).add(e);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AstroHero(
          accent: accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${year.year}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tr(
                  context,
                  'The year ahead for ${access.name}',
                  'El año de ${access.name}',
                ),
                style: theme.textTheme.titleSmall,
              ),
              if (year.birthday != null) ...[
                const SizedBox(height: 8),
                Text(
                  '🎂 ${tr(context, 'Solar return', 'Revolución solar')}: ${DateFormat.MMMMd(context.dateLocale).add_jm().format(year.birthday!.toLocal())}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        PrismSectionHeader(
          title: tr(context, 'MAJOR THEMES', 'TEMAS PRINCIPALES'),
        ),
        for (final t in year.themes) ...[
          AstroCard(child: Text(t, style: const TextStyle(height: 1.45))),
          const SizedBox(height: 10),
        ],
        PrismSectionHeader(
          title: tr(context, 'GROWTH PERIODS', 'PERIODOS DE CRECIMIENTO'),
        ),
        _EventList(
          events: year.growth,
          accent: accent,
          dateFormat: DateFormat.MMMd(context.dateLocale),
        ),
        PrismSectionHeader(
          title: tr(context, 'REFLECTION PERIODS', 'PERIODOS DE REFLEXIÓN'),
        ),
        _EventList(
          events: year.reflection,
          accent: accent,
          dateFormat: DateFormat.MMMd(context.dateLocale),
        ),
        PrismSectionHeader(title: tr(context, 'MONTH BY MONTH', 'MES A MES')),
        for (final m in byMonth.keys.toList()..sort()) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 6, left: 4),
            child: Text(
              DateFormat.MMMM(
                context.dateLocale,
              ).format(DateTime(year.year, m)),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ),
          _EventList(events: byMonth[m]!, accent: accent),
        ],
        const AstroDisclaimer(),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction, this.color, this.track);
  final double fraction;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 7.0;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(rect, 0, 6.2832, false, base);
    canvas.drawArc(
      rect,
      -1.5708,
      6.2832 * fraction.clamp(0, 1),
      false,
      base
        ..color = color
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color || old.track != track;
}
