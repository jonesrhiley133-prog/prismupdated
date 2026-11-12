import 'package:freezed_annotation/freezed_annotation.dart';

part 'work.freezed.dart';
part 'work.g.dart';

@freezed
abstract class Job with _$Job {
  const factory Job({
    required String id,
    required String name,

    /// Hourly wage in minor units (e.g. cents).
    @Default(0) int hourlyRateCents,
    @Default('USD') String currencyCode,
    String? colorHex,
    String? notes,
    @Default(false) bool isArchived,
    required DateTime createdAt,
    required DateTime modifiedAt,
  }) = _Job;

  factory Job.fromJson(Map<String, dynamic> json) => _$JobFromJson(json);
}

/// One clock-in. Exact to the second.
@freezed
abstract class WorkSession with _$WorkSession {
  const WorkSession._();

  const factory WorkSession({
    required String id,
    required String jobId,
    required DateTime startedAt,
    DateTime? endedAt,

    /// Rate snapshot taken at clock-in, in minor units per hour.
    @Default(0) int hourlyRateCents,
    @Default('USD') String currencyCode,

    /// Unpaid break time, in seconds.
    @Default(0) int breakSeconds,
    String? memberId,
    String? note,
    required DateTime createdAt,
    required DateTime modifiedAt,
  }) = _WorkSession;

  factory WorkSession.fromJson(Map<String, dynamic> json) =>
      _$WorkSessionFromJson(json);

  bool get isActive => endedAt == null;

  /// Exact paid time (elapsed minus breaks), never negative.
  Duration workedAt(DateTime now) {
    final elapsed = (endedAt ?? now).difference(startedAt).inSeconds;
    final worked = elapsed - breakSeconds;
    return Duration(seconds: worked < 0 ? 0 : worked);
  }

  /// Estimated earnings in minor units, from the exact worked seconds.
  /// Rounded half-up to the nearest minor unit only at the end.
  int estimatedEarningsCentsAt(DateTime now) =>
      estimateEarningsCents(workedAt(now).inSeconds, hourlyRateCents);
}

/// Earnings (minor units) for [seconds] at [hourlyRateCents]/hour, computed
/// with integer maths so no precision is lost before the final rounding.
int estimateEarningsCents(int seconds, int hourlyRateCents) {
  if (seconds <= 0 || hourlyRateCents <= 0) return 0;
  return (seconds * hourlyRateCents + 1800) ~/ 3600;
}
