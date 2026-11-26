@TestOn('browser')
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/features/data_management/services/export_crypto.dart';

/// The web import path: fast scrypt + WebCrypto AES-GCM must read the same
/// files the native exporter writes.
void main() {
  test(
    'decryptAsync reads an export and rejects a wrong password',
    timeout: const Timeout(Duration(minutes: 4)),
    () async {
      final json = jsonEncode({
        'formatVersion': 'prism_v3',
        'rows': List.generate(50000, (i) => 'row $i ✨'),
      });
      final enc = ExportCrypto.encrypt(json, const [], 'hunter2 pässword');
      final sw = Stopwatch()..start();
      final r = await ExportCrypto.decryptAsync(enc, 'hunter2 pässword');
      // ignore: avoid_print
      print(
        'web decrypt: ${sw.elapsedMilliseconds} ms for ${enc.length} bytes',
      );
      expect(r.json, json);
      expect(r.mediaBlobs, isEmpty);
      await expectLater(
        ExportCrypto.decryptAsync(enc, 'wrong'),
        throwsA(isA<FormatException>()),
      );
    },
  );
}
