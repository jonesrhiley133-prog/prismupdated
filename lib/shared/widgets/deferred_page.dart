import 'package:flutter/widgets.dart';

import 'package:prism_plurality/shared/widgets/prism_loading_state.dart';

/// Builds a page whose code lives in a deferred library (`import ... deferred
/// as x`), so heavy, rarely used features are not part of the startup
/// download. The library loads the first time the page opens; later opens
/// build at once.
///
/// On platforms that do not split code (Android/iOS without deferred
/// components, desktop, tests) the load completes immediately.
class DeferredPage extends StatefulWidget {
  const DeferredPage({super.key, required this.load, required this.build});

  /// The deferred prefix's `loadLibrary`.
  final Future<void> Function() load;

  /// Builds the page once the library is loaded.
  final Widget Function() build;

  static final Map<Future<void> Function(), Future<void>> _loads = {};
  static final Set<Future<void> Function()> _loaded = {};

  @override
  State<DeferredPage> createState() => _DeferredPageState();
}

class _DeferredPageState extends State<DeferredPage> {
  late bool _ready = DeferredPage._loaded.contains(widget.load);

  @override
  void initState() {
    super.initState();
    if (_ready) return;
    DeferredPage._loads.putIfAbsent(widget.load, widget.load).then((_) {
      DeferredPage._loaded.add(widget.load);
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) =>
      _ready ? widget.build() : const PrismLoadingState();
}
