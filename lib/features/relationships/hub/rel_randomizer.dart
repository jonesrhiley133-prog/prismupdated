import 'dart:math' as math;

import 'package:prism_plurality/features/relationships/hub/rel_model.dart';

/// What the randomizer knows about an alter — only documented information.
class RandAlter {
  const RandAlter({
    required this.id,
    required this.name,
    this.age,
    this.roles = const {},
    this.interests = const {},
    this.communication = const {},
  });
  final String id;
  final String name;
  final AgeInfo? age;
  final Set<String> roles;
  final Set<String> interests;
  final Set<String> communication;
}

/// A documented age, possibly a range ("16–19"). Never invented.
class AgeInfo {
  const AgeInfo(this.min, this.max);
  final int min;
  final int max;
  bool get adult => min >= 18;
  bool get minor => max < 18;
  @override
  String toString() => min == max ? '$min' : '$min–$max';
}

/// Reads ages like "17", "16-19", "about 30". Words alone give null.
AgeInfo? parseAge(String? raw) {
  if (raw == null) return null;
  final nums = [
    for (final m in RegExp(r'\d{1,3}').allMatches(raw)) int.parse(m.group(0)!),
  ].where((n) => n > 0 && n < 150).toList();
  if (nums.isEmpty) return null;
  nums.sort();
  return AgeInfo(nums.first, nums.last);
}

class RandOptions {
  const RandOptions({
    this.excludeNoAge = false,
    this.onlyRoles = const {},
    this.excludeConnected = false,
    this.allowAdditional = true,
    this.noRomantic = false,
    this.noFamilial = false,
    this.onlyPlatonic = false,
    this.includeCustom = false,
    this.useRoles = true,
    this.useInterests = true,
  });
  final bool excludeNoAge;
  final Set<String> onlyRoles;
  final bool excludeConnected;
  final bool allowAdditional;
  final bool noRomantic;
  final bool noFamilial;
  final bool onlyPlatonic;
  final bool includeCustom;
  final bool useRoles;
  final bool useInterests;

  factory RandOptions.from(RelSettings s) => RandOptions(
    excludeNoAge: s.rand('excludeNoAge'),
    onlyRoles: s.randomizerRoles.toSet(),
    excludeConnected: s.rand('excludeConnected'),
    allowAdditional: s.rand('allowAdditional', true),
    noRomantic: s.rand('noRomantic'),
    noFamilial: s.rand('noFamilial'),
    onlyPlatonic: s.rand('onlyPlatonic'),
    includeCustom: s.rand('includeCustom'),
    useRoles: s.rand('useRoles', true),
    useInterests: s.rand('useInterests', true),
  );
}

typedef Bi = (String en, String es);

class RelSuggestion {
  RelSuggestion({
    required this.a,
    required this.b,
    required this.label,
    required this.category,
    required this.reasons,
    required this.factors,
    required this.warnings,
    this.existing = const [],
  });
  final RandAlter a;
  final RandAlter b;
  final String label;
  final String category;
  final List<Bi> reasons;
  final List<Bi> factors;
  final List<Bi> warnings;

  /// Labels the pair already has (the suggestion adds to them).
  final List<String> existing;
}

/// Role keyword groups. Roles are context, never a prediction.
const _roleGroups = {
  'protector': ['protector', 'guardian', 'defender', 'protect'],
  'little': ['little', 'child', 'kid', 'young'],
  'caretaker': ['caretaker', 'caregiver', 'carer', 'nurturer', 'caretaking'],
  'leader': [
    'host',
    'co-host',
    'cohost',
    'manager',
    'gatekeeper',
    'leader',
    'coordinator',
  ],
  'ish': ['ish', 'internal self helper', 'internal self-helper', 'helper'],
  'persecutor': ['persecutor'],
};

Set<String> roleGroups(Set<String> roles) => {
  for (final e in _roleGroups.entries)
    if (roles.any(
      (r) => e.value.any(
        (k) => r.toLowerCase() == k || r.toLowerCase().contains(k),
      ),
    ))
      e.key,
};

const _generational = {
  'parent',
  'child',
  'grandparent',
  'grandchild',
  'aunt_uncle',
  'niece_nephew',
  'guardian',
  'ward',
};
const _ancestorLabels = {'parent', 'grandparent', 'guardian'};

/// Suggests possible relationships from documented information, explaining
/// every factor it used. It never saves anything itself.
class RelRandomizer {
  RelRandomizer({
    required this.alters,
    required this.rels,
    required this.settings,
    required this.options,
    math.Random? random,
  }) : rnd = random ?? math.Random();
  final List<RandAlter> alters;
  final List<Rel> rels;
  final RelSettings settings;
  final RandOptions options;
  final math.Random rnd;

