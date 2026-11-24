import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/domain/models/cycle_entry.dart';
import 'package:prism_plurality/features/cycle/utils/cycle_stats.dart';

/// One day from another app or a file.
class ImportedCycleDay {
  const ImportedCycleDay(
    this.day,
    this.flow, {
    this.symptoms = const [],
    this.note,
    this.source,
  });
  final DateTime day;

  /// 0 none, 1 spotting, 2 light, 3 medium, 4 heavy.
  final int flow;
  final List<String> symptoms;
  final String? note;
  final String? source;
  String get key => CycleStats.dateKey(day);
}

class CycleParseResult {
  const CycleParseResult(this.days, this.format, {this.skippedRows = 0});
  final List<ImportedCycleDay> days;
  final String format;
  final int skippedRows;
  DateTime? get first => days.isEmpty
      ? null
      : days.map((d) => d.day).reduce((a, b) => a.isBefore(b) ? a : b);
  DateTime? get last => days.isEmpty
      ? null
      : days.map((d) => d.day).reduce((a, b) => a.isAfter(b) ? a : b);
}

/// Flow from words or numbers used by common trackers.
int? flowFrom(Object? v, {int unspecified = 3}) {
  if (v == null) return null;
  if (v is num) return v.toInt().clamp(0, 4);
  if (v is bool) return v ? unspecified : 0;
  if (v is Map)
    return flowFrom(
      v['option'] ?? v['value'] ?? v['flow'] ?? v['intensity'],
      unspecified: unspecified,
    );
  final s = '$v'.trim().toLowerCase();
  if (s.isEmpty) return null;
  final n = int.tryParse(s);
  if (n != null) return n.clamp(0, 4);
  if (s.contains('spot')) return 1;
  if (s.contains('light') || s == 'low' || s.contains('ligero')) return 2;
  if (s.contains('medium') ||
      s.contains('moderate') ||
      s.contains('normal') ||
      s.contains('medio'))
    return 3;
  if (s.contains('heavy') || s.contains('high') || s.contains('abundante'))
    return 4;
  if (s == 'none' || s == 'no' || s == '0' || s == 'false') return 0;
  if (s == 'yes' ||
      s == 'true' ||
      s.contains('period') ||
      s.contains('bleed') ||
      s.contains('menstrua'))
    return unspecified;
  return null;
}

DateTime? _date(Object? v) {
  if (v == null) return null;
  final s = '$v'.trim();
  final iso = DateTime.tryParse(
    s.length >= 10 && s[4] == '-' ? s.substring(0, 10) : s,
  );
  if (iso != null) return DateTime(iso.year, iso.month, iso.day);
  // dd/mm/yyyy or mm/dd/yyyy: day-first when the first part can't be a month.
  final m = RegExp(r'^(\d{1,2})[/.](\d{1,2})[/.](\d{4})').firstMatch(s);
  if (m != null) {
    final a = int.parse(m[1]!), b = int.parse(m[2]!), y = int.parse(m[3]!);
    final (mo, d) = a > 12 ? (b, a) : (a, b);
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    return DateTime(y, mo, d);
  }
  return null;
}

const _periodTypes = {
  'period',
  'bleeding',
  'flow',
  'menstruation',
  'menstrual_flow',
  'menstruation_flow',
  'spotting',
};

