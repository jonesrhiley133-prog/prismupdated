import 'package:flutter/material.dart';

import 'package:prism_plurality/shared/utils/animations.dart';

/// Animates content that changes in place (tabs, segmented views, wizard
/// steps): when [id] changes, the new content fades in and rises slightly.
///
/// Only the incoming content is animated — the old content is not kept on
/// screen for a cross-fade. That keeps it cheap and means steps that share
/// form or field keys never exist twice at once. Off when the system or
/// Prism asks for reduced motion.
class SectionSwitcher extends StatefulWidget {
  const SectionSwitcher({super.key, required this.id, required this.child});

  final Object? id;
  final Widget child;

  @override
  State<SectionSwitcher> createState() => _SectionSwitcherState();
}

class _SectionSwitcherState extends State<SectionSwitcher> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Anim.md, value: 1);
  late final Animation<double> _fade = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  late final Animation<Offset> _slide = Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(_fade);

  @override
  void didUpdateWidget(SectionSwitcher old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id && !MediaQuery.of(context).disableAnimations) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: SlideTransition(
      position: _slide,
      child: KeyedSubtree(key: ValueKey(widget.id), child: widget.child),
    ),
  );
}