  late final Map<String, List<String>> _pairLabels = () {
    final out = <String, List<String>>{};
    for (final r in rels) {
      if (r.a == null || r.b == null) continue;
      out['${r.a}>${r.b}'] = [...?out['${r.a}>${r.b}'], ...r.labels];
      out['${r.b}>${r.a}'] = [
        ...?out['${r.b}>${r.a}'],
        for (final l in r.labels) invertLabel(l, settings),
      ];
    }
    return out;
  }();

  /// Labels from x's point of view towards y.
  List<String> labelsBetween(String x, String y) =>
      _pairLabels['$x>$y'] ?? const [];

  late final Map<String, Set<String>> _parentsOf = () {
    final out = <String, Set<String>>{};
    for (final r in rels) {
      if (r.a == null || r.b == null) continue;
      for (final l in r.labels) {
        if (_ancestorLabels.contains(l)) (out[r.b!] ??= {}).add(r.a!);
        if (_ancestorLabels.contains(invertLabel(l)))
          (out[r.a!] ??= {}).add(r.b!);
      }
    }
    return out;
  }();

  bool _isAncestor(String x, String y, [int depth = 0]) {
    if (depth > 6) return false;
    final ps = _parentsOf[y] ?? const {};
    return ps.contains(x) || ps.any((p) => _isAncestor(x, p, depth + 1));
  }

  bool _shareParent(String x, String y) => (_parentsOf[x] ?? const {})
      .intersection(_parentsOf[y] ?? const {})
      .isNotEmpty;

  List<RandAlter> get eligible => [
    for (final a in alters)
      if ((!options.excludeNoAge || a.age != null) &&
          (options.onlyRoles.isEmpty ||
              a.roles.any((r) => options.onlyRoles.contains(r.toLowerCase()))))
        a,
  ];

  /// Picks a pair and a label. [lockA] keeps one alter; [lockB] keeps the
  /// other; [avoidLabels] skips labels already shown for this pair.
  RelSuggestion? suggest({
    String? lockA,
    String? lockB,
    Set<String> avoidLabels = const {},
    Set<String> avoidPartners = const {},
  }) {
    final pool = eligible;
    final pairs = <(RandAlter, RandAlter)>[];
    for (var i = 0; i < pool.length; i++) {
      for (var j = i + 1; j < pool.length; j++) {
        final x = pool[i], y = pool[j];
        if (lockA != null && x.id != lockA && y.id != lockA) continue;
        if (lockB != null && x.id != lockB && y.id != lockB) continue;
        final other = lockA == null ? null : (x.id == lockA ? y.id : x.id);
        if (other != null && lockB == null && avoidPartners.contains(other))
          continue;
        final existing = labelsBetween(x.id, y.id);
        if (existing.isNotEmpty &&
            (options.excludeConnected || !options.allowAdditional))
          continue;
        pairs.add(rnd.nextBool() ? (x, y) : (y, x));
      }
    }
    pairs.shuffle(rnd);
    // Prefer pairs with nothing documented yet.
    pairs.sort(
      (p, q) => labelsBetween(
        p.$1.id,
        p.$2.id,
      ).length.compareTo(labelsBetween(q.$1.id, q.$2.id).length),
    );
    final firstEmpty = pairs
        .takeWhile((p) => labelsBetween(p.$1.id, p.$2.id).isEmpty)
        .length;
    if (firstEmpty > 0 &&
        pairs.length > firstEmpty &&
        rnd.nextDouble() < 0.25) {
      // Sometimes look at already-connected pairs for an added label.
      pairs.insert(
        0,
        pairs.removeAt(firstEmpty + rnd.nextInt(pairs.length - firstEmpty)),
      );
    }
    for (final (x, y) in pairs) {
      final s = suggestFor(x, y, avoidLabels: avoidLabels);
      if (s != null) return s;
    }
    return null;
  }

