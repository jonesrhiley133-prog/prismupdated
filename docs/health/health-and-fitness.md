# Health and Fitness

Health lives at `/health` and in More / customizable navigation. The Home quick
Health action opens its logger. Timeline, Body Map and Episodes use the existing
tracker repository, encrypted database and encrypted system sync. New records
are private. No Health records are posted to social services or notifications.
The logger separates author from subjects, supports multiple subjects, whole
system and unsure, and refreshes new-entry attribution when fronting changes.

## Historical Body Sensations

Mood no longer creates body sensations. Old Mood records remain unchanged for
backup compatibility and existing relationships. Health projects each record
with sensations into `health:mood:<original id>`. Repeating projection after an
old backup restore yields the same ID. Original text, unknown vocabulary, notes,
intensity, timestamps and member attribution are retained. Unknown locations
show **Location unspecified**. Editing in Health persists an override at that
stable ID; it does not rewrite the original mood check-in. Mood history links
open the corresponding Health record. Compatibility routes also redirect
`/mood/body-sensations` and `/mood/body-sensations/:id` to Health.

The shared Body Map editor is used both from Health and from individual
symptoms. Region IDs, body-relative sides, views and optional normalized point
coordinates are persisted. Front-view body-left appears on screen-right;
back-view body-left appears on screen-left. The region list exposes both views,
including individual fingers/toes. Zoom preserves sheet coordinates. A point
offers adjacent candidate regions. Custom descriptor wording is copied into
observations, so renaming or retiring a reusable term cannot rewrite history.
No PluralNova reference was present in the workspace; the outline, hit-region
selection, side labels, companion list and front/back interaction implement the
written requirements rather than copying that app.

Episodes group independent check-ins by `episodeId`. Follow-ups append immutable
observations; correction remains a separate edit. Resolve/reopen preserves
history. Logging counts describe days with records, never symptom-free days.
Health summary export reviews the filtered accessible records and excludes
identity and private notes unless explicitly selected. It is a plaintext JSON
summary, distinct from an encrypted complete Prism backup. Complete backups
continue to retain the original Mood rows and tracker records.

## Privacy boundary

Prism has a system database and fronting identities, not independently
password-authenticated alter accounts. Health reads, editing, links and summary
exports apply the current fronting subjects/author scope and subsystem-isolation
rules. Whole-system records are visible to the unlocked system. The app's
existing PIN and screen-privacy protections still apply. Nested editors stop
showing an edited private record when its scope is no longer accessible. Health
is not indexed in shared record search/link graphs, system-wide body/emotion
correlations or body-sensation Insights summaries.

These controls do not protect against another owner of the same unlocked system
database, nor create a new per-alter server authorization mechanism. The sync
relay receives encrypted system records; no new shared medical backend or social
endpoint has been introduced. Drafts stay in the active editor with Prism's
unsaved-changes guard; no new cross-profile persistent draft cache is used.

## Fitness import diagnosis and changes

The original implementation already used `health` 13.3.1, a native bridge to
Android Health Connect / Apple HealthKit. It was not a simulated provider
connection. The code inspection found these independent defects:

* iOS had usage descriptions but lacked the HealthKit entitlement.
* The connection flag was synced across devices although permission/consent is
  local. A provider selection/flag therefore did not establish local access.
* A failure in any selected data type aborted the entire import; successful
  reads earlier in the operation could be hidden behind a generic failure.
* Sync did not recheck permissions per type, including after revocation.
* Existing daily records could be read from an unloaded/stale UI cache, allowing
  duplicates. Workout deduplication also relied on that cache.
* Imported daily metrics only appeared in a connected, supported-device banner.
  Desktop/disconnected views hid the data despite its presence in storage.
* Daily numeric samples from different apps were added, potentially counting
  mirrored activity twice. Source units and provider edits were not handled
  consistently.

Connected Apps now separates **Connect**, **Manage permissions**, **Sync now**,
**Import date range**, **Disconnect**, and **Import file**. Connection consent is
local to this installation. Each selected data type checks permission, reads
its window, normalizes and persists records, then advances its own cursor.
Failed types retain their cursor for retry. UI state distinguishes unavailable,
permission needed, partial permission, syncing, success, zero records and
failure. HealthKit deliberately does not reveal denied read permission, so an
empty iOS read cannot prove denial or authorization; its detail text says so.

