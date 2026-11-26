import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/domain/repositories/entity_repository.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/relationships/hub/member_relationships.dart';
import 'package:prism_plurality/features/relationships/hub/rel_editor.dart';
import 'package:prism_plurality/features/relationships/hub/rel_hub_screen.dart';
import 'package:prism_plurality/features/relationships/hub/rel_model.dart';
import 'package:prism_plurality/features/relationships/hub/rel_profile.dart';
import 'package:prism_plurality/features/relationships/hub/rel_randomize_sheet.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';

final _t = DateTime(2026);

class _Repo implements EntityRepository<TrackerRecord> {
  _Repo(List<TrackerRecord> seed) : rows = [...seed];
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
  Future<TrackerRecord?> getById(String id) async =>
      rows.where((r) => r.id == id).firstOrNull;
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

final _members = [
  Member(id: 'a', name: 'Ash', age: '30', createdAt: _t),
  Member(id: 'b', name: 'Bee', age: '29', createdAt: _t),
  Member(id: 'c', name: 'Cal', age: '8', createdAt: _t),
];

TrackerRecord _rel(
  String id,
  String a,
  String b,
  List<String> labels, {
  String status = 'active',
}) =>
    TrackerRecord(
      id: id,
      kind: TrackerKind.relationship,
      memberId: a,
      title: '',
      body: 'They look out for each other.',
      createdAt: _t,
      modifiedAt: _t,
    ).withFields({
      'otherType': 'member',
      'otherId': b,
      'labels': labels,
      'status': status,
    });

Widget _app(Widget home, _Repo repo) => ProviderScope(
  overrides: [
    trackerRecordRepositoryProvider.overrideWithValue(repo),
    allMemberListProvider.overrideWith((ref) => Stream.value(_members)),
    memberNamePreferDisplayProvider.overrideWithValue(false),
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: const [Locale('en')],
    home: home,
  ),
);

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  for (final size in const [Size(400, 900), Size(1300, 900)]) {
    testWidgets(
      'hub shows stats, map and directory at ${size.width.toInt()}px',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repo = _Repo([
          _rel('r1', 'a', 'b', ['sibling', 'best_friends']),
          _rel('r2', 'a', 'c', ['protector'], status: 'exploring'),
        ]);
        await tester.pumpWidget(_app(const RelationshipsHubScreen(), repo));
        await _settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('Randomize relationship'), findsOneWidget);
        expect(find.text('Relationship map'), findsOneWidget);
        // Statistics come from records.
        expect(find.text('Documented relationships'), findsOneWidget);
        expect(
          find.textContaining('2 relationships · 3 alters connected'),
          findsOneWidget,
        );
        // Map nodes.
        expect(find.text('Ash'), findsWidgets);
        // Directory shows both relationships (scroll there).
        await tester.scrollUntilVisible(
          find.textContaining('Siblings · Best friends'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.textContaining('Siblings · Best friends'), findsOneWidget);
      },
    );
  }

  testWidgets('stat card filters the directory', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _Repo([
      _rel('r1', 'a', 'b', ['sibling']),
      _rel('r2', 'a', 'c', ['friends']),
    ]);
    await tester.pumpWidget(_app(const RelationshipsHubScreen(), repo));
    await _settle(tester);
    await tester.tap(find.text('Familial').first);
    await _settle(tester);
    await tester.scrollUntilVisible(
      find.byType(RelCard).first,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byType(RelCard), findsOneWidget);
  });

  testWidgets(
    'relationship profile shows labels and tabs, notes can be added',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = _Repo([
        _rel('r1', 'a', 'c', ['parent', 'best_friends']),
      ]);
      await tester.pumpWidget(
        _app(const RelationshipProfileScreen(id: 'r1'), repo),
      );
      await _settle(tester);
      expect(find.text('Parent'), findsOneWidget);
      expect(find.text('Best friends'), findsOneWidget);
      expect(find.text('They look out for each other.'), findsOneWidget);
      await tester.tap(find.text('Notes'));
      await _settle(tester);
      await tester.tap(find.text('Add note'));
      await _settle(tester);
      await tester.enterText(find.byType(EditableText).first, 'First talk');
      await tester.tap(find.text('Save').last);
      await _settle(tester);
      expect(
        repo.rows.where(
          (r) =>
              r.kind == TrackerKind.relationshipNote &&
              r.parentId == 'r1' &&
              r.title == 'First talk',
        ),
        hasLength(1),
      );
    },
  );

  testWidgets('alter profile section reads labels from that alter’s side', (
    tester,
  ) async {
    final repo = _Repo([
      _rel('r1', 'a', 'c', ['parent']),
    ]);
    await tester.pumpWidget(
      _app(
        const Scaffold(
          body: SingleChildScrollView(
            child: MemberRelationshipsSection(memberId: 'c'),
          ),
        ),
        repo,
      ),
    );
    await _settle(tester);
    expect(find.text('Child'), findsOneWidget);
    expect(find.text('Ash'), findsOneWidget);
  });

  testWidgets('editor merges into an existing pair instead of duplicating', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _Repo([
      _rel('r1', 'a', 'b', ['sibling']),
    ]);
    await tester.pumpWidget(
      _app(
        const Scaffold(
          body: RelEditor(
            memberId: 'b',
            otherId: 'a',
            presetLabels: ['best_friends'],
          ),
        ),
        repo,
      ),
    );
    await _settle(tester);
    expect(find.textContaining('already have a relationship'), findsOneWidget);
    await tester.tap(find.text('Add to relationship'));
    await _settle(tester);
    final rels = repo.rows
        .where((r) => r.kind == TrackerKind.relationship)
        .toList();
    expect(rels, hasLength(1));
    expect(Rel(rels.single).labels, ['sibling', 'best_friends']);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets(
    'randomizer suggests from real alters and saves only after confirming',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = _Repo([]);
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButtonLike(onTap: () => showRandomizer(context)),
              ),
            ),
          ),
          repo,
        ),
      );
      await _settle(tester);
      await tester.tap(find.text('open'));
      await _settle(tester);
      expect(find.text('Why this pairing'), findsOneWidget);
      expect(repo.rows, isEmpty);
      await tester.tap(find.text('Accept & save'));
      await _settle(tester);
      expect(repo.rows, isEmpty, reason: 'nothing saved before confirming');
      await tester.tap(find.text('Save').last);
      await _settle(tester);
      final saved = repo.rows
          .where((r) => r.kind == TrackerKind.relationship)
          .toList();
      expect(saved, hasLength(1));
      expect(Rel(saved.single).confidence, 'suspected');
      // Never romance with the 8-year-old.
      final r = Rel(saved.single);
      if (r.involves('c'))
        expect(
          r.labels.any((l) => relLabelIndex[l]?.category == 'romantic'),
          isFalse,
        );
      await tester.pump(const Duration(seconds: 4));
    },
  );
}

class TextButtonLike extends StatelessWidget {
  const TextButtonLike({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) =>
      GestureDetector(onTap: onTap, child: const Text('open'));
}
