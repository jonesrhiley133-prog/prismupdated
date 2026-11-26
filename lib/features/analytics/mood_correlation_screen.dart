import 'dart:io';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/analytics/cofront_engine.dart';
import 'package:prism_plurality/features/analytics/cofront_screen.dart'
    show rangeSessionsProvider;
import 'package:prism_plurality/features/analytics/correlation_engine.dart';
import 'package:prism_plurality/features/calendar/providers/calendar_providers.dart';
import 'package:prism_plurality/features/calendar/utils/recurrence.dart';
import 'package:prism_plurality/features/cycle/providers/cycle_providers.dart';
import 'package:prism_plurality/features/locations/providers/location_providers.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/mood/providers/mood_providers.dart';
import 'package:prism_plurality/features/work/providers/work_providers.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Splits [start, end) into per-day minutes.
void _addMinutes(Map<DateTime, double> out, DateTime start, DateTime end) {
  var cur = start;
  while (cur.isBefore(end)) {
    final next = DateTime(cur.year, cur.month, cur.day + 1);
    final segEnd = end.isBefore(next) ? end : next;
    final k = _day(cur);
    out[k] = (out[k] ?? 0) + segEnd.difference(cur).inMinutes;
    cur = segEnd;
  }
}

class MoodData {
  MoodData(this.mood, this.series, this.days);
  final DailySeries mood;
  final List<DailySeries> series;
  final List<DateTime> days;
}

