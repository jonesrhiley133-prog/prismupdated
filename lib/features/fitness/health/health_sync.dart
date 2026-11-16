import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:health/health.dart';
import 'package:uuid/uuid.dart';
import 'package:uuid/enums.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:prism_plurality/core/features/feature_state.dart';
import 'package:prism_plurality/features/fitness/utils/fitness.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Categories the user can choose to import.
enum HealthCategory {
  workouts,
  steps,
  distance,
  calories,
  heartRate,
  activeMinutes,
  sleep,
}

String healthCategoryText(BuildContext c, HealthCategory k) => switch (k) {
  HealthCategory.workouts => tr(
    c,
    'Workouts & exercise sessions',
    'Entrenamientos y sesiones',
  ),
  HealthCategory.steps => tr(c, 'Steps', 'Pasos'),
  HealthCategory.distance => tr(c, 'Distance', 'Distancia'),
  HealthCategory.calories => tr(c, 'Calories burned', 'Calorías quemadas'),
  HealthCategory.heartRate => tr(c, 'Heart rate', 'Frecuencia cardiaca'),
  HealthCategory.activeMinutes => tr(c, 'Active minutes', 'Minutos activos'),
  HealthCategory.sleep => tr(
    c,
    'Sleep (separate opt-in)',
    'Sueño (opcional aparte)',
  ),
};

String healthCategoryWhy(BuildContext c, HealthCategory k) => switch (k) {
  HealthCategory.workouts => tr(
    c,
    'Type, start and end time, duration, distance and calories of each workout.',
    'Tipo, inicio y fin, duración, distancia y calorías de cada entrenamiento.',
  ),
  HealthCategory.steps => tr(c, 'Your daily step count.', 'Tus pasos diarios.'),
  HealthCategory.distance => tr(
    c,
    'Daily distance walked or run.',
    'Distancia diaria caminada o corrida.',
  ),
  HealthCategory.calories => tr(
    c,
    'Daily active calories, when the source records them.',
    'Calorías activas diarias, si la fuente las registra.',
  ),
  HealthCategory.heartRate => tr(
    c,
    'Average heart rate per day and during workouts.',
    'Frecuencia media por día y en los entrenamientos.',
  ),
  HealthCategory.activeMinutes => tr(
    c,
    'Minutes of exercise per day.',
    'Minutos de ejercicio al día.',
  ),
  HealthCategory.sleep => tr(
    c,
    'Nightly sleep duration, shown in Fitness only.',
    'Duración del sueño, solo en Ejercicio.',
  ),
};

/// Health platform types read for each category.
List<HealthDataType> healthTypesFor(HealthCategory c, {required bool ios}) =>
    switch (c) {
      HealthCategory.workouts => [HealthDataType.WORKOUT],
      HealthCategory.steps => [HealthDataType.STEPS],
      HealthCategory.distance => [
        ios
            ? HealthDataType.DISTANCE_WALKING_RUNNING
            : HealthDataType.DISTANCE_DELTA,
      ],
      HealthCategory.calories => [HealthDataType.ACTIVE_ENERGY_BURNED],
      HealthCategory.heartRate => [HealthDataType.HEART_RATE],
      HealthCategory.activeMinutes =>
        ios ? [HealthDataType.EXERCISE_TIME] : [HealthDataType.WORKOUT],
      HealthCategory.sleep => [
        ios ? HealthDataType.SLEEP_ASLEEP : HealthDataType.SLEEP_SESSION,
      ],
    };

