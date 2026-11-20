import 'dart:async';

import 'package:uuid/uuid.dart';

import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/health/health_model.dart';
import 'package:prism_plurality/features/health/health_widgets.dart';
import 'package:prism_plurality/features/health/sensation_editor.dart';
import 'package:prism_plurality/features/health/symptom_catalog.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/widgets/prism_inline_icon_button.dart';

/// "Log how I feel": a quick entry that can grow into a detailed one.
Future<void> showHealthLog(BuildContext context, {TrackerRecord? existing, Map<String, dynamic>? draft, String? episodeId}) => PrismSheet.showFullScreen<void>(
  context: context,
  builder: (ctx, scroll) => _HealthLog(scroll: scroll, existing: existing, draft: draft, episodeId: episodeId),
);

/// Common symptoms offered before the user types anything.
const _quickPicks = ['headache', 'fatigue', 'nausea', 'sore_throat', 'congestion', 'dizziness', 'aching', 'cough', 'cramping_gi', 'feverish'];

class _HealthLog extends ConsumerStatefulWidget {
  const _HealthLog({required this.scroll, this.existing, this.draft, this.episodeId});
  final ScrollController scroll;
  final TrackerRecord? existing;
  final Map<String, dynamic>? draft;
  final String? episodeId;

  @override
  ConsumerState<_HealthLog> createState() => _HealthLogState();
}

