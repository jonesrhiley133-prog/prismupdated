import 'package:intl/intl.dart';

import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/health/body_atlas.dart';
import 'package:prism_plurality/features/health/body_map_view.dart';
import 'package:prism_plurality/features/health/health_episodes.dart';
import 'package:prism_plurality/features/health/health_export.dart';
import 'package:prism_plurality/features/health/health_log_sheet.dart';
import 'package:prism_plurality/features/health/health_model.dart';
import 'package:prism_plurality/features/health/health_widgets.dart';
import 'package:prism_plurality/features/health/sensation_editor.dart';
import 'package:prism_plurality/features/health/symptom_catalog.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/settings/views/feature_data_screen.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/prism_shapes.dart';
import 'package:prism_plurality/shared/utils/animations.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/widgets/prism_inline_icon_button.dart';

enum HealthTab { timeline, map, episodes }

/// Timeline filters.
class _Filter {
  const _Filter({
    this.days = 0,
    this.categories = const {},
    this.descriptor = '',
    this.regionId,
    this.regionSide,
    this.state = 'all',
  });
  final int days;
  final Set<SymptomCategory> categories;
  final String descriptor;
  final String? regionId;
  final BodySide? regionSide;

  /// all, ongoing, resolved
  final String state;

  int get count =>
      (days > 0 ? 1 : 0) +
      (categories.isNotEmpty ? 1 : 0) +
      (descriptor.isNotEmpty ? 1 : 0) +
      (regionId != null ? 1 : 0) +
      (state != 'all' ? 1 : 0);
}

/// Health: a private place to record symptoms and illness over time.
class HealthScreen extends ConsumerStatefulWidget {
  const HealthScreen({
    super.key,
    this.showBackButton = false,
    this.entryId,
    this.moodId,
    this.tab,
  });
  final bool showBackButton;

  /// Deep links: open a specific entry, or Body Map spots carried over from
  /// a Mood check-in.
  final String? entryId;
  final String? moodId;
  final String? tab;

