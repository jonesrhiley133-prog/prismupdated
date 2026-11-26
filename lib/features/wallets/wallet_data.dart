import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:prism_plurality/features/wallets/id_templates.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Every exported card carries this designation. Wallet ID cards are
/// personal and fictional — never real identity documents.
const fictionalIdNotice =
    'Prism — Personal / Fictional ID · Not an official document';

/// Kinds of ID card. All are playful or personal: there are deliberately
/// no government-style templates (licences, passports, national IDs).
const idCardTypes = <String, (String, String)>{
  'member': ('Member ID', '🪪'),
  'library': ('Library card', '📚'),
  'student': ('Student card', '🎓'),
  'club': ('Club membership', '🎟️'),
  'fan': ('Fan club card', '⭐'),
  'gym': ('Gym pass', '🏋️'),
  'loyalty': ('Loyalty card', '☕'),
  'travel': ('Travel pass', '🚆'),
  'guild': ('Adventurer\'s guild card', '🗡️'),
  'wizard': ('Wizarding academy card', '🪄'),
  'pilot': ('Starship crew badge', '🚀'),
  'explorer': ('Explorer badge', '🧭'),
  'staff': ('Staff badge', '🏷️'),
  'concert': ('Concert pass', '🎤'),
  'backstage': ('Backstage pass', '🎸'),
  'pet': ('Companion tag', '🐾'),
  'emergency': ('Emergency info card', '🆘'),
  'pronoun': ('Pronoun card', '💬'),
  'business': ('Business card', '💼'),
  'access': ('Accessibility card', '♿'),
};

/// Fields a card can show (picked per card).
const idFields = <String, String>{
  'name': 'Name',
  'pronouns': 'Pronouns',
  'role': 'Role',
  'age': 'Age',
  'birthday': 'Birthday',
  'number': 'Card number',
  'photo': 'Photo / avatar',
  'signature': 'Signature',
  'issued': 'Issued',
  'expires': 'Valid until',
  'system': 'System name',
  'issuer': 'Issued by',
  'notes': 'Notes',
  'emoji': 'Emblem',
  'barcode': 'Decorative barcode',
  'custom1': 'Custom field 1',
  'custom2': 'Custom field 2',
  'status': 'Status',
  'flags': 'Flags',
  'boundaries': 'Boundaries',
  'interests': 'Interests',
  'custom3': 'Custom field 3',
};

/// One thing drawn on a card face. Positions and sizes are 0–1 of the card.
@immutable
class CardLayer {
  const CardLayer({
    required this.id,
    required this.kind,
    this.x = 0.5,
    this.y = 0.5,
    this.w = 0.3,
    this.h = 0.12,
    this.rotation = 0,
    this.color = 0xFF222222,
    this.size = 0.06,
    this.text = '',
    this.field,
    this.align = 'left',
    this.bold = false,
    this.font = 'standard',
    this.opacity = 1,
    this.locked = false,
    this.color2,
    this.stroke = 0,
  });

  final String id;

  /// text, field, emoji, shape, photo, barcode, circle, line
  final String kind;
  final double x, y, w, h, rotation, size, opacity;
  final int color;
  final String text;
  final String? field;
  final String align;
  final bool bold;
  final String font;
  final bool locked;

  /// Second colour: makes shapes a diagonal gradient from [color] to it.
  final int? color2;

  /// Outline width as a fraction of the shorter side; 0 fills the shape.
  final double stroke;

  CardLayer copyWith({
    double? x,
    double? y,
    double? w,
    double? h,
    double? rotation,
    int? color,
    double? size,
    String? text,
    String? field,
    String? align,
    bool? bold,
    String? font,
    double? opacity,
    bool? locked,
    String? id,
    Object? color2 = _keep,
    double? stroke,
  }) => CardLayer(
    id: id ?? this.id,
    kind: kind,
    x: x ?? this.x,
    y: y ?? this.y,
    w: w ?? this.w,
    h: h ?? this.h,
    rotation: rotation ?? this.rotation,
    color: color ?? this.color,
    size: size ?? this.size,
    text: text ?? this.text,
    field: field ?? this.field,
    align: align ?? this.align,
    bold: bold ?? this.bold,
    font: font ?? this.font,
    opacity: opacity ?? this.opacity,
    locked: locked ?? this.locked,
    color2: identical(color2, _keep) ? this.color2 : color2 as int?,
    stroke: stroke ?? this.stroke,
  );

