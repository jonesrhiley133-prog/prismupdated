import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/scrapbook/scrap_stickers.dart';
import 'package:prism_plurality/features/social/models/social.dart'
    show SocialKind;
import 'package:prism_plurality/features/social/services/social_media.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();
List<String> _without(List<String> l, String id) => [
  for (final x in l)
    if (x != id) x,
];
const maxRecents = 30;
const maxSvgBytes = 400 * 1024;
const maxPackStickers = 60;
const maxPackBytes = 6 * 1024 * 1024;

class CustomSticker {
  const CustomSticker({
    required this.id,
    required this.name,
    required this.media,
  });
  final String id, name, media;
  Map<String, Object?> toJson() => {'id': id, 'n': name, 'm': media};
  static CustomSticker? fromJson(Object? j) {
    if (j is! Map || j['id'] is! String || j['m'] is! String) return null;
    return CustomSticker(
      id: j['id'] as String,
      name: (j['n'] as String?) ?? 'Sticker',
      media: j['m'] as String,
    );
  }
}

class StickerCollection {
  const StickerCollection({
    required this.id,
    required this.name,
    this.items = const [],
  });
  final String id, name;
  final List<String> items;
  StickerCollection copyWith({String? name, List<String>? items}) =>
      StickerCollection(
        id: id,
        name: name ?? this.name,
        items: items ?? this.items,
      );
  Map<String, Object?> toJson() => {'id': id, 'n': name, 'i': items};
  static StickerCollection? fromJson(Object? j) {
    if (j is! Map || j['id'] is! String) return null;
    return StickerCollection(
      id: j['id'] as String,
      name: (j['n'] as String?) ?? 'Collection',
      items: [
        for (final x in (j['i'] is List ? j['i'] as List : const []))
          if (x is String) x,
      ],
    );
  }
}

class StickerLibrary {
  const StickerLibrary({
    this.favorites = const [],
    this.recents = const [],
    this.collections = const [],
    this.custom = const [],
  });
  final List<String> favorites, recents;
  final List<StickerCollection> collections;
  final List<CustomSticker> custom;

  bool isFavorite(String id) => favorites.contains(id);
  CustomSticker? customById(String id) {
    for (final c in custom) {
      if (c.id == id) return c;
    }
    return null;
  }

  StickerLibrary copyWith({
    List<String>? favorites,
    List<String>? recents,
    List<StickerCollection>? collections,
    List<CustomSticker>? custom,
  }) => StickerLibrary(
    favorites: favorites ?? this.favorites,
    recents: recents ?? this.recents,
    collections: collections ?? this.collections,
    custom: custom ?? this.custom,
  );

  Map<String, Object?> toJson() => {
    'f': favorites,
    'r': recents,
    'c': [for (final c in collections) c.toJson()],
    'u': [for (final c in custom) c.toJson()],
  };

  static StickerLibrary fromJson(Map<String, Object?> j) {
    List<String> strs(Object? v) => [
      for (final x in (v is List ? v : const []))
        if (x is String) x,
    ];
    return StickerLibrary(
      favorites: strs(j['f']),
      recents: strs(j['r']),
      collections: [
        for (final x in (j['c'] is List ? j['c'] as List : const []))
          ?StickerCollection.fromJson(x),
      ],
      custom: [
        for (final x in (j['u'] is List ? j['u'] as List : const []))
          ?CustomSticker.fromJson(x),
      ],
    );
  }
}

// ── Import ───────────────────────────────────────────────────────────────

/// Why an import was refused (shown to the person, never a silent skip).
enum StickerImportError { empty, tooBig, unsupported, unreadable }

typedef PreparedSticker = ({Uint8List bytes, String mime});

bool _startsWith(Uint8List b, List<int> sig, [int at = 0]) {
  if (b.length < at + sig.length) return false;
  for (var i = 0; i < sig.length; i++) {
    if (b[at + i] != sig[i]) return false;
  }
  return true;
}

bool looksLikeSvg(Uint8List b) {
  final head = utf8
      .decode(b.length > 2048 ? b.sublist(0, 2048) : b, allowMalformed: true)
      .toLowerCase();
  return head.contains('<svg');
}

