import 'dart:io';

import 'package:drift/drift.dart';
import 'package:sqlite3/common.dart';

/// Web stub: raw file-backed SQLite is unavailable in the browser.
CommonDatabase openRawSqlite(String path) =>
    throw UnsupportedError('File-backed SQLite is not available on the web.');

/// Web stub: the web build opens Drift via `openWebDatabase` instead.
QueryExecutor openNativeDatabaseInBackground(
  File file, {
  required void Function(CommonDatabase db) setup,
}) => throw UnsupportedError('Native SQLite is not available on the web.');
