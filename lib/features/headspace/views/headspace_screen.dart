import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/headspace/utils/headspace.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/features/trackers/widgets/member_picker.dart';
import 'package:prism_plurality/features/trackers/widgets/tracker_widgets.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/app_shell.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_dialog.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/shared/widgets/prism_switch_row.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar_action.dart';

List<TrackerRecord> _kind(WidgetRef ref, String k) =>
    ref.watch(trackerKindProvider(k)).value ?? const <TrackerRecord>[];

/// List of headspace maps.
class HeadspaceScreen extends ConsumerWidget {
  const HeadspaceScreen({super.key, this.showBackButton = false});

  final bool showBackButton;

  Future<void> _newMap(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final c = TextEditingController();
    final ok = await PrismDialog.show<bool>(
      context: context,
      title: l10n.hsNewMap,
      builder: (_) => PrismTextField(
        controller: c,
        labelText: l10n.hsMapName,
        autofocus: true,
      ),
      actions: [
        PrismButton(
          label: l10n.cancel,
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
        ),
        PrismButton(
          label: l10n.save,
          tone: PrismButtonTone.filled,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
        ),
      ],
    );
    final name = c.text.trim();
    c.dispose();
    if (ok != true || name.isEmpty) return;
    final map = await ref
        .read(trackerNotifierProvider.notifier)
        .create(kind: TrackerKind.headspaceMap, title: name);
    if (context.mounted) _open(context, map.id);
  }