/// Builds every daily variable for [range] (and optionally one alter).
final moodDataProvider = Provider.autoDispose
    .family<AsyncValue<MoodData>, (DateTime, DateTime, String?)>((ref, key) {
      final (from, to, alter) = key;
      final sessionsAsync = ref.watch(rangeSessionsProvider((from, to)));
      final moodAsync = ref.watch(moodEntriesProvider);
      if (sessionsAsync.isLoading || moodAsync.isLoading)
        return const AsyncLoading();
      if (sessionsAsync.hasError)
        return AsyncError(
          sessionsAsync.error!,
          sessionsAsync.stackTrace ?? StackTrace.current,
        );
      final sessions = sessionsAsync.value ?? const <FrontingSession>[];
      final tracker =
          ref.watch(trackerRecordsProvider).value ?? const <TrackerRecord>[];
      final members =
          ref.watch(activeMembersProvider).value ?? const <Member>[];
      final preferDisplay = ref.watch(memberNamePreferDisplayProvider);
      final now = DateTime.now();
      final days = [
        for (
          var d = _day(from);
          d.isBefore(to) && !d.isAfter(now);
          d = DateTime(d.year, d.month, d.day + 1)
        )
          d,
      ];
      bool inRange(DateTime t) => !t.isBefore(from) && t.isBefore(to);

      // Mood, energy, stress.
      final moodSum = <DateTime, (double, int)>{},
          energy = <DateTime, (double, int)>{},
          stress = <DateTime, (double, int)>{},
          moodSleep = <DateTime, (double, int)>{};
      void acc(Map<DateTime, (double, int)> m, DateTime d, num? v) {
        if (v == null) return;
        final c = m[d];
        m[d] = ((c?.$1 ?? 0) + v, (c?.$2 ?? 0) + 1);
      }

      for (final e in moodAsync.value ?? const []) {
        if (!inRange(e.recordedAt) || (alter != null && e.memberId != alter))
          continue;
        final d = _day(e.recordedAt);
        acc(moodSum, d, e.mood);
        acc(energy, d, e.energy);
        acc(stress, d, e.stress);
        acc(moodSleep, d, e.sleepQuality);
      }
      Map<DateTime, double> avg(Map<DateTime, (double, int)> m) => {
        for (final e in m.entries) e.key: e.value.$1 / e.value.$2,
      };
      final mood = DailySeries(
        id: 'mood',
        group: 'mood',
        en: 'Mood',
        es: 'Ánimo',
        values: avg(moodSum),
      );
      final out = <DailySeries>[
        DailySeries(
          id: 'energy',
          group: 'mood',
          en: 'Energy',
          es: 'Energía',
          values: avg(energy),
        ),
        DailySeries(
          id: 'stress',
          group: 'mood',
          en: 'Stress',
          es: 'Estrés',
          values: avg(stress),
        ),
      ];

      // Fronting.
      final frontMin = <DateTime, double>{},
          switches = <DateTime, double>{},
          perAlter = <String, Map<DateTime, double>>{};
      final sleepMin = <DateTime, double>{}, sleepQ = <DateTime, double>{};
      for (final s in sessions) {
        if (s.isDeleted) continue;
        final end = s.endTime ?? now;
        if (s.sessionType == SessionType.sleep) {
          final wake = _day(end);
          sleepMin[wake] =
              (sleepMin[wake] ?? 0) + end.difference(s.startTime).inMinutes;
          if (s.quality != null && s.quality != SleepQuality.unknown)
            sleepQ[wake] = s.quality!.index.toDouble();
          continue;
        }
        if (alter == null || s.memberId == alter) {
          _addMinutes(
            frontMin,
            s.startTime.isBefore(from) ? from : s.startTime,
            end.isAfter(to) ? to : end,
          );
          if (inRange(s.startTime))
            switches[_day(s.startTime)] =
                (switches[_day(s.startTime)] ?? 0) + 1;
        }
        if (s.memberId != null)
          _addMinutes(
            perAlter.putIfAbsent(s.memberId!, () => {}),
            s.startTime.isBefore(from) ? from : s.startTime,
            end.isAfter(to) ? to : end,
          );
      }
      out.addAll([
        DailySeries(
          id: 'front.min',
          group: 'fronting',
          en: alter == null
              ? 'Time with someone fronting'
              : 'Time this alter fronted',
          es: alter == null
              ? 'Tiempo con alguien al frente'
              : 'Tiempo al frente de este alter',
          values: frontMin,
          unit: 'min',
          zeroFill: true,
        ),
        DailySeries(
          id: 'front.switches',
          group: 'fronting',
          en: 'Switches',
          es: 'Cambios',
          values: switches,
          zeroFill: true,
        ),
      ]);
      final coPeriods = findCoFronting(sessions, from: from, to: to, now: now);
      final coMin = <DateTime, double>{};
      final comboMin = <String, Map<DateTime, double>>{};
      for (final p in coPeriods) {
        if (alter != null && !p.members.contains(alter)) continue;
        _addMinutes(coMin, p.start, p.end);
        _addMinutes(comboMin.putIfAbsent(p.key, () => {}), p.start, p.end);
      }
      out.add(
        DailySeries(
          id: 'cofront.min',
          group: 'fronting',
          en: 'Co-fronting time',
          es: 'Tiempo de co-frente',
          values: coMin,
          unit: 'min',
          zeroFill: true,
        ),
      );
      final names = {
        for (final m in members)
          m.id: m.effectiveName(preferDisplayName: preferDisplay),
      };
      for (final m in members) {
        final v = perAlter[m.id];
        if (v == null || v.isEmpty || m.id == alter) continue;
        out.add(
          DailySeries(
            id: 'alter.${m.id}',
            group: 'alters',
            en: '${names[m.id]} fronting',
            es: '${names[m.id]} al frente',
            values: v,
            unit: 'min',
            zeroFill: true,
          ),
        );
      }
      final topCombos =
          (comboMin.entries.toList()
                ..sort((a, b) => b.value.length - a.value.length))
              .take(5);
      for (final c in topCombos) {
        final label = c.key
            .split('+')
            .map((id) => names[id] ?? '?')
            .join(' + ');
        out.add(
          DailySeries(
            id: 'combo.${c.key}',
            group: 'alters',
            en: 'Co-fronting: $label',
            es: 'Co-frente: $label',
            values: c.value,
            unit: 'min',
            zeroFill: true,
          ),
        );
      }

      // Sleep.
      out.addAll([
        DailySeries(
          id: 'sleep.min',
          group: 'sleep',
          en: 'Sleep duration',
          es: 'Duración del sueño',
          values: {for (final e in sleepMin.entries) e.key: e.value / 60},
          unit: 'h',
        ),
        DailySeries(
          id: 'sleep.q',
          group: 'sleep',
          en: 'Sleep quality (logged sleep)',
          es: 'Calidad del sueño (registro)',
          values: sleepQ,
        ),
        DailySeries(
          id: 'sleep.mood',
          group: 'sleep',
          en: 'Sleep quality (check-ins)',
          es: 'Calidad del sueño (registros de ánimo)',
          values: avg(moodSleep),
        ),
      ]);

      // Tracker-based variables.
      final hyd = <DateTime, double>{},
          meals = <DateTime, double>{},
          kcal = <DateTime, double>{},
          caffeine = <DateTime, double>{};
      final workout = <DateTime, double>{},
          journal = <DateTime, double>{},
          dreams = <DateTime, double>{},
          nightmares = <DateTime, double>{};
      final social = <DateTime, double>{},
          study = <DateTime, double>{},
          posts = <DateTime, double>{};
      for (final r in tracker) {
        final t = r.occurredAt ?? r.createdAt;
        if (!inRange(t)) continue;
        if (alter != null &&
            r.memberId != null &&
            r.memberId != alter &&
            !r.strings('members').contains(alter))
          continue;
        final d = _day(t);
        void inc(Map<DateTime, double> m, [double by = 1]) =>
            m[d] = (m[d] ?? 0) + by;
        switch (r.kind) {
          case TrackerKind.nutriDrink:
            inc(hyd, (r.integer('ml') ?? 0).toDouble());
          case TrackerKind.nutriMeal:
            inc(meals);
            final n = r.fields['n'];
            if (n is Map && n['kcal'] is num)
              inc(kcal, (n['kcal'] as num).toDouble());
            if (n is Map && n['caffeine'] is num)
              inc(caffeine, (n['caffeine'] as num).toDouble());
          case TrackerKind.fitnessWorkout:
            inc(
              workout,
              (r.integer('minutes') ??
                      (r.endedAt?.difference(t).inMinutes ?? 30))
                  .toDouble(),
            );
          case TrackerKind.journalEntry:
            inc(journal);
          case TrackerKind.dreamEntry:
            inc(dreams);
            if (r.strings('types').contains('nightmare')) inc(nightmares);
          case TrackerKind.relationshipEvent:
            inc(social);
          case TrackerKind.schoolStudy:
            inc(
              study,
              (r.integer('minutes') ??
                      (r.endedAt?.difference(t).inMinutes ?? 0))
                  .toDouble(),
            );
          case 'social.post':
            inc(posts);
        }
      }
      out.addAll([
        DailySeries(
          id: 'hydration',
          group: 'nutrition',
          en: 'Hydration',
          es: 'Hidratación',
          values: hyd,
          unit: 'ml',
          zeroFill: true,
        ),
        DailySeries(
          id: 'meals',
          group: 'nutrition',
          en: 'Meals logged',
          es: 'Comidas registradas',
          values: meals,
          zeroFill: true,
        ),
        DailySeries(
          id: 'kcal',
          group: 'nutrition',
          en: 'Energy intake (where recorded)',
          es: 'Energía ingerida (si se registró)',
          values: kcal,
          unit: 'kcal',
        ),
        DailySeries(
          id: 'caffeine',
          group: 'nutrition',
          en: 'Caffeine (where recorded)',
          es: 'Cafeína (si se registró)',
          values: caffeine,
          unit: 'mg',
        ),
        DailySeries(
          id: 'workout',
          group: 'activity',
          en: 'Activity minutes',
          es: 'Minutos de actividad',
          values: workout,
          unit: 'min',
          zeroFill: true,
        ),
        DailySeries(
          id: 'social',
          group: 'social',
          en: 'Social / relationship moments',
          es: 'Momentos sociales',
          values: social,
          zeroFill: true,
        ),
        DailySeries(
          id: 'posts',
          group: 'social',
          en: 'Bulletin Board posts',
          es: 'Publicaciones del tablón',
          values: posts,
          zeroFill: true,
        ),
        DailySeries(
          id: 'study',
          group: 'school',
          en: 'Study minutes',
          es: 'Minutos de estudio',
          values: study,
          unit: 'min',
          zeroFill: true,
        ),
        DailySeries(
          id: 'journal',
          group: 'journal',
          en: 'Journal entries',
          es: 'Entradas del diario',
          values: journal,
          zeroFill: true,
        ),
        DailySeries(
          id: 'dreams',
          group: 'dreams',
          en: 'Dreams recorded',
          es: 'Sueños registrados',
          values: dreams,
          zeroFill: true,
        ),
        DailySeries(
          id: 'nightmares',
          group: 'dreams',
          en: 'Nightmares',
          es: 'Pesadillas',
          values: nightmares,
          zeroFill: true,
        ),
      ]);

      // Work.
      final workMin = <DateTime, double>{};
      for (final w in ref.watch(workSessionsProvider).value ?? const []) {
        if (alter != null && w.memberId != null && w.memberId != alter)
          continue;
        final end = w.endedAt ?? now;
        if (!end.isAfter(from) || !w.startedAt.isBefore(to)) continue;
        _addMinutes(
          workMin,
          w.startedAt.isBefore(from) ? from : w.startedAt,
          end.isAfter(to) ? to : end,
        );
      }
      out.add(
        DailySeries(
          id: 'work',
          group: 'school',
          en: 'Work minutes',
          es: 'Minutos de trabajo',
          values: workMin,
          unit: 'min',
          zeroFill: true,
        ),
      );

      // Locations.
      final locNames = {
        for (final l in ref.watch(savedLocationsProvider).value ?? const [])
          l.id: l.name,
      };
      final perLoc = <String, Map<DateTime, double>>{};
      for (final s in ref.watch(locationSessionsProvider).value ?? const []) {
        final end = s.endedAt ?? now;
        if (!end.isAfter(from) || !s.startedAt.isBefore(to)) continue;
        _addMinutes(
          perLoc.putIfAbsent(s.locationId, () => {}),
          s.startedAt.isBefore(from) ? from : s.startedAt,
          end.isAfter(to) ? to : end,
        );
      }
      for (final e
          in (perLoc.entries.toList()
                ..sort((a, b) => b.value.length - a.value.length))
              .take(6)) {
        out.add(
          DailySeries(
            id: 'loc.${e.key}',
            group: 'locations',
            en: 'Time at ${locNames[e.key] ?? '?'}',
            es: 'Tiempo en ${locNames[e.key] ?? '?'}',
            values: e.value,
            unit: 'min',
            zeroFill: true,
          ),
        );
      }

      // Cycle (only when used).
      final cycle = ref.watch(cycleEntriesProvider).value ?? const [];
      if (cycle.isNotEmpty) {
        final flow = <DateTime, double>{}, symptoms = <DateTime, double>{};
        for (final c in cycle) {
          final d = DateTime.tryParse(c.date);
          if (d == null ||
              !inRange(d) ||
              (alter != null && c.memberId != null && c.memberId != alter))
            continue;
          flow[_day(d)] = c.flow.toDouble();
          symptoms[_day(d)] = c.symptoms.length.toDouble();
        }
        out.addAll([
          DailySeries(
            id: 'cycle.flow',
            group: 'cycle',
            en: 'Cycle flow',
            es: 'Flujo del ciclo',
            values: flow,
            zeroFill: true,
          ),
          DailySeries(
            id: 'cycle.symptoms',
            group: 'cycle',
            en: 'Cycle symptoms',
            es: 'Síntomas del ciclo',
            values: symptoms,
          ),
        ]);
      }

      // Calendar.
      final events = <DateTime, double>{};
      for (final o in expandCalendarEvents(
        ref.watch(calendarEventsProvider).value ?? const [],
        from,
        to,
      )) {
        if (alter != null &&
            o.event.memberIds.isNotEmpty &&
            !o.event.memberIds.contains(alter))
          continue;
        events[_day(o.start)] = (events[_day(o.start)] ?? 0) + 1;
      }
      out.add(
        DailySeries(
          id: 'events',
          group: 'calendar',
          en: 'Calendar events',
          es: 'Eventos del calendario',
          values: events,
          zeroFill: true,
        ),
      );

      return AsyncData(MoodData(mood, out, days));
    });