/// Prism activity for a platform workout type.
String mapWorkoutActivity(String type) {
  final t = type.toLowerCase();
  if (t.contains('walk')) return 'walk';
  if (t.contains('run') || t.contains('jog')) return 'run';
  if (t.contains('bik') || t.contains('cycl')) return 'cycle';
  if (t.contains('swim')) return 'swim';
  if (t.contains('strength') ||
      t.contains('weight') ||
      t.contains('calisthenics')) {
    return 'strength';
  }
  if (t.contains('yoga') || t.contains('pilates')) return 'yoga';
  if (t.contains('interval') || t.contains('hiit')) return 'hiit';
  if (t.contains('hik')) return 'hike';
  if (t.contains('danc')) return 'dance';
  if (t.contains('climb')) return 'climb';
  if (t.contains('row')) return 'row';
  if (t.contains('stretch') || t.contains('flexibility')) return 'stretch';
  if (const [
    'ball',
    'tennis',
    'soccer',
    'football',
    'hockey',
    'golf',
    'rugby',
    'cricket',
    'badminton',
    'volley',
    'squash',
    'boxing',
    'martial',
    'skat',
    'ski',
    'surf',
  ].any(t.contains)) {
    return 'sports';
  }
  return 'other';
}

/// A workout read from a health platform.
class ImportedWorkout {
  const ImportedWorkout({
    required this.sourceId,
    required this.source,
    required this.activity,
    required this.start,
    required this.end,
    this.distanceKm,
    this.calories,
    this.heartRate,
    this.rawType,
  });
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
(List<ImportedWorkout> fresh, int duplicates) dedupeWorkouts(
  List<TrackerRecord> existing,
  List<ImportedWorkout> incoming,
) {
  final ids = {for (final r in existing) ?r.str('sourceId')};
  final kept = <ImportedWorkout>[];
  var dups = 0;
  bool overlaps(DateTime s1, int m1, DateTime s2, int m2) =>
      s1.difference(s2).inMinutes.abs() <= 3 && (m1 - m2).abs() <= 3;
  for (final w in incoming) {
    if (ids.contains(w.sourceId)) {
      dups++;
      continue;
    }
    final clash =
        existing.any(
          (r) =>
              r.str(FitField.activity) == w.activity &&
              r.occurredAt != null &&
              overlaps(
                r.occurredAt!,
                r.integer(FitField.minutes) ?? 0,
                w.start,
                w.minutes,
              ),
        ) ||
        kept.any(
          (k) =>
              k.activity == w.activity &&
              overlaps(k.start, k.minutes, w.start, w.minutes),
        );
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
    'distanceKm': distanceKm == null
        ? null
        : double.parse(distanceKm!.toStringAsFixed(2)),
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
  Future<String>
  availability(); // available, notInstalled, updateRequired, unsupported
  Future<void> install();
  Future<bool> request(List<HealthDataType> types);
  Future<bool?> has(List<HealthDataType> types);
  Future<void> revoke();
  Future<List<HealthDataPoint>> read(
    List<HealthDataType> types,
    DateTime from,
    DateTime to,
  );
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
      HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired =>
        'updateRequired',
      _ => 'notInstalled',
    };
  }

  @override
  Future<void> install() async {
    await _cfg();
    await _h.installHealthConnect();
  }

  Future<bool> allowHistory() async {
    await _cfg();
    if (ios) return true;
    return await _h.isHealthDataHistoryAvailable() &&
        (await _h.isHealthDataHistoryAuthorized() ||
            await _h.requestHealthDataHistoryAuthorization());
  }

  @override
  Future<bool> request(List<HealthDataType> types) async {
    await _cfg();
    if (!ios &&
        types.any(
          (t) => t == HealthDataType.STEPS || t == HealthDataType.WORKOUT,
        )) {
      await Permission.activityRecognition.request();
    }
    return _h.requestAuthorization(
      types,
      permissions: [for (final _ in types) HealthDataAccess.READ],
    );
  }

  @override
  Future<bool?> has(List<HealthDataType> types) async {
    await _cfg();
    return _h.hasPermissions(
      types,
      permissions: [for (final _ in types) HealthDataAccess.READ],
    );
  }

  @override
  Future<void> revoke() async {
    await _cfg();
    if (!ios) await _h.revokePermissions();
  }

  @override
  Future<List<HealthDataPoint>> read(
    List<HealthDataType> types,
    DateTime from,
    DateTime to,
  ) async {
    await _cfg();
    final pts = await _h.getHealthDataFromTypes(
      types: types,
      startTime: from,
      endTime: to,
    );
    return _h.removeDuplicates(pts);
  }

