import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:prism_plurality/features/scrapbook/scrap_models.dart';

enum ScrapAlign { left, hCenter, right, top, vCenter, bottom }

/// What a drag snapped to: the shift to apply (pixels) and the guide lines
/// to show (page-space x for vertical lines, y for horizontal lines).
class SnapResult {
  const SnapResult(this.dx, this.dy, this.vLines, this.hLines);
  final double dx, dy;
  final List<double> vLines, hLines;
  static const none = SnapResult(0, 0, [], []);
}

/// Alignment guides: snaps the edges and centre of [moving] to the page and
/// to the other elements, when within [threshold] pixels.
SnapResult snapMove(
  Rect moving,
  List<Rect> others,
  Size page, {
  double threshold = 6,
}) {
  final xs = <double>[0, page.width / 2, page.width];
  final ys = <double>[0, page.height / 2, page.height];
  for (final o in others) {
    xs.addAll([o.left, o.center.dx, o.right]);
    ys.addAll([o.top, o.center.dy, o.bottom]);
  }
  double? bestDx, bestDy;
  double? lineX, lineY;
  for (final m in [moving.left, moving.center.dx, moving.right]) {
    for (final x in xs) {
      final d = x - m;
      if (d.abs() <= threshold && (bestDx == null || d.abs() < bestDx.abs())) {
        bestDx = d;
        lineX = x;
      }
    }
  }
  for (final m in [moving.top, moving.center.dy, moving.bottom]) {
    for (final y in ys) {
      final d = y - m;
      if (d.abs() <= threshold && (bestDy == null || d.abs() < bestDy.abs())) {
        bestDy = d;
        lineY = y;
      }
    }
  }
  if (bestDx == null && bestDy == null) return SnapResult.none;
  return SnapResult(
    bestDx ?? 0,
    bestDy ?? 0,
    [if (lineX != null) lineX],
    [if (lineY != null) lineY],
  );
}

/// Everything about editing a set of scrapbook elements, independent of any
/// screen: selection, undo/redo, grouping, locking, layers, alignment,
/// copy/paste. A cover and a page both use this.
class ScrapEditorController extends ChangeNotifier {
  ScrapEditorController({
    required List<ScrapElement> elements,
    Map<String, Object?>? meta,
  }) : els = [...elements],
       meta = Map<String, Object?>.of(meta ?? const {}) {
    _history.add(_snapshot());
    _cursor = 0;
  }

  final List<ScrapElement> els;

  /// Page-level settings (background, texture, size…) saved with undo history.
  final Map<String, Object?> meta;
  final Set<String> selected = {};

  bool snapEnabled = true;
  double zoom = 1;

  /// Kept across pages, so you can copy on one page and paste on another.
  static List<Map<String, Object?>> clipboard = [];

  static const maxHistory = 100;
  final List<String> _history = [];
  int _cursor = 0;
  bool _dirty = false;

  /// True when something has changed since the last [markSaved].
  bool get changed => _dirty;
  void markSaved() => _dirty = false;

  bool get canUndo => _cursor > 0;
  bool get canRedo => _cursor < _history.length - 1;

  String _snapshot() => jsonEncode({
    'e': [for (final e in els) e.toJson()],
    'm': meta,
  });

  /// Records the current state as an undo step (no-op if nothing changed).
  void commit() {
    final s = _snapshot();
    if (s == _history[_cursor]) {
      notifyListeners();
      return;
    }
    _history.removeRange(_cursor + 1, _history.length);
    _history.add(s);
    if (_history.length > maxHistory) _history.removeAt(0);
    _cursor = _history.length - 1;
    _dirty = true;
    notifyListeners();
  }

  void _restore(String s) {
    final j = jsonDecode(s) as Map;
    els
      ..clear()
      ..addAll([for (final o in j['e'] as List) ?ScrapElement.fromJson(o)]);
    meta
      ..clear()
      ..addAll(Map<String, Object?>.from(j['m'] as Map));
    selected.removeWhere((id) => !els.any((e) => e.id == id));
    _dirty = true;
    notifyListeners();
  }

  void undo() {
    if (!canUndo) return;
    _restore(_history[--_cursor]);
  }

  void redo() {
    if (!canRedo) return;
    _restore(_history[++_cursor]);
  }

  ScrapElement? byId(String id) {
    for (final e in els) {
      if (e.id == id) return e;
    }
    return null;
  }

  List<ScrapElement> get selection => [
    for (final e in els)
      if (selected.contains(e.id)) e,
  ];
  ScrapElement? get single =>
      selected.length == 1 ? byId(selected.first) : null;

