import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:prism_plurality/features/prism_social/social_remote.dart' show remoteSocialImageProvider, serverMediaPrefix;
import 'package:prism_plurality/features/social/models/social.dart';
import 'package:prism_plurality/features/social/services/social_data.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';

const _uuid = Uuid();

/// Largest animated GIF kept as-is (bigger ones become a still image).
const maxGifBytes = 1500 * 1024;

/// Largest video accepted (videos stay on this device).
const maxVideoBytes = 200 * 1024 * 1024;

/// Shrinks an image for syncing: at most 1280 px, JPEG (PNG kept for
/// transparency, small GIFs kept animated). Returns bytes, mime and size.
({Uint8List bytes, String mime, int w, int h})? prepareSocialImage(Uint8List source) {
  final isGif = source.length > 3 && source[0] == 0x47 && source[1] == 0x49 && source[2] == 0x46;
  img.Image? decoded;
  try {
    decoded = isGif ? img.decodeGif(source) : img.decodeImage(source);
  } catch (_) {
    return null;
  }
  if (decoded == null) return null;
  if (isGif && source.length <= maxGifBytes) {
    return (bytes: source, mime: 'image/gif', w: decoded.width, h: decoded.height);
  }
  var image = img.bakeOrientation(decoded);
  const maxSide = 1280;
  if (image.width > maxSide || image.height > maxSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: maxSide, interpolation: img.Interpolation.average)
        : img.copyResize(image, height: maxSide, interpolation: img.Interpolation.average);
  }
  if (image.hasAlpha && image.numChannels == 4) {
    return (bytes: img.encodePng(image, level: 6), mime: 'image/png', w: image.width, h: image.height);
  }
  return (bytes: img.encodeJpg(image, quality: 80), mime: 'image/jpeg', w: image.width, h: image.height);
}

/// Folder for videos (kept on the device they were added on).
final socialVideoDirProvider = FutureProvider<Directory?>((ref) async {
  if (kIsWeb) return null;
  final dir = Directory(p.join((await getApplicationSupportDirectory()).path, 'social_videos'));
  await dir.create(recursive: true);
  return dir;
});

class SocialMediaStore {
  SocialMediaStore(this.ref);
  final Ref ref;

  /// Stores a picked image; returns its media id, or null if unreadable.
  Future<String?> addImage(Uint8List bytes, {String? owner}) async {
    final prepared = await compute(prepareSocialImage, bytes);
    if (prepared == null) return null;
    final r = await ref.read(trackerNotifierProvider.notifier).create(
      kind: SocialKind.media,
      memberId: owner,
      fields: {'mime': prepared.mime, 'w': prepared.w, 'h': prepared.h, 'data': base64Encode(prepared.bytes)},
    );
    return r.id;
  }

  /// Copies a picked video into Prism; returns 'video:<file>' or an error code.
  Future<({String? id, String? error})> addVideo(String path) async {
    final dir = await ref.read(socialVideoDirProvider.future);
    if (dir == null) return (id: null, error: 'unsupported');
    final src = File(path);
    if (!await src.exists()) return (id: null, error: 'missing');
    if (await src.length() > maxVideoBytes) return (id: null, error: 'tooLarge');
    final ext = p.extension(path).toLowerCase();
    if (!const ['.mp4', '.mov', '.m4v', '.webm', '.3gp', '.mkv'].contains(ext)) return (id: null, error: 'format');
    final name = '${_uuid.v4()}$ext';
    await src.copy(p.join(dir.path, name));
    return (id: 'video:$name', error: null);
  }
}

final socialMediaStoreProvider = Provider<SocialMediaStore>(SocialMediaStore.new);

final _decodedCache = <String, Uint8List>{};

/// Image bytes for a media id (null while missing, e.g. not synced yet).
final socialImageProvider = Provider.family<Uint8List?, String>((ref, id) {
  // Prism Social server images.
  if (id.startsWith(serverMediaPrefix)) return ref.watch(remoteSocialImageProvider(id)).value;
  final r = ref.watch(socialDataProvider.select((d) => d.mediaRecords[id]));
  final data = r?.str('data');
  if (data == null) return null;
  final hit = _decodedCache[id];
  if (hit != null) return hit;
  try {
    return _decodedCache[id] = base64Decode(data);
  } on FormatException {
    return null;
  }
});

/// Path of a stored video on this device, or null if it lives elsewhere.
final socialVideoPathProvider = Provider.family<String?, String>((ref, id) {
  if (!id.startsWith('video:')) return null;
  final dir = ref.watch(socialVideoDirProvider).value;
  if (dir == null) return null;
  final path = p.join(dir.path, id.substring(6));
  return File(path).existsSync() ? path : null;
});
