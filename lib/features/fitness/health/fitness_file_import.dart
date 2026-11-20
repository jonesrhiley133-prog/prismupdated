import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'package:prism_plurality/features/fitness/health/health_sync.dart';

/// Formats Prism can import from a provider export.
enum ExportKind { appleHealth, googleFit, samsungHealth }

String exportKindLabel(ExportKind k) => switch (k) {
  ExportKind.appleHealth => 'Apple Health export',
  ExportKind.googleFit => 'Google Fit (Takeout) daily metrics',
  ExportKind.samsungHealth => 'Samsung Health export',
};

String exportPlatform(ExportKind k) => switch (k) {
  ExportKind.appleHealth => 'file:apple',
  ExportKind.googleFit => 'file:googlefit',
  ExportKind.samsungHealth => 'file:samsung',
};

/// What a file contains, checked before anything is saved.
class ImportPreview {
  ImportPreview({required this.kind, required this.workouts, required this.daily, required this.skipped, this.warnings = const []});
  final ExportKind kind;
  final List<ImportedWorkout> workouts;

  /// dayKey → field values (steps, distanceKm, calories, activeMinutes,
  /// heartRateAvg, sleepMinutes).
  final Map<String, Map<String, Object?>> daily;
  final int skipped;
  final List<String> warnings;

  DateTime? get from {
    final dates = [for (final w in workouts) w.start, for (final k in daily.keys) DateTime.parse(k)];
    return dates.isEmpty ? null : dates.reduce((a, b) => a.isBefore(b) ? a : b);
  }

  DateTime? get to {
    final dates = [for (final w in workouts) w.end, for (final k in daily.keys) DateTime.parse(k)];
    return dates.isEmpty ? null : dates.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// Number of days with a value, per field.
  Map<String, int> get countsByField {
    final out = <String, int>{};
    for (final d in daily.values) {
      for (final e in d.entries) {
        if (e.value == null || e.key.endsWith('Source')) continue;
        out[e.key] = (out[e.key] ?? 0) + 1;
      }
    }
    return out;
  }

  bool get isEmpty => workouts.isEmpty && daily.isEmpty;
}

class ImportFormatException implements Exception {
  ImportFormatException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Reads [bytes] (named [fileName]) and returns a preview. Throws
/// [ImportFormatException] for files Prism can't read.
ImportPreview parseFitnessExport(Uint8List bytes, String fileName) {
  final name = fileName.toLowerCase();
  if (name.endsWith('.zip')) {
    final zip = ZipDecoder().decodeBytes(bytes);
    final xml = zip.files.where((f) => f.isFile && f.name.toLowerCase().endsWith('export.xml') && !f.name.toLowerCase().contains('cda')).firstOrNull;
    if (xml != null) return parseAppleHealthXml(utf8.decode(xml.content as List<int>, allowMalformed: true));
    final csvs = [for (final f in zip.files) if (f.isFile && f.name.toLowerCase().endsWith('.csv')) f];
    final daily = csvs.where((f) => f.name.toLowerCase().contains('daily activity metrics')).firstOrNull;
    if (daily != null) return parseGoogleFitDaily(utf8.decode(daily.content as List<int>, allowMalformed: true));
    final samsung = [for (final f in csvs) if (f.name.toLowerCase().contains('com.samsung')) utf8.decode(f.content as List<int>, allowMalformed: true)];
    if (samsung.isNotEmpty) return parseSamsungCsvs(samsung);
    throw ImportFormatException('This zip doesn’t contain an Apple Health export.xml, a Google Fit “Daily activity metrics.csv” or Samsung Health CSV files.');
  }
  final text = utf8.decode(bytes, allowMalformed: true);
  if (name.endsWith('.xml') || text.trimLeft().startsWith('<?xml')) {
    if (!text.contains('<HealthData')) throw ImportFormatException('This XML file isn’t an Apple Health export.');
    return parseAppleHealthXml(text);
  }
  if (name.endsWith('.csv')) {
    if (text.startsWith('com.samsung')) return parseSamsungCsvs([text]);
    final header = text.split('\n').first.toLowerCase();
    if (header.contains('step count') && header.contains('date')) return parseGoogleFitDaily(text);
    throw ImportFormatException('Prism can read Google Fit “Daily activity metrics.csv” and Samsung Health CSV files. This CSV looks different.');
  }
  throw ImportFormatException('Choose an Apple Health export (.zip or export.xml), a Google Fit Takeout CSV/zip, or Samsung Health CSV files.');
}

// ---------------------------------------------------------------------------
// Apple Health
// ---------------------------------------------------------------------------

final _attr = RegExp(r'(\w+)="([^"]*)"');

Map<String, String> _attrs(String tag) => {for (final m in _attr.allMatches(tag)) m.group(1)!: _unescape(m.group(2)!)};
String _unescape(String s) => s.replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&quot;', '"').replaceAll('&apos;', "'");

/// "2024-05-01 07:12:33 +0200" → DateTime (local).
DateTime? parseAppleDate(String? s) {
  if (s == null) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2}) ([+-])(\d{2})(\d{2})$').firstMatch(s.trim());
  if (m == null) return DateTime.tryParse(s)?.toLocal();
  final g = [for (var i = 1; i <= 9; i++) m.group(i)!];
  final utc = DateTime.utc(int.parse(g[0]), int.parse(g[1]), int.parse(g[2]), int.parse(g[3]), int.parse(g[4]), int.parse(g[5]));
  final offset = Duration(hours: int.parse(g[7]), minutes: int.parse(g[8]));
  return (g[6] == '+' ? utc.subtract(offset) : utc.add(offset)).toLocal();
}

