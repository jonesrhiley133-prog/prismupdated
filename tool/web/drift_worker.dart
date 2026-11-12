// Source for web/drift_worker.js, the Web Worker Drift uses to run SQLite
// (WASM) off the UI thread in the browser build. Rebuild after upgrading
// drift with: ./scripts/build_web_assets.sh
import 'package:drift/wasm.dart';

void main() => WasmDatabase.workerMainForOpen();
