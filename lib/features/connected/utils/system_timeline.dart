import 'package:prism_plurality/domain/models/calendar_event.dart';
import 'package:prism_plurality/domain/models/cycle_entry.dart';
import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/domain/models/location.dart';
import 'package:prism_plurality/domain/models/mood_entry.dart';
import 'package:prism_plurality/domain/models/note.dart';
import 'package:prism_plurality/domain/models/work.dart';
import 'package:prism_plurality/features/calendar/utils/recurrence.dart';

/// Kinds of things on the System Timeline (also used as filters).
enum TimelineKind { front, sleep, mood, location, work, event, journal, cycle }

/// One moment on the System Timeline.
class SystemTimelineItem {
  const SystemTimelineItem({
    required this.time,
    required this.kind,
    required this.isStart,
    this.end,
    this.memberId,
    this.mood,
    this.locationId,
    this.jobId,
    this.event,
    this.note,
    this.moodEntry,
    this.cycleEntry,
    this.frontingSession,
  });

  final DateTime time;
  final TimelineKind kind;

  /// Start of a span (true) or its end (false); point events are starts.
  final bool isStart;

  /// End of the span this item starts, when known.
  final DateTime? end;
  final String? memberId;
  final int? mood;
  final String? locationId;
  final String? jobId;
  final CalendarOccurrence? event;
  final Note? note;
  final MoodEntry? moodEntry;
  final CycleEntry? cycleEntry;
  final FrontingSession? frontingSession;
}

/// Builds the timeline for [day] (local) from everything Prism tracks,
/// newest first. Spans that cross midnight show their start and/or end on
/// the days they happen.
List<SystemTimelineItem> buildSystemTimeline({
  required DateTime day,
  required DateTime now,
  required List<FrontingSession> fronting,
  required List<MoodEntry> moods,
  required List<LocationSession> locations,
  required List<WorkSession> work,
  required List<CalendarEvent> events,
  required List<Note> notes,
  required List<CycleEntry> cycle,
}) {
  final start = DateTime(day.year, day.month, day.day);
  final end = DateTime(day.year, day.month, day.day + 1);
  bool inDay(DateTime t) => !t.isBefore(start) && t.isBefore(end);
  final out = <SystemTimelineItem>[];

  for (final s in fronting) {
    final kind = s.isSleep ? TimelineKind.sleep : TimelineKind.front;
    if (inDay(s.startTime)) {
      out.add(
        SystemTimelineItem(
          time: s.startTime,
          kind: kind,
          isStart: true,
          end: s.endTime,
          memberId: s.memberId,
          frontingSession: s,
        ),
      );
    }
    final e = s.endTime;
    if (e != null && inDay(e)) {
      out.add(
        SystemTimelineItem(
          time: e,
          kind: kind,
          isStart: false,
          memberId: s.memberId,
          frontingSession: s,
        ),
      );
    }
  }
  for (final m in moods.where((m) => inDay(m.recordedAt))) {
    out.add(
      SystemTimelineItem(
        time: m.recordedAt,
        kind: TimelineKind.mood,
        isStart: true,
        memberId: m.memberId,
        mood: m.mood,
        moodEntry: m,
      ),
    );
  }
  for (final l in locations) {
    if (inDay(l.startedAt)) {
      out.add(
        SystemTimelineItem(
          time: l.startedAt,
          kind: TimelineKind.location,
          isStart: true,
          end: l.endedAt,
          locationId: l.locationId,
        ),
      );
    }
    final e = l.endedAt;
    if (e != null && inDay(e)) {
      out.add(
        SystemTimelineItem(
          time: e,
          kind: TimelineKind.location,
          isStart: false,
          locationId: l.locationId,
        ),
      );
    }
  }
  for (final w in work) {
    if (inDay(w.startedAt)) {
      out.add(
        SystemTimelineItem(
          time: w.startedAt,
          kind: TimelineKind.work,
          isStart: true,
          end: w.endedAt,
          jobId: w.jobId,
          memberId: w.memberId,
        ),
      );
    }
    final e = w.endedAt;
    if (e != null && inDay(e)) {
      out.add(
        SystemTimelineItem(
          time: e,
          kind: TimelineKind.work,
          isStart: false,
          jobId: w.jobId,
        ),
      );
    }
  }
  for (final o in expandCalendarEvents(events, start, end)) {
    final t = o.start.isBefore(start) ? start : o.start;
    out.add(
      SystemTimelineItem(
        time: t,
        kind: TimelineKind.event,
        isStart: true,
        end: o.end,
        event: o,
      ),
    );
  }
  for (final n in notes.where((n) => inDay(n.date))) {
    out.add(
      SystemTimelineItem(
        time: n.date,
        kind: TimelineKind.journal,
        isStart: true,
        memberId: n.memberId,
        note: n,
      ),
    );
  }
  final key =
      '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  for (final c in cycle.where((c) => c.date == key)) {
    out.add(
      SystemTimelineItem(
        time: start,
        kind: TimelineKind.cycle,
        isStart: true,
        cycleEntry: c,
      ),
    );
  }
  out.sort((a, b) => b.time.compareTo(a.time));
  return out;
}
