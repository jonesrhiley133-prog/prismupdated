import 'dart:typed_data';

import 'package:prism_plurality/features/chat/services/voice/mobile_voice_recorder_backend.dart';

MobileOggCafRemuxer createDefaultOggCafRemuxer() => _UnsupportedRemuxer();

class _UnsupportedRemuxer implements MobileOggCafRemuxer {
  @override
  Future<Uint8List> remuxCafToOgg(String inputPath) =>
      throw UnsupportedError('CAF remuxing is not available on the web.');
}
