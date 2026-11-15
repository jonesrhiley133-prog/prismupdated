import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/members/studio/profile_config.dart';
import 'package:prism_plurality/features/members/studio/profile_studio.dart';
import 'package:prism_plurality/features/members/studio/profile_view.dart';
import 'package:prism_plurality/features/subsystems/hub/subsystem_hub.dart';
import 'package:prism_plurality/features/subsystems/hub/subsystem_profile.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';

final _t = DateTime(2026);
final _members = [Member(id: 'a', name: 'Ash', createdAt: _t), Member(id: 'b', name: 'Bee', createdAt: _t)];

Widget _app(Widget home, List<TrackerRecord> records) => ProviderScope(
  overrides: [
    trackerRecordsProvider.overrideWith((ref) => Stream.value(records)),
    activeMemberListProvider.overrideWith((ref) => Stream.value(_members)),
    allMemberListProvider.overrideWith((ref) => Stream.value(_members)),
    memberNamePreferDisplayProvider.overrideWithValue(false),
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: const [Locale('en')],
    home: MediaQuery(data: const MediaQueryData(size: Size(400, 900), disableAnimations: true), child: home),
  ),
);

void main() {
  testWidgets('empty hub shows the create button and Learn more', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(const SubsystemHubScreen(), const []));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Create a subsystem'), findsOneWidget);
    expect(find.text('Learn more'), findsOneWidget);
  });

  testWidgets('hub places subsystems in orbit and lists them', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final s = TrackerRecord(id: 's1', kind: TrackerKind.subsystem, title: 'Moonlight', createdAt: _t, modifiedAt: _t).withFields({'isolate': true});
    final m = TrackerRecord(id: 'm1', kind: TrackerKind.subMember, parentId: 's1', memberId: 'b', createdAt: _t, modifiedAt: _t);
    await tester.pumpWidget(_app(const SubsystemHubScreen(), [s, m]));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Moonlight'), findsWidgets);
    expect(find.text('Create a subsystem'), findsNothing);
  });

  testWidgets('subsystem profile shows members and tabs', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final s = TrackerRecord(id: 's1', kind: TrackerKind.subsystem, title: 'Moonlight', createdAt: _t, modifiedAt: _t).withFields({'isolate': true, 'founder': 'b'});
    final m = TrackerRecord(id: 'm1', kind: TrackerKind.subMember, parentId: 's1', memberId: 'b', createdAt: _t, modifiedAt: _t).withFields({'roles': ['Guard'], 'founder': true});
    await tester.pumpWidget(_app(const SubsystemProfileScreen(id: 's1', initial: SubTab.members), [s, m]));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Bee'), findsWidgets);
    expect(find.text('Guard'), findsOneWidget);
    expect(find.text('Relationships'), findsOneWidget);
  });

  testWidgets('profile view shows roles as pills and a banner line', (tester) async {
    final cfg = ProfileConfig.empty().withRoles(const [ProfileRole(name: 'Host'), ProfileRole(name: 'Protector')]).set('subtitle', 'Night owl');
    await tester.pumpWidget(_app(Scaffold(body: SingleChildScrollView(child: StudioProfileView(member: _members.first, cfg: cfg, preview: true))), const []));
    await tester.pump();
    expect(find.text('Host · Protector'), findsOneWidget);
    expect(find.text('Host'), findsOneWidget);
    expect(find.text('Night owl'), findsOneWidget);
  });

  testWidgets('Profile Studio turns space-separated roles into pills', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(const ProfileStudioScreen(), const []));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('01'), findsOneWidget);
    await tester.ensureVisible(find.text('Add multi-word role'));
    await tester.pump();
    final roleField = find.descendant(of: find.byWidgetPredicate((w) => w is PrismTextField && (w.hintText ?? '').startsWith('Host Protector')), matching: find.byType(EditableText));
    await tester.enterText(roleField, 'Host Protector ');
    await tester.pump();
    expect(find.textContaining('Host · Protector'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('hub and Profile Studio render at desktop width', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final s = TrackerRecord(id: 's1', kind: TrackerKind.subsystem, title: 'Moonlight', createdAt: _t, modifiedAt: _t).withFields({'isolate': true});
    await tester.pumpWidget(_app(const SubsystemHubScreen(), [s]));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Moonlight'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(_app(const ProfileStudioScreen(), const []));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Save'), findsWidgets);
    expect(find.text('Cancel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