  static const _keep = Object();

  Map<String, Object?> toJson() => {
    'id': id,
    'k': kind,
    'x': x,
    'y': y,
    'w': w,
    'h': h,
    'r': rotation,
    'c': color,
    's': size,
    't': text,
    'f': field,
    'a': align,
    'b': bold,
    'fo': font,
    'o': opacity,
    'l': locked,
    'c2': ?color2,
    if (stroke != 0) 'sw': stroke,
  };

  static CardLayer fromJson(Map j) {
    double d(String k, double def) => (j[k] as num?)?.toDouble() ?? def;
    return CardLayer(
      id: '${j['id']}',
      kind: '${j['k'] ?? 'text'}',
      x: d('x', 0.5),
      y: d('y', 0.5),
      w: d('w', 0.3),
      h: d('h', 0.12),
      rotation: d('r', 0),
      color: (j['c'] as num?)?.toInt() ?? 0xFF222222,
      size: d('s', 0.06),
      text: '${j['t'] ?? ''}',
      field: j['f'] as String?,
      align: '${j['a'] ?? 'left'}',
      bold: j['b'] == true,
      font: '${j['fo'] ?? 'standard'}',
      opacity: d('o', 1),
      locked: j['l'] == true,
      color2: (j['c2'] as num?)?.toInt(),
      stroke: d('sw', 0),
    );
  }
}

/// A card face: background plus layers.
@immutable
class CardFace {
  const CardFace({
    this.bg1 = 0xFFF5F2EA,
    this.bg2 = 0xFFE4DDCF,
    this.pattern = 'none',
    this.layers = const [],
    this.tpl = '',
    this.aspect = 0,
  });
  final int bg1, bg2;

  /// Id of the template this face was built from ('' = hand-made or legacy).
  /// Kept on the face so undo, saving and restarting all keep the selection.
  final String tpl;

  /// Card shape (width ÷ height) this face was designed for; 0 = the
  /// card's own setting. Kept on the face so undo restores it too.
  final double aspect;

  /// none, dots, stripes, waves, stars, grid, holo, guilloche
  final String pattern;
  final List<CardLayer> layers;

  CardFace copyWith({
    int? bg1,
    int? bg2,
    String? pattern,
    List<CardLayer>? layers,
    String? tpl,
    double? aspect,
  }) => CardFace(
    bg1: bg1 ?? this.bg1,
    bg2: bg2 ?? this.bg2,
    pattern: pattern ?? this.pattern,
    layers: layers ?? this.layers,
    tpl: tpl ?? this.tpl,
    aspect: aspect ?? this.aspect,
  );

  Map<String, Object?> toJson() => {
    'bg1': bg1,
    'bg2': bg2,
    'p': pattern,
    if (tpl.isNotEmpty) 'tpl': tpl,
    if (aspect > 0) 'ar': aspect,
    'layers': [for (final l in layers) l.toJson()],
  };
  static CardFace fromJson(Object? raw) {
    final j = raw is Map ? raw : const {};
    return CardFace(
      bg1: (j['bg1'] as num?)?.toInt() ?? 0xFFF5F2EA,
      bg2: (j['bg2'] as num?)?.toInt() ?? 0xFFE4DDCF,
      pattern: '${j['p'] ?? 'none'}',
      tpl: '${j['tpl'] ?? ''}',
      aspect: (j['ar'] as num?)?.toDouble() ?? 0,
      layers: [
        for (final l in (j['layers'] as List? ?? const []))
          if (l is Map) CardLayer.fromJson(l),
      ],
    );
  }
}

/// A template collection: a palette and a mood, used with any layout.
class TemplateCollection {
  const TemplateCollection(
    this.id,
    this.name,
    this.bg1,
    this.bg2,
    this.ink,
    this.accent,
    this.pattern, {
    this.font = 'standard',
  });
  final String id, name;
  final int bg1, bg2, ink, accent;
  final String pattern;
  final String font;
}