const _groups = [
  ('fronting', 'Fronting', 'Al frente'),
  ('alters', 'Alters & co-fronting', 'Alters y co-frente'),
  ('sleep', 'Sleep', 'Sueño'),
  ('nutrition', 'Nutrition', 'Nutrición'),
  ('activity', 'Activity', 'Actividad'),
  ('cycle', 'Cycle', 'Ciclo'),
  ('locations', 'Places', 'Lugares'),
  ('social', 'Social', 'Social'),
  ('school', 'School & work', 'Estudio y trabajo'),
  ('journal', 'Journal', 'Diario'),
  ('dreams', 'Dreams', 'Sueños'),
  ('calendar', 'Calendar', 'Calendario'),
  ('mood', 'Energy & stress', 'Energía y estrés'),
];

class MoodCorrelationScreen extends ConsumerStatefulWidget {
  const MoodCorrelationScreen({super.key});
  @override
  ConsumerState<MoodCorrelationScreen> createState() =>
      _MoodCorrelationScreenState();
}

class _MoodCorrelationScreenState extends ConsumerState<MoodCorrelationScreen> {
  int _days = 90;
  DateTimeRange? _custom;
  String? _alter;
  int _lag = 0;
  String? _group;
  final List<String> _selected = [];

  (DateTime, DateTime) get _range {
    if (_custom != null)
      return (
        _custom!.start,
        DateTime(_custom!.end.year, _custom!.end.month, _custom!.end.day + 1),
      );
    final now = DateTime.now();
    return (
      DateTime(now.year, now.month, now.day - _days + 1),
      DateTime(now.year, now.month, now.day + 1),
    );
  }

