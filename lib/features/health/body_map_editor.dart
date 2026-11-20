import 'package:uuid/uuid.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'body_regions.dart';
import 'health_data.dart';
import 'health_surface.dart';
import 'body_sheet.dart';

/// Shared editor for Health → Body Map and locations inside symptom logging.
Future<List<Map<String, dynamic>>?> showHealthBodyMap(
  BuildContext context,
  List<Map<String, dynamic>> spots,
) => PrismSheet.showFullScreen<List<Map<String, dynamic>>>(
  context: context,
  builder: (ctx, scroll) => HealthAccessGuard(
    child: HealthBodyMapEditor(initial: spots, scroll: scroll),
  ),
);

class HealthBodyMapEditor extends ConsumerStatefulWidget {
  const HealthBodyMapEditor({super.key, required this.initial, this.scroll});
  final List<Map<String, dynamic>> initial;
  final ScrollController? scroll;
  @override
  ConsumerState<HealthBodyMapEditor> createState() => _BodyMapState();
}

class _BodyMapState extends ConsumerState<HealthBodyMapEditor> {
  late final List<Map<String, dynamic>> _spots = [
    for (final s in widget.initial) Map.of(s),
  ];
  String _view = 'front', _query = '', _detail = 'Full body';
  String _regionView = 'all';
  double _sheetWidth = 360;
  String? _focus;
  final _transform = TransformationController();
  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  Future<void> _edit(
    AnatomicalRegion? region, {
    Map<String, dynamic>? existing,
    Offset? point,
  }) async {
    final base =
        existing ??
        {
          'id': const Uuid().v4(),
          'region': region!.id,
          'label': region.label,
          'side': region.side,
          'view': region.view,
          if (point != null) ...{
            'x': point.dx.clamp(0, 1),
            'y': point.dy.clamp(0, 1),
          },
        };
    final result = await PrismSheet.showFullScreen<Map<String, dynamic>>(
      context: context,
      builder: (ctx, scroll) => HealthAccessGuard(
        child: _SpotDetails(
          initial: base,
          region: region,
          others: _spots,
          scroll: scroll,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        final i = _spots.indexWhere((s) => s['id'] == result['id']);
        if (i < 0) {
          _spots.add(result);
        } else {
          _spots[i] = result;
        }
        _focus = result['id'] as String;
      });
    }
  }

