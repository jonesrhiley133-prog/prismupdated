import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/foundation.dart';

/// Opens `prism` in the browser using `web/sqlite3.wasm` and
/// `web/drift_worker.js`. Drift picks the best storage the browser offers
/// (OPFS, shared IndexedDB, or plain IndexedDB).
///
/// Data is NOT encrypted at rest on the web: SQLCipher is not available in
/// the WASM build. The web build is meant for development and previews.
QueryExecutor openWebDatabase() {
  return DatabaseConnection.delayed(
    Future(() async {
      final result = await WasmDatabase.open(
        databaseName: 'prism',
        sqlite3Uri: Uri.parse('sqlite3.wasm'),
        driftWorkerUri: Uri.parse('drift_worker.js'),
      );
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