const templateCollections = <TemplateCollection>[
  TemplateCollection(
    'classic',
    'Classic',
    0xFFF5F2EA,
    0xFFE4DDCF,
    0xFF2B2A28,
    0xFF2F5D8A,
    'guilloche',
    font: 'serif',
  ),
  TemplateCollection(
    'minimal',
    'Minimal',
    0xFFFFFFFF,
    0xFFF2F2F2,
    0xFF1C1C1E,
    0xFF5B5BD6,
    'none',
  ),
  TemplateCollection(
    'holo',
    'Holographic',
    0xFFE3F2FF,
    0xFFF8E3FF,
    0xFF2A2440,
    0xFF8E6CF0,
    'holo',
  ),
  TemplateCollection(
    'retro',
    'Retro',
    0xFFFFE8B8,
    0xFFFFB86B,
    0xFF3A1F5C,
    0xFFE8462F,
    'stripes',
    font: 'mono',
  ),
  TemplateCollection(
    'kawaii',
    'Kawaii',
    0xFFFFE3F0,
    0xFFFFF4C9,
    0xFF5A3D5C,
    0xFFFF7AB6,
    'dots',
    font: 'rounded',
  ),
  TemplateCollection(
    'celestial',
    'Celestial',
    0xFF141A3D,
    0xFF3B2C6E,
    0xFFF4F1FF,
    0xFFFFD66B,
    'stars',
    font: 'serif',
  ),
  TemplateCollection(
    'cyber',
    'Cyberpunk',
    0xFF0D0F1A,
    0xFF1F1240,
    0xFF7DF9FF,
    0xFFFF2E97,
    'grid',
    font: 'mono',
  ),
  TemplateCollection(
    'guild',
    'Fantasy guild',
    0xFFF1E3C4,
    0xFFD9BF8C,
    0xFF3E2A14,
    0xFF8C2F2F,
    'guilloche',
    font: 'serif',
  ),
  TemplateCollection(
    'scrapbook',
    'Scrapbook',
    0xFFF4EBDD,
    0xFFEADBC4,
    0xFF3E2C1C,
    0xFFE0607E,
    'dots',
  ),
  TemplateCollection(
    'nature',
    'Nature',
    0xFFE8F3DF,
    0xFFC9E2B3,
    0xFF23401F,
    0xFF4E8A3E,
    'waves',
  ),
  TemplateCollection(
    'ocean',
    'Ocean',
    0xFFD9F1FF,
    0xFF8FD3F2,
    0xFF0F3550,
    0xFF1F7FBF,
    'waves',
  ),
  TemplateCollection(
    'pastel',
    'Pastel',
    0xFFFFF0F5,
    0xFFE3F0FF,
    0xFF3D3550,
    0xFFB57EDC,
    'none',
    font: 'rounded',
  ),
  TemplateCollection(
    'mono',
    'Monochrome',
    0xFF2B2B2E,
    0xFF111113,
    0xFFF2F2F2,
    0xFFBDBDBD,
    'stripes',
  ),
  TemplateCollection(
    'neon',
    'Neon',
    0xFF120024,
    0xFF2A004F,
    0xFFFFFFFF,
    0xFF39FF14,
    'grid',
    font: 'mono',
  ),
];

/// Layout variants that every collection comes in.
const templateLayouts = <String, String>{
  'badge': 'Photo left',
  'centered': 'Centered',
  'banner': 'Top banner',
};

/// Ids of layers generated by a template start with `t`, so switching
/// templates can tell them apart from layers the user added themselves.
String _tid() => 't${_uid()}';

/// A fresh id for a template-generated layer (starts with `t`).
String templateLayerId() => _tid();

String _uid() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${math.Random().nextInt(1 << 20).toRadixString(36)}';

