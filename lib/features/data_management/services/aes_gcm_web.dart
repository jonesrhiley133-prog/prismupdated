import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'aes_gcm_io.dart' as fallback;

/// Decrypts [ciphertext] (with its 16-byte tag appended) with WebCrypto,
/// falling back to the Dart implementation if WebCrypto is unavailable
/// (e.g. a page served over plain http, where `crypto.subtle` is absent).
Future<Uint8List> aesGcmDecrypt(Uint8List key, Uint8List nonce, Uint8List ciphertext) async {
  final crypto = globalContext['crypto'] as JSObject?;
  final subtle = crypto?['subtle'] as JSObject?;
  if (subtle == null) return fallback.aesGcmDecryptSync(key, nonce, ciphertext);
  final alg = JSObject()..['name'] = 'AES-GCM'.toJS;
  final cryptoKey = await (subtle.callMethodVarArgs<JSPromise<JSObject>>('importKey'.toJS, [
    'raw'.toJS,
    key.toJS,
    alg,
    false.toJS,
    ['decrypt'.toJS].toJS,
  ])).toDart;
  final params = JSObject()
    ..['name'] = 'AES-GCM'.toJS
    ..['iv'] = nonce.toJS
    ..['tagLength'] = 128.toJS;
  try {
    final plain = await (subtle.callMethodVarArgs<JSPromise<JSArrayBuffer>>('decrypt'.toJS, [params, cryptoKey, ciphertext.toJS])).toDart;
    return plain.toDart.asUint8List();
  } catch (_) {
    // WebCrypto rejects with an OperationError on a wrong key / bad tag.
    throw const FormatException('mac check in GCM failed');
  }
}

Uint8List aesGcmDecryptSync(Uint8List key, Uint8List nonce, Uint8List ciphertext) => fallback.aesGcmDecryptSync(key, nonce, ciphertext);
