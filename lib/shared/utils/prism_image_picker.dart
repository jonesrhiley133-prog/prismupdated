import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:prism_plurality/core/services/files/prism_file_dialog_service.dart';
import 'package:prism_plurality/shared/media/prism_originals.dart';
import 'package:prism_plurality/shared/utils/picked_image_normalizer.dart';
import 'package:prism_plurality/shared/utils/prism_cropped_bitmap_encoder.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/widgets/prism_image_crop_screen.dart';

/// What a particular place wants from the cropper.
@immutable
class PrismCropSpec {
  const PrismCropSpec({
    this.aspect,
    this.ratios = PrismCropRatio.standard,
    this.circle = false,
    this.title,
  });

  /// Starting ratio (null = freeform). With [ratios] empty the crop is locked.
  final double? aspect;
  final List<PrismCropRatio> ratios;
  final bool circle;
  final String? title;

  /// Anything goes: freeform plus every common ratio.
  static const free = PrismCropSpec();

  /// Square start, other ratios allowed.
  static const square = PrismCropSpec(aspect: 1);

  /// Round profile picture: locked square with a circular preview.
  static const avatar = PrismCropSpec(aspect: 1, ratios: [], circle: true);

  /// Wide header image.
  static const banner = PrismCropSpec(
    aspect: 3,
    ratios: [
      PrismCropRatio.banner,
      PrismCropRatio.landscape169,
      PrismCropRatio.landscape32,
      PrismCropRatio.free,
    ],
  );

  /// Full-screen background.
  static const background = PrismCropSpec(
    aspect: 9 / 16,
    ratios: [
      PrismCropRatio.portrait916,
      PrismCropRatio.portrait23,
      PrismCropRatio.square,
      PrismCropRatio.landscape169,
      PrismCropRatio.free,
    ],
  );

  PrismCropSpec withTitle(String t) =>
      PrismCropSpec(aspect: aspect, ratios: ratios, circle: circle, title: t);
}

/// An image the user picked and cropped.
class PrismPickedImage {
  const PrismPickedImage({
    required this.bytes,
    this.originalId,
    this.animated = false,
  });

  /// The cropped result (PNG) — or the untouched file for animated images.
  final Uint8List bytes;

  /// Where the full-quality original is kept, for re-cropping.
  final String? originalId;
  final bool animated;
}

/// The one way Prism lets a person import or change an image.
///
/// Every picker in the app goes through here, so every crop looks, feels and
/// behaves the same (it is the same screen, [showPrismImageCropper]) and the
/// original file is always kept for re-cropping.
abstract final class PrismImageCrop {
  static bool _isAnimated(Uint8List b) {
    if (b.length > 6 && b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46)
      return true; // GIF
    // Animated WebP carries an ANIM chunk near the start.
    if (b.length > 40 &&
        String.fromCharCodes(b.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(b.sublist(8, 12)) == 'WEBP') {
      final head = String.fromCharCodes(
        b.sublist(12, b.length > 64 ? 64 : b.length),
      );
      return head.contains('ANIM');
    }
    return false;
  }

  /// Picks from the gallery/camera/file dialog, then crops.
  static Future<PrismPickedImage?> pick(
    BuildContext context, {
    PrismCropSpec spec = PrismCropSpec.free,
    bool camera = false,
    bool allowCrop = true,
  }) async {
    final platform = defaultTargetPlatform;
    final desktop =
        !kIsWeb &&
        (platform == TargetPlatform.windows ||
            platform == TargetPlatform.linux ||
            platform == TargetPlatform.macOS);
    Uint8List? bytes;
    if (!camera && desktop) {
      final f = await PlatformPrismFileDialogService().pickImageFile();
      bytes = f == null ? null : await f.readAsBytes();
    } else {
      final x = await ImagePicker().pickImage(
        source: camera ? ImageSource.camera : ImageSource.gallery,
      );
      bytes = x == null ? null : await x.readAsBytes();
    }
    if (bytes == null || bytes.isEmpty) return null;
    if (!context.mounted) return null;
    return fromBytes(context, bytes, spec: spec, allowCrop: allowCrop);
  }

  /// Convenience: pick + crop and return just the result bytes.
  static Future<Uint8List?> pickBytes(
    BuildContext context, {
    PrismCropSpec spec = PrismCropSpec.free,
    bool camera = false,
  }) async => (await pick(context, spec: spec, camera: camera))?.bytes;

  /// Crops bytes you already have (and keeps the original).
  static Future<PrismPickedImage?> fromBytes(
    BuildContext context,
    Uint8List bytes, {
    PrismCropSpec spec = PrismCropSpec.free,
    bool allowCrop = true,
    String? originalId,
  }) async {
    // Animated images keep their animation: cropping would flatten them.
    if (_isAnimated(bytes))
      return PrismPickedImage(bytes: bytes, animated: true);
    final normalized = await normalizePickedImageBytes(bytes) ?? bytes;
    if (!context.mounted) return null;
    final String? origId = originalId ?? await PrismOriginals.save(bytes);
    if (!allowCrop)
      return PrismPickedImage(bytes: normalized, originalId: origId);
    if (!context.mounted) return null;
    final out = await _crop(context, normalized, spec);
    if (out == null) {
      // Cancelled: don't keep an original nobody is using.
      if (originalId == null) await PrismOriginals.delete(origId);
      return null;
    }
    return PrismPickedImage(bytes: out, originalId: origId);
  }

  /// Re-crops a previously imported image from its saved original.
  static Future<PrismPickedImage?> recrop(
    BuildContext context,
    String originalId, {
    PrismCropSpec spec = PrismCropSpec.free,
  }) async {
    final bytes = await PrismOriginals.load(originalId);
    if (bytes == null) {
      if (context.mounted) {
        PrismToast.error(
          context,
          message: tr(
            context,
            'The original image isn\'t on this device.',
            'La imagen original no está en este dispositivo.',
          ),
        );
      }
      return null;
    }
    if (!context.mounted) return null;
    return fromBytes(context, bytes, spec: spec, originalId: originalId);
  }

  static Future<Uint8List?> _crop(
    BuildContext context,
    Uint8List bytes,
    PrismCropSpec spec,
  ) async {
    final bmp = await showPrismImageCropper(
      context,
      PrismImageCropRequest(
        sourceBytes: bytes,
        title: spec.title ?? tr(context, 'Crop image', 'Recortar imagen'),
        doneButtonTitle: context.l10n.done,
        cancelButtonTitle: context.l10n.cancel,
        aspectRatio: spec.aspect,
        ratios: spec.ratios,
        circlePreview: spec.circle,
      ),
    );
    if (bmp == null) return null;
    return encodeCroppedBitmapPng(bmp);
  }
}
