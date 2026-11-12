import 'package:freezed_annotation/freezed_annotation.dart';

part 'location.freezed.dart';
part 'location.g.dart';

@freezed
abstract class SavedLocation with _$SavedLocation {
  const factory SavedLocation({
    required String id,
    required String name,
    String? emoji,
    String? colorHex,
    String? address,
    String? notes,
    @Default(false) bool isFavorite,
    @Default(0) int sortOrder,
    required DateTime createdAt,
    required DateTime modifiedAt,
  }) = _SavedLocation;

  factory SavedLocation.fromJson(Map<String, dynamic> json) =>
      _$SavedLocationFromJson(json);
}

/// Time spent at a location. Exact to the second.
@freezed
abstract class LocationSession with _$LocationSession {
  const LocationSession._();

  const factory LocationSession({
    required String id,
    required String locationId,
    required DateTime startedAt,
    DateTime? endedAt,
    String? note,
    required DateTime createdAt,
    required DateTime modifiedAt,
  }) = _LocationSession;

  factory LocationSession.fromJson(Map<String, dynamic> json) =>
      _$LocationSessionFromJson(json);

  bool get isActive => endedAt == null;

  /// Exact elapsed time; open sessions measure up to [now].
  Duration durationAt(DateTime now) {
    final d = (endedAt ?? now).difference(startedAt);
    return d.isNegative ? Duration.zero : d;
  }
}