ImportPreview parseAppleHealthXml(String xml) {
  final workouts = <ImportedWorkout>[];
  final perDay = <String, Map<String, Map<String, double>>>{}; // day → field → source → value
  final hr = <String, (double, int)>{};
  var skipped = 0;

  void add(String day, String field, String source, double v) {
    final f = perDay.putIfAbsent(day, () => {}).putIfAbsent(field, () => {});
    f[source] = (f[source] ?? 0) + v;
  }

  for (final m in RegExp(r'<(Record|Workout)\s([^>]*?)/?>', multiLine: true).allMatches(xml)) {
    final a = _attrs(m.group(2)!);
    final start = parseAppleDate(a['startDate']);
    final end = parseAppleDate(a['endDate']);
    final source = a['sourceName'] ?? 'Apple Health';
    if (start == null || end == null) {
      skipped++;
      continue;
    }
    if (m.group(1) == 'Workout') {
      final type = (a['workoutActivityType'] ?? '').replaceFirst('HKWorkoutActivityType', '');
      final dist = double.tryParse(a['totalDistance'] ?? '');
      final distUnit = a['totalDistanceUnit'] ?? 'km';
      final energy = double.tryParse(a['totalEnergyBurned'] ?? '');
      final energyUnit = a['totalEnergyBurnedUnit'] ?? 'kcal';
      workouts.add(ImportedWorkout(
        sourceId: 'apple:$source:${start.toUtc().toIso8601String()}:$type',
        source: source,
        activity: mapWorkoutActivity(type),
        rawType: type,
        start: start,
        end: end,
        distanceKm: dist == null || dist <= 0 ? null : (distUnit == 'mi' ? dist * 1.609344 : (distUnit == 'm' ? dist / 1000 : dist)),
        calories: energy == null || energy <= 0 ? null : (energyUnit == 'kJ' ? energy / 4.184 : energy).round(),
      ));
      continue;
    }
    final type = a['type'] ?? '';
    final value = double.tryParse(a['value'] ?? '');
    final unit = a['unit'] ?? '';
    final day = dayKey(start);
    switch (type) {
      case 'HKQuantityTypeIdentifierStepCount' when value != null:
        add(day, 'steps', source, value);
      case 'HKQuantityTypeIdentifierDistanceWalkingRunning' when value != null:
        add(day, 'distanceKm', source, unit == 'mi' ? value * 1.609344 : (unit == 'm' ? value / 1000 : value));
      case 'HKQuantityTypeIdentifierActiveEnergyBurned' when value != null:
        add(day, 'calories', source, unit == 'kJ' ? value / 4.184 : value);
      case 'HKQuantityTypeIdentifierAppleExerciseTime' when value != null:
        add(day, 'activeMinutes', source, value);
      case 'HKQuantityTypeIdentifierHeartRate' when value != null:
        final cur = hr[day] ?? (0, 0);
        hr[day] = (cur.$1 + value, cur.$2 + 1);
      case 'HKCategoryTypeIdentifierSleepAnalysis':
        if ((a['value'] ?? '').contains('Asleep')) add(dayKey(end), 'sleepMinutes', source, end.difference(start).inMinutes.toDouble());
      case _:
        if (value == null && !type.startsWith('HKCategory')) skipped++;
    }
  }
  if (workouts.isEmpty && perDay.isEmpty && hr.isEmpty) throw ImportFormatException('No steps, workouts or other supported data were found in this Apple Health export.');
  return ImportPreview(kind: ExportKind.appleHealth, workouts: workouts, daily: _resolveDaily(perDay, hr), skipped: skipped);
}