  @override
  Future<int?> steps(DateTime from, DateTime to) async {
    await _cfg();
    return _h.getTotalStepsInInterval(from, to);
  }
}

final healthGatewayProvider = Provider<HealthGateway>(
  (ref) => PluginHealthGateway(),
);

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
    if (raw is! List) {
      return {
        HealthCategory.workouts,
        HealthCategory.steps,
        HealthCategory.distance,
        HealthCategory.calories,
        HealthCategory.activeMinutes,
      };
    }
    return {
      for (final c in HealthCategory.values)
        if (raw.contains(c.name)) c,
    };
  }

  DateTime? get lastAttempt => DateTime.tryParse('${f['lastAttempt'] ?? ''}');
  String get status =>
      f['status'] as String? ?? (connected ? 'connected' : 'permission needed');
  Map<String, dynamic> get results =>
      (f['results'] as Map?)?.cast<String, dynamic>() ?? {};
  DateTime? get lastSync => DateTime.tryParse('${f['lastSync'] ?? ''}');
  String? get lastError => f['lastError'] as String?;
  int get imported => (f['imported'] as num?)?.toInt() ?? 0;
  int get duplicates => (f['duplicates'] as num?)?.toInt() ?? 0;
  List<String> get sourcesSeen => [
    for (final s in (f['sources'] as List?) ?? const []) '$s',
  ];
}

// Connection consent belongs to this installation, not the encrypted synced
// settings record. Another device must connect and authorize independently.
final healthLocalConnectionProvider = FutureProvider<bool>((ref) async {
  final g = ref.watch(healthGatewayProvider);
  if (g is! PluginHealthGateway || !g.supported) return false;
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(
        'prism.health.connected.${g.ios ? 'healthkit' : 'healthconnect'}',
      ) ??
      false;
});

final healthSettingsProvider = Provider<HealthSettings>((ref) {
  final rows =
      ref.watch(trackerKindProvider(TrackerKind.fitnessSource)).value ??
      const <TrackerRecord>[];
  final settings = HealthSettings(
    rows.isEmpty
        ? null
        : (rows.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt)))
              .first,
  );
  if (ref.watch(healthGatewayProvider) is PluginHealthGateway &&
      ref.watch(healthLocalConnectionProvider).value != true) {
    return HealthSettings(
      settings.r?.withFields({
        'connected': false,
        'status': 'permission needed',
      }),
    );
  }
  return settings;
});

/// Result of one sync.
class HealthSyncResult {
  const HealthSyncResult({
    this.workouts = 0,
    this.duplicates = 0,
    this.days = 0,
    this.error,
  });
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
  int _generation = 0;

  String get platform => _g.ios ? 'healthkit' : 'healthconnect';

  Future<HealthSettings> _settings() async {
    final all = await ref.read(trackerRecordRepositoryProvider).getAll();
    final rows = all.where((r) => r.kind == TrackerKind.fitnessSource).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final settings = HealthSettings(rows.firstOrNull);
    if (_g is PluginHealthGateway &&
        !(await ref.read(healthLocalConnectionProvider.future))) {
      return HealthSettings(
        settings.r?.withFields({
          'connected': false,
          'status': 'permission needed',
        }),
      );
    }
    return settings;
  }

  Future<void> saveSettings(Map<String, Object?> changes) async {
    final s = (await _settings()).r;
    if (s == null) {
      await _t.create(
        kind: TrackerKind.fitnessSource,
        title: 'health',
        isPrivate: true,
        fields: changes,
      );
    } else {
      await _t.save(s.withFields(changes));
    }
  }

  List<HealthDataType> typesFor(Set<HealthCategory> cats) =>
      {for (final c in cats) ...healthTypesFor(c, ios: _g.ios)}.toList();

