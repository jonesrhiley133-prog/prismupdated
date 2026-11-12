// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'location_sessions_dao.dart';

// ignore_for_file: type=lint
mixin _$LocationSessionsDaoMixin on DatabaseAccessor<AppDatabase> {
  $LocationSessionsTable get locationSessions =>
      attachedDatabase.locationSessions;
  LocationSessionsDaoManager get managers => LocationSessionsDaoManager(this);
}

class LocationSessionsDaoManager {
  final _$LocationSessionsDaoMixin _db;
  LocationSessionsDaoManager(this._db);
  $$LocationSessionsTableTableManager get locationSessions =>
      $$LocationSessionsTableTableManager(
        _db.attachedDatabase,
        _db.locationSessions,
      );
}
