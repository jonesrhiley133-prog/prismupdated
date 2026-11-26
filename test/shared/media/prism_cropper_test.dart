import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';
import 'package:prism_plurality/shared/media/prism_originals.dart';
import 'package:prism_plurality/shared/utils/prism_image_picker.dart';
import 'package:prism_plurality/shared/widgets/prism_image_crop_screen.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

Future<Uint8List> _png(int w, int h) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.drawRect(
    Rect.fromLTWH(0, 0, w / 2, h.toDouble()),
    Paint()..color = const Color(0xFFFF0000),
  );
  c.drawRect(
    Rect.fromLTWH(w / 2, 0, w / 2, h.toDouble()),
    Paint()..color = const Color(0xFF0000FF),
  );
  final img = await rec.endRecording().toImage(w, h);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  test('ratio text parses ratios and rejects nonsense', () {
    expect(PrismCropRatio.parse('5:7'), closeTo(5 / 7, 1e-9));
    expect(PrismCropRatio.parse('16/9'), closeTo(16 / 9, 1e-9));
    expect(PrismCropRatio.parse('1.5'), 1.5);
    expect(PrismCropRatio.parse('abc'), isNull);
    expect(PrismCropRatio.parse('0:5'), isNull);
    expect(PrismCropRatio.parse('100:1'), isNull);
  });

  test('every cropper preset offers freeform and ratios; avatar is locked', () {
    expect(
      PrismCropRatio.standard.map((r) => r.id),
      containsAll(['free', '1:1', '16:9', '9:16']),
    );
    expect(PrismCropSpec.free.ratios, isNotEmpty);
    expect(PrismCropSpec.avatar.ratios, isEmpty);
    expect(PrismCropSpec.avatar.circle, isTrue);
  });

  test('originals are kept untouched and can be loaded again', () async {
    final dir = await Directory.systemTemp.createTemp('orig-test');
    final old = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(dir.path);
    addTearDown(() {
      PathProviderPlatform.instance = old;
      dir.deleteSync(recursive: true);
    });
    final bytes = await _png(40, 30);
    final id = await PrismOriginals.save(bytes);
    expect(id!.startsWith('orig:'), isTrue);
    expect(await PrismOriginals.load(id), bytes);
    expect(await PrismOriginals.load('orig:missing'), isNull);
    await PrismOriginals.delete(id);
    expect(await PrismOriginals.exists(id), isFalse);
  });

  testWidgets('cropper shows ratios, zoom, flip, reset and a live preview', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final bytes = (await tester.runAsync(() => _png(120, 80)))!;
    ui.Image? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async => result = await showPrismImageCropper(
                  context,
                  PrismImageCropRequest(
                    sourceBytes: bytes,
                    title: 'Crop',
                    doneButtonTitle: 'Done',
                    cancelButtonTitle: 'Cancel',
                    aspectRatio: null,
                    ratios: PrismCropRatio.standard,
                    circlePreview: true,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('Free'), findsOneWidget);
    expect(find.text('1:1'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
    expect(find.textContaining('Flip'), findsNWidgets(2));
    expect(find.byType(ClipOval), findsOneWidget);
    await tester.tap(find.text('1:1'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Reset'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });
}
