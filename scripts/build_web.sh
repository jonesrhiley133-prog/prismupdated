#!/usr/bin/env bash
# Builds the browser version of Prism into build/web.
#
#   --no-tree-shake-icons   some icons are chosen at runtime (custom fields),
#                           which icon tree-shaking can't handle.
#   --no-web-resources-cdn  bundle CanvasKit with the app instead of loading
#                           it from Google's CDN, so the deploy is
#                           self-contained.
set -euo pipefail
cd "$(dirname "$0")/.."
flutter build web --release --no-tree-shake-icons --no-web-resources-cdn "$@"
