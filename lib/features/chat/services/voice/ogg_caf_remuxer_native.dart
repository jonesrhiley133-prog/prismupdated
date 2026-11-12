import 'dart:typed_data';

import 'package:ogg_caf_converter/ogg_caf_converter.dart';

import 'package:prism_plurality/features/chat/services/voice/mobile_voice_recorder_backend.dart';

MobileOggCafRemuxer createDefaultOggCafRemuxer() =>
    OggCafConverterMobileOggCafRemuxer();

class OggCafConverterMobileOggCafRemuxer implements MobileOggCafRemuxer {
  OggCafConverterMobileOggCafRemuxer({OggCafConverter? converter})
    : _converter = converter ?? OggCafConverter();

  final OggCafConverter _converter;

  @override
  Future<Uint8List> remuxCafToOgg(String inputPath) {
    return _converter.convertCafToOggInMemory(input: inputPath);
  }
}