/// Builds the front and back of a card for [collection] + [layout].
(CardFace, CardFace) buildTemplate(
  String collectionId,
  String layout, {
  required String type,
  Set<String> fields = const {
    'name',
    'pronouns',
    'number',
    'photo',
    'issued',
    'emoji',
  },
}) {
  final c = templateCollections.firstWhere(
    (x) => x.id == collectionId,
    orElse: () => templateCollections.first,
  );
  final title = idCardTypes[type]?.$1 ?? 'ID card';
  final layers = <CardLayer>[];
  CardLayer t(
    String text,
    double x,
    double y, {
    double size = 0.055,
    bool bold = false,
    String align = 'left',
    int? color,
    double w = 0.5,
  }) => CardLayer(
    id: _tid(),
    kind: 'text',
    text: text,
    x: x,
    y: y,
    w: w,
    size: size,
    bold: bold,
    align: align,
    color: color ?? c.ink,
    font: c.font,
  );
  CardLayer f(
    String field,
    double x,
    double y, {
    double size = 0.05,
    bool bold = false,
    String align = 'left',
    double w = 0.5,
  }) => CardLayer(
    id: _tid(),
    kind: 'field',
    field: field,
    x: x,
    y: y,
    w: w,
    size: size,
    bold: bold,
    align: align,
    color: c.ink,
    font: c.font,
  );
  switch (layout) {
    case 'centered':
      layers.add(
        t(
          title.toUpperCase(),
          0.5,
          0.12,
          size: 0.05,
          bold: true,
          align: 'center',
          color: c.accent,
          w: 0.9,
        ),
      );
      if (fields.contains('photo'))
        layers.add(
          CardLayer(
            id: _tid(),
            kind: 'photo',
            x: 0.5,
            y: 0.42,
            w: 0.22,
            h: 0.35,
            color: c.accent,
          ),
        );
      final order = [
        'name',
        'pronouns',
        'role',
        'number',
      ].where(fields.contains).toList();
      for (final (i, k) in order.indexed) {
        layers.add(
          f(
            k,
            0.5,
            0.68 + i * 0.08,
            size: i == 0 ? 0.07 : 0.045,
            bold: i == 0,
            align: 'center',
            w: 0.8,
          ),
        );
      }
    case 'banner':
      layers.add(
        CardLayer(
          id: _tid(),
          kind: 'shape',
          x: 0.5,
          y: 0.1,
          w: 1,
          h: 0.2,
          color: c.accent,
        ),
      );
      layers.add(
        t(
          title.toUpperCase(),
          0.06,
          0.1,
          size: 0.05,
          bold: true,
          color: c.bg1,
          w: 0.8,
        ),
      );
      if (fields.contains('photo'))
        layers.add(
          CardLayer(
            id: _tid(),
            kind: 'photo',
            x: 0.82,
            y: 0.52,
            w: 0.24,
            h: 0.42,
            color: c.accent,
          ),
        );
      final order = [
        'name',
        'pronouns',
        'role',
        'birthday',
        'number',
        'issued',
        'expires',
      ].where(fields.contains).toList();
      for (final (i, k) in order.indexed) {
        layers.add(
          f(
            k,
            0.06,
            0.32 + i * 0.1,
            size: i == 0 ? 0.07 : 0.045,
            bold: i == 0,
            w: 0.6,
          ),
        );
      }
    default: // badge
      if (fields.contains('photo'))
        layers.add(
          CardLayer(
            id: _tid(),
            kind: 'photo',
            x: 0.2,
            y: 0.52,
            w: 0.26,
            h: 0.5,
            color: c.accent,
          ),
        );
      layers.add(
        t(
          title.toUpperCase(),
          0.38,
          0.12,
          size: 0.05,
          bold: true,
          color: c.accent,
          w: 0.6,
        ),
      );
      final order = [
        'name',
        'pronouns',
        'role',
        'birthday',
        'number',
        'issued',
        'expires',
      ].where(fields.contains).toList();
      for (final (i, k) in order.indexed) {
        layers.add(
          f(
            k,
            0.38,
            0.28 + i * 0.1,
            size: i == 0 ? 0.07 : 0.045,
            bold: i == 0,
            w: 0.58,
          ),
        );
      }
  }
  if (fields.contains('emoji'))
    layers.add(
      CardLayer(
        id: _tid(),
        kind: 'field',
        field: 'emoji',
        x: 0.9,
        y: 0.14,
        w: 0.12,
        size: 0.1,
        align: 'center',
      ),
    );
  if (fields.contains('signature'))
    layers.add(
      CardLayer(
        id: _tid(),
        kind: 'field',
        field: 'signature',
        x: 0.6,
        y: 0.9,
        w: 0.36,
        size: 0.06,
        font: 'script',
        color: c.ink,
      ),
    );
  final front = CardFace(
    bg1: c.bg1,
    bg2: c.bg2,
    pattern: c.pattern,
    layers: layers,
    tpl: '${c.id}.$layout',
  );
  final back = CardFace(
    bg1: c.bg2,
    bg2: c.bg1,
    pattern: c.pattern,
    tpl: '${c.id}.$layout',
    layers: [
      t(
        'If found, please return to its owner. 💛',
        0.5,
        0.18,
        size: 0.045,
        align: 'center',
        w: 0.9,
      ),
      if (fields.contains('notes'))
        f('notes', 0.08, 0.38, size: 0.045, w: 0.84),
      if (fields.contains('issuer'))
        f('issuer', 0.08, 0.62, size: 0.04, w: 0.84),
      CardLayer(
        id: _tid(),
        kind: 'barcode',
        x: 0.5,
        y: 0.8,
        w: 0.7,
        h: 0.14,
        color: c.ink,
      ),
      t(
        'Personal / fictional — not an official document',
        0.5,
        0.94,
        size: 0.03,
        align: 'center',
        w: 0.9,
      ),
    ],
  );
  return (front, back);
}

