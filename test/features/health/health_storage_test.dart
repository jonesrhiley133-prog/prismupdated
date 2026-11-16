import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/core/database/app_database.dart' as db;
import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/data/repositories/drift_tracker_record_repository.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/health/health_data.dart';
import 'package:prism_plurality/features/subsystems/hub/subsystem_data.dart';

void main() {
  test(
    'private check-in and appended episode history persist after database reopen; unauthorized edits fail',
    () async {
      final dir = await Directory.systemTemp.createTemp('prism-health-test-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/health.sqlite');
      var database = db.AppDatabase(NativeDatabase(file));
      var repo = DriftTrackerRecordRepository(database.trackerRecordsDao, null);
      var container = ProviderContainer(
        overrides: [
          trackerRecordRepositoryProvider.overrideWithValue(repo),
          healthViewersProvider.overrideWithValue({'a'}),
        ],
      );
      final now = DateTime.now();
      final checkIn =
          TrackerRecord(
            id: 'check-in',
            kind: healthCheckIn,
            title: 'Headache',
            occurredAt: now,
            createdAt: now,
            modifiedAt: now,
            isPrivate: true,
          ).withFields({
            'subjectMode': 'alters',
            'subjects': ['a'],
            'author': 'a',
            'status': 'open',
            'symptoms': [
              {
                'term': 'headache',
                'spots': [
                  {
                    'region': 'front_left_ring_finger',
                    'side': 'left',
                    'view': 'front',
                    'x': .821,
                    'y': .54,
                  },
                ],
              },
            ],
          });
      final episode = checkIn.copyWith(
        id: 'episode',
        kind: healthEpisode,
        title: 'This week',
      );
      final actions = container.read(healthActionsProvider);
      await actions.save(checkIn);
      await actions.save(episode);
      await actions.save(checkIn.withFields({'episodeId': 'episode'}));
      await Future.wait([
        actions.followUp(episode, 'open', note: 'Still happening'),
        actions.followUp(episode, 'changed', note: 'Different today'),
      ]);
      await actions.followUp(episode, 'resolved');
      await actions.followUp(episode, 'reopened');
      container.dispose();
      await database.close();
      database = db.AppDatabase(NativeDatabase(file));
      repo = DriftTrackerRecordRepository(database.trackerRecordsDao, null);
      final restored = await repo.getById('episode');
      expect(restored!.str('status'), 'reopened');
      expect(healthMaps(restored.fields['observations']).length, 4);
      final saved = await repo.getById('check-in');
      expect(saved!.str('episodeId'), 'episode');
      expect(saved.isPrivate, true);
      final spot = healthMaps(
        healthMaps(saved.fields['symptoms']).single['spots'],
      ).single;
      expect(spot['side'], 'left');
      expect(spot['region'], 'front_left_ring_finger');
      container = ProviderContainer(
        overrides: [
          trackerRecordRepositoryProvider.overrideWithValue(repo),
          healthViewersProvider.overrideWithValue({'b'}),
        ],
      );
      await expectLater(
        container
            .read(healthActionsProvider)
            .save(saved.copyWith(title: 'Forbidden correction')),
        throwsStateError,
      );
      container.dispose();
      container = ProviderContainer(
        overrides: [
          trackerRecordRepositoryProvider.overrideWithValue(repo),
          healthViewersProvider.overrideWithValue({'a'}),
        ],
      );
      container
          .read(isolatedMembersProvider.notifier)
          .set(IsolatedMembers({'a'}));
      await expectLater(
        container.read(healthActionsProvider).save(saved),
        throwsStateError,
      );
      container.dispose();
      await database.close();
    },
  );
}
