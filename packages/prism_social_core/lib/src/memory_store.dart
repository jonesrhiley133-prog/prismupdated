import 'dart:math';

import 'records.dart';

/// In-memory [SocialStore] for tests and local tooling.
class MemorySocialStore implements SocialStore {
  final rows = <String, SocRecord>{};
  final _rand = Random.secure();

  String newId() => List.generate(16, (_) => _rand.nextInt(256).toRadixString(16).padLeft(2, '0')).join();

  @override
  Future<List<SocRecord>> all(String kind) async => [for (final r in rows.values) if (r.kind == kind) r];

  @override
  Future<SocRecord> create({required String kind, String title = '', String? body, String? parentId, String? memberId, Map<String, Object?> fields = const {}, DateTime? occurredAt}) async {
    final now = DateTime.now();
    final r = SocRecord(id: newId(), kind: kind, title: title, body: body, parentId: parentId, memberId: memberId, occurredAt: occurredAt, createdAt: now, modifiedAt: now).withFields(fields);
    rows[r.id] = r;
    return r;
  }

  @override
  Future<void> save(SocRecord record) async => rows[record.id] = record.copyWith(modifiedAt: DateTime.now());

  @override
  Future<void> delete(String id) async => rows.remove(id);
}