  // ── Selection ──────────────────────────────────────────────────────────
  Set<String> _expandGroups(Iterable<String> ids) {
    final out = <String>{...ids};
    for (final id in ids) {
      final g = byId(id)?.group;
      if (g != null)
        out.addAll(els.where((e) => e.group == g).map((e) => e.id));
    }
    return out;
  }

  void select(String? id, {bool additive = false}) {
    if (id == null) {
      if (selected.isNotEmpty) {
        selected.clear();
        notifyListeners();
      }
      return;
    }
    if (additive) {
      final grp = _expandGroups([id]);
      if (selected.contains(id)) {
        selected.removeAll(grp);
      } else {
        selected.addAll(grp);
      }
    } else {
      selected
        ..clear()
        ..addAll(_expandGroups([id]));
    }
    notifyListeners();
  }

  /// Selects everything, or only what [where] accepts (e.g. one side of a cover).
  void selectAll([bool Function(ScrapElement e)? where]) {
    selected
      ..clear()
      ..addAll(els.where((e) => where?.call(e) ?? true).map((e) => e.id));
    notifyListeners();
  }

  /// Whether multi-select is on: taps add to the selection instead of replacing it.
  bool multi = false;
  void setMulti(bool v) {
    multi = v;
    notifyListeners();
  }

  // ── Adding and removing ────────────────────────────────────────────────
  int get _topZ => els.isEmpty ? 0 : els.map((e) => e.z).reduce(math.max);
  int get _bottomZ => els.isEmpty ? 0 : els.map((e) => e.z).reduce(math.min);

  void add(ScrapElement e, {bool select = true}) {
    e.z = _topZ + 1;
    els.add(e);
    if (select) {
      selected
        ..clear()
        ..add(e.id);
    }
    commit();
  }

  /// Deletes the selection (locked elements stay). Returns how many went.
  int deleteSelected() {
    final ids = [
      for (final e in selection)
        if (!e.locked) e.id,
    ];
    els.removeWhere((e) => ids.contains(e.id));
    selected.removeAll(ids);
    commit();
    return ids.length;
  }

  void duplicateSelected() {
    final copies = <ScrapElement>[];
    final regroup = <String, String>{};
    for (final e in selection) {
      final c = e.copy();
      if (e.group != null)
        c.group = regroup.putIfAbsent(
          e.group!,
          () => 'g${DateTime.now().microsecondsSinceEpoch}${regroup.length}',
        );
      c.locked = false;
      copies.add(c);
    }
    if (copies.isEmpty) return;
    var z = _topZ;
    for (final c in copies) {
      c.z = ++z;
    }
    els.addAll(copies);
    selected
      ..clear()
      ..addAll(copies.map((c) => c.id));
    commit();
  }

  void copySelected() {
    clipboard = [for (final e in selection) e.toJson()];
  }

  bool get canPaste => clipboard.isNotEmpty;

  void paste() {
    final fresh = <ScrapElement>[];
    final regroup = <String, String>{};
    for (final j in clipboard) {
      final e = ScrapElement.fromJson({...j, 'id': null});
      if (e == null) continue;
      e
        ..x = math.min(e.x + 0.03, 0.95)
        ..y = math.min(e.y + 0.03, 0.95)
        ..locked = false;
      if (e.group != null)
        e.group = regroup.putIfAbsent(
          e.group!,
          () => 'g${DateTime.now().microsecondsSinceEpoch}${regroup.length}',
        );
      fresh.add(e);
    }
    if (fresh.isEmpty) return;
    var z = _topZ;
    for (final e in fresh) {
      e.z = ++z;
    }
    els.addAll(fresh);
    selected
      ..clear()
      ..addAll(fresh.map((e) => e.id));
    commit();
  }

  // ── Grouping, locking ──────────────────────────────────────────────────
  bool get canGroup => selection.length > 1;
  bool get canUngroup => selection.any((e) => e.group != null);

  void group() {
    if (!canGroup) return;
    final g = 'g${DateTime.now().microsecondsSinceEpoch}';
    for (final e in selection) {
      e.group = g;
    }
    commit();
  }

  void ungroup() {
    for (final e in selection) {
      e.group = null;
    }
    commit();
  }

  bool get allLocked =>
      selection.isNotEmpty && selection.every((e) => e.locked);

  void toggleLock() {
    final lock = !allLocked;
    for (final e in selection) {
      e.locked = lock;
    }
    commit();
  }

  // ── Layers ─────────────────────────────────────────────────────────────
  void _renumber() {
    final sorted = [...els]..sort((a, b) => a.z.compareTo(b.z));
    for (var i = 0; i < sorted.length; i++) {
      sorted[i].z = i;
    }
  }

