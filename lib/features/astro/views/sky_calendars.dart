import 'package:intl/intl.dart' show DateFormat;

import 'package:prism_plurality/features/astro/content/horoscope.dart';
import 'package:prism_plurality/features/astro/content/zodiac.dart';
import 'package:prism_plurality/features/astro/data/astro_model.dart';
import 'package:prism_plurality/features/astro/engine/ephemeris.dart';
import 'package:prism_plurality/features/astro/engine/events.dart';
import 'package:prism_plurality/features/astro/views/astro_widgets.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

class _MonthMoon {
  _MonthMoon(this.phases, this.signs, this.lunations);
  final List<MoonPhase> phases;
  final List<int> signs;
  final List<Lunation> lunations;
}

final _moonCache = <String, _MonthMoon>{};

_MonthMoon _moonMonth(int year, int month) => _moonCache.putIfAbsent('$year-$month', () {
  final start = DateTime(year, month);
  final end = DateTime(year, month + 1);
  final lun = lunations(start.subtract(const Duration(days: 1)).toUtc(), end.add(const Duration(days: 1)).toUtc());
  final days = end.difference(start).inDays;
  return _MonthMoon(
    [for (var d = 0; d < days; d++) phaseForDay(DateTime(year, month, d + 1), known: lun)],
    [for (var d = 0; d < days; d++) signOf(longitudeOf(Body.moon, DateTime(year, month, d + 1, 12).toUtc()))],
    lun,
  );
});

/// A month of moon phases. With [access], selecting a day adds a personal
/// interpretation for that alter.
class MoonCalendar extends StatefulWidget {
  const MoonCalendar({super.key, this.access});
  final AstroAccess? access;

  @override
  State<MoonCalendar> createState() => _MoonCalendarState();
}

