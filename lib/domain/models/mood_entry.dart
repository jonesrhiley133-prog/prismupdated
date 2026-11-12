import 'package:freezed_annotation/freezed_annotation.dart';

part 'mood_entry.freezed.dart';
part 'mood_entry.g.dart';

/// A single mood and wellbeing check-in.
@freezed
abstract class MoodEntry with _$MoodEntry {
  const MoodEntry._();

  static const minMood = 1;
  static const maxMood = 5;
  static const minIntensity = 1;
  static const maxIntensity = 10;
  static const minScale = 1;
  static const maxScale = 5;

  const factory MoodEntry({
    required String id,

    /// Member who logged the check-in, or null for the whole system.
    String? memberId,

    /// Valence on a 1–5 scale (1 = very low, 5 = great).
    @Default(3) int mood,

    /// How strongly the mood is felt, 1–10.
    @Default(5) int intensity,

    /// Emotion keys from the emotion library (or free-form labels).
    @Default(<String>[]) List<String> emotions,

    /// Optional 1–5 energy level.
    int? energy,

    /// Optional 1–5 stress level.
    int? stress,

    /// Optional 1–5 sleep quality for the previous night.
    int? sleepQuality,

    /// Body regions where a sensation was noticed (keys from the body map).
    @Default(<String>[]) List<String> bodySensations,
    String? note,
    required DateTime recordedAt,
    required DateTime createdAt,
    required DateTime modifiedAt,
  }) = _MoodEntry;

  factory MoodEntry.fromJson(Map<String, dynamic> json) =>
      _$MoodEntryFromJson(json);
}
