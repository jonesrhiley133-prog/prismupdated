import 'package:flutter/material.dart';

import 'package:prism_plurality/shared/theme/prism_tokens.dart';

/// Constrains a content-primary screen (dashboard or feed — home, polls,
/// boards, stats, sleep) to a comfortable column width and centers it, so the
/// body doesn't stretch edge-to-edge on wide desktop windows.
///
/// This is the counterpart to [ListDetailLayout]: list-first screens get a
/// permanent list pane, but content-first screens keep their content centered
/// and open per-item detail in a modal side sheet (see `showDetailSideSheet`)
/// rather than squishing the primary view into a narrow pane.
///
/// Works around a full-height scrollable (e.g. a `CustomScrollView`): the child
/// fills the available height and is clamped/centered only on the cross axis.
class ClampedBody extends StatelessWidget {
  const ClampedBody({
    super.key,
    required this.child,
    this.maxWidth,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  /// Defaults to [PrismTokens.contentMaxWidth] (wider on desktop web).
  final double? maxWidth;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    // Depend on the window size so the column follows browser resizes.
    MediaQuery.sizeOf(context);
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth ?? PrismTokens.contentMaxWidth),
        child: child,
      ),
    );
  }
}

/// Keeps month calendars a comfortable size on wide web windows instead of
/// stretching day cells across the whole screen. No effect on phones,
/// tablets or the native apps.
class CompactCalendar extends StatelessWidget {
  const CompactCalendar({super.key, required this.child, this.maxWidth = 560});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    MediaQuery.sizeOf(context);
    if (PrismTokens.desktopWebContentWidth == null) return child;
    return Center(
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
    );
  }
}
