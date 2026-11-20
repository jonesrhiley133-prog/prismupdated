import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/core/features/feature_state.dart';
import 'package:prism_plurality/features/fitness/utils/fitness.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

// Why imports used to fail (kept here so it isn't reintroduced):
//
// * On Health Connect the plugin reads a workout's distance, total calories
//   and steps alongside the exercise session. Prism only asked for exercise
//   access, so every workout read hit a SecurityException — which the plugin
//   swallows and turns into an EMPTY list. Workouts never arrived and no
//   error was shown.
// * A partly granted request (e.g. steps allowed, heart rate denied) was
//   stored as "not connected", so nothing synced at all.
// * Calories were read as "active calories", which Samsung Health doesn't
//   write to Health Connect (it writes total calories), so they stayed empty.
// * Daily totals were matched against a list that might not have loaded
//   yet, which could create duplicate days.
//
// Now each category is requested, checked, read and saved on its own, with
// its own progress cursor; results report exactly what came back per type.

/// Categories the user can choose to import.
enum HealthCategory { workouts, steps, distance, calories, heartRate, activeMinutes, sleep }

String healthCategoryText(BuildContext c, HealthCategory k) => switch (k) {
  HealthCategory.workouts => tr(c, 'Workouts & exercise sessions', 'Entrenamientos y sesiones'),
  HealthCategory.steps => tr(c, 'Steps', 'Pasos'),
  HealthCategory.distance => tr(c, 'Distance', 'Distancia'),
  HealthCategory.calories => tr(c, 'Calories burned', 'Calorías quemadas'),
  HealthCategory.heartRate => tr(c, 'Heart rate', 'Frecuencia cardiaca'),
  HealthCategory.activeMinutes => tr(c, 'Active minutes', 'Minutos activos'),
  HealthCategory.sleep => tr(c, 'Sleep (separate opt-in)', 'Sueño (opcional aparte)'),
};

String healthCategoryWhy(BuildContext c, HealthCategory k) => switch (k) {
  HealthCategory.workouts => tr(c, 'Type, start and end time, duration, distance and calories of each workout.', 'Tipo, inicio y fin, duración, distancia y calorías de cada entrenamiento.'),
  HealthCategory.steps => tr(c, 'Your daily step count.', 'Tus pasos diarios.'),
  HealthCategory.distance => tr(c, 'Daily distance walked or run.', 'Distancia diaria caminada o corrida.'),
  HealthCategory.calories => tr(c, 'Daily calories burned, as recorded by the source app.', 'Calorías diarias quemadas, según la app de origen.'),
  HealthCategory.heartRate => tr(c, 'Average heart rate per day.', 'Frecuencia media por día.'),
  HealthCategory.activeMinutes => tr(c, 'Minutes of exercise per day.', 'Minutos de ejercicio al día.'),
  HealthCategory.sleep => tr(c, 'Nightly sleep duration, shown in Fitness only.', 'Duración del sueño, solo en Ejercicio.'),
};

/// Types read for a category.
List<HealthDataType> healthTypesFor(HealthCategory c, {required bool ios}) => switch (c) {
  HealthCategory.workouts => [HealthDataType.WORKOUT],
  HealthCategory.steps => [HealthDataType.STEPS],
  HealthCategory.distance => [ios ? HealthDataType.DISTANCE_WALKING_RUNNING : HealthDataType.DISTANCE_DELTA],
  HealthCategory.calories => ios ? [HealthDataType.ACTIVE_ENERGY_BURNED] : [HealthDataType.TOTAL_CALORIES_BURNED, HealthDataType.ACTIVE_ENERGY_BURNED],
  HealthCategory.heartRate => [HealthDataType.HEART_RATE],
  HealthCategory.activeMinutes => ios ? [HealthDataType.EXERCISE_TIME] : [HealthDataType.WORKOUT],
  HealthCategory.sleep => [ios ? HealthDataType.SLEEP_ASLEEP : HealthDataType.SLEEP_SESSION],
};