class _HealthLogState extends ConsumerState<_HealthLog> {
  late String _clientId;
  late Attribution _who;
  bool _whoTouched = false;
  String? _authorAtOpen;
  final _search = TextEditingController();
  final _quick = TextEditingController();
  List<HealthSymptom> _symptoms = [];
  final Set<String> _expanded = {};
  final Map<String, List<BodySpot>> _spots = {};
  late DateTime _at;
  TimePrecision _precision = TimePrecision.exact;
  bool _earlier = false;
  String? _episodeId;
  bool _saving = false;
  Timer? _draftTimer;
  String? _frontNotice;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final viewer = ref.read(healthViewerProvider);
    _authorAtOpen = viewer;
    final e = widget.existing;
    final d = widget.draft;
    if (e != null) {
      _clientId = e.str('clientId') ?? const Uuid().v4();
      _who = Attribution.of(e);
      _whoTouched = true;
      _symptoms = e.symptoms;
      _quick.text = e.body ?? '';
      _at = e.happenedAt;
      _precision = e.timePrecision;
      _earlier = e.backdated;
      _episodeId = e.episodeId;
      final spots = ref.read(bodySpotsProvider);
      for (final s in _symptoms) {
        _spots[s.id] = [for (final sp in spots) if (s.spotIds.contains(sp.id)) sp];
      }
    } else if (d != null) {
      _clientId = (d['clientId'] as String?) ?? const Uuid().v4();
      _who = Attribution(
        scope: HealthScope.values.where((s) => s.name == d['scope']).firstOrNull ?? HealthScope.members,
        subjects: [for (final s in (d['subjects'] as List?) ?? const []) if (s is String) s],
        author: viewer,
        visibility: d['visibility'] == 'system' ? HealthVisibility.system : HealthVisibility.private,
      );
      _whoTouched = d['whoTouched'] == true;
      _quick.text = (d['quick'] as String?) ?? '';
      _symptoms = [for (final s in (d['symptoms'] as List?) ?? const []) if (s is Map) HealthSymptom.fromJson(s.cast<String, dynamic>())];
      _at = DateTime.tryParse('${d['at']}')?.toLocal() ?? DateTime.now();
      _precision = TimePrecision.values.where((p) => p.name == d['precision']).firstOrNull ?? TimePrecision.exact;
      _earlier = d['earlier'] == true;
      _episodeId = d['episodeId'] as String? ?? widget.episodeId;
    } else {
      _clientId = const Uuid().v4();
      _who = _defaultWho(viewer);
      _at = DateTime.now();
      _episodeId = widget.episodeId;
    }
  }

  Attribution _defaultWho(String? viewer) =>
      viewer == null ? const Attribution(scope: HealthScope.unsure) : Attribution(scope: HealthScope.members, subjects: [viewer], author: viewer);

  @override
  void dispose() {
    _draftTimer?.cancel();
    _search.dispose();
    _quick.dispose();
    super.dispose();
  }

  void _changed() {
    setState(() {});
    if (_editing) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 600), () {
      if (!_hasContent) {
        HealthDrafts.clear(_authorAtOpen);
        return;
      }
      HealthDrafts.save(_authorAtOpen, {
        'clientId': _clientId,
        'scope': _who.scope.name,
        'subjects': _who.subjects,
        'visibility': _who.visibility.name,
        'whoTouched': _whoTouched,
        'quick': _quick.text,
        'symptoms': [for (final s in _symptoms) s.toJson()],
        'at': _at.toUtc().toIso8601String(),
        'precision': _precision.name,
        'earlier': _earlier,
        'episodeId': _episodeId,
        'savedAt': DateTime.now().toUtc().toIso8601String(),
      });
      ref.invalidate(healthDraftProvider);
    });
  }

  bool get _hasContent => _symptoms.isNotEmpty || _quick.text.trim().isNotEmpty;

  void _addSymptom(SymptomTerm t, bool es) {
    if (_symptoms.any((s) => s.termId == t.id)) return;
    _symptoms = [..._symptoms, HealthSymptom(termId: t.id, label: t.label(es), category: t.category)];
    _search.clear();
    _changed();
  }

  Future<void> _addCustom(bool es) async {
    final text = _search.text.trim();
    if (text.isEmpty) return;
    final r = await ref.read(healthStoreProvider).addCustomTerm(type: 'symptom', label: text);
    _addSymptom(SymptomTerm('custom:${r.id}', SymptomCategory.other, r.title, r.title), es);
  }

  void _updateSymptom(String id, HealthSymptom Function(HealthSymptom) f) {
    _symptoms = [for (final s in _symptoms) s.id == id ? f(s) : s];
    _changed();
  }

  Future<void> _markOnMap(HealthSymptom s) async {
    final es = healthEs(context);
    final result = await showSensationEditor(context, who: _who, initial: _spots[s.id] ?? const [], save: false, title: es ? 'Dónde: ${s.label}' : 'Where: ${s.label}');
    if (result == null) return;
    setState(() => _spots[s.id] = result);
  }

  Future<void> _save() async {
    if (_saving || !_canSave) return;
    setState(() => _saving = true);
    final store = ref.read(healthStoreProvider);
    try {
      var symptoms = _symptoms;
      var rec = await store.saveCheckin(
        clientId: _clientId,
        existing: widget.existing,
        who: _who,
        symptoms: symptoms,
        quickText: _quick.text,
        happenedAt: _earlier ? _at : (widget.existing?.happenedAt ?? DateTime.now()),
        precision: _earlier ? _precision : TimePrecision.exact,
        episodeId: _episodeId,
      );
      if (_spots.values.any((l) => l.isNotEmpty) || _editing) {
        final updated = <HealthSymptom>[];
        for (final s in symptoms) {
          final ids = <String>[];
          for (final sp in _spots[s.id] ?? const <BodySpot>[]) {
            final saved = await store.saveSpot(
              clientId: sp.record?.str('clientId') ?? '$_clientId/${sp.id}',
              existing: sp.record,
              who: _who,
              spot: BodySpot(id: sp.id, regionId: sp.regionId, side: sp.side, view: sp.view, x: sp.x, y: sp.y, customLabel: sp.customLabel, descriptors: sp.descriptors, intensity: sp.intensity, notes: sp.notes, spreads: sp.spreads, at: sp.at, checkinId: rec.id),
            );
            ids.add(saved.id);
          }
          updated.add(s.copyWith(spotIds: ids));
        }
        symptoms = updated;
        rec = await store.saveCheckin(clientId: _clientId, existing: rec, who: _who, symptoms: symptoms, quickText: _quick.text, happenedAt: rec.happenedAt, precision: rec.timePrecision, episodeId: _episodeId);
      }
      await HealthDrafts.clear(_authorAtOpen);
      ref.invalidate(healthDraftProvider);
      if (mounted) {
        Navigator.of(context).pop();
        PrismToast.show(context, message: healthEs(context) ? 'Guardado en Salud' : 'Saved to Health', icon: PhosphorIcons.check());
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool get _canSave => _who.valid && _hasContent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final es = healthEs(context);
    final members = {for (final m in ref.watch(userVisibleMembersProvider).value ?? const <Member>[]) m.id: m};

    // Keep the draft's attribution in step with the front until the user
    // chooses someone explicitly, and say so when it changes.
    ref.listen<String?>(healthViewerProvider, (prev, next) {
      if (_editing || prev == next) return;
      setState(() {
        if (!_whoTouched) _who = _defaultWho(next);
        _who = _who.copyWith(author: next);
        final name = next == null ? null : members[next]?.effectiveName(preferDisplayName: ref.read(memberNamePreferDisplayProvider));
        _frontNotice = name == null
            ? (es ? 'Ya no hay nadie marcado al frente.' : 'No one is marked as fronting now.')
            : (es ? '$name está al frente ahora. Revisa para quién es esta entrada.' : '$name is fronting now. Check who this entry is for.');
      });
    });

    final q = _search.text.trim();
    final vocab = ref.watch(healthVocabProvider);
    final suggestions = q.isEmpty ? [for (final id in _quickPicks) symptomById[id]!] : searchSymptoms(q, es, custom: vocab.symptoms).take(10).toList();
    final exact = suggestions.any((t) => t.label(es).toLowerCase() == q.toLowerCase());
    final episodes = [
      for (final r in ref.watch(visibleHealthRecordsProvider).value ?? const <TrackerRecord>[])
        if (r.kind == TrackerKind.healthEpisode && (r.episodeActive || r.id == _episodeId)) r,
    ];

    return SafeArea(
      child: Column(
        children: [
          HealthSheetBar(title: _editing ? (es ? 'Editar entrada' : 'Edit entry') : (es ? 'Cómo me siento' : 'Log how I feel'), canSave: _canSave && !_saving, onSave: _save),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  controller: widget.scroll,
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(context).bottom + 40),
                  children: [
                    if (_frontNotice != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: PrismSurface(
                          accentColor: theme.colorScheme.primary,
                          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                          child: Row(
                            children: [
                              Icon(PhosphorIcons.arrowsLeftRight(), size: 18, color: theme.colorScheme.primary),
                              const SizedBox(width: 10),
                              Expanded(child: Text(_frontNotice!, style: theme.textTheme.bodyMedium)),
                              PrismInlineIconButton(icon: PhosphorIcons.x(), onPressed: () => setState(() => _frontNotice = null), tooltip: es ? 'Cerrar' : 'Dismiss'),
                            ],
                          ),
                        ),
                      ),
                    HealthFormLabel(es ? 'Para quién' : 'Who this is about', top: 10),
                    AttributionPicker(
                      value: _who,
                      onChanged: (w) {
                        _who = w;
                        _whoTouched = true;
                        _changed();
                      },
                    ),
                    HealthFormLabel(es ? 'Qué está pasando' : 'What’s going on'),
                    PrismTextField(
                      controller: _search,
                      hintText: es ? 'Busca un síntoma (p. ej. dolor de cabeza, náuseas)' : 'Find a symptom (e.g. headache, nausea)',
                      prefixIcon: Icon(PhosphorIcons.magnifyingGlass()),
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) {
                        if (suggestions.isNotEmpty && q.isNotEmpty) {
                          _addSymptom(suggestions.first, es);
                        } else if (q.isNotEmpty) {
                          _addCustom(es);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final t in suggestions)
                          PrismChip(
                            label: t.label(es),
                            selected: _symptoms.any((s) => s.termId == t.id),
                            onTap: () => _symptoms.any((s) => s.termId == t.id) ? null : _addSymptom(t, es),
                          ),
                        if (q.isNotEmpty && !exact)
                          PrismChip(label: es ? 'Añadir “$q”' : 'Add “$q”', selected: false, avatar: Icon(PhosphorIcons.plus(), size: 14), onTap: () => _addCustom(es)),
                      ],
                    ),
                    if (q.isNotEmpty && suggestions.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          suggestions.map((t) => symptomCategoryLabel(t.category, es)).toSet().take(3).join(' · '),
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    const SizedBox(height: 12),
                    PrismTextField(
                      controller: _quick,
                      minLines: 2,
                      maxLines: 6,
                      textCapitalization: TextCapitalization.sentences,
                      hintText: es ? 'O descríbelo con tus palabras' : 'Or describe it in your own words',
                      onChanged: (_) => _changed(),
                    ),
                    for (final (i, s) in _symptoms.indexed)
                      _SymptomCard(
                        key: ValueKey(s.id),
                        index: i + 1,
                        symptom: s,
                        expanded: _expanded.contains(s.id),
                        spots: _spots[s.id] ?? const [],
                        onToggle: () => setState(() => _expanded.contains(s.id) ? _expanded.remove(s.id) : _expanded.add(s.id)),
                        onChanged: (f) => _updateSymptom(s.id, f),
                        onRemove: () {
                          _symptoms = [for (final x in _symptoms) if (x.id != s.id) x];
                          _spots.remove(s.id);
                          _changed();
                        },
                        onMap: () => _markOnMap(s),
                      ),
                    HealthFormLabel(es ? 'Cuándo pasó' : 'When it happened'),
                    PrismSegmentedControl<bool>(
                      segments: [PrismSegment(value: false, label: _editing ? (es ? 'Como estaba' : 'As recorded') : (es ? 'Ahora' : 'Now')), PrismSegment(value: true, label: es ? 'Otro momento' : 'Earlier / other time')],
                      selected: _earlier,
                      onChanged: (v) {
                        _earlier = v;
                        _changed();
                      },
                    ),
                    if (_earlier) ...[
                      const SizedBox(height: 12),
                      PreciseTimeField(
                        label: es ? 'Fecha y hora' : 'Date and time',
                        value: _at,
                        precision: _precision,
                        allowUnknown: false,
                        onChanged: (at, p) {
                          _at = at ?? _at;
                          _precision = p;
                          _changed();
                        },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        es ? 'Se guardará también la hora en que lo registras.' : 'The time you record it is saved too.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                    if (episodes.isNotEmpty) ...[
                      HealthFormLabel(es ? 'Episodio' : 'Episode', optional: true),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          PrismChip(label: es ? 'Ninguno' : 'None', selected: _episodeId == null, onTap: () {
                            _episodeId = null;
                            _changed();
                          }),
                          for (final e in episodes)
                            PrismChip(label: e.title.isEmpty ? (es ? 'Sin título' : 'Untitled') : e.title, selected: _episodeId == e.id, onTap: () {
                              _episodeId = e.id;
                              _changed();
                            }),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    PrismButton(
                      label: _editing ? (es ? 'Guardar cambios' : 'Save changes') : (es ? 'Guardar entrada' : 'Save entry'),
                      icon: AppIcons.check,
                      tone: PrismButtonTone.filled,
                      expanded: true,
                      isLoading: _saving,
                      enabled: _canSave,
                      onPressed: _save,
                    ),
                    if (!_who.valid)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(es ? 'Elige para quién es, o “No estoy seguro”.' : 'Choose who this is about, or “Unsure”.', textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(PhosphorIcons.lockSimple(), size: 13, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            es ? 'Las entradas de Salud no aparecen en el tablón, perfiles sociales ni notificaciones.' : 'Health entries never appear on the Bulletin Board, social profiles or notifications.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ],
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

class _SymptomCard extends StatelessWidget {
  const _SymptomCard({
    super.key,
    required this.index,
    required this.symptom,
    required this.expanded,
    required this.spots,
    required this.onToggle,
    required this.onChanged,
    required this.onRemove,
    required this.onMap,
  });

  final int index;
  final HealthSymptom symptom;
  final bool expanded;
  final List<BodySpot> spots;
  final VoidCallback onToggle;
  final void Function(HealthSymptom Function(HealthSymptom)) onChanged;
  final VoidCallback onRemove;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final es = healthEs(context);
    final s = symptom;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: PrismSurface(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(es ? 'SÍNTOMA $index' : 'SYMPTOM $index', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.1, color: theme.colorScheme.primary)),
                const SizedBox(width: 8),
                Expanded(child: Text(s.label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                PrismInlineIconButton(icon: PhosphorIcons.x(), onPressed: onRemove, tooltip: es ? 'Quitar síntoma' : 'Remove symptom'),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HealthFormLabel(es ? 'Gravedad' : 'Severity', optional: true, top: 4),
                  SeverityPicker(value: s.severity, onChanged: (v) => onChanged((x) => x.copyWith(severity: v))),
                  if (!expanded) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        PrismButton(label: es ? 'Añadir detalles' : 'Add details', icon: PhosphorIcons.listPlus(), density: PrismControlDensity.compact, onPressed: onToggle),
                        const SizedBox(width: 8),
                        PrismButton(label: spots.isEmpty ? (es ? 'Marcar en el cuerpo' : 'Mark on body') : (es ? '${spots.length} en el cuerpo' : '${spots.length} on body'), icon: PhosphorIcons.personSimple(), density: PrismControlDensity.compact, onPressed: onMap),
                      ],
                    ),
                  ] else ...[
                    HealthFormLabel(es ? 'Puntuación 0–10' : 'Rating 0–10', optional: true),
                    IntensityRating(value: s.score, onChanged: (v) => onChanged((x) => x.copyWith(score: v))),
                    HealthFormLabel(es ? 'Empezó' : 'Started', optional: true),
                    PreciseTimeField(label: es ? 'Inicio' : 'Onset', value: s.onset, precision: s.onsetPrecision, onChanged: (at, p) => onChanged((x) => x.copyWith(onset: at, onsetPrecision: p))),
                    HealthFormLabel(es ? 'Terminó' : 'Ended', optional: true),
                    PreciseTimeField(label: es ? 'Fin' : 'End', value: s.end, precision: s.endPrecision, emptyLabel: es ? 'Sigue (o sin indicar)' : 'Still going (or not set)', onChanged: (at, p) => onChanged((x) => x.copyWith(end: at, endPrecision: p))),
                    HealthFormLabel(es ? 'Cómo va' : 'Pattern & course', optional: true),
                    _MultiChips(options: courseOptions, selected: s.course, onChanged: (v) => onChanged((x) => x.copyWith(course: v))),
                    HealthFormLabel(es ? 'Dónde' : 'Where', optional: true),
                    if (spots.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          spots.map((p) => [p.placeLabel(es), ...p.descriptors.map((d) => d.label)].join(' · ')).join('\n'),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: PrismButton(label: spots.isEmpty ? (es ? 'Marcar en el mapa corporal' : 'Mark on the Body Map') : (es ? 'Editar ubicaciones' : 'Edit locations'), icon: PhosphorIcons.personSimple(), density: PrismControlDensity.compact, onPressed: onMap),
                    ),
                    HealthFormLabel(es ? 'Cómo afecta' : 'Affects', optional: true),
                    _MultiChips(options: impactOptions, selected: s.impact, onChanged: (v) => onChanged((x) => x.copyWith(impact: v))),
                    HealthFormLabel(es ? 'Desencadenantes' : 'Triggers', optional: true),
                    PrismTextField(initialValue: s.triggers, hintText: es ? '¿Qué parece empeorarlo o provocarlo?' : 'What seems to bring it on or make it worse?', onChanged: (v) => onChanged((x) => x.copyWith(triggers: v))),
                    HealthFormLabel(es ? 'Qué alivia' : 'What helps', optional: true),
                    PrismTextField(initialValue: s.relief, hintText: es ? 'Lo que lo hace más llevadero' : 'Anything that eases it', onChanged: (v) => onChanged((x) => x.copyWith(relief: v))),
                    HealthFormLabel(es ? 'Lo que probé' : 'What I tried', optional: true),
                    PrismTextField(initialValue: s.tried, hintText: es ? 'Descanso, agua, calor…' : 'Rest, water, heat…', onChanged: (v) => onChanged((x) => x.copyWith(tried: v))),
                    HealthFormLabel(es ? 'Qué pasó después' : 'What happened afterwards', optional: true),
                    PrismTextField(initialValue: s.after, hintText: es ? 'Tus observaciones' : 'Your own observations', onChanged: (v) => onChanged((x) => x.copyWith(after: v))),
                    HealthFormLabel(es ? 'Temperatura · introducida por ti' : 'Temperature · self-entered', optional: true),
                    _TemperatureField(value: s.tempValue, unit: s.tempUnit, onChanged: (v, u) => onChanged((x) => x.copyWith(tempValue: v, tempUnit: u))),
                    HealthFormLabel(es ? 'Notas' : 'Notes', optional: true),
                    PrismTextField(initialValue: s.notes, minLines: 2, maxLines: 6, textCapitalization: TextCapitalization.sentences, onChanged: (v) => onChanged((x) => x.copyWith(notes: v))),
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerLeft, child: PrismButton(label: es ? 'Ocultar detalles' : 'Hide details', density: PrismControlDensity.compact, onPressed: onToggle)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MultiChips extends StatelessWidget {
  const _MultiChips({required this.options, required this.selected, required this.onChanged});
  final List<(String, String, String)> options;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final es = healthEs(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (id, en, esLabel) in options)
          PrismChip(
            label: es ? esLabel : en,
            selected: selected.contains(id),
            onTap: () => onChanged(selected.contains(id) ? [for (final x in selected) if (x != id) x] : [...selected, id]),
          ),
      ],
    );
  }
}

class _TemperatureField extends StatefulWidget {
  const _TemperatureField({required this.value, required this.unit, required this.onChanged});
  final double? value;
  final String unit;
  final void Function(double? value, String unit) onChanged;
  @override
  State<_TemperatureField> createState() => _TemperatureFieldState();
}

class _TemperatureFieldState extends State<_TemperatureField> {
  late final _c = TextEditingController(text: widget.value?.toString() ?? '');

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 130,
          child: PrismTextField(
            controller: _c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            hintText: widget.unit == 'F' ? '98.6' : '37.0',
            onChanged: (v) => widget.onChanged(double.tryParse(v.replaceAll(',', '.')), widget.unit),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 120,
          child: PrismSegmentedControl<String>(
            segments: const [PrismSegment(value: 'C', label: '°C'), PrismSegment(value: 'F', label: '°F')],
            selected: widget.unit,
            onChanged: (u) => widget.onChanged(double.tryParse(_c.text.replaceAll(',', '.')), u),
          ),
        ),
      ],
    );
  }
}
