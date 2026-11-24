import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Decrypts [ciphertext] (with its 16-byte tag appended).
Future<Uint8List> aesGcmDecrypt(Uint8List key, Uint8List nonce, Uint8List ciphertext) async => aesGcmDecryptSync(key, nonce, ciphertext);

Uint8List aesGcmDecryptSync(Uint8List key, Uint8List nonce, Uint8List ciphertext) {
  final cipher = GCMBlockCipher(AESEngine())..init(false, AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)));
  final out = Uint8List(cipher.getOutputSize(ciphertext.length));
  var len = cipher.processBytes(ciphertext, 0, ciphertext.length, out, 0);
  len += cipher.doFinal(out, len);
  return out.sublist(0, len);
}
