import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/features/calendar/providers/calendar_providers.dart';
import 'package:prism_plurality/features/calendar/utils/recurrence.dart';
import 'package:prism_plurality/features/calendar/views/event_detail_sheet.dart';
import 'package:prism_plurality/features/journal/views/journal_entry_sheet.dart';
import 'package:prism_plurality/features/links/models/record_ref.dart';
import 'package:prism_plurality/features/links/widgets/related_records.dart';
import 'package:prism_plurality/features/locations/providers/location_providers.dart';
import 'package:prism_plurality/features/locations/views/location_editor_sheet.dart';
import 'package:prism_plurality/features/mood/providers/mood_providers.dart';
import 'package:prism_plurality/features/mood/views/log_mood_sheet.dart';
import 'package:prism_plurality/features/sleep_log/views/sleep_details_sheet.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Openers for tracker kinds owned by newer modules; each module registers
/// its own so this file does not depend on all of them.
final Map<String, void Function(BuildContext context, String id)>
recordKindOpeners = {};

/// Openers for whole record types owned by other modules (habits).
final Map<String, void Function(BuildContext context, String id)>
recordTypeOpeners = {};

/// Opens the right screen or sheet for [info].
Future<void> openRecord(
  BuildContext context,
  WidgetRef ref,
  RecordInfo info,
) async {
  final id = info.ref.id;
  switch (info.ref.type) {
    case RecordRef.member:
      await context.push(AppRoutePaths.member(id));
    case RecordRef.front:
      final s = await ref
          .read(frontingSessionRepositoryProvider)
          .getSessionById(id);
      if (s == null || !context.mounted) return;
      if (s.sessionType == SessionType.sleep) {
        await showSleepDetails(context, s);
      } else {
        await context.push(AppRoutePaths.session(id));
      }
    case RecordRef.mood:
      final m = (ref.read(moodEntriesProvider).value ?? const [])
          .where((e) => e.id == id)
          .firstOrNull;
      if (m != null) await showLogMoodSheet(context, editing: m);
    case RecordRef.location:
      final l = (ref.read(savedLocationsProvider).value ?? const [])
          .where((e) => e.id == id)
          .firstOrNull;
      if (l != null) await showLocationEditor(context, editing: l);
    case RecordRef.event:
      final e = (ref.read(calendarEventsProvider).value ?? const [])
          .where((x) => x.id == id)
          .firstOrNull;
      if (e != null) {
        await showEventDetailSheet(
          context,
          CalendarOccurrence(event: e, start: e.startAt, end: e.endAt),
        );
      }
    case RecordRef.habit:
      await context.push(AppRoutePaths.habit(id));
    case RecordRef.habitLog:
      recordTypeOpeners[RecordRef.habitLog]?.call(context, id);
    case RecordRef.rec:
      final kind = info.kind;
      if (kind == TrackerKind.journalEntry) {
        await showJournalEntry(context, id);
        return;
      }
      final opener = kind == null ? null : recordKindOpeners[kind];
      if (opener != null) {
        opener(context, id);
        return;
      }
      await showGenericRecord(context, id);
  }
}

/// Read-only view of any tracker record plus its connections.
Future<void> showGenericRecord(BuildContext context, String id) =>
    PrismSheet.showFullScreen(
      context: context,
      builder: (ctx, scroll) => _GenericRecordSheet(id: id, scroll: scroll),
    );

class _GenericRecordSheet extends ConsumerWidget {
  const _GenericRecordSheet({required this.id, required this.scroll});
  final String id;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r =
        (ref.watch(trackerRecordsProvider).value ?? const <TrackerRecord>[])
            .where((x) => x.id == id)
            .firstOrNull;
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        children: [
          PrismSheetTopBar(title: r?.title ?? ''),
          Expanded(
            child: r == null
                ? Center(
                    child: Text(
                      tr(
                        context,
                        'This record was deleted.',
                        'Este registro fue eliminado.',
                      ),
                    ),
                  )
                : ListView(
                    controller: scroll,
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        moduleFor(
                          moduleForKind(r.kind) ?? 'other',
                        ).label(context),
                        style: theme.textTheme.labelMedium,
                      ),
                      if (r.occurredAt != null)
                        Text(shortDate(context, r.occurredAt)),
                      if (r.body != null) ...[
                        const SizedBox(height: 12),
                        PrivateReveal(
                          isPrivate: r.isPrivate,
                          child: Text(r.body!),
                        ),
                      ],
                      if (r.tags.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        TagWrap(tags: r.tags),
                      ],
                      RelatedRecordsSection(
                        self: RecordRef(RecordRef.rec, r.id),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
