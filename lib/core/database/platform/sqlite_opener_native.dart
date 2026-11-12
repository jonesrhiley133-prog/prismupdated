import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart' as ffi_sqlite;

/// Opens a raw SQLite connection to the file at [path].
CommonDatabase openRawSqlite(String path) => ffi_sqlite.sqlite3.open(path);

/// Opens [file] with Drift on a background isolate, running [setup] on the
/// raw connection first (used to apply the SQLCipher key).
QueryExecutor openNativeDatabaseInBackground(
  File file, {
  required void Function(CommonDatabase db) setup,
}) {
  return NativeDatabase.createInBackground(file, setup: setup);
}