/// Removes anything active from an SVG: scripts, event handlers, external
/// references and embedded foreign content.
String sanitizeSvg(String svg) {
  var s = svg;
  s = s.replaceAll(
    RegExp(r'<script[\s\S]*?</script\s*>', caseSensitive: false),
    '',
  );
  s = s.replaceAll(RegExp(r'<script[^>]*/>', caseSensitive: false), '');
  s = s.replaceAll(
    RegExp(r'<foreignObject[\s\S]*?</foreignObject\s*>', caseSensitive: false),
    '',
  );
  s = s.replaceAll(RegExp(r'<!ENTITY[^>]*>', caseSensitive: false), '');
  s = s.replaceAll(
    RegExp(r'''\son\w+\s*=\s*("[^"]*"|'[^']*')''', caseSensitive: false),
    '',
  );
  s = s.replaceAll(
    RegExp(
      r'''(href|src)\s*=\s*("\s*(https?:|javascript:|file:)[^"]*"|'\s*(https?:|javascript:|file:)[^']*')''',
      caseSensitive: false,
    ),
    '',
  );
  s = s.replaceAll(
    RegExp(
      r'''url\(\s*['"]?\s*(https?:|javascript:|file:)[^)]*\)''',
      caseSensitive: false,
    ),
    'none',
  );
  return s;
}

/// Checks and normalises a picked file into something safe to store.
/// PNG keeps its transparency, GIF stays animated, WebP/JPEG become PNG/JPEG
/// (animated WebP keeps its first frame), SVG is cleaned.
({PreparedSticker? ok, StickerImportError? error}) prepareStickerFile(
  Uint8List bytes, {
  int maxBytes = 8 * 1024 * 1024,
}) {
  if (bytes.isEmpty) return (ok: null, error: StickerImportError.empty);
  if (bytes.length > maxBytes)
    return (ok: null, error: StickerImportError.tooBig);
  final isPng = _startsWith(bytes, const [0x89, 0x50, 0x4E, 0x47]);
  final isGif = _startsWith(bytes, const [0x47, 0x49, 0x46]);
  final isWebp =
      _startsWith(bytes, const [0x52, 0x49, 0x46, 0x46]) &&
      _startsWith(bytes, const [0x57, 0x45, 0x42, 0x50], 8);
  final isJpg = _startsWith(bytes, const [0xFF, 0xD8, 0xFF]);
  if (isPng || isGif || isWebp || isJpg) {
    final p = prepareSocialImage(bytes);
    if (p == null) return (ok: null, error: StickerImportError.unreadable);
    return (ok: (bytes: p.bytes, mime: p.mime), error: null);
  }
  if (looksLikeSvg(bytes)) {
    if (bytes.length > maxSvgBytes)
      return (ok: null, error: StickerImportError.tooBig);
    final clean = sanitizeSvg(utf8.decode(bytes, allowMalformed: true));
    return (
      ok: (
        bytes: Uint8List.fromList(utf8.encode(clean)),
        mime: 'image/svg+xml',
      ),
      error: null,
    );
  }
  return (ok: null, error: StickerImportError.unsupported);
}

/// A shareable pack: `{prismStickers:1, name, stickers:[{n, d}]}`. Files are
/// re-checked on import, so a pack can never carry anything active.
String exportStickerPack(
  String name,
  List<({String name, Uint8List bytes})> files,
) => jsonEncode({
  'prismStickers': 1,
  'name': name,
  'stickers': [
    for (final f in files) {'n': f.name, 'd': base64Encode(f.bytes)},
  ],
});

({
  String name,
  List<({String name, PreparedSticker file})> stickers,
  int skipped,
})?
parseStickerPack(String json) {
  if (json.length > maxPackBytes * 2) return null;
  Object? j;
  try {
    j = jsonDecode(json);
  } catch (_) {
    return null;
  }
  if (j is! Map || j['prismStickers'] != 1 || j['stickers'] is! List)
    return null;
  final out = <({String name, PreparedSticker file})>[];
  var skipped = 0, total = 0;
  for (final s in (j['stickers'] as List).take(maxPackStickers)) {
    if (s is! Map || s['d'] is! String) {
      skipped++;
      continue;
    }
    Uint8List b;
    try {
      b = base64Decode(s['d'] as String);
    } catch (_) {
      skipped++;
      continue;
    }
    total += b.length;
    if (total > maxPackBytes) {
      skipped++;
      continue;
    }
    final r = prepareStickerFile(b);
    if (r.ok == null) {
      skipped++;
      continue;
    }
    out.add((
      name: ((s['n'] as String?) ?? 'Sticker').trim().isEmpty
          ? 'Sticker'
          : (s['n'] as String).trim(),
      file: r.ok!,
    ));
  }
  if (out.isEmpty) return null;
  return (
    name: ((j['name'] as String?) ?? 'Sticker pack'),
    stickers: out,
    skipped:
        skipped +
        (((j['stickers'] as List).length > maxPackStickers)
            ? (j['stickers'] as List).length - maxPackStickers
            : 0),
  );
}