/// Applies the single-source-per-day policy (largest total wins) so the
/// iPhone and a watch counting the same steps aren't added together.
Map<String, Map<String, Object?>> _resolveDaily(Map<String, Map<String, Map<String, double>>> perDay, Map<String, (double, int)> hr) {
  final out = <String, Map<String, Object?>>{};
  for (final d in perDay.entries) {
    final fields = <String, Object?>{};
    for (final f in d.value.entries) {
      final pick = pickDailySource(f.value);
      if (pick == null || pick.$1 <= 0) continue;
      fields[f.key] = f.key == 'distanceKm' ? double.parse(pick.$1.toStringAsFixed(2)) : pick.$1.round();
      fields['${f.key}Source'] = pick.$2;
    }
    if (fields.isNotEmpty) out[d.key] = fields;
  }
  for (final e in hr.entries) {
    out.putIfAbsent(e.key, () => {})['heartRateAvg'] = (e.value.$1 / e.value.$2).round();
  }
  return out;
}

// ---------------------------------------------------------------------------
// CSV helpers
// ---------------------------------------------------------------------------

/// Minimal RFC 4180 CSV reader (quotes, escaped quotes, CRLF).
List<List<String>> parseCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(c);
      }
      continue;
    }
    switch (c) {
      case '"':
        quoted = true;
      case ',':
        row.add(cell.toString());
        cell.clear();
      case '\n':
        row.add(cell.toString());
        cell.clear();
        if (row.any((x) => x.isNotEmpty)) rows.add(row);
        row = <String>[];
      case '\r':
        break;
      default:
        cell.write(c);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    if (row.any((x) => x.isNotEmpty)) rows.add(row);
  }
  return rows;
}

// ---------------------------------------------------------------------------
// Google Fit (Takeout) — "Daily activity metrics.csv"
// ---------------------------------------------------------------------------

ImportPreview parseGoogleFitDaily(String text) {
  final rows = parseCsv(text);
  if (rows.length < 2) throw ImportFormatException('This file has no data rows.');
  final h = [for (final x in rows.first) x.trim().toLowerCase()];
  int col(String name) => h.indexOf(name);
  final iDate = col('date');
  if (iDate < 0) throw ImportFormatException('The Google Fit file is missing its Date column.');
  final iSteps = col('step count'), iDist = col('distance (m)'), iCal = col('calories (kcal)'), iMove = col('move minutes count'), iHr = col('average heart rate (bpm)');
  final daily = <String, Map<String, Object?>>{};
  var skipped = 0;
  for (final r in rows.skip(1)) {
    String? v(int i) => i >= 0 && i < r.length && r[i].trim().isNotEmpty ? r[i].trim() : null;
    final date = DateTime.tryParse(v(iDate) ?? '');
    if (date == null) {
      skipped++;
      continue;
    }
    final f = <String, Object?>{
      'steps': double.tryParse(v(iSteps) ?? '')?.round(),
      'distanceKm': double.tryParse(v(iDist) ?? '') == null ? null : double.parse((double.parse(v(iDist)!) / 1000).toStringAsFixed(2)),
      'calories': double.tryParse(v(iCal) ?? '')?.round(),
      'activeMinutes': double.tryParse(v(iMove) ?? '')?.round(),
      'heartRateAvg': double.tryParse(v(iHr) ?? '')?.round(),
    }..removeWhere((k, x) => x == null || x == 0);
    if (f.isEmpty) {
      skipped++;
      continue;
    }
    f['stepsSource'] = 'Google Fit';
    daily[dayKey(date)] = f;
  }
  if (daily.isEmpty) throw ImportFormatException('No days with activity were found in this file.');
  return ImportPreview(kind: ExportKind.googleFit, workouts: const [], daily: daily, skipped: skipped);
}

// ---------------------------------------------------------------------------
// Samsung Health — CSV files from "Download personal data"
// ---------------------------------------------------------------------------

const _samsungExercise = {
  1001: 'walk', 1002: 'run', 11007: 'cycle', 13001: 'hike', 14001: 'swim', 14002: 'swim', 9002: 'yoga', 10004: 'strength', 10007: 'strength', 15005: 'other', 15006: 'other', 13002: 'climb', 16001: 'sports',
};

