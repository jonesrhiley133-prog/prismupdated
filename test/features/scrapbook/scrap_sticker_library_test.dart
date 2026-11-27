import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:prism_plurality/features/scrapbook/scrap_sticker_library.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';

class _Lib extends StickerLibraryNotifier {
  @override
  Future<void> flush() async {}
}

Uint8List _png() => Uint8List.fromList(
  img.encodePng(
    img.Image(width: 8, height: 8, numChannels: 4)
      ..clear(img.ColorRgba8(255, 0, 0, 100)),
  ),
);

void main() {
  ProviderContainer box() {
    final c = ProviderContainer(
      overrides: [
        stickerLibraryProvider.overrideWith(_Lib.new),
        trackerKindProvider.overrideWith(
          (ref, k) => const AsyncValue.data(<TrackerRecord>[]),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('favorites, recents and collections', () {
    final c = box();
    final n = c.read(stickerLibraryProvider.notifier);
    n.toggleFavorite('Food.0');
    expect(c.read(stickerLibraryProvider).isFavorite('Food.0'), isTrue);
    n.toggleFavorite('Food.0');
    expect(c.read(stickerLibraryProvider).favorites, isEmpty);
    for (var i = 0; i < 40; i++) {
      n.used('Food.$i');
    }
    n.used('Food.5');
    final r = c.read(stickerLibraryProvider).recents;
    expect(r.length, maxRecents);
    expect(r.first, 'Food.5');
    expect(r.where((x) => x == 'Food.5').length, 1);
    final id = n.addCollection('Cute');
    n.toggleInCollection(id, 'Kawaii.1');
    n.toggleInCollection(id, 'Kawaii.2');
    n.toggleInCollection(id, 'Kawaii.1');
    expect(c.read(stickerLibraryProvider).collections.single.items, [
      'Kawaii.2',
    ]);
    n.renameCollection(id, 'Cutest');
    expect(c.read(stickerLibraryProvider).collections.single.name, 'Cutest');
    n.deleteCollection(id);
    expect(c.read(stickerLibraryProvider).collections, isEmpty);
  });

  test('library survives a save and load', () {
    final l = StickerLibrary(
      favorites: const ['a'],
      recents: const ['b'],
      collections: const [
        StickerCollection(id: 'x', name: 'N', items: ['a']),
      ],
      custom: const [CustomSticker(id: 'c:1', name: 'Mine', media: 'm1')],
    );
    final back = StickerLibrary.fromJson(l.toJson());
    expect(back.favorites, ['a']);
    expect(back.collections.single.items, ['a']);
    expect(back.custom.single.media, 'm1');
    expect(
      StickerLibrary.fromJson({
        'f': 5,
        'c': [1, 'x'],
      }).collections,
      isEmpty,
    );
  });

  test('imports: PNG keeps transparency, SVG is cleaned, junk is refused', () {
    final png = prepareStickerFile(_png());
    expect(png.ok!.mime, 'image/png');
    expect(img.decodePng(png.ok!.bytes)!.hasAlpha, isTrue);

    const evil =
        '<svg xmlns="http://www.w3.org/2000/svg" onload="x()"><script>alert(1)</script><image href="https://evil.test/a.png"/><circle r="5" onclick="y()"/><foreignObject><div/></foreignObject></svg>';
    final svg = prepareStickerFile(Uint8List.fromList(utf8.encode(evil)));
    expect(svg.ok!.mime, 'image/svg+xml');
    final clean = utf8.decode(svg.ok!.bytes);
    expect(clean, isNot(contains('script')));
    expect(clean, isNot(contains('onload')));
    expect(clean, isNot(contains('onclick')));
    expect(clean, isNot(contains('evil.test')));
    expect(clean, isNot(contains('foreignObject')));
    expect(clean, contains('<circle'));

    expect(prepareStickerFile(Uint8List(0)).error, StickerImportError.empty);
    expect(
      prepareStickerFile(Uint8List.fromList([1, 2, 3, 4])).error,
      StickerImportError.unsupported,
    );
    expect(
      prepareStickerFile(
        Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2]),
      ).error,
      StickerImportError.unreadable,
    );
    expect(
      prepareStickerFile(Uint8List(9 * 1024 * 1024)).error,
      StickerImportError.tooBig,
    );
  });

  test('packs round-trip, skip bad entries and refuse non-packs', () {
    final json = exportStickerPack('Reds', [(name: 'Red', bytes: _png())]);
    final back = parseStickerPack(json)!;
    expect(back.name, 'Reds');
    expect(back.stickers.single.name, 'Red');
    final mixed = jsonEncode({
      'prismStickers': 1,
      'name': 'x',
      'stickers': [
        {'n': 'ok', 'd': base64Encode(_png())},
        {'n': 'bad', 'd': 'AAAA'},
        7,
      ],
    });
    final m = parseStickerPack(mixed)!;
    expect(m.stickers.length, 1);
    expect(m.skipped, 2);
    expect(parseStickerPack('nope'), isNull);
    expect(parseStickerPack('{"hello":1}'), isNull);
  });
}