class _MoonCalendarState extends State<MoonCalendar> {
  late DateTime _month;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final es = astroEs(context);
    final theme = Theme.of(context);
    final locale = context.dateLocale;
    final m = _moonMonth(_month.year, _month.month);
    final first = DateTime(_month.year, _month.month);
    final lead = (first.weekday + 6) % 7; // Monday first
    final days = m.phases.length;
    final today = DateTime.now();
    final accent = widget.access == null ? theme.colorScheme.primary : alterAccent(context, widget.access!);
    final weekdays = [for (var i = 0; i < 7; i++) DateFormat.E(locale).format(DateTime(2024, 1, 1 + i)).substring(0, 2)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AstroCard(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
          child: Column(
            children: [
              Row(
                children: [
                  PrismIconButton(icon: PhosphorIcons.caretLeft(), tooltip: tr(context, 'Previous month', 'Mes anterior'), onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1))),
                  Expanded(child: Text(DateFormat.yMMMM(locale).format(_month), textAlign: TextAlign.center, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                  PrismIconButton(icon: PhosphorIcons.caretRight(), tooltip: tr(context, 'Next month', 'Mes siguiente'), onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1))),
                ],
              ),
              const SizedBox(height: 8),
              Row(children: [for (final w in weekdays) Expanded(child: Text(w, textAlign: TextAlign.center, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)))]),
              const SizedBox(height: 4),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 0.78,
                children: [
                  for (var i = 0; i < lead; i++) const SizedBox.shrink(),
                  for (var d = 1; d <= days; d++)
                    _DayCell(
                      day: d,
                      phase: m.phases[d - 1],
                      sign: m.signs[d - 1],
                      selected: _selected.year == _month.year && _selected.month == _month.month && _selected.day == d,
                      today: today.year == _month.year && today.month == _month.month && today.day == d,
                      accent: accent,
                      onTap: () => setState(() => _selected = DateTime(_month.year, _month.month, d)),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_selected.year == _month.year && _selected.month == _month.month)
          _DayDetail(day: _selected, phase: m.phases[_selected.day - 1], lunations: m.lunations, access: widget.access, es: es),
        PrismSectionHeader(title: tr(context, 'THIS MONTH', 'ESTE MES')),
        PrismSurface(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final l in m.lunations.where((l) => l.utc.toLocal().month == _month.month))
                PrismListRow(
                  dense: true,
                  leading: Text(l.phase.glyph, style: const TextStyle(fontSize: 22)),
                  title: Text('${l.eclipse == Eclipse.none ? phaseName(l.phase, es) : l.eclipse == Eclipse.solar ? tr(context, 'Solar eclipse', 'Eclipse solar') : tr(context, 'Lunar eclipse', 'Eclipse lunar')} ${es ? 'en' : 'in'} ${signs[l.sign].name.of(es)}'),
                  subtitle: Text('${DateFormat.MMMEd(locale).format(l.utc.toLocal())} · ${context.formatTime(l.utc.toLocal())} · ${phaseThemeTitle(l.phase, es)}'),
                  onTap: () => setState(() => _selected = DateTime(l.utc.toLocal().year, l.utc.toLocal().month, l.utc.toLocal().day)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.phase, required this.sign, required this.selected, required this.today, required this.accent, required this.onTap});
  final int day;
  final MoonPhase phase;
  final int sign;
  final bool selected;
  final bool today;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '$day, ${phaseName(phase, astroEs(context))}',
      child: InkWell(
        borderRadius: prismCorners(context, 10),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: prismCorners(context, 10),
            color: selected ? accent.withValues(alpha: 0.18) : null,
            border: today ? Border.all(color: accent, width: 1.4) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$day', style: theme.textTheme.labelSmall?.copyWith(fontWeight: phase.principal ? FontWeight.w800 : FontWeight.w500)),
              Text(phase.glyph, style: TextStyle(fontSize: phase.principal ? 17 : 13)),
              AstroGlyph(signs[sign].glyph, size: 9, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayDetail extends StatelessWidget {
  const _DayDetail({required this.day, required this.phase, required this.lunations, required this.access, required this.es});
  final DateTime day;
  final MoonPhase phase;
  final List<Lunation> lunations;
  final AstroAccess? access;
  final bool es;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moon = moonSignForDay(day);
    final exact = lunations.where((l) {
      final t = l.utc.toLocal();
      return t.year == day.year && t.month == day.month && t.day == day.day;
    }).firstOrNull;
    final reading = access?.subject == null ? null : dailyReading(access!.subject!, day, es);
    final accent = access == null ? theme.colorScheme.primary : alterAccent(context, access!);
    return AstroHero(
      accent: accent,
      seed: day.day,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(DateFormat.MMMMEEEEd(context.dateLocale).format(day), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            '${phase.glyph} ${phaseName(phase, es)} ${es ? 'en' : 'in'} ${signs[moon.sign].name.of(es)}${moon.nextSign != null ? ' → ${signs[moon.nextSign!].name.of(es)} (${context.formatTime(moon.changeAt!)})' : ''}',
            style: theme.textTheme.titleSmall,
          ),
          if (exact != null) Text('${tr(context, 'Exact at', 'Exacta a las')} ${context.formatTime(exact.utc.toLocal())}', style: theme.textTheme.bodySmall),
          Text('${tr(context, 'Illumination', 'Iluminación')}: ${(moonIllumination(DateTime(day.year, day.month, day.day, 12).toUtc()) * 100).round()}%', style: theme.textTheme.bodySmall),
          const SizedBox(height: 10),
          Text('${tr(context, 'Theme', 'Tema')}: ${phaseThemeTitle(phase, es)}', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(phaseTraditional(phase, es), style: const TextStyle(height: 1.45)),
          if (reading != null) ...[
            const SizedBox(height: 10),
            Text(es ? 'Para ${access!.name}:' : 'For ${access!.name}:', style: TextStyle(fontWeight: FontWeight.w700, color: accent)),
            const SizedBox(height: 2),
            Text(
              es
                  ? 'La Luna pasa por su casa ${houseOrdinal(reading.moonHouse, true)} (${houses[reading.moonHouse - 1].theme.es}). ${reading.parts[ReadingPart.emotions]}'
                  : 'The Moon moves through their ${houseOrdinal(reading.moonHouse, false)} house (${houses[reading.moonHouse - 1].theme.en}). ${reading.parts[ReadingPart.emotions]}',
              style: const TextStyle(height: 1.45),
            ),
            const SizedBox(height: 6),
            Text('${tr(context, 'Energy', 'Energía')}: ${reading.energy}% · ${reading.emotionalFocus}', style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Text('🧠 ${reading.parts[ReadingPart.reflection]}', style: const TextStyle(fontStyle: FontStyle.italic, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

/// The Sun's journey: current sign with the previous and next, and the
/// year's sign changes. With [access], how it meets that alter's chart.
class SolarSection extends StatelessWidget {
  const SolarSection({super.key, this.access});
  final AstroAccess? access;

  @override
  Widget build(BuildContext context) {
    final es = astroEs(context);
    final theme = Theme.of(context);
    final locale = context.dateLocale;
    final now = DateTime.now().toUtc();
    final sun = signOf(longitudeOf(Body.sun, now));
    final next = ingresses(Body.sun, now, now.add(const Duration(days: 33))).firstOrNull;
    final last = ingresses(Body.sun, now.subtract(const Duration(days: 33)), now).lastOrNull;
    final year = DateTime.now().year;
    final yearIngresses = ingresses(Body.sun, DateTime.utc(year), DateTime.utc(year + 1));
    final s = signs[sun];
    final subject = access?.subject;
    final accent = access == null ? theme.colorScheme.primary : alterAccent(context, access!);
    final house = subject?.houseOf(longitudeOf(Body.sun, now));
    final hits = subject == null ? const <TransitHit>[] : transitsAt(subject, now).where((t) => t.transit == Body.sun).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AstroHero(
          accent: accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr(context, 'SUN TRANSIT', 'TRÁNSITO SOLAR'), style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.1)),
              const SizedBox(height: 6),
              Row(
                children: [
                  AstroGlyph(s.glyph, size: 40, color: accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(es ? 'El Sol está en ${s.name.es}' : 'The Sun is in ${s.name.en}', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                        Text(formatPosition(longitudeOf(Body.sun, now), es), style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(es ? 'Una temporada asociada con ${s.keywords.es}.' : 'A season associated with ${s.keywords.en}.', style: const TextStyle(height: 1.45)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _SunStep(label: tr(context, 'Previous', 'Anterior'), sign: (sun + 11) % 12, date: last?.utc, accent: accent)),
                  Expanded(child: _SunStep(label: tr(context, 'Next', 'Siguiente'), sign: (sun + 1) % 12, date: next?.utc, accent: accent)),
                ],
              ),
            ],
          ),
        ),
        if (subject != null && house != null) ...[
          const SizedBox(height: 12),
          AstroCard(
            title: es ? 'Para ${access!.name}' : 'For ${access!.name}',
            emoji: '☀️',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  es
                      ? 'El Sol ilumina su casa ${houseOrdinal(house, true)}${subject.hasHouses ? '' : ' solar'}: ${houses[house - 1].area.es}.'
                      : 'The Sun lights up their ${houseOrdinal(house, false)}${subject.hasHouses ? '' : ' solar'} house: ${houses[house - 1].area.en}.',
                  style: const TextStyle(height: 1.45),
                ),
                for (final h in hits) ...[const SizedBox(height: 6), Text('• ${h.label(es)}: ${h.meaning(es)}', style: const TextStyle(height: 1.4))],
              ],
            ),
          ),
        ],
        PrismSectionHeader(title: es ? 'CALENDARIO SOLAR $year' : 'SOLAR CALENDAR $year'),
        PrismSurface(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final i in yearIngresses)
                PrismListRow(
                  dense: true,
                  selected: i.sign == sun,
                  leading: SizedBox(width: 30, child: Center(child: AstroGlyph(signs[i.sign].glyph, size: 20, color: accent))),
                  title: Text(signs[i.sign].name.of(es)),
                  subtitle: Text('${DateFormat.MMMMd(locale).format(i.utc.toLocal())} · ${context.formatTime(i.utc.toLocal())} · ${signs[i.sign].keywords.of(es)}'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SunStep extends StatelessWidget {
  const _SunStep({required this.label, required this.sign, required this.date, required this.accent});
  final String label;
  final int sign;
  final DateTime? date;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final es = astroEs(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        Row(children: [AstroGlyph(signs[sign].glyph, size: 16, color: accent), const SizedBox(width: 4), Text(signs[sign].name.of(es), style: const TextStyle(fontWeight: FontWeight.w600))]),
        if (date != null) Text(DateFormat.MMMd(context.dateLocale).format(date!.toLocal()), style: theme.textTheme.bodySmall),
      ],
    );
  }
}