/// An ID card record.
class IdCard {
  IdCard(this.r);
  final TrackerRecord r;
  String get id => r.id;
  String get title =>
      r.title.isEmpty ? (idCardTypes[type]?.$1 ?? 'ID card') : r.title;
  String get type => '${r.fields['type'] ?? 'member'}';
  String? get memberId => r.memberId;
  String get collection => '${r.fields['collection'] ?? 'classic'}';
  String get layout => '${r.fields['layout'] ?? 'badge'}';

  /// Width ÷ height of the card. Landscape by default; templates and the
  /// designer can make it portrait, square or any custom shape.
  double get aspect {
    final fa = front.aspect;
    if (fa >= 0.4 && fa <= 3) return fa;
    final a = (r.fields['aspect'] as num?)?.toDouble();
    return a == null || a < 0.4 || a > 3 ? 1.585 : a;
  }

  CardFace get front => CardFace.fromJson(r.fields['front']);
  CardFace get back => CardFace.fromJson(r.fields['back']);
  Map<String, String> get values => {
    for (final e in ((r.fields['values'] as Map?) ?? const {}).entries)
      '${e.key}': '${e.value ?? ''}',
  };
  String get number => '${r.fields['number'] ?? ''}';
  DateTime get issued =>
      DateTime.tryParse('${r.fields['issued'] ?? ''}') ?? r.createdAt;
}

/// One entry in a wallet.
@immutable
class WalletItem {
  const WalletItem({
    required this.ref,
    this.folder = '',
    this.pinned = false,
    this.favorite = false,
    this.archived = false,
  });

  /// card:<id>, intro:<id>, pass:<id>
  final String ref;
  final String folder;
  final bool pinned, favorite, archived;
  String get kind => ref.split(':').first;
  String get targetId => ref.substring(ref.indexOf(':') + 1);

  WalletItem copyWith({
    String? folder,
    bool? pinned,
    bool? favorite,
    bool? archived,
  }) => WalletItem(
    ref: ref,
    folder: folder ?? this.folder,
    pinned: pinned ?? this.pinned,
    favorite: favorite ?? this.favorite,
    archived: archived ?? this.archived,
  );
  Map<String, Object?> toJson() => {
    'ref': ref,
    'folder': folder,
    'pin': pinned,
    'fav': favorite,
    'arch': archived,
  };
  static WalletItem fromJson(Map j) => WalletItem(
    ref: '${j['ref']}',
    folder: '${j['folder'] ?? ''}',
    pinned: j['pin'] == true,
    favorite: j['fav'] == true,
    archived: j['arch'] == true,
  );
}

class Wallet {
  Wallet(this.r);
  final TrackerRecord r;
  String get id => r.id;
  String get name => r.title.isEmpty ? 'Wallet' : r.title;
  String? get ownerId => r.memberId;
  int get color => (r.fields['color'] as num?)?.toInt() ?? 0xFF7A5C3E;
  String get emoji => '${r.fields['emoji'] ?? '👛'}';
  List<WalletItem> get items => [
    for (final i in (r.fields['items'] as List? ?? const []))
      if (i is Map) WalletItem.fromJson(i),
  ];
  String? get primaryCard => r.fields['primary'] as String?;
  List<String> get folders => {
    for (final i in items)
      if (i.folder.isNotEmpty) i.folder,
  }.toList()..sort();
}