  /// A suggestion for a specific pair, or null when no label fits.
  RelSuggestion? suggestFor(
    RandAlter x,
    RandAlter y, {
    Set<String> avoidLabels = const {},
  }) {
    final reasons = <Bi>[];
    final factors = <Bi>[];
    final warnings = <Bi>[];
    final existing = labelsBetween(x.id, y.id);
    final existingCats = {for (final l in existing) categoryOf(l, settings)};

    // Candidate labels with weights, from x's point of view.
    final w = <String, double>{};
    void add(String l, double v) => w[l] = (w[l] ?? 0) + v;
    for (final l in relLabels) {
      if (l.key == 'other' ||
          l.key == 'complicated' ||
          l.key.endsWith('_other') ||
          l.key == 'ex_partners' ||
          l.key == 'enemy')
        continue;
      add(l.key, switch (l.category) {
        'platonic' => 3,
        'other' => 1.2,
        'familial' => 0.8,
        'romantic' => 0.8,
        _ => 1,
      });
    }
    if (options.includeCustom) {
      for (final c in settings.customLabels) {
        add(c.key, 1);
      }
      factors.add((
        'Custom labels included',
        'Etiquetas personalizadas incluidas',
      ));
    }

    String cat(String l) => categoryOf(l, settings);
    void dropWhere(bool Function(String) test) =>
        w.removeWhere((k, _) => test(k));

    // Settings.
    if (options.onlyPlatonic) {
      dropWhere((l) => cat(l) != 'platonic');
      factors.add(('Only platonic connections', 'Solo conexiones platónicas'));
    }
    if (options.noRomantic) {
      dropWhere((l) => cat(l) == 'romantic');
      factors.add((
        'Romantic suggestions are off',
        'Sugerencias románticas desactivadas',
      ));
    }
    if (options.noFamilial) {
      dropWhere((l) => cat(l) == 'familial');
      factors.add((
        'Family suggestions are off',
        'Sugerencias familiares desactivadas',
      ));
    }

    // Existing relationship between the two.
    if (existing.isNotEmpty) {
      factors.add((
        'They already have documented labels — this would add to them',
        'Ya tienen etiquetas documentadas: esto se añadiría',
      ));
      dropWhere(
        (l) =>
            existing.contains(l) || existing.contains(invertLabel(l, settings)),
      );
      if (existingCats.contains('familial')) {
        dropWhere((l) => cat(l) == 'romantic');
        reasons.add((
          'Romantic labels are excluded because they are documented as family',
          'Se excluyen etiquetas románticas porque están documentados como familia',
        ));
      }
      if (existingCats.contains('romantic'))
        dropWhere((l) => cat(l) == 'familial');
      if (existing.contains('friends')) {
        add('close_friends', 4);
        add('trusted', 2);
        reasons.add((
          'They are documented as friends, so a closer platonic label is offered',
          'Están documentados como amigos, así que se ofrece una etiqueta más cercana',
        ));
      }
      if (existing.contains('close_friends')) add('best_friends', 4);
      // Only one parent/child direction, and no generational label when one exists.
      if (existing.any(_generational.contains))
        dropWhere(_generational.contains);
    }

    // Family structure elsewhere in the system.
    if (_isAncestor(x.id, y.id) || _isAncestor(y.id, x.id)) {
      dropWhere(
        (l) =>
            cat(l) == 'romantic' ||
            _generational.contains(l) ||
            l.contains('sibling'),
      );
      reasons.add((
        'Their documented family tree already connects them across generations',
        'Su árbol familiar documentado ya los conecta entre generaciones',
      ));
    } else if (_shareParent(x.id, y.id)) {
      dropWhere((l) => cat(l) == 'romantic' || _generational.contains(l));
      reasons.add((
        'They share a documented parent, so romantic and parent/child labels are excluded',
        'Comparten un progenitor documentado, así que se excluyen etiquetas románticas y de madre/padre e hijo',
      ));
    }

    // Ages.
    final ax = x.age, ay = y.age;
    if (ax != null && ay != null) {
      factors.add((
        'Documented ages: ${x.name} ${ax.toString()}, ${y.name} ${ay.toString()}',
        'Edades documentadas: ${x.name} ${ax.toString()}, ${y.name} ${ay.toString()}',
      ));
    } else {
      final missing = [
        if (ax == null) x.name,
        if (ay == null) y.name,
      ].join(', ');
      warnings.add((
        'No documented age for $missing — age-sensitive labels are left out',
        'Sin edad documentada para $missing: se omiten las etiquetas sensibles a la edad',
      ));
    }
    final bothAdults = ax != null && ay != null && ax.adult && ay.adult;
    if (!bothAdults && w.keys.any((l) => cat(l) == 'romantic')) {
      dropWhere((l) => cat(l) == 'romantic');
      reasons.add((
        ax != null && ay != null && (ax.minor || ay.minor)
            ? 'Romantic labels are never suggested when a minor is involved'
            : 'Romantic labels need both alters documented as adults',
        ax != null && ay != null && (ax.minor || ay.minor)
            ? 'Nunca se sugieren etiquetas románticas si hay un menor'
            : 'Las etiquetas románticas requieren que ambos estén documentados como adultos',
      ));
    }
    if (ax == null || ay == null) {
      dropWhere(_generational.contains);
    } else {
      final gap = ax.min - ay.max; // > 0 means x is clearly older
      final rgap = ay.min - ax.max;
      void gen(String older, String younger, int need) {
        if (gap >= need) {
          w.remove(younger);
        } else if (rgap >= need) {
          w.remove(older);
        } else {
          w.remove(older);
          w.remove(younger);
        }
      }

      gen('parent', 'child', 14);
      gen('guardian', 'ward', 8);
      gen('grandparent', 'grandchild', 30);
      gen('aunt_uncle', 'niece_nephew', 8);
      if (ax.minor && ay.adult || ay.minor && ax.adult) {
        dropWhere((l) => l == 'roommate' || l == 'colleague');
      }
    }

    // Roles (context only, and optional).
    if (options.useRoles) {
      final gx = roleGroups(x.roles), gy = roleGroups(y.roles);
      if (gx.isNotEmpty || gy.isNotEmpty)
        factors.add((
          'Documented roles (as context, not a prediction)',
          'Roles documentados (como contexto, no como predicción)',
        ));
      void dir(
        String gA,
        String gB,
        String label,
        String inverse,
        double v,
        Bi why,
      ) {
        if (gx.contains(gA) && gy.contains(gB) && w.containsKey(label)) {
          add(label, v);
          reasons.add(why);
        } else if (gy.contains(gA) &&
            gx.contains(gB) &&
            w.containsKey(inverse)) {
          add(inverse, v);
          reasons.add(why);
        }
      }

      dir('protector', 'little', 'protector', 'protected', 6, (
        'One is documented as a protector and the other as a little',
        'Uno está documentado como protector y el otro como little',
      ));
      dir('caretaker', 'little', 'caregiver', 'dependent', 6, (
        'One is documented as a caretaker and the other as a little',
        'Uno está documentado como cuidador y el otro como little',
      ));
      dir('ish', 'little', 'mentor', 'mentee', 3, (
        'An internal self-helper often supports others',
        'Un ayudante interno suele apoyar a otros',
      ));
      if (gx.contains('caretaker') && gy.contains('caretaker')) {
        add('companions', 3);
        add('trusted', 3);
        reasons.add((
          'Both are documented caretakers',
          'Ambos están documentados como cuidadores',
        ));
      }
      if (gx.contains('leader') && gy.contains('leader')) {
        add('colleague', 3);
        add('teammate', 3);
        reasons.add((
          'Both hold leadership roles',
          'Ambos tienen roles de liderazgo',
        ));
      }
      final shared = x.roles
          .map((r) => r.toLowerCase())
          .toSet()
          .intersection(y.roles.map((r) => r.toLowerCase()).toSet());
      if (shared.isNotEmpty) {
        add('teammate', 1.5);
        reasons.add((
          'Shared roles: ${shared.take(3).join(', ')}',
          'Roles en común: ${shared.take(3).join(', ')}',
        ));
      }
    } else {
      factors.add((
        'Role-based suggestions are off',
        'Sugerencias por rol desactivadas',
      ));
    }

    // Shared interests and communication styles.
    if (options.useInterests) {
      final shared = x.interests.intersection(y.interests);
      if (shared.isNotEmpty) {
        add('friends', 1.5 * shared.length.clamp(1, 4));
        add('close_friends', 0.8 * shared.length.clamp(1, 4));
        reasons.add((
          'Shared interests: ${shared.take(3).join(', ')}',
          'Intereses en común: ${shared.take(3).join(', ')}',
        ));
      }
      final comm = x.communication.intersection(y.communication);
      if (comm.isNotEmpty) {
        add('trusted', 1);
        reasons.add((
          'Similar communication preferences: ${comm.take(2).join(', ')}',
          'Preferencias de comunicación parecidas: ${comm.take(2).join(', ')}',
        ));
      }
      if (shared.isEmpty && comm.isEmpty)
        factors.add((
          'No shared interests documented',
          'Sin intereses en común documentados',
        ));
    }

    w.removeWhere((k, v) => avoidLabels.contains(k) || v <= 0);
    if (w.isEmpty) return null;

    // Weighted pick.
    final total = w.values.reduce((a, b) => a + b);
    var roll = rnd.nextDouble() * total;
    var label = w.keys.first;
    for (final e in w.entries) {
      roll -= e.value;
      if (roll <= 0) {
        label = e.key;
        break;
      }
    }
    if (_generational.contains(label)) {
      warnings.add((
        'This family label is only plausible by documented age — please confirm it reflects your system',
        'Esta etiqueta familiar solo es plausible por la edad documentada: confirma que refleja a tu sistema',
      ));
    }
    if (reasons.isEmpty)
      reasons.add((
        'No strong factors — a random, compatible pairing',
        'Sin factores fuertes: una combinación aleatoria compatible',
      ));
    return RelSuggestion(
      a: x,
      b: y,
      label: label,
      category: cat(label),
      reasons: reasons,
      factors: factors,
      warnings: warnings,
      existing: existing,
    );
  }
}
