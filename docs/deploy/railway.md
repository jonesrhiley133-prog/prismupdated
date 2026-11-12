# Deploying the web build to Railway

Prism builds for the browser as well as for iOS, Android and desktop. The web
build is meant for development and previews: anything you push can be opened
from any device with a browser, without a local Flutter or Rust toolchain.

## What works on the web

Everything that runs on the local database works: members, fronting, chat,
boards, polls, habits, notes, reminders (without notifications), mood,
calendar, statistics, settings, import and export.

These are **not available** on the web build:

| Feature | Why |
| --- | --- |
| Sync and device pairing | The sync engine is native Rust code; the web build never starts it. |
| Encryption at rest | SQLCipher has no WASM build. Data sits unencrypted in the browser's storage. |
| Recovery phrase | Only used to set up sync keys, so onboarding skips it on the web. |
| Notifications | Reminder, habit and calendar alerts need the native notification plugin. |
| iOS voice-note remuxing | Uses a converter that can't compile to JavaScript. |

Data is stored per browser (IndexedDB / OPFS) under the name `prism`.
Clearing site data in the browser erases it. Use **Settings → Import &
export** to move data in or out.

The PIN on the web is a local app lock with lighter hashing, because Argon2
is very slow in JavaScript. It is not a security boundary: the data itself
is unencrypted.

## Deploying

The repository contains everything Railway needs:

- `Dockerfile`: stage 1 downloads Flutter and runs `scripts/build_web.sh`;
  stage 2 serves `build/web` with Caddy.
- `deploy/web/Caddyfile`: listens on Railway's `$PORT`, sends unknown paths
  to `index.html`, and stops browsers caching the entry files after a deploy.
- `railway.json`: tells Railway to use the Dockerfile and health-check `/`.

Steps:

1. In Railway, create a project, choose **Deploy from GitHub repo** and pick
   this repository.
2. In the service's **Settings → Source**, choose the branch to deploy.
   Railway redeploys on every push to it.
3. In **Settings → Networking**, click **Generate Domain**.
4. Open the domain. The first build takes several minutes (it downloads the
   Flutter SDK); later builds reuse the cached dependency layer.

No environment variables are needed. To change the Flutter version, edit
`FLUTTER_VERSION` in the Dockerfile.

## Running the web build locally

```bash
flutter run -d web-server --web-port 8080
```

or build exactly what Railway serves:

```bash
./scripts/build_web.sh
```

```bash
docker build -t prism-web . && docker run --rm -p 8080:8080 prism-web
```

## How the web build differs in code

- `lib/main.dart` calls `runWebApp()` (`lib/web/web_bootstrap.dart`) when
  `kIsWeb`. It opens the database with Drift's WASM backend and stubs out
  the sync handle, notification listeners and screen-privacy controller.
- `lib/core/database/platform/` holds conditional imports: native builds
  open SQLite through FFI with SQLCipher; web builds use
  `web/sqlite3.wasm` and `web/drift_worker.js`.
- `lib/shared/utils/run_in_background.dart` runs work on an isolate natively
  and inline on the web (browsers have no Dart isolates).
- Calls into the sync bindings wrap 64-bit integers with
  `PlatformInt64Util.from`, since the web bindings use `BigInt`.

After upgrading the `drift` or `sqlite3` packages, regenerate the two web
database files:

```bash
./scripts/build_web_assets.sh
```
