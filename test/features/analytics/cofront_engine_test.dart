import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/features/analytics/cofront_engine.dart';

FrontingSession s(String id, String m, int startH, int? endH, {FrontConfidence? c}) => FrontingSession(
  id: id,
  memberId: m,
  startTime: DateTime(2026, 1, 1, startH),
  endTime: endH == null ? null : DateTime(2026, 1, 1, endH),
  confidence: c,
);

void main() {
  final from = DateTime(2026, 1, 1);
  final to = DateTime(2026, 1, 2);
  final now = DateTime(2026, 1, 1, 23);

  test('overlapping sessions produce co-fronting periods with the right members', () {
    final p = findCoFronting([s('1', 'a', 8, 12), s('2', 'b', 10, 14), s('3', 'c', 11, 13)], from: from, to: to, now: now);
    expect(p.map((x) => (x.key, x.start.hour, x.end.hour)).toList(), [('a+b', 10, 11), ('a+b+c', 11, 12), ('b+c', 12, 13)]);
    final st = summarize(p);
    expect(st.total, const Duration(hours: 3));
    expect(st.pairs['a|b'], const Duration(hours: 2));
    expect(st.byMember['b']!.$2, const Duration(hours: 3));
  });

  test('unsure confidence marks the period uncertain; sleep is ignored', () {
    final p = findCoFronting([
      s('1', 'a', 8, 10, c: FrontConfidence.unsure),
      s('2', 'b', 9, 11),
      FrontingSession(id: '3', memberId: 'c', startTime: DateTime(2026, 1, 1, 8), endTime: DateTime(2026, 1, 1, 11), sessionType: SessionType.sleep),
    ], from: from, to: to, now: now);
    expect(p, hasLength(1));
    expect(p.single.certainty, CoCertainty.uncertain);
    expect(p.single.key, 'a+b');
  });

  test('an open session older than a day is incomplete', () {
    final p = findCoFronting([
      FrontingSession(id: '1', memberId: 'a', startTime: DateTime(2025, 12, 30)),
      s('2', 'b', 9, 10),
    ], from: from, to: to, now: now);
    expect(p.single.certainty, CoCertainty.incomplete);
  });

  test('no overlap means no co-fronting', () {
    expect(findCoFronting([s('1', 'a', 8, 9), s('2', 'b', 9, 10)], from: from, to: to, now: now), isEmpty);
  });
}
