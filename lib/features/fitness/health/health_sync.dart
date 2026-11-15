import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:prism_plurality/core/features/feature_state.dart';
import 'package:prism_plurality/features/fitness/utils/fitness.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

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
  HealthCategory.calories => tr(c, 'Daily active calories, when the source records them.', 'Calorías activas diarias, si la fuente las registra.'),
  HealthCategory.heartRate => tr(c, 'Average heart rate per day and during workouts.', 'Frecuencia media por día y en los entrenamientos.'),
  HealthCategory.activeMinutes => tr(c, 'Minutes of exercise per day.', 'Minutos de ejercicio al día.'),
  HealthCategory.sleep => tr(c, 'Nightly sleep duration, shown in Fitness only.', 'Duración del sueño, solo en Ejercicio.'),
};

/// Health platform types read for each category.
List<HealthDataType> healthTypesFor(HealthCategory c, {required bool ios}) => switch (c) {
  HealthCategory.workouts => [HealthDataType.WORKOUT],
  HealthCategory.steps => [HealthDataType.STEPS],
  HealthCategory.distance => [ios ? HealthDataType.DISTANCE_WALKING_RUNNING : HealthDataType.DISTANCE_DELTA],
  HealthCategory.calories => [HealthDataType.ACTIVE_ENERGY_BURNED],
  HealthCategory.heartRate => [HealthDataType.HEART_RATE],
  HealthCategory.activeMinutes => ios ? [HealthDataType.EXERCISE_TIME] : [HealthDataType.WORKOUT],
  HealthCategory.sleep => [ios ? HealthDataType.SLEEP_ASLEEP : HealthDataType.SLEEP_SESSION],
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

/// A workout read from a health platform.
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
/// session synced by two apps).
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

/// Daily totals for one day.
class DailyHealth {
  DailyHealth(this.day);
  final DateTime day;
  int? steps;
  double? distanceKm;
  int? calories;
  int? activeMinutes;
  int? heartRateAvg;
  int? sleepMinutes;
  final Set<String> sources = {};
  Map<String, Object?> toFields() => {
    'steps': steps,
    'distanceKm': distanceKm == null ? null : double.parse(distanceKm!.toStringAsFixed(2)),
    'calories': calories,
    'activeMinutes': activeMinutes,
    'heartRateAvg': heartRateAvg,
    'sleepMinutes': sleepMinutes,
    'sources': sources.toList(),
  };
}

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

/// Talks to Health Connect / HealthKit. Swapped for a fake in tests.
abstract class HealthGateway {
  bool get supported;
  bool get ios;
  Future<String> availability(); // available, notInstalled, updateRequired, unsupported
  Future<void> install();
  Future<bool> request(List<HealthDataType> types);
  Future<bool?> has(List<HealthDataType> types);
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

  DateTime? get lastSync => DateTime.tryParse('${f['lastSync'] ?? ''}');
  String? get lastError => f['lastError'] as String?;
  int get imported => (f['imported'] as num?)?.toInt() ?? 0;
  int get duplicates => (f['duplicates'] as num?)?.toInt() ?? 0;
  List<String> get sourcesSeen => [for (final s in (f['sources'] as List?) ?? const []) '$s'];
}

final healthSettingsProvider = Provider<HealthSettings>((ref) {
  final rows = ref.watch(trackerKindProvider(TrackerKind.fitnessSource)).value ?? const <TrackerRecord>[];
  return HealthSettings(rows.isEmpty ? null : (rows.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt))).first);
});

/// Result of one sync.
class HealthSyncResult {
  const HealthSyncResult({this.workouts = 0, this.duplicates = 0, this.days = 0, this.error});
  final int workouts;
  final int duplicates;
  final int days;
  final String? error;
}

class HealthSyncService {
  HealthSyncService(this.ref);
  final Ref ref;
  HealthGateway get _g => ref.read(healthGatewayProvider);
  TrackerNotifier get _t => ref.read(trackerNotifierProvider.notifier);
  bool _running = false;

  Future<void> saveSettings(Map<String, Object?> changes) async {
    final s = ref.read(healthSettingsProvider).r;
    if (s == null) {
      await _t.create(kind: TrackerKind.fitnessSource, title: 'health', fields: changes);
    } else {
      await _t.save(s.withFields(changes));
    }
  }

