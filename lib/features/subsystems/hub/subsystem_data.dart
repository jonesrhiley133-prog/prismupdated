import 'dart:async';

import 'package:prism_plurality/features/subsystems/utils/subsystems.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Permissions a member can have inside a subsystem.
const subsystemPermissions = [
  ('manage', 'Manage settings & members', 'Gestionar ajustes y miembros'),
  ('post', 'Post announcements & messages', 'Publicar anuncios y mensajes'),
  (
    'journal',
    'Write in the subsystem journal',
    'Escribir en el diario del subsistema',
  ),
  ('rules', 'Edit rules & boundaries', 'Editar normas y límites'),
];

/// One alter's membership in one subsystem (its own record, so the alter
/// is never copied and their main profile is never changed).
class SubMembership {
  const SubMembership(this.record);
  final TrackerRecord record;
  String get subsystemId => record.parentId ?? '';
  String get memberId => record.memberId ?? '';
  List<String> get roles => record.strings('roles');
  Set<String> get permissions => record.strings('perms').toSet();
  bool get founder => record.flag('founder');
  DateTime get joined => record.occurredAt ?? record.createdAt;
}

/// Subsystem settings live on the subsystem record's data.
class SubSettings {
  const SubSettings(this.r);
  final TrackerRecord r;
  bool get isolate => r.fields['isolate'] == true;
  bool get coFronting => r.fields['coFronting'] != false;
  bool get notifyFronting => r.flag('notifyFronting');
  bool get chat => r.fields['chat'] != false;
  bool get separateJournal => r.fields['separateJournal'] != false;
  String get visibility => r.str('visibility') ?? 'system';
  String? get founderId => r.str('founder');
  String? get banner => r.str('banner');
  int get color => r.integer(SubField.color) ?? 0xFFC98B8B;
  int? get color2 => r.integer('color2');
  String? get lookId => r.str('look');
  List<String> get tags => r.tags;
}

final subsystemsProvider = Provider<List<TrackerRecord>>((ref) {
  final list =
      ref.watch(trackerKindProvider(TrackerKind.subsystem)).value ??
      const <TrackerRecord>[];
  subsystemIndex = {for (final r in list) r.id: r};
  return list;
});

/// Latest subsystems by id, for palette inheritance from parents.
Map<String, TrackerRecord> subsystemIndex = const {};

/// How a subsystem picks its colours.
const subPaletteModes = <String, String>{
  'own': 'Its own palette',
  'inherit': 'Same as parent',
  'blend': 'Blend with parent',
  'theme': 'Follow the app theme',
};

/// Ready-made subsystem palettes (main, glow, accent, soft, deep).
const subPalettePresets = <String, List<int>>{
  'Dusty rose': [0xFFC98B8B, 0xFFE8B4A0, 0xFF8C5A6B, 0xFFF4E1DA, 0xFF5A3A44],
  'Forest': [0xFF4E8A3E, 0xFFA7D379, 0xFF2F5D3A, 0xFFE3F2D9, 0xFF1F3A24],
  'Ocean': [0xFF1F7FBF, 0xFF8FD3F2, 0xFF0F3550, 0xFFDDF2FB, 0xFF0A2236],
  'Twilight': [0xFF6C5BA8, 0xFFC9B6F2, 0xFF2B2D5C, 0xFFEDE6FB, 0xFF1A1B3A],
  'Ember': [0xFFE8462F, 0xFFFFB86B, 0xFF8C2F2F, 0xFFFFE8D6, 0xFF4A1A14],
  'Candy': [0xFFFF7AB6, 0xFFFFD6EA, 0xFFB57EDC, 0xFFFFF0F7, 0xFF5A3D5C],
  'Stone': [0xFF8C8C8C, 0xFFCFCFCF, 0xFF4A4A4A, 0xFFF2F2F2, 0xFF222222],
  'Sunny': [0xFFF2C14E, 0xFFFFE8A3, 0xFFC08A3E, 0xFFFFF8E1, 0xFF5C4310],
};

