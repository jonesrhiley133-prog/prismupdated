# Prism Social server API

The server (`server/`) and the app's on-device mode run the **same rules**,
from `packages/prism_social_core`. The app picks its backend in
`socialBackendProvider`:

- **`LocalSocialBackend`** (on-device): the rules run against your synced
  records. Systems in one Prism account can befriend and message each other.
- **`RemoteSocialBackend`** (server mode): every action goes to the server as
  an RPC. The app then mirrors the server's per-account snapshot into its
  local Social rows, so the screens are identical in both modes.

Deploying the server: [docs/deploy/railway-social-server.md](../deploy/railway-social-server.md).

## Conventions

- JSON in and out. Times are ISO-8601 UTC.
- **Actor**: `{"p": "<profileId>", "a": "<alterId>"?}`. A system, or one of
  its alters speaking. An alter never appears without its system.
- **Audience**: `everyone` | `friendsOfFriends` | `friends` | `nobody`.
- **Errors**: `{"error": {"code": "...", "message"?: "..."}}`.

| HTTP | Codes |
|---|---|
| 401 | `unauthorized` |
| 403 | `self`, `blocked`, `privacy`, `not_owner`, `not_friends`, `not_participant`, `alters_closed`, `not_managed`, `too_many_profiles`, `invite_required`, `registration_closed` |
| 404 | `not_found`, `unknown_method` |
| 409 | `duplicate`, `already_friends`, `username_taken` |
| 400 | `invalid`, `bad_request` |
| 413 / 415 | `too_large`, `quota_exceeded` / `unsupported_media_type` |
| 429 | `rate_limited` |

## Endpoints

| Method | Path | Auth | Notes |
|---|---|---|---|
| GET | `/healthz` | — | `{"ok":true}` when the database answers. Used by Railway's health check. |
| GET | `/v1/info` | — | `{name: "Prism Social", version, maxMediaBytes, registration: open/invite/closed}` |
| POST | `/v1/auth/register` | — | Optional header `x-registration-code`. Returns `201 {account, token}`. Only a SHA-256 of the token is stored. |
| POST | `/v1/rpc/{method}` | Bearer | Body: the method's arguments. Returns `{result, version}`. |
| GET | `/v1/sync?v={version}` | Bearer | `{version, profiles: [mine], records: [...]}`, or `304` when nothing has changed since `version`. |
| POST | `/v1/media` | Bearer | Raw image bytes with `content-type: image/jpeg/png/webp/gif/heic`. Returns `201 {id}`. The app refers to it as `srv:<id>`. |
| GET | `/v1/media/{id}` | Bearer | The image bytes. |
| DELETE | `/v1/account` | Bearer | Deletes the account, its systems and everything they authored (sent messages show as deleted). |

CORS allows any origin, because auth is a bearer token (no cookies). The web
build can therefore connect too.

## RPC methods

Names and arguments mirror `SocialBackend` (`lib/features/prism_social/social_core.dart`)
one-to-one. The server checks that every actor or `profileId` belongs to the
calling account (`not_managed`).

| Area | Methods |
|---|---|
| Profiles | `createProfile {username, systemName, description?, primary?}` · `updateProfile {profileId, changes, systemName?, description?}` · `touch {profileId}` |
| Alters | `saveAlter {profileId, editingId?, memberId?, name, fields, description?}` · `deleteAlter {profileId, alterId}` |
| Requests | `sendRequest {from, to, note?}` · `acceptRequest` / `declineRequest` / `cancelRequest {actor, requestId}` |
| Relationships | `removeFriend` / `toggleFavorite` / `toggleFollow` / `block` / `unblock {actor, other}` · `report {actor, targetType, targetId, reason}` |
| Messaging | `openConversation {me, them}` · `sendMessage {actor, conversationId, body?, media?, replyTo?}` · `editMessage` · `deleteMessage {actor, messageId[, body]}` · `react {actor, messageId, emoji}` · `markRead` / `markUnread` / `toggleMute {actor, conversationId}` · `togglePin {actor, conversationId, messageId}` |
| Posts | `createPost {actor, type, title?, body?, media?, link?, quoteSource?, milestone?, audience?, circleId?}` · `editPost` · `deletePost` · `toggleReact {actor, postId, type: like/bookmark}` · `comment {actor, postId, body, replyTo?}` · `deleteComment` · `reblog {actor, postId, note?, audience?}` · `togglePinPost` |
| Circles | `saveCircle {actor, editingId?, name, members}` · `deleteCircle {actor, circleId}` |
| Notifications | `markNotifications {profileId, id?, read?}` · `deleteNotification {profileId, id}` |

## Rules

The rules are the same in both modes. See `packages/prism_social_core/lib/src/rules.dart`.

**Usernames**
- `^[a-z0-9_.]{3,30}$`, unique.

**Friend requests**
- Refused for yourself, between blocked systems, between existing friends, or
  as a duplicate.
- Respect the target's `privacy.requests`.
- If a reverse request is already pending, it is accepted instead.

**Messages**
- Respect the target's `privacy.messages`.
- An alter can be messaged only if all of these allow it: the system's
  `altersMessages` and `friendsReachAlters`, and the alter's `canMessage` and
  `visibility`.
- Only the exact participant identities can send.
- Edits and deletes are by the sender only.

**Posts**
- Visible by audience or circle. Hidden across blocks.
- An alter needs `canPost`.
- Only `everyone` posts can be reblogged. A reblog always credits the
  original post and author.

**Blocks**
- End the friendship, cancel pending requests and remove follows.

**Notifications**
- Not sent across blocks, when the recipient has turned that type off, or
  for muted conversations.
- `@username` mentions notify the mentioned system.

## What each account downloads (`visibleTo`)

`packages/prism_social_core/lib/src/visibility.dart`:

- **Own data:** your profiles (marked `_mine` in the app), alters, circles,
  blocks, reports and notifications.
- **Relationships:** requests and follows involving you; friendships of you
  and your friends (used for mutual friends and friends-of-friends
  audiences).
- **Posts:** the ones your systems may see, with their comments and likes.
  Bookmarks are only yours.
- **Circle posts:** you also get a stripped copy of the circle (no name, only
  you as a member).
- **Other people's profiles:** connected or discoverable ones.
  - Without profile access: a minimal card.
  - Always stripped: `owner` and `notify`.
  - Included: a `followers` count.
- **Other people's alters:** only when both `privacy.alters` and the alter's
  `visibility` allow it, or when the alter is talking to or posting where you
  can see. Member IDs are removed.
- **Blocks:** anyone who blocked you, or whom you blocked, is left out
  entirely. A block placed by someone else is never revealed.

## Not included (yet)

- Phone push notifications while the app is closed (needs APNs/FCM).
- Realtime streaming: the app polls `/v1/sync` every ~15 seconds, and a
  `304` makes idle polls cheap.
- End-to-end encrypted messages.
- Running more than one server instance.
