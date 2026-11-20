import 'package:uuid/uuid.dart';

import 'package:prism_plurality/features/health/body_atlas.dart';
import 'package:prism_plurality/features/health/body_map_view.dart';
import 'package:prism_plurality/features/health/health_model.dart';
import 'package:prism_plurality/features/health/health_widgets.dart';
import 'package:prism_plurality/shared/theme/prism_shapes.dart';
import 'package:prism_plurality/shared/widgets/prism_datetime_pills.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/widgets/prism_inline_icon_button.dart';

/// Opens the Body Map editor. The same editor is used from Health › Body
/// Map and while logging a symptom; both write `health.spot` records.
///
/// Returns the ids of the saved spots, or null if cancelled. When [save] is
/// false the spots are returned unsaved through [onDraft] (used by the
/// check-in form, which saves everything together).
Future<List<BodySpot>?> showSensationEditor(
  BuildContext context, {
  required Attribution who,
  List<BodySpot> initial = const [],
  String? checkinId,
  bool save = true,
  String? title,
}) => PrismSheet.showFullScreen<List<BodySpot>>(
  context: context,
  builder: (ctx, scroll) => _SensationEditor(scroll: scroll, who: who, initial: initial, checkinId: checkinId, save: save, title: title),
);

class _SensationEditor extends ConsumerStatefulWidget {
  const _SensationEditor({required this.scroll, required this.who, required this.initial, this.checkinId, required this.save, this.title});
  final ScrollController scroll;
  final Attribution who;
  final List<BodySpot> initial;
  final String? checkinId;
  final bool save;
  final String? title;

  @override
  ConsumerState<_SensationEditor> createState() => _SensationEditorState();
}

