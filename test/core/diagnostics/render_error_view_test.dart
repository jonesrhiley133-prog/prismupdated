import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/core/diagnostics/render_error_view.dart';
import 'package:prism_plurality/shared/theme/app_theme.dart';

class _Flaky extends StatefulWidget {
  const _Flaky();
  static var fail = true;
  @override
  State<_Flaky> createState() => _FlakyState();
}

class _FlakyState extends State<_Flaky> {
  @override
  Widget build(BuildContext context) => _Boom(fail: _Flaky.fail);
}

class _Boom extends StatelessWidget {
  const _Boom({required this.fail});
  final bool fail;
  @override
  Widget build(BuildContext context) {
    if (fail) throw StateError('boom');
    return const Text('Loaded fine');
  }
}

void main() {
  testWidgets('a page that fails to build shows a recoverable themed view', (t) async {
    final old = ErrorWidget.builder;
    ErrorWidget.builder = (d) => RecoverableErrorView(details: d);
    _Flaky.fail = true;
    await t.pumpWidget(MaterialApp(theme: AppTheme.light(), home: const Scaffold(body: _Flaky())));
    expect(t.takeException(), isStateError);
    expect(find.text('This page hit a snag'), findsOneWidget);
    _Flaky.fail = false;
    await t.tap(find.text('Try again'));
    await t.pump();
    expect(find.text('Loaded fine'), findsOneWidget);
    ErrorWidget.builder = old;
  });
}
