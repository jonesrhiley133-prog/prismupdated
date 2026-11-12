/// Platform-neutral entry points for opening SQLite outside Drift's managed
/// connection. Native builds use FFI sqlite3; web builds get a stub, because
/// the web build stores data through Drift's WASM backend instead (see
/// `lib/main_web.dart`).
library;

export 'sqlite_opener_stub.dart'
    if (dart.library.ffi) 'sqlite_opener_native.dart';
