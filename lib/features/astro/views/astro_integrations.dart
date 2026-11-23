import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/features/feature_state.dart';
import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/astro/content/horoscope.dart';
import 'package:prism_plurality/features/astro/content/zodiac.dart';
import 'package:prism_plurality/features/astro/data/astro_model.dart';
import 'package:prism_plurality/features/astro/engine/events.dart';
import 'package:prism_plurality/features/astro/views/astro_widgets.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Astro is on and its calendar layer wanted.
final _astroCalendarOn = Provider<bool>((ref) => ref.watch(featureEnabledProvider('astro')) && ref.watch(astroSettingsProvider).calendar);

final _monthEvents = <String, List<SkyEvent>>{};
final _monthLunations = <String, List<Lunation>>{};

List<SkyEvent> _eventsFor(DateTime day, bool es) {
  final key = '${day.year}-${day.month}|$es';
  return _monthEvents.putIfAbsent(key, () {
    final start = DateTime(day.year, day.month);
    return skyEvents(start.toUtc(), DateTime(day.year, day.month + 1).toUtc(), es);
  });
}

List<Lunation> _lunationsFor(DateTime day) => _monthLunations.putIfAbsent('${day.year}-${day.month}', () {
  final start = DateTime(day.year, day.month);
  return lunations(start.toUtc(), DateTime(day.year, day.month + 1).toUtc());
});

bool _sameLocalDay(DateTime utc, DateTime day) {
  final t = utc.toLocal();
  return t.year == day.year && t.month == day.month && t.day == day.day;
}

/// A moon-phase glyph on Calendar month cells for new, quarter and full
/// moons.
class AstroDayGlyph extends ConsumerWidget {
  const AstroDayGlyph({super.key, required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(_astroCalendarOn)) return const SizedBox.shrink();
    final l = _lunationsFor(day).where((l) => _sameLocalDay(l.utc, day)).firstOrNull;
    if (l == null) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(right: 2), child: Text(l.phase.glyph, style: const TextStyle(fontSize: 9)));
  }
}

/// Astrology rows in the Calendar's day view: lunations, eclipses, sign
/// changes, retrogrades, tarot readings and the fronting alter's transits.
class CalendarAstroForDay extends ConsumerWidget {
  const CalendarAstroForDay({super.key, required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(_astroCalendarOn)) return const SizedBox.shrink();
    final es = astroEs(context);
    final theme = Theme.of(context);
    final events = [
      for (final e in _eventsFor(day, es))
        if (_sameLocalDay(e.utc, day)) e,
    ];
    final listed = ref.watch(astroListedProvider);
    final viewers = ref.watch(astroViewersProvider);
    final personal = <SkyEvent>[];
    for (final a in listed) {
      if (!viewers.contains(a.member.id) || a.subject == null) continue;
      final start = DateTime(day.year, day.month, day.day);
      for (final e in exactTransits(a.subject!, start.toUtc(), start.add(const Duration(days: 1)).toUtc(), es)) {
        personal.add(SkyEvent(e.kind, e.utc, e.glyph, '${a.name}: ${e.title}', e.detail, personal: true, body: e.body));
      }
    }
    final readings = <(AstroAccess, TarotReading)>[
      for (final a in listed)
        for (final r in ref.watch(tarotReadingsProvider(a.member.id)))
          if (_sameLocalDay(r.when.toUtc(), day) && (!r.record.isPrivate || viewers.contains(a.member.id))) (a, r),
    ];
    if (events.isEmpty && personal.isEmpty && readings.isEmpty) return const SizedBox.shrink();
    Widget row(String glyph, String text, {VoidCallback? onTap, bool emoji = false}) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(width: 28, child: Center(child: emoji ? Text(glyph, style: const TextStyle(fontSize: 16)) : AstroGlyph(glyph, size: 16, color: theme.colorScheme.secondary))),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in [...events, ...personal])
          row(e.glyph, e.title, emoji: e.glyph.runes.first > 0x1F000, onTap: () => context.push(AppRoutePaths.astro)),
        for (final (a, r) in readings)
          row('🃏', es ? '${a.name}: tirada de tarot (${r.spread.name.es})' : '${a.name}: tarot reading (${r.spread.name.en})', emoji: true, onTap: () => context.push(AppRoutePaths.astroAlter(a.member.id, section: 'tarot'))),
      ],
    );
  }
}

