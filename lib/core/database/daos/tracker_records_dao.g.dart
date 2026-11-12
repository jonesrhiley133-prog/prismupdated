// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tracker_records_dao.dart';

// ignore_for_file: type=lint
mixin _$TrackerRecordsDaoMixin on DatabaseAccessor<AppDatabase> {
  $TrackerRecordsTable get trackerRecords => attachedDatabase.trackerRecords;
  TrackerRecordsDaoManager get managers => TrackerRecordsDaoManager(this);
}

class TrackerRecordsDaoManager {
  final _$TrackerRecordsDaoMixin _db;
  TrackerRecordsDaoManager(this._db);
  $$TrackerRecordsTableTableManager get trackerRecords =>
      $$TrackerRecordsTableTableManager(
        _db.attachedDatabase,
        _db.trackerRecords,
      );
}
