import 'package:flutter/material.dart';

import 'package:prism_plurality/core/diagnostics/freeze_watchdog.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';

/// Shown in place of a part of the screen that failed to build, instead of
/// a blank or black area. Uses the current theme when there is one, records
/// the error (without personal content) for diagnostics, and offers a way
/// to retry or leave.
class RecoverableErrorView extends StatefulWidget {
  const RecoverableErrorView({super.key, required this.details});
  final FlutterErrorDetails details;
  @override
  State<RecoverableErrorView> createState() => _RecoverableErrorViewState();
}

class _RecoverableErrorViewState extends State<RecoverableErrorView> {
  @override
  void initState() {
    super.initState();
    final first = widget.details.exceptionAsString().split('\n').first;
    FreezeWatchdog.crumb('render error: ${first.length > 160 ? first.substring(0, 160) : first} (${widget.details.library ?? ''})');
  }

  void _retry() {
    // Rebuild the nearest stateful ancestor so the failed part builds again.
    var done = false;
    context.visitAncestorElements((e) {
      if (!done && e is StatefulElement) {
        e.markNeedsBuild();
        done = true;
      }
      return !done;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final small = context.findRenderObject() == null;
    return LayoutBuilder(builder: (context, box) {
      final tiny = box.maxHeight < 120 || box.maxWidth < 180;
      final ink = theme.colorScheme.onSurfaceVariant;
      if (tiny) {
        return Tooltip(message: 'This part couldn\'t load', child: Icon(Icons.error_outline, color: ink, size: 18));
      }
      return Material(
        color: theme.colorScheme.surface,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.auto_fix_high_outlined, size: 40, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text('This page hit a snag', style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text('Nothing was lost. Try again, or go back and reopen it.', style: theme.textTheme.bodyMedium?.copyWith(color: ink), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                PrismButton(label: 'Try again', tone: PrismButtonTone.filled, onPressed: _retry),
                if (!small) PrismButton(label: 'Go back', onPressed: () => Navigator.maybeOf(context)?.maybePop()),
              ]),
            ]),
          ),
        ),
      );
    });
  }
}

/// Records page changes in the diagnostics trail.
class PrismNavObserver extends NavigatorObserver {
  String _name(Route<dynamic>? r) => r?.settings.name ?? r.runtimeType.toString();
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => FreezeWatchdog.crumb('nav push ${_name(route)}');
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => FreezeWatchdog.crumb('nav pop ${_name(route)}');
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => FreezeWatchdog.crumb('nav replace ${_name(newRoute)}');
}
