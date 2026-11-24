import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/fronting_roles/roles_data.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';

FrontingSession s(String m, DateTime start) => FrontingSession(id: 's-$m', startTime: start, memberId: m);
TrackerRecord role(String m, String status, DateTime at, {bool noPrimary = false}) => TrackerRecord(
  id: 'r-$m-${at.millisecondsSinceEpoch}',
  kind: TrackerKind.frontRole,
  memberId: m,
  occurredAt: at,
  createdAt: at,
  modifiedAt: at,
).withFields({'status': status, if (noPrimary) 'noPrimary': true});

void main() {
  final t0 = DateTime(2026, 11, 24, 9);
  const types = builtInStatuses;

  test('earliest session is Primary by default, the rest Co-front', () {
    final r = computeRoles(active: [s('b', t0.add(const Duration(minutes: 5))), s('a', t0)], roleRecords: const [], types: types);
    expect({for (final x in r) x.memberId: x.statusId}, {'a': kPrimary, 'b': kCoFront});
  });

  test('an explicit Primary during the session wins, only one Primary', () {
    final r = computeRoles(
      active: [s('a', t0), s('b', t0.add(const Duration(minutes: 1)))],
      roleRecords: [role('b', kPrimary, t0.add(const Duration(minutes: 2)))],
      types: types,
    );
    expect({for (final x in r) x.memberId: x.statusId}, {'a': kCoFront, 'b': kPrimary});
  });

  test('a role recorded before the session started is ignored', () {
    final r = computeRoles(active: [s('a', t0)], roleRecords: [role('a', kCoFront, t0.subtract(const Duration(hours: 3)))], types: types);
    expect(r.single.statusId, kPrimary);
  });

  test('"no primary" makes everyone Co-front', () {
    final r = computeRoles(active: [s('a', t0)], roleRecords: [role('a', kCoFront, t0.add(const Duration(minutes: 1)), noPrimary: true)], types: types);
    expect(r.single.statusId, kCoFront);
  });

  test('awareness statuses last without a session and can be cleared', () {
    var r = computeRoles(active: const [], roleRecords: [role('c', kCoConscious, t0)], types: types);
    expect(r.single.statusId, kCoConscious);
    r = computeRoles(active: const [], roleRecords: [role('c', kCoConscious, t0), role('c', kNoStatus, t0.add(const Duration(minutes: 1)))], types: types);
    expect(r, isEmpty);
  });

  test('Who\'s There is due after the interval, respects confirm and snooze', () {
    const base = RoleSettings(intervalMinutes: 300);
    expect(whosThereDue(settings: base, lastChange: t0, now: t0.add(const Duration(hours: 4))), isFalse);
    expect(whosThereDue(settings: base, lastChange: t0, now: t0.add(const Duration(hours: 5))), isTrue);
    // Confirming "still the same" resets the timer without a fronting change.
    final confirmed = base.copyWith(lastConfirmed: t0.add(const Duration(hours: 5)));
    expect(whosThereDue(settings: confirmed, lastChange: t0, now: t0.add(const Duration(hours: 6))), isFalse);
    final snoozed = base.copyWith(snoozedUntil: t0.add(const Duration(hours: 7)));
    expect(whosThereDue(settings: snoozed, lastChange: t0, now: t0.add(const Duration(hours: 6))), isFalse);
    expect(whosThereDue(settings: base.copyWith(whosThereEnabled: false), lastChange: t0, now: t0.add(const Duration(days: 2))), isFalse);
  });
}