/// System-wide identity used on cards ("Issued by", system name, numbers).
@immutable
class SystemIdentity {
  const SystemIdentity({
    this.systemName = '',
    this.issuer = 'The Prism Collective',
    this.emblem = '✨',
    this.prefix = 'PRM',
    this.collection = 'classic',
    this.accent = 0xFF2F5D8A,
  });
  final String systemName, issuer, emblem, prefix, collection;
  final int accent;

  SystemIdentity copyWith({
    String? systemName,
    String? issuer,
    String? emblem,
    String? prefix,
    String? collection,
    int? accent,
  }) => SystemIdentity(
    systemName: systemName ?? this.systemName,
    issuer: issuer ?? this.issuer,
    emblem: emblem ?? this.emblem,
    prefix: prefix ?? this.prefix,
    collection: collection ?? this.collection,
    accent: accent ?? this.accent,
  );
  Map<String, Object?> toJson() => {
    'systemName': systemName,
    'issuer': issuer,
    'emblem': emblem,
    'prefix': prefix,
    'collection': collection,
    'accent': accent,
  };
  static SystemIdentity fromJson(Object? raw) {
    final j = raw is Map ? raw : const {};
    return SystemIdentity(
      systemName: '${j['systemName'] ?? ''}',
      issuer: '${j['issuer'] ?? 'The Prism Collective'}',
      emblem: '${j['emblem'] ?? '✨'}',
      prefix: '${j['prefix'] ?? 'PRM'}',
      collection: templateCollections.any((c) => c.id == j['collection'])
          ? j['collection'] as String
          : 'classic',
      accent: (j['accent'] as num?)?.toInt() ?? 0xFF2F5D8A,
    );
  }
}

// ── Providers ────────────────────────────────────────────────────────────

final walletsProvider = Provider<List<Wallet>>(
  (ref) => [
    for (final r
        in ref.watch(trackerKindProvider(TrackerKind.wallet)).value ??
            const <TrackerRecord>[])
      Wallet(r),
  ]..sort((a, b) => a.r.createdAt.compareTo(b.r.createdAt)),
);
final walletByIdProvider = Provider.family<Wallet?, String>(
  (ref, id) => ref.watch(walletsProvider).where((w) => w.id == id).firstOrNull,
);
final idCardsProvider = Provider<List<IdCard>>(
  (ref) => [
    for (final r
        in ref.watch(trackerKindProvider(TrackerKind.walletCard)).value ??
            const <TrackerRecord>[])
      IdCard(r),
  ],
);
final idCardByIdProvider = Provider.family<IdCard?, String>(
  (ref, id) => ref.watch(idCardsProvider).where((c) => c.id == id).firstOrNull,
);
final systemIdentityRecordProvider = Provider<TrackerRecord?>(
  (ref) =>
      (ref.watch(trackerKindProvider(TrackerKind.walletIdentity)).value ??
              const <TrackerRecord>[])
          .firstOrNull,
);
final systemIdentityProvider = Provider<SystemIdentity>(
  (ref) => SystemIdentity.fromJson(
    ref.watch(systemIdentityRecordProvider)?.fields['identity'],
  ),
);

/// The card shown on a headmate's profile.
final primaryIdCardProvider = Provider.family<IdCard?, String>((ref, memberId) {
  for (final w in ref.watch(walletsProvider)) {
    if (w.ownerId != memberId || w.primaryCard == null) continue;
    final c = ref.watch(idCardByIdProvider(w.primaryCard!));
    if (c != null) return c;
  }
  return null;
});

class WalletActions {
  WalletActions(this.ref);
  final Ref ref;
  TrackerNotifier get _t => ref.read(trackerNotifierProvider.notifier);

  Future<TrackerRecord> createWallet({
    required String name,
    String? ownerId,
    int color = 0xFF7A5C3E,
    String emoji = '👛',
  }) => _t.create(
    kind: TrackerKind.wallet,
    title: name.trim(),
    memberId: ownerId,
    fields: {'color': color, 'emoji': emoji, 'items': const []},
  );

  Future<void> saveWallet(
    Wallet w, {
    String? name,
    int? color,
    String? emoji,
    List<WalletItem>? items,
    String? primary,
    bool clearPrimary = false,
  }) => _t.save(
    w.r.copyWith(title: name ?? w.r.title).withFields({
      ...w.r.fields,
      'color': ?color,
      'emoji': ?emoji,
      if (items != null) 'items': [for (final i in items) i.toJson()],
      if (primary != null) 'primary': primary,
      if (clearPrimary) 'primary': null,
    }),
  );

