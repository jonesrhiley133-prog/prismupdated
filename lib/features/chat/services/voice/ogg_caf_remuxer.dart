/// Default CAF→Ogg remuxer for iOS voice notes. The converter package uses
/// 64-bit integer literals that JavaScript cannot represent, so web builds
/// get a stub (voice-note recording is not offered on the web).
library;

export 'ogg_caf_remuxer_stub.dart'
    if (dart.library.ffi) 'ogg_caf_remuxer_native.dart';
