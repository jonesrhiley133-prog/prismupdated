import 'dart:async';

import 'package:prism_plurality/features/subsystems/utils/subsystems.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Permissions a member can have inside a subsystem.
const subsystemPermissions = [
  ('manage', 'Manage settings & members', 'Gestionar ajustes y miembros'),
  ('post', 'Post announcements & messages', 'Publicar anuncios y mensajes'),
  ('journal', 'Write in the subsystem journal', 'Escribir en el diario del subsistema'),
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

final subsystemsProvider = Provider<List<TrackerRecord>>((ref) => ref.watch(trackerKindProvider(TrackerKind.subsystem)).value ?? const []);

/// Memberships, including legacy member lists stored on older subsystems
/// (shown until they are migrated to records).
final subMembershipsProvider = Provider<List<SubMembership>>((ref) {
  final rows = ref.watch(trackerKindProvider(TrackerKind.subMember)).value ?? const <TrackerRecord>[];
  final out = [for (final r in rows) if (r.parentId != null && r.memberId != null) SubMembership(r)];
  final have = {for (final m in out) '${m.subsystemId}|${m.memberId}'};
  for (final s in ref.watch(subsystemsProvider)) {
    for (final legacy in subsystemMembers(s)) {
      if (have.contains('${s.id}|${legacy.memberId}')) continue;
      final now = s.createdAt;
      out.add(SubMembership(TrackerRecord(
        id: 'legacy:${s.id}:${legacy.memberId}',
        kind: TrackerKind.subMember,
        parentId: s.id,
        memberId: legacy.memberId,
        createdAt: now,
        modifiedAt: now,
      ).withFields({'roles': [?legacy.role], 'legacy': true})));
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
  bool operator ==(Object other) => other is IsolatedMembers && other._key == _key;
  @override
  int get hashCode => _key.hashCode;
}

/// Computed isolation set (reads subsystem records).
final computedIsolationProvider = Provider<IsolatedMembers>((ref) {
  final subs = {for (final s in ref.watch(subsystemsProvider)) if (SubSettings(s).isolate) s.id};
  if (subs.isEmpty) return IsolatedMembers(const {});
  return IsolatedMembers({for (final m in ref.watch(subMembershipsProvider)) if (subs.contains(m.subsystemId)) m.memberId});
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
final isolatedMembersProvider = NotifierProvider<IsolatedMembersNotifier, IsolatedMembers>(IsolatedMembersNotifier.new);

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
    List<(String memberId, List<String> roles, Set<String> perms)> members = const [],
  }) async {
    final s = await _t.create(
      kind: TrackerKind.subsystem,
      title: name,
      body: description,
      parentId: parentId,
      tags: tags,
      fields: {SubField.emoji: emoji, SubField.color: color, 'color2': color2, 'founder': founderId, 'isolate': true, ...settings},
    );
    await addMember(s.id, founderId, roles: const ['Founder'], perms: {for (final p in subsystemPermissions) p.$1}, founder: true);
    for (final (id, roles, perms) in members) {
      if (id != founderId) await addMember(s.id, id, roles: roles, perms: perms);
    }
    return s;
  }

  Future<void> addMember(String subsystemId, String memberId, {List<String> roles = const [], Set<String> perms = const {'post', 'journal'}, bool founder = false}) async {
    final exists = ref.read(subMembershipsProvider).any((m) => m.subsystemId == subsystemId && m.memberId == memberId && !m.record.flag('legacy'));
    if (exists) return;
    await _t.create(kind: TrackerKind.subMember, parentId: subsystemId, memberId: memberId, occurredAt: DateTime.now(), fields: {'roles': roles, 'perms': perms.toList(), 'founder': founder});
  }

  Future<void> updateMember(SubMembership m, {List<String>? roles, Set<String>? perms}) async {
    if (m.record.flag('legacy')) {
      await _t.create(kind: TrackerKind.subMember, parentId: m.subsystemId, memberId: m.memberId, occurredAt: m.joined, fields: {'roles': roles ?? m.roles, 'perms': (perms ?? m.permissions).toList()});
      await _dropLegacy(m.subsystemId, m.memberId);
      return;
    }
    await _t.save(m.record.withFields({'roles': ?roles, if (perms != null) 'perms': perms.toList()}));
  }

  Future<void> removeMember(SubMembership m) async {
    if (!m.record.flag('legacy')) await _t.delete(m.record.id, children: false);
    await _dropLegacy(m.subsystemId, m.memberId);
  }

  Future<void> _dropLegacy(String subsystemId, String memberId) async {
    final s = ref.read(subsystemsProvider).where((x) => x.id == subsystemId).firstOrNull;
    if (s == null) return;
    final list = subsystemMembers(s);
    if (!list.any((x) => x.memberId == memberId)) return;
    await _t.save(s.withFields({SubField.members: [for (final x in list) if (x.memberId != memberId) x.toJson()]}));
  }

  /// Turns legacy member lists into membership records (keeps roles).
  Future<void> migrateLegacy() async {
    for (final m in ref.read(subMembershipsProvider).where((m) => m.record.flag('legacy')).toList()) {
      await _t.create(kind: TrackerKind.subMember, parentId: m.subsystemId, memberId: m.memberId, occurredAt: m.joined, fields: {'roles': m.roles, 'perms': ['post', 'journal']});
    }
    for (final s in ref.read(subsystemsProvider)) {
      if (subsystemMembers(s).isNotEmpty) await _t.save(s.withFields({SubField.members: null}));
    }
  }

  Future<void> saveSettings(TrackerRecord s, Map<String, Object?> changes, {String? title, String? body, List<String>? tags, String? parentId, bool clearParent = false}) => _t.save(
    s.copyWith(title: title ?? s.title, body: body ?? s.body, tags: tags ?? s.tags, parentId: clearParent ? null : (parentId ?? s.parentId)).withFields(changes),
  );

  /// Deletes a subsystem with its memberships, groups, rules, notes,
  /// journal and messages. Nested subsystems move up a level; alters stay.
  Future<void> delete(TrackerRecord s) async {
    for (final child in ref.read(subsystemsProvider).where((x) => x.parentId == s.id)) {
      await _t.save(child.copyWith(parentId: s.parentId));
    }
    final all = await ref.read(trackerRecordsProvider.future);
    for (final r in all) {
      if (r.parentId == s.id && r.kind.startsWith('subsystem.')) await _t.delete(r.id, children: false);
    }
    await _t.delete(s.id, children: false);
  }
}

final subsystemActionsProvider = Provider<SubsystemActions>(SubsystemActions.new);
