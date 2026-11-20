import 'dart:async';

import 'package:flutter/widgets.dart';

/// Rebuilds [builder] once per second with the current time, for live
/// timers (exact to the second).
///
/// Pauses while its page is hidden (the shell keeps hidden sections mounted
/// with tickers off), so a timer on another tab costs nothing. On return it
/// rebuilds at once with the current time, so the value stays exact.
class LiveTicker extends StatefulWidget {
  const LiveTicker({super.key, required this.builder});

  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  State<LiveTicker> createState() => _LiveTickerState();
}

class _LiveTickerState extends State<LiveTicker> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && _timer == null) {
      _now = DateTime.now();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    } else if (!visible && _timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _now);
}