/// "2023-01-05 08:00:00.000" (UTC in Samsung exports) → local.
DateTime? _samsungTime(String? s) {
  if (s == null || s.isEmpty) return null;
  final ms = int.tryParse(s);
  if (ms != null) return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
  final d = DateTime.tryParse('${s.replaceFirst(' ', 'T')}Z');
  return d?.toLocal();
}

ImportPreview parseSamsungCsvs(List<String> files) {
  final workouts = <ImportedWorkout>[];
  final perDay = <String, Map<String, Map<String, double>>>{};
  var skipped = 0;
  var recognised = 0;
  for (final text in files) {
    final lines = text.split('\n');
    if (lines.length < 3) continue;
    // Line 1 is Samsung's metadata (table name), line 2 the header.
    final rows = parseCsv(lines.skip(1).join('\n'));
    if (rows.isEmpty) continue;
    final h = [for (final x in rows.first) x.trim()];
    int find(bool Function(String) test) => h.indexWhere(test);
    final iStart = find((x) => x.endsWith('exercise.start_time'));
    final iDayTime = find((x) => x == 'day_time');
    if (iStart >= 0) {
      recognised++;
      final iEnd = find((x) => x.endsWith('exercise.end_time'));
      final iType = find((x) => x.endsWith('exercise.exercise_type'));
      final iDist = find((x) => x.endsWith('exercise.distance'));
      final iCal = find((x) => x.endsWith('exercise.calorie'));
      final iUuid = find((x) => x.endsWith('datauuid'));
      for (final r in rows.skip(1)) {
        String? v(int i) => i >= 0 && i < r.length && r[i].trim().isNotEmpty ? r[i].trim() : null;
        final start = _samsungTime(v(iStart));
        final end = _samsungTime(v(iEnd));
        if (start == null || end == null || !end.isAfter(start)) {
          skipped++;
          continue;
        }
        final code = int.tryParse(v(iType) ?? '');
        final dist = double.tryParse(v(iDist) ?? '');
        final cal = double.tryParse(v(iCal) ?? '');
        workouts.add(ImportedWorkout(
          sourceId: 'samsung:${v(iUuid) ?? '${start.toUtc().toIso8601String()}:$code'}',
          source: 'Samsung Health',
          activity: _samsungExercise[code] ?? 'other',
          rawType: code?.toString(),
          start: start,
          end: end,
          distanceKm: dist == null || dist <= 0 ? null : dist / 1000,
          calories: cal == null || cal <= 0 ? null : cal.round(),
        ));
      }
    } else if (iDayTime >= 0) {
      final iCount = find((x) => x == 'count' || x == 'step_count');
      if (iCount < 0) continue;
      recognised++;
      final iDist = find((x) => x == 'distance');
      final iCal = find((x) => x == 'calorie');
      // Group by device so a phone and a watch counting the same walk
      // aren't added together.
      final iSrc = h.contains('deviceuuid') ? find((x) => x == 'deviceuuid') : find((x) => x == 'source_pkg_name');
      for (final r in rows.skip(1)) {
        String? v(int i) => i >= 0 && i < r.length && r[i].trim().isNotEmpty ? r[i].trim() : null;
        final ms = int.tryParse(v(iDayTime) ?? '');
        final steps = double.tryParse(v(iCount) ?? '');
        if (ms == null || steps == null) {
          skipped++;
          continue;
        }
        // day_time is midnight UTC of the local day.
        final d = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
        final key = dayKey(DateTime(d.year, d.month, d.day));
        final src = v(iSrc) ?? 'Samsung Health';
        final f = perDay.putIfAbsent(key, () => {});
        (f['steps'] ??= {})[src] = ((f['steps']![src]) ?? 0) + steps;
        final dist = double.tryParse(v(iDist) ?? '');
        if (dist != null) (f['distanceKm'] ??= {})[src] = ((f['distanceKm']![src]) ?? 0) + dist / 1000;
        final cal = double.tryParse(v(iCal) ?? '');
        if (cal != null) (f['calories'] ??= {})[src] = ((f['calories']![src]) ?? 0) + cal;
      }
    }
  }
  if (recognised == 0) throw ImportFormatException('These Samsung Health files don’t include step or exercise tables. Include the step_daily_trend and exercise CSVs.');
  final preview = ImportPreview(kind: ExportKind.samsungHealth, workouts: workouts, daily: _resolveDaily(perDay, const {}), skipped: skipped);
  if (preview.isEmpty) throw ImportFormatException('No steps or workouts were found in these Samsung Health files.');
  return preview;
}
