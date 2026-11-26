import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:prism_plurality/features/seasonal/decor_models.dart';

/// Where real parts of Prism's interface currently are, so a decoration can
/// be attached to a profile picture, a widget or a header and follow it.
class DecorAnchors {
  DecorAnchors._();

  static final ValueNotifier<Map<DecoAnchor, Rect>> rects = ValueNotifier(
    const {},
  );

  static void set(DecoAnchor a, Rect r) {
    final cur = rects.value[a];
    if (cur != null &&
        (cur.left - r.left).abs() < 0.5 &&
        (cur.top - r.top).abs() < 0.5 &&
        (cur.width - r.width).abs() < 0.5 &&
        (cur.height - r.height).abs() < 0.5)
      return;
    rects.value = {...rects.value, a: r};
  }

  static void clear(DecoAnchor a, Rect? only) {
    if (!rects.value.containsKey(a)) return;
    if (only != null && rects.value[a] != only) return;
    rects.value = {...rects.value}..remove(a);
  }
}

/// Wrap a part of the interface so decorations can attach to it. It draws
/// nothing and changes no layout.
class DecoAnchorTarget extends StatefulWidget {
  const DecoAnchorTarget({
    super.key,
    required this.anchor,
    required this.child,
  });
  final DecoAnchor anchor;
  final Widget child;

  @override
  State<DecoAnchorTarget> createState() => _DecoAnchorTargetState();
}

class _DecoAnchorTargetState extends State<DecoAnchorTarget> {
  Rect? _last;
  bool _scheduled = false;

  void _measure() {
    _scheduled = false;
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final r = box.localToGlobal(Offset.zero) & box.size;
    _last = r;
    DecorAnchors.set(widget.anchor, r);
  }

  @override
  void dispose() {
    DecorAnchors.clear(widget.anchor, _last);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_scheduled) {
      _scheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) => _measure());
    }
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        if (!_scheduled) {
          _scheduled = true;
          SchedulerBinding.instance.addPostFrameCallback((_) => _measure());
        }
        return false;
      },
      child: SizeChangedLayoutNotifier(child: widget.child),
    );
  }
}
