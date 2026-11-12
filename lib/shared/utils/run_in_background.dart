import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart' show kIsWeb;

/// Runs [computation] on a short-lived background isolate on native
/// platforms. Browsers have no Dart isolates, so on the web it runs on the
/// main thread instead (callers only use pure-Dart work here).
Future<R> runInBackground<R>(FutureOr<R> Function() computation) {
  if (kIsWeb) return Future.sync(computation);
  return Isolate.run(computation);
}
