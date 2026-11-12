import 'package:drift/drift.dart';
import 'package:prism_plurality/core/database/app_database.dart';
import 'package:prism_plurality/core/database/tables/cycle_contacts_tables.dart';

part 'contacts_dao.g.dart';

@DriftAccessor(tables: [Contacts])
class ContactsDao extends DatabaseAccessor<AppDatabase>
    with _$ContactsDaoMixin {
  ContactsDao(super.db);

  Stream<List<ContactRow>> watchAll() =>
      (select(contacts)
            ..where((t) => t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.displayName)]))
          .watch();

  Future<List<ContactRow>> getAll() =>
      (select(contacts)
            ..where((t) => t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.displayName)]))
          .get();

  Future<ContactRow?> getById(String id) =>
      (select(contacts)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> create(ContactsCompanion companion) =>
      into(contacts).insert(companion);

  Future<void> updateById(String id, ContactsCompanion companion) =>
      (update(contacts)..where((t) => t.id.equals(id))).write(companion);

  Future<void> softDelete(String id) =>
      (update(contacts)..where((t) => t.id.equals(id))).write(
        const ContactsCompanion(isDeleted: Value(true)),
      );
}