/// The "Astrology" card on an alter's profile. Shows nothing unless the
/// viewer may see this alter's astrology and it isn't hidden.
class AstroProfileModule extends ConsumerWidget {
  const AstroProfileModule({super.key, required this.member, required this.accent, this.showTitle = true});
  final Member member;
  final Color accent;
  final bool showTitle;

  static bool visible(WidgetRef ref, String memberId) =>
      ref.watch(featureEnabledProvider('astro')) && (ref.watch(astroAccessProvider(memberId))?.listed ?? false);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(astroAccessProvider(member.id));
    if (a == null || !a.listed || !ref.watch(featureEnabledProvider('astro'))) return const SizedBox.shrink();
    final es = astroEs(context);
    final theme = Theme.of(context);
    final c = a.chart;
    final s = a.sunSign!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Text(tr(context, 'Astrology', 'Astrología'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: accent)),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            AstroGlyph(signs[s].glyph, size: 34, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(signs[s].name.of(es), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  Text('☉ ${signs[s].name.of(es)} ${es ? 'Sol' : 'Sun'}', style: theme.textTheme.bodySmall),
                  if (c != null && c.moonCertain) Text('☽ ${signs[c.moonSign].name.of(es)} ${es ? 'Luna' : 'Moon'}', style: theme.textTheme.bodySmall),
                  if (c?.risingSign != null) Text('↑ ${signs[c!.risingSign!].name.of(es)} ${es ? 'Ascendente' : 'Rising'}', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        PrismButton(
          density: PrismControlDensity.compact,
          onPressed: () => context.push(AppRoutePaths.astroAlter(member.id)),
          icon: PhosphorIcons.arrowRight(),
          label: tr(context, 'View full astrology profile', 'Ver perfil astrológico completo'),
        ),
      ],
    );
  }
}

/// The fronting alter's astrology on Home (when Astro and the card are on,
/// and their astrology is visible).
class AstroFrontingCard extends ConsumerWidget {
  const AstroFrontingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(featureEnabledProvider('astro')) || !ref.watch(astroSettingsProvider).homeCard) return const SizedBox.shrink();
    final viewers = ref.watch(astroViewersProvider);
    final a = ref.watch(astroListedProvider).where((x) => viewers.contains(x.member.id)).firstOrNull;
    if (a == null || a.subject == null) return const SizedBox.shrink();
    final es = astroEs(context);
    final theme = Theme.of(context);
    final reading = dailyReading(a.subject!, DateTime.now(), es);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AstroHero(
        accent: alterAccent(context, a),
        onTap: () => context.push(AppRoutePaths.astroAlter(a.member.id)),
        child: Row(
          children: [
            AstroAvatar(a, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(es ? 'Al frente: ${a.name}' : 'Currently Fronting: ${a.name}', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  BigThree(access: a, size: 13),
                  const SizedBox(height: 2),
                  Text('✨ ${tr(context, 'Today\'s theme', 'Tema de hoy')}: ${reading.title}', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Icon(PhosphorIcons.caretRight(), size: 16),
          ],
        ),
      ),
    );
  }
}

/// One astrology line for Daily Insights, or null.
String? astroInsight(WidgetRef ref, bool es) {
  if (!ref.watch(featureEnabledProvider('astro')) || !ref.watch(astroSettingsProvider).insights) return null;
  final now = DateTime.now();
  final phase = phaseForDay(now);
  final moon = moonSignForDay(now);
  final s = signs[moon.sign];
  return es
      ? '🌙 ${phaseName(phase, true)} en ${s.name.es}. Tradicionalmente, la Luna en ${s.name.es} se asocia con ${s.keywords.es}; ${phaseThemeTitle(phase, true).toLowerCase()}.'
      : '🌙 ${phaseName(phase, false)} in ${s.name.en}. The Moon in ${s.name.en} is traditionally associated with ${s.keywords.en}; a time for ${phaseThemeTitle(phase, false).toLowerCase()}.';
}