  Future<bool> connect(Set<HealthCategory> cats) async {
    if (!_g.supported ||
        cats.isEmpty ||
        await _g.availability() != 'available') {
      await saveSettings({
        'connected': false,
        'status': 'provider unavailable',
      });
      return false;
    }
    final requested = await _g.request(typesFor(cats));
    final granted = <String>[];
    for (final c in cats) {
      final has = await _g.has(healthTypesFor(c, ios: _g.ios));
      // HealthKit intentionally does not disclose read denial. A successful
      // request permits querying, not a claim that every type was authorized.
      if (has == true || (_g.ios && requested && has == null)) {
        granted.add(c.name);
      }
    }
    final ok = granted.isNotEmpty;
    if (_g is PluginHealthGateway) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('prism.health.connected.$platform', ok);
      ref.invalidate(healthLocalConnectionProvider);
    }
    await saveSettings({
      'connected': ok,
      'categories': [for (final c in cats) c.name],
      'granted': granted,
      'status': !ok
          ? 'permission needed'
          : granted.length < cats.length
          ? 'partially authorized'
          : 'connected',
      'lastError': ok ? null : 'denied',
    });
    return ok;
  }

  Future<void> disconnect() async {
    _generation++;
    if (_g is PluginHealthGateway) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('prism.health.connected.$platform', false);
      ref.invalidate(healthLocalConnectionProvider);
    }
    // Mark disconnected before revocation so a failed revoke cannot keep the
    // automatic importer running. Imported records remain explicitly retained.
    await saveSettings({'connected': false, 'status': 'disconnected'});
    try {
      await _g.revoke();
    } catch (_) {
      await saveSettings({
        'lastError':
            'Could not revoke access. Manage permissions in the health app.',
      });
    }
  }

  Future<HealthSyncResult> sync({DateTime? now, DateTime? from}) async {
    if (_running) {
      return const HealthSyncResult(error: 'A sync is already running.');
    }
    _running = true;
    final generation = _generation;
    try {
      final s = await _settings();
      if (!s.connected) {
        return const HealthSyncResult(error: 'Connect a provider first.');
      }
      if (!_g.supported || await _g.availability() != 'available') {
        await saveSettings({'status': 'provider unavailable'});
        return const HealthSyncResult(
          error: 'Health provider unavailable on this device.',
        );
      }
      if (!isFeatureOn(ref, 'healthIntegration') ||
          !isFeatureOn(ref, 'fitness')) {
        return const HealthSyncResult(
          error: 'Enable Fitness and health integrations first.',
        );
      }
      final end = now ?? DateTime.now();
      if (from != null && !from.isBefore(end)) {
        return const HealthSyncResult(error: 'Choose a start before the end.');
      }
      if (from != null &&
          from.isBefore(end.subtract(const Duration(days: 30)))) {
        final gateway = _g;
        if (gateway is PluginHealthGateway && !await gateway.allowHistory()) {
          return const HealthSyncResult(
            error:
                'Historical read permission is unavailable or denied. Choose the last 30 days, or manage Health Connect history access.',
          );
        }
      }
      await saveSettings({
        'lastAttempt': end.toUtc().toIso8601String(),
        'status': 'syncing',
      });
      final progress = Map<String, dynamic>.from(
        (s.f['progress'] as Map?) ?? {},
      );
      final results = <String, Object?>{};
      final failures = <String>[];
      final denied = <String>[];
      final sources = {...s.sourcesSeen};
      var newWorkouts = 0,
          duplicates = 0,
          savedDays = 0,
          successes = 0,
          recordsRead = 0;
      final repo = ref.read(trackerRecordRepositoryProvider);
      for (final category in s.categories) {
        if (generation != _generation) {
          return const HealthSyncResult(
            error: 'Disconnected. Existing imports were retained.',
          );
        }
        final key = '$platform:${category.name}';
        final previous = DateTime.tryParse('${progress[key] ?? ''}');
        final start = _day(
          (from ??
                  previous?.subtract(const Duration(days: 1)) ??
                  end.subtract(const Duration(days: 30)))
              .toLocal(),
        );
        try {
          final permission = await _g.has(
            healthTypesFor(category, ios: _g.ios),
          );
          if (permission == false && !_g.ios) {
            denied.add(category.name);
            results[category.name] = {'state': 'permission needed'};
            continue;
          }
          final days = <DateTime, DailyHealth>{};
          DailyHealth dayOf(DateTime t) => days.putIfAbsent(
            _day(t.toLocal()),
            () => DailyHealth(_day(t.toLocal())),
          );
          var read = 0, added = 0, updated = 0;
          if (category == HealthCategory.steps) {
            for (
              var day = _day(start);
              !day.isAfter(end);
              day = DateTime(day.year, day.month, day.day + 1)
            ) {
              final next = DateTime(day.year, day.month, day.day + 1);
              final n = await _g.steps(day, next.isAfter(end) ? end : next);
              if (generation != _generation) {
                return const HealthSyncResult(
                  error: 'Disconnected. Existing imports were retained.',
                );
              }
              if (n == null) throw StateError('Step query returned no result');
              dayOf(day).steps = n;
              if (n > 0) read++;
            }
          } else {
            final points = await _g.read(
              healthTypesFor(category, ios: _g.ios),
              start,
              end,
            );
            if (generation != _generation) {
              return const HealthSyncResult(
                error: 'Disconnected. Existing imports were retained.',
              );
            }
            read = points.length;
            if (category == HealthCategory.workouts) {
              // Read persistent state, not the asynchronous widget cache. UUIDs
              // are scoped by platform and originating app to avoid collisions.
              final existing = (await repo.getAll())
                  .where((r) => r.kind == TrackerKind.fitnessWorkout)
                  .toList();
              for (final p in points) {
                if (generation != _generation) {
                  return const HealthSyncResult(
                    error: 'Disconnected. Existing imports were retained.',
                  );
                }
                final v = p.value;
                if (v is! WorkoutHealthValue) continue;
                sources.add(p.sourceName);
                final sourceKey = '$platform:${p.sourceId}:${p.uuid}';
                final old = existing
                    .where(
                      (r) =>
                          r.str('sourceKey') == sourceKey ||
                          (r.str('platform') == platform &&
                              r.str('sourceId') == p.uuid &&
                              r.str('source') == p.sourceName),
                    )
                    .firstOrNull;
                final fields = <String, Object?>{
                  FitField.activity: mapWorkoutActivity(
                    v.workoutActivityType.name,
                  ),
                  FitField.minutes: p.dateTo.difference(p.dateFrom).inMinutes,
                  FitField.distanceKm: v.totalDistance == null
                      ? null
                      : v.totalDistance! *
                            (v.totalDistanceUnit == HealthDataUnit.MILE
                                ? 1.609344
                                : .001),
                  FitField.calories: v.totalEnergyBurned == null
                      ? null
                      : (v.totalEnergyBurned! *
                                (v.totalEnergyBurnedUnit == HealthDataUnit.JOULE
                                    ? 1 / 4184
                                    : 1))
                            .round(),
                  'source': p.sourceName,
                  'sourceId': p.uuid,
                  'sourceKey': sourceKey,
                  'sourceApp': p.sourceId,
                  'sourceType': v.workoutActivityType.name,
                  'platform': platform,
                  'imported': true,
                  'sourceStart': p.dateFrom.toUtc().toIso8601String(),
                  'sourceEnd': p.dateTo.toUtc().toIso8601String(),
                  'utcOffsetMinutes': p.dateFrom
                      .toLocal()
                      .timeZoneOffset
                      .inMinutes,
                };
                if (old != null) {
                  final snapshot = (old.fields['importSnapshot'] as Map?) ?? {};
                  final merged = Map<String, Object?>.from(fields);
                  // Preserve a manual correction to an imported field. The
                  // provider snapshot still advances for later comparisons.
                  for (final k in [
                    FitField.activity,
                    FitField.minutes,
                    FitField.distanceKm,
                    FitField.calories,
                  ]) {
                    if (snapshot.containsKey(k) &&
                        old.fields[k] != snapshot[k]) {
                      merged[k] = old.fields[k];
                    }
                  }
                  await _t.save(
                    old
                        .withFields({...merged, 'importSnapshot': fields})
                        .copyWith(
                          occurredAt:
                              snapshot['sourceStart'] == null ||
                                  old.occurredAt?.toUtc().toIso8601String() ==
                                      snapshot['sourceStart']
                              ? p.dateFrom.toLocal()
                              : old.occurredAt,
                          endedAt:
                              snapshot['sourceEnd'] == null ||
                                  old.endedAt?.toUtc().toIso8601String() ==
                                      snapshot['sourceEnd']
                              ? p.dateTo.toLocal()
                              : old.endedAt,
                        ),
                  );
                  duplicates++;
                  updated++;
                  continue;
                }
                final activity = fields[FitField.activity];
                final overlap = existing.any(
                  (r) =>
                      r.flag('imported') &&
                      r.str('source') != p.sourceName &&
                      r.str(FitField.activity) == activity &&
                      r.occurredAt != null &&
                      r.occurredAt!.difference(p.dateFrom).inSeconds.abs() <=
                          180 &&
                      ((r.integer(FitField.minutes) ?? 0) -
                                  p.dateTo.difference(p.dateFrom).inMinutes)
                              .abs() <=
                          3,
                );
                if (overlap) {
                  duplicates++;
                  continue;
                }
                final t = DateTime.now();
                final record = TrackerRecord(
                  id: const Uuid().v5(
                    Namespace.url.value,
                    'prism:fitness:$sourceKey',
                  ),
                  kind: TrackerKind.fitnessWorkout,
                  occurredAt: p.dateFrom.toLocal(),
                  endedAt: p.dateTo.toLocal(),
                  memberId: s.defaultAlter,
                  createdAt: t,
                  modifiedAt: t,
                  isPrivate: true,
                ).withFields({...fields, 'importSnapshot': fields});
                await repo.create(record);
                existing.add(record);
                newWorkouts++;
                added++;
              }
            } else {
              // Choose one originating app per day/type (greatest coverage;
              // ties use source id). Never add mirrored apps' daily totals.
              final bySource = <DateTime, Map<String, List<HealthDataPoint>>>{};
              for (final p in points) {
                sources.add(p.sourceName);
                final day = _day(
                  (category == HealthCategory.sleep ? p.dateTo : p.dateFrom)
                      .toLocal(),
                );
                ((bySource[day] ??= {})[p.sourceId] ??= []).add(p);
              }
              for (final entry in bySource.entries) {
                num value(List<HealthDataPoint> pts) => pts.fold<num>(0, (
                  total,
                  p,
                ) {
                  if (category == HealthCategory.sleep ||
                      (category == HealthCategory.activeMinutes && !_g.ios)) {
                    return total + p.dateTo.difference(p.dateFrom).inMinutes;
                  }
                  final v = p.value;
                  if (v is! NumericHealthValue) return total;
                  final n = v.numericValue;
                  if (category == HealthCategory.distance) {
                    return total +
                        n * (p.unit == HealthDataUnit.MILE ? 1.609344 : .001);
                  }
                  if (category == HealthCategory.calories) {
                    return total +
                        n * (p.unit == HealthDataUnit.JOULE ? 1 / 4184 : 1);
                  }
                  return total + n;
                });
                final candidates = entry.value.entries.toList()
                  ..sort((a, b) {
                    final c = (category == HealthCategory.heartRate
                        ? b.value.length.compareTo(a.value.length)
                        : value(b.value).compareTo(value(a.value)));
                    return c != 0 ? c : a.key.compareTo(b.key);
                  });
                final selected = candidates.first.value;
                final v = value(selected);
                final d = dayOf(entry.key);
                d.sources.addAll(selected.map((p) => p.sourceName));
                switch (category) {
                  case HealthCategory.distance:
                    d.distanceKm = v.toDouble();
                  case HealthCategory.calories:
                    d.calories = v.round();
                  case HealthCategory.heartRate:
                    d.heartRateAvg = (v / selected.length).round();
                  case HealthCategory.activeMinutes:
                    d.activeMinutes = v.round();
                  case HealthCategory.sleep:
                    d.sleepMinutes = v.round();
                  default:
                    break;
                }
              }
            }
          }
          final existingDaily = (await repo.getAll())
              .where((r) => r.kind == TrackerKind.fitnessDaily)
              .toList();
          for (final d in days.values) {
            if (generation != _generation) {
              return const HealthSyncResult(
                error: 'Disconnected. Existing imports were retained.',
              );
            }
            final old = existingDaily
                .where(
                  (r) =>
                      r.occurredAt != null &&
                      _day(r.occurredAt!.toLocal()) == d.day &&
                      (r.str('platform') == platform ||
                          r.str('platform') == null),
                )
                .firstOrNull;
            final fields = {
              for (final e in d.toFields().entries)
                if (e.value != null && e.key != 'sources') e.key: e.value,
              'sources': {
                ...old?.strings('sources') ?? [],
                ...d.sources,
              }.toList(),
              'platform': platform,
              'imported': true,
              'sourcePolicy':
                  'One originating app per day and data type; steps use the platform aggregate.',
              'utcOffsetMinutes': d.day.timeZoneOffset.inMinutes,
            };
            if (old != null) {
              await _t.save(old.withFields(fields));
              updated++;
            } else {
              final t = DateTime.now();
              await repo.create(
                TrackerRecord(
                  id: const Uuid().v5(
                    Namespace.url.value,
                    'prism:fitness:$platform:${d.day.toIso8601String()}',
                  ),
                  kind: TrackerKind.fitnessDaily,
                  occurredAt: d.day,
                  memberId: s.defaultAlter,
                  isPrivate: true,
                  createdAt: t,
                  modifiedAt: t,
                ).withFields(fields),
              );
              added++;
            }
            savedDays++;
          }
          // Advance this type only after every write for its window succeeds.
          progress[key] = end.toUtc().toIso8601String();
          await saveSettings({'progress': progress});
          successes++;
          recordsRead += read;
          results[category.name] = {
            'state': read == 0
                ? (_g.ios
                      ? 'zero records (HealthKit does not disclose denied read access)'
                      : 'authorized with zero records')
                : 'imported successfully',
            'read': read,
            'new': added,
            'updated': updated,
          };
        } catch (_) {
          // Provider exceptions can include private record content. Persist only
          // a neutral state; preserve progress so the failed window is retried.
          failures.add(category.name);
          results[category.name] = {'state': 'failed; retry available'};
        }
      }
      final error = failures.isEmpty
          ? null
          : 'Some data types failed. Successful imports were saved; retry the remaining types.';
      final state = successes == 0
          ? (denied.isNotEmpty ? 'permission needed' : 'failed')
          : failures.isNotEmpty
          ? 'partially imported'
          : denied.isNotEmpty
          ? 'partially authorized'
          : recordsRead == 0
          ? (_g.ios
                ? 'zero records (read access not disclosed)'
                : 'authorized with zero records')
          : 'imported successfully';
      await saveSettings({
        'status': state,
        'results': results,
        'lastError': error,
        if (failures.isEmpty && denied.isEmpty)
          'lastSync': end.toUtc().toIso8601String(),
        if (successes > 0)
          'lastSuccessfulImport': end.toUtc().toIso8601String(),
        'imported': s.imported + newWorkouts,
        'duplicates': s.duplicates + duplicates,
        'sources': sources.toList(),
      });
      return HealthSyncResult(
        workouts: newWorkouts,
        duplicates: duplicates,
        days: savedDays,
        error:
            error ??
            (successes == 0
                ? 'Permission needed. Manage permissions and try again.'
                : null),
      );
    } catch (_) {
      await saveSettings({
        'status': 'failed',
        'lastError':
            'Sync failed. Check provider availability and permissions, then retry.',
      });
      return const HealthSyncResult(
        error:
            'Sync failed. Check provider availability and permissions, then retry.',
      );
    } finally {
      _running = false;
    }
  }

  /// Removes everything imported from health apps (manual entries stay).
  Future<int> removeImported() async {
    final all = await ref.read(trackerRecordRepositoryProvider).getAll();
    var n = 0;
    for (final r in all) {
      if (r.str('platform') == platform &&
          ((r.kind == TrackerKind.fitnessWorkout && r.flag('imported')) ||
              r.kind == TrackerKind.fitnessDaily)) {
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
