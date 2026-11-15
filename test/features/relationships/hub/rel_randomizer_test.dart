import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/relationships/hub/rel_model.dart';
import 'package:prism_plurality/features/relationships/hub/rel_randomizer.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';

final _t = DateTime(2026);
Rel _rel(String a, String b, List<String> labels) => Rel(TrackerRecord(id: '$a-$b', kind: TrackerKind.relationship, memberId: a, createdAt: _t, modifiedAt: _t).withFields({'otherType': 'member', 'otherId': b, 'labels': labels}));
RandAlter _alter(String id, {String? age, Set<String> roles = const {}, Set<String> interests = const {}}) => RandAlter(id: id, name: id, age: parseAge(age), roles: roles, interests: interests);

RelRandomizer _engine(List<RandAlter> alters, {List<Rel> rels = const [], RandOptions options = const RandOptions(), int seed = 1}) =>
    RelRandomizer(alters: alters, rels: rels, settings: const RelSettings(), options: options, random: math.Random(seed));

Set<String> _labelsOver(RelRandomizer Function(int) make, RandAlter a, RandAlter b, {int runs = 300}) {
  final out = <String>{};
  for (var i = 0; i < runs; i++) {
    final s = make(i).suggestFor(a, b);
    if (s != null) out.add(s.label);
  }
  return out;
}

bool _romantic(String l) => relLabelIndex[l]?.category == 'romantic';

void main() {
  test('parseAge reads numbers and ranges, never words', () {
    expect(parseAge('17')!.min, 17);
    final r = parseAge('16-19')!;
    expect((r.min, r.max), (16, 19));
    expect(parseAge('little'), isNull);
    expect(parseAge(null), isNull);
  });

  test('never suggests romance between a minor and an adult', () {
    final kid = _alter('kid', age: '12'), adult = _alter('adult', age: '30');
    final labels = _labelsOver((i) => _engine([kid, adult], seed: i), kid, adult);
    expect(labels, isNotEmpty);
    expect(labels.where(_romantic), isEmpty);
  });

  test('never suggests romance when an age is unknown or between minors', () {
    final a = _alter('a'), b = _alter('b', age: '25');
    expect(_labelsOver((i) => _engine([a, b], seed: i), a, b).where(_romantic), isEmpty);
    final c = _alter('c', age: '15'), d = _alter('d', age: '16');
    expect(_labelsOver((i) => _engine([c, d], seed: i), c, d).where(_romantic), isEmpty);
  });

  test('two documented adults can get romantic suggestions', () {
    final a = _alter('a', age: '28'), b = _alter('b', age: '31');
    expect(_labelsOver((i) => _engine([a, b], seed: i), a, b, runs: 600).where(_romantic), isNotEmpty);
  });

  test('family members are never paired romantically', () {
    final a = _alter('a', age: '30'), b = _alter('b', age: '32');
    final rels = [_rel('a', 'b', ['sibling'])];
    final labels = _labelsOver((i) => _engine([a, b], rels: rels, seed: i), a, b);
    expect(labels.where(_romantic), isEmpty);
    expect(labels.contains('sibling'), isFalse, reason: 'existing labels are not duplicated');
  });

  test('alters sharing a documented parent get no romance or parent/child labels', () {
    final p = _alter('p', age: '50'), a = _alter('a', age: '25'), b = _alter('b', age: '27');
    final rels = [_rel('p', 'a', ['parent']), _rel('p', 'b', ['parent'])];
    final labels = _labelsOver((i) => _engine([p, a, b], rels: rels, seed: i), a, b);
    expect(labels.where(_romantic), isEmpty);
    expect(labels.intersection({'parent', 'child', 'grandparent', 'grandchild'}), isEmpty);
  });

  test('generational labels need documented ages with a plausible gap and the right direction', () {
    final older = _alter('o', age: '45'), younger = _alter('y', age: '12');
    final labels = _labelsOver((i) => _engine([older, younger], seed: i), older, younger, runs: 800);
    expect(labels.contains('child'), isFalse, reason: 'the older alter is never the child');
    final same = _alter('s', age: '20'), same2 = _alter('t', age: '22');
    expect(_labelsOver((i) => _engine([same, same2], seed: i), same, same2).intersection({'parent', 'child'}), isEmpty);
    final unknown = _alter('u');
    expect(_labelsOver((i) => _engine([older, unknown], seed: i), older, unknown).intersection({'parent', 'child', 'grandparent', 'grandchild', 'guardian', 'ward'}), isEmpty);
  });

  test('roles add context: protector and little favour a protective label', () {
    final prot = _alter('p', age: '30', roles: {'Protector'}), little = _alter('l', age: '6', roles: {'Little'});
    var protective = 0;
    for (var i = 0; i < 300; i++) {
      final s = _engine([prot, little], seed: i).suggestFor(prot, little)!;
      if (s.label == 'protector') protective++;
      expect(s.reasons.any((r) => r.$1.contains('protector')), isTrue);
    }
    expect(protective, greaterThan(30));
    // Off when role suggestions are disabled.
    final off = _engine([prot, little], options: const RandOptions(useRoles: false)).suggestFor(prot, little)!;
    expect(off.factors.any((f) => f.$1.contains('Role-based suggestions are off')), isTrue);
  });

  test('settings: only platonic, no family, exclude connected', () {
    final a = _alter('a', age: '30'), b = _alter('b', age: '31');
    final plat = _labelsOver((i) => _engine([a, b], options: const RandOptions(onlyPlatonic: true), seed: i), a, b);
    expect(plat.every((l) => relLabelIndex[l]!.category == 'platonic'), isTrue);
    final rels = [_rel('a', 'b', ['friends'])];
    expect(_engine([a, b], rels: rels, options: const RandOptions(excludeConnected: true)).suggest(), isNull);
    final extra = _engine([a, b], rels: rels).suggest();
    expect(extra, isNotNull);
    expect(extra!.label, isNot('friends'));
    expect(extra.existing, contains('friends'));
  });

  test('explains missing information', () {
    final a = _alter('a'), b = _alter('b');
    final s = _engine([a, b]).suggestFor(a, b)!;
    expect(s.warnings.any((w) => w.$1.contains('No documented age')), isTrue);
  });
}
