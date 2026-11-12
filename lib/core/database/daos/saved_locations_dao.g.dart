// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_locations_dao.dart';

// ignore_for_file: type=lint
mixin _$SavedLocationsDaoMixin on DatabaseAccessor<AppDatabase> {
  $SavedLocationsTable get savedLocations => attachedDatabase.savedLocations;
  SavedLocationsDaoManager get managers => SavedLocationsDaoManager(this);
}

class SavedLocationsDaoManager {
  final _$SavedLocationsDaoMixin _db;
  SavedLocationsDaoManager(this._db);
  $$SavedLocationsTableTableManager get savedLocations =>
      $$SavedLocationsTableTableManager(
        _db.attachedDatabase,
        _db.savedLocations,
      );
}
