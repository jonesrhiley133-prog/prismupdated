import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Keeps the untouched original of every picked image so it can be
/// re-cropped later without importing it again and without losing quality
/// to repeated crop-of-a-crop compression.
///
/// Originals live in the app's private storage (not in synced records, so
/// backups stay small); on web they stay in memory for the session.
///
/// Keeping an original is a convenience: every method here swallows storage
/// errors so a full disk or missing plugin never stops someone importing a
/// picture.
abstract final class PrismOriginals {
  static const _uuid = Uuid();
  static final _memory = <String, Uint8List>{};
  static const prefix = 'orig:';

  static Future<Directory?> _dir() async {
    if (kIsWeb) return null;
    final d = Directory(
      p.join((await getApplicationSupportDirectory()).path, 'prism_originals'),
    );
    await d.create(recursive: true);
    return d;
  }

  /// Saves [bytes] and returns an id like `orig:<uuid>`, or null if storage
  /// isn't available.
  static Future<String?> save(Uint8List bytes) async {
    try {
      final id = '$prefix${_uuid.v4()}';
      final dir = await _dir();
      if (dir == null) {
        _memory[id] = bytes;
      } else {
        await File(
          p.join(dir.path, id.substring(prefix.length)),
        ).writeAsBytes(bytes, flush: true);
      }
      return id;
    } catch (_) {
      return null;
    }
  }

  /// The original's bytes, or null if it isn't on this device.
  static Future<Uint8List?> load(String? id) async {
    if (id == null || !id.startsWith(prefix)) return null;
    try {
      final dir = await _dir();
      if (dir == null) return _memory[id];
      final f = File(p.join(dir.path, id.substring(prefix.length)));
      return await f.exists() ? await f.readAsBytes() : null;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> exists(String? id) async => (await load(id)) != null;

  static Future<void> delete(String? id) async {
    if (id == null || !id.startsWith(prefix)) return;
    try {
      final dir = await _dir();
      if (dir == null) {
        _memory.remove(id);
        return;
      }
      final f = File(p.join(dir.path, id.substring(prefix.length)));
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
