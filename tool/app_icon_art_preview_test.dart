// Renders the permanent icon designs (and a sample of seasonal ones) to
// PNG files. Run with: flutter test tool/app_icon_art_preview_test.dart
// Output: build/icon_art/<id>.png (432 px, full bleed, for launcher art).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/core/app_icon/icon_art.dart';
import 'package:prism_plurality/core/app_icon/icon_catalog.dart';

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    l.addFont(Future.value(ByteData.view(File(f).readAsBytesSync().buffer)));
  }
  await l.load();
}

void main() {
  testWidgets('render icon art', (t) async {
    await t.runAsync(() async {
      await _font('NotoColorEmoji', ['assets/fonts/NotoColorEmoji.ttf']);
      final codec = await ui.instantiateImageCodec(
        File('assets/icon_layers/Prism-Logo-Foreground.png').readAsBytesSync(),
        targetWidth: 512,
      );
      final logo = (await codec.getNextFrame()).image;
      final out = Directory(Platform.environment['ICON_OUT'] ?? 'build/icon_art')
        ..createSync(recursive: true);
      final ids = Platform.environment['ICON_SEASONAL'] == '1'
          ? [
              for (final c in ['christmas', 'halloween', 'kwanzaa', 'pride'])
                ...seasonalIconDesigns(c).take(5),
            ]
          : permanentIconDesigns;
      for (final d in ids) {
        final img = await renderIconArtImage(d.art, 432, logo: logo);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('${out.path}/${d.id}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        img.dispose();
      }
    });
  });
}
