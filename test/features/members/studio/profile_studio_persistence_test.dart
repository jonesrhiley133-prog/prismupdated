import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/domain/repositories/entity_repository.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/members/studio/profile_studio.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';

import '../../../helpers/fake_repositories.dart';

class _FakeTrackers implements EntityRepository<TrackerRecord> {
  _FakeTrackers(List<TrackerRecord> seed) : rows = [...seed];
  final List<TrackerRecord> rows;
  final _c = StreamController<List<TrackerRecord>>.broadcast();
  void _emit() => _c.add([...rows]);
  @override
  Stream<List<TrackerRecord>> watchAll() async* {
    yield [...rows];
    yield* _c.stream;
  }

  @override
  Future<List<TrackerRecord>> getAll() async => [...rows];
  @override
  Future<TrackerRecord?> getById(String id) async => rows.where((r) => r.id == id).firstOrNull;
  @override
  Future<void> create(TrackerRecord item) async {
    rows.add(item);
    _emit();
  }

  @override
  Future<void> update(TrackerRecord item) async {
    rows[rows.indexWhere((r) => r.id == item.id)] = item;
    _emit();
  }

  @override
  Future<void> delete(String id) async {
    rows.removeWhere((r) => r.id == id);
    _emit();
  }
}

void main() {
  final t = DateTime(2026);
  final avatar = Uint8List.fromList(List.generate(64, (i) => i));

  testWidgets('studio loads the saved profile, edits the bio in place and keeps the avatar', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(500, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final members = FakeMemberRepository()..seed([Member(id: 'm1', name: 'Ash', bio: 'Old bio', avatarImageData: avatar, createdAt: t)]);
    final trackers = _FakeTrackers([
      TrackerRecord(id: 'p1', kind: TrackerKind.memberProfile, parentId: 'm1', memberId: 'm1', createdAt: t, modifiedAt: t).withFields({
        'cfg': {'subtitle': 'Night owl', 'roles': [{'name': 'Host'}]},
      }),
    ]);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        memberRepositoryProvider.overrideWithValue(members),
        trackerRecordRepositoryProvider.overrideWithValue(trackers),
        allMemberListProvider.overrideWith((ref) => Stream.value(const <Member>[])),
        memberNamePreferDisplayProvider.overrideWithValue(false),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: [Locale('en')],
        home: ProfileStudioScreen(memberId: 'm1'),
      ),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Saved values are loaded.
    expect(tester.widgetList<EditableText>(find.byType(EditableText)).map((e) => e.controller.text), contains('Night owl'));
    expect(find.text('Host'), findsWidgets);

    // Edit the bio: it replaces the old text.
    final bioField = find.byWidgetPredicate((w) => w is PrismTextField && w.labelText == 'Bio');
    await tester.scrollUntilVisible(bioField, 300, scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first);
    final bio = find.descendant(of: bioField, matching: find.byType(EditableText));
    await tester.enterText(bio, 'New bio');
    await tester.pump();

    await tester.tap(find.text('Save').last);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final saved = await members.getMemberById('m1');
    expect(saved!.bio, 'New bio');
    expect(saved.avatarImageData, avatar);
    final profiles = trackers.rows.where((r) => r.kind == TrackerKind.memberProfile).toList();
    expect(profiles, hasLength(1));
    final cfg = profiles.single.fields['cfg'] as Map;
    expect(cfg['subtitle'], 'Night owl');
    await tester.pump(const Duration(seconds: 8));
  });
}
