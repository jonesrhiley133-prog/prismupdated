import 'package:uuid/uuid.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'body_regions.dart';
import 'health_data.dart';

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
  String _view = 'front', _query = '';
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

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Body Map'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _spots),
            child: const Text('Use locations'),
          ),
        ],
      ),
      body: ListView(
        controller: widget.scroll,
        padding: const EdgeInsets.all(16),
        children: [
          ClampedBody(
            maxWidth: 600,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Choose a point or use the region list. Sides refer to your body. Pinch or use zoom to inspect the face, hands and feet.',
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final view in ['front', 'back'])
                      ChoiceChip(
                        label: Text(view == 'front' ? 'Front' : 'Back'),
                        selected: _view == view,
                        onSelected: (_) => setState(() {
                          _view = view;
                          _transform.value = Matrix4.identity();
                        }),
                      ),
                    IconButton(
                      tooltip: 'Zoom in',
                      onPressed: () =>
                          _transform.value = Matrix4.copy(_transform.value)
                            ..scaleByDouble(1.5, 1.5, 1.5, 1),
                      icon: const Icon(Icons.zoom_in),
                    ),
                    IconButton(
                      tooltip: 'Reset zoom',
                      onPressed: () => _transform.value = Matrix4.identity(),
                      icon: const Icon(Icons.zoom_out_map),
                    ),
                  ],
                ),
                SizedBox(
                  height: 600,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: InteractiveViewer(
                        transformationController: _transform,
                        maxScale: 6,
                        child: LayoutBuilder(
                          builder: (ctx, box) => GestureDetector(
                            onTapUp: (d) => _tap(
                              Offset(
                                d.localPosition.dx / box.maxWidth,
                                d.localPosition.dy / box.maxHeight,
                              ),
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CustomPaint(
                                  painter: _AnatomyPainter(
                                    color.outline,
                                    color.surfaceContainerHighest,
                                    _view,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  left: 8,
                                  child: Text(
                                    _view == 'front'
                                        ? 'Body’s right'
                                        : 'Body’s left',
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Text(
                                    _view == 'front'
                                        ? 'Body’s left'
                                        : 'Body’s right',
                                  ),
                                ),
                                for (final s in _spots.where(
                                  (s) => s['view'] == _view,
                                )) ...[
                                  if (_region(s) case final r?)
                                    Positioned(
                                      left:
                                          ((s['x'] as num?)?.toDouble() ??
                                                  r.x) *
                                              box.maxWidth -
                                          24,
                                      top:
                                          ((s['y'] as num?)?.toDouble() ??
                                                  r.y) *
                                              box.maxHeight -
                                          24,
                                      child: IconButton(
                                        tooltip:
                                            '${s['label']}: ${(s['descriptors'] as List? ?? []).join(', ')}',
                                        style: IconButton.styleFrom(
                                          backgroundColor:
                                              color.primaryContainer,
                                          foregroundColor:
                                              color.onPrimaryContainer,
                                        ),
                                        onPressed: () => _edit(r, existing: s),
                                        icon: Icon(
                                          _focus == s['id']
                                              ? Icons.my_location
                                              : Icons.location_on,
                                        ),
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                for (final s in _spots)
                  ListTile(
                    selected: s['id'] == _focus,
                    title: Text(
                      '${s['label'] ?? 'Location unspecified'} · ${s['view']}',
                    ),
                    subtitle: Text(
                      '${(s['descriptors'] as List? ?? []).join(', ')}${s['intensity'] == null ? '' : ' · Intensity ${s['intensity']}'}',
                    ),
                    onTap: () {
                      setState(() {
                        _focus = s['id'] as String;
                        if (s['view'] == 'front' || s['view'] == 'back') {
                          _view = s['view'] as String;
                        }
                        _transform.value = Matrix4.identity();
                      });
                      _edit(_region(s), existing: s);
                    },
                    trailing: IconButton(
                      tooltip: 'Remove location',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _spots.remove(s)),
                    ),
                  ),
                TextField(
                  decoration: const InputDecoration(
                    labelText:
                        'Search regions (keyboard and screen-reader alternative)',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _query = v.toLowerCase()),
                ),
                const SizedBox(height: 8),
                // All choices, including both sides and views, remain available to assistive technology.
                for (final r in anatomicalRegions.where(
                  (r) => '${r.label} ${r.view}'.toLowerCase().contains(_query),
                ))
                  ListTile(
                    title: Text(r.label),
                    subtitle: Text(r.view),
                    trailing: const Icon(Icons.add_location_alt_outlined),
                    onTap: () => _edit(r),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initial['label'] as String? ?? 'Location unspecified',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, {
              ...widget.initial,
              'label': _location.text.trim(),
              'descriptors': _terms.toList(),
              'notes': _notes.text.trim(),
              'intensity': _intensity,
              'time': _time,
              'spreadsTo': _spreadsTo,
            }),
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
                  TextField(
                    controller: _location,
                    decoration: const InputDecoration(labelText: 'Location'),
                  ),
                const Text('Descriptors (choose several, or add your own)'),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final term in {
                      ...descriptorsFor(widget.region?.group ?? ''),
                      ...vocabulary.map((v) => v.title),
                      ..._terms,
                    })
                      FilterChip(
                        label: Text(term),
                        selected: _terms.contains(term),
                        onSelected: (v) => setState(
                          () => v ? _terms.add(term) : _terms.remove(term),
                        ),
                      ),
                  ],
                ),
                TextField(
                  controller: _custom,
                  decoration: const InputDecoration(
                    labelText: 'Custom descriptor',
                    helperText:
                        'Historical entries keep their original wording.',
                  ),
                ),
                Wrap(
                  spacing: 8,
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
                      onPressed: () async {
                        final term = _custom.text.trim();
                        if (term.isEmpty) return;
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
                      },
                      child: const Text('Save term for this region'),
                    ),
                  ],
                ),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _intensity,
                  decoration: const InputDecoration(labelText: 'Intensity'),
                  items: [
                    for (final v in [
                      'Unsure',
                      ...List.generate(11, (i) => '$i'),
                    ])
                      DropdownMenuItem(value: v, child: Text(v)),
                  ],
                  onChanged: (v) => setState(() => _intensity = v!),
                ),
                TextFormField(
                  initialValue: _time,
                  decoration: const InputDecoration(
                    labelText: 'When / approximate time',
                    helperText: 'Leave Unsure if you cannot determine it.',
                  ),
                  onChanged: (v) => _time = v,
                ),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _spreadsTo,
                  decoration: const InputDecoration(
                    labelText: 'Spreads to (your observation; endpoint)',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('No spread recorded'),
                    ),
                    for (final s in widget.others.where(
                      (s) => s['id'] != widget.initial['id'],
                    ))
                      DropdownMenuItem(
                        value: s['id'] as String,
                        child: Text('${s['label']}'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _spreadsTo = v),
                ),
                TextField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Location notes',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnatomyPainter extends CustomPainter {
  _AnatomyPainter(this.outline, this.fill, this.view);
  final Color outline, fill;
  final String view;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width, size.height);
    final line = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = .004;
    final shade = Paint()..color = fill;
    void path(Path p) {
      canvas.drawPath(p, shade);
      canvas.drawPath(p, line);
    }

    final head = Path()..addOval(const Rect.fromLTWH(.40, .025, .20, .125));
    path(head);
    path(
      Path()
        ..moveTo(.46, .15)
        ..lineTo(.46, .185)
        ..lineTo(.34, .21)
        ..lineTo(.29, .34)
        ..lineTo(.245, .455)
        ..lineTo(.20, .49)
        ..lineTo(.17, .55)
        ..lineTo(.19, .56)
        ..lineTo(.23, .52)
        ..lineTo(.22, .565)
        ..lineTo(.25, .565)
        ..lineTo(.28, .50)
        ..lineTo(.31, .48)
        ..lineTo(.37, .32)
        ..lineTo(.38, .40)
        ..lineTo(.35, .49)
        ..lineTo(.37, .67)
        ..lineTo(.38, .88)
        ..lineTo(.35, .96)
        ..quadraticBezierTo(.39, 1, .46, .96)
        ..lineTo(.46, .88)
        ..lineTo(.47, .68)
        ..lineTo(.50, .53)
        ..lineTo(.53, .68)
        ..lineTo(.54, .88)
        ..lineTo(.54, .96)
        ..quadraticBezierTo(.61, 1, .65, .96)
        ..lineTo(.62, .88)
        ..lineTo(.63, .67)
        ..lineTo(.65, .49)
        ..lineTo(.62, .40)
        ..lineTo(.63, .32)
        ..lineTo(.69, .48)
        ..lineTo(.72, .50)
        ..lineTo(.75, .565)
        ..lineTo(.78, .565)
        ..lineTo(.77, .52)
        ..lineTo(.81, .56)
        ..lineTo(.83, .55)
        ..lineTo(.80, .49)
        ..lineTo(.755, .455)
        ..lineTo(.71, .34)
        ..lineTo(.66, .21)
        ..lineTo(.54, .185)
        ..lineTo(.54, .15)
        ..close(),
    );
    if (view == 'back') {
      canvas.drawLine(const Offset(.5, .20), const Offset(.5, .46), line);
    } else {
      canvas.drawLine(const Offset(.46, .09), const Offset(.48, .09), line);
      canvas.drawLine(const Offset(.52, .09), const Offset(.54, .09), line);
      canvas.drawLine(const Offset(.47, .12), const Offset(.53, .12), line);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AnatomyPainter old) =>
      outline != old.outline || fill != old.fill || view != old.view;
}