  void toFront() {
    var z = _topZ;
    for (final e in selection) {
      e.z = ++z;
    }
    _renumber();
    commit();
  }

  void toBack() {
    var z = _bottomZ;
    for (final e in selection.reversed) {
      e.z = --z;
    }
    _renumber();
    commit();
  }

  void _step(int dir) {
    _renumber();
    final ordered = [...els]..sort((a, b) => a.z.compareTo(b.z));
    final idx = [
      for (var i = 0; i < ordered.length; i++)
        if (selected.contains(ordered[i].id)) i,
    ];
    if (idx.isEmpty) return;
    if (dir > 0) {
      for (final i in idx.reversed) {
        if (i + 1 < ordered.length && !selected.contains(ordered[i + 1].id)) {
          final t = ordered[i].z;
          ordered[i].z = ordered[i + 1].z;
          ordered[i + 1].z = t;
          final tmp = ordered[i];
          ordered[i] = ordered[i + 1];
          ordered[i + 1] = tmp;
        }
      }
    } else {
      for (final i in idx) {
        if (i - 1 >= 0 && !selected.contains(ordered[i - 1].id)) {
          final t = ordered[i].z;
          ordered[i].z = ordered[i - 1].z;
          ordered[i - 1].z = t;
          final tmp = ordered[i];
          ordered[i] = ordered[i - 1];
          ordered[i - 1] = tmp;
        }
      }
    }
    commit();
  }

  void forward() => _step(1);
  void backward() => _step(-1);

  /// Moves a layer from [from] to [to] in the top-first layers list.
  void reorderLayer(int from, int to) {
    final top = [...els]..sort((a, b) => b.z.compareTo(a.z));
    final e = top.removeAt(from);
    top.insert(to.clamp(0, top.length), e);
    for (var i = 0; i < top.length; i++) {
      top[i].z = top.length - 1 - i;
    }
    commit();
  }

  // ── Alignment ──────────────────────────────────────────────────────────
  void align(ScrapAlign a) {
    final sel = [
      for (final e in selection)
        if (!e.locked) e,
    ];
    if (sel.isEmpty) return;
    final box = sel.length == 1
        ? const Rect.fromLTWH(0, 0, 1, 1)
        : _bounds(sel);
    for (final e in sel) {
      switch (a) {
        case ScrapAlign.left:
          e.x = box.left;
        case ScrapAlign.hCenter:
          e.x = box.center.dx - e.w / 2;
        case ScrapAlign.right:
          e.x = box.right - e.w;
        case ScrapAlign.top:
          e.y = box.top;
        case ScrapAlign.vCenter:
          e.y = box.center.dy - e.h / 2;
        case ScrapAlign.bottom:
          e.y = box.bottom - e.h;
      }
    }
    commit();
  }

  /// Spaces three or more elements evenly.
  void distribute({required bool horizontal}) {
    final sel = [
      for (final e in selection)
        if (!e.locked) e,
    ];
    if (sel.length < 3) return;
    sel.sort((a, b) => horizontal ? a.x.compareTo(b.x) : a.y.compareTo(b.y));
    final first = sel.first, last = sel.last;
    final total = horizontal
        ? (last.x + last.w - first.x)
        : (last.y + last.h - first.y);
    final sizes = sel.fold<double>(0, (s, e) => s + (horizontal ? e.w : e.h));
    final gap = (total - sizes) / (sel.length - 1);
    var pos = horizontal ? first.x : first.y;
    for (final e in sel) {
      if (horizontal) {
        e.x = pos;
        pos += e.w + gap;
      } else {
        e.y = pos;
        pos += e.h + gap;
      }
    }
    commit();
  }

  static Rect _bounds(List<ScrapElement> l) {
    var r = Rect.fromLTWH(l.first.x, l.first.y, l.first.w, l.first.h);
    for (final e in l.skip(1)) {
      r = r.expandToInclude(Rect.fromLTWH(e.x, e.y, e.w, e.h));
    }
    return r;
  }

  Rect? get selectionBounds => selection.isEmpty ? null : _bounds(selection);

  /// Moves the selection by a fraction of the page (locked elements stay).
  void moveSelection(double dx, double dy) {
    for (final e in selection) {
      if (e.locked) continue;
      e.x += dx;
      e.y += dy;
    }
    notifyListeners();
  }

  /// Repaints listeners during a live edit (a slider drag) without making an undo step.
  void refresh() => notifyListeners();

  void setZoom(double z) {
    zoom = z.clamp(0.5, 4.0);
    notifyListeners();
  }
}
