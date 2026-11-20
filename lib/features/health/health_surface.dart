import 'package:prism_plurality/shared/ui_kit.dart';

/// Prism's surface with a local ink layer for expandable rows and region lists.
/// Without this layer a ListTile paints behind the surface decoration.
class HealthSurface extends StatelessWidget {
  const HealthSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => PrismSurface(
    padding: padding,
    child: Material(type: MaterialType.transparency, child: child),
  );
}

/// Modal editors keep the shared Prism header fixed while the sheet's own
/// controller scrolls the form. A second nested scroll view would compete with
/// DraggableScrollableSheet and can leave focused controls outside the viewport.
class HealthEditorScaffold extends StatelessWidget {
  const HealthEditorScaffold({
    super.key,
    required this.topBar,
    required this.body,
    this.bodyPadding = EdgeInsets.zero,
    this.backgroundColor,
    this.topBarMaxWidth = double.infinity,
  });
  final PrismTopBar topBar;
  final Widget body;
  final EdgeInsets bodyPadding;
  final Color? backgroundColor;
  final double topBarMaxWidth;
  @override
  Widget build(BuildContext context) => PrismPageScaffold(
    bodyPadding: bodyPadding,
    backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.surface,
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClampedBody(maxWidth: topBarMaxWidth, child: topBar),
        Expanded(child: body),
      ],
    ),
  );
}