class _SensationEditorState extends ConsumerState<_SensationEditor> {
  late final List<BodySpot> _spots = [...widget.initial];
  final Map<String, String> _clientIds = {};
  final _panel = GlobalKey<BodyMapPanelState>();
  String? _focused;
  String? _spreadFor;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _focused = _spots.firstOrNull?.id;
  }

  void _onPick(BodyPick p) {
    setState(() {
      if (_spreadFor != null) {
        final i = _spots.indexWhere((s) => s.id == _spreadFor);
        if (i >= 0) {
          _spots[i] = _spots[i].copyWith(spreads: [..._spots[i].spreads, SpreadPoint(regionId: p.regionId, side: p.side, view: p.view, x: p.x, y: p.y)]);
        }
        return;
      }
      final spot = BodySpot(id: 'new:${const Uuid().v4()}', regionId: p.regionId, side: p.side, view: p.view, x: p.x, y: p.y, at: DateTime.now(), checkinId: widget.checkinId);
      _spots.add(spot);
      _focused = spot.id;
    });
  }

  Future<void> _addSpecial(String regionId) async {
    var label = '';
    if (regionId == customLocation) {
      final es = healthEs(context);
      label = await askHealthText(context, title: es ? 'Ubicación personalizada' : 'Custom location', hint: es ? 'Descríbela con tus palabras' : 'Describe it in your own words') ?? '';
      if (label.trim().isEmpty) return;
    }
    setState(() {
      final spot = BodySpot(id: 'new:${const Uuid().v4()}', regionId: regionId, customLabel: label.trim().isEmpty ? null : label.trim(), at: DateTime.now(), checkinId: widget.checkinId);
      _spots.add(spot);
      _focused = spot.id;
    });
  }

  void _update(String id, BodySpot Function(BodySpot) f) => setState(() {
    final i = _spots.indexWhere((s) => s.id == id);
    if (i >= 0) _spots[i] = f(_spots[i]);
  });

  Future<void> _changePlace(BodySpot s) async {
    final p = await showRegionList(context);
    if (p == null) return;
    _update(s.id, (x) => x.copyWith(regionId: p.regionId, side: p.side, view: p.view, x: null, y: null, descriptors: x.descriptors));
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (!widget.save) {
        Navigator.of(context).pop(_spots);
        return;
      }
      final store = ref.read(healthStoreProvider);
      final saved = <BodySpot>[];
      for (final s in _spots) {
        final clientId = _clientIds.putIfAbsent(s.id, () => s.record?.str('clientId') ?? const Uuid().v4());
        final rec = await store.saveSpot(clientId: clientId, existing: s.record, who: s.isLegacy ? legacyAttribution(s.legacyMood!) : widget.who, spot: s, legacyRef: s.isLegacy ? s.id : null);
        saved.add(BodySpot.fromRecord(rec));
      }
      for (final s in widget.initial) {
        if (s.record != null && !_spots.any((x) => x.id == s.id)) await store.delete(s.record!);
      }
      if (mounted) Navigator.of(context).pop(saved);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final es = healthEs(context);
    final markers = MapMarker.fromSpots(_spots);
    return SafeArea(
      child: Column(
        children: [
          HealthSheetBar(
            title: widget.title ?? (es ? 'Mapa corporal' : 'Body Map'),
            canSave: _spots.isNotEmpty && !_saving,
            onSave: _save,
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: ListView(
                  controller: widget.scroll,
                  padding: EdgeInsets.fromLTRB(16, 4, 16, MediaQuery.viewInsetsOf(context).bottom + 32),
                  children: [
                    if (_spreadFor != null)
                      _SpreadBanner(onDone: () => setState(() => _spreadFor = null))
                    else
                      Text(
                        es ? 'Toca donde lo sientes. Puedes marcar varios puntos; cada uno tiene sus propios detalles.' : 'Tap where you feel it. Mark as many spots as you need — each keeps its own details.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    const SizedBox(height: 12),
                    PrismSurface(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                      child: BodyMapPanel(
                        key: _panel,
                        markers: markers,
                        focusedId: _focused,
                        maxHeight: 440,
                        onPick: (p) {
                          if (const {whole, hardToLocate, customLocation}.contains(p.regionId)) {
                            _addSpecial(p.regionId);
                          } else {
                            _onPick(p);
                          }
                        },
                        onMarkerTap: (id) => setState(() => _focused = id),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final id in const [whole, hardToLocate, customLocation])
                          PrismChip(label: regionById[id]!.label(es), selected: false, avatar: Icon(PhosphorIcons.plus(), size: 14), onTap: () => _addSpecial(id)),
                      ],
                    ),
                    if (_spots.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Text(es ? 'Aún no hay puntos marcados.' : 'No spots marked yet.', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ),
                    for (final (i, s) in _spots.indexed)
                      _SpotCard(
                        key: ValueKey(s.id),
                        number: i + 1,
                        spot: s,
                        focused: s.id == _focused,
                        spreading: s.id == _spreadFor,
                        onFocus: () {
                          setState(() => _focused = s.id);
                          if (s.hasPoint) _panel.currentState?.show(s.view, s.side);
                        },
                        onChanged: (n) => _update(s.id, (_) => n),
                        onChangePlace: () => _changePlace(s),
                        onSpread: () => setState(() {
                          _spreadFor = s.id;
                          _focused = s.id;
                        }),
                        onRemove: () => setState(() {
                          _spots.removeWhere((x) => x.id == s.id);
                          if (_focused == s.id) _focused = _spots.lastOrNull?.id;
                          if (_spreadFor == s.id) _spreadFor = null;
                        }),
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

class _SpreadBanner extends StatelessWidget {
  const _SpreadBanner({required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final es = healthEs(context);
    return PrismSurface(
      accentColor: theme.colorScheme.primary,
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(
        children: [
          Icon(PhosphorIcons.arrowsOutSimple(), color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(es ? 'Toca por dónde se extiende, en orden. Marca el último como “se detiene aquí”.' : 'Tap where it spreads, in order. Mark the last one as “stops here”.', style: theme.textTheme.bodyMedium)),
          PrismButton(label: es ? 'Listo' : 'Done', density: PrismControlDensity.compact, tone: PrismButtonTone.filled, onPressed: onDone),
        ],
      ),
    );
  }
}

class _SpotCard extends StatelessWidget {
  const _SpotCard({
    super.key,
    required this.number,
    required this.spot,
    required this.focused,
    required this.spreading,
    required this.onFocus,
    required this.onChanged,
    required this.onChangePlace,
    required this.onSpread,
    required this.onRemove,
  });

  final int number;
  final BodySpot spot;
  final bool focused;
  final bool spreading;
  final VoidCallback onFocus;
  final ValueChanged<BodySpot> onChanged;
  final VoidCallback onChangePlace;
  final VoidCallback onSpread;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final es = healthEs(context);
    final drawable = regionById[spot.regionId]?.anchor != null;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: PrismSurface(
        accentColor: focused ? theme.colorScheme.primary : null,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              label: es ? 'Punto $number, ${spot.placeLabel(es)}' : 'Spot $number, ${spot.placeLabel(es)}',
              child: InkWell(
                borderRadius: BorderRadius.circular(PrismShapes.of(context).radius(10)),
                onTap: onFocus,
                child: Row(
                  children: [
                    _NumberBadge(number: number, active: focused),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(spot.placeLabel(es), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                          Text(
                            spot.hasPoint ? (es ? 'Punto exacto' : 'Exact point') : (drawable ? (es ? 'Toda la zona' : 'Whole area') : (es ? 'Sin punto en el dibujo' : 'No point on the drawing')),
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    PrismPopupMenu<String>(
                      tooltip: es ? 'Más opciones' : 'More options',
                      icon: PhosphorIcons.dotsThreeVertical(),
                      onSelected: (v) => switch (v) {
                        'place' => onChangePlace(),
                        'whole' => onChanged(spot.copyWith(x: null, y: null)),
                        _ => onRemove(),
                      },
                      items: [
                        PrismMenuItem(value: 'place', label: es ? 'Cambiar zona' : 'Change area', icon: PhosphorIcons.mapPin()),
                        if (spot.hasPoint) PrismMenuItem(value: 'whole', label: es ? 'Marcar toda la zona' : 'Use the whole area', icon: PhosphorIcons.selectionAll()),
                        PrismMenuItem(value: 'remove', label: es ? 'Quitar punto' : 'Remove spot', icon: PhosphorIcons.trash(), destructive: true),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (spot.isLegacy)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  es ? 'De un registro de Ánimo (“${spot.legacyText}”). Al guardar se convierte en una entrada de Salud; el registro de Ánimo no cambia.' : 'From a Mood check-in (“${spot.legacyText}”). Saving turns it into a Health entry; the Mood check-in isn’t changed.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            if (focused) ...[
              HealthFormLabel(es ? 'Cómo se siente' : 'What it feels like'),
              DescriptorPicker(regionId: spot.regionId, selected: spot.descriptors, onChanged: (d) => onChanged(spot.copyWith(descriptors: d))),
              HealthFormLabel(es ? 'Intensidad' : 'Intensity', optional: true),
              IntensityRating(value: spot.intensity, onChanged: (v) => onChanged(spot.copyWith(intensity: v))),
              HealthFormLabel(es ? 'Cuándo' : 'When'),
              PrismDateTimeField(value: spot.at ?? DateTime.now(), onChanged: (d) => onChanged(spot.copyWith(at: d))),
              HealthFormLabel(es ? 'Se extiende a' : 'Spreads to', optional: true),
              if (spot.spreads.isEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: PrismButton(label: spreading ? (es ? 'Toca el mapa…' : 'Tap the map…') : (es ? 'Marcar hacia dónde se extiende' : 'Mark where it spreads'), icon: PhosphorIcons.arrowsOutSimple(), density: PrismControlDensity.compact, onPressed: onSpread),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, p) in spot.spreads.indexed)
                      Row(
                        children: [
                          Icon(PhosphorIcons.arrowDownRight(), size: 16, color: theme.colorScheme.primary),
                          const SizedBox(width: 6),
                          Expanded(child: Text(p.label(es), style: theme.textTheme.bodyMedium)),
                          PrismChip(
                            label: es ? 'Se detiene aquí' : 'Stops here',
                            selected: p.stops,
                            onTap: () => onChanged(spot.copyWith(spreads: [
                              for (final (j, q) in spot.spreads.indexed) SpreadPoint(regionId: q.regionId, side: q.side, view: q.view, x: q.x, y: q.y, stops: j == i ? !q.stops : false),
                            ])),
                          ),
                          PrismInlineIconButton(icon: PhosphorIcons.x(), onPressed: () => onChanged(spot.copyWith(spreads: [...spot.spreads]..removeAt(i))), tooltip: es ? 'Quitar' : 'Remove'),
                        ],
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: PrismButton(label: es ? 'Añadir otro punto' : 'Add another point', icon: PhosphorIcons.plus(), density: PrismControlDensity.compact, onPressed: onSpread),
                    ),
                  ],
                ),
              HealthFormLabel(es ? 'Notas' : 'Notes', optional: true),
              PrismTextField(
                initialValue: spot.notes,
                minLines: 2,
                maxLines: 5,
                hintText: es ? 'Lo que notes, con tus palabras' : 'Anything you notice, in your own words',
                onChanged: (v) => onChanged(spot.copyWith(notes: v)),
              ),
            ] else if (spot.descriptors.isNotEmpty || spot.intensity != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 38),
                child: Text(
                  [...spot.descriptors.map((d) => d.label), if (spot.intensity != null) '${spot.intensity}/10'].join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.number, required this.active});
  final int number;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? theme.colorScheme.primary : theme.colorScheme.primary.withValues(alpha: 0.14),
      ),
      child: Text('$number', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800, color: active ? theme.colorScheme.onPrimary : theme.colorScheme.primary)),
    );
  }
}

/// A single date + time field.
class PrismDateTimeField extends StatelessWidget {
  const PrismDateTimeField({super.key, required this.value, required this.onChanged});
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) => PrismDateTimePills(label: healthEs(context) ? 'Fecha y hora' : 'Date and time', dateTime: value, lastDate: DateTime.now().add(const Duration(days: 1)), onChanged: onChanged);
}