  List<HealthDataType> typesFor(Set<HealthCategory> cats) => {for (final c in cats) ...healthTypesFor(c, ios: _g.ios)}.toList();

  /// Asks the platform for read access to [cats]. Nothing is connected
  /// unless the user grants it in the system dialog.
  Future<bool> connect(Set<HealthCategory> cats) async {
    final ok = await _g.request(typesFor(cats));
    await saveSettings({'connected': ok, 'categories': [for (final c in cats) c.name], 'lastError': ok ? null : 'denied'});
    return ok;
  }

  /// Stops syncing and (on Android) revokes Prism's Health Connect access.
  /// Imported records stay unless removed separately.
  Future<void> disconnect() async {
    try {
      await _g.revoke();
    } catch (_) {}
    await saveSettings({'connected': false});
  }

  /// Imports new data since the last sync (first sync: the last 30 days).
  Future<HealthSyncResult> sync({DateTime? now}) async {
    if (_running) return const HealthSyncResult();
    final s = ref.read(healthSettingsProvider);
    if (!s.connected || !isFeatureOn(ref, 'healthIntegration') || !isFeatureOn(ref, 'fitness')) return const HealthSyncResult();
    _running = true;
    try {
      final end = now ?? DateTime.now();
      final start = s.lastSync == null ? _day(end).subtract(const Duration(days: 30)) : _day(s.lastSync!).subtract(const Duration(days: 1));
      final cats = s.categories;
      final ios = _g.ios;
      final sources = {...s.sourcesSeen};
      var newWorkouts = 0, dups = 0;

      // Workouts.
      final workouts = <ImportedWorkout>[];
      if (cats.contains(HealthCategory.workouts) || cats.contains(HealthCategory.activeMinutes)) {
        for (final p in await _g.read([HealthDataType.WORKOUT], start, end)) {
          final v = p.value;
          if (v is! WorkoutHealthValue) continue;
          sources.add(p.sourceName);
          final dist = v.totalDistance == null ? null : (v.totalDistanceUnit == HealthDataUnit.MILE ? v.totalDistance! * 1.609344 : v.totalDistance! / 1000);
          workouts.add(ImportedWorkout(
            sourceId: p.uuid,
            source: p.sourceName,
            activity: mapWorkoutActivity(v.workoutActivityType.name),
            rawType: v.workoutActivityType.name,
            start: p.dateFrom.toLocal(),
            end: p.dateTo.toLocal(),
            distanceKm: dist,
            calories: v.totalEnergyBurned,
          ));
        }
      }
      if (cats.contains(HealthCategory.workouts) && workouts.isNotEmpty) {
        final existing = ref.read(trackerKindProvider(TrackerKind.fitnessWorkout)).value ?? (await ref.read(trackerRecordsProvider.future)).where((r) => r.kind == TrackerKind.fitnessWorkout).toList();
        final (fresh, d) = dedupeWorkouts(existing, workouts);
        dups += d;
        for (final w in fresh) {
          await _t.create(
            kind: TrackerKind.fitnessWorkout,
            title: '',
            occurredAt: w.start,
            endedAt: w.end,
            memberId: s.defaultAlter,
            fields: {
              FitField.activity: w.activity,
              FitField.minutes: w.minutes,
              FitField.distanceKm: w.distanceKm == null ? null : double.parse(w.distanceKm!.toStringAsFixed(2)),
              FitField.calories: w.calories,
              'imported': true,
              'source': w.source,
              'sourceId': w.sourceId,
              'sourceType': w.rawType,
              'platform': ios ? 'healthkit' : 'healthconnect',
            },
          );
          newWorkouts++;
        }
      }

      // Daily totals.
      final days = <DateTime, DailyHealth>{};
      DailyHealth dayOf(DateTime t) => days.putIfAbsent(_day(t.toLocal()), () => DailyHealth(_day(t.toLocal())));
      for (var d = _day(start); !d.isAfter(end); d = DateTime(d.year, d.month, d.day + 1)) {
        dayOf(d);
      }
      if (cats.contains(HealthCategory.steps)) {
        for (final day in days.keys.toList()) {
          final n = await _g.steps(day, DateTime(day.year, day.month, day.day + 1).isAfter(end) ? end : DateTime(day.year, day.month, day.day + 1));
          if (n != null && n > 0) days[day]!.steps = n;
        }
      }
      Future<void> sumInto(List<HealthDataType> types, void Function(DailyHealth, num) add) async {
        for (final p in await _g.read(types, start, end)) {
          final v = p.value;
          if (v is! NumericHealthValue) continue;
          sources.add(p.sourceName);
          final dh = dayOf(p.dateFrom);
          dh.sources.add(p.sourceName);
          add(dh, v.numericValue);
        }
      }

      if (cats.contains(HealthCategory.distance)) {
        await sumInto(healthTypesFor(HealthCategory.distance, ios: ios), (d, v) => d.distanceKm = (d.distanceKm ?? 0) + v / 1000);
      }
      if (cats.contains(HealthCategory.calories)) {
        await sumInto([HealthDataType.ACTIVE_ENERGY_BURNED], (d, v) => d.calories = (d.calories ?? 0) + v.round());
      }
      if (cats.contains(HealthCategory.heartRate)) {
        final sums = <DateTime, (num, int)>{};
        for (final p in await _g.read([HealthDataType.HEART_RATE], start, end)) {
          final v = p.value;
          if (v is! NumericHealthValue) continue;
          final k = _day(p.dateFrom.toLocal());
          final cur = sums[k] ?? (0, 0);
          sums[k] = (cur.$1 + v.numericValue, cur.$2 + 1);
        }
        for (final e in sums.entries) {
          dayOf(e.key).heartRateAvg = (e.value.$1 / e.value.$2).round();
        }
      }
      if (cats.contains(HealthCategory.activeMinutes)) {
        if (ios) {
          await sumInto([HealthDataType.EXERCISE_TIME], (d, v) => d.activeMinutes = (d.activeMinutes ?? 0) + v.round());
        } else {
          for (final w in workouts) {
            final d = dayOf(w.start);
            d.activeMinutes = (d.activeMinutes ?? 0) + w.minutes;
          }
        }
      }
      if (cats.contains(HealthCategory.sleep)) {
        for (final p in await _g.read(healthTypesFor(HealthCategory.sleep, ios: ios), start, end)) {
          final d = dayOf(p.dateTo);
          d.sleepMinutes = (d.sleepMinutes ?? 0) + p.dateTo.difference(p.dateFrom).inMinutes;
          sources.add(p.sourceName);
        }
      }
      final existingDaily = {
        for (final r in ref.read(trackerKindProvider(TrackerKind.fitnessDaily)).value ?? const <TrackerRecord>[])
          if (r.occurredAt != null) _day(r.occurredAt!.toLocal()): r,
      };
      var savedDays = 0;
      for (final d in days.values) {
        final fields = d.toFields();
        if (fields.entries.where((e) => e.key != 'sources').every((e) => e.value == null)) continue;
        final prev = existingDaily[d.day];
        if (prev == null) {
          await _t.create(kind: TrackerKind.fitnessDaily, occurredAt: d.day, memberId: s.defaultAlter, fields: {...fields, 'platform': ios ? 'healthkit' : 'healthconnect'});
        } else {
          await _t.save(prev.withFields(fields));
        }
        savedDays++;
      }

      await saveSettings({
        'lastSync': end.toIso8601String(),
        'lastError': null,
        'imported': s.imported + newWorkouts,
        'duplicates': s.duplicates + dups,
        'sources': sources.where((x) => x.trim().isNotEmpty).toList(),
      });
      return HealthSyncResult(workouts: newWorkouts, duplicates: dups, days: savedDays);
    } catch (e) {
      await saveSettings({'lastError': '$e'});
      return HealthSyncResult(error: '$e');
    } finally {
      _running = false;
    }
  }

  /// Removes everything imported from health apps (manual entries stay).
  Future<int> removeImported() async {
    final all = await ref.read(trackerRecordsProvider.future);
    var n = 0;
    for (final r in all) {
      if ((r.kind == TrackerKind.fitnessWorkout && r.flag('imported')) || r.kind == TrackerKind.fitnessDaily) {
        await _t.delete(r.id, children: false);
        n++;
      }
    }
    await saveSettings({'imported': 0, 'lastSync': null});
    return n;
  }
}

final healthSyncProvider = Provider<HealthSyncService>(HealthSyncService.new);

/// Syncs a few seconds after launch and every 30 minutes while Prism is
/// open, when connected with automatic sync on.
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
