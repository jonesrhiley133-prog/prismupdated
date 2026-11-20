import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/domain/models/mood_entry.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/domain/repositories/entity_repository.dart';
import 'package:prism_plurality/features/health/body_atlas.dart';
import 'package:prism_plurality/features/health/health_model.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';

class _Repo implements EntityRepository<TrackerRecord> {
  final rows = <TrackerRecord>[];
  @override
  Stream<List<TrackerRecord>> watchAll() async* {
    yield [...rows];
  }

  @override
  Future<List<TrackerRecord>> getAll() async => [...rows];
  @override
  Future<TrackerRecord?> getById(String id) async => rows.where((r) => r.id == id).firstOrNull;
  @override
  Future<void> create(TrackerRecord item) async => rows.add(item);
  @override
  Future<void> update(TrackerRecord item) async => rows[rows.indexWhere((r) => r.id == item.id)] = item;
  @override
  Future<void> delete(String id) async => rows.removeWhere((r) => r.id == id);
}

MoodEntry _mood(String id, List<String> body, {String? member, String? note}) {
  final t = DateTime(2026, 2, 1, 10);
  return MoodEntry(id: id, memberId: member, bodySensations: body, note: note, intensity: 7, recordedAt: t, createdAt: t, modifiedAt: t);
}

void main() {
  group('Mood → Health migration', () {
    test('legacy sensations keep their text, attribution, time and stable ids', () {
      final spots = legacySpotsFrom([
        _mood('m1', ['chest:tight', 'stomach', 'mystery:fizzy'], member: 'alter-a', note: 'after the call'),
      ], const {});
      expect(spots.map((s) => s.id), ['mood:m1:0', 'mood:m1:1', 'mood:m1:2']);
      expect(spots[0].regionId, 'chest');
      expect(spots[0].descriptors.single, (id: 'tight', label: 'Tight'));
      expect(spots[1].regionId, 'abdomen_mid');
      expect(spots[1].descriptors, isEmpty);
      // Unknown regions keep their original text as a custom location.
      expect(spots[2].regionId, customLocation);
      expect(spots[2].customLabel, 'mystery');
      expect(spots[2].descriptors.single.label, 'fizzy');
      expect(spots.every((s) => s.legacyText != null && s.notes == 'after the call' && s.at == DateTime(2026, 2, 1, 10)), isTrue);
      expect(legacyAttribution(spots.first.legacyMood!).subjects, ['alter-a']);
    });

    test('running again, or after restoring an old backup, gives the same result', () {
      final moods = [_mood('m1', ['head:aching']), _mood('m2', ['back'])];
      final a = legacySpotsFrom(moods, const {}).map((s) => (s.id, s.regionId, s.legacyText)).toList();
      final b = legacySpotsFrom([...moods.reversed], const {}).map((s) => (s.id, s.regionId, s.legacyText)).toSet();
      expect(b, a.toSet());
    });

    test('an entry edited in Health replaces its Mood original exactly once', () {
      final spots = legacySpotsFrom([_mood('m1', ['head:aching', 'back'])], {'mood:m1:0'});
      expect(spots.map((s) => s.id), ['mood:m1:1']);
    });

    test('an empty region is shown as unspecified, not dropped', () {
      final s = legacySpotsFrom([_mood('m1', [':tight'])], const {}).single;
      expect(s.regionId, hardToLocate);
      expect(s.placeLabel(false), 'Hard to locate');
    });
  });

  group('privacy', () {
    test('private entries are visible to their subjects and author only', () {
      const a = Attribution(subjects: ['mira'], author: 'rowan');
      expect(a.visibleTo('mira'), isTrue);
      expect(a.visibleTo('rowan'), isTrue);
      expect(a.visibleTo('sol'), isFalse);
      expect(a.visibleTo(null), isFalse);
      expect(a.copyWith(visibility: HealthVisibility.system).visibleTo('sol'), isTrue);
      expect(const Attribution(scope: HealthScope.system).visibleTo(null), isTrue);
      expect(const Attribution(scope: HealthScope.unsure).visibleTo('sol'), isTrue);
    });

    test('a viewer without access cannot open a record by id', () async {
      final repo = _Repo();
      final c = ProviderContainer(overrides: [trackerRecordRepositoryProvider.overrideWithValue(repo), healthViewerProvider.overrideWithValue('sol')]);
      addTearDown(c.dispose);
      final store = c.read(healthStoreProvider);
      final rec = await store.saveCheckin(clientId: 'x', who: const Attribution(subjects: ['mira'], author: 'mira'), symptoms: [HealthSymptom(label: 'Headache')], happenedAt: DateTime.now());
      c.listen(trackerRecordsProvider, (_, _) {});
      c.listen(visibleHealthRecordsProvider, (_, _) {});
      await c.read(trackerRecordsProvider.future);
      expect(c.read(visibleHealthRecordsProvider).value, isEmpty);
      expect(c.read(hiddenHealthCountProvider), 1);
      expect(rec.isPrivate, isTrue, reason: 'kept out of other features');
    });
  });

  group('saving', () {
    test('a double tap or retry updates the same check-in', () async {
      final repo = _Repo();
      final c = ProviderContainer(overrides: [trackerRecordRepositoryProvider.overrideWithValue(repo), healthViewerProvider.overrideWithValue('mira')]);
      addTearDown(c.dispose);
      final store = c.read(healthStoreProvider);
      const who = Attribution(subjects: ['mira'], author: 'mira');
      await store.saveCheckin(clientId: 'same', who: who, symptoms: [HealthSymptom(label: 'Cough')], happenedAt: DateTime(2026, 3, 1, 9));
      await store.saveCheckin(clientId: 'same', who: who, symptoms: [HealthSymptom(label: 'Cough'), HealthSymptom(label: 'Fatigue')], happenedAt: DateTime(2026, 3, 1, 9));
      final checkins = repo.rows.where((r) => r.kind == TrackerKind.healthCheckin).toList();
      expect(checkins, hasLength(1));
      expect(checkins.single.symptoms.map((s) => s.label), ['Cough', 'Fatigue']);
      expect(Attribution.of(checkins.single).author, 'mira');
    });

    test('follow-ups append; the original entry is unchanged', () async {
      final repo = _Repo();
      final c = ProviderContainer(overrides: [trackerRecordRepositoryProvider.overrideWithValue(repo), healthViewerProvider.overrideWithValue('mira')]);
      addTearDown(c.dispose);
      final store = c.read(healthStoreProvider);
      final rec = await store.saveCheckin(clientId: 'c', who: const Attribution(subjects: ['mira'], author: 'mira'), symptoms: [HealthSymptom(label: 'Sore throat', severity: Severity.moderate)], happenedAt: DateTime(2026, 3, 1));
      await store.addFollowup(clientId: 'f1', checkin: rec, status: FollowStatus.still, at: DateTime(2026, 3, 2));
      await store.addFollowup(clientId: 'f2', checkin: rec, status: FollowStatus.resolved, at: DateTime(2026, 3, 4));
      final fus = repo.rows.where((r) => r.kind == TrackerKind.healthFollowup).toList();
      expect(fus, hasLength(2));
      expect(latestStatus(rec, fus), FollowStatus.resolved);
      expect(repo.rows.firstWhere((r) => r.id == rec.id).symptoms.single.severity, Severity.moderate);
    });

    test('an episode keeps its whole history through resolve and reopen', () async {
      final repo = _Repo();
      final c = ProviderContainer(overrides: [trackerRecordRepositoryProvider.overrideWithValue(repo), healthViewerProvider.overrideWithValue('mira')]);
      addTearDown(c.dispose);
      final store = c.read(healthStoreProvider);
      const who = Attribution(subjects: ['mira'], author: 'mira');
      var ep = await store.saveEpisode(clientId: 'e', who: who, title: 'Cold', start: DateTime(2026, 3, 1), state: EpisodeState.open);
      ep = await store.saveEpisode(clientId: 'e', existing: ep, who: who, title: 'Cold', start: DateTime(2026, 3, 1), state: EpisodeState.resolved, note: 'gone', end: DateTime(2026, 3, 5));
      ep = await store.saveEpisode(clientId: 'e', existing: ep, who: who, title: 'Cold', start: DateTime(2026, 3, 1), state: EpisodeState.reopened, note: 'back again');
      expect(ep.episodeLog.map((l) => l.state), [EpisodeState.open, EpisodeState.resolved, EpisodeState.reopened]);
      expect(ep.episodeLog[1].note, 'gone');
      expect(repo.rows.where((r) => r.kind == TrackerKind.healthEpisode), hasLength(1));
    });

    test('symptoms survive a JSON round trip, including approximate and unknown times', () {
      final s = HealthSymptom(label: 'Headache', termId: 'headache', onset: DateTime(2026, 3, 1, 8), onsetPrecision: TimePrecision.approx, endPrecision: TimePrecision.unknown, severity: Severity.severe, score: 7, course: ['worsening'], impact: ['sleep'], tempValue: 38.2, spotIds: ['s1']);
      final back = HealthSymptom.fromJson(s.toJson());
      expect((back.label, back.onset, back.onsetPrecision, back.endPrecision, back.severity, back.score, back.tempValue, back.tempUnit),
          ('Headache', DateTime(2026, 3, 1, 8), TimePrecision.approx, TimePrecision.unknown, Severity.severe, 7, 38.2, 'C'));
      expect(back.course, ['worsening']);
      expect(back.impact, ['sleep']);
      expect(back.spotIds, ['s1']);
    });

    test('days with a logged symptom count only logged days', () {
      final t = DateTime(2026, 3, 1);
      TrackerRecord c(DateTime at) => TrackerRecord(id: '$at', kind: TrackerKind.healthCheckin, occurredAt: at, createdAt: at, modifiedAt: at);
      final n = daysWithLoggedSymptom([c(t), c(t.add(const Duration(hours: 5))), c(t.add(const Duration(days: 2)))], t, t.add(const Duration(days: 7)));
      expect(n, 2);
    });
  });

  group('Body Map anatomy', () {
    Offset scaled(BodySheet s, double x, double y) => Offset(x * s.size.width, y * s.size.height);

    test('the left ring finger is found on the left hand sheet', () {
      final sheet = sheetFor(BodyView.handPalm, side: BodySide.left);
      final ring = sheet.shapes.firstWhere((s) => s.regionId == 'finger_ring');
      final c = ring.path.getBounds().center;
      final hit = hitTestSheet(sheet, c, slop: 0);
      expect(hit.primary!.regionId, 'finger_ring');
      expect(hit.primary!.side, BodySide.left);
      // Normalised coordinates map back to the same place at any size.
      final p = scaled(sheet, c.dx / sheet.size.width, c.dy / sheet.size.height);
      expect(hitTestSheet(sheet, p, slop: 0).primary!.regionId, 'finger_ring');
    });

    test('front and back views use the body’s own sides', () {
      final front = sheetFor(BodyView.front);
      final back = sheetFor(BodyView.back);
      // Viewer's left on the front is the body's right; on the back, its left.
      expect(hitTestSheet(front, const Offset(84, 104), slop: 0).primary!.side, BodySide.right);
      final blade = hitTestSheet(back, const Offset(116, 107), slop: 0).primary!;
      expect((blade.regionId, blade.side), ('shoulder_blade', BodySide.right));
    });

    test('a tap between wrist and forearm offers both', () {
      final front = sheetFor(BodyView.front);
      final wrist = front.shapes.firstWhere((s) => s.regionId == 'wrist_front' && s.side == BodySide.right).path.getBounds();
      final hit = hitTestSheet(front, Offset(wrist.center.dx, wrist.top + 1));
      final ids = {hit.primary!.regionId, for (final a in hit.alternatives) a.regionId};
      expect(ids, containsAll(['wrist_front', 'forearm_front']));
    });

    test('every region in the list can be found by name', () {
      expect(searchRegions('pinky', false).map((r) => r.id), contains('finger_little'));
      expect(searchRegions('scapula', false).map((r) => r.id), contains('shoulder_blade'));
      for (final id in ['scalp', 'crown', 'temple', 'eyelid', 'sinus', 'gums', 'tongue', 'sternum', 'flank', 'tailbone', 'fingertips', 'inner_thigh', 'knee_back', 'arch', 'ball_of_foot', 'toe_little']) {
        expect(regionById.containsKey(id), isTrue, reason: id);
      }
    });

    test('region-specific words come first and custom words are searchable', () {
      expect(descriptorsFor('ear').first.id, 'ringing');
      expect(searchDescriptors('ear', 'tinnitus', false).map((d) => d.id), ['ringing']);
      expect(descriptorsFor('knee').map((d) => d.id), contains('giving_way'));
    });
  });
}
