/// How the web build draws (see web/flutter_bootstrap.js). On other
/// platforms these are no-ops.
library;

export 'render_mode_stub.dart'
    if (dart.library.js_interop) 'render_mode_web.dart';