/// The colours a subsystem actually shows, after inheritance. Returns null
/// for 'theme' mode (callers use the app theme).
List<int>? effectiveSubPalette(TrackerRecord s, {int depth = 0}) {
  final mode = s.str('paletteMode') ?? 'own';
  final own = [
    for (final x in (s.fields['palette'] as List? ?? const []))
      if (x is num) x.toInt(),
  ];
  final base = own.length >= 2
      ? own
      : [SubSettings(s).color, SubSettings(s).color2 ?? SubSettings(s).color];
  if (mode == 'theme') return null;
  final parent = s.parentId == null ? null : subsystemIndex[s.parentId];
  if (parent == null || depth > 8 || mode == 'own') return base;
  final p = effectiveSubPalette(parent, depth: depth + 1);
  if (p == null) return mode == 'inherit' ? null : base;
  if (mode == 'inherit') return p;
  // Blend: halfway between own and parent, colour by colour.
  return [
    for (var i = 0; i < base.length; i++)
      Color.lerp(Color(base[i]), Color(p[i % p.length]), 0.5)!.toARGB32(),
  ];
}

/// Memberships, including legacy member lists stored on older subsystems
/// (shown until they are migrated to records).
final subMembershipsProvider = Provider<List<SubMembership>>((ref) {
  final rows =
      ref.watch(trackerKindProvider(TrackerKind.subMember)).value ??
      const <TrackerRecord>[];
  final out = [
    for (final r in rows)
      if (r.parentId != null && r.memberId != null) SubMembership(r),
  ];
  final have = {for (final m in out) '${m.subsystemId}|${m.memberId}'};
  for (final s in ref.watch(subsystemsProvider)) {
    for (final legacy in subsystemMembers(s)) {
      if (have.contains('${s.id}|${legacy.memberId}')) continue;
      final now = s.createdAt;
      out.add(
        SubMembership(
          TrackerRecord(
            id: 'legacy:${s.id}:${legacy.memberId}',
            kind: TrackerKind.subMember,
            parentId: s.id,
            memberId: legacy.memberId,
            createdAt: now,
            modifiedAt: now,
          ).withFields({
            'roles': [?legacy.role],
            'legacy': true,
          }),
        ),
      );
    }
  }
  return out;
});

/// Member ids that must stay out of system-wide lists, with value equality
/// so member lists only rebuild when the set really changes.
class IsolatedMembers {
  IsolatedMembers(this.ids) : _key = (ids.toList()..sort()).join(',');
  final Set<String> ids;
  final String _key;
  @override
  bool operator ==(Object other) =>
      other is IsolatedMembers && other._key == _key;
  @override
  int get hashCode => _key.hashCode;
}

/// Computed isolation set (reads subsystem records).
final computedIsolationProvider = Provider<IsolatedMembers>((ref) {
  final subs = {
    for (final s in ref.watch(subsystemsProvider))
      if (SubSettings(s).isolate) s.id,
  };
  if (subs.isEmpty) return IsolatedMembers(const {});
  return IsolatedMembers({
    for (final m in ref.watch(subMembershipsProvider))
      if (subs.contains(m.subsystemId)) m.memberId,
  });
});

class IsolatedMembersNotifier extends Notifier<IsolatedMembers> {
  @override
  IsolatedMembers build() => IsolatedMembers(const {});
  void set(IsolatedMembers v) {
    if (v != state) state = v;
  }
}

/// The isolation set member lists filter by. Kept in sync by
/// [isolationSyncProvider] (listened to by the app), so member lists don't
/// open record streams themselves.
final isolatedMembersProvider =
    NotifierProvider<IsolatedMembersNotifier, IsolatedMembers>(
      IsolatedMembersNotifier.new,
    );

final isolationSyncProvider = Provider<void>((ref) {
  // Starts right after the first frame (a short timer keeps app start-up
  // tests from holding record streams open).
  final t = Timer(const Duration(milliseconds: 400), () {
    if (!ref.mounted) return;
    ref.listen<IsolatedMembers>(computedIsolationProvider, (_, next) {
      Future.microtask(() {
        if (ref.mounted) ref.read(isolatedMembersProvider.notifier).set(next);
      });
    }, fireImmediately: true);
  });
  ref.onDispose(t.cancel);
});

class SubsystemActions {
  SubsystemActions(this.ref);
  final Ref ref;
  TrackerNotifier get _t => ref.read(trackerNotifierProvider.notifier);

