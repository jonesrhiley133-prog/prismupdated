import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;

import 'package:prism_plurality/core/services/files/prism_file_dialog_service.dart';
import 'package:prism_plurality/features/social/models/social.dart';
import 'package:prism_plurality/features/social/services/social_actions.dart';
import 'package:prism_plurality/features/social/services/social_media.dart'
    show socialMediaStoreProvider;
import 'package:prism_plurality/shared/ui_kit.dart';

/// Shared export helpers for Companions, Passport and Wrapped. Nothing is
/// ever uploaded or shared without the user starting it.

/// Renders the widget under [key] (a RepaintBoundary) to PNG bytes.
Future<Uint8List?> captureBoundary(
  GlobalKey key, {
  double pixelRatio = 3,
}) async {
  final obj = key.currentContext?.findRenderObject();
  if (obj is! RenderRepaintBoundary) return null;
  final img = await obj.toImage(pixelRatio: pixelRatio);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return data?.buffer.asUint8List();
}

Future<bool> saveImageBytes(WidgetRef ref, Uint8List bytes, String name) async {
  try {
    final out = await ref
        .read(prismFileDialogServiceProvider)
        .saveBytes(
          bytes: bytes,
          suggestedName: name.endsWith('.png') ? name : '$name.png',
          allowedExtensions: const ['png'],
          mimeType: 'image/png',
        );
    return out.pathOrUri != null || out.savedDisplayName != null;
  } catch (_) {
    return false;
  }
}

Future<bool> savePdfBytes(WidgetRef ref, Uint8List bytes, String name) async {
  try {
    final out = await ref
        .read(prismFileDialogServiceProvider)
        .saveBytes(
          bytes: bytes,
          suggestedName: name.endsWith('.pdf') ? name : '$name.pdf',
          allowedExtensions: const ['pdf'],
          mimeType: 'application/pdf',
        );
    return out.pathOrUri != null || out.savedDisplayName != null;
  } catch (_) {
    return false;
  }
}

/// One image per page, centered, in a PDF.
Future<Uint8List> imagesToPdf(
  List<Uint8List> pages, {
  String title = 'Prism',
}) async {
  final doc = pw.Document(title: title, creator: 'Prism');
  for (final p in pages) {
    final img = pw.MemoryImage(p);
    doc.addPage(
      pw.Page(
        pageFormat: pdf.PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain)),
      ),
    );
  }
  return doc.save();
}

/// Stores the image in Prism's media and posts it to the Bulletin Board
/// as [actor]. Returns the media id.
Future<String?> shareImageToBoard(
  WidgetRef ref,
  Uint8List bytes, {
  required String actor,
  String title = '',
  String body = '',
  List<String> tags = const [],
}) async {
  final id = await ref
      .read(socialMediaStoreProvider)
      .addImage(bytes, owner: actor);
  if (id == null) return null;
  await ref
      .read(socialActionsProvider)
      .createPost(
        actor: actor,
        type: PostType.image,
        title: title,
        body: body,
        images: [id],
        tags: tags,
      );
  return id;
}

/// Saves the image into Prism's media library (e.g. to attach elsewhere).
Future<String?> storeImage(WidgetRef ref, Uint8List bytes, {String? owner}) =>
    ref.read(socialMediaStoreProvider).addImage(bytes, owner: owner);
