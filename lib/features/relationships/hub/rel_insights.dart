import 'package:intl/intl.dart';

import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/relationships/hub/rel_model.dart';
import 'package:prism_plurality/features/relationships/hub/rel_randomizer.dart' show Bi;

/// Check-in rating keys (each optional, 1–5).
const checkinRatings = ['feel', 'comfort', 'communication', 'conflict'];

/// A pattern found in documented records. [sources] are the relationship
/// ids it was computed from, so every insight can be traced back.
class RelInsight {
  const RelInsight({required this.kind, required this.title, required this.body, this.sources = const []});
  final String kind;
  final Bi title;
  final Bi body;
  final List<String> sources;
}

Map<String, int> _ratings(TrackerRecord c) {
  final m = c.fields['ratings'];
  if (m is! Map) return const {};
  return {for (final e in m.entries) if (e.value is num) '${e.key}': (e.value as num).toInt()};
}

/// Computes insights only from what the user documented. Nothing here is a
/// judgement about the alters; it describes patterns in the records.
List<RelInsight> computeInsights({
  required List<Rel> rels,
  required Map<String, String> names,
  required List<TrackerRecord> events,
  required List<TrackerRecord> checkins,
  required List<TrackerRecord> notes,
  required RelSettings settings,
  required DateTime now,
}) {
  final out = <RelInsight>[];
  if (rels.isEmpty) return out;
  String n(String? id) => names[id] ?? '—';
  final byRel = <String, List<TrackerRecord>>{};
  for (final r in [...events, ...checkins, ...notes]) {
    if (r.parentId != null) (byRel[r.parentId!] ??= []).add(r);
  }

  // Alters with the most documented connections.
  final conn = <String, List<String>>{};
  for (final r in rels) {
    for (final m in [?r.a, ?r.b]) {
      (conn[m] ??= []).add(r.id);
    }
  }
  final top = conn.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length));
  if (top.isNotEmpty && top.first.value.length > 1) {
    final names3 = top.take(3).map((e) => '${n(e.key)} (${e.value.length})').join(', ');
    out.add(RelInsight(
      kind: 'connected',
      title: ('Most connected', 'Con más conexiones'),
      body: ('Alters with the most documented relationships: $names3.', 'Alters con más relaciones documentadas: $names3.'),
      sources: top.first.value,
    ));
  }

  // Most common categories and labels.
  final cats = <String, int>{};
  final labels = <String, int>{};
  for (final r in rels) {
    for (final c in relCategoriesOf(r, settings)) {
      cats[c] = (cats[c] ?? 0) + 1;
    }
    for (final l in r.labels) {
      labels[l] = (labels[l] ?? 0) + 1;
    }
  }
  if (labels.isNotEmpty) {
    final l = labels.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final c = cats.entries.reduce((a, b) => a.value >= b.value ? a : b);
    out.add(RelInsight(
      kind: 'categories',
      title: ('Common connections', 'Conexiones frecuentes'),
      body: ('The most documented category is ${c.key} (${c.value}); the most used label is “${relLabelIndex[l.key]?.en ?? l.key}” (${l.value}).', 'La categoría más documentada es ${c.key} (${c.value}); la etiqueta más usada es «${relLabelIndex[l.key]?.es ?? l.key}» (${l.value}).'),
      sources: [for (final r in rels) if (r.labels.contains(l.key)) r.id],
    ));
  }

  // Most documented relationships (notes, events, check-ins).
  final busiest = rels.where((r) => (byRel[r.id]?.length ?? 0) > 0).toList()..sort((a, b) => (byRel[b.id]?.length ?? 0).compareTo(byRel[a.id]?.length ?? 0));
  if (busiest.isNotEmpty) {
    final r = busiest.first;
    out.add(RelInsight(
      kind: 'documented',
      title: ('Most documented', 'Más documentada'),
      body: ('${n(r.a)} & ${n(r.b) == '—' ? (r.otherName ?? '—') : n(r.b)} have the most entries (${byRel[r.id]!.length} notes, events and check-ins).', '${n(r.a)} y ${n(r.b) == '—' ? (r.otherName ?? '—') : n(r.b)} tienen más entradas (${byRel[r.id]!.length} notas, eventos y registros).'),
      sources: [r.id],
    ));
  }

  // Check-in trends.
  for (final r in rels) {
    final cs = [for (final c in byRel[r.id] ?? const <TrackerRecord>[]) if (c.kind == 'rel.checkin') c]..sort((a, b) => (a.occurredAt ?? a.createdAt).compareTo(b.occurredAt ?? b.createdAt));
    if (cs.length < 2) continue;
    for (final key in const ['communication', 'feel', 'comfort']) {
      final vals = [for (final c in cs) ?_ratings(c)[key]];
      if (vals.length < 2) continue;
      final half = vals.length ~/ 2;
      final early = vals.take(half).reduce((a, b) => a + b) / half;
      final late = vals.skip(half).reduce((a, b) => a + b) / (vals.length - half);
      if ((late - early).abs() < 0.75) continue;
      final up = late > early;
      final what = switch (key) { 'communication' => ('communication', 'la comunicación'), 'feel' => ('how the relationship feels', 'cómo se siente la relación'), _ => ('comfort', 'la comodidad') };
      out.add(RelInsight(
        kind: up ? 'improving' : 'declining',
        title: up ? ('Improving in check-ins', 'Mejora en los registros') : ('Lower in recent check-ins', 'Más baja en registros recientes'),
        body: (
          'Recent check-ins for ${n(r.a)} & ${n(r.b)} rate ${what.$1} ${up ? 'higher' : 'lower'} than earlier ones (${early.toStringAsFixed(1)} → ${late.toStringAsFixed(1)} out of 5).',
          'Los registros recientes de ${n(r.a)} y ${n(r.b)} puntúan ${what.$2} ${up ? 'más alto' : 'más bajo'} que antes (${early.toStringAsFixed(1)} → ${late.toStringAsFixed(1)} de 5).',
        ),
        sources: [r.id],
      ));
      break;
    }
  }

  // Frequently documented conflicts.
  for (final r in rels) {
    final conflicts = (byRel[r.id] ?? const <TrackerRecord>[]).where((e) => e.kind == 'rel.event' && (e.str('category') == 'conflict' || (e.integer('sentiment') ?? 0) < 0)).length;
    if (conflicts >= 2) {
      out.add(RelInsight(
        kind: 'conflicts',
        title: ('Recurring conflicts', 'Conflictos recurrentes'),
        body: ('$conflicts conflicts or difficult moments are documented for ${n(r.a)} & ${n(r.b)}.', 'Hay $conflicts conflictos o momentos difíciles documentados para ${n(r.a)} y ${n(r.b)}.'),
        sources: [r.id],
      ));
    }
  }

  // Not updated in a while.
  final stale = <Rel>[];
  for (final r in rels) {
    final last = [r.updated, for (final c in byRel[r.id] ?? const <TrackerRecord>[]) c.occurredAt ?? c.createdAt].reduce((a, b) => a.isAfter(b) ? a : b);
    if (now.difference(last).inDays >= 60) stale.add(r);
  }
  if (stale.isNotEmpty) {
    out.add(RelInsight(
      kind: 'stale',
      title: ('Not updated recently', 'Sin actualizar hace tiempo'),
      body: ('${stale.length} relationship${stale.length == 1 ? '' : 's'} haven’t been updated in two months or more.', '${stale.length} relación${stale.length == 1 ? '' : 'es'} sin actualizar desde hace dos meses o más.'),
      sources: [for (final r in stale) r.id],
    ));
  }
  return out;
}

