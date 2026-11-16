import 'package:prism_plurality/shared/widgets/unsaved_changes_guard.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'health_data.dart';
import 'body_regions.dart';
import 'body_map_editor.dart';

class HealthScreen extends ConsumerStatefulWidget {
  const HealthScreen({super.key, this.entryId, this.initialTab = 0});
  final String? entryId;
  final int initialTab;
  @override
  ConsumerState<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends ConsumerState<HealthScreen> {
  String _query = '', _state = 'all';
  String? _alter;
  DateTimeRange? _dates;
  bool _compare = false;
  late int _tab = widget.initialTab;
  @override
  Widget build(BuildContext context) {
    final records = ref.watch(healthRecordsProvider);
    // Watching the current identity refreshes this entire view, including
    // already-open deep links and export review, when fronting changes.
    ref.watch(healthViewersProvider);
    final members = ref.watch(userVisibleMembersProvider).value ?? [];
    return PrismPageScaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      topBar: PrismTopBar(
        title: 'Health',
        actions: [
          PrismTopBarAction(
            icon: Icons.ios_share,
            tooltip: 'Export filtered records',
            onPressed: () => _export(context),
          ),
        ],
      ),
      body: records.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(
          child: Text('Health records could not be loaded. Try again.'),
        ),
        data: (all) {
          var visible = all
              .where(
                (r) =>
                    r.kind != healthVocabulary &&
                    (_alter == null ||
                        r.strings('subjects').contains(_alter)) &&
                    (_state == 'all' || r.str('status') == _state) &&
                    (_dates == null ||
                        (!(r.occurredAt ?? r.createdAt).isBefore(
                              _dates!.start,
                            ) &&
                            (r.occurredAt ?? r.createdAt).isBefore(
                              _dates!.end.add(const Duration(days: 1)),
                            ))) &&
                    healthSearchText(
                      '${r.title} ${r.data ?? ''}',
                    ).contains(_query),
              )
              .toList();
          if (widget.entryId != null) {
            visible = visible
                .where(
                  (r) =>
                      r.id == widget.entryId ||
                      r.str('legacyMoodId') == widget.entryId,
                )
                .toList();
          }
          return ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              NavBarInset.of(context) + 32,
            ),
            children: [
              ClampedBody(
                maxWidth: 600,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Private records of what you experience. No diagnoses or automatic interpretation.',
                    ),
                    const SizedBox(height: 12),
                    PrismButton(
                      label: 'Log how I feel',
                      icon: Icons.add,
                      tone: PrismButtonTone.filled,
                      onPressed: () =>
                          showHealthLog(context, mapFirst: _tab == 1),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _alter ?? '',
                      decoration: const InputDecoration(
                        labelText: 'Whose records are in view',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('All accessible records'),
                        ),
                        for (final m in members)
                          DropdownMenuItem(value: m.id, child: Text(m.name)),
                      ],
                      onChanged: (v) =>
                          setState(() => _alter = v!.isEmpty ? null : v),
                    ),
                    TextField(
                      decoration: const InputDecoration(
                        labelText:
                            'Search symptoms, categories, descriptors or regions',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (v) =>
                          setState(() => _query = v.toLowerCase()),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        DropdownButton<String>(
                          value: _state,
                          items: [
                            for (final s in [
                              'all',
                              'open',
                              'improving',
                              'resolved',
                              'reopened',
                              'unsure',
                            ])
                              DropdownMenuItem(value: s, child: Text(s)),
                          ],
                          onChanged: (v) => setState(() => _state = v!),
                        ),
                        TextButton(
                          onPressed: () async {
                            final r = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now(),
                              initialDateRange: _dates,
                            );
                            if (r != null && mounted) {
                              setState(() => _dates = r);
                            }
                          },
                          child: Text(
                            _dates == null
                                ? 'Filter dates'
                                : '${DateFormat.yMd().format(_dates!.start)} – ${DateFormat.yMd().format(_dates!.end)}',
                          ),
                        ),
                        if (_dates != null)
                          TextButton(
                            onPressed: () => setState(() => _dates = null),
                            child: const Text('Clear dates'),
                          ),
                      ],
                    ),
                    if (widget.entryId == null) ...[
                      for (final r
                          in visible
                              .where(
                                (r) =>
                                    r.kind == healthEpisode &&
                                    r.str('status') != 'resolved',
                              )
                              .take(3))
                        ListTile(
                          leading: const Icon(Icons.history),
                          title: Text(r.title),
                          subtitle: Text(
                            'Episode · ${r.str('status') ?? 'open'}',
                          ),
                        ),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final (i, label) in [
                            'Timeline',
                            'Body Map',
                            'Episodes',
                          ].indexed)
                            ChoiceChip(
                              label: Text(label),
                              selected: _tab == i,
                              onSelected: (_) => setState(() => _tab = i),
                            ),
                        ],
                      ),
                    ],
                    if (_tab == 2)
                      TextButton.icon(
                        onPressed: () => showHealthLog(context, episode: true),
                        icon: const Icon(Icons.add),
                        label: const Text('Create episode'),
                      ),
                    const SizedBox(height: 12),
                    if (visible
                        .where(
                          (r) => _tab == 2
                              ? r.kind == healthEpisode
                              : r.kind == healthCheckIn,
                        )
                        .isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No records in this view. Log a symptom, a body sensation, or how you feel in your own words.',
                        ),
                      ),
                    if (_tab == 1) const _VocabularyManager(),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Compare days with logged observations',
                      ),
                      value: _compare,
                      onChanged: (v) => setState(() => _compare = v),
                    ),
                    if (_compare)
                      Builder(
                        builder: (context) {
                          final start =
                              _dates?.start ??
                              DateTime.now().subtract(const Duration(days: 7));
                          final end =
                              _dates?.end.add(const Duration(days: 1)) ??
                              DateTime.now();
                          final prior = start.subtract(end.difference(start));
                          int count(DateTime a, DateTime b) => all
                              .where(
                                (r) =>
                                    r.kind == healthCheckIn &&
                                    (_alter == null ||
                                        r
                                            .strings('subjects')
                                            .contains(_alter)) &&
                                    (_state == 'all' ||
                                        r.str('status') == _state) &&
                                    healthSearchText(
                                      '${r.title} ${r.data ?? ''}',
                                    ).contains(_query) &&
                                    !(r.occurredAt ?? r.createdAt).isBefore(
                                      a,
                                    ) &&
                                    (r.occurredAt ?? r.createdAt).isBefore(b),
                              )
                              .map(
                                (r) => DateFormat.yMd().format(
                                  (r.occurredAt ?? r.createdAt).toLocal(),
                                ),
                              )
                              .toSet()
                              .length;
                          return Text(
                            '${count(start, end)} logged days in this period; ${count(prior, start)} in the preceding period of equal length. These are logging counts, not symptom-free days.',
                          );
                        },
                      ),
                    for (final group in _byDay(
                      visible.where(
                        (r) => _tab == 2
                            ? r.kind == healthEpisode
                            : r.kind == healthCheckIn,
                      ),
                    ).entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 8),
                        child: Text(
                          group.key,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      for (final r in group.value) _HealthRow(record: r),
                    ],
                    if (visible.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          '${visible.where((r) => r.kind == healthCheckIn).map((r) => DateFormat.yMd().format(r.occurredAt ?? r.createdAt)).toSet().length} days with a logged observation in this view. Days without a log are unknown.',
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Map<String, List<TrackerRecord>> _byDay(Iterable<TrackerRecord> rows) {
    final out = <String, List<TrackerRecord>>{};
    for (final r in rows) {
      (out[DateFormat.yMMMMd().format(
                (r.occurredAt ?? r.createdAt).toLocal(),
              )] ??=
              [])
          .add(r);
    }
    return out;
  }

  Future<void> _export(BuildContext context) async {
    await PrismSheet.showFullScreen(
      context: context,
      builder: (ctx, scroll) => _ExportHealthReview(
        query: _query,
        alter: _alter,
        status: _state,
        dates: _dates,
        scroll: scroll,
      ),
    );
  }
}

