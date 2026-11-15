# Prism Social server API (draft)

Prism Social currently runs on `LocalSocialBackend`
(`lib/features/prism_social/social_core.dart`). It stores everything as synced
`soc.*` tracker records, so the systems managed in one Prism account can
befriend, message and post to each other across that account's devices.

Reaching **other people's** systems needs a server. This document is the
contract a `RemoteSocialBackend` would implement. Every rule below is already
enforced by the local backend, so the screens will not need to change.

## Principles

- **Identity.** An actor is a system (`profileId`), optionally speaking as one
  of its alters (`profileId` + `alterId`). Alters always travel with their
  system and are never shown on their own.
- **Server-side enforcement.** Privacy, blocks, audiences and circles are
  checked on every read and write. The client checks are only for UI.
- **Opt-in sharing.** Nothing from the rest of Prism is uploaded. Only data
  the user explicitly posts, sends or puts on their profile reaches the
  server. Milestones are shared only via "Share to Social", with the fields
  the user selects.
- **Errors.** Every refusal returns `403/404/409` with `{ "code": "<code>" }`.
  The codes are: `self`, `blocked`, `privacy`, `duplicate`, `already_friends`,
  `not_found`, `not_owner`, `not_friends`, `not_participant`, `alters_closed`,
  `username_taken`, `not_managed`, `invalid`. They map 1:1 to `SocialDenied`.

## Auth

- `POST /v1/auth/device` — exchanges the prism-sync account identity for a
  short-lived bearer token. One account can manage several system profiles.
- Every request carries `Authorization: Bearer <token>`.
- Acting as a profile or alter the account doesn't manage returns
  `not_managed`.

## Profiles

| Method | Path | Notes |
|---|---|---|
| POST | `/v1/profiles` | `{username, systemName, description?}`. Username: `^[a-z0-9_.]{3,30}$`, unique (`username_taken`). |
| GET | `/v1/profiles/{id}` | Returns a limited card if `privacy.profile` excludes the viewer. |
| PATCH | `/v1/profiles/{id}` | Fields: `systemName, description, pronouns, systemType, showSystemType, avatar, banner, bannerY, status, links, theme, useTheme, privacy, notify, pinned`. |
| GET | `/v1/profiles?q=` | Discover/search. Only profiles with `privacy.discover != false`. Blocked profiles are excluded both ways. |
| POST | `/v1/profiles/{id}/alters` | `{name, memberId?, pronouns, description, avatar, banner, customStatus, visibility, canMessage, canPost}` |
| PATCH/DELETE | `/v1/alters/{id}` | Owner only. |

**Privacy keys** use the audience values `everyone | friendsOfFriends | friends | nobody`:

- `requests`, `messages`, `profile`, `alters`, `posts` (the default audience for new posts)
- Booleans: `altersMessages`, `friendsReachAlters`, `online`, `discover`, `readReceipts`, `typing`, `activity`

**Theme** is `{accent, background, card: ARGB int, font: default|display|serif|mono|dyslexic, layout: classic|centered|compact, radius}`.

## Relationships

| Method | Path | Rules |
|---|---|---|
| POST | `/v1/requests` | `{from, to, note?}`. Fails with `self`, `blocked`, `already_friends`, `duplicate`, or `privacy` (the target's `requests` audience). If a reverse request is pending, it is accepted instead. |
| POST | `/v1/requests/{id}/accept` · `/decline` | Recipient only. |
| POST | `/v1/requests/{id}/cancel` | Sender only. |
| DELETE | `/v1/friends/{other}` | Ends the friendship. Conversations remain. |
| POST | `/v1/friends/{other}/favorite` | Toggle; private to the caller. |
| POST/DELETE | `/v1/follows/{other}` | |
| POST | `/v1/blocks/{other}` | Ends the friendship, cancels pending requests, removes follows both ways. |
| DELETE | `/v1/blocks/{other}` | Unblock. |
| POST | `/v1/reports` | `{targetType, targetId, reason}` → moderation queue. |
| PUT | `/v1/circles/{id}` | `{name, members[]}`. Members must be friends. Circle names and member lists are never shown to members. |

## Messaging

- `POST /v1/conversations` with `{me: Actor, them: Actor}` reuses an existing
  1:1 conversation between exactly these two identities. It checks:
  - blocks
  - the recipient's `messages` audience
  - for an alter: `altersMessages`, the alter's `canMessage` and
    `visibility`, and `friendsReachAlters` (→ `alters_closed`)
- `GET /v1/conversations?profile=` — sorted by last message.
- `POST /v1/conversations/{id}/messages` with `{sender: Actor, body, media[], replyTo?}`.
  - The sender must be a participant identity exactly (`not_participant`).
  - Fails with `blocked` if either side has blocked the other.
- `PATCH /v1/messages/{id}` (edit) and `DELETE` (soft delete; shows as
  "Message deleted"). Sender identity only.
- `POST /v1/messages/{id}/reactions` with `{emoji}` — toggle.
- `POST /v1/conversations/{id}/read`, `/unread`, `/mute`, `/pins/{messageId}`.
- Read receipts are only returned when **both** sides have `readReceipts` on.

## Posts

| Method | Path | Notes |
|---|---|---|
| POST | `/v1/posts` | `{author: Actor, type: text|image|link|quote|milestone|update|question, title, body, media[], link, quoteSource, milestone?, audience, circleId?}`. An alter needs `canPost`. |
| PATCH/DELETE | `/v1/posts/{id}` | Edit: the author identity. Delete: the author's system (also removes comments and reactions). |
| GET | `/v1/feed?mode=following|friends|recommended|recent|popular&cursor=` | Only posts the viewer may see. |
| POST | `/v1/posts/{id}/reactions` | `{type: like|bookmark}` toggle. Bookmarks are private. |
| POST | `/v1/posts/{id}/comments` | `{author, body, replyTo?}`. Comment authors and post owners can delete. |
| POST | `/v1/posts/{id}/reblog` | `{author, note?, audience?}`. Only `everyone` posts. `origin` always points at the original post and author, even when reblogging a reblog. |
| POST | `/v1/posts/{id}/pin` | Up to 5 pins per profile. |

**Visibility** (`canSee`):

1. The owner can always see their own posts.
2. Blocked users never can.
3. `nobody` means the owner only.
4. A post with a circle is visible to circle members only.
5. Otherwise the audience applies (`everyone`, `friends`, `friendsOfFriends`).

## Notifications

- Types: `request`, `accepted`, `message`, `alterMessage`, `like`,
  `milestoneLike`, `comment`, `reply`, `reblog`, `mention` (`@username` in a
  post or comment).
- Nothing is created when the recipient has blocked the actor, or has turned
  that type off in `notify`. Muted conversations don't notify.
- Endpoints: `GET /v1/notifications?profile=`, `POST /v1/notifications/read`
  (`{id?}`, all when omitted), and `DELETE /v1/notifications/{id}`.
- Push goes through APNs/FCM only when the profile's `notify.push != false`.
  The payload carries the type, the actor's display names and the target id —
  never private Prism data.

## Realtime

`GET /v1/stream` (WebSocket or SSE) emits `{kind, id}` change events for
conversations, messages, notifications, requests and the feed. The client then
re-fetches the changed resource.

## Moderation and safety

- Reports are kept with the reporter and target.
- Rate limits on requests, messages and posts.
- Usernames can be reserved.
- A blocked user is not told they were blocked; actions simply return
  `blocked`.