/// A plain summary of one relationship's documented history.
List<Bi> summarizeRelationship({required Rel rel, required List<TrackerRecord> events, required List<TrackerRecord> checkins, required List<TrackerRecord> notes, String locale = 'en'}) {
  final df = DateFormat.yMMMd(locale);
  final out = <Bi>[];
  out.add(('Documented since ${df.format(rel.documented)}; last updated ${df.format(rel.updated)}.', 'Documentada desde el ${df.format(rel.documented)}; actualizada el ${df.format(rel.updated)}.'));
  if (events.isNotEmpty) {
    final sorted = [...events]..sort((a, b) => (a.occurredAt ?? a.createdAt).compareTo(b.occurredAt ?? b.createdAt));
    final last = sorted.last;
    out.add(('${events.length} timeline event${events.length == 1 ? '' : 's'}; the latest is “${last.title}” (${df.format(last.occurredAt ?? last.createdAt)}).', '${events.length} evento${events.length == 1 ? '' : 's'} en la cronología; el último es «${last.title}» (${df.format(last.occurredAt ?? last.createdAt)}).'));
  }
  if (checkins.length >= 2) {
    final sorted = [...checkins]..sort((a, b) => (a.occurredAt ?? a.createdAt).compareTo(b.occurredAt ?? b.createdAt));
    final first = _ratings(sorted.first), last = _ratings(sorted.last);
    final changed = [
      for (final k in checkinRatings)
        if (first[k] != null && last[k] != null && first[k] != last[k]) '$k ${first[k]}→${last[k]}',
    ];
    out.add((
      '${checkins.length} check-ins${changed.isEmpty ? '' : '; between the first and latest: ${changed.join(', ')}'}.',
      '${checkins.length} registros${changed.isEmpty ? '' : '; entre el primero y el último: ${changed.join(', ')}'}.',
    ));
  } else if (checkins.length == 1) {
    out.add(('One check-in so far.', 'Un registro por ahora.'));
  }
  if (notes.isNotEmpty) out.add(('${notes.length} note${notes.length == 1 ? '' : 's'}.', '${notes.length} nota${notes.length == 1 ? '' : 's'}.'));
  return out;
}
