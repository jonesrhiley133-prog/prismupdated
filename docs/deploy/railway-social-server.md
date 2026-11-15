# Deploying the Prism Social server to Railway

The Prism Social server lets systems on **different people's phones** become
friends, message each other (including alter-to-alter), post and react.
Without it, Social only works between the systems in one Prism account.

- Code: `server/`. It uses the shared rules package in
  `packages/prism_social_core`, the same rules the app runs on-device.
- Image: a ~20 MB Docker image (an AOT-compiled Dart binary).
- Database: Postgres. Tables are created automatically on first start.

## 1. Create the services

The repository's root `Dockerfile` builds the web app by default. With the
service variable `PRISM_SERVICE=server`, it builds the Social server instead.
Both services can share the same repository and the root `railway.json`.

1. In your Railway project: **New → Database → PostgreSQL**.
2. **New → GitHub Repo** → this repository (branch `main`). This becomes the
   server service. Leave **Root Directory** empty.
3. Under the service's **Variables**, add:
   - `PRISM_SERVICE` = `server`
   - `DATABASE_URL` = `${{Postgres.DATABASE_URL}}` (the private URL; TLS is
     turned off automatically for `*.railway.internal`)
   - `REGISTRATION_CODE` = an invite code of your choice (recommended)
4. Under **Networking**, choose **Generate Domain** (port 8080).

Deploy. The logs should end with
`Prism Social server 0.1.0 listening on :8080 (postgres)`, and
`https://<your-domain>/healthz` returns `{"ok":true}`. (Railway's health check
uses `/`, which the server also answers.)

`server/Dockerfile` builds the same image on its own, for other hosts:
`docker build -f server/Dockerfile .`

## 2. Connect the app

In Prism: **Social → settings (gear) → Connection → Connect to a server**.
Enter your domain, plus the invite code if you set one.

- Each person connects their own Prism account. All of that person's devices
  then share the connection automatically, through end-to-end-encrypted
  Prism sync.
- "Bring my system profiles" recreates existing on-device Social profiles and
  alter profiles on the server.
- The app polls about every 15 seconds while it's open. Device notifications
  for new requests and messages appear while Prism is running.

## Settings (environment variables)

| Variable | Default | Meaning |
| --- | --- | --- |
| `DATABASE_URL` | — (required) | Postgres connection string. |
| `PGSSLMODE` | auto | Override TLS (`disable`, `require`, `verify-full`…). |
| `REGISTRATION_CODE` | unset | If set, new accounts must enter this invite code. Recommended for a private server. |
| `ALLOW_REGISTRATION` | `true` | `false` stops new accounts entirely. |
| `MAX_PROFILES_PER_ACCOUNT` | `10` | Systems one account can create. |
| `MAX_MEDIA_BYTES` | `8388608` | Largest image upload (8 MB). |
| `WRITES_PER_MINUTE` | `120` | Per-account write rate limit. |
| `REGISTRATIONS_PER_HOUR` | `20` | Per-IP sign-up limit. |
| `PRISM_SOCIAL_ALLOW_MEMORY` | unset | `true` runs without a database. Everything is lost on restart, so use it only for a quick test. |

## What the server stores, and what it doesn't

- **Stores:**
  - Social profiles, alter profiles, friend requests, friendships, follows,
    blocks, circles
  - Conversations and messages
  - Posts, comments, likes and bookmarks
  - Notifications and reports
  - Images people attach
- **Never receives:** anything else from Prism (fronting, journals, members,
  health data…). Milestones arrive only through "Share to Social", with the
  fields the person picked.
- **Visibility is enforced on the server.** Each account downloads only what
  its systems may see: blocked people disappear in both directions,
  friends-only and circle posts stay private, and other people's
  notification settings and member IDs are stripped.
- **Messages are not end-to-end encrypted.** The server operator could read
  them. Run your own server, or use one run by someone you trust.
- **Deleting an account** (Connection → Delete server account) removes that
  account's systems, posts, comments, likes, friendships and images. Messages
  it sent show as deleted.

## Limits to know about

- **Run one instance (no replicas).** The server serialises writes in memory
  so its duplicate checks can't race.
- **No phone push notifications** when Prism is closed. That would need
  APNs/FCM credentials.
- **Polling, not realtime.** Changes appear within about 15 seconds.
- **Built for communities of hundreds of systems,** not millions. Each sync
  builds that account's view from the database.

## Running it yourself

```bash
cd server
dart pub get
DATABASE_URL=postgres://user:pass@localhost:5432/prism_social dart run bin/server.dart
```

Tests:

```bash
cd server && dart test
```

To run the same tests against Postgres, set
`PRISM_TEST_DATABASE_URL=postgres://…` (the tables are emptied between tests).