// ── Saved library ────────────────────────────────────────────────────────

class StickerLibraryNotifier extends Notifier<StickerLibrary> {
  Timer? _debounce;
  StickerLibrary? _pending;

  @override
  StickerLibrary build() {
    ref.onDispose(() => _debounce?.cancel());
    final rec =
        (ref.watch(trackerKindProvider(TrackerKind.scrapStickers)).value ??
                const <TrackerRecord>[])
            .firstOrNull;
    return _pending ??
        (rec == null
            ? const StickerLibrary()
            : StickerLibrary.fromJson(rec.fields));
  }

  void update(StickerLibrary Function(StickerLibrary l) change) {
    final next = change(state);
    _pending = next;
    state = next;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), flush);
  }

  Future<void> flush() async {
    _debounce?.cancel();
    final p = _pending;
    if (p == null) return;
    final t = ref.read(trackerNotifierProvider.notifier);
    final rec =
        (ref.read(trackerKindProvider(TrackerKind.scrapStickers)).value ??
                const <TrackerRecord>[])
            .firstOrNull;
    if (rec == null) {
      await t.create(
        kind: TrackerKind.scrapStickers,
        title: 'Sticker library',
        fields: p.toJson(),
      );
    } else {
      await t.save(rec.withFields(p.toJson()));
    }
    if (identical(_pending, p)) _pending = null;
  }

  void toggleFavorite(String id) => update(
    (l) => l.copyWith(
      favorites: l.isFavorite(id)
          ? _without(l.favorites, id)
          : [id, ...l.favorites],
    ),
  );

  void used(String id) => update(
    (l) => l.copyWith(
      recents: [
        id,
        ...l.recents.where((x) => x != id),
      ].take(maxRecents).toList(),
    ),
  );

  void clearRecents() => update((l) => l.copyWith(recents: const []));

  String addCollection(String name) {
    final c = StickerCollection(
      id: _uuid.v4(),
      name: name.trim().isEmpty ? 'Collection' : name.trim(),
    );
    update((l) => l.copyWith(collections: [...l.collections, c]));
    return c.id;
  }

  void renameCollection(String id, String name) => update(
    (l) => l.copyWith(
      collections: [
        for (final c in l.collections)
          c.id == id
              ? c.copyWith(name: name.trim().isEmpty ? c.name : name.trim())
              : c,
      ],
    ),
  );

  void deleteCollection(String id) => update(
    (l) => l.copyWith(
      collections: [
        for (final c in l.collections)
          if (c.id != id) c,
      ],
    ),
  );

  void toggleInCollection(String collectionId, String stickerId) => update(
    (l) => l.copyWith(
      collections: [
        for (final c in l.collections)
          if (c.id == collectionId)
            c.copyWith(
              items: c.items.contains(stickerId)
                  ? _without(c.items, stickerId)
                  : [...c.items, stickerId],
            )
          else
            c,
      ],
    ),
  );

  /// Stores [file] as a media record and adds it to the custom stickers.
  Future<String> addCustom(String name, PreparedSticker file) async {
    final r = await ref
        .read(trackerNotifierProvider.notifier)
        .create(
          kind: SocialKind.media,
          fields: {
            'mime': file.mime,
            'data': base64Encode(file.bytes),
            'w': 0,
            'h': 0,
          },
        );
    final id = 'c:${_uuid.v4()}';
    update(
      (l) => l.copyWith(
        custom: [
          ...l.custom,
          CustomSticker(id: id, name: name, media: r.id),
        ],
      ),
    );
    return id;
  }

  void removeCustom(String id) => update(
    (l) => l.copyWith(
      custom: [
        for (final c in l.custom)
          if (c.id != id) c,
      ],
      favorites: _without(l.favorites, id),
      recents: _without(l.recents, id),
      collections: [
        for (final c in l.collections) c.copyWith(items: _without(c.items, id)),
      ],
    ),
  );
}

final stickerLibraryProvider =
    NotifierProvider<StickerLibraryNotifier, StickerLibrary>(
      StickerLibraryNotifier.new,
    );

/// Resolves a favorite/recent/collection entry to something drawable:
/// a built-in sticker, a custom one, or null if it has been deleted.
({ScrapSticker? builtIn, CustomSticker? custom}) resolveSticker(
  StickerLibrary l,
  String id,
) => (builtIn: scrapStickerById(id), custom: l.customById(id));

@visibleForTesting
String debugSanitize(String s) => sanitizeSvg(s);