List<String> _symptoms(Object? v) {
  if (v == null) return const [];
  if (v is List)
    return [for (final x in v) '$x'.trim()].where((s) => s.isNotEmpty).toList();
  return '$v'
      .split(RegExp(r'[;|,]'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

/// Reads a CSV or JSON export: Prism's own format, Clue's measurement
/// export, or any table with a date column plus a flow or period column,
/// or period start/end columns.
CycleParseResult parseCycleFile(
  String name,
  String content, {
  int unspecified = 3,
}) {
  final text = content.trim().replaceFirst('﻿', '');
  if (text.startsWith('{') || text.startsWith('['))
    return _parseJson(jsonDecode(text), unspecified);
  return _parseCsv(text, unspecified);
}

CycleParseResult _parseJson(Object? root, int unspecified) {
  var format = 'JSON';
  List<Object?> rows;
  if (root is Map) {
    final list =
        root['measurements'] ??
        root['data'] ??
        root['entries'] ??
        root['cycle'] ??
        root['days'] ??
        root['records'];
    if (root.containsKey('measurements')) format = 'Clue';
    rows = list is List ? list : [root];
  } else if (root is List) {
    rows = root;
  } else {
    rows = const [];
  }
  final byDay = <String, ImportedCycleDay>{};
  var skipped = 0;
  for (final r in rows) {
    if (r is! Map) {
      skipped++;
      continue;
    }
    final type = '${r['type'] ?? r['category'] ?? ''}'.toLowerCase();
    // Ranges: {start, end}
    final start = _date(r['start'] ?? r['startDate'] ?? r['period_start']);
    final end = _date(r['end'] ?? r['endDate'] ?? r['period_end']);
    if (start != null &&
        end != null &&
        !end.isBefore(start) &&
        end.difference(start).inDays < 15) {
      for (
        var d = start;
        !d.isAfter(end);
        d = DateTime(d.year, d.month, d.day + 1)
      ) {
        byDay[CycleStats.dateKey(d)] = ImportedCycleDay(
          d,
          unspecified,
          source: format,
        );
      }
      continue;
    }
    final day = _date(r['date'] ?? r['day'] ?? r['day_date'] ?? r['timestamp']);
    if (day == null) {
      skipped++;
      continue;
    }
    int? flow;
    if (type.isNotEmpty && _periodTypes.contains(type)) {
      flow = type == 'spotting'
          ? 1
          : (flowFrom(r['value'], unspecified: unspecified) ?? unspecified);
    } else if (type.isEmpty) {
      flow = flowFrom(
        r['flow'] ?? r['period'] ?? r['bleeding'] ?? r['menstruation'],
        unspecified: unspecified,
      );
    }
    final symptoms = type.isEmpty
        ? _symptoms(r['symptoms'] ?? r['tags'])
        : (type.contains('pain') ||
                  type.contains('symptom') ||
                  type.contains('mood')
              ? _symptoms(
                  r['value'] is Map
                      ? (r['value'] as Map)['option']
                      : r['value'],
                )
              : const <String>[]);
    final note = (r['note'] ?? r['notes'])?.toString();
    if ((flow == null || flow == 0) &&
        symptoms.isEmpty &&
        (note == null || note.trim().isEmpty)) {
      if (type.isNotEmpty && !_periodTypes.contains(type)) continue;
      skipped++;
      continue;
    }
    final prev = byDay[CycleStats.dateKey(day)];
    byDay[CycleStats.dateKey(day)] = ImportedCycleDay(
      day,
      [flow ?? 0, prev?.flow ?? 0].reduce((a, b) => a > b ? a : b),
      symptoms: {...?prev?.symptoms, ...symptoms}.toList(),
      note: note ?? prev?.note,
      source: format,
    );
  }
  return CycleParseResult(
    byDay.values.toList()..sort((a, b) => a.day.compareTo(b.day)),
    format,
    skippedRows: skipped,
  );
}

List<List<String>> _csvRows(String text) {
  final rows = <List<String>>[];
  final sep =
      text.split('\n').first.contains(';') &&
          !text.split('\n').first.contains(',')
      ? ';'
      : ',';
  for (final line in const LineSplitter().convert(text)) {
    if (line.trim().isEmpty) continue;
    final cells = <String>[];
    final b = StringBuffer();
    var q = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (q && i + 1 < line.length && line[i + 1] == '"') {
          b.write('"');
          i++;
        } else {
          q = !q;
        }
      } else if (ch == sep && !q) {
        cells.add(b.toString());
        b.clear();
      } else {
        b.write(ch);
      }
    }
    cells.add(b.toString());
    rows.add(cells.map((c) => c.trim()).toList());
  }
  return rows;
}

CycleParseResult _parseCsv(String text, int unspecified) {
  final rows = _csvRows(text);
  if (rows.length < 2) return const CycleParseResult([], 'CSV');
  final head = [for (final h in rows.first) h.toLowerCase()];
  int col(List<String> names) =>
      head.indexWhere((h) => names.any((n) => h == n || h.contains(n)));
  final dateCol = col(['date', 'day', 'fecha']);
  final startCol = col(['start', 'inicio']);
  final endCol = col(['end', 'fin']);
  final flowCol = col([
    'flow',
    'period',
    'bleeding',
    'menstrua',
    'flujo',
    'intensity',
  ]);
  final symCol = col(['symptom', 'tags', 'síntoma', 'sintoma']);
  final noteCol = col(['note', 'nota', 'comment']);
  final byDay = <String, ImportedCycleDay>{};
  var skipped = 0;
  String cell(List<String> r, int i) => i >= 0 && i < r.length ? r[i] : '';
  for (final r in rows.skip(1)) {
    if (dateCol < 0 && startCol >= 0) {
      final s = _date(cell(r, startCol));
      final e = _date(cell(r, endCol)) ?? s;
      if (s == null ||
          e == null ||
          e.isBefore(s) ||
          e.difference(s).inDays > 14) {
        skipped++;
        continue;
      }
      final f =
          flowFrom(cell(r, flowCol), unspecified: unspecified) ?? unspecified;
      for (var d = s; !d.isAfter(e); d = DateTime(d.year, d.month, d.day + 1)) {
        byDay[CycleStats.dateKey(d)] = ImportedCycleDay(
          d,
          f == 0 ? unspecified : f,
          source: 'CSV',
        );
      }
      continue;
    }
    final day = _date(cell(r, dateCol < 0 ? 0 : dateCol));
    if (day == null) {
      skipped++;
      continue;
    }
    final flow = flowFrom(cell(r, flowCol), unspecified: unspecified) ?? 0;
    final symptoms = _symptoms(cell(r, symCol));
    final note = cell(r, noteCol);
    if (flow == 0 && symptoms.isEmpty && note.isEmpty) {
      skipped++;
      continue;
    }
    byDay[CycleStats.dateKey(day)] = ImportedCycleDay(
      day,
      flow,
      symptoms: symptoms,
      note: note.isEmpty ? null : note,
      source: 'CSV',
    );
  }
  return CycleParseResult(
    byDay.values.toList()..sort((a, b) => a.day.compareTo(b.day)),
    'CSV',
    skippedRows: skipped,
  );
}

/// What an import would do.
class CycleImportPlan {
  const CycleImportPlan(this.create, this.update, this.unchanged);
  final List<ImportedCycleDay> create;
  final List<(CycleEntry, ImportedCycleDay)> update;
  final int unchanged;
}

/// New days are added. Days already logged keep what was entered: only an
/// empty flow is filled in and new symptoms are added (unless [fillBlanksOnly]
/// is false, in which case a higher imported flow also wins).
CycleImportPlan planCycleImport(
  Map<String, CycleEntry> existing,
  List<ImportedCycleDay> incoming, {
  bool fillBlanksOnly = true,
}) {
  final create = <ImportedCycleDay>[];
  final update = <(CycleEntry, ImportedCycleDay)>[];
  var same = 0;
  for (final d in incoming) {
    final e = existing[d.key];
    if (e == null) {
      create.add(d);
      continue;
    }
    final flowChange = e.flow == 0
        ? d.flow > 0
        : (!fillBlanksOnly && d.flow > e.flow);
    final newSymptoms = d.symptoms
        .where((s) => !e.symptoms.contains(s))
        .isNotEmpty;
    final noteChange =
        (e.note == null || e.note!.isEmpty) && (d.note?.isNotEmpty ?? false);
    if (flowChange || newSymptoms || noteChange) {
      update.add((e, d));
    } else {
      same++;
    }
  }
  return CycleImportPlan(create, update, same);
}

class CycleImportWriter {
  CycleImportWriter(this.ref);
  final Ref ref;

  Future<(int created, int updated, int unchanged)> apply(
    List<ImportedCycleDay> days, {
    bool fillBlanksOnly = true,
    String? memberId,
  }) async {
    final repo = ref.read(cycleEntryRepositoryProvider);
    final all = await repo.getAll();
    final existing = {
      for (final e
          in (all.toList()
            ..sort((a, b) => a.modifiedAt.compareTo(b.modifiedAt))))
        e.date: e,
    };
    final plan = planCycleImport(
      existing,
      days,
      fillBlanksOnly: fillBlanksOnly,
    );
    final now = DateTime.now();
    for (final d in plan.create) {
      await repo.create(
        CycleEntry(
          id: const Uuid().v4(),
          date: d.key,
          flow: d.flow.clamp(0, 4),
          symptoms: d.symptoms,
          note: d.note,
          memberId: memberId,
          createdAt: now,
          modifiedAt: now,
        ),
      );
    }
    for (final (e, d) in plan.update) {
      await repo.update(
        e.copyWith(
          flow: e.flow == 0 || (!fillBlanksOnly && d.flow > e.flow)
              ? d.flow.clamp(0, 4)
              : e.flow,
          symptoms: {...e.symptoms, ...d.symptoms}.toList(),
          note: (e.note == null || e.note!.isEmpty) ? d.note : e.note,
          modifiedAt: now,
        ),
      );
    }
    return (plan.create.length, plan.update.length, plan.unchanged);
  }
}

final cycleImportWriterProvider = Provider<CycleImportWriter>(
  CycleImportWriter.new,
);