class _HealthRow extends ConsumerWidget {
  const _HealthRow({required this.record});
  final TrackerRecord record;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = record;
    final members = ref.watch(userVisibleMembersProvider).value ?? [];
    String name(String? id) =>
        members.where((m) => m.id == id).firstOrNull?.name ?? 'Unsure';
    final subject = r.str('subjectMode') == 'system'
        ? 'Whole system'
        : r.str('subjectMode') == 'unsure'
        ? 'Unsure'
        : r.strings('subjects').map(name).join(', ');
    final observations = healthMaps(r.fields['observations']);
    return Card(
      child: ExpansionTile(
        key: ValueKey('${r.id}:${ref.watch(healthViewersProvider)}'),
        title: Text(r.title),
        subtitle: Text(
          '$subject · ${r.str('status') ?? 'open'} · ${observations.isEmpty ? 'First report' : '${observations.length} follow-ups'}',
        ),
        childrenPadding: const EdgeInsets.all(16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Author: ${name(r.str('author'))} · Subject: $subject'),
          Text(
            'Happened: ${DateFormat.yMMMd().add_jm().format((r.occurredAt ?? r.createdAt).toLocal())}',
          ),
          if (r.occurredAt != r.createdAt)
            Text(
              'Recorded: ${DateFormat.yMMMd().add_jm().format(r.createdAt.toLocal())}',
            ),
          if (r.body != null) Text(r.body!),
          if (r.kind == healthEpisode) ...[
            const Text('Episode chronology'),
            for (final entry
                in ((ref.watch(healthRecordsProvider).value ?? [])
                    .where(
                      (e) =>
                          e.kind == healthCheckIn && e.str('episodeId') == r.id,
                    )
                    .toList()
                  ..sort(
                    (a, b) => (a.occurredAt ?? a.createdAt).compareTo(
                      b.occurredAt ?? b.createdAt,
                    ),
                  )))
              _HealthRow(record: entry),
          ],
          if (r.str('legacyMoodId') != null)
            const Text(
              'Preserved from a Mood check-in. Original ID, text and association retained.',
            ),
          for (final s in healthMaps(r.fields['symptoms'])) ...[
            Text(
              '${s['term']} · ${s['severity'] ?? 'Unsure'}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final e in s.entries.where(
              (e) =>
                  !['id', 'term', 'spots', 'severity'].contains(e.key) &&
                  e.value != null &&
                  '${e.value}'.isNotEmpty,
            ))
              Text('${e.key}: ${e.value}'),
            for (final spot in healthMaps(s['spots']))
              Text(
                '${spot['label'] ?? 'Location unspecified'} (${spot['side'] ?? 'unspecified'}, ${spot['view'] ?? 'unspecified'}) · ${(spot['descriptors'] as List? ?? []).join(', ')}${spot['legacyText'] == null ? '' : ' · Original: ${spot['legacyText']}'}',
              ),
          ],
          for (final o in observations)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${o['status']} · ${o['at']}'),
              subtitle: o['note'] == null ? null : Text('${o['note']}'),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (label, status) in [
                ('Still happening', 'open'),
                ('Changed', 'changed'),
                ('Resolved', 'resolved'),
                if (r.str('status') == 'resolved') ('Reopen', 'reopened'),
              ])
                TextButton(
                  onPressed: () async {
                    final note = await _ask(
                      context,
                      '$label — optional observation',
                    );
                    if (note == null || !context.mounted) return;
                    try {
                      await ref
                          .read(healthActionsProvider)
                          .followUp(r, status, note: note);
                    } catch (_) {
                      if (context.mounted) {
                        PrismToast.show(
                          context,
                          message:
                              'Could not save the follow-up. Please retry.',
                        );
                      }
                    }
                  },
                  child: Text(label),
                ),
              TextButton(
                onPressed: () => showHealthLog(
                  context,
                  editing: r,
                  episode: r.kind == healthEpisode,
                ),
                child: const Text('Edit / add details'),
              ),
              if (r.kind == healthCheckIn)
                TextButton(
                  onPressed: () async {
                    final episodes =
                        (ref.read(healthRecordsProvider).value ?? []).where(
                          (r) => r.kind == healthEpisode,
                        );
                    final id = await showDialog<String>(
                      context: context,
                      builder: (ctx) => SimpleDialog(
                        title: const Text('Attach to episode'),
                        children: [
                          SimpleDialogOption(
                            onPressed: () => Navigator.pop(ctx, ''),
                            child: const Text('Independent check-in'),
                          ),
                          for (final e in episodes)
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(ctx, e.id),
                              child: Text(e.title),
                            ),
                        ],
                      ),
                    );
                    if (id != null) {
                      await ref
                          .read(healthActionsProvider)
                          .save(
                            r.withFields({'episodeId': id.isEmpty ? null : id}),
                          );
                    }
                  },
                  child: const Text('Episode…'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<String?> _ask(BuildContext context, String title) async {
  final controller = TextEditingController();
  final value = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(controller: controller, maxLines: 3),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  // Dialog route disposal may still reference its controller during animation.
  return value;
}

Future<void> showHealthLog(
  BuildContext context, {
  TrackerRecord? editing,
  bool mapFirst = false,
  bool episode = false,
}) => PrismSheet.showFullScreen(
  context: context,
  builder: (ctx, scroll) => ProviderScope(
    overrides: [healthEditingRecordProvider.overrideWithValue(editing)],
    child: HealthAccessGuard(
      child: _HealthLog(
        editing: editing,
        mapFirst: mapFirst,
        episode: episode,
        scroll: scroll,
      ),
    ),
  ),
);

class _HealthLog extends ConsumerStatefulWidget {
  const _HealthLog({
    this.editing,
    this.scroll,
    this.mapFirst = false,
    this.episode = false,
  });
  final TrackerRecord? editing;
  final ScrollController? scroll;
  final bool mapFirst, episode;
  @override
  ConsumerState<_HealthLog> createState() => _HealthLogState();
}

class _HealthLogState extends ConsumerState<_HealthLog> {
  late final _title = TextEditingController(text: widget.editing?.title ?? '');
  late final _notes = TextEditingController(text: widget.editing?.body ?? '');
  late final String _id = widget.editing?.id ?? const Uuid().v4();
  late DateTime _at = widget.editing?.occurredAt ?? DateTime.now();
  late final List<Map<String, dynamic>> _symptoms = healthMaps(
    widget.editing?.fields['symptoms'],
  );
  late Set<String> _subjects = {
    ...widget.editing?.strings('subjects') ?? ref.read(healthViewersProvider),
  };
  late String _mode =
      widget.editing?.str('subjectMode') ??
      (_subjects.isEmpty ? 'unsure' : 'alters');
  late String? _author = widget.editing == null
      ? ref.read(healthViewersProvider).singleOrNull
      : widget.editing!.str('author');
  late String _status = widget.editing?.str('status') ?? 'open';
  late String _approximateStart = widget.editing?.str('approximateStart') ?? '';
  late String _episodeEnd = widget.editing?.str('episodeEnd') ?? '';
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    if (widget.mapFirst) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _addMap());
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _addMap() async {
    final spots = await showHealthBodyMap(context, []);
    if (spots != null && spots.isNotEmpty && mounted) {
      setState(
        () => _symptoms.add({
          'id': const Uuid().v4(),
          'term': 'Body sensations',
          'category': 'Sensation and coordination',
          'spots': spots,
        }),
      );
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_title.text.trim().isEmpty && _symptoms.isEmpty) {
      setState(() => _error = 'Add a symptom or a short description.');
      return;
    }
    if (_mode == 'alters' && _subjects.isEmpty) {
      setState(
        () => _error = 'Choose at least one alter, Whole system, or Unsure.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final r =
          (widget.editing ??
                  TrackerRecord(
                    id: _id,
                    kind: widget.episode ? healthEpisode : healthCheckIn,
                    createdAt: now,
                    modifiedAt: now,
                  ))
              .copyWith(
                title: _title.text.trim().isEmpty
                    ? _symptoms.map((s) => s['term']).join(', ')
                    : _title.text.trim(),
                body: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
                occurredAt: _at,
                memberId: _subjects.singleOrNull,
                isPrivate: true,
              )
              .withFields({
                'subjectMode': _mode,
                'subjects': _mode == 'alters' ? _subjects.toList() : [],
                'author': _author,
                'symptoms': _symptoms,
                'status': _status,
                if (widget.episode) 'approximateStart': _approximateStart,
                if (widget.episode) 'episodeEnd': _episodeEnd,
              });
      await ref.read(healthActionsProvider).save(r);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not save. Check attribution and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(healthViewersProvider, (before, after) {
      if (widget.editing == null &&
          before != null &&
          before.toString() != after.toString()) {
        setState(() {
          _subjects = {...after};
          _mode = after.isEmpty ? 'unsure' : 'alters';
          _author = after.singleOrNull;
          _error =
              'Fronting changed. Please review the author and subject before saving.';
        });
      }
    });
    final members = ref.watch(userVisibleMembersProvider).value ?? [];
    return UnsavedChangesGuard<void>(
      hasUnsavedChanges:
          !_saving &&
          (_title.text.isNotEmpty ||
              _notes.text.isNotEmpty ||
              _symptoms.isNotEmpty),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.episode ? 'Episode' : 'Log how I feel'),
          actions: [
            TextButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ],
        ),
        body: ListView(
          controller: widget.scroll,
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 32,
          ),
          children: [
            ClampedBody(
              maxWidth: 600,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null)
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  TextField(
                    controller: _title,
                    onChanged: (_) => setState(() {}),
                    autofocus: !widget.mapFirst,
                    decoration: InputDecoration(
                      labelText: widget.episode
                          ? 'Episode label'
                          : 'Symptom or short description',
                      hintText: 'Use your own words. Details are optional.',
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    key: ValueKey('author:$_author'),
                    initialValue: _author ?? '',
                    decoration: const InputDecoration(
                      labelText: 'Author — who is creating this entry',
                    ),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Unsure')),
                      for (final m in members.where(
                        (m) => ref.watch(healthViewersProvider).contains(m.id),
                      ))
                        DropdownMenuItem(value: m.id, child: Text(m.name)),
                    ],
                    onChanged: (v) =>
                        setState(() => _author = v!.isEmpty ? null : v),
                  ),
                  const SizedBox(height: 12),
                  const Text('Subject — who this describes'),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final mode in ['alters', 'system', 'unsure'])
                        ChoiceChip(
                          label: Text(switch (mode) {
                            'alters' => 'One or several alters',
                            'system' => 'Whole system',
                            _ => 'Unsure',
                          }),
                          selected: _mode == mode,
                          onSelected: (_) => setState(() => _mode = mode),
                        ),
                    ],
                  ),
                  if (_mode == 'alters')
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final m in members)
                          FilterChip(
                            label: Text(m.name),
                            selected: _subjects.contains(m.id),
                            onSelected: (v) => setState(
                              () => v
                                  ? _subjects.add(m.id)
                                  : _subjects.remove(m.id),
                            ),
                          ),
                      ],
                    ),
                  const Text(
                    'Private in Health. Whole-system records and Unsure records without an author are visible to the unlocked system. Nothing is posted to social profiles, Bulletin Board, or lock-screen notifications.',
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.schedule),
                    label: Text(
                      'Happened: ${DateFormat.yMMMd().add_jm().format(_at)}',
                    ),
                    onPressed: () async {
                      final day = await showDatePicker(
                        context: context,
                        initialDate: _at,
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (day == null || !context.mounted) return;
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(_at),
                      );
                      if (time != null && mounted) {
                        setState(
                          () => _at = DateTime(
                            day.year,
                            day.month,
                            day.day,
                            time.hour,
                            time.minute,
                          ),
                        );
                      }
                    },
                  ),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'State'),
                    items: [
                      for (final s in [
                        'open',
                        'improving',
                        'resolved',
                        'reopened',
                        'unsure',
                      ])
                        DropdownMenuItem(value: s, child: Text(s)),
                    ],
                    onChanged: (v) => setState(() => _status = v!),
                  ),
                  if (widget.episode) ...[
                    TextFormField(
                      initialValue: _approximateStart,
                      decoration: const InputDecoration(
                        labelText: 'Approximate start (optional)',
                        hintText: 'For example, earlier this week',
                      ),
                      onChanged: (v) => _approximateStart = v,
                    ),
                    TextFormField(
                      initialValue: _episodeEnd,
                      decoration: const InputDecoration(
                        labelText: 'End date (optional)',
                        hintText: 'YYYY-MM-DD, or Unsure',
                      ),
                      onChanged: (v) => _episodeEnd = v,
                    ),
                  ],
                  for (final s in _symptoms)
                    ListTile(
                      title: Text('${s['term']}'),
                      subtitle: Text(
                        '${s['severity'] ?? 'Unsure'} · ${healthMaps(s['spots']).length} locations',
                      ),
                      onTap: () async {
                        final next = await _editSymptom(context, s);
                        if (next != null && mounted) {
                          setState(
                            () => _symptoms[_symptoms.indexOf(s)] = next,
                          );
                        }
                      },
                      trailing: IconButton(
                        tooltip: 'Remove symptom',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _symptoms.remove(s)),
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          final s = await _editSymptom(context, {});
                          if (s != null && mounted) {
                            setState(() => _symptoms.add(s));
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add detailed symptom'),
                      ),
                      TextButton.icon(
                        onPressed: _addMap,
                        icon: const Icon(Icons.accessibility_new),
                        label: const Text('Add Body Map locations'),
                      ),
                    ],
                  ),
                  TextField(
                    controller: _notes,
                    onChanged: (_) => setState(() {}),
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Private notes (optional)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  PrismButton(
                    label: 'Save',
                    tone: PrismButtonTone.filled,
                    isLoading: _saving,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<Map<String, dynamic>?> _editSymptom(
  BuildContext context,
  Map<String, dynamic> initial,
) => PrismSheet.showFullScreen<Map<String, dynamic>>(
  context: context,
  builder: (ctx, scroll) => HealthAccessGuard(
    child: _SymptomDetails(initial: initial, scroll: scroll),
  ),
);

class _SymptomDetails extends ConsumerStatefulWidget {
  const _SymptomDetails({required this.initial, this.scroll});
  final Map<String, dynamic> initial;
  final ScrollController? scroll;
  @override
  ConsumerState<_SymptomDetails> createState() => _SymptomDetailsState();
}

class _SymptomDetailsState extends ConsumerState<_SymptomDetails> {
  late final Map<String, dynamic> _s = {...widget.initial};
  late final _term = TextEditingController(text: _s['term'] as String? ?? '');
  late List<Map<String, dynamic>> _spots = healthMaps(_s['spots']);
  String _search = '';
  @override
  void dispose() {
    _term.dispose();
    super.dispose();
  }

  Widget _text(String key, String label, {String? hint}) => TextFormField(
    initialValue: _s[key] as String?,
    decoration: InputDecoration(labelText: label, helperText: hint),
    onChanged: (v) => _s[key] = v,
  );
  Widget _choice(String key, String label, List<String> options) =>
      DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: options.contains(_s[key])
            ? _s[key] as String
            : options.first,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final o in options) DropdownMenuItem(value: o, child: Text(o)),
        ],
        onChanged: (v) => setState(() => _s[key] = v),
      );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Symptom details'),
      actions: [
        TextButton(
          onPressed: () {
            if (_term.text.trim().isEmpty) return;
            Navigator.pop(context, {
              ..._s,
              'id': _s['id'] ?? const Uuid().v4(),
              'term': _term.text.trim(),
              'category': _s['category'] ?? 'Custom',
              'spots': _spots,
            });
          },
          child: const Text('Done'),
        ),
      ],
    ),
    body: ListView(
      controller: widget.scroll,
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 32,
      ),
      children: [
        ClampedBody(
          maxWidth: 600,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _term,
                decoration: const InputDecoration(
                  labelText: 'Symptom / custom term',
                ),
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
              ),
              Wrap(
                spacing: 6,
                children: [
                  for (final term in {
                    for (final r
                        in ref.watch(healthRecordsProvider).value ?? [])
                      for (final s in healthMaps(r.fields['symptoms']))
                        if (s['term'] is String) s['term'] as String,
                  }.where((s) => healthSearchText(s).contains(_search)))
                    ActionChip(
                      label: Text(term),
                      onPressed: () => setState(() => _term.text = term),
                    ),
                ],
              ),
              for (final category in symptomCategories.entries)
                if (category.value.any(
                  (t) => healthSearchText(t).contains(_search),
                ))
                  ExpansionTile(
                    title: Text(category.key),
                    children: [
                      Wrap(
                        spacing: 6,
                        children: [
                          for (final term in category.value.where(
                            (t) => healthSearchText(t).contains(_search),
                          ))
                            ActionChip(
                              label: Text(term),
                              onPressed: () => setState(() {
                                _term.text = term;
                                _s['category'] = category.key;
                              }),
                            ),
                        ],
                      ),
                    ],
                  ),
              _choice('severity', 'Severity', [
                'Unsure',
                'Mild',
                'Moderate',
                'Severe',
                '0',
                '1',
                '2',
                '3',
                '4',
                '5',
                '6',
                '7',
                '8',
                '9',
                '10',
              ]),
              _text(
                'onset',
                'Onset / approximate start',
                hint: 'Optional; e.g. yesterday morning, or Unsure',
              ),
              _text(
                'end',
                'End / approximate end',
                hint: 'Optional; leave blank if ongoing or unknown',
              ),
              _choice('frequency', 'Frequency', [
                'Unsure',
                'Constant',
                'Intermittent',
              ]),
              _choice('course', 'Course', [
                'Unsure',
                'Sudden',
                'Gradual',
                'Improving',
                'Unchanged',
                'Worsening',
                'Resolved',
              ]),
              _text('triggers', 'Triggers (your observations)'),
              _text('relief', 'Relieving factors'),
              _text('tried', 'What you tried'),
              _text('afterward', 'What happened afterward'),
              _text(
                'impact',
                'Impact on daily life',
                hint:
                    'Sleep, eating, hydration, movement, school, work or concentration',
              ),
              _text(
                'measurement',
                'Self-entered measurement',
                hint:
                    'Optional. Include units, e.g. 37.5 °C or 99.5 °F. Not interpreted.',
              ),
              for (final s in _spots)
                ListTile(
                  title: Text('${s['label'] ?? 'Location unspecified'}'),
                  subtitle: Text('${s['side']} · ${s['view']}'),
                ),
              TextButton.icon(
                onPressed: () async {
                  final spots = await showHealthBodyMap(context, _spots);
                  if (spots != null && mounted) setState(() => _spots = spots);
                },
                icon: const Icon(Icons.accessibility_new),
                label: const Text('Edit Body Map locations'),
              ),
              _text('notes', 'Private symptom notes'),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ExportHealthReview extends ConsumerStatefulWidget {
  const _ExportHealthReview({
    required this.query,
    required this.alter,
    required this.status,
    required this.dates,
    this.scroll,
  });
  final String query, status;
  final String? alter;
  final DateTimeRange? dates;
  final ScrollController? scroll;
  @override
  ConsumerState<_ExportHealthReview> createState() => _ExportHealthState();
}

class _ExportHealthState extends ConsumerState<_ExportHealthReview> {
  bool _identity = false, _notes = false, _busy = false;
  @override
  Widget build(BuildContext context) {
    final rows = (ref.watch(healthRecordsProvider).value ?? [])
        .where(
          (r) =>
              r.kind != healthVocabulary &&
              (widget.alter == null ||
                  r.strings('subjects').contains(widget.alter)) &&
              (widget.status == 'all' || r.str('status') == widget.status) &&
              healthSearchText(
                '${r.title} ${r.data ?? ''}',
              ).contains(widget.query) &&
              (widget.dates == null ||
                  (!(r.occurredAt ?? r.createdAt).isBefore(
                        widget.dates!.start,
                      ) &&
                      (r.occurredAt ?? r.createdAt).isBefore(
                        widget.dates!.end.add(const Duration(days: 1)),
                      ))),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Review Health export')),
      body: ListView(
        controller: widget.scroll,
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${rows.length} accessible records. ${widget.dates == null ? 'All dates' : widget.dates.toString()}. Filter: ${widget.status} / ${widget.query}.',
          ),
          const Text(
            'This creates an unencrypted JSON summary. Save it somewhere private.',
          ),
          SwitchListTile(
            title: const Text('Include identity'),
            value: _identity,
            onChanged: (v) => setState(() => _identity = v),
          ),
          SwitchListTile(
            title: const Text('Include private notes'),
            value: _notes,
            onChanged: (v) => setState(() => _notes = v),
          ),
          for (final r in rows)
            ListTile(
              title: Text(r.title),
              subtitle: Text(
                DateFormat.yMMMd().format(r.occurredAt ?? r.createdAt),
              ),
            ),
          PrismButton(
            label: 'Export these records',
            isLoading: _busy,
            onPressed: () async {
              if (_busy) return;
              setState(() => _busy = true);
              try {
                await FilePicker.saveFile(
                  dialogTitle: 'Save Health summary',
                  fileName: 'prism-health.json',
                  type: FileType.custom,
                  allowedExtensions: ['json'],
                  bytes: Uint8List.fromList(
                    utf8.encode(
                      healthSummary(rows, identity: _identity, notes: _notes),
                    ),
                  ),
                );
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _VocabularyManager extends ConsumerWidget {
  const _VocabularyManager();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = (ref.watch(healthRecordsProvider).value ?? [])
        .where((r) => r.kind == healthVocabulary)
        .toList();
    if (rows.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      title: const Text('Custom sensation vocabulary'),
      subtitle: const Text(
        'Rename or retire terms; past observations retain their wording.',
      ),
      children: [
        for (final r in rows)
          ListTile(
            title: Text(r.title),
            subtitle: Text(
              '${r.str('region') ?? 'Any region'}${r.flag('retired') ? ' · Retired' : ''}',
            ),
            trailing: Wrap(
              children: [
                IconButton(
                  tooltip: 'Rename term',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    final term = await _ask(context, 'New descriptor name');
                    if (term != null && term.trim().isNotEmpty) {
                      await ref
                          .read(healthActionsProvider)
                          .save(r.copyWith(title: term.trim()));
                    }
                  },
                ),
                IconButton(
                  tooltip: r.flag('retired') ? 'Restore term' : 'Retire term',
                  icon: Icon(
                    r.flag('retired') ? Icons.restore : Icons.archive_outlined,
                  ),
                  onPressed: () => ref
                      .read(healthActionsProvider)
                      .save(r.withFields({'retired': !r.flag('retired')})),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
