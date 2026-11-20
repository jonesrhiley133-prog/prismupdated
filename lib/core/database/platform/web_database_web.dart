import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:prism_plurality/core/web/render_mode.dart';

/// Opens `prism` in the browser using `web/sqlite3.wasm` and
/// `web/drift_worker.js`. Drift picks the best storage the browser offers
/// (OPFS, shared IndexedDB, or plain IndexedDB).
///
/// Data is NOT encrypted at rest on the web: SQLCipher is not available in
/// the WASM build. The web build is meant for development and previews.
QueryExecutor openWebDatabase() {
  return DatabaseConnection.delayed(
    Future(() async {
      markWebStage('db-open');
      final WasmDatabaseResult result;
      try {
        // Another Prism tab or installed-app window can hold the database;
        // fail visibly (with Try again) instead of waiting forever.
        result = await WasmDatabase.open(
          databaseName: 'prism',
          sqlite3Uri: Uri.parse('sqlite3.wasm'),
          driftWorkerUri: Uri.parse('drift_worker.js'),
        ).timeout(const Duration(seconds: 25));
      } on TimeoutException {
        reportWebError('Opening the browser database timed out.');
        throw const _OpenTimeout();
      } catch (e) {
        reportWebError('Database open failed: $e');
        rethrow;
      }
      markWebStage('db-ready');
      debugPrint('[WEB_DB] Using ${result.chosenImplementation}.');
      if (result.missingFeatures.isNotEmpty) {
        debugPrint(
          '[WEB_DB] Using ${result.chosenImplementation}; missing browser '
          'features: ${result.missingFeatures}',
        );
      }
      return result.resolvedExecutor;
    }),
  );
}

class _OpenTimeout implements Exception {
  const _OpenTimeout();

  @override
  String toString() =>
      'Opening the browser database timed out. Close any other Prism tabs '
      'or the installed Prism app window, then try again.';
}
