import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/features/wallets/id_card_view.dart';
import 'package:prism_plurality/features/wallets/id_shapes.dart';
import 'package:prism_plurality/features/wallets/id_template_gallery.dart';
import 'package:prism_plurality/features/wallets/id_templates.dart';
import 'package:prism_plurality/features/wallets/wallet_data.dart';

String _signature(CardFace f) => [
  f.pattern,
  f.aspect.toStringAsFixed(2),
  for (final l in f.layers)
    '${l.kind}:${l.text.length < 12 ? l.text : ''}:${l.field ?? ''}:${l.x.toStringAsFixed(2)},${l.y.toStringAsFixed(2)},${l.w.toStringAsFixed(2)},${l.h.toStringAsFixed(2)}',
].join('|');

void main() {
  test('at least 60 templates, all with unique ids and names', () {
    expect(idTemplates.length, greaterThanOrEqualTo(60));
    expect(idTemplates.map((t) => t.id).toSet().length, idTemplates.length);
    expect(idTemplates.map((t) => t.name).toSet().length, idTemplates.length);
    for (final t in idTemplates) {
      expect(t.id.startsWith('tpl.'), isTrue);
      expect(
        t.id.split('.').length,
        2,
        reason: 'slug must not contain dots: ${t.id}',
      );
    }
  });

  test('every requested style family is represented', () {
    final cats = idTemplateCategories.map((c) => c.toLowerCase()).join('|');
    for (final k in [
      'modern',
      'student',
      'vintage',
      'passport',
      'social',
      'minimal',
      'glass',
      'holo',
      'anime',
      'rpg',
      'trading',
      'magazine',
      'gothic',
      'cottage',
      'cyber',
      'celestial',
      'kawaii',
      'grunge',
      'scrapbook',
      'botanical',
      'retro',
      'music',
      'professional',
      'business',
      'polaroid',
      'seasonal',
    ]) {
      expect(cats, contains(k), reason: k);
    }
  });

  test('templates are different designs, not recolours of one layout', () {
    final sigs = <String, String>{};
    for (final t in idTemplates) {
      final (f, _) = buildIdTemplate(
        t,
        type: 'member',
        fields: const {
          'name',
          'pronouns',
          'role',
          'birthday',
          'number',
          'photo',
          'issued',
          'emoji',
          'interests',
          'status',
        },
      );
      final sig = _signature(f);
      expect(
        sigs.containsKey(sig),
        isFalse,
        reason: '${t.id} duplicates ${sigs[sig]}',
      );
      sigs[sig] = t.id;
    }
    // Layout geometry (ignoring colour) must differ for nearly all pairs.
    final shapes = idTemplates
        .map(
          (t) => _signature(
            buildIdTemplate(t, type: 'member').$1,
          ).split('|').skip(2).join('|'),
        )
        .toSet();
    expect(shapes.length, idTemplates.length);
  });

  test('landscape, portrait and square designs all exist', () {
    expect(idTemplates.where((t) => t.aspect > 1.2).length, greaterThan(10));
    expect(idTemplates.where((t) => t.aspect < 0.9).length, greaterThan(5));
    expect(
      idTemplates.where((t) => (t.aspect - 1).abs() < 0.01).length,
      greaterThan(0),
    );
  });

  test('every template builds for every card type and any field choice', () {
    for (final t in idTemplates) {
      for (final type in idCardTypes.keys) {
        for (final fields in [
          const <String>{},
          const {'name'},
          idFields.keys.toSet(),
        ]) {
          final (f, b) = buildIdTemplate(t, type: type, fields: fields);
          expect(f.tpl, t.id);
          expect(b.tpl, t.id);
          expect(f.aspect, t.aspect);
          for (final l in [...f.layers, ...b.layers]) {
            expect(l.id.startsWith('t'), isTrue);
            expect(
              l.x.isFinite && l.y.isFinite && l.w.isFinite && l.h.isFinite,
              isTrue,
            );
            expect(l.opacity, inInclusiveRange(0, 1));
            if (l.kind == 'shape' && l.text.isNotEmpty) {
              expect(
                idShapeKinds.containsKey(l.text),
                isTrue,
                reason: '${t.id}: ${l.text}',
              );
            }
            if (l.kind == 'field')
              expect(
                idFields.containsKey(l.field),
                isTrue,
                reason: '${t.id}: ${l.field}',
              );
          }
        }
      }
    }
  });

  test('fields a card hides never appear on the template', () {
    final (f, b) = buildIdTemplate(
      idTemplates.first,
      type: 'member',
      fields: const {'name'},
    );
    for (final l in [
      ...f.layers,
      ...b.layers,
    ].where((l) => l.kind == 'field')) {
      expect(l.field, 'name');
    }
    expect(f.layers.any((l) => l.kind == 'photo'), isFalse);
  });

  test('every back says the card is personal, not official', () {
    for (final t in idTemplates) {
      final (_, b) = buildIdTemplate(t, type: 'member');
      expect(
        b.layers.any(
          (l) =>
              l.kind == 'text' && l.text.contains('not an official document'),
        ),
        isTrue,
        reason: t.id,
      );
    }
  });

  test('every template id resolves through the shared builder', () {
    for (final t in idTemplates) {
      final parts = t.id.split('.');
      final (f, _) = buildAnyTemplate(parts.first, parts.last, type: 'member');
      expect(f.tpl, t.id);
      expect(idTemplateAspect(parts.first, parts.last), t.aspect);
    }
    // Legacy collection templates still work.
    final (f, _) = buildAnyTemplate('holo', 'banner', type: 'member');
    expect(f.tpl, 'holo.banner');
  });

  test('shape, gradient, outline and card shape survive saving', () {
    const l = CardLayer(
      id: 'a',
      kind: 'shape',
      text: 'star',
      color2: 0xFF112233,
      stroke: 0.03,
    );
    final back = CardLayer.fromJson(l.toJson());
    expect(back.text, 'star');
    expect(back.color2, 0xFF112233);
    expect(back.stroke, 0.03);
    final face = CardFace(layers: [l], aspect: 0.64, tpl: 'tpl.x');
    final f2 = CardFace.fromJson(face.toJson());
    expect(f2.aspect, 0.64);
    expect(f2.layers.single.color2, 0xFF112233);
    // Old saved layers without the new fields still load.
    expect(CardLayer.fromJson({'id': 'x', 'k': 'shape'}).color2, isNull);
  });

  test('all 30 shape kinds make a drawable outline', () {
    for (final k in idShapeKinds.keys) {
      final p = idShapePath(k, const Rect.fromLTWH(0, 0, 100, 60));
      expect(p.getBounds().isEmpty, isFalse, reason: k);
    }
  });

  testWidgets('gallery lists every template and renders them lazily', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(8),
            child: IdTemplateGallery(
              type: 'member',
              selected: 'tpl.modern-stripe',
              onPick: (id) => picked = id,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Modern stripe'), findsOneWidget);
    await tester.tap(find.text('Modern stripe'));
    expect(picked, 'tpl.modern-stripe');
  });

  testWidgets('contact sheet renders all templates without errors', (
    tester,
  ) async {
    const cols = 6;
    const cell = 150.0;
    final rows = (idTemplates.length / cols).ceil();
    final key = GlobalKey();
    tester.view.physicalSize = Size(
      cols * (cell + 10) + 10,
      rows * (cell + 26) + 10,
    );
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFFCCCCCC),
          body: RepaintBoundary(
            key: key,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final t in idTemplates)
                  SizedBox(
                    width: cell,
                    height: cell + 16,
                    child: Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: Builder(
                              builder: (context) {
                                final (f, _) = buildIdTemplate(
                                  t,
                                  type: 'member',
                                  fields: const {
                                    'name',
                                    'pronouns',
                                    'role',
                                    'birthday',
                                    'number',
                                    'photo',
                                    'issued',
                                    'emoji',
                                    'interests',
                                    'status',
                                    'signature',
                                    'expires',
                                    'notes',
                                    'custom1',
                                    'custom2',
                                    'flags',
                                    'system',
                                    'issuer',
                                  },
                                );
                                final w = t.aspect >= 1
                                    ? cell
                                    : cell * t.aspect;
                                return CardFaceView(
                                  face: f,
                                  values: idPreviewValues,
                                  width: w,
                                  ratio: t.aspect,
                                );
                              },
                            ),
                          ),
                        ),
                        Text(t.name, style: const TextStyle(fontSize: 9)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    final out = Platform.environment['ID_SHEET'];
    if (out != null) {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await boundary.toImage();
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        File(out).writeAsBytesSync(data!.buffer.asUint8List());
      });
    }
  });
}