  void _open(BuildContext context, String id) =>
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(builder: (_) => HeadspaceMapScreen(mapId: id)),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final maps = _kind(ref, TrackerKind.headspaceMap);
    final areas = _kind(ref, TrackerKind.headspaceArea);
    final links = _kind(ref, TrackerKind.headspaceLink);
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: l10n.navHeadspace,
        showBackButton: showBackButton,
        actions: [
          PrismTopBarAction(
            icon: AppIcons.add,
            tooltip: l10n.hsNewMap,
            onPressed: () => _newMap(context, ref),
          ),
        ],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, NavBarInset.of(context) + 24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: PrismTokens.contentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.hsIntro, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  if (maps.isEmpty)
                    PrismButton(
                      label: l10n.hsNewMap,
                      icon: AppIcons.add,
                      tone: PrismButtonTone.filled,
                      onPressed: () => _newMap(context, ref),
                    ),
                  for (final m in maps)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: PrismSurface(
                        onTap: () => _open(context, m.id),
                        child: Row(
                          children: [
                            Icon(
                              AppIcons.navHeadspace,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.title,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  Text(
                                    l10n.hsMapSummary(
                                      areas
                                          .where((a) => a.parentId == m.id)
                                          .length,
                                      links
                                          .where((l) => l.parentId == m.id)
                                          .length,
                                    ),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            if (m.isPrivate)
                              Icon(AppIcons.privateLock, size: 14),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The interactive map: drag areas, tap to edit, connect mode to link.
class HeadspaceMapScreen extends ConsumerStatefulWidget {
  const HeadspaceMapScreen({super.key, required this.mapId});

  final String mapId;

  @override
  ConsumerState<HeadspaceMapScreen> createState() => _HeadspaceMapScreenState();
}

class _HeadspaceMapScreenState extends ConsumerState<HeadspaceMapScreen> {
  final Map<String, Offset> _dragging = {};
  bool _connect = false;
  String? _connectFrom;
  bool _listView = false;
  final _transform = TransformationController();
  bool _fitted = false;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _fit(Size viewport, List<Rect> rects) {
    var bounds = Offset.zero & headspaceCanvas;
    if (rects.isNotEmpty) {
      bounds = rects.reduce((a, b) => a.expandToInclude(b)).inflate(60);
    }
    final scale = math
        .min(viewport.width / bounds.width, viewport.height / bounds.height)
        .clamp(0.2, 1.5)
        .toDouble();
    _transform.value = Matrix4.identity()
      ..translateByDouble(
        (viewport.width - bounds.width * scale) / 2 - bounds.left * scale,
        (viewport.height - bounds.height * scale) / 2 - bounds.top * scale,
        0,
        1,
      )
      ..scaleByDouble(scale, scale, 1, 1);
    _fitted = true;
  }

  TrackerNotifier get _n => ref.read(trackerNotifierProvider.notifier);

  Future<void> _addArea(List<TrackerRecord> areas) async {
    final pos = gridLayout(areas.length + 1).last;
    final a = await _n.create(
      kind: TrackerKind.headspaceArea,
      parentId: widget.mapId,
      title: context.l10n.hsNewAreaName(areas.length + 1),
      fields: {
        HsField.x: pos.dx,
        HsField.y: pos.dy,
        HsField.w: 180,
        HsField.h: 120,
        HsField.color: trackerPalette[areas.length % trackerPalette.length],
        HsField.shape: 'rounded',
      },
    );
    if (mounted) _editArea(a);
  }

  Future<void> _arrange(List<TrackerRecord> areas) async {
    final pos = gridLayout(areas.length);
    for (var i = 0; i < areas.length; i++) {
      await _n.save(
        areas[i].withFields({HsField.x: pos[i].dx, HsField.y: pos[i].dy}),
      );
    }
  }

  void _tapArea(TrackerRecord a, List<TrackerRecord> links) {
    if (!_connect) {
      _editArea(a);
      return;
    }
    if (_connectFrom == null) {
      setState(() => _connectFrom = a.id);
      return;
    }
    if (_connectFrom == a.id) {
      setState(() => _connectFrom = null);
      return;
    }
    final from = _connectFrom!;
    final exists = links.any(
      (l) => {l.str(HsField.from), l.str(HsField.to)}.containsAll({from, a.id}),
    );
    setState(() => _connectFrom = null);
    if (!exists) {
      _n.create(
        kind: TrackerKind.headspaceLink,
        parentId: widget.mapId,
        title: '',
        fields: {HsField.from: from, HsField.to: a.id},
      );
    }
  }

  void _editArea(TrackerRecord a) => PrismSheet.showFullScreen(
    context: context,
    builder: (context, scroll) => _AreaEditor(areaId: a.id, scroll: scroll),
  );

  void _editLink(TrackerRecord l) => PrismSheet.show(
    context: context,
    title: context.l10n.hsEditLink,
    builder: (_) => _LinkEditor(link: l),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final map = _kind(
      ref,
      TrackerKind.headspaceMap,
    ).where((m) => m.id == widget.mapId).firstOrNull;
    if (map == null) {
      return PrismPageScaffold(
        topBar: PrismTopBar(title: l10n.navHeadspace, showBackButton: true),
        body: Center(child: Text(l10n.hsMapGone)),
      );
    }
    final areas = [
      for (final a in _kind(ref, TrackerKind.headspaceArea))
        if (a.parentId == map.id) a,
    ];
    final ids = {for (final a in areas) a.id};
    final links = validLinks([
      for (final l in _kind(ref, TrackerKind.headspaceLink))
        if (l.parentId == map.id) l,
    ], ids);
    final members = {
      for (final m in ref.watch(allMembersProvider).value ?? const <Member>[])
        m.id: m,
    };
    Rect rectOf(TrackerRecord a) {
      final r = areaRect(a);
      final d = _dragging[a.id];
      return d == null ? r : Rect.fromLTWH(d.dx, d.dy, r.width, r.height);
    }

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: map.title,
        showBackButton: true,
        actions: [
          PrismTopBarAction(
            icon: _listView ? AppIcons.navHeadspace : AppIcons.listView,
            tooltip: _listView ? l10n.hsShowMap : l10n.hsShowList,
            onPressed: () => setState(() => _listView = !_listView),
          ),
          PrismTopBarAction(
            icon: AppIcons.add,
            tooltip: l10n.hsAddArea,
            onPressed: () => _addArea(areas),
          ),
        ],
      ),
      bodyPadding: EdgeInsets.zero,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                PrismChip(
                  label: _connect
                      ? (_connectFrom == null
                            ? l10n.hsConnectPickFirst
                            : l10n.hsConnectPickSecond)
                      : l10n.hsConnect,
                  selected: _connect,
                  onTap: () => setState(() {
                    _connect = !_connect;
                    _connectFrom = null;
                  }),
                ),
                PrismButton(
                  label: l10n.hsFit,
                  density: PrismControlDensity.compact,
                  onPressed: () => setState(() => _fitted = false),
                ),
                PrismButton(
                  label: l10n.hsArrange,
                  density: PrismControlDensity.compact,
                  onPressed: areas.isEmpty ? () {} : () => _arrange(areas),
                ),
                PrismButton(
                  label: l10n.hsMapSettings,
                  icon: AppIcons.navSettings,
                  density: PrismControlDensity.compact,
                  onPressed: () => PrismSheet.show(
                    context: context,
                    title: l10n.hsMapSettings,
                    builder: (_) => _MapSettings(map: map),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _listView
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (areas.isEmpty) Text(l10n.hsEmptyMap),
                      for (final a in areas)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: PrismSurface(
                            accentColor: Color(
                              a.integer(HsField.color) ?? trackerPalette.first,
                            ),
                            onTap: () => _editArea(a),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.title,
                                  style: theme.textTheme.titleSmall,
                                ),
                                if (a.body != null)
                                  Text(
                                    a.body!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                Text(
                                  [
                                    l10n.hsConnectedTo(
                                      links
                                          .where(
                                            (l) =>
                                                l.str(HsField.from) == a.id ||
                                                l.str(HsField.to) == a.id,
                                          )
                                          .length,
                                    ),
                                    for (final r in a.strings(
                                      HsField.residents,
                                    ))
                                      ?members[r]?.name,
                                  ].join(' · '),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (links.isNotEmpty) TrackerLabel(l10n.hsLinks),
                      for (final l in links)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: PrismSurface(
                            onTap: () => _editLink(l),
                            child: Text(
                              '${areas.firstWhere((a) => a.id == l.str(HsField.from)).title} ${l.flag(HsField.oneWay) ? '→' : '↔'} ${areas.firstWhere((a) => a.id == l.str(HsField.to)).title}${l.title.isEmpty ? '' : ' · ${l.title}'}',
                            ),
                          ),
                        ),
                    ],
                  )
                : areas.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(l10n.hsEmptyMap, textAlign: TextAlign.center),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, box) {
                      if (!_fitted) {
                        _fit(box.biggest, [for (final a in areas) rectOf(a)]);
                      }
                      return InteractiveViewer(
                        transformationController: _transform,
                        constrained: false,
                        minScale: 0.2,
                        maxScale: 2.5,
                        boundaryMargin: const EdgeInsets.all(200),
                        child: SizedBox(
                          width: headspaceCanvas.width,
                          height: headspaceCanvas.height,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _MapPainter(
                                    rects: {
                                      for (final a in areas) a.id: rectOf(a),
                                    },
                                    links: links,
                                    theme: theme,
                                    background: Color(
                                      map.integer(HsField.background) ??
                                          theme
                                              .colorScheme
                                              .surfaceContainerLowest
                                              .toARGB32(),
                                    ),
                                  ),
                                ),
                              ),
                              for (final l in links)
                                Builder(
                                  builder: (context) {
                                    final a = rectOf(
                                      areas.firstWhere(
                                        (x) => x.id == l.str(HsField.from),
                                      ),
                                    );
                                    final b = rectOf(
                                      areas.firstWhere(
                                        (x) => x.id == l.str(HsField.to),
                                      ),
                                    );
                                    final mid = Offset.lerp(
                                      a.center,
                                      b.center,
                                      0.5,
                                    )!;
                                    return Positioned(
                                      left: mid.dx - 14,
                                      top: mid.dy - 14,
                                      child: Tooltip(
                                        message: l10n.hsEditLink,
                                        child: InkResponse(
                                          radius: 18,
                                          onTap: () => _editLink(l),
                                          child: Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.surface,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color:
                                                    theme.colorScheme.outline,
                                              ),
                                            ),
                                            child: Icon(
                                              AppIcons.edit,
                                              size: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              for (final a in areas)
                                Builder(
                                  builder: (context) {
                                    final r = rectOf(a);
                                    final color = Color(
                                      a.integer(HsField.color) ??
                                          trackerPalette.first,
                                    );
                                    final shape =
                                        a.str(HsField.shape) ?? 'rounded';
                                    final selected = _connectFrom == a.id;
                                    return Positioned(
                                      left: r.left,
                                      top: r.top,
                                      width: r.width,
                                      height: r.height,
                                      child: GestureDetector(
                                        onTap: () => _tapArea(a, links),
                                        onPanUpdate: _connect
                                            ? null
                                            : (d) => setState(() {
                                                final cur =
                                                    _dragging[a.id] ??
                                                    r.topLeft;
                                                _dragging[a.id] = clampPosition(
                                                  cur + d.delta,
                                                  r.size,
                                                );
                                              }),
                                        onPanEnd: _connect
                                            ? null
                                            : (_) async {
                                                final p = _dragging[a.id];
                                                if (p == null) return;
                                                await _n.save(
                                                  a.withFields({
                                                    HsField.x: p.dx,
                                                    HsField.y: p.dy,
                                                  }),
                                                );
                                                if (mounted)
                                                  setState(
                                                    () =>
                                                        _dragging.remove(a.id),
                                                  );
                                              },
                                        child: Semantics(
                                          button: true,
                                          label: a.title,
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: color.withValues(
                                                alpha: 0.22,
                                              ),
                                              border: Border.all(
                                                color: selected
                                                    ? theme.colorScheme.primary
                                                    : color,
                                                width: selected ? 4 : 2,
                                              ),
                                              shape: shape == 'circle'
                                                  ? BoxShape.circle
                                                  : BoxShape.rectangle,
                                              borderRadius: shape == 'circle'
                                                  ? null
                                                  : BorderRadius.circular(
                                                      shape == 'rect' ? 4 : 18,
                                                    ),
                                            ),
                                            alignment: Alignment.center,
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  a.title,
                                                  textAlign: TextAlign.center,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: theme
                                                      .textTheme
                                                      .titleSmall,
                                                ),
                                                if (a
                                                    .strings(HsField.residents)
                                                    .isNotEmpty)
                                                  Text(
                                                    [
                                                      for (final id
                                                          in a.strings(
                                                            HsField.residents,
                                                          ))
                                                        ?members[id]?.name,
                                                    ].join(', '),
                                                    textAlign: TextAlign.center,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: theme
                                                        .textTheme
                                                        .labelSmall,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({
    required this.rects,
    required this.links,
    required this.theme,
    required this.background,
  });

  final Map<String, Rect> rects;
  final List<TrackerRecord> links;
  final ThemeData theme;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final grid = Paint()
      ..color = theme.colorScheme.outlineVariant.withValues(alpha: 0.35);
    for (var x = 0.0; x <= size.width; x += 80) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y <= size.height; y += 80) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final line = Paint()
      ..color = theme.colorScheme.primary.withValues(alpha: 0.7)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    for (final l in links) {
      final a = rects[l.str(HsField.from)], b = rects[l.str(HsField.to)];
      if (a == null || b == null) continue;
      final p1 = edgePoint(a, b.center), p2 = edgePoint(b, a.center);
      canvas.drawLine(p1, p2, line);
      if (l.flag(HsField.oneWay)) {
        final ang = math.atan2(p2.dy - p1.dy, p2.dx - p1.dx);
        final path = Path()
          ..moveTo(p2.dx, p2.dy)
          ..lineTo(
            p2.dx - 14 * math.cos(ang - 0.4),
            p2.dy - 14 * math.sin(ang - 0.4),
          )
          ..lineTo(
            p2.dx - 14 * math.cos(ang + 0.4),
            p2.dy - 14 * math.sin(ang + 0.4),
          )
          ..close();
        canvas.drawPath(path, Paint()..color = line.color);
      }
      if (l.title.isNotEmpty) {
        final tp = TextPainter(
          text: TextSpan(
            text: l.title,
            style: theme.textTheme.labelSmall?.copyWith(
              backgroundColor: background,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 160);
        final mid = Offset.lerp(p1, p2, 0.5)!;
        tp.paint(canvas, mid + const Offset(16, -8));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) => true;
}

class _AreaEditor extends ConsumerStatefulWidget {
  const _AreaEditor({required this.areaId, this.scroll});

  final String areaId;
  final ScrollController? scroll;

  @override
  ConsumerState<_AreaEditor> createState() => _AreaEditorState();
}

class _AreaEditorState extends ConsumerState<_AreaEditor> {
  late final TrackerRecord? _a =
      (ref.read(trackerKindProvider(TrackerKind.headspaceArea)).value ??
              const <TrackerRecord>[])
          .where((x) => x.id == widget.areaId)
          .firstOrNull;
  late final _name = TextEditingController(text: _a?.title ?? '');
  late final _desc = TextEditingController(text: _a?.body ?? '');
  late int _color = _a?.integer(HsField.color) ?? trackerPalette.first;
  late String _shape = _a?.str(HsField.shape) ?? 'rounded';
  late double _w = (_a?.number(HsField.w) ?? 180).toDouble();
  late double _h = (_a?.number(HsField.h) ?? 120).toDouble();
  late final Set<String> _residents = {...?_a?.strings(HsField.residents)};
  late bool _private = _a?.isPrivate ?? false;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final a = _a;
    if (a == null) return SafeArea(child: Center(child: Text(l10n.hsMapGone)));
    final members = ref.watch(activeMembersProvider).value ?? const <Member>[];
    final n = ref.read(trackerNotifierProvider.notifier);
    return ListenableBuilder(
      listenable: _name,
      builder: (context, _) => TrackerEditorScaffold(
        title: l10n.hsEditArea,
        canSave: _name.text.trim().isNotEmpty,
        onSave: () async {
          await n.save(
            a
                .copyWith(
                  title: _name.text.trim(),
                  body: _desc.text,
                  isPrivate: _private,
                )
                .withFields({
                  HsField.color: _color,
                  HsField.shape: _shape,
                  HsField.w: _w,
                  HsField.h: _shape == 'circle' ? _w : _h,
                  HsField.residents: _residents.isEmpty
                      ? null
                      : _residents.toList(),
                }),
          );
          if (context.mounted) Navigator.of(context).pop();
        },
        scrollController: widget.scroll,
        children: [
          PrismTextField(controller: _name, labelText: l10n.hsAreaName),
          const SizedBox(height: 12),
          PrismTextField(
            controller: _desc,
            labelText: l10n.hsAreaDescription,
            helperText: l10n.hsAreaDescriptionHelp,
            maxLines: 8,
            minLines: 3,
          ),
          TrackerLabel(l10n.finColor),
          Wrap(
            spacing: 8,
            children: [
              for (final c in trackerPalette)
                InkResponse(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(width: _color == c ? 3 : 0),
                    ),
                  ),
                ),
            ],
          ),
          TrackerLabel(l10n.hsShape),
          Wrap(
            spacing: 6,
            children: [
              for (final s in headspaceShapes)
                PrismChip(
                  label: switch (s) {
                    'rect' => l10n.hsShapeRect,
                    'circle' => l10n.hsShapeCircle,
                    _ => l10n.hsShapeRounded,
                  },
                  selected: _shape == s,
                  onTap: () => setState(() => _shape = s),
                ),
            ],
          ),
          TrackerLabel(l10n.hsSize),
          Wrap(
            spacing: 6,
            children: [
              for (final (label, w, h) in [
                (l10n.hsSmall, 140.0, 100.0),
                (l10n.hsMedium, 200.0, 140.0),
                (l10n.hsLarge, 300.0, 200.0),
                (l10n.hsHuge, 440.0, 300.0),
              ])
                PrismChip(
                  label: label,
                  selected: _w == w,
                  onTap: () => setState(() {
                    _w = w;
                    _h = h;
                  }),
                ),
            ],
          ),
          if (members.isNotEmpty) ...[
            TrackerLabel(l10n.hsResidents),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in members)
                  PrismChip(
                    label: memberLabel(m),
                    selected: _residents.contains(m.id),
                    onTap: () => setState(
                      () => _residents.contains(m.id)
                          ? _residents.remove(m.id)
                          : _residents.add(m.id),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          PrismSwitchRow(
            title: l10n.trackerPrivate,
            subtitle: l10n.trackerPrivateHelp,
            icon: AppIcons.privateLock,
            value: _private,
            onChanged: (v) => setState(() => _private = v),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: PrismButton(
              label: l10n.trackerDelete,
              icon: AppIcons.delete,
              tone: PrismButtonTone.destructive,
              onPressed: () async {
                final ok = await PrismDialog.confirm(
                  context: context,
                  title: l10n.hsDeleteArea(a.title),
                  message: l10n.hsDeleteAreaMessage,
                  confirmLabel: l10n.trackerDelete,
                  cancelLabel: l10n.cancel,
                  destructive: true,
                );
                if (!ok) return;
                final links =
                    ref
                        .read(trackerKindProvider(TrackerKind.headspaceLink))
                        .value ??
                    const <TrackerRecord>[];
                for (final l in links.where(
                  (l) =>
                      l.str(HsField.from) == a.id || l.str(HsField.to) == a.id,
                )) {
                  await n.delete(l.id);
                }
                await n.delete(a.id);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkEditor extends ConsumerStatefulWidget {
  const _LinkEditor({required this.link});

  final TrackerRecord link;

  @override
  ConsumerState<_LinkEditor> createState() => _LinkEditorState();
}

class _LinkEditorState extends ConsumerState<_LinkEditor> {
  late final _label = TextEditingController(text: widget.link.title);
  late bool _oneWay = widget.link.flag(HsField.oneWay);

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final n = ref.read(trackerNotifierProvider.notifier);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrismTextField(
          controller: _label,
          labelText: l10n.hsLinkLabel,
          hintText: l10n.hsLinkHint,
        ),
        PrismSwitchRow(
          title: l10n.hsOneWay,
          value: _oneWay,
          onChanged: (v) => setState(() => _oneWay = v),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            PrismButton(
              label: l10n.trackerDelete,
              tone: PrismButtonTone.destructive,
              onPressed: () async {
                await n.delete(widget.link.id);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
            const Spacer(),
            PrismButton(
              label: l10n.save,
              tone: PrismButtonTone.filled,
              onPressed: () async {
                await n.save(
                  widget.link.copyWith(title: _label.text.trim()).withFields({
                    HsField.oneWay: _oneWay ? true : null,
                  }),
                );
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _MapSettings extends ConsumerStatefulWidget {
  const _MapSettings({required this.map});

  final TrackerRecord map;

  @override
  ConsumerState<_MapSettings> createState() => _MapSettingsState();
}

class _MapSettingsState extends ConsumerState<_MapSettings> {
  late final _name = TextEditingController(text: widget.map.title);
  late final _desc = TextEditingController(text: widget.map.body ?? '');
  late bool _private = widget.map.isPrivate;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final n = ref.read(trackerNotifierProvider.notifier);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrismTextField(controller: _name, labelText: l10n.hsMapName),
        const SizedBox(height: 8),
        PrismTextField(
          controller: _desc,
          labelText: l10n.hsAreaDescription,
          maxLines: 3,
        ),
        PrismSwitchRow(
          title: l10n.trackerPrivate,
          subtitle: l10n.trackerPrivateHelp,
          value: _private,
          onChanged: (v) => setState(() => _private = v),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            PrismButton(
              label: l10n.hsDeleteMap,
              tone: PrismButtonTone.destructive,
              onPressed: () async {
                final ok = await PrismDialog.confirm(
                  context: context,
                  title: l10n.hsDeleteMap,
                  message: l10n.hsDeleteMapMessage,
                  confirmLabel: l10n.trackerDelete,
                  cancelLabel: l10n.cancel,
                  destructive: true,
                );
                if (!ok) return;
                await n.delete(widget.map.id);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  Navigator.of(context, rootNavigator: true).pop();
                }
              },
            ),
            const Spacer(),
            PrismButton(
              label: l10n.save,
              tone: PrismButtonTone.filled,
              onPressed: () async {
                if (_name.text.trim().isEmpty) return;
                await n.save(
                  widget.map.copyWith(
                    title: _name.text.trim(),
                    body: _desc.text,
                    isPrivate: _private,
                  ),
                );
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ],
    );
  }
}
