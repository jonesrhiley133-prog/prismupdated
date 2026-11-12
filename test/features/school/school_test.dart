import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/school/utils/school.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';

final _t = DateTime(2026);

TrackerRecord _a({
  double? earned,
  double? possible,
  double? weight,
  String status = 'todo',
  DateTime? due,
  String parent = 'c1',
}) =>
    TrackerRecord(
      id: '$earned$possible$weight$due',
      kind: TrackerKind.schoolAssignment,
      parentId: parent,
      occurredAt: due,
      createdAt: _t,
      modifiedAt: _t,
    ).withFields({
      SchoolField.earned: earned,
      SchoolField.possible: possible,
      SchoolField.weight: weight,
      SchoolField.status: status,
    });

void main() {
  test('points-based and weighted class grades, letters and GPA', () {
    expect(
      classPercent([_a(earned: 18, possible: 20), _a(earned: 7, possible: 10)]),
      closeTo(83.33, 0.01),
    );
    expect(classPercent([_a()]), isNull);
    final weighted = [
      _a(earned: 90, possible: 100, weight: 30),
      _a(earned: 40, possible: 50, weight: 20),
      _a(weight: 50),
    ];
    expect(classPercent(weighted), closeTo(86, 0.001));
    expect(neededOnRemaining(weighted, 90), closeTo(94, 0.001));
    expect(letterGrade(86), 'B');
    expect(letterGrade(93), 'A');
    expect(letterGrade(59.9), 'F');
    final c1 = TrackerRecord(
      id: 'c1',
      kind: TrackerKind.schoolClass,
      createdAt: _t,
      modifiedAt: _t,
    ).withFields({SchoolField.credits: 4});
    final c2 = TrackerRecord(
      id: 'c2',
      kind: TrackerKind.schoolClass,
      createdAt: _t,
      modifiedAt: _t,
    ).withFields({SchoolField.credits: 2});
    final g = gpa(
      [c1, c2],
      {
        'c1': [_a(earned: 95, possible: 100)],
        'c2': [_a(earned: 75, possible: 100, parent: 'c2')],
      },
    );
    expect(g, closeTo((4.0 * 4 + 2.0 * 2) / 6, 0.001));
  });

  test('schedule for a weekday and overdue status', () {
    final c =
        TrackerRecord(
          id: 'c',
          kind: TrackerKind.schoolClass,
          createdAt: _t,
          modifiedAt: _t,
        ).withFields({
          SchoolField.schedule: [
            const ClassMeeting(
              weekday: 4,
              startMinute: 600,
              endMinute: 660,
            ).toJson(),
            const ClassMeeting(
              weekday: 2,
              startMinute: 540,
              endMinute: 600,
            ).toJson(),
            {'weekday': 9, 'start': 1, 'end': 2},
          ],
        });
    expect(classSchedule(c).map((m) => m.weekday), [2, 4]);
    expect(
      scheduleFor([c], DateTime(2026, 11, 12)).single.$2.startMinute,
      600,
    ); // Thursday
    final now = DateTime(2026, 11, 12, 12);
    expect(isOverdue(_a(due: DateTime(2026, 11, 11)), now), isTrue);
    expect(
      isOverdue(_a(due: DateTime(2026, 11, 11), status: 'done'), now),
      isFalse,
    );
    expect(formatMinuteOfDay(545), '09:05');
  });
}