  @override
  ConsumerState<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends ConsumerState<HealthScreen> {
  late HealthTab _tab =
      HealthTab.values.where((t) => t.name == widget.tab).firstOrNull ??
      (widget.moodId != null ? HealthTab.map : HealthTab.timeline);

  /// 'all', a member id, 'system' or 'unsure'.
  String _alter = 'all';
  _Filter _filter = const _Filter();
  final Set<String> _expanded = {};
  String? _focusSpot;
  int _mapDays = 30;
  final _mapKey = GlobalKey<BodyMapPanelState>();

  @override
  void initState() {
    super.initState();
    if (widget.entryId != null) _expanded.add(widget.entryId!);
  }

  bool _matchesAlter(Attribution a) => switch (_alter) {
    'all' => true,
    'system' => a.scope == HealthScope.system,
    'unsure' => a.scope == HealthScope.unsure,
    final id => a.isAbout(id),
  };

  @override
  Widget build(BuildContext context) {
    final es = healthEs(context);
    final theme = Theme.of(context);
    final async = ref.watch(visibleHealthRecordsProvider);
    final members = {
      for (final m
          in ref.watch(userVisibleMembersProvider).value ?? const <Member>[])
        m.id: m,
    };
    final viewer = ref.watch(healthViewerProvider);
    final records = [
      for (final r in async.value ?? const <TrackerRecord>[])
        if (_matchesAlter(Attribution.of(r))) r,
    ];
    final checkins = [
      for (final r in records)
        if (r.kind == TrackerKind.healthCheckin) r,
    ];
    final followups = [
      for (final r in records)
        if (r.kind == TrackerKind.healthFollowup) r,
    ];
    final episodes = [
      for (final r in records)
        if (r.kind == TrackerKind.healthEpisode) r,
    ];
    final spots = [
      for (final s in ref.watch(bodySpotsProvider))
        if (_matchesAlter(
          s.isLegacy
              ? legacyAttribution(s.legacyMood!)
              : Attribution.of(s.record!),
        ))
          s,
    ];
    final draft = ref.watch(healthDraftProvider).value;

    final ongoing = [
      for (final c in checkins)
        if (latestStatus(c, followups) != FollowStatus.resolved &&
            DateTime.now().difference(c.happenedAt).inDays <= 21 &&
            (c.symptoms.isNotEmpty || c.body != null))
          c,
    ]..sort((a, b) => b.happenedAt.compareTo(a.happenedAt));
    final activeEpisodes = [
      for (final e in episodes)
        if (e.episodeActive) e,
    ];

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: es ? 'Salud' : 'Health',
        showBackButton: widget.showBackButton || Navigator.of(context).canPop(),
        actions: [
          const FeatureDataAction(featureId: 'health'),
          PrismTopBarAction(
            icon: PhosphorIcons.export(),
            tooltip: es ? 'Exportar resumen' : 'Export summary',
            onPressed: () => showHealthExport(context),
          ),
        ],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: !async.hasValue
          ? const PrismLoadingState()
          : ClampedBody(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  32 + NavBarInset.of(context),
                ),
                children: [
                  _Header(
                    viewerName: viewer == null ? null : members[viewer]?.effectiveName(preferDisplayName: ref.watch(memberNamePreferDisplayProvider)),
                    alter: _alter,
                    members: members,
                    subjects: {
                      for (final c in checkins) ...Attribution.of(c).subjects,
                    },
                    onAlter: (a) => setState(() => _alter = a),
                    onLog: () => showHealthLog(context),
                  ),
                  if (draft != null) ...[
                    const SizedBox(height: 12),
                    _DraftBanner(
                      draft: draft,
                      onContinue: () => showHealthLog(context, draft: draft),
                      onDiscard: () async {
                        await HealthDrafts.clear(viewer);
                        ref.invalidate(healthDraftProvider);
                      },
                    ),
                  ],
                  if (widget.entryId != null)
                    _LinkedEntry(
                      id: widget.entryId!,
                      followups: followups,
                      members: members,
                    ),
                  if (ongoing.isNotEmpty || activeEpisodes.isNotEmpty) ...[
                    PrismSectionHeader(title: es ? 'EN CURSO' : 'ONGOING'),
                    PrismSurface(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (final (i, e) in activeEpisodes.indexed) ...[
                            if (i > 0) _divider(theme),
                            _OngoingEpisode(
                              episode: e,
                              count: checkins
                                  .where((c) => c.episodeId == e.id)
                                  .length,
                            ),
                          ],
                          for (final (i, c) in ongoing.take(5).indexed) ...[
                            if (i > 0 || activeEpisodes.isNotEmpty)
                              _divider(theme),
                            _OngoingRow(
                              checkin: c,
                              status: latestStatus(c, followups),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  PrismSegmentedControl<HealthTab>(
                    segments: [
                      PrismSegment(
                        value: HealthTab.timeline,
                        label: es ? 'Cronología' : 'Timeline',
                      ),
                      PrismSegment(
                        value: HealthTab.map,
                        label: es ? 'Mapa corporal' : 'Body Map',
                      ),
                      PrismSegment(
                        value: HealthTab.episodes,
                        label: es ? 'Episodios' : 'Episodes',
                      ),
                    ],
                    selected: _tab,
                    onChanged: (t) => setState(() => _tab = t),
                  ),
                  const SizedBox(height: 14),
                  SectionSwitcher(
                    id: _tab,
                    child: switch (_tab) {
                      HealthTab.timeline => _timeline(
                        context,
                        checkins,
                        followups,
                        spots,
                        members,
                      ),
                      HealthTab.map => _map(context, spots),
                      HealthTab.episodes => _episodes(
                        context,
                        episodes,
                        checkins,
                      ),
                    },
                  ),
                  _HiddenNote(),
                ],
              ),
            ),
    );
  }

  Widget _divider(ThemeData theme) => Divider(
    height: 1,
    indent: 16,
    endIndent: 16,
    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
  );

  // -------------------------------------------------------------------------
  // Timeline
  // -------------------------------------------------------------------------

  Widget _timeline(
    BuildContext context,
    List<TrackerRecord> checkins,
    List<TrackerRecord> followups,
    List<BodySpot> spots,
    Map<String, Member> members,
  ) {
    final theme = Theme.of(context);
    final es = healthEs(context);
    final f = _filter;
    final from = f.days == 0
        ? null
        : DateTime.now().subtract(Duration(days: f.days));
    final spotById = {for (final s in spots) s.id: s};

    bool keepCheckin(TrackerRecord c) {
      if (from != null && c.happenedAt.isBefore(from)) return false;
      if (f.categories.isNotEmpty &&
          !c.symptoms.any((s) => f.categories.contains(s.category)))
        return false;
      if (f.state != 'all') {
        final resolved = latestStatus(c, followups) == FollowStatus.resolved;
        if (f.state == 'ongoing' ? resolved : !resolved) return false;
      }
      final linked = [
        for (final s in c.symptoms)
          for (final id in s.spotIds) ?spotById[id],
      ];
      if (f.regionId != null &&
          !linked.any(
            (s) =>
                s.regionId == f.regionId &&
                (f.regionSide == null || s.side == f.regionSide),
          ))
        return false;
      if (f.descriptor.isNotEmpty &&
          !linked.any(
            (s) => s.descriptors.any(
              (d) => d.label.toLowerCase().contains(f.descriptor.toLowerCase()),
            ),
          ))
        return false;
      return true;
    }

    bool keepSpot(BodySpot s) {
      if (s.checkinId != null) return false; // shown with its check-in
      if (from != null && (s.at ?? DateTime(0)).isBefore(from)) return false;
      if (f.categories.isNotEmpty || f.state != 'all') return false;
      if (f.regionId != null &&
          (s.regionId != f.regionId ||
              (f.regionSide != null && s.side != f.regionSide)))
        return false;
      if (f.descriptor.isNotEmpty &&
          !s.descriptors.any(
            (d) => d.label.toLowerCase().contains(f.descriptor.toLowerCase()),
          ))
        return false;
      return true;
    }

    final keptCheckins = [
      for (final c in checkins)
        if (keepCheckin(c)) c,
    ];
    final keptIds = {for (final c in keptCheckins) c.id};
    final items = <_Item>[
      for (final c in keptCheckins) _Item(c.happenedAt, checkin: c),
      for (final fu in followups)
        if (keptIds.contains(fu.parentId)) _Item(fu.happenedAt, followup: fu),
      for (final s in spots)
        if (keepSpot(s)) _Item(s.at ?? DateTime(0), spot: s),
    ]..sort((a, b) => b.at.compareTo(a.at));

    final byDay = <DateTime, List<_Item>>{};
    for (final it in items) {
      byDay
          .putIfAbsent(DateTime(it.at.year, it.at.month, it.at.day), () => [])
          .add(it);
    }
    final checkinById = {for (final c in checkins) c.id: c};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            PrismButton(
              label: f.count == 0
                  ? (es ? 'Filtrar' : 'Filter')
                  : (es ? 'Filtros (${f.count})' : 'Filters (${f.count})'),
              icon: PhosphorIcons.funnelSimple(),
              density: PrismControlDensity.compact,
              onPressed: () async {
                final next = await _showFilters(context, f);
                if (next != null) setState(() => _filter = next);
              },
            ),
            if (f.count > 0) ...[
              const SizedBox(width: 8),
              PrismButton(label: es ? 'Quitar filtros' : 'Clear', density: PrismControlDensity.compact, onPressed: () => setState(() => _filter = const _Filter())),
            ],
            const Spacer(),
            if (checkins.isNotEmpty) _ComparePeriods(checkins: checkins),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          _EmptyTimeline(filtered: f.count > 0 || _alter != 'all')
        else
          for (final e in byDay.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
              child: Row(
                children: [
                  Text(
                    dayHeading(context, e.key),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Divider(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (final (i, it) in e.value.indexed)
              _TimelineRow(
                item: it,
                parent: it.followup == null
                    ? null
                    : checkinById[it.followup!.parentId],
                followups: followups,
                spots: spotById,
                members: members,
                expanded: _expanded.contains(it.id),
                last: i == e.value.length - 1,
                onToggle: () => setState(
                  () => _expanded.contains(it.id)
                      ? _expanded.remove(it.id)
                      : _expanded.add(it.id),
                ),
                onOpenSpot: (s) => setState(() {
                  _tab = HealthTab.map;
                  _focusSpot = s.id;
                }),
              ),
          ],
      ],
    );
  }

  Future<_Filter?> _showFilters(BuildContext context, _Filter current) =>
      PrismSheet.show<_Filter>(
        context: context,
        title: healthEs(context) ? 'Filtrar cronología' : 'Filter timeline',
        builder: (ctx) => _FilterForm(initial: current),
      );

  // -------------------------------------------------------------------------
  // Body Map
  // -------------------------------------------------------------------------

  Widget _map(BuildContext context, List<BodySpot> all) {
    final theme = Theme.of(context);
    final es = healthEs(context);
    final from = _mapDays == 0
        ? null
        : DateTime.now().subtract(Duration(days: _mapDays));
    final spots = [
      for (final s in all)
        if (from == null || !(s.at ?? DateTime(0)).isBefore(from)) s,
    ].take(40).toList();
    final viewer = ref.watch(healthViewerProvider);
    final who = viewer == null
        ? const Attribution(scope: HealthScope.unsure)
        : Attribution(subjects: [viewer], author: viewer);
    // A link from a Mood check-in focuses its carried-over sensations,
    // including ones since edited into Health entries.
    if (_focusSpot == null && widget.moodId != null) {
      final prefix = 'mood:${widget.moodId}:';
      final hit = all
          .where(
            (s) =>
                s.id.startsWith(prefix) ||
                (s.record?.str('legacyRef')?.startsWith(prefix) ?? false),
          )
          .firstOrNull;
      if (hit != null) {
        _focusSpot = hit.id;
        if (!spots.contains(hit)) spots.insert(0, hit);
      }
    }
    final markers = MapMarker.fromSpots(spots);
    final focused = spots.where((s) => s.id == _focusSpot).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (d, label) in [
                      (7, es ? '7 días' : '7 days'),
                      (30, es ? '30 días' : '30 days'),
                      (90, es ? '90 días' : '90 days'),
                      (0, es ? 'Todo' : 'All'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: PrismChip(
                          label: label,
                          selected: _mapDays == d,
                          onTap: () => setState(() => _mapDays = d),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            PrismButton(
              label: es ? 'Añadir' : 'Add',
              icon: PhosphorIcons.plus(),
              tone: PrismButtonTone.filled,
              density: PrismControlDensity.compact,
              onPressed: () => showSensationEditor(context, who: who),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            final mapCol = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PrismSurface(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                  child: BodyMapPanel(
                    key: _mapKey,
                    markers: markers,
                    focusedId: _focusSpot,
                    maxHeight: 460,
                    allowSpecial: true,
                    onMarkerTap: (id) => setState(() => _focusSpot = id),
                    onPick: (p) => showSensationEditor(
                      context,
                      who: who,
                      initial: [
                        BodySpot(
                          id: 'new:${DateTime.now().microsecondsSinceEpoch}',
                          regionId: p.regionId,
                          side: p.side,
                          view: p.view,
                          x: p.x,
                          y: p.y,
                          at: DateTime.now(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  es
                      ? 'Toca una zona para registrar una sensación. Los marcadores numerados coinciden con la lista.'
                      : 'Tap an area to record a sensation. Numbered markers match the list.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            );
            final sideCol = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (focused != null) ...[
                  const SizedBox(height: 12),
                  _SpotDetail(
                    spot: focused,
                    number: spots.indexOf(focused) + 1,
                    who: who,
                  ),
                ],
                PrismSectionHeader(title: es ? 'MARCADORES' : 'MARKERS'),
                if (spots.isEmpty)
                  Text(
                    es ? 'Nada en este periodo.' : 'Nothing in this period.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  PrismSurface(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final (i, s) in spots.indexed) ...[
                          if (i > 0) _divider(theme),
                          _SpotRow(
                            spot: s,
                            number: i + 1,
                            selected: s.id == _focusSpot,
                            onTap: () {
                              setState(() => _focusSpot = s.id);
                              if (s.hasPoint)
                                _mapKey.currentState?.show(s.view, s.side);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            );
            // Wide screens: the list sits beside the drawing.
            if (c.maxWidth >= 860) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: mapCol),
                  const SizedBox(width: 16),
                  Expanded(flex: 4, child: sideCol),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [mapCol, sideCol],
            );
          },
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Episodes
  // -------------------------------------------------------------------------

  Widget _episodes(
    BuildContext context,
    List<TrackerRecord> episodes,
    List<TrackerRecord> checkins,
  ) {
    final theme = Theme.of(context);
    final es = healthEs(context);
    final sorted = [...episodes]
      ..sort((a, b) {
        if (a.episodeActive != b.episodeActive) return a.episodeActive ? -1 : 1;
        return (b.occurredAt ?? b.createdAt).compareTo(
          a.occurredAt ?? a.createdAt,
        );
      });
    final df = DateFormat.MMMd(context.dateLocale);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                es
                    ? 'Agrupa síntomas y seguimientos de una misma enfermedad.'
                    : 'Group the symptoms and follow-ups of one illness.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            PrismButton(
              label: es ? 'Nuevo' : 'New',
              icon: PhosphorIcons.plus(),
              tone: PrismButtonTone.filled,
              density: PrismControlDensity.compact,
              onPressed: () => showEpisodeEditor(context),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (sorted.isEmpty)
          PrismSurface(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  PhosphorIcons.stack(),
                  size: 28,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 10),
                Text(
                  es ? 'Aún no hay episodios' : 'No episodes yet',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  es
                      ? 'Crea uno desde aquí o desde una entrada de la cronología, como “Garganta y cansancio esta semana”.'
                      : 'Start one here or from a timeline entry — like “Sore throat and fatigue this week”.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else
          for (final e in sorted)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PrismSurface(
                onTap: () => showEpisodeDetail(context, e),
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                accentColor: e.episodeActive ? theme.colorScheme.primary : null,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.title.isEmpty
                                ? (es ? 'Sin título' : 'Untitled')
                                : e.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              StatusTag(
                                text: episodeStateLabel(e.episodeState, es),
                                active: e.episodeActive,
                              ),
                              Text(
                                [
                                  '${df.format(e.occurredAt?.toLocal() ?? e.createdAt)}${e.flag('approxStart') ? '~' : ''}${e.endedAt != null ? ' – ${df.format(e.endedAt!.toLocal())}' : ''}',
                                  es
                                      ? '${checkins.where((c) => c.episodeId == e.id).length} entradas'
                                      : '${checkins.where((c) => c.episodeId == e.id).length} entries',
                                ].join(' · '),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      PhosphorIcons.caretRight(),
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------

class _Header extends ConsumerWidget {
  const _Header({
    required this.viewerName,
    required this.alter,
    required this.members,
    required this.subjects,
    required this.onAlter,
    required this.onLog,
  });
  final String? viewerName;
  final String alter;
  final Map<String, Member> members;
  final Set<String> subjects;
  final ValueChanged<String> onAlter;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final es = healthEs(context);
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    final alterLabel = switch (alter) {
      'all' => es ? 'Todos' : 'Everyone',
      'system' => context.l10n.trackerWholeSystem,
      'unsure' => es ? 'No se sabe quién' : 'Unsure who',
      final id => members[id]?.effectiveName(preferDisplayName: prefer) ?? '—',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              PhosphorIcons.lockSimple(),
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                viewerName == null
                    ? (es
                          ? 'Privado · sin alter al frente'
                          : 'Private · no one marked as fronting')
                    : (es
                          ? 'Privado · viendo como $viewerName'
                          : 'Private · viewing as $viewerName'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Semantics(
              button: true,
              label: es
                  ? 'Mostrar registros de: $alterLabel'
                  : 'Showing records for: $alterLabel',
              child: InkWell(
                borderRadius: BorderRadius.circular(
                  PrismShapes.of(context).radius(10),
                ),
                onTap: () async {
                  final pick = await PrismSheet.show<String>(
                    context: context,
                    title: es ? 'Registros de' : 'Show records for',
                    builder: (ctx) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final (id, label) in [
                          (
                            'all',
                            es
                                ? 'Todos los que puedo ver'
                                : 'Everyone I can see',
                          ),
                          for (final s in subjects)
                            if (members[s] != null)
                              (s, memberLabel(members[s]!, preferDisplayName: ref.watch(memberNamePreferDisplayProvider))),
                          ('system', context.l10n.trackerWholeSystem),
                          ('unsure', es ? 'No se sabe quién' : 'Unsure who'),
                        ])
                          PrismListRow(
                            title: Text(label),
                            trailing: id == alter
                                ? Icon(
                                    AppIcons.check,
                                    color: theme.colorScheme.primary,
                                  )
                                : null,
                            onTap: () => Navigator.of(ctx).pop(id),
                          ),
                      ],
                    ),
                  );
                  if (pick != null) onAlter(pick);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      PrismShapes.of(context).radius(10),
                    ),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        PhosphorIcons.usersThree(),
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Text(
                          alterLabel,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        PhosphorIcons.caretDown(),
                        size: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        PrismButton(
          label: es ? 'Registrar cómo me siento' : 'Log how I feel',
          icon: PhosphorIcons.stethoscope(),
          tone: PrismButtonTone.filled,
          expanded: true,
          onPressed: onLog,
        ),
      ],
    );
  }
}

class _DraftBanner extends StatelessWidget {
  const _DraftBanner({
    required this.draft,
    required this.onContinue,
    required this.onDiscard,
  });
  final Map<String, dynamic> draft;
  final VoidCallback onContinue;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final es = healthEs(context);
    final at = DateTime.tryParse('${draft['savedAt']}')?.toLocal();
    final symptoms = [
      for (final s in (draft['symptoms'] as List?) ?? const [])
        if (s is Map) '${s['label']}',
    ];
    final summary = symptoms.isNotEmpty
        ? symptoms.join(', ')
        : ((draft['quick'] as String?) ?? '');
    return PrismSurface(
      accentColor: theme.colorScheme.primary,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Row(
        children: [
          Icon(
            PhosphorIcons.notePencil(),
            color: theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  es
                      ? 'Entrada sin terminar${at == null ? '' : ' · ${clockTime(context, at)}'}'
                      : 'Unfinished entry${at == null ? '' : ' · ${clockTime(context, at)}'}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (summary.isNotEmpty)
                  Text(
                    summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          PrismButton(label: es ? 'Descartar' : 'Discard', density: PrismControlDensity.compact, onPressed: onDiscard),
          PrismButton(
            label: es ? 'Seguir' : 'Continue',
            tone: PrismButtonTone.filled,
            density: PrismControlDensity.compact,
            onPressed: onContinue,
          ),
        ],
      ),
    );
  }
}

class _OngoingRow extends ConsumerWidget {
  const _OngoingRow({required this.checkin, required this.status});
  final TrackerRecord checkin;
  final FollowStatus? status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final es = healthEs(context);
    final title = checkin.title.isNotEmpty
        ? checkin.title
        : (checkin.body ?? '');
    final since = DateFormat.MMMd(
      context.dateLocale,
    ).format(checkin.happenedAt);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                es ? 'desde $since' : 'since $since',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in FollowStatus.values)
                PrismChip(
                  label: followStatusLabel(s, es),
                  selected: false,
                  onTap: () => showFollowup(context, checkin, status: s),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OngoingEpisode extends StatelessWidget {
  const _OngoingEpisode({required this.episode, required this.count});
  final TrackerRecord episode;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final es = healthEs(context);
    return InkWell(
      onTap: () => showEpisodeDetail(context, episode),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Icon(
              PhosphorIcons.stack(),
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    episode.title.isEmpty
                        ? (es ? 'Episodio' : 'Episode')
                        : episode.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    es
                        ? 'Episodio · $count entradas'
                        : 'Episode · $count entries',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            StatusTag(
              text: episodeStateLabel(episode.episodeState, es),
              active: true,
            ),
            const SizedBox(width: 6),
            Icon(
              PhosphorIcons.caretRight(),
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _Item {
  _Item(this.at, {this.checkin, this.followup, this.spot});
  final DateTime at;
  final TrackerRecord? checkin;
  final TrackerRecord? followup;
  final BodySpot? spot;
  String get id => checkin?.id ?? followup?.id ?? spot!.id;
}

class _TimelineRow extends ConsumerWidget {
  const _TimelineRow({
    required this.item,
    required this.parent,
    required this.followups,
    required this.spots,
    required this.members,
    required this.expanded,
    required this.last,
    required this.onToggle,
    required this.onOpenSpot,
  });

  final _Item item;
  final TrackerRecord? parent;
  final List<TrackerRecord> followups;
  final Map<String, BodySpot> spots;
  final Map<String, Member> members;
  final bool expanded;
  final bool last;
  final VoidCallback onToggle;
  final ValueChanged<BodySpot> onOpenSpot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final es = healthEs(context);
    final c = item.checkin;
    final fu = item.followup;
    final sp = item.spot;
    final kind = c != null
        ? (es ? 'NUEVA ENTRADA' : 'NEW ENTRY')
        : (fu != null
              ? (es ? 'SEGUIMIENTO' : 'FOLLOW-UP')
              : (es ? 'MAPA CORPORAL' : 'BODY MAP'));
    final followStatus = fu == null
        ? null
        : FollowStatus.values
              .where((s) => s.name == fu.str('status'))
              .firstOrNull;
    final title = c != null
        ? (c.title.isNotEmpty ? c.title : (c.body ?? ''))
        : fu != null
        ? '${followStatusLabel(followStatus ?? FollowStatus.still, es)} — ${parent?.title.isNotEmpty == true ? parent!.title : (parent?.body ?? '')}'
        : sp!.placeLabel(es);
    final record = c ?? fu ?? sp?.record;
    final who = sp?.isLegacy == true
        ? legacyAttribution(sp!.legacyMood!)
        : (record == null ? null : Attribution.of(record));
    final status = c == null ? null : latestStatus(c, followups);
    final worst = c?.symptoms
        .map((s) => s.severity)
        .whereType<Severity>()
        .where((s) => s != Severity.unsure)
        .fold<Severity?>(
          null,
          (a, b) => a == null || b.index > a.index ? b : a,
        );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                const SizedBox(height: 18),
                _Node(followup: fu != null, spot: sp != null),
                if (!last)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 1.5,
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PrismSurface(
                onTap: onToggle,
                semanticLabel: '$kind. $title',
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          kind,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: fu != null
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.colorScheme.primary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          clockTime(context, item.at),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 4),
                        AnimatedRotation(
                          turns: expanded ? 0.5 : 0,
                          duration: MediaQuery.of(context).disableAnimations
                              ? Duration.zero
                              : Anim.sm,
                          child: Icon(
                            PhosphorIcons.caretDown(),
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      maxLines: expanded ? null : 2,
                      overflow: expanded ? null : TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (worst != null) SeverityTag(worst),
                        if (status != null)
                          StatusTag(
                            text: followStatusLabel(status, es),
                            active: status != FollowStatus.resolved,
                          ),
                        if (sp != null && sp.descriptors.isNotEmpty)
                          Text(
                            sp.descriptors.map((d) => d.label).join(' · '),
                            style: theme.textTheme.bodySmall,
                          ),
                        if (sp?.isLegacy == true)
                          StatusTag(
                            text: es ? 'De Ánimo' : 'From Mood',
                            active: false,
                            icon: PhosphorIcons.smiley(),
                          ),
                        if (who != null)
                          Text(
                            attributionText(who, members, es, preferDisplayName: ref.watch(memberNamePreferDisplayProvider)),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        if (c != null && c.backdated)
                          Text(
                            es
                                ? 'registrado ${DateFormat.MMMd(context.dateLocale).add_jm().format(c.createdAt.toLocal())}'
                                : 'recorded ${DateFormat.MMMd(context.dateLocale).add_jm().format(c.createdAt.toLocal())}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        if (c != null &&
                            c.timePrecision == TimePrecision.approx)
                          Text(
                            es ? 'hora aproximada' : 'approximate time',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    AnimatedSize(
                      duration: MediaQuery.of(context).disableAnimations
                          ? Duration.zero
                          : Anim.md,
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: expanded
                          ? _details(context, ref, c, fu, sp)
                          : const SizedBox(width: double.infinity),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _details(
    BuildContext context,
    WidgetRef ref,
    TrackerRecord? c,
    TrackerRecord? fu,
    BodySpot? sp,
  ) {
    final theme = Theme.of(context);
    final es = healthEs(context);
    final df = DateFormat.MMMd(context.dateLocale).add_jm();
    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label  ',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            TextSpan(text: value, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
    final children = <Widget>[];
    if (c != null) {
      if (c.symptoms.isNotEmpty && c.body != null)
        children.add(line(es ? 'NOTA' : 'NOTE', c.body!));
      final single = c.symptoms.length == 1;
      for (final s in c.symptoms) {
        // With one symptom its name is already the row title.
        if (!single)
          children.add(
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      s.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (s.severity != null)
                    SeverityTag(s.severity!, score: s.score),
                ],
              ),
            ),
          );
        if (s.onset != null || s.onsetPrecision == TimePrecision.unknown) {
          children.add(
            line(
              es ? 'INICIO' : 'ONSET',
              s.onsetPrecision == TimePrecision.unknown
                  ? (es ? 'desconocido' : 'unknown')
                  : '${df.format(s.onset!)}${s.onsetPrecision == TimePrecision.approx ? (es ? ' (aprox.)' : ' (approx.)') : ''}',
            ),
          );
        }
        if (s.end != null)
          children.add(line(es ? 'FIN' : 'ENDED', df.format(s.end!)));
        if (s.course.isNotEmpty)
          children.add(
            line(
              es ? 'EVOLUCIÓN' : 'COURSE',
              s.course
                  .map(
                    (id) =>
                        courseOptions
                            .where((o) => o.$1 == id)
                            .map((o) => es ? o.$3 : o.$2)
                            .firstOrNull ??
                        id,
                  )
                  .join(', '),
            ),
          );
        final locs = [for (final id in s.spotIds) ?spots[id]];
        for (final l in locs) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: InkWell(
                onTap: () => onOpenSpot(l),
                child: Row(
                  children: [
                    Icon(
                      PhosphorIcons.personSimple(),
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        [
                          l.placeLabel(es),
                          ...l.descriptors.map((d) => d.label),
                        ].join(' · '),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (s.impact.isNotEmpty)
          children.add(
            line(
              es ? 'AFECTA' : 'AFFECTS',
              s.impact
                  .map(
                    (id) =>
                        impactOptions
                            .where((o) => o.$1 == id)
                            .map((o) => es ? o.$3 : o.$2)
                            .firstOrNull ??
                        id,
                  )
                  .join(', '),
            ),
          );
        if (s.triggers != null)
          children.add(line(es ? 'DESENCADENANTES' : 'TRIGGERS', s.triggers!));
        if (s.relief != null)
          children.add(line(es ? 'ALIVIO' : 'RELIEF', s.relief!));
        if (s.tried != null)
          children.add(line(es ? 'PROBADO' : 'TRIED', s.tried!));
        if (s.after != null)
          children.add(line(es ? 'DESPUÉS' : 'AFTERWARDS', s.after!));
        if (s.tempValue != null)
          children.add(
            line(
              es ? 'TEMPERATURA' : 'TEMPERATURE',
              '${s.tempValue} °${s.tempUnit} · ${es ? 'introducida por ti' : 'self-entered'}',
            ),
          );
        if (s.notes != null)
          children.add(line(es ? 'NOTAS' : 'NOTES', s.notes!));
      }
      final mine = [
        for (final f in followups)
          if (f.parentId == c.id) f,
      ]..sort((a, b) => a.happenedAt.compareTo(b.happenedAt));
      if (mine.isNotEmpty) {
        children.add(
          HealthFormLabel(es ? 'Seguimientos' : 'Follow-ups', top: 14),
        );
        for (final f in mine) {
          final st =
              FollowStatus.values
                  .where((s) => s.name == f.str('status'))
                  .firstOrNull ??
              FollowStatus.still;
          children.add(
            line(
              df.format(f.happenedAt).toUpperCase(),
              '${followStatusLabel(st, es)}${f.body != null ? ' — ${f.body}' : ''}',
            ),
          );
        }
      }
      children.add(const SizedBox(height: 12));
      children.add(
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final s in FollowStatus.values)
              PrismChip(
                label: followStatusLabel(s, es),
                selected: false,
                onTap: () => showFollowup(context, c, status: s),
              ),
          ],
        ),
      );
      children.add(const SizedBox(height: 8));
      children.add(
        Wrap(
          spacing: 4,
          children: [
            PrismButton(label: es ? 'Corregir' : 'Edit', icon: PhosphorIcons.pencilSimple(), density: PrismControlDensity.compact, onPressed: () => showHealthLog(context, existing: c)),
            PrismButton(label: c.episodeId != null
                    ? (es ? 'Quitar del episodio' : 'Remove from episode')
                    : (es ? 'Añadir a episodio' : 'Add to episode'), icon: c.episodeId != null
                    ? PhosphorIcons.folderMinus()
                    : PhosphorIcons.folderSimplePlus(), density: PrismControlDensity.compact, onPressed: () async {
                if (c.episodeId != null) {
                  await ref.read(healthStoreProvider).setEpisode(c, null);
                } else {
                  if (context.mounted) await _pickEpisode(context, ref, c);
                }
              }),
            PrismButton(label: es ? 'Borrar' : 'Delete', icon: PhosphorIcons.trash(), density: PrismControlDensity.compact, tone: PrismButtonTone.destructive, onPressed: () async {
                final ok = await PrismDialog.confirm(
                  context: context,
                  title: es ? '¿Borrar esta entrada?' : 'Delete this entry?',
                  message: es
                      ? 'También se borrarán sus seguimientos.'
                      : 'Its follow-ups are deleted too.',
                  confirmLabel: es ? 'Borrar' : 'Delete',
                  destructive: true,
                );
                if (ok) await ref.read(healthStoreProvider).delete(c);
              }),
          ],
        ),
      );
    } else if (fu != null) {
      if (fu.str('severity') != null) {
        final sev = Severity.values
            .where((s) => s.name == fu.str('severity'))
            .firstOrNull;
        if (sev != null)
          children.add(
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SeverityTag(sev),
              ),
            ),
          );
      }
      if (fu.body != null)
        children.add(line(es ? 'OBSERVACIONES' : 'OBSERVATIONS', fu.body!));
    } else if (sp != null) {
      if (sp.intensity != null)
        children.add(
          line(
            es ? 'INTENSIDAD' : 'INTENSITY',
            '${sp.intensity}/10 · ${IntensityRating.words(sp.intensity!, es)}',
          ),
        );
      if (sp.spreads.isNotEmpty)
        children.add(
          line(
            es ? 'SE EXTIENDE A' : 'SPREADS TO',
            sp.spreads
                .map(
                  (p) =>
                      '${p.label(es)}${p.stops ? (es ? ' (se detiene)' : ' (stops)') : ''}',
                )
                .join(' → '),
          ),
        );
      if (sp.isLegacy) {
        children.add(line(es ? 'ORIGINAL' : 'ORIGINAL', sp.legacyText ?? ''));
        children.add(
          line(
            es ? 'INTENSIDAD DEL ÁNIMO' : 'MOOD INTENSITY',
            '${sp.legacyMood!.intensity}/10',
          ),
        );
      }
      if (sp.notes != null && sp.notes!.isNotEmpty)
        children.add(
          line(
            sp.isLegacy
                ? (es ? 'NOTA DEL ÁNIMO' : 'MOOD NOTE')
                : (es ? 'NOTAS' : 'NOTES'),
            sp.notes!,
          ),
        );
      children.add(const SizedBox(height: 8));
      children.add(
        Align(
          alignment: Alignment.centerLeft,
          child: PrismButton(label: es ? 'Ver en el mapa' : 'Show on the map', icon: PhosphorIcons.personSimple(), density: PrismControlDensity.compact, onPressed: () => onOpenSpot(sp)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Future<void> _pickEpisode(
    BuildContext context,
    WidgetRef ref,
    TrackerRecord c,
  ) async {
    final es = healthEs(context);
    final eps = [
      for (final r
          in ref.read(visibleHealthRecordsProvider).value ??
              const <TrackerRecord>[])
        if (r.kind == TrackerKind.healthEpisode && r.episodeActive) r,
    ];
    final pick = await PrismSheet.show<String>(
      context: context,
      title: es ? 'Añadir a episodio' : 'Add to episode',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in eps)
            PrismListRow(
              title: Text(
                e.title.isEmpty ? (es ? 'Sin título' : 'Untitled') : e.title,
              ),
              leading: Icon(PhosphorIcons.stack()),
              onTap: () => Navigator.of(ctx).pop(e.id),
            ),
          PrismListRow(
            title: Text(es ? 'Nuevo episodio…' : 'New episode…'),
            leading: Icon(PhosphorIcons.plus()),
            onTap: () => Navigator.of(ctx).pop('new'),
          ),
        ],
      ),
    );
    if (pick == null || !context.mounted) return;
    if (pick == 'new') {
      await showEpisodeEditor(context, seed: c);
    } else {
      await ref.read(healthStoreProvider).setEpisode(c, pick);
    }
  }
}

class _Node extends StatelessWidget {
  const _Node({required this.followup, required this.spot});
  final bool followup;
  final bool spot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme.primary;
    if (spot) {
      return Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c.withValues(alpha: 0.14),
        ),
        child: Icon(PhosphorIcons.personSimple(), size: 10, color: c),
      );
    }
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: followup ? theme.colorScheme.surface : c,
        border: Border.all(
          color: followup ? theme.colorScheme.onSurfaceVariant : c,
          width: 2,
        ),
      ),
    );
  }
}

class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline({required this.filtered});
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final es = healthEs(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
      child: Column(
        children: [
          Icon(
            filtered ? PhosphorIcons.funnelSimple() : PhosphorIcons.firstAid(),
            size: 30,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          Text(
            filtered
                ? (es
                      ? 'Nada coincide con estos filtros.'
                      : 'Nothing matches these filters.')
                : (es ? 'Aún no hay nada registrado' : 'Nothing logged yet'),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (!filtered) ...[
            const SizedBox(height: 4),
            Text(
              es
                  ? 'Usa “Registrar cómo me siento” para anotar un síntoma, aunque sea una palabra.'
                  : 'Use “Log how I feel” to note a symptom — even a single word is enough.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HiddenNote extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(hiddenHealthCountProvider);
    if (n == 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final es = healthEs(context);
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIcons.lockSimple(),
            size: 13,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              es
                  ? '$n ${n == 1 ? 'entrada es privada' : 'entradas son privadas'} de otros alters.'
                  : '$n ${n == 1 ? 'entry is' : 'entries are'} private to other alters.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A deep-linked entry, shown above the tabs (or why it can't be opened).
class _LinkedEntry extends ConsumerWidget {
  const _LinkedEntry({
    required this.id,
    required this.followups,
    required this.members,
  });
  final String id;
  final List<TrackerRecord> followups;
  final Map<String, Member> members;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final es = healthEs(context);
    ref.watch(visibleHealthRecordsProvider);
    final (state, record) = lookupHealthRecord(ref, id);
    if (state == HealthLookup.found &&
        record != null &&
        record.kind == TrackerKind.healthCheckin) {
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PrismSectionHeader(title: es ? 'ENTRADA ENLAZADA' : 'LINKED ENTRY'),
            _TimelineRow(
              item: _Item(record.happenedAt, checkin: record),
              parent: null,
              followups: followups,
              spots: {for (final s in ref.watch(bodySpotsProvider)) s.id: s},
              members: members,
              expanded: true,
              last: true,
              onToggle: () {},
              onOpenSpot: (_) {},
            ),
          ],
        ),
      );
    }
    if (state == HealthLookup.found) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: PrismSurface(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              state == HealthLookup.hidden
                  ? PhosphorIcons.lockSimple()
                  : PhosphorIcons.question(),
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                state == HealthLookup.hidden
                    ? (es
                          ? 'Esta entrada es privada de otro alter y no se puede abrir con el frente actual.'
                          : 'This entry is private to another alter and can’t be opened with the current front.')
                    : (es
                          ? 'Esta entrada ya no existe.'
                          : 'This entry no longer exists.'),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotRow extends StatelessWidget {
  const _SpotRow({
    required this.spot,
    required this.number,
    required this.selected,
    required this.onTap,
  });
  final BodySpot spot;
  final int number;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final es = healthEs(context);
    final df = DateFormat.MMMd(context.dateLocale).add_jm();
    return Semantics(
      selected: selected,
      button: true,
      label: es ? 'Marcador $number' : 'Marker $number',
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.08)
              : null,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.primary.withValues(alpha: 0.14),
                ),
                child: Text(
                  '$number',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spot.placeLabel(es),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      [
                        if (spot.descriptors.isNotEmpty)
                          spot.descriptors.map((d) => d.label).join(', '),
                        if (spot.at != null) df.format(spot.at!),
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (spot.isLegacy)
                StatusTag(
                  text: es ? 'De Ánimo' : 'From Mood',
                  active: false,
                  icon: PhosphorIcons.smiley(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpotDetail extends StatelessWidget {
  const _SpotDetail({
    required this.spot,
    required this.number,
    required this.who,
  });
  final BodySpot spot;
  final int number;
  final Attribution who;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final es = healthEs(context);
    return PrismSurface(
      accentColor: theme.colorScheme.primary,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '$number',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  spot.placeLabel(es),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              PrismButton(label: es ? 'Editar' : 'Edit', icon: PhosphorIcons.pencilSimple(), density: PrismControlDensity.compact, onPressed: () => showSensationEditor(
                  context,
                  who: spot.record != null ? Attribution.of(spot.record!) : who,
                  initial: [spot],
                )),
            ],
          ),
          if (spot.descriptors.isNotEmpty)
            Text(
              spot.descriptors.map((d) => d.label).join(' · '),
              style: theme.textTheme.bodyMedium,
            ),
          if (spot.intensity != null)
            Text(
              '${spot.intensity}/10 · ${IntensityRating.words(spot.intensity!, es)}',
              style: theme.textTheme.bodySmall,
            ),
          if (spot.spreads.isNotEmpty)
            Text(
              '${es ? 'Se extiende a' : 'Spreads to'}: ${spot.spreads.map((p) => p.label(es)).join(' → ')}',
              style: theme.textTheme.bodySmall,
            ),
          if (spot.isLegacy)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                es
                    ? 'Registrado en Ánimo como “${spot.legacyText}”.'
                    : 'Recorded in Mood as “${spot.legacyText}”.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "Days with a logged symptom" for this period and the one before. Missing
/// days are labelled as unknown, not as symptom-free.
class _ComparePeriods extends StatelessWidget {
  const _ComparePeriods({required this.checkins});
  final List<TrackerRecord> checkins;

  @override
  Widget build(BuildContext context) {
    final es = healthEs(context);
    return PrismButton(
      label: es ? 'Comparar periodos' : 'Compare periods',
      icon: PhosphorIcons.chartBar(),
      density: PrismControlDensity.compact,
      onPressed: () => PrismSheet.show<void>(
        context: context,
        title: es ? 'Comparar periodos' : 'Compare periods',
        builder: (ctx) => _CompareBody(checkins: checkins),
      ),
    );
  }
}

class _CompareBody extends StatefulWidget {
  const _CompareBody({required this.checkins});
  final List<TrackerRecord> checkins;
  @override
  State<_CompareBody> createState() => _CompareBodyState();
}

class _CompareBodyState extends State<_CompareBody> {
  int _days = 14;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final es = healthEs(context);
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day + 1);
    final start = end.subtract(Duration(days: _days));
    final prevStart = start.subtract(Duration(days: _days));
    final cur = daysWithLoggedSymptom(widget.checkins, start, end);
    final prev = daysWithLoggedSymptom(widget.checkins, prevStart, start);
    final entriesCur = widget.checkins
        .where((c) => !c.happenedAt.isBefore(start))
        .length;
    Widget row(String label, int days, int of) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
          Text(
            es ? '$days de $of días' : '$days of $of days',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrismSegmentedControl<int>(
          segments: [
            PrismSegment(value: 7, label: es ? '7 días' : '7 days'),
            PrismSegment(value: 14, label: es ? '14 días' : '14 days'),
            PrismSegment(value: 30, label: es ? '30 días' : '30 days'),
          ],
          selected: _days,
          onChanged: (d) => setState(() => _days = d),
        ),
        const SizedBox(height: 12),
        HealthFormLabel(
          es
              ? 'Días con algún síntoma registrado'
              : 'Days with a logged symptom',
          top: 4,
        ),
        row(es ? 'Este periodo' : 'This period', cur, _days),
        Divider(
          height: 1,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        row(es ? 'Periodo anterior' : 'Previous period', prev, _days),
        const SizedBox(height: 8),
        Text(
          es
              ? '$entriesCur entradas en este periodo.'
              : '$entriesCur entries this period.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        PrismSurface(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                PhosphorIcons.info(),
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  es
                      ? 'Solo cuenta días con algo registrado. Un día sin registro es un día desconocido, no un día sin síntomas.'
                      : 'Only days with something logged are counted. A day without a log is unknown — not a symptom-free day.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterForm extends StatefulWidget {
  const _FilterForm({required this.initial});
  final _Filter initial;
  @override
  State<_FilterForm> createState() => _FilterFormState();
}

class _FilterFormState extends State<_FilterForm> {
  late int _days = widget.initial.days;
  late Set<SymptomCategory> _cats = {...widget.initial.categories};
  late final _descriptor = TextEditingController(
    text: widget.initial.descriptor,
  );
  late String? _region = widget.initial.regionId;
  late BodySide? _side = widget.initial.regionSide;
  late String _state = widget.initial.state;

  @override
  void dispose() {
    _descriptor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final es = healthEs(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HealthFormLabel(es ? 'Fechas' : 'Dates', top: 0),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (d, l) in [
              (0, es ? 'Todo' : 'All'),
              (7, es ? '7 días' : '7 days'),
              (30, es ? '30 días' : '30 days'),
              (90, es ? '90 días' : '90 days'),
            ])
              PrismChip(
                label: l,
                selected: _days == d,
                onTap: () => setState(() => _days = d),
              ),
          ],
        ),
        HealthFormLabel(es ? 'Estado' : 'State'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (v, l) in [
              ('all', es ? 'Todos' : 'All'),
              ('ongoing', es ? 'En curso' : 'Ongoing'),
              ('resolved', es ? 'Resueltos' : 'Resolved'),
            ])
              PrismChip(
                label: l,
                selected: _state == v,
                onTap: () => setState(() => _state = v),
              ),
          ],
        ),
        HealthFormLabel(es ? 'Categoría' : 'Category'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in SymptomCategory.values)
              PrismChip(
                label: symptomCategoryLabel(c, es),
                selected: _cats.contains(c),
                onTap: () => setState(
                  () => _cats.contains(c) ? _cats.remove(c) : _cats.add(c),
                ),
              ),
          ],
        ),
        HealthFormLabel(es ? 'Zona del cuerpo' : 'Body region'),
        Row(
          children: [
            Expanded(
              child: Text(
                _region == null
                    ? (es ? 'Cualquiera' : 'Any')
                    : regionById[_region]!.label(es, _side ?? BodySide.center),
              ),
            ),
            if (_region != null)
              PrismInlineIconButton(icon: PhosphorIcons.x(), onPressed: () => setState(() => _region = _side = null), tooltip: es ? 'Quitar' : 'Clear'),
            PrismButton(
              label: es ? 'Elegir' : 'Choose',
              density: PrismControlDensity.compact,
              onPressed: () async {
                final p = await showRegionList(context);
                if (p != null)
                  setState(() {
                    _region = p.regionId;
                    _side = p.side == BodySide.center ? null : p.side;
                  });
              },
            ),
          ],
        ),
        HealthFormLabel(es ? 'Descripción de la sensación' : 'Sensation word'),
        PrismTextField(
          controller: _descriptor,
          hintText: es
              ? 'p. ej. punzante, hormigueo'
              : 'e.g. throbbing, tingly',
        ),
        const SizedBox(height: 16),
        PrismButton(
          label: es ? 'Aplicar' : 'Apply',
          tone: PrismButtonTone.filled,
          expanded: true,
          onPressed: () => Navigator.of(context).pop(
            _Filter(
              days: _days,
              categories: _cats,
              descriptor: _descriptor.text.trim(),
              regionId: _region,
              regionSide: _side,
              state: _state,
            ),
          ),
        ),
      ],
    );
  }
}
