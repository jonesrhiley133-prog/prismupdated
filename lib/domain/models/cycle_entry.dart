import 'package:freezed_annotation/freezed_annotation.dart';

part 'cycle_entry.freezed.dart';
part 'cycle_entry.g.dart';

/// One day of cycle tracking.
@freezed
abstract class CycleEntry with _$CycleEntry {
  const CycleEntry._();

  static const flowNone = 0;
  static const flowSpotting = 1;
  static const flowHeavy = 4;

  const factory CycleEntry({
    required String id,

    /// `yyyy-MM-dd`.
    required String date,
    @Default(0) int flow,
    @Default(<String>[]) List<String> symptoms,
    String? note,
    String? memberId,
    required DateTime createdAt,
    required DateTime modifiedAt,
  }) = _CycleEntry;

  factory CycleEntry.fromJson(Map<String, dynamic> json) =>
      _$CycleEntryFromJson(json);

  /// Bleeding that counts toward a period (spotting does not).
  bool get isPeriodDay => flow >= 2;

  DateTime get day {
    final p = date.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }
}