/// Types that must be granted before a category can be read. On Health
/// Connect a workout read also reads distance, total calories and steps.
List<HealthDataType> requiredTypesFor(HealthCategory c, {required bool ios}) => switch (c) {
  HealthCategory.workouts || HealthCategory.activeMinutes when !ios => [HealthDataType.WORKOUT, HealthDataType.DISTANCE_DELTA, HealthDataType.TOTAL_CALORIES_BURNED, HealthDataType.STEPS],
  HealthCategory.calories when !ios => [HealthDataType.TOTAL_CALORIES_BURNED],
  _ => healthTypesFor(c, ios: ios),
};

/// Prism activity for a platform workout type.
String mapWorkoutActivity(String type) {
  final t = type.toLowerCase();
  if (t.contains('walk')) return 'walk';
  if (t.contains('run') || t.contains('jog')) return 'run';
  if (t.contains('bik') || t.contains('cycl')) return 'cycle';
  if (t.contains('swim')) return 'swim';
  if (t.contains('strength') || t.contains('weight') || t.contains('calisthenics')) return 'strength';
  if (t.contains('yoga') || t.contains('pilates')) return 'yoga';
  if (t.contains('interval') || t.contains('hiit')) return 'hiit';
  if (t.contains('hik')) return 'hike';
  if (t.contains('danc')) return 'dance';
  if (t.contains('climb')) return 'climb';
  if (t.contains('row')) return 'row';
  if (t.contains('stretch') || t.contains('flexibility')) return 'stretch';
  if (const ['ball', 'tennis', 'soccer', 'football', 'hockey', 'golf', 'rugby', 'cricket', 'badminton', 'volley', 'squash', 'boxing', 'martial', 'skat', 'ski', 'surf']
      .any(t.contains)) {
    return 'sports';
  }
  return 'other';
}

/// Friendly names for common source apps (package names otherwise).
String sourceAppName(String raw) {
  const known = {
    'com.sec.android.app.shealth': 'Samsung Health',
    'com.google.android.apps.fitness': 'Google Fit',
    'com.google.android.apps.healthdata': 'Health Connect',
    'com.fitbit.FitbitMobile': 'Fitbit',
    'com.strava': 'Strava',
    'com.garmin.android.apps.connectmobile': 'Garmin Connect',
    'com.huawei.health': 'Huawei Health',
    'com.xiaomi.hm.health': 'Zepp Life',
    'com.ouraring.oura': 'Oura',
  };
  return known[raw] ?? raw;
}

/// A workout from a provider or file.
class ImportedWorkout {
  const ImportedWorkout({required this.sourceId, required this.source, required this.activity, required this.start, required this.end, this.distanceKm, this.calories, this.heartRate, this.rawType});
  final String sourceId;
  final String source;
  final String activity;
  final DateTime start;
  final DateTime end;
  final double? distanceKm;
  final int? calories;
  final int? heartRate;
  final String? rawType;
  int get minutes => end.difference(start).inMinutes;
}

/// Splits incoming workouts into new ones and duplicates. A workout is a
/// duplicate when its source id was imported before, or when another
/// workout of the same activity overlaps it almost exactly (the same
/// session synced by two apps, or already logged by hand).
@visibleForTesting
(List<ImportedWorkout> fresh, int duplicates) dedupeWorkouts(List<TrackerRecord> existing, List<ImportedWorkout> incoming) {
  final ids = {for (final r in existing) ?r.str('sourceId')};
  final kept = <ImportedWorkout>[];
  var dups = 0;
  bool overlaps(DateTime s1, int m1, DateTime s2, int m2) => s1.difference(s2).inMinutes.abs() <= 3 && (m1 - m2).abs() <= 3;
  for (final w in incoming) {
    if (ids.contains(w.sourceId)) {
      dups++;
      continue;
    }
    final clash = existing.any((r) => r.str(FitField.activity) == w.activity && r.occurredAt != null && overlaps(r.occurredAt!, r.integer(FitField.minutes) ?? 0, w.start, w.minutes)) ||
        kept.any((k) => k.activity == w.activity && overlaps(k.start, k.minutes, w.start, w.minutes));
    if (clash) {
      dups++;
      continue;
    }
    kept.add(w);
    ids.add(w.sourceId);
  }
  return (kept, dups);
}

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

