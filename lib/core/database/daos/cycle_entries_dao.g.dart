// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cycle_entries_dao.dart';

// ignore_for_file: type=lint
mixin _$CycleEntriesDaoMixin on DatabaseAccessor<AppDatabase> {
  $CycleEntriesTable get cycleEntries => attachedDatabase.cycleEntries;
  CycleEntriesDaoManager get managers => CycleEntriesDaoManager(this);
}

class CycleEntriesDaoManager {
  final _$CycleEntriesDaoMixin _db;
  CycleEntriesDaoManager(this._db);
  $$CycleEntriesTableTableManager get cycleEntries =>
      $$CycleEntriesTableTableManager(_db.attachedDatabase, _db.cycleEntries);
}
