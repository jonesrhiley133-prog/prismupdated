import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/features/scrapbook/scrap_models.dart';

List<ScrapElement> _roundTrip(List<ScrapElement> els) => [
  for (final e in els) ScrapElement.fromJson(e.toJson())!,
];

void main() {
  test('videos on one page keep independent ids, media and options', () {
    final a = ScrapElement(type: ScrapType.video, media: 'video:a.mp4')
      ..setOpt('loop', true)
      ..setOpt('vol', 0.3);
    final b = ScrapElement(type: ScrapType.video, media: 'video:b.mp4')
      ..setOpt('auto', true);
    expect(a.id, isNot(b.id));
    expect(b.opt('loop', false), isFalse);
    expect(a.opt('auto', false), isFalse);
    a.setOpt('vol', 0.9);
    expect(b.opt('vol', 1.0), 1.0);
  });

  test('videos across different pages do not share state', () {
    final page1 = [ScrapElement(type: ScrapType.video, media: 'video:a.mp4')];
    final page2 = [ScrapElement(type: ScrapType.video, media: 'video:b.mp4')];
    page1.first.setOpt('loop', true);
    expect(page2.first.opt('loop', false), isFalse);
    expect(page1.first.media, isNot(page2.first.media));
  });

  test('deleting one video leaves the others untouched', () {
    final els = [
      for (var i = 0; i < 3; i++)
        ScrapElement(type: ScrapType.video, media: 'video:$i.mp4')
          ..setOpt('vol', i / 10),
    ];
    final keep = [els[0].toJson(), els[2].toJson()];
    els.removeAt(1);
    expect([els[0].toJson(), els[1].toJson()], keep);
  });

  test('video options, opacity, lock and group survive save and restart', () {
    final e = ScrapElement(type: ScrapType.video, media: 'video:a.mp4')
      ..setOpt('loop', true)
      ..setOpt('thumb', 'media-id')
      ..opacity = 0.5
      ..locked = true
      ..group = 'g1';
    final back = _roundTrip([e]).single;
    expect(back.media, 'video:a.mp4');
    expect(back.opt('loop', false), isTrue);
    expect(back.opts['thumb'], 'media-id');
    expect(back.opacity, 0.5);
    expect(back.locked, isTrue);
    expect(back.group, 'g1');
  });

  test('undo snapshots do not alias an element\'s options', () {
    final e = ScrapElement(type: ScrapType.video, media: 'video:a.mp4')
      ..setOpt('vol', 0.2);
    final snap = e.toJson();
    e.setOpt('vol', 0.8);
    expect(ScrapElement.fromJson(snap)!.opt('vol', 1.0), 0.2);
  });

  test('older saved elements without new fields still load', () {
    final e = ScrapElement.fromJson({'id': 'x', 't': 'photo', 'x': .1, 'y': .1, 'w': .5, 'h': .5, 'z': 0})!;
    expect(e.opacity, 1);
    expect(e.locked, isFalse);
    expect(e.opts, isEmpty);
  });
}