/// Local calendar day key: keeps a day's totals on the same record however
/// the time zone changes later.
String dayKey(DateTime t) {
  final d = t.toLocal();
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Picks one source per day for summed metrics so two apps recording the
/// same walk aren't added together: the source with the largest total.
/// Returns (value, source).
(double, String)? pickDailySource(Map<String, double> bySource) {
  if (bySource.isEmpty) return null;
  final best = bySource.entries.reduce((a, b) => b.value > a.value ? b : a);
  return (best.value, best.key);
}

/// One value per metric for a day covered by several imports (live sync and
/// files): the largest, matching [pickDailySource].
Map<String, num?> mergeDailyRows(Iterable<TrackerRecord> rows) {
  const fields = ['steps', 'distanceKm', 'calories', 'activeMinutes', 'heartRateAvg', 'sleepMinutes'];
  final out = <String, num?>{};
  for (final f in fields) {
    num? best;
    for (final r in rows) {
      final v = r.fields[f];
      if (v is num && (best == null || v > best)) best = v;
    }
    out[f] = best;
  }
  return out;
}

/// Talks to Health Connect / HealthKit. Swapped for a fake in tests.
abstract class HealthGateway {
  bool get supported;
  bool get ios;
  Future<String> availability(); // available, notInstalled, updateRequired, unsupported
  Future<void> install();
  Future<bool> request(List<HealthDataType> types);

  /// True/false where the platform says; null where it won't tell (iOS
  /// never reveals read access).
  Future<bool?> has(List<HealthDataType> types);
  Future<bool> requestHistory();
  Future<void> revoke();
  Future<List<HealthDataPoint>> read(List<HealthDataType> types, DateTime from, DateTime to);
  Future<int?> steps(DateTime from, DateTime to);
}

class PluginHealthGateway implements HealthGateway {
  final Health _h = Health();
  bool _configured = false;
  Future<void> _cfg() async {
    if (_configured) return;
    await _h.configure();
    _configured = true;
  }

  @override
  bool get supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  @override
  bool get ios => !kIsWeb && Platform.isIOS;

  @override
  Future<String> availability() async {
    if (!supported) return 'unsupported';
    if (ios) return 'available';
    await _cfg();
    final s = await _h.getHealthConnectSdkStatus();
    return switch (s) {
      HealthConnectSdkStatus.sdkAvailable => 'available',
      HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired => 'updateRequired',
      _ => 'notInstalled',
    };
  }

  @override
  Future<void> install() async {
    await _cfg();
    await _h.installHealthConnect();
  }

  @override
  Future<bool> request(List<HealthDataType> types) async {
    await _cfg();
    if (!ios && types.any((t) => t == HealthDataType.STEPS || t == HealthDataType.WORKOUT)) {
      await Permission.activityRecognition.request();
    }
    return _h.requestAuthorization(types, permissions: [for (final _ in types) HealthDataAccess.READ]);
  }

  @override
  Future<bool?> has(List<HealthDataType> types) async {
    await _cfg();
    return _h.hasPermissions(types, permissions: [for (final _ in types) HealthDataAccess.READ]);
  }

  @override
  Future<bool> requestHistory() async {
    if (ios) return true;
    await _cfg();
    try {
      if (!await _h.isHealthDataHistoryAvailable()) return false;
      if (await _h.isHealthDataHistoryAuthorized()) return true;
      return await _h.requestHealthDataHistoryAuthorization();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> revoke() async {
    await _cfg();
    if (!ios) await _h.revokePermissions();
  }

  @override
  Future<List<HealthDataPoint>> read(List<HealthDataType> types, DateTime from, DateTime to) async {
    await _cfg();
    final pts = await _h.getHealthDataFromTypes(types: types, startTime: from, endTime: to);
    return _h.removeDuplicates(pts);
  }

  @override
  Future<int?> steps(DateTime from, DateTime to) async {
    await _cfg();
    return _h.getTotalStepsInInterval(from, to);
  }
}

final healthGatewayProvider = Provider<HealthGateway>((ref) => PluginHealthGateway());

/// Per-category outcome of the last sync.
class CategoryResult {
  const CategoryResult({required this.status, this.created = 0, this.updated = 0, this.duplicates = 0, this.error});

  /// ok, empty, failed, denied
  final String status;
  final int created;
  final int updated;
  final int duplicates;
  final String? error;

  Map<String, Object?> toJson() => {'status': status, 'created': created, 'updated': updated, 'duplicates': duplicates, 'error': error}..removeWhere((k, v) => v == null);
  static CategoryResult fromJson(Map j) => CategoryResult(
    status: (j['status'] as String?) ?? 'ok',
    created: (j['created'] as num?)?.toInt() ?? 0,
    updated: (j['updated'] as num?)?.toInt() ?? 0,
    duplicates: (j['duplicates'] as num?)?.toInt() ?? 0,
    error: j['error'] as String?,
  );
}

/// Integration settings (one synced record).
class HealthSettings {
  const HealthSettings([this.r]);
  final TrackerRecord? r;
  Map<String, dynamic> get f => r?.fields ?? const {};
  bool get connected => f['connected'] == true;
  bool get autoSync => f['autoSync'] != false;
  bool get assistantSeen => f['assistantSeen'] == true;
  String? get defaultAlter => f['defaultAlter'] as String?;
  Set<HealthCategory> get categories {
    final raw = f['categories'];
    if (raw is! List) return {HealthCategory.workouts, HealthCategory.steps, HealthCategory.distance, HealthCategory.calories, HealthCategory.activeMinutes};
    return {for (final c in HealthCategory.values) if (raw.contains(c.name)) c};
  }

  Set<HealthCategory> _set(String key) => {for (final c in HealthCategory.values) if ((f[key] as List?)?.contains(c.name) ?? false) c};

  /// Categories the platform confirmed as allowed / refused.
  Set<HealthCategory> get granted => _set('granted');
  Set<HealthCategory> get denied => _set('denied');

  /// Days of history for the first import.
  int get historyDays => (f['historyDays'] as num?)?.toInt() ?? 30;

  DateTime? get lastSync => DateTime.tryParse('${f['lastSync'] ?? ''}');
  DateTime? get lastAttempt => DateTime.tryParse('${f['lastAttempt'] ?? ''}');
  String? get lastError => f['lastError'] as String?;
  int get imported => (f['imported'] as num?)?.toInt() ?? 0;
  int get duplicates => (f['duplicates'] as num?)?.toInt() ?? 0;
  List<String> get sourcesSeen => [for (final s in (f['sources'] as List?) ?? const []) sourceAppName('$s')];

  /// Where each category got to (only advanced after its data is saved).
  DateTime? cursor(HealthCategory c) => DateTime.tryParse('${(f['cursors'] as Map?)?[c.name] ?? ''}');

  Map<HealthCategory, CategoryResult> get lastResults => {
    for (final c in HealthCategory.values)
      if ((f['lastResult'] as Map?)?[c.name] is Map) c: CategoryResult.fromJson((f['lastResult'] as Map)[c.name] as Map),
  };
}

final healthSettingsProvider = Provider<HealthSettings>((ref) {
  final rows = ref.watch(trackerKindProvider(TrackerKind.fitnessSource)).value ?? const <TrackerRecord>[];
  return HealthSettings(_settingsRow(rows));
});

TrackerRecord? _settingsRow(Iterable<TrackerRecord> rows) {
  final list = [for (final r in rows) if (r.kind == TrackerKind.fitnessSource && r.title == 'health') r]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  if (list.isNotEmpty) return list.first;
  final any = [for (final r in rows) if (r.kind == TrackerKind.fitnessSource && r.str('fileSource') == null) r]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return any.firstOrNull;
}

/// Result of one sync.
class HealthSyncResult {
  const HealthSyncResult({this.workouts = 0, this.updated = 0, this.duplicates = 0, this.days = 0, this.error, this.byCategory = const {}});
  final int workouts;
  final int updated;
  final int duplicates;
  final int days;
  final String? error;
  final Map<HealthCategory, CategoryResult> byCategory;
  bool get partial => byCategory.values.any((r) => r.status == 'failed' || r.status == 'denied') && byCategory.values.any((r) => r.status == 'ok' || r.status == 'empty');
}

/// Writes imported workouts and daily totals idempotently. Shared by live
/// sync and file import.
class FitnessWriter {
  FitnessWriter(this.ref);
  final Ref ref;
  TrackerNotifier get _t => ref.read(trackerNotifierProvider.notifier);

  Future<List<TrackerRecord>> _all() => ref.read(trackerRecordRepositoryProvider).getAll();

  /// Upserts workouts. A workout with a known source id is updated when the
  /// provider changed it (unless edited by hand in Prism); an almost
  /// identical session from another source is skipped as a duplicate.
  Future<(int created, int updated, int duplicates)> upsertWorkouts(List<ImportedWorkout> incoming, {required String platform, String? memberId}) async {
    final existing = [for (final r in await _all()) if (r.kind == TrackerKind.fitnessWorkout) r];
    final byId = {for (final r in existing) if (r.str('sourceId') != null) r.str('sourceId')!: r};
    var created = 0, updated = 0, dups = 0;
    final fresh = <ImportedWorkout>[];
    for (final w in incoming) {
      final prev = byId[w.sourceId];
      if (prev == null) {
        fresh.add(w);
        continue;
      }
      final changed = prev.integer(FitField.minutes) != w.minutes ||
          prev.occurredAt?.toUtc() != w.start.toUtc() ||
          (w.distanceKm != null && (prev.number(FitField.distanceKm) ?? -1) != double.parse(w.distanceKm!.toStringAsFixed(2))) ||
          (w.calories != null && prev.integer(FitField.calories) != w.calories);
      if (!changed || prev.flag('manualEdit')) {
        dups++;
        continue;
      }
      await _t.save(prev.copyWith(occurredAt: w.start, endedAt: w.end).withFields(_workoutFields(w, platform)));
      updated++;
    }
    final (keep, d) = dedupeWorkouts(existing, fresh);
    dups += d;
    for (final w in keep) {
      await _t.create(kind: TrackerKind.fitnessWorkout, occurredAt: w.start, endedAt: w.end, memberId: memberId, fields: _workoutFields(w, platform));
      created++;
    }
    return (created, updated, dups);
  }

  Map<String, Object?> _workoutFields(ImportedWorkout w, String platform) => {
    FitField.activity: w.activity,
    FitField.minutes: w.minutes,
    FitField.distanceKm: w.distanceKm == null ? null : double.parse(w.distanceKm!.toStringAsFixed(2)),
    FitField.calories: w.calories,
    'imported': true,
    'source': sourceAppName(w.source),
    'sourceId': w.sourceId,
    'sourceType': w.rawType,
    'platform': platform,
  };

  /// Merges daily values (field → value) into one record per local day and
  /// platform. Only the given fields change, so a failed category never
  /// wipes another's numbers.
  Future<int> upsertDaily(Map<String, Map<String, Object?>> byDay, {required String platform, String? memberId}) async {
    if (byDay.isEmpty) return 0;
    final existing = <String, TrackerRecord>{};
    for (final r in await _all()) {
      if (r.kind != TrackerKind.fitnessDaily) continue;
      if ((r.str('platform') ?? platform) != platform) continue;
      final k = r.str('dayKey') ?? (r.occurredAt == null ? null : dayKey(r.occurredAt!));
      if (k != null) existing.putIfAbsent(k, () => r);
    }
    var n = 0;
    for (final e in byDay.entries) {
      final values = {...e.value}..removeWhere((k, v) => v == null);
      if (values.isEmpty) continue;
      final prev = existing[e.key];
      final parts = e.key.split('-').map(int.parse).toList();
      if (prev == null) {
        await _t.create(kind: TrackerKind.fitnessDaily, occurredAt: DateTime(parts[0], parts[1], parts[2]), memberId: memberId, fields: {...values, 'dayKey': e.key, 'platform': platform});
      } else {
        await _t.save(prev.withFields({...values, 'dayKey': e.key}));
      }
      n++;
    }
    return n;
  }
}

final fitnessWriterProvider = Provider<FitnessWriter>(FitnessWriter.new);

class HealthSyncService {
  HealthSyncService(this.ref);
  final Ref ref;
  HealthGateway get _g => ref.read(healthGatewayProvider);
  TrackerNotifier get _t => ref.read(trackerNotifierProvider.notifier);
  FitnessWriter get _w => ref.read(fitnessWriterProvider);
  bool _running = false;

  String get _platform => _g.ios ? 'healthkit' : 'healthconnect';

  /// Settings read from storage (not from a stream that may not have
  /// delivered yet).
  Future<HealthSettings> _settingsNow() async => HealthSettings(_settingsRow(await ref.read(trackerRecordRepositoryProvider).getAll()));

  Future<void> saveSettings(Map<String, Object?> changes) async {
    final s = (await _settingsNow()).r;
    if (s == null) {
      await _t.create(kind: TrackerKind.fitnessSource, title: 'health', fields: changes);
    } else {
      await _t.save(s.withFields(changes));
    }
  }

  List<HealthDataType> typesFor(Set<HealthCategory> cats) => {for (final c in cats) ...healthTypesFor(c, ios: _g.ios), for (final c in cats) ...requiredTypesFor(c, ios: _g.ios)}.toList();

  /// Asks for read access to [cats], then checks each category: a partial
  /// grant still connects, syncing what was allowed.
  Future<bool> connect(Set<HealthCategory> cats, {int? historyDays}) async {
    await _g.request(typesFor(cats));
    final granted = <HealthCategory>{}, denied = <HealthCategory>{};
    for (final c in cats) {
      final ok = await _g.has(requiredTypesFor(c, ios: _g.ios));
      if (ok == false) {
        denied.add(c);
      } else {
        granted.add(c);
      }
    }
    if ((historyDays ?? 30) > 30 && granted.isNotEmpty) await _g.requestHistory();
    final connected = granted.isNotEmpty;
    await saveSettings({
      'connected': connected,
      'categories': [for (final c in cats) c.name],
      'granted': [for (final c in granted) c.name],
      'denied': [for (final c in denied) c.name],
      'historyDays': ?historyDays,
      'lastError': connected ? null : 'denied',
    });
    return connected;
  }

  /// Stops syncing and (on Android) revokes Prism's Health Connect access.
  /// Imported records stay unless removed separately.
  Future<void> disconnect() async {
    try {
      await _g.revoke();
    } catch (_) {}
    await saveSettings({'connected': false, 'granted': const <String>[], 'cursors': null});
  }

  /// Imports new data. Each category is read and saved on its own; its
  /// cursor only moves forward once its records are stored.
  Future<HealthSyncResult> sync({DateTime? now, bool force = false}) async {
    if (_running) return const HealthSyncResult();
    final s = await _settingsNow();
    if (!s.connected || !isFeatureOn(ref, 'healthIntegration') || !isFeatureOn(ref, 'fitness')) return const HealthSyncResult();
    _running = true;
    final end = now ?? DateTime.now();
    final ios = _g.ios;
    final results = <HealthCategory, CategoryResult>{};
    final cursors = Map<String, Object?>.of((s.f['cursors'] as Map?)?.cast<String, Object?>() ?? const {});
    final sources = {...((s.f['sources'] as List?) ?? const []).map((e) => '$e')};
    var created = 0, updated = 0, dups = 0, days = 0;
    try {
      await saveSettings({'lastAttempt': end.toIso8601String()});

      // Re-check access so a permission revoked in system settings shows up.
      final denied = <HealthCategory>{...s.denied};
      for (final c in s.categories) {
        try {
          final ok = await _g.has(requiredTypesFor(c, ios: ios));
          if (ok == false) {
            denied.add(c);
          } else if (ok == true) {
            denied.remove(c);
          }
        } catch (_) {}
      }

      DateTime startFor(HealthCategory c) {
        final cur = s.cursor(c);
        if (cur == null || force) return _day(end).subtract(Duration(days: s.historyDays));
        return _day(cur).subtract(const Duration(days: 1));
      }

      Future<void> run(HealthCategory c, Future<CategoryResult> Function(DateTime from) body) async {
        if (!s.categories.contains(c)) return;
        if (denied.contains(c)) {
          results[c] = const CategoryResult(status: 'denied');
          return;
        }
        try {
          final r = await body(startFor(c));
          results[c] = r;
          cursors[c.name] = end.toIso8601String();
        } catch (e) {
          results[c] = CategoryResult(status: 'failed', error: _short(e));
        }
      }

      final workouts = <ImportedWorkout>[];
      Future<void> readWorkouts(DateTime from) async {
        if (workouts.isNotEmpty) return;
        for (final p in await _g.read([HealthDataType.WORKOUT], from, end)) {
          final v = p.value;
          if (v is! WorkoutHealthValue) continue;
          sources.add(p.sourceName);
          final dist = v.totalDistance == null
              ? null
              : switch (v.totalDistanceUnit) {
                  HealthDataUnit.MILE => v.totalDistance! * 1.609344,
                  _ => v.totalDistance! / 1000,
                };
          workouts.add(ImportedWorkout(
            sourceId: '$_platform:${p.uuid}',
            source: p.sourceName,
            activity: mapWorkoutActivity(v.workoutActivityType.name),
            rawType: v.workoutActivityType.name,
            start: p.dateFrom.toLocal(),
            end: p.dateTo.toLocal(),
            distanceKm: dist == null || dist <= 0 ? null : dist,
            calories: v.totalEnergyBurned == null || v.totalEnergyBurned! <= 0 ? null : v.totalEnergyBurned,
          ));
        }
      }

      await run(HealthCategory.workouts, (from) async {
        await readWorkouts(from);
        if (workouts.isEmpty) return const CategoryResult(status: 'empty');
        final (cr, up, du) = await _w.upsertWorkouts(workouts, platform: _platform, memberId: s.defaultAlter);
        created += cr;
        updated += up;
        dups += du;
        return CategoryResult(status: 'ok', created: cr, updated: up, duplicates: du);
      });

      Future<CategoryResult> saveDaily(Map<String, Map<String, Object?>> byDay) async {
        if (byDay.isEmpty) return const CategoryResult(status: 'empty');
        final n = await _w.upsertDaily(byDay, platform: _platform, memberId: s.defaultAlter);
        days += n;
        return CategoryResult(status: 'ok', updated: n);
      }

      await run(HealthCategory.steps, (from) async {
        // The platform's aggregate already resolves overlapping sources.
        final byDay = <String, Map<String, Object?>>{};
        for (var d = _day(from); !d.isAfter(end); d = DateTime(d.year, d.month, d.day + 1)) {
          final next = DateTime(d.year, d.month, d.day + 1);
          final n = await _g.steps(d, next.isAfter(end) ? end : next);
          if (n != null && n > 0) byDay[dayKey(d)] = {'steps': n, 'stepsSource': ios ? 'Apple Health' : 'Health Connect'};
        }
        return saveDaily(byDay);
      });

      Future<Map<String, Map<String, Object?>>> summed(List<HealthDataType> types, DateTime from, String field, double Function(NumericHealthValue v, HealthDataUnit unit) value, {int digits = 0}) async {
        final perDay = <String, Map<String, double>>{};
        for (final p in await _g.read(types, from, end)) {
          final v = p.value;
          if (v is! NumericHealthValue) continue;
          sources.add(p.sourceName);
          final k = dayKey(p.dateFrom);
          final m = perDay.putIfAbsent(k, () => {});
          m[p.sourceName] = (m[p.sourceName] ?? 0) + value(v, p.unit);
        }
        return {
          for (final e in perDay.entries)
            if (pickDailySource(e.value) case (final total, final src) when total > 0)
              e.key: {field: digits == 0 ? total.round() : double.parse(total.toStringAsFixed(digits)), '${field}Source': sourceAppName(src)},
        };
      }

      await run(HealthCategory.distance, (from) async => saveDaily(await summed(healthTypesFor(HealthCategory.distance, ios: ios), from, 'distanceKm', (v, u) => switch (u) {
        HealthDataUnit.MILE => v.numericValue * 1.609344,
        _ => v.numericValue / 1000,
      }, digits: 2)));

      await run(HealthCategory.calories, (from) async {
        // Samsung Health writes total calories; others may write active.
        var byDay = await summed(ios ? [HealthDataType.ACTIVE_ENERGY_BURNED] : [HealthDataType.TOTAL_CALORIES_BURNED], from, 'calories', (v, u) => u == HealthDataUnit.JOULE ? v.numericValue / 4184 : v.numericValue.toDouble());
        if (byDay.isEmpty && !ios) byDay = await summed([HealthDataType.ACTIVE_ENERGY_BURNED], from, 'calories', (v, u) => v.numericValue.toDouble());
        return saveDaily(byDay);
      });

      await run(HealthCategory.heartRate, (from) async {
        final sums = <String, (double, int)>{};
        for (final p in await _g.read([HealthDataType.HEART_RATE], from, end)) {
          final v = p.value;
          if (v is! NumericHealthValue) continue;
          sources.add(p.sourceName);
          final k = dayKey(p.dateFrom);
          final cur = sums[k] ?? (0, 0);
          sums[k] = (cur.$1 + v.numericValue, cur.$2 + 1);
        }
        return saveDaily({for (final e in sums.entries) e.key: {'heartRateAvg': (e.value.$1 / e.value.$2).round()}});
      });

      await run(HealthCategory.activeMinutes, (from) async {
        if (ios) return saveDaily(await summed([HealthDataType.EXERCISE_TIME], from, 'activeMinutes', (v, u) => v.numericValue.toDouble()));
        await readWorkouts(from);
        final perDay = <String, int>{};
        for (final w in workouts) {
          final k = dayKey(w.start);
          perDay[k] = (perDay[k] ?? 0) + w.minutes;
        }
        return saveDaily({for (final e in perDay.entries) e.key: {'activeMinutes': e.value}});
      });

      await run(HealthCategory.sleep, (from) async {
        final perDay = <String, Map<String, double>>{};
        for (final p in await _g.read(healthTypesFor(HealthCategory.sleep, ios: ios), from, end)) {
          final k = dayKey(p.dateTo);
          final m = perDay.putIfAbsent(k, () => {});
          m[p.sourceName] = (m[p.sourceName] ?? 0) + p.dateTo.difference(p.dateFrom).inMinutes;
          sources.add(p.sourceName);
        }
        return saveDaily({
          for (final e in perDay.entries)
            if (pickDailySource(e.value) case (final total, _)) e.key: {'sleepMinutes': total.round()},
        });
      });

      final anyOk = results.values.any((r) => r.status == 'ok' || r.status == 'empty');
      final firstError = results.values.where((r) => r.status == 'failed').map((r) => r.error).firstOrNull;
      await saveSettings({
        if (anyOk) 'lastSync': end.toIso8601String(),
        'lastError': anyOk ? null : (firstError ?? (results.values.every((r) => r.status == 'denied') ? 'denied' : null)),
        'imported': s.imported + created,
        'duplicates': s.duplicates + dups,
        'sources': sources.where((x) => x.trim().isNotEmpty).toList(),
        'cursors': cursors,
        'denied': [for (final c in denied) c.name],
        'granted': [for (final c in s.categories) if (!denied.contains(c)) c.name],
        'lastResult': {for (final e in results.entries) e.key.name: e.value.toJson()},
      });
      return HealthSyncResult(workouts: created, updated: updated, duplicates: dups, days: days, byCategory: results, error: anyOk ? null : firstError);
    } catch (e) {
      await saveSettings({'lastError': _short(e)});
      return HealthSyncResult(error: _short(e), byCategory: results);
    } finally {
      _running = false;
    }
  }

  /// Error text without data: just the type and first line.
  static String _short(Object e) {
    final s = '$e'.split('\n').first;
    return s.length > 160 ? '${s.substring(0, 160)}…' : s;
  }

  /// Removes records imported from [platform] (all imports when null).
  /// Manual entries and hand-edited imports stay.
  Future<int> removeImported({String? platform}) async {
    final all = await ref.read(trackerRecordRepositoryProvider).getAll();
    var n = 0;
    for (final r in all) {
      final mine = platform == null || (r.str('platform') ?? 'healthconnect') == platform || (platform == 'healthconnect' && r.str('platform') == null);
      if (!mine) continue;
      if ((r.kind == TrackerKind.fitnessWorkout && r.flag('imported') && !r.flag('manualEdit')) || r.kind == TrackerKind.fitnessDaily) {
        await _t.delete(r.id, children: false);
        n++;
      }
    }
    if (platform == null || platform == _platform) await saveSettings({'imported': 0, 'lastSync': null, 'cursors': null});
    return n;
  }
}

final healthSyncProvider = Provider<HealthSyncService>(HealthSyncService.new);

/// Syncs a few seconds after launch and every 30 minutes while Prism is
/// open, when connected with automatic sync on. "Sync now" always works.
final healthAutoSyncProvider = Provider<void>((ref) {
  Timer? periodic;
  final first = Timer(const Duration(seconds: 8), () {
    if (!ref.mounted) return;
    Future<void> tick() async {
      final s = ref.read(healthSettingsProvider);
      if (s.connected && s.autoSync) await ref.read(healthSyncProvider).sync();
    }

    tick();
    periodic = Timer.periodic(const Duration(minutes: 30), (_) => tick());
  });
  ref.onDispose(() {
    first.cancel();
    periodic?.cancel();
  });
});
