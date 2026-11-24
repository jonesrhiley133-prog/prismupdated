/// AES-256-GCM decryption. On the web this uses the browser's native
/// WebCrypto (fast and off the Dart code path); elsewhere, pointycastle.
library;

export 'aes_gcm_io.dart' if (dart.library.js_interop) 'aes_gcm_web.dart';
