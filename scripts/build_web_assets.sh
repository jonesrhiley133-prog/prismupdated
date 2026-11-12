#!/usr/bin/env bash
# Regenerates the two files the web database needs, in web/:
#   sqlite3.wasm     SQLite compiled to WebAssembly (from the sqlite3 package
#                    release matching pubspec.lock)
#   drift_worker.js  Drift's database worker, compiled from
#                    tool/web/drift_worker.dart with the pinned drift version
# Run after upgrading the sqlite3 or drift packages.
set -euo pipefail
cd "$(dirname "$0")/.."
SQLITE3_VERSION=$(awk '/^  sqlite3:$/{f=1} f&&/version:/{gsub(/"/,"",$2); print $2; exit}' pubspec.lock)
echo "sqlite3 package version: ${SQLITE3_VERSION}"
curl -fsSL -o web/sqlite3.wasm \
  "https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-${SQLITE3_VERSION}/sqlite3.wasm"
dart compile js -O4 tool/web/drift_worker.dart -o web/drift_worker.js
rm -f web/drift_worker.js.deps web/drift_worker.js.map
echo "Updated web/sqlite3.wasm and web/drift_worker.js"