  Future<void> _tap(Offset p) async {
    final candidates = anatomicalRegions.where((r) => r.view == _view).toList()
      ..sort(
        (a, b) => (Offset(a.x, a.y) - p).distance.compareTo(
          (Offset(b.x, b.y) - p).distance,
        ),
      );
    final chosen = await showDialog<AnatomicalRegion>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Choose the area you mean'),
        children: [
          for (final r in candidates.take(5))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, r),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(r.label),
              ),
            ),
        ],
      ),
    );
    if (chosen != null) await _edit(chosen, point: p);
  }

  void _zoom(String detail) {
    setState(() {
      _detail = detail;
      final (x, y, scale) = switch (detail) {
        'Face' => (.5, .10, 3.5),
        'Left hand' => (_view == 'front' ? .80 : .20, .51, 4.0),
        'Right hand' => (_view == 'front' ? .20 : .80, .51, 4.0),
        'Feet' => (.5, .90, 3.0),
        _ => (.5, .5, 1.0),
      };
      _transform.value = Matrix4.identity()
        ..translateByDouble(
          _sheetWidth * (.5 - x * scale),
          (_sheetWidth / .6) * (.5 - y * scale),
          0,
          1,
        )
        ..scaleByDouble(scale, scale, scale, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final regions = anatomicalRegions.where(
      (r) =>
          (_regionView == 'all' ||
              r.view == _regionView ||
              r.view == 'unspecified') &&
          healthSearchText(
            '${r.label} ${r.view} ${r.group.replaceAll('_', ' ')}',
          ).contains(_query),
    );
    return HealthEditorScaffold(
      backgroundColor: colors.surface,
      bodyPadding: EdgeInsets.zero,
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      topBar: PrismTopBar(
        title: 'Body Sheet',
        centerTitle: false,
        showBackButton: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _spots),
            child: const Text('Use locations'),
          ),
        ],
      ),
      body: ClampedBody(
        child: ListView(
          controller: widget.scroll,
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 32,
          ),
          children: [
            Text(
              'A place for every sensation',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Mark one spot, an entire region, or several locations. Each location keeps its own sensations, intensity, time and notes.',
            ),
            const SizedBox(height: 16),
            PrismSegmentedControl<String>(
              key: const ValueKey('body-sheet-view'),
              segments: const [
                PrismSegment(value: 'front', label: 'Front'),
                PrismSegment(value: 'back', label: 'Back'),
              ],
              selected: _view,
              onChanged: (view) {
                setState(() => _view = view);
                _zoom(_detail);
              },
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 620;
                final sheet = _sheet(colors);
                final locations = _locationList();
                if (!wide) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [sheet, const SizedBox(height: 16), locations],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: sheet),
                    const SizedBox(width: 20),
                    Expanded(child: locations),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Region directory',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              'The same locations are available here without using the drawing. Left and right always mean your body’s own sides.',
            ),
            const SizedBox(height: 12),
            PrismTextField(
              labelText: 'Search regions',
              hintText: 'Try ring finger, shoulder blade, or whole body',
              prefixIcon: const Icon(Icons.search),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
            const SizedBox(height: 12),
            PrismSegmentedControl<String>(
              segments: const [
                PrismSegment(value: 'all', label: 'All'),
                PrismSegment(value: 'front', label: 'Front'),
                PrismSegment(value: 'back', label: 'Back'),
              ],
              selected: _regionView,
              onChanged: (v) => setState(() => _regionView = v),
            ),
            const SizedBox(height: 12),
            if (regions.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No matching region. Choose Custom location to describe it in your own words.',
                ),
              ),
            for (final r in regions)
              ListTile(
                minVerticalPadding: 12,
                title: Text(r.label),
                subtitle: Text(
                  r.view == 'unspecified'
                      ? 'Any view'
                      : '${r.view == 'front' ? 'Front' : 'Back'} · ${r.side}',
                ),
                trailing: const Icon(Icons.add_location_alt_outlined),
                onTap: () => _edit(r),
              ),
            if (_query.isNotEmpty)
              TextButton.icon(
                onPressed: () => _edit(
                  anatomicalRegions.firstWhere((r) => r.id == 'custom'),
                ),
                icon: const Icon(Icons.edit_location_alt_outlined),
                label: const Text('Use a custom location'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sheet(ColorScheme colors) => HealthSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _view == 'front' ? 'Body’s right' : 'Body’s left',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            Text(
              _view == 'front' ? 'Body’s left' : 'Body’s right',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRect(
          child: AspectRatio(
            aspectRatio: .6,
            child: LayoutBuilder(
              builder: (context, box) {
                if (_sheetWidth != box.maxWidth) {
                  final ratio = box.maxWidth / _sheetWidth;
                  _sheetWidth = box.maxWidth;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    final resized = Matrix4.copy(_transform.value);
                    resized.setEntry(0, 3, resized.entry(0, 3) * ratio);
                    resized.setEntry(1, 3, resized.entry(1, 3) * ratio);
                    _transform.value = resized;
                  });
                }
                // Fixed child coordinates make detail presets independent of layout.
                return InteractiveViewer(
                  transformationController: _transform,
                  constrained: true,
                  minScale: .7,
                  maxScale: 6,
                  boundaryMargin: const EdgeInsets.all(600),
                  child: SizedBox(
                    width: box.maxWidth,
                    height: box.maxHeight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (d) => _tap(
                        Offset(
                          d.localPosition.dx / box.maxWidth,
                          d.localPosition.dy / box.maxHeight,
                        ),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Semantics(
                            label:
                                '${_view == 'front' ? 'Front' : 'Back'} body outline. Use the region directory below as a keyboard accessible alternative.',
                            image: true,
                            child: HealthBodySheet(view: _view),
                          ),
                          for (final spot in _spots)
                            if (spot['view'] == _view && spot['x'] == null)
                              if (_region(spot) case final region?)
                                Positioned(
                                  left:
                                      (region.x -
                                          _regionExtent(region).width / 2) *
                                      box.maxWidth,
                                  top:
                                      (region.y -
                                          _regionExtent(region).height / 2) *
                                      box.maxHeight,
                                  width:
                                      _regionExtent(region).width *
                                      box.maxWidth,
                                  height:
                                      _regionExtent(region).height *
                                      box.maxHeight,
                                  child: IgnorePointer(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: colors.primary.withValues(
                                          alpha: .16,
                                        ),
                                        border: Border.all(
                                          color: colors.primary.withValues(
                                            alpha: .65,
                                          ),
                                        ),
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                    ),
                                  ),
                                ),
                          for (final (index, spot) in _spots.indexed)
                            if (spot['view'] == _view)
                              if (_region(spot) case final region?)
                                Positioned(
                                  left:
                                      ((spot['x'] as num?)?.toDouble() ??
                                              region.x) *
                                          box.maxWidth -
                                      22,
                                  top:
                                      ((spot['y'] as num?)?.toDouble() ??
                                              region.y) *
                                          box.maxHeight -
                                      22,
                                  child: SizedBox.square(
                                    dimension: 44,
                                    child: IconButton(
                                      tooltip:
                                          '${index + 1}. ${spot['label']}: ${(spot['descriptors'] as List? ?? []).join(', ')}',
                                      style: IconButton.styleFrom(
                                        backgroundColor: _focus == spot['id']
                                            ? colors.primary
                                            : colors.primaryContainer,
                                        foregroundColor: _focus == spot['id']
                                            ? colors.onPrimary
                                            : colors.onPrimaryContainer,
                                        side: BorderSide(
                                          color: colors.primary,
                                          width: 1.5,
                                        ),
                                      ),
                                      onPressed: () {
                                        setState(
                                          () => _focus = spot['id'] as String,
                                        );
                                        _edit(region, existing: spot);
                                      },
                                      icon: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final detail in [
              'Full body',
              'Face',
              'Left hand',
              'Right hand',
              'Feet',
            ])
              PrismChip(
                label: detail,
                selected: _detail == detail,
                onTap: () => _zoom(detail),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Tap to choose an area. Pinch to zoom and drag to move. Markers stay with their original view.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );

  Widget _locationList() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Selected locations${_spots.isEmpty ? '' : ' · ${_spots.length}'}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      if (_spots.isEmpty)
        const HealthSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.touch_app_outlined),
              SizedBox(height: 12),
              Text('Start wherever you notice something'),
              SizedBox(height: 6),
              Text(
                'Choose a point on the sheet or a region below. You can also record Whole body, Hard to locate, or a custom location.',
              ),
            ],
          ),
        ),
      for (final (index, spot) in _spots.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: HealthSurface(
            padding: EdgeInsets.zero,
            child: ListTile(
              selected: spot['id'] == _focus,
              leading: CircleAvatar(child: Text('${index + 1}')),
              title: Text(
                '${spot['label'] ?? 'Location unspecified'} · ${spot['view']}',
              ),
              subtitle: Text(
                [
                  if ((spot['descriptors'] as List? ?? []).isNotEmpty)
                    (spot['descriptors'] as List).join(', '),
                  spot['x'] != null ? 'Precise point' : 'Entire region',
                  if (spot['intensity'] != null)
                    'Intensity ${spot['intensity']}',
                  if (spot['time'] != null && spot['time'] != 'Unsure')
                    '${spot['time']}',
                  if (spot['notes'] != null && '${spot['notes']}'.isNotEmpty)
                    '${spot['notes']}',
                ].join(' · '),
              ),
              onTap: () {
                setState(() {
                  _focus = spot['id'] as String;
                  if (spot['view'] == 'front' || spot['view'] == 'back') {
                    _view = spot['view'] as String;
                  }
                });
                _zoom('Full body');
                _edit(_region(spot), existing: spot);
              },
              trailing: PrismTopBarAction(
                icon: Icons.close,
                tooltip: 'Remove location',
                onPressed: () => setState(() => _spots.remove(spot)),
              ),
            ),
          ),
        ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final id in ['whole', 'hard_to_locate', 'custom'])
            PrismChip(
              label: anatomicalRegions.firstWhere((r) => r.id == id).label,
              selected: false,
              onTap: () =>
                  _edit(anatomicalRegions.firstWhere((r) => r.id == id)),
            ),
        ],
      ),
    ],
  );

  Size _regionExtent(AnatomicalRegion region) => switch (region.group) {
    'chest' ||
    'upper_back' ||
    'mid_back' ||
    'lower_back' ||
    'upper_abdomen' ||
    'mid_abdomen' ||
    'lower_abdomen' => const Size(.22, .07),
    'thigh' ||
    'upper_arm' ||
    'forearm' ||
    'shin' ||
    'calf' => const Size(.07, .10),
    'scalp' || 'back_of_head' => const Size(.18, .10),
    'shoulder_blade' || 'shoulder' || 'hip' => const Size(.10, .06),
    'hand' || 'sole' || 'top_of_foot' => const Size(.08, .045),
    _ when region.group.contains('finger') || region.group.contains('toe') =>
      const Size(.025, .022),
    _ => const Size(.055, .035),
  };

  AnatomicalRegion? _region(Map<String, dynamic> spot) =>
      anatomicalRegions.where((r) => r.id == spot['region']).firstOrNull;
}

class _SpotDetails extends ConsumerStatefulWidget {
  const _SpotDetails({
    required this.initial,
    required this.region,
    required this.others,
    this.scroll,
  });
  final Map<String, dynamic> initial;
  final AnatomicalRegion? region;
  final List<Map<String, dynamic>> others;
  final ScrollController? scroll;
  @override
  ConsumerState<_SpotDetails> createState() => _SpotDetailsState();
}

class _SpotDetailsState extends ConsumerState<_SpotDetails> {
  late final _notes = TextEditingController(
    text: widget.initial['notes'] as String? ?? '',
  );
  late final _location = TextEditingController(
    text: widget.initial['label'] as String? ?? 'Location unspecified',
  );
  final _custom = TextEditingController();
  late final Set<String> _terms = {
    for (final t in widget.initial['descriptors'] as List? ?? []) '$t',
  };
  late String _intensity = '${widget.initial['intensity'] ?? 'Unsure'}';
  late String? _spreadsTo = widget.initial['spreadsTo'] as String?;
  late String _time = widget.initial['time'] as String? ?? 'Unsure';
  late String _endTime = widget.initial['endTime'] as String? ?? '';
  late String _areaMode =
      widget.initial['areaMode'] as String? ??
      (widget.initial['x'] == null ? 'region' : 'point');
  String _termQuery = '';
  bool _savingTerm = false;
  String? _termError;
  @override
  void dispose() {
    _notes.dispose();
    _custom.dispose();
    _location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vocabulary = (ref.watch(healthRecordsProvider).value ?? []).where(
      (r) =>
          r.kind == healthVocabulary &&
          r.str('region') == widget.region?.group &&
          !r.flag('retired'),
    );
    return HealthEditorScaffold(
      bodyPadding: EdgeInsets.zero,
      backgroundColor: Theme.of(context).colorScheme.surface,
      topBar: PrismTopBar(
        title: widget.initial['label'] as String? ?? 'Location unspecified',
        centerTitle: false,
        showBackButton: true,
        actions: [
          TextButton(
            onPressed: () {
              final result = <String, dynamic>{
                ...widget.initial,
                'label': _location.text.trim(),
                'descriptors': _terms.toList(),
                'notes': _notes.text.trim(),
                'intensity': _intensity,
                'time': _time,
                'endTime': _endTime,
                'areaMode': _areaMode,
                'spreadsTo': _spreadsTo,
              };
              if (_areaMode == 'region') {
                result.remove('x');
                result.remove('y');
              }
              Navigator.pop(context, result);
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
                if (widget.region?.id == 'custom' || widget.region == null)
                  PrismTextField(controller: _location, labelText: 'Location'),
                Text(
                  'Location & sensations',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.region?.side ?? 'unspecified'} · ${widget.region?.view ?? 'unspecified'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (widget.initial['x'] != null) ...[
                  const SizedBox(height: 12),
                  PrismSegmentedControl<String>(
                    segments: const [
                      PrismSegment(value: 'point', label: 'Precise point'),
                      PrismSegment(value: 'region', label: 'Entire region'),
                    ],
                    selected: _areaMode,
                    onChanged: (v) => setState(() => _areaMode = v),
                  ),
                ],
                const SizedBox(height: 16),
                const Text('Descriptors (choose several, or add your own)'),
                const SizedBox(height: 8),
                PrismTextField(
                  labelText: 'Search sensations',
                  hintText: 'Try tingling, warm or pressure',
                  prefixIcon: const Icon(Icons.search),
                  onChanged: (v) =>
                      setState(() => _termQuery = v.trim().toLowerCase()),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final term
                        in {
                          ...descriptorsFor(widget.region?.group ?? ''),
                          ...vocabulary.map((v) => v.title),
                          ..._terms,
                        }.where(
                          (t) =>
                              _terms.contains(t) ||
                              healthSearchText(t).contains(_termQuery),
                        ))
                      PrismChip(
                        label: term,
                        selected: _terms.contains(term),
                        onTap: () => setState(
                          () => !_terms.contains(term)
                              ? _terms.add(term)
                              : _terms.remove(term),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                PrismTextField(
                  controller: _custom,
                  labelText: 'Custom descriptor',
                  helperText: 'Historical entries keep their original wording.',
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () {
                        if (_custom.text.trim().isNotEmpty) {
                          setState(() {
                            _terms.add(_custom.text.trim());
                            _custom.clear();
                          });
                        }
                      },
                      child: const Text('Use term'),
                    ),
                    TextButton(
                      onPressed: _savingTerm
                          ? null
                          : () async {
                              final term = _custom.text.trim();
                              if (term.isEmpty) return;
                              setState(() {
                                _savingTerm = true;
                                _termError = null;
                              });
                              try {
                                final now = DateTime.now();
                                final viewers = ref.read(healthViewersProvider);
                                await ref
                                    .read(healthActionsProvider)
                                    .save(
                                      TrackerRecord(
                                        id: const Uuid().v4(),
                                        kind: healthVocabulary,
                                        title: term,
                                        isPrivate: true,
                                        createdAt: now,
                                        modifiedAt: now,
                                      ).withFields({
                                        'region': widget.region?.group,
                                        'author': viewers.singleOrNull,
                                        'subjectMode': viewers.isEmpty
                                            ? 'system'
                                            : 'alters',
                                        'subjects': viewers.toList(),
                                      }),
                                    );
                                if (mounted) {
                                  setState(() {
                                    _terms.add(term);
                                    _custom.clear();
                                  });
                                }
                              } catch (_) {
                                if (mounted) {
                                  setState(
                                    () => _termError =
                                        'Could not save this term. Your location details are still here. Please retry.',
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setState(() => _savingTerm = false);
                                }
                              }
                            },
                      child: const Text('Save term for this region'),
                    ),
                  ],
                ),
                if (_termError != null)
                  Text(
                    _termError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  'Intensity & timing',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                PrismSelect<String>(
                  value: _intensity,
                  labelText: 'Intensity',
                  items: [
                    for (final v in [
                      'Unsure',
                      ...List.generate(11, (i) => '$i'),
                    ])
                      PrismSelectItem(
                        value: v,
                        label: switch (v) {
                          '0' => '0 · No intensity',
                          '3' => '3 · Mild',
                          '5' => '5 · Moderate',
                          '8' => '8 · Strong',
                          '10' => '10 · Most intense',
                          _ => v,
                        },
                      ),
                  ],
                  onChanged: (v) => setState(() => _intensity = v!),
                ),
                const SizedBox(height: 16),
                PrismTextField(
                  initialValue: _time,
                  labelText: 'When / approximate time',
                  helperText: 'Leave Unsure if you cannot determine it.',
                  onChanged: (v) => _time = v,
                ),
                const SizedBox(height: 16),
                PrismTextField(
                  initialValue: _endTime,
                  labelText: 'Ended / approximate end (optional)',
                  hintText: 'Leave blank if ongoing or unknown',
                  onChanged: (v) => _endTime = v,
                ),
                const SizedBox(height: 24),
                Text(
                  'Spread & observations',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose another marked location as the endpoint. This records your observation without interpreting it.',
                ),
                const SizedBox(height: 12),
                PrismSelect<String>(
                  value: widget.others.any((s) => s['id'] == _spreadsTo)
                      ? _spreadsTo
                      : '',
                  labelText: 'Spreads to (your observation; endpoint)',
                  items: [
                    const PrismSelectItem(
                      value: '',
                      label: 'No spread recorded',
                    ),
                    for (final s in widget.others.where(
                      (s) => s['id'] != widget.initial['id'],
                    ))
                      PrismSelectItem(
                        value: s['id'] as String,
                        label: '${s['label']}',
                      ),
                  ],
                  onChanged: (v) => setState(() => _spreadsTo = v),
                ),
                const SizedBox(height: 16),
                PrismTextField(
                  controller: _notes,
                  maxLines: 3,
                  labelText: 'Location notes',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