  Future<void> deleteWallet(Wallet w) => _t.delete(w.id, children: false);

  Future<void> addItem(Wallet w, String ref) async {
    if (w.items.any((i) => i.ref == ref)) return;
    await saveWallet(
      w,
      items: [
        ...w.items,
        WalletItem(ref: ref),
      ],
    );
  }

  Future<void> updateItem(Wallet w, WalletItem item) => saveWallet(
    w,
    items: [for (final i in w.items) i.ref == item.ref ? item : i],
  );
  Future<void> removeItem(Wallet w, WalletItem item) => saveWallet(
    w,
    items: [
      for (final i in w.items)
        if (i.ref != item.ref) i,
    ],
    clearPrimary: w.primaryCard == item.targetId,
  );

  String _number(String prefix) {
    final r = math.Random();
    return '$prefix-${List.generate(4, (_) => r.nextInt(10)).join()}-${List.generate(4, (_) => r.nextInt(10)).join()}';
  }

  Future<TrackerRecord> createCard({
    required String type,
    String? memberId,
    required String collection,
    required String layout,
    Set<String> fields = const {
      'name',
      'pronouns',
      'number',
      'photo',
      'issued',
      'emoji',
    },
    String title = '',
  }) {
    final (front, back) = buildAnyTemplate(
      collection,
      layout,
      type: type,
      fields: fields,
    );
    final tplAspect = idTemplateAspect(collection, layout);
    final id = ref.read(systemIdentityProvider);
    return _t.create(
      kind: TrackerKind.walletCard,
      title: title,
      memberId: memberId,
      fields: {
        'v': 1,
        'type': type,
        'collection': collection,
        'layout': layout,
        'aspect': tplAspect,
        'front': front.toJson(),
        'back': back.toJson(),
        'values': const {},
        'number': _number(id.prefix),
        'issued': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> saveCard(
    IdCard c, {
    CardFace? front,
    CardFace? back,
    Map<String, String>? values,
    String? title,
    String? collection,
    String? layout,
    double? aspect,
  }) => _t.save(
    c.r.copyWith(title: title ?? c.r.title).withFields({
      ...c.r.fields,
      if (front != null) 'front': front.toJson(),
      if (back != null) 'back': back.toJson(),
      if (values != null) 'values': values,
      'collection': ?collection,
      'layout': ?layout,
      'aspect': ?aspect,
    }),
  );

  Future<TrackerRecord> duplicateCard(IdCard c) => _t.create(
    kind: TrackerKind.walletCard,
    title: '${c.title} (copy)',
    memberId: c.memberId,
    fields: {
      ...c.r.fields,
      'number': _number(ref.read(systemIdentityProvider).prefix),
    },
  );

  Future<void> deleteCard(IdCard c) async {
    for (final w in ref.read(walletsProvider)) {
      final it = w.items.where((i) => i.ref == 'card:${c.id}').firstOrNull;
      if (it != null) await removeItem(w, it);
    }
    await _t.delete(c.id, children: false);
  }

  Future<void> saveIdentity(SystemIdentity s) async {
    final rec = ref.read(systemIdentityRecordProvider);
    if (rec == null) {
      await _t.create(
        kind: TrackerKind.walletIdentity,
        fields: {'identity': s.toJson()},
      );
    } else {
      await _t.save(rec.withFields({...rec.fields, 'identity': s.toJson()}));
    }
  }

  /// Puts an introduction card in a wallet, optionally hiding it from the
  /// Introductions page (it stays fully visible inside the wallet).
  Future<void> addIntroCard(
    Wallet w,
    TrackerRecord card, {
    bool hideFromIntroductions = false,
  }) async {
    await addItem(w, 'intro:${card.id}');
    if (hideFromIntroductions)
      await _t.save(card.withFields({...card.fields, 'walletOnly': true}));
  }

  Future<void> showIntroOnIntroductions(TrackerRecord card) =>
      _t.save(card.withFields({...card.fields, 'walletOnly': false}));
}

final walletActionsProvider = Provider<WalletActions>(WalletActions.new);
