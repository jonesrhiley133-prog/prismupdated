import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/analytics/cofront_engine.dart';
import 'package:prism_plurality/features/members/providers/member_groups_providers.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Sessions overlapping [from, to).
final rangeSessionsProvider = StreamProvider.autoDispose
    .family<List<FrontingSession>, (DateTime, DateTime)>(
      (ref, r) => ref
          .watch(frontingSessionRepositoryProvider)
          .watchSessionsOverlappingRange(r.$1, r.$2),
    );

enum _Section {
  summary,
  rankings,
  combos,
  pairs,
  monthly,
  calendar,
  timeline,
  certainty,
}

const _sectionPrefsKey = 'prism.cofront.sections.v1';

class CoFrontingScreen extends ConsumerStatefulWidget {
  const CoFrontingScreen({super.key});
  @override
  ConsumerState<CoFrontingScreen> createState() => _CoFrontingScreenState();
}

class _CoFrontingScreenState extends ConsumerState<CoFrontingScreen> {
  int _days = 90;
  DateTimeRange? _custom;
  final Set<String> _alters = {};
  String? _group;
  final Set<CoCertainty> _certainty = {...CoCertainty.values};
  Set<_Section> _sections = {..._Section.values};
  DateTime _calMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance()
        .then((p) {
          final saved = p.getStringList(_sectionPrefsKey);
          if (saved != null && mounted)
            setState(
              () => _sections = {
                for (final s in _Section.values)
                  if (saved.contains(s.name)) s,
              },
            );
        })
        .catchError((_) {});
  }

  (DateTime, DateTime) get _range {
    if (_custom != null)
      return (
        _custom!.start,
        DateTime(_custom!.end.year, _custom!.end.month, _custom!.end.day + 1),
      );
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day + 1);
    return (
      _days == 0
          ? DateTime(2000)
          : DateTime(now.year, now.month, now.day - _days + 1),
      end,
    );
  }

  @override
  Widget build(BuildContext context) {
    final range = _range;
    final async = ref.watch(rangeSessionsProvider(range));
    final prevRange = (
      range.$1.subtract(range.$2.difference(range.$1)),
      range.$1,
    );
    final prevAsync = _days == 0
        ? null
        : ref.watch(rangeSessionsProvider(prevRange));
    final members = {
      for (final m in ref.watch(allMembersProvider).value ?? const <Member>[])
        m.id: m,
    };
    final preferDisplay = ref.watch(memberNamePreferDisplayProvider);
    String name(String id) =>
        members[id]?.effectiveName(preferDisplayName: preferDisplay) ?? '?';
    final groupMembers = _group == null
        ? null
        : ref.watch(transitiveGroupMemberIdsProvider(_group!));
    final groups = ref.watch(allGroupsProvider).value ?? const [];

    bool keep(CoFrontPeriod p) =>
        _certainty.contains(p.certainty) &&
        (_alters.isEmpty || _alters.every(p.members.contains)) &&
        (groupMembers == null || p.members.any(groupMembers.contains));

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(context, 'Co-fronting', 'Co-frente'),
        showBackButton: true,
        actions: [
          PrismTopBarAction(
            icon: PhosphorIcons.slidersHorizontal(),
            tooltip: tr(context, 'Choose sections', 'Elegir secciones'),
            onPressed: _chooseSections,
          ),
          PrismTopBarAction(
            icon: AppIcons.shareOutlined,
            tooltip: tr(context, 'Share report', 'Compartir informe'),
            onPressed: () {
              final sessions = async.value;
              if (sessions == null) return;
              final st = summarize(
                findCoFronting(
                  sessions,
                  from: range.$1,
                  to: range.$2,
                ).where(keep).toList(),
              );
              SharePlus.instance.share(
                ShareParams(
                  text: _report(st, name, range),
                  subject: 'Prism co-fronting report',
                ),
              );
            },
          ),
        ],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      body: async.when(
        loading: () => const PrismLoadingState(),
        error: (e, _) => Center(child: Text(context.l10n.errorWithDetail(e))),
        data: (sessions) {
          final periods = findCoFronting(
            sessions,
            from: range.$1,
            to: range.$2,
          ).where(keep).toList();
          final st = summarize(periods);
          final prev = prevAsync?.value == null
              ? null
              : summarize(
                  findCoFronting(
                    prevAsync!.value!,
                    from: prevRange.$1,
                    to: prevRange.$2,
                  ).where(keep).toList(),
                );
          return ListView(
            padding: EdgeInsets.only(
              top: 8,
              bottom: NavBarInset.of(context) + 24,
            ),
            children: [
              _filters(members, preferDisplay, groups),
              const SizedBox(height: 12),
              if (periods.isEmpty)
                EmptyState(
                  icon: Icon(PhosphorIcons.usersThree()),
                  title: tr(
                    context,
                    'No co-fronting recorded here',
                    'No hay co-frente registrado aquí',
                  ),
                  subtitle: tr(
                    context,
                    'Co-fronting appears when two or more alters have overlapping fronting sessions. Try a wider date range or fewer filters.',
                    'El co-frente aparece cuando dos o más alters tienen sesiones superpuestas. Prueba un rango más amplio o menos filtros.',
                  ),
                )
              else ...[
                if (_sections.contains(_Section.summary)) _summary(st, prev),
                if (_sections.contains(_Section.certainty)) _certaintyCard(st),
                if (_sections.contains(_Section.rankings)) _rankings(st, name),
                if (_sections.contains(_Section.combos)) _combos(st, name),
                if (_sections.contains(_Section.pairs)) _pairs(st, name),
                if (_sections.contains(_Section.monthly)) _monthly(st),
                if (_sections.contains(_Section.calendar)) _calendar(st),
                if (_sections.contains(_Section.timeline)) _timeline(st, name),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _filters(
    Map<String, Member> members,
    bool preferDisplay,
    List groups,
  ) {
    final presets = [
      (30, tr(context, '30 days', '30 días')),
      (90, tr(context, '90 days', '90 días')),
      (365, tr(context, '1 year', '1 año')),
      (0, tr(context, 'All time', 'Todo')),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (d, label) in presets)
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
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final m in members.values.where((m) => m.isActive))
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: PrismChip(
                    label: m.effectiveName(preferDisplayName: preferDisplay),
                    selected: _alters.contains(m.id),
                    onTap: () => setState(
                      () => _alters.contains(m.id)
                          ? _alters.remove(m.id)
                          : _alters.add(m.id),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (groups.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final g in groups)
                  Padding(
                    padding: const EdgeInsets.only(right: 6, top: 6),
                    child: PrismChip(
                      label: '👥 ${g.name}',
                      variant: PrismChipVariant.inline,
                      selected: _group == g.id,
                      onTap: () => setState(
                        () => _group = _group == g.id ? null : g.id as String,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: [
            for (final c in CoCertainty.values)
              PrismChip(
                label: _certLabel(c),
                selected: _certainty.contains(c),
                selectedColor: _certColor(c),
                onTap: () => setState(
                  () => _certainty.contains(c) && _certainty.length > 1
                      ? _certainty.remove(c)
                      : _certainty.add(c),
                ),
              ),
          ],
        ),
      ],
    );
  }

  String _certLabel(CoCertainty c) => switch (c) {
    CoCertainty.confirmed => tr(context, 'Confirmed', 'Confirmado'),
    CoCertainty.uncertain => tr(context, 'Uncertain', 'Incierto'),
    CoCertainty.incomplete => tr(context, 'Incomplete', 'Incompleto'),
  };

  Color _certColor(CoCertainty c) => switch (c) {
    CoCertainty.confirmed => const Color(0xFF3BA55C),
    CoCertainty.uncertain => const Color(0xFFFAA61A),
    CoCertainty.incomplete => const Color(0xFF95A5A6),
  };

  Widget _card(String title, Widget child, {IconData? icon}) => PrismSurface(
    margin: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 6),
            ],
            Text(title, style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );

  Widget _summary(CoFrontStats st, CoFrontStats? prev) {
    String change(Duration now, Duration? before) {
      if (before == null || before == Duration.zero) return '';
      final pct = ((now.inMinutes - before.inMinutes) * 100 / before.inMinutes)
          .round();
      return pct == 0 ? '' : ' (${pct > 0 ? '+' : ''}$pct%)';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TrackerStatGrid(
        children: [
          TrackerStatTile(
            label: tr(context, 'Total co-fronting', 'Co-frente total'),
            value: fmtDuration(st.total) + change(st.total, prev?.total),
            icon: PhosphorIcons.clock(),
          ),
          TrackerStatTile(
            label: tr(context, 'Sessions', 'Sesiones'),
            value: '${st.periods.length}',
            icon: PhosphorIcons.usersThree(),
          ),
          TrackerStatTile(
            label: tr(context, 'Average length', 'Duración media'),
            value: fmtDuration(st.average),
            icon: PhosphorIcons.timer(),
          ),
          TrackerStatTile(
            label: tr(context, 'Most alters at once', 'Más alters a la vez'),
            value:
                '${st.periods.map((p) => p.members.length).fold(0, math.max)}',
            icon: PhosphorIcons.stack(),
          ),
        ],
      ),
    );
  }

  Widget _certaintyCard(CoFrontStats st) {
    final total = st.total.inMinutes == 0 ? 1 : st.total.inMinutes;
    return _card(
      tr(context, 'Record certainty', 'Certeza de los registros'),
      Column(
        children: [
          ClipRRect(
            borderRadius: prismCorners(context, 6),
            child: Row(
              children: [
                for (final c in CoCertainty.values)
                  if ((st.certaintyTotals[c]?.inMinutes ?? 0) > 0)
                    Expanded(
                      flex: st.certaintyTotals[c]!.inMinutes,
                      child: Container(height: 14, color: _certColor(c)),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            children: [
              for (final c in CoCertainty.values)
                Text(
                  '${_certLabel(c)}: ${((st.certaintyTotals[c]?.inMinutes ?? 0) * 100 / total).round()}%',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            tr(
              context,
              'Uncertain = a session was marked “unsure”. Incomplete = a session was left open for over a day.',
              'Incierto = una sesión se marcó como «no seguro». Incompleto = una sesión quedó abierta más de un día.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      icon: PhosphorIcons.sealCheck(),
    );
  }

  Widget _rankings(CoFrontStats st, String Function(String) name) {
    final list = st.byMember.entries.toList()
      ..sort((a, b) => b.value.$2.compareTo(a.value.$2));
    final maxM = list.isEmpty ? 1 : list.first.value.$2.inMinutes;
    return _card(
      tr(context, 'Most frequent co-fronters', 'Quienes más co-frentan'),
      Column(
        children: [
          for (final (i, e) in list.take(10).indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${i + 1}.',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  SizedBox(
                    width: 110,
                    child: Text(
                      name(e.key),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    child: TrackerBar(
                      value: e.value.$2.inMinutes / (maxM == 0 ? 1 : maxM),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${fmtDuration(e.value.$2)} · ${e.value.$1}×',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
        ],
      ),
      icon: PhosphorIcons.trophy(),
    );
  }

  Widget _combos(CoFrontStats st, String Function(String) name) {
    final list = st.byCombination.entries.toList()
      ..sort(
        (a, b) => b.value.$1 != a.value.$1
            ? b.value.$1 - a.value.$1
            : b.value.$2.compareTo(a.value.$2),
      );
    return _card(
      tr(context, 'Frequent combinations', 'Combinaciones frecuentes'),
      Column(
        children: [
          for (final e in list.take(10))
            PrismListRow(
              dense: true,
              padding: EdgeInsets.zero,
              title: Text(e.key.split('+').map(name).join(' + ')),
              subtitle: Text(
                tr(
                  context,
                  '${e.value.$1} times · ${fmtDuration(e.value.$2)} total · avg ${fmtDuration(Duration(seconds: e.value.$2.inSeconds ~/ e.value.$1))}',
                  '${e.value.$1} veces · ${fmtDuration(e.value.$2)} total · media ${fmtDuration(Duration(seconds: e.value.$2.inSeconds ~/ e.value.$1))}',
                ),
              ),
            ),
        ],
      ),
      icon: PhosphorIcons.usersFour(),
    );
  }

  Widget _pairs(CoFrontStats st, String Function(String) name) {
    final ids =
        (st.byMember.entries.toList()
              ..sort((a, b) => b.value.$2.compareTo(a.value.$2)))
            .take(8)
            .map((e) => e.key)
            .toList();
    if (ids.length < 2) return const SizedBox.shrink();
    final maxPair = st.pairs.values
        .fold(Duration.zero, (a, b) => a > b ? a : b)
        .inMinutes;
    final theme = Theme.of(context);
    return _card(
      tr(context, 'Who co-fronts with whom', 'Quién co-frenta con quién'),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const FixedColumnWidth(54),
          columnWidths: const {0: FixedColumnWidth(96)},
          children: [
            TableRow(
              children: [
                const SizedBox.shrink(),
                for (final b in ids)
                  Padding(
                    padding: const EdgeInsets.all(2),
                    child: Text(
                      name(b),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
              ],
            ),
            for (final a in ids)
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      name(a),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                  for (final b in ids)
                    () {
                      final k = ([a, b]..sort()).join('|');
                      final d = a == b ? null : st.pairs[k];
                      final f = d == null || maxPair == 0
                          ? 0.0
                          : d.inMinutes / maxPair;
                      return Tooltip(
                        message: d == null
                            ? ''
                            : '${name(a)} + ${name(b)}: ${fmtDuration(d)}',
                        child: Container(
                          height: 40,
                          margin: const EdgeInsets.all(1),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: a == b
                                ? theme.colorScheme.surfaceContainerHighest
                                : theme.colorScheme.primary.withValues(
                                    alpha: 0.08 + f * 0.8,
                                  ),
                            borderRadius: prismCorners(context, 6),
                          ),
                          child: Text(
                            d == null ? '' : fmtDuration(d),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 9,
                              color: f > 0.5
                                  ? theme.colorScheme.onPrimary
                                  : null,
                            ),
                          ),
                        ),
                      );
                    }(),
                ],
              ),
          ],
        ),
      ),
      icon: PhosphorIcons.gridNine(),
    );
  }

  Widget _monthly(CoFrontStats st) {
    if (st.byMonth.isEmpty) return const SizedBox.shrink();
    final months = st.byMonth.keys.toList()..sort();
    final first = months.first, last = months.last;
    final all = [
      for (var m = first; !m.isAfter(last); m = DateTime(m.year, m.month + 1))
        m,
    ];
    final years = <int, Duration>{};
    st.byMonth.forEach(
      (k, v) => years[k.year] = (years[k.year] ?? Duration.zero) + v,
    );
    final theme = Theme.of(context);
    return _card(
      tr(context, 'Monthly & yearly', 'Mensual y anual'),
      Column(
        children: [
          SizedBox(
            height: 170,
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (v, m) => Text(
                        '${v.toInt()}h',
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: math.max(1, all.length / 6).floorToDouble(),
                      getTitlesWidget: (v, m) {
                        final i = v.toInt();
                        if (i < 0 || i >= all.length)
                          return const SizedBox.shrink();
                        return Text(
                          DateFormat.MMM(context.dateLocale).format(all[i]),
                          style: theme.textTheme.labelSmall,
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < all.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: (st.byMonth[all[i]]?.inMinutes ?? 0) / 60,
                          color: theme.colorScheme.primary,
                          width: math.max(3, 220 / all.length),
                          borderRadius: prismCorners(context, 3),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: [
              for (final y in (years.keys.toList()..sort()))
                Text(
                  '$y: ${fmtDuration(years[y]!)}',
                  style: theme.textTheme.labelMedium,
                ),
            ],
          ),
        ],
      ),
      icon: PhosphorIcons.chartBar(),
    );
  }

  Widget _calendar(CoFrontStats st) {
    final m = DateTime(_calMonth.year, _calMonth.month);
    final days = DateUtils.getDaysInMonth(m.year, m.month);
    final maxMin = st.byDay.values.fold(1, (a, b) => math.max(a, b.inMinutes));
    final theme = Theme.of(context);
    return _card(
      tr(context, 'Co-fronting calendar', 'Calendario de co-frente'),
      Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: tr(context, 'Previous month', 'Mes anterior'),
                icon: Icon(PhosphorIcons.caretLeft()),
                onPressed: () =>
                    setState(() => _calMonth = DateTime(m.year, m.month - 1)),
              ),
              Expanded(
                child: Text(
                  DateFormat.yMMMM(context.dateLocale).format(m),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                tooltip: tr(context, 'Next month', 'Mes siguiente'),
                icon: Icon(PhosphorIcons.caretRight()),
                onPressed: () =>
                    setState(() => _calMonth = DateTime(m.year, m.month + 1)),
              ),
            ],
          ),
          CompactCalendar(
            child: GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var i = 0; i < m.weekday - 1; i++) const SizedBox.shrink(),
                for (var d = 1; d <= days; d++)
                  () {
                    final v = st.byDay[DateTime(m.year, m.month, d)];
                    final f = v == null ? 0.0 : v.inMinutes / maxMin;
                    return Tooltip(
                      message: v == null ? '' : fmtDuration(v),
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: v == null
                              ? null
                              : theme.colorScheme.primary.withValues(
                                  alpha: 0.15 + f * 0.75,
                                ),
                          borderRadius: prismCorners(context, 8),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                        child: Text(
                          '$d',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: f > 0.5 ? theme.colorScheme.onPrimary : null,
                          ),
                        ),
                      ),
                    );
                  }(),
              ],
            ),
          ),
        ],
      ),
      icon: PhosphorIcons.calendarBlank(),
    );
  }

  Widget _timeline(CoFrontStats st, String Function(String) name) {
    final recent = [...st.periods]..sort((a, b) => b.start.compareTo(a.start));
    final fmt = DateFormat.MMMd(context.dateLocale).add_jm();
    return _card(
      tr(context, 'Timeline', 'Cronología'),
      Column(
        children: [
          for (final p in recent.take(60))
            PrismListRow(
              dense: true,
              padding: EdgeInsets.zero,
              leading: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _certColor(p.certainty),
                  borderRadius: prismRound(context),
                ),
              ),
              title: Text(p.members.map(name).join(' + ')),
              subtitle: Text(
                '${fmt.format(p.start)} · ${fmtDuration(p.duration)}${p.ongoing ? tr(context, ' · ongoing', ' · en curso') : ''} · ${_certLabel(p.certainty)}',
              ),
            ),
          if (recent.length > 60)
            Text(
              tr(
                context,
                '+${recent.length - 60} earlier',
                '+${recent.length - 60} anteriores',
              ),
              style: Theme.of(context).textTheme.labelSmall,
            ),
        ],
      ),
      icon: PhosphorIcons.listBullets(),
    );
  }

  Future<void> _chooseSections() async {
    final labels = {
      _Section.summary: tr(context, 'Summary', 'Resumen'),
      _Section.certainty: tr(context, 'Record certainty', 'Certeza'),
      _Section.rankings: tr(context, 'Rankings', 'Clasificación'),
      _Section.combos: tr(context, 'Combinations', 'Combinaciones'),
      _Section.pairs: tr(context, 'Pair matrix', 'Matriz de pares'),
      _Section.monthly: tr(
        context,
        'Monthly & yearly chart',
        'Gráfico mensual y anual',
      ),
      _Section.calendar: tr(context, 'Calendar', 'Calendario'),
      _Section.timeline: tr(context, 'Timeline', 'Cronología'),
    };
    await PrismSheet.show(
      context: context,
      title: tr(context, 'Dashboard sections', 'Secciones del panel'),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => ListView(
          shrinkWrap: true,
          children: [
            for (final s in _Section.values)
              PrismSwitchRow(
                title: labels[s]!,
                value: _sections.contains(s),
                onChanged: (v) {
                  setState(() => v ? _sections.add(s) : _sections.remove(s));
                  set(() {});
                  SharedPreferences.getInstance().then(
                    (p) => p.setStringList(_sectionPrefsKey, [
                      for (final x in _sections) x.name,
                    ]),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  String _report(
    CoFrontStats st,
    String Function(String) name,
    (DateTime, DateTime) range,
  ) {
    final f = DateFormat.yMMMd();
    final b = StringBuffer()
      ..writeln('Prism co-fronting report')
      ..writeln(
        '${f.format(range.$1)} – ${f.format(range.$2.subtract(const Duration(days: 1)))}',
      )
      ..writeln(
        'Total: ${fmtDuration(st.total)} across ${st.periods.length} periods (average ${fmtDuration(st.average)})',
      )
      ..writeln();
    b.writeln('Most frequent co-fronters:');
    for (final e
        in (st.byMember.entries.toList()
              ..sort((a, b) => b.value.$2.compareTo(a.value.$2)))
            .take(10)) {
      b.writeln(
        '  ${name(e.key)}: ${fmtDuration(e.value.$2)} (${e.value.$1} periods)',
      );
    }
    b.writeln('\nCombinations:');
    for (final e
        in (st.byCombination.entries.toList()
              ..sort((a, b) => b.value.$1 - a.value.$1))
            .take(10)) {
      b.writeln(
        '  ${e.key.split('+').map(name).join(' + ')}: ${e.value.$1}× · ${fmtDuration(e.value.$2)}',
      );
    }
    b.writeln('\nRecord certainty:');
    st.certaintyTotals.forEach(
      (k, v) => b.writeln('  ${k.name}: ${fmtDuration(v)}'),
    );
    return b.toString();
  }
}