Workout identity includes platform, originating app and provider UUID, using
stable IDs. Existing imports are updated; user corrections differing from the
prior import snapshot are retained. Step totals use the platform aggregate.
Other daily types choose one source per day/type (largest coverage/value, source
ID as deterministic tie-breaker) instead of adding mirrored sources. Different
CSV/native source rows are displayed separately, not added to each other.
Daily metrics remain visible in Fitness after reload or disconnection.
Disconnect stops further reads and retains imports; confirmed removal targets
only the selected native provider, retaining manual entries and CSV imports.
Automatic sync remains foreground-only (at launch and every 30 minutes while
open); no new OS background scheduling is claimed.

## Supported paths and requirements

* **Android:** Health Connect, not a direct Samsung/Garmin/Fitbit account API.
  Other apps must write the requested types to Health Connect first. This
  repository has `FlutterFragmentActivity`, compile/target SDK 36, min SDK 26,
  read permissions, package visibility, rationale and permission-usage alias.
  Runtime availability still gates unsupported devices. Historical reads older
  than 30 days request Health Connect's separate history authorization when
  available. No credentials for a direct provider API are introduced.
* **iOS:** Apple HealthKit read integration and entitlement; usage descriptions
  already existed. Signing/provisioning must enable HealthKit for the app ID.
* **Web/Linux/macOS/Windows:** no live health bridge. CSV import works through
  the platform file picker. Supported layouts are Garmin Activities and Fitbit
  daily activity, with explicit source-account label, date order and distance
  units. Preview shows date range, types, valid/skipped rows before saving.
  Repeat files update stable source records. Fitbit total calories are retained
  as total energy, never mislabeled as active energy.

The installed plugin documentation and current pub.dev package documentation
were consulted. The direct Android developer documentation request was denied
by this environment's network policy, so no claim is made that a newer SDK
configuration has been device-qualified here. The repository already meets the
installed plugin's documented activity/permission requirements.

## Verification boundary

Regression tests exercise legacy projection/backup roundtrip, access checks,
redacted export, sided region IDs, actual Drift persistence across database
close/reopen, concurrent follow-ups and resolve/reopen, quick-log duplicate
submission, author/subject preservation, small/wide light/dark layouts with
large text, and map/list interaction. Fitness gateway fixtures cover partial
and revoked permission, zero results, failure/retry, reconnect, source edits,
manual correction preservation and repeat-sync deduplication. CSV parser tests
use representative synthetic Garmin/Fitbit rows, not a downloaded personal
provider export.

Real provider validation still requires an Android device with Health Connect
and actual workout/step records (including permissions and a source app sharing
data), or a signed iPhone HealthKit build with actual records. Linux headless
and widget tests cannot validate OS permission dialogs, Health Connect source
configuration, HealthKit provisioning, or background execution. No real-device
sync result is claimed by these fixtures.

## Body Sheet and visual review

The Body Map tab contains a front/back Body Sheet overview and a dedicated
logging action. The shared editor uses Prism's page scaffold, pinned header,
segmented controls, surfaces, selectors, chips and text fields. It has named
face, left-hand, right-hand and feet detail views, numbered markers, region
shading, and a searchable front/back directory. Detail views change only the
viewport transform; saved body-relative sides and normalized points stay intact.
Region-only selections remain distinguishable from precise points. Each location
supports searchable descriptors, reusable custom terms, intensity, start/end
observations, notes and a spread endpoint.

Symptom detail forms group timing, context, daily impact, measurements and
locations. Timeline readouts use human-readable labels and show location notes,
intensity, timing and spreading observations. Advanced search/date/state filters
collapse to keep the primary logging action and timeline within easy reach.

To capture review images from the actual Flutter widgets with synthetic records:

```bash
flutter test tool/health_screenshots_test.dart
```

The capture tool uses Prism's light/dark themes and renders mobile and desktop
layouts. Images are written to `test-results/health-screenshots/`; override with
`--dart-define=PRISM_HEALTH_SCREENSHOT_DIR=/path/to/review` when needed. These are
UI previews with fixture records, not evidence of live provider synchronization.