  Future<TrackerRecord> create({
    required String name,
    required String founderId,
    String? emoji,
    String? description,
    int? color,
    int? color2,
    String? parentId,
    List<String> tags = const [],
    Map<String, Object?> settings = const {},
    List<(String memberId, List<String> roles, Set<String> perms)> members =
        const [],
  }) async {
    final s = await _t.create(
      kind: TrackerKind.subsystem,
      title: name,
      body: description,
      parentId: parentId,
      tags: tags,
      fields: {
        SubField.emoji: emoji,
        SubField.color: color,
        'color2': color2,
        'founder': founderId,
        'isolate': true,
        ...settings,
      },
    );
    await addMember(
      s.id,
      founderId,
      roles: const ['Founder'],
      perms: {for (final p in subsystemPermissions) p.$1},
      founder: true,
    );
    for (final (id, roles, perms) in members) {
      if (id != founderId)
        await addMember(s.id, id, roles: roles, perms: perms);
    }
    return s;
  }

  Future<void> addMember(
    String subsystemId,
    String memberId, {
    List<String> roles = const [],
    Set<String> perms = const {'post', 'journal'},
    bool founder = false,
  }) async {
    final exists = ref
        .read(subMembershipsProvider)
        .any(
          (m) =>
              m.subsystemId == subsystemId &&
              m.memberId == memberId &&
              !m.record.flag('legacy'),
        );
    if (exists) return;
    await _t.create(
      kind: TrackerKind.subMember,
      parentId: subsystemId,
      memberId: memberId,
      occurredAt: DateTime.now(),
      fields: {'roles': roles, 'perms': perms.toList(), 'founder': founder},
    );
  }

  Future<void> updateMember(
    SubMembership m, {
    List<String>? roles,
    Set<String>? perms,
  }) async {
    if (m.record.flag('legacy')) {
      await _t.create(
        kind: TrackerKind.subMember,
        parentId: m.subsystemId,
        memberId: m.memberId,
        occurredAt: m.joined,
        fields: {
          'roles': roles ?? m.roles,
          'perms': (perms ?? m.permissions).toList(),
        },
      );
      await _dropLegacy(m.subsystemId, m.memberId);
      return;
    }
    await _t.save(
      m.record.withFields({
        'roles': ?roles,
        if (perms != null) 'perms': perms.toList(),
      }),
    );
  }

  Future<void> removeMember(SubMembership m) async {
    if (!m.record.flag('legacy')) await _t.delete(m.record.id, children: false);
    await _dropLegacy(m.subsystemId, m.memberId);
  }

  Future<void> _dropLegacy(String subsystemId, String memberId) async {
    final s = ref
        .read(subsystemsProvider)
        .where((x) => x.id == subsystemId)
        .firstOrNull;
    if (s == null) return;
    final list = subsystemMembers(s);
    if (!list.any((x) => x.memberId == memberId)) return;
    await _t.save(
      s.withFields({
        SubField.members: [
          for (final x in list)
            if (x.memberId != memberId) x.toJson(),
        ],
      }),
    );
  }

  /// Turns legacy member lists into membership records (keeps roles).
  Future<void> migrateLegacy() async {
    for (final m
        in ref
            .read(subMembershipsProvider)
            .where((m) => m.record.flag('legacy'))
            .toList()) {
      await _t.create(
        kind: TrackerKind.subMember,
        parentId: m.subsystemId,
        memberId: m.memberId,
        occurredAt: m.joined,
        fields: {
          'roles': m.roles,
          'perms': ['post', 'journal'],
        },
      );
    }
    for (final s in ref.read(subsystemsProvider)) {
      if (subsystemMembers(s).isNotEmpty)
        await _t.save(s.withFields({SubField.members: null}));
    }
  }

  Future<void> saveSettings(
    TrackerRecord s,
    Map<String, Object?> changes, {
    String? title,
    String? body,
    List<String>? tags,
    String? parentId,
    bool clearParent = false,
  }) => _t.save(
    s
        .copyWith(
          title: title ?? s.title,
          body: body ?? s.body,
          tags: tags ?? s.tags,
          parentId: clearParent ? null : (parentId ?? s.parentId),
        )
        .withFields(changes),
  );

  /// Deletes a subsystem with its memberships, groups, rules, notes,
  /// journal and messages. Nested subsystems move up a level; alters stay.
  Future<void> delete(TrackerRecord s) async {
    for (final child
        in ref.read(subsystemsProvider).where((x) => x.parentId == s.id)) {
      await _t.save(child.copyWith(parentId: s.parentId));
    }
    final all = await ref.read(trackerRecordsProvider.future);
    for (final r in all) {
      if (r.parentId == s.id && r.kind.startsWith('subsystem.'))
        await _t.delete(r.id, children: false);
    }
    await _t.delete(s.id, children: false);
  }
}

final subsystemActionsProvider = Provider<SubsystemActions>(
  SubsystemActions.new,
);
