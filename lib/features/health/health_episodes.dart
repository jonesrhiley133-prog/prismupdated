import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:prism_plurality/features/health/health_model.dart';
import 'package:prism_plurality/features/health/health_widgets.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/widgets/prism_checkbox_row.dart';
import 'package:prism_plurality/shared/widgets/prism_inline_icon_button.dart';

/// Quick "Still happening / Changed / Resolved" follow-up. Appends a new
/// record; the original entry is never rewritten.
Future<void> showFollowup(
  BuildContext context,
  TrackerRecord checkin, {
  FollowStatus? status,
}) => PrismSheet.show<void>(
  context: context,
  title: healthEs(context) ? 'Seguimiento' : 'Follow-up',
  subtitle: checkin.title.isEmpty ? checkin.body : checkin.title,
  builder: (ctx) => _FollowupForm(checkin: checkin, initial: status),
);

class _FollowupForm extends ConsumerStatefulWidget {
  const _FollowupForm({required this.checkin, this.initial});
  final TrackerRecord checkin;
  final FollowStatus? initial;
  @override
  ConsumerState<_FollowupForm> createState() => _FollowupFormState();
}

class _FollowupFormState extends ConsumerState<_FollowupForm> {
  late FollowStatus? _status = widget.initial;
  Severity? _severity;
  final _note = TextEditingController();
  final _clientId = const Uuid().v4();
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _status == null) return;
    setState(() => _saving = true);
    await ref
        .read(healthStoreProvider)
        .addFollowup(
          clientId: _clientId,
          checkin: widget.checkin,
          status: _status!,
          note: _note.text,
          severity: _severity,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final es = healthEs(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HealthFormLabel(es ? 'Ahora mismo' : 'Right now', top: 0),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in FollowStatus.values)
                PrismChip(
                  label: followStatusLabel(s, es),
                  selected: _status == s,
                  onTap: () => setState(() => _status = s),
                ),
            ],
          ),
          if (_status == FollowStatus.changed ||
              _status == FollowStatus.still) ...[
            HealthFormLabel(
              es ? 'Gravedad ahora' : 'Severity now',
              optional: true,
            ),
            SeverityPicker(
              value: _severity,
              onChanged: (v) => setState(() => _severity = v),
            ),
          ],
          HealthFormLabel(
            es ? 'Observaciones' : 'Observations',
            optional: true,
          ),
          PrismTextField(
            controller: _note,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            hintText: es ? '¿Qué ha cambiado?' : 'What’s different?',
          ),
          const SizedBox(height: 16),
          PrismButton(
            label: es ? 'Añadir seguimiento' : 'Add follow-up',
            tone: PrismButtonTone.filled,
            expanded: true,
            isLoading: _saving,
            enabled: _status != null,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

/// Create or edit an episode, and choose which check-ins belong to it.
Future<void> showEpisodeEditor(
  BuildContext context, {
  TrackerRecord? existing,
  TrackerRecord? seed,
}) => PrismSheet.showFullScreen<void>(
  context: context,
  builder: (ctx, scroll) =>
      _EpisodeEditor(scroll: scroll, existing: existing, seed: seed),
);

class _EpisodeEditor extends ConsumerStatefulWidget {
  const _EpisodeEditor({required this.scroll, this.existing, this.seed});
  final ScrollController scroll;
  final TrackerRecord? existing;
  final TrackerRecord? seed;
  @override
  ConsumerState<_EpisodeEditor> createState() => _EpisodeEditorState();
}

class _EpisodeEditorState extends ConsumerState<_EpisodeEditor> {
  late final _title = TextEditingController(
    text: widget.existing?.title ?? widget.seed?.title ?? '',
  );
  final _note = TextEditingController();
  late DateTime _start =
      widget.existing?.occurredAt?.toLocal() ??
      widget.seed?.happenedAt ??
      DateTime.now();
  late bool _approx = widget.existing?.flag('approxStart') ?? false;
  late DateTime? _end = widget.existing?.endedAt?.toLocal();
  late EpisodeState _state = widget.existing?.episodeState ?? EpisodeState.open;
  late final String _clientId =
      widget.existing?.str('clientId') ?? const Uuid().v4();
  late Set<String> _members;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final checkins = ref.read(visibleHealthRecordsProvider).value ?? const [];
    _members = {
      for (final c in checkins)
        if (c.kind == TrackerKind.healthCheckin &&
            widget.existing != null &&
            c.episodeId == widget.existing!.id)
          c.id,
      ?widget.seed?.id,
    };
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _title.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final store = ref.read(healthStoreProvider);
    final checkins = [
      for (final c
          in ref.read(visibleHealthRecordsProvider).value ??
              const <TrackerRecord>[])
        if (c.kind == TrackerKind.healthCheckin) c,
    ];
    // An episode is seen by whoever can see its entries; use the first
    // entry's attribution, or the current alter's.
    final first = checkins.where((c) => _members.contains(c.id)).firstOrNull;
    final viewer = ref.read(healthViewerProvider);
    final who = widget.existing != null
        ? Attribution.of(widget.existing!)
        : (first != null
              ? Attribution.of(first).copyWith(author: viewer)
              : (viewer == null
                    ? const Attribution(scope: HealthScope.unsure)
                    : Attribution(subjects: [viewer], author: viewer)));
    final ep = await store.saveEpisode(
      clientId: _clientId,
      existing: widget.existing,
      who: who,
      title: _title.text,
      start: _start,
      approxStart: _approx,
      end: _end,
      state: _state,
      note: _note.text,
    );
    for (final c in checkins) {
      final inIt = _members.contains(c.id);
      if (inIt && c.episodeId != ep.id) await store.setEpisode(c, ep.id);
      if (!inIt && c.episodeId == ep.id) await store.setEpisode(c, null);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final es = healthEs(context);
    final checkins = [
      for (final c
          in ref.watch(visibleHealthRecordsProvider).value ??
              const <TrackerRecord>[])
        if (c.kind == TrackerKind.healthCheckin) c,
    ]..sort((a, b) => b.happenedAt.compareTo(a.happenedAt));
    final df = DateFormat.MMMd(context.dateLocale).add_jm();
    final stateChanged =
        widget.existing != null && widget.existing!.episodeState != _state;
    return SafeArea(
      child: Column(
        children: [
          HealthSheetBar(
            title: widget.existing == null
                ? (es ? 'Nuevo episodio' : 'New episode')
                : (es ? 'Editar episodio' : 'Edit episode'),
            canSave: _title.text.trim().isNotEmpty && !_saving,
            onSave: _save,
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  controller: widget.scroll,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    MediaQuery.viewInsetsOf(context).bottom + 32,
                  ),
                  children: [
                    HealthFormLabel(es ? 'Nombre' : 'Name', top: 8),
                    PrismTextField(
                      controller: _title,
                      autofocus: widget.existing == null,
                      textCapitalization: TextCapitalization.sentences,
                      hintText: es
                          ? 'p. ej. Garganta irritada y cansancio esta semana'
                          : 'e.g. Sore throat and fatigue this week',
                      onChanged: (_) => setState(() {}),
                    ),
                    HealthFormLabel(es ? 'Estado' : 'State'),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final s in EpisodeState.values)
                          PrismChip(
                            label: episodeStateLabel(s, es),
                            selected: _state == s,
                            onTap: () => setState(() => _state = s),
                          ),
                      ],
                    ),
                    if (stateChanged) ...[
                      HealthFormLabel(
                        es ? 'Nota sobre el cambio' : 'Note about this change',
                        optional: true,
                      ),
                      PrismTextField(
                        controller: _note,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        hintText: _state == EpisodeState.resolved
                            ? (es ? 'Cómo terminó' : 'How it wrapped up')
                            : null,
                      ),
                    ],
                    HealthFormLabel(es ? 'Empezó' : 'Started'),
                    PreciseTimeField(
                      label: es ? 'Inicio' : 'Start',
                      value: _start,
                      precision: _approx
                          ? TimePrecision.approx
                          : TimePrecision.exact,
                      allowUnknown: false,
                      onChanged: (at, p) => setState(() {
                        _start = at ?? _start;
                        _approx = p == TimePrecision.approx;
                      }),
                    ),
                    HealthFormLabel(es ? 'Terminó' : 'Ended', optional: true),
                    if (_end == null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: PrismButton(
                          label: es ? 'Añadir fecha de fin' : 'Add an end date',
                          density: PrismControlDensity.compact,
                          icon: PhosphorIcons.calendarCheck(),
                          onPressed: () =>
                              setState(() => _end = DateTime.now()),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: PreciseTimeField(
                              label: es ? 'Fin' : 'End',
                              value: _end,
                              precision: TimePrecision.exact,
                              allowUnknown: false,
                              onChanged: (at, _) => setState(() => _end = at),
                            ),
                          ),
                          PrismInlineIconButton(
                            icon: PhosphorIcons.x(),
                            onPressed: () => setState(() => _end = null),
                            tooltip: es ? 'Quitar fin' : 'Remove end',
                          ),
                        ],
                      ),
                    HealthFormLabel(
                      es ? 'Entradas incluidas' : 'Entries in this episode',
                      trailing: Text(
                        '${_members.length}',
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                    if (checkins.isEmpty)
                      Text(
                        es ? 'Aún no hay entradas.' : 'No entries yet.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    else
                      PrismSurface(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (final (i, c) in checkins.take(60).indexed) ...[
                              if (i > 0)
                                Divider(
                                  height: 1,
                                  indent: 16,
                                  color: theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.4),
                                ),
                              PrismCheckboxRow(
                                title: Text(
                                  c.title.isNotEmpty
                                      ? c.title
                                      : (c.body ?? (es ? 'Entrada' : 'Entry')),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  [
                                    df.format(c.happenedAt),
                                    if (c.episodeId != null &&
                                        c.episodeId != widget.existing?.id)
                                      es
                                          ? 'en otro episodio'
                                          : 'in another episode',
                                  ].join(' · '),
                                ),
                                value: _members.contains(c.id),
                                onChanged: (v) => setState(
                                  () => v == true
                                      ? _members.add(c.id)
                                      : _members.remove(c.id),
                                ),
                                checkboxAffinity: PrismCheckboxAffinity.leading,
                              ),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      es
                          ? 'Quitar una entrada del episodio no la borra.'
                          : 'Removing an entry from an episode doesn’t delete it.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
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
}

/// An episode's chronology: first report, added symptoms, follow-ups,
/// locations and state changes, in order.
Future<void> showEpisodeDetail(BuildContext context, TrackerRecord episode) =>
    PrismSheet.showFullScreen<void>(
      context: context,
      builder: (ctx, scroll) =>
          _EpisodeDetail(scroll: scroll, episodeId: episode.id),
    );

class _EpisodeDetail extends ConsumerWidget {
  const _EpisodeDetail({required this.scroll, required this.episodeId});
  final ScrollController scroll;
  final String episodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final es = healthEs(context);
    final records =
        ref.watch(visibleHealthRecordsProvider).value ??
        const <TrackerRecord>[];
    final ep = records.where((r) => r.id == episodeId).firstOrNull;
    if (ep == null) {
      return SafeArea(
        child: Column(
          children: [
            PrismSheetTopBar(title: es ? 'Episodio' : 'Episode'),
            Expanded(
              child: Center(
                child: Text(
                  es
                      ? 'Este episodio no está disponible.'
                      : 'This episode isn’t available.',
                ),
              ),
            ),
          ],
        ),
      );
    }
    final checkins = [
      for (final r in records)
        if (r.kind == TrackerKind.healthCheckin && r.episodeId == ep.id) r,
    ]..sort((a, b) => a.happenedAt.compareTo(b.happenedAt));
    final ids = {for (final c in checkins) c.id};
    final followups = [
      for (final r in records)
        if (r.kind == TrackerKind.healthFollowup && ids.contains(r.parentId)) r,
    ];
    final spots = ref
        .watch(bodySpotsProvider)
        .where((s) => ids.contains(s.checkinId))
        .toList();
    final df = DateFormat.MMMEd(context.dateLocale).add_jm();

    final events = <(DateTime, IconData, String, String?)>[];
    final seenSymptoms = <String>{};
    for (final (i, c) in checkins.indexed) {
      final names = c.symptoms.map((s) => s.label).toList();
      final added = [
        for (final n in names)
          if (seenSymptoms.add(n.toLowerCase())) n,
      ];
      events.add((
        c.happenedAt,
        i == 0 ? PhosphorIcons.flag() : PhosphorIcons.plusCircle(),
        i == 0
            ? (es ? 'Primer registro' : 'First report')
            : (added.isEmpty
                  ? (es ? 'Nueva entrada' : 'New entry')
                  : (es ? 'Síntomas añadidos' : 'Symptoms added')),
        [
          if (i == 0 || added.isNotEmpty) (i == 0 ? names : added).join(', '),
          ?c.body,
        ].where((x) => x.isNotEmpty).join(' — '),
      ));
    }
    for (final f in followups) {
      final st =
          FollowStatus.values
              .where((s) => s.name == f.str('status'))
              .firstOrNull ??
          FollowStatus.still;
      events.add((
        f.happenedAt,
        st == FollowStatus.resolved
            ? PhosphorIcons.checkCircle()
            : PhosphorIcons.arrowsClockwise(),
        followStatusLabel(st, es),
        f.body,
      ));
    }
    for (final s in spots) {
      events.add((
        s.at ?? DateTime.now(),
        PhosphorIcons.personSimple(),
        es ? 'Ubicación' : 'Location',
        [s.placeLabel(es), ...s.descriptors.map((d) => d.label)].join(' · '),
      ));
    }
    for (final l in ep.episodeLog) {
      events.add((
        l.at,
        PhosphorIcons.tag(),
        '${es ? 'Estado' : 'State'}: ${episodeStateLabel(l.state, es)}',
        l.note,
      ));
    }
    events.sort((a, b) => a.$1.compareTo(b.$1));

    Future<void> setState(EpisodeState s) async {
      String? note;
      if (s == EpisodeState.resolved || s == EpisodeState.reopened) {
        note = await askHealthText(
          context,
          title: s == EpisodeState.resolved
              ? (es ? 'Nota de cierre' : 'Resolution note')
              : (es ? 'Por qué se reabre' : 'Why it’s reopening'),
          hint: es ? 'Opcional' : 'Optional',
          action: es ? 'Guardar' : 'Save',
        );
        if (note == null) return;
      }
      await ref
          .read(healthStoreProvider)
          .saveEpisode(
            clientId: ep.str('clientId') ?? ep.id,
            existing: ep,
            who: Attribution.of(ep),
            title: ep.title,
            start: ep.occurredAt?.toLocal() ?? DateTime.now(),
            approxStart: ep.flag('approxStart'),
            end: s == EpisodeState.resolved
                ? DateTime.now()
                : (s == EpisodeState.reopened ? null : ep.endedAt?.toLocal()),
            state: s,
            note: note,
          );
    }

    final active = ep.episodeActive;
    return SafeArea(
      child: Column(
        children: [
          PrismSheetTopBar(
            title: es ? 'Episodio' : 'Episode',
            trailing: PrismInlineIconButton(
              icon: PhosphorIcons.pencilSimple(),
              onPressed: () => showEpisodeEditor(context, existing: ep),
              tooltip: es ? 'Editar' : 'Edit',
            ),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  children: [
                    Text(
                      ep.title.isEmpty
                          ? (es ? 'Sin título' : 'Untitled')
                          : ep.title,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusTag(
                          text: episodeStateLabel(ep.episodeState, es),
                          active: active,
                        ),
                        Text(
                          [
                            '${es ? 'Desde' : 'Since'} ${DateFormat.yMMMd(context.dateLocale).format(ep.occurredAt?.toLocal() ?? ep.createdAt)}${ep.flag('approxStart') ? (es ? ' (aprox.)' : ' (approx.)') : ''}',
                            if (ep.endedAt != null)
                              '${es ? 'hasta' : 'until'} ${DateFormat.yMMMd(context.dateLocale).format(ep.endedAt!.toLocal())}',
                            es
                                ? '${checkins.length} entradas'
                                : '${checkins.length} entries',
                          ].join(' · '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (active && ep.episodeState != EpisodeState.improving)
                          PrismButton(
                            label: es ? 'Mejorando' : 'Improving',
                            icon: PhosphorIcons.trendDown(),
                            density: PrismControlDensity.compact,
                            onPressed: () => setState(EpisodeState.improving),
                          ),
                        if (active)
                          PrismButton(
                            label: es ? 'Resolver' : 'Resolve',
                            icon: PhosphorIcons.checkCircle(),
                            density: PrismControlDensity.compact,
                            onPressed: () => setState(EpisodeState.resolved),
                          ),
                        if (!active)
                          PrismButton(
                            label: es ? 'Reabrir' : 'Reopen',
                            icon: PhosphorIcons.arrowCounterClockwise(),
                            density: PrismControlDensity.compact,
                            onPressed: () => setState(EpisodeState.reopened),
                          ),
                        PrismButton(
                          label: es ? 'Añadir entradas' : 'Attach entries',
                          icon: PhosphorIcons.folderSimplePlus(),
                          density: PrismControlDensity.compact,
                          onPressed: () =>
                              showEpisodeEditor(context, existing: ep),
                        ),
                      ],
                    ),
                    HealthFormLabel(es ? 'Cronología' : 'Chronology', top: 22),
                    if (events.isEmpty)
                      Text(
                        es
                            ? 'Añade entradas para ver su historia aquí.'
                            : 'Attach entries to see their history here.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    else
                      for (final (i, e) in events.indexed)
                        _ChronoRow(
                          icon: e.$2,
                          title: e.$3,
                          detail: e.$4,
                          time: df.format(e.$1),
                          last: i == events.length - 1,
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
}

class _ChronoRow extends StatelessWidget {
  const _ChronoRow({
    required this.icon,
    required this.title,
    this.detail,
    required this.time,
    required this.last,
  });
  final IconData icon;
  final String title;
  final String? detail;
  final String time;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    borderRadius: prismRound(context),
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  ),
                  child: Icon(icon, size: 14, color: theme.colorScheme.primary),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16, top: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        time,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (detail != null && detail!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(detail!, style: theme.textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