  String _label(DailySeries s) => tr(context, s.en, s.es);

  @override
  Widget build(BuildContext context) {
    final r = _range;
    final data = ref.watch(moodDataProvider((r.$1, r.$2, _alter)));
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(context, 'Mood correlations', 'Correlaciones de ánimo'),
        showBackButton: true,
        actions: [
          PrismTopBarAction(
            icon: AppIcons.downloadOutlined,
            tooltip: tr(context, 'Download report', 'Descargar informe'),
            onPressed: data.value == null ? null : () => _export(data.value!),
          ),
        ],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      body: data.when(
        loading: () => const PrismLoadingState(),
        error: (e, _) => Center(child: Text(context.l10n.errorWithDetail(e))),
        data: (d) {
          final moodDays = d.mood.values.length;
          final corrs = [
            for (final s in d.series)
              if (correlate(d.mood, s, d.days, lag: _lag) case final c?
                  when c.n >= 3)
                c,
          ]..sort((a, b) => b.r.abs().compareTo(a.r.abs()));
          final shown = [
            for (final c in corrs)
              if (_group == null || c.series.group == _group) c,
          ];
          return ListView(
            padding: EdgeInsets.only(
              top: 8,
              bottom: NavBarInset.of(context) + 24,
            ),
            children: [
              _controls(),
              const SizedBox(height: 10),
              _disclaimer(),
              const SizedBox(height: 10),
              if (moodDays < 7)
                EmptyState(
                  icon: Icon(PhosphorIcons.smiley()),
                  title: tr(
                    context,
                    'Not enough mood check-ins yet',
                    'Aún no hay suficientes registros de ánimo',
                  ),
                  subtitle: tr(
                    context,
                    'There are $moodDays days with mood data in this range. Patterns become meaningful after a couple of weeks of check-ins.',
                    'Hay $moodDays días con datos de ánimo en este rango. Los patrones tienen sentido tras un par de semanas de registros.',
                  ),
                )
              else ...[
                _insights(d, corrs),
                const SizedBox(height: 12),
                _chart(d),
                const SizedBox(height: 12),
                _weekday(d),
                const SizedBox(height: 12),
                Text(
                  tr(
                    context,
                    'Everything compared with mood',
                    'Todo comparado con el ánimo',
                  ),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: PrismChip(
                          label: tr(context, 'All', 'Todo'),
                          selected: _group == null,
                          onTap: () => setState(() => _group = null),
                        ),
                      ),
                      for (final g in _groups)
                        if (corrs.any((c) => c.series.group == g.$1))
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: PrismChip(
                              label: tr(context, g.$2, g.$3),
                              selected: _group == g.$1,
                              onTap: () => setState(
                                () => _group = _group == g.$1 ? null : g.$1,
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                for (final c in shown)
                  _CorrRow(
                    c: c,
                    label: _label(c.series),
                    selected: _selected.contains(c.series.id),
                    onTap: () => setState(() {
                      if (_selected.contains(c.series.id)) {
                        _selected.remove(c.series.id);
                      } else {
                        if (_selected.length >= 3) _selected.removeAt(0);
                        _selected.add(c.series.id);
                      }
                    }),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _controls() {
    final members = ref.watch(activeMembersProvider).value ?? const <Member>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (d, label) in [
              (30, tr(context, '30 days', '30 días')),
              (90, tr(context, '90 days', '90 días')),
              (180, tr(context, '6 months', '6 meses')),
              (365, tr(context, '1 year', '1 año')),
            ])
              PrismChip(
                label: label,
                selected: _custom == null && _days == d,
                onTap: () => setState(() {
                  _days = d;
                  _custom = null;
                }),
              ),
            PrismChip(
              label: _custom == null
                  ? tr(context, 'Custom…', 'Personalizado…')
                  : '${DateFormat.MMMd(context.dateLocale).format(_custom!.start)} – ${DateFormat.MMMd(context.dateLocale).format(_custom!.end)}',
              selected: _custom != null,
              onTap: () async {
                final r = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (r != null) setState(() => _custom = r);
              },
            ),
          ],
        ),
        if (members.isNotEmpty)
          TrackerMemberPicker(
            label: tr(context, 'Whose mood', 'Ánimo de'),
            value: _alter,
            onChanged: (m) => setState(() => _alter = m),
          ),
        const SizedBox(height: 6),
        PrismSegmentedControl<int>(
          segments: [
            PrismSegment(
              value: 0,
              label: tr(context, 'Same-day mood', 'Ánimo del mismo día'),
            ),
            PrismSegment(
              value: 1,
              label: tr(context, 'Next-day mood', 'Ánimo del día siguiente'),
            ),
          ],
          selected: _lag,
          onChanged: (v) => setState(() => _lag = v),
        ),
      ],
    );
  }

  Widget _disclaimer() => PrismSurface(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(AppIcons.infoOutline, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            tr(
              context,
              'These show which things tend to move together with mood in your records. A link here does not mean one causes the other, and missing check-ins can skew results. The number of days behind each result is shown.',
              'Esto muestra qué cosas tienden a cambiar junto con el ánimo en tus registros. Que estén relacionadas no significa que una cause la otra, y los registros que faltan pueden sesgar los resultados. Se indica cuántos días respaldan cada resultado.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    ),
  );

  String _confLabel(Confidence c) => switch (c) {
    Confidence.insufficient => tr(context, 'not enough data', 'pocos datos'),
    Confidence.low => tr(context, 'low confidence', 'confianza baja'),
    Confidence.moderate => tr(
      context,
      'moderate confidence',
      'confianza moderada',
    ),
    Confidence.high => tr(context, 'high confidence', 'confianza alta'),
  };

  Widget _insights(MoodData d, List<Correlation> corrs) {
    final theme = Theme.of(context);
    final items = <String>[];
    final solid = [
      for (final c in corrs)
        if (c.confidence.index >= Confidence.moderate.index && c.r.abs() >= 0.2)
          c,
    ];
    final day = _lag == 0
        ? tr(context, 'the same day', 'el mismo día')
        : tr(context, 'the next day', 'al día siguiente');
    for (final c in solid.take(4)) {
      final split = splitByMedian(d.mood, c.series, d.days);
      final up = c.r > 0;
      final base = tr(
        context,
        'On days with more “${c.series.en.toLowerCase()}”, mood $day tended to be ${up ? 'higher' : 'lower'} (${c.strength} relationship, ${c.n} days, ${_confLabel(c.confidence)}).',
        'Los días con más «${c.series.es.toLowerCase()}», el ánimo $day tendió a ser ${up ? 'más alto' : 'más bajo'} (relación ${c.strength}, ${c.n} días, ${_confLabel(c.confidence)}).',
      );
      items.add(
        split == null
            ? base
            : '$base ${tr(context, 'Average mood ${split.$1.toStringAsFixed(1)} vs ${split.$2.toStringAsFixed(1)}.', 'Ánimo medio ${split.$1.toStringAsFixed(1)} frente a ${split.$2.toStringAsFixed(1)}.')}',
      );
    }
    final wd =
        weekdayPattern(d.mood).entries.where((e) => e.value.$2 >= 3).toList()
          ..sort((a, b) => b.value.$1.compareTo(a.value.$1));
    if (wd.length >= 4 && wd.first.value.$1 - wd.last.value.$1 >= 0.4) {
      final f = DateFormat.EEEE(context.dateLocale);
      items.add(
        tr(
          context,
          '${f.format(DateTime(2024, 1, wd.first.key))}s have had the highest average mood (${wd.first.value.$1.toStringAsFixed(1)}) and ${f.format(DateTime(2024, 1, wd.last.key))}s the lowest (${wd.last.value.$1.toStringAsFixed(1)}).',
          'Los ${f.format(DateTime(2024, 1, wd.first.key))} han tenido el ánimo medio más alto (${wd.first.value.$1.toStringAsFixed(1)}) y los ${f.format(DateTime(2024, 1, wd.last.key))} el más bajo (${wd.last.value.$1.toStringAsFixed(1)}).',
        ),
      );
    }
    if (items.isEmpty) {
      items.add(
        tr(
          context,
          'No clear patterns stand out yet. That’s common — keep logging and check back, or try a longer range.',
          'Aún no destacan patrones claros. Es habitual: sigue registrando y vuelve a mirar, o prueba un rango más largo.',
        ),
      );
    }
    items.add(
      tr(
        context,
        'Mood data covers ${d.mood.values.length} of ${d.days.length} days in this range.',
        'Hay datos de ánimo en ${d.mood.values.length} de ${d.days.length} días de este rango.',
      ),
    );
    return PrismSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                PhosphorIcons.sparkle(),
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                tr(context, 'Insights', 'Observaciones'),
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
          Text(
            tr(
              context,
              'Written automatically on this device from your numbers. Observations, not facts or advice.',
              'Escritas automáticamente en este dispositivo a partir de tus datos. Son observaciones, no hechos ni consejos.',
            ),
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: 8),
          for (final s in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('• $s'),
            ),
        ],
      ),
    );
  }

  Widget _chart(MoodData d) {
    final theme = Theme.of(context);
    final sel = [
      for (final id in _selected)
        ?d.series.where((s) => s.id == id).firstOrNull,
    ];
    const colors = [Color(0xFFE15759), Color(0xFF4E79A7), Color(0xFF59A14F)];
    List<FlSpot> norm(DailySeries s) {
      final vals = [for (final day in d.days) ?s.at(day)];
      if (vals.length < 2) return const [];
      final mean = vals.reduce((a, b) => a + b) / vals.length;
      final sd = math.sqrt(
        vals.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
            vals.length,
      );
      return [
        for (var i = 0; i < d.days.length; i++)
          if (s.at(d.days[i]) case final v?)
            FlSpot(i.toDouble(), sd == 0 ? 0 : ((v - mean) / sd).clamp(-3, 3)),
      ];
    }

    return PrismSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr(context, 'Compare over time', 'Comparar en el tiempo'),
            style: theme.textTheme.titleSmall,
          ),
          Text(
            sel.isEmpty
                ? tr(
                    context,
                    'Tap up to three variables below to overlay them on mood. Lines are scaled so different units can be compared.',
                    'Toca hasta tres variables abajo para superponerlas. Las líneas se escalan para comparar unidades distintas.',
                  )
                : tr(
                    context,
                    'Scaled values (0 = usual for this range).',
                    'Valores escalados (0 = lo habitual en este rango).',
                  ),
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 190,
            child: LineChart(
              LineChartData(
                minY: -3,
                maxY: 3,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(
                  topTitles: AxisTitles(),
                  rightTitles: AxisTitles(),
                  leftTitles: AxisTitles(),
                  bottomTitles: AxisTitles(),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: norm(d.mood),
                    isCurved: true,
                    color: theme.colorScheme.primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                  ),
                  for (final (i, s) in sel.indexed)
                    LineChartBarData(
                      spots: norm(s),
                      isCurved: true,
                      color: colors[i],
                      barWidth: 2,
                      dashArray: [6, 3],
                      dotData: const FlDotData(show: false),
                    ),
                ],
              ),
            ),
          ),
          Wrap(
            spacing: 12,
            children: [
              Text(
                '— ${tr(context, 'Mood', 'Ánimo')}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              for (final (i, s) in sel.indexed)
                Text(
                  '- - ${_label(s)}',
                  style: theme.textTheme.labelSmall?.copyWith(color: colors[i]),
                ),
            ],
          ),
          if (sel.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              tr(
                context,
                'Each dot is a day: ${_label(sel.first)} vs mood',
                'Cada punto es un día: ${_label(sel.first)} frente a ánimo',
              ),
              style: theme.textTheme.labelMedium,
            ),
            SizedBox(
              height: 180,
              child: ScatterChart(
                ScatterChartData(
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  titlesData: const FlTitlesData(
                    topTitles: AxisTitles(),
                    rightTitles: AxisTitles(),
                  ),
                  scatterSpots: [
                    for (final day in d.days)
                      if (sel.first.at(day) case final x?)
                        if (d.mood.at(
                              _lag == 0
                                  ? day
                                  : DateTime(day.year, day.month, day.day + 1),
                            )
                            case final y?)
                          ScatterSpot(
                            x,
                            y,
                            dotPainter: FlDotCirclePainter(
                              radius: 4,
                              color: colors[0].withValues(alpha: 0.6),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _weekday(MoodData d) {
    final p = weekdayPattern(d.mood);
    final theme = Theme.of(context);
    return PrismSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr(context, 'Recurring weekly pattern', 'Patrón semanal'),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                minY: 0,
                maxY: 5,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 1,
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, m) => Text(
                        DateFormat.E(
                          context.dateLocale,
                        ).format(DateTime(2024, 1, v.toInt())),
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  ),
                ),
                barGroups: [
                  for (var w = 1; w <= 7; w++)
                    BarChartGroupData(
                      x: w,
                      barRods: [
                        BarChartRodData(
                          toY: p[w]?.$1 ?? 0,
                          width: 18,
                          color: theme.colorScheme.primary.withValues(
                            alpha: (p[w]?.$2 ?? 0) >= 3 ? 1 : 0.35,
                          ),
                          borderRadius: prismCorners(context, 4),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          Text(
            tr(
              context,
              'Faded bars have fewer than 3 days of data.',
              'Las barras tenues tienen menos de 3 días de datos.',
            ),
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  Future<void> _export(MoodData d) async {
    final f = DateFormat('yyyy-MM-dd');
    final csv = StringBuffer(
      'date,mood,${d.series.map((s) => '"${s.en.replaceAll('"', "'")}"').join(',')}\n',
    );
    for (final day in d.days) {
      csv.writeln(
        '${f.format(day)},${d.mood.at(day)?.toStringAsFixed(2) ?? ''},${d.series.map((s) => s.at(day)?.toStringAsFixed(1) ?? '').join(',')}',
      );
    }
    final corrs = [
      for (final s in d.series) ?correlate(d.mood, s, d.days, lag: _lag),
    ]..sort((a, b) => b.r.abs().compareTo(a.r.abs()));
    final summary = StringBuffer()
      ..writeln('Prism mood correlation report')
      ..writeln(
        '${f.format(d.days.first)} to ${f.format(d.days.last)} · ${_lag == 0 ? 'same-day' : 'next-day'} mood · ${_alter == null ? 'whole system' : 'one alter'}',
      )
      ..writeln('Correlation is not causation. n = days with both values.')
      ..writeln();
    for (final c in corrs) {
      summary.writeln(
        '${c.series.en}: r = ${c.r.toStringAsFixed(2)} (${c.strength}), n = ${c.n}, ${c.confidence.name} confidence',
      );
    }
    try {
      final dir = await getTemporaryDirectory();
      final csvFile = File(
        '${dir.path}/prism-mood-${f.format(DateTime.now())}.csv',
      )..writeAsStringSync(csv.toString());
      final txtFile = File(
        '${dir.path}/prism-mood-summary-${f.format(DateTime.now())}.txt',
      )..writeAsStringSync(summary.toString());
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(txtFile.path), XFile(csvFile.path)],
          subject: 'Prism mood correlation report',
        ),
      );
    } catch (_) {
      await SharePlus.instance.share(ShareParams(text: summary.toString()));
    }
  }
}

class _CorrRow extends StatelessWidget {
  const _CorrRow({
    required this.c,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final Correlation c;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = c.r >= 0 ? const Color(0xFF3BA55C) : const Color(0xFFE15759);
    final confColor = switch (c.confidence) {
      Confidence.high => const Color(0xFF3BA55C),
      Confidence.moderate => const Color(0xFFFAA61A),
      Confidence.low => const Color(0xFF95A5A6),
      Confidence.insufficient => const Color(0xFFBDC3C7),
    };
    return PrismSurface(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: onTap,
      borderColor: selected ? theme.colorScheme.primary : null,
      child: Row(
        children: [
          SizedBox(
            width: 70,
            height: 14,
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: c.r < 0
                          ? c.r.abs().clamp(0.04, 1).toDouble()
                          : 0,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: prismCorners(context, 4),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 2,
                  height: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: c.r >= 0 ? c.r.clamp(0.04, 1).toDouble() : 0,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: prismCorners(context, 4),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
                Text(
                  '${c.r >= 0 ? tr(context, 'moves with mood', 'va con el ánimo') : tr(context, 'moves opposite to mood', 'va en contra del ánimo')} · r = ${c.r.toStringAsFixed(2)} · ${tr(context, '${c.n} days', '${c.n} días')}',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: confColor.withValues(alpha: 0.18),
              borderRadius: prismCorners(context, 8),
            ),
            child: Text(switch (c.confidence) {
              Confidence.high => tr(context, 'High', 'Alta'),
              Confidence.moderate => tr(context, 'Moderate', 'Media'),
              Confidence.low => tr(context, 'Low', 'Baja'),
              Confidence.insufficient => tr(context, 'Too few', 'Pocos'),
            }, style: theme.textTheme.labelSmall?.copyWith(color: confColor)),
          ),
        ],
      ),
    );
  }
}
