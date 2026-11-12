/// Opens the app database in the browser (Drift + SQLite compiled to WASM,
/// persisted in OPFS or IndexedDB). Native builds get a stub.
library;

export 'web_database_stub.dart'
    if (dart.library.js_interop) 'web_database_web.dart';
