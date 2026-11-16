import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_plurality/core/constants/fronting_namespaces.dart';
import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/features/fronting/providers/fronting_providers.dart';
import 'package:prism_plurality/features/subsystems/hub/subsystem_data.dart';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/domain/models/mood_entry.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/health/health_data.dart';
import 'package:prism_plurality/features/health/body_regions.dart';

void main() {
  test(
    'legacy projection is repeatable after backup restoration and preserves original values',
    () {
      final at = DateTime.utc(2024, 2, 3, 16, 45);
      final original = MoodEntry(
        id: 'original-mood-id',
        memberId: 'alter-a',
        bodySensations: ['hands:custom:old term', 'unrecognized free text'],
        intensity: 8,
        note: 'original private note',
        recordedAt: at,
        createdAt: at.add(const Duration(days: 1)),
        modifiedAt: at.add(const Duration(days: 2)),
      );
      final restored = MoodEntry.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );
      final before = legacyHealthEntry(original),
          after = legacyHealthEntry(restored);
      expect(after.toJson(), before.toJson());
      expect(after.id, 'health:mood:original-mood-id');
      expect(after.str('legacyMoodId'), original.id);
      expect(after.fields['legacyRaw'], original.bodySensations);
      expect(after.body, original.note);
      expect(after.occurredAt, at);
      expect(after.createdAt, original.createdAt);
      expect(after.fields['legacyIntensity'], 8);
      expect(after.memberId, 'alter-a');
      expect(after.isPrivate, true);
      final spots = healthMaps(
        healthMaps(after.fields['symptoms']).single['spots'],
      );
      expect(spots.first['descriptors'], ['custom:old term']);
      expect(spots.last['legacyText'], 'unrecognized free text');
    },
  );
  test(
    'private subject and author scope is independent from filter selection',
    () {
      final now = DateTime.now();
      final r =
          TrackerRecord(
            id: 'private',
            kind: healthCheckIn,
            isPrivate: true,
            createdAt: now,
            modifiedAt: now,
          ).withFields({
            'author': 'author',
            'subjects': ['subject'],
            'subjectMode': 'alters',
          });
      expect(canViewHealth(r, {'author'}), true);
      expect(canViewHealth(r, {'subject'}), true);
      expect(canViewHealth(r, {'other'}), false);
      expect(canViewHealth(r, {}), false);
      expect(
        canViewHealth(r.withFields({'subjectMode': 'system'}), {'other'}),
        true,
      );
    },
  );
  test(
    'review export excludes nested private notes and identity by default',
    () {
      final now = DateTime.now();
      final r =
          TrackerRecord(
            id: 'r',
            kind: healthCheckIn,
            title: 'Headache',
            body: 'PRIVATE TOP NOTE',
            isPrivate: true,
            createdAt: now,
            modifiedAt: now,
          ).withFields({
            'author': 'PRIVATE AUTHOR',
            'subjects': ['PRIVATE SUBJECT'],
            'symptoms': [
              {
                'term': 'headache',
                'notes': 'PRIVATE SYMPTOM NOTE',
                'spots': [
                  {'region': 'front_forehead', 'notes': 'PRIVATE SPOT NOTE'},
                ],
              },
            ],
            'observations': [
              {
                'status': 'open',
                'note': 'PRIVATE FOLLOWUP NOTE',
                'author': 'PRIVATE AUTHOR',
              },
            ],
          });
      final redacted = healthSummary([r]);
      expect(redacted, isNot(contains('PRIVATE')));
      final explicit = healthSummary([r], notes: true, identity: true);
      expect(explicit, contains('PRIVATE SPOT NOTE'));
      expect(explicit, contains('PRIVATE AUTHOR'));
    },
  );
  test(
    'body side/view identifiers and normalized precise placement survive JSON resize roundtrip',
    () {
      final finger = anatomicalRegions.singleWhere(
        (r) => r.id == 'front_left_ring_finger',
      );
      final blade = anatomicalRegions.singleWhere(
        (r) => r.id == 'back_right_shoulder_blade',
      );
      expect(finger.side, 'left');
      expect(finger.x, greaterThan(.5));
      expect(blade.side, 'right');
      expect(blade.view, 'back');
      expect(blade.x, greaterThan(.5));
      expect(
        anatomicalRegions.map((r) => r.id).toSet().length,
        anatomicalRegions.length,
      );
      for (final r in anatomicalRegions) {
        expect(r.x, inInclusiveRange(0, 1));
        expect(r.y, inInclusiveRange(0, 1));
      }
      final spot =
          jsonDecode(
                jsonEncode({
                  'region': finger.id,
                  'side': finger.side,
                  'view': finger.view,
                  'x': finger.x,
                  'y': finger.y,
                }),
              )
              as Map;
      expect((spot['x'] as num) * 320 / 320, (spot['x'] as num) * 800 / 800);
    },
  );
  test(
    'Unknown and isolated fronters never become invalid author choices',
    () async {
      final at = DateTime.now();
      final c = ProviderContainer(
        overrides: [
          activeSessionsProvider.overrideWith(
            (ref) => Stream.value([
              FrontingSession(
                id: 'unknown',
                startTime: at,
                memberId: unknownSentinelMemberId,
              ),
              FrontingSession(
                id: 'isolated',
                startTime: at,
                memberId: 'hidden',
              ),
            ]),
          ),
        ],
      );
      addTearDown(c.dispose);
      c.read(isolatedMembersProvider.notifier).set(IsolatedMembers({'hidden'}));
      c.listen(activeSessionsProvider, (_, _) {});
      await c.read(activeSessionsProvider.future);
      expect(c.read(healthViewersProvider), isEmpty);
    },
  );
  test(
    'restored Unknown-attributed body records remain accessible as Unsure',
    () {
      final at = DateTime.now();
      final mood = MoodEntry(
        id: 'unknown-mood',
        memberId: unknownSentinelMemberId,
        bodySensations: ['chest:tight'],
        recordedAt: at,
        createdAt: at,
        modifiedAt: at,
      );
      final migrated = legacyHealthEntry(mood);
      expect(migrated.memberId, unknownSentinelMemberId);
      expect(migrated.str('subjectMode'), 'unsure');
      expect(migrated.strings('subjects'), isEmpty);
      expect(canViewHealth(migrated, {'a'}), true);
    },
  );
}
