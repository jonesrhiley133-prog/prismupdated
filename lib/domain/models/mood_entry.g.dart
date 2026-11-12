// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mood_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MoodEntry _$MoodEntryFromJson(Map<String, dynamic> json) => _MoodEntry(
  id: json['id'] as String,
  memberId: json['memberId'] as String?,
  mood: (json['mood'] as num?)?.toInt() ?? 3,
  intensity: (json['intensity'] as num?)?.toInt() ?? 5,
  emotions:
      (json['emotions'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  energy: (json['energy'] as num?)?.toInt(),
  stress: (json['stress'] as num?)?.toInt(),
  sleepQuality: (json['sleepQuality'] as num?)?.toInt(),
  bodySensations:
      (json['bodySensations'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  note: json['note'] as String?,
  recordedAt: DateTime.parse(json['recordedAt'] as String),
  createdAt: DateTime.parse(json['createdAt'] as String),
  modifiedAt: DateTime.parse(json['modifiedAt'] as String),
);

Map<String, dynamic> _$MoodEntryToJson(_MoodEntry instance) =>
    <String, dynamic>{
      'id': instance.id,
      'memberId': instance.memberId,
      'mood': instance.mood,
      'intensity': instance.intensity,
      'emotions': instance.emotions,
      'energy': instance.energy,
      'stress': instance.stress,
      'sleepQuality': instance.sleepQuality,
      'bodySensations': instance.bodySensations,
      'note': instance.note,
      'recordedAt': instance.recordedAt.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
      'modifiedAt': instance.modifiedAt.toIso8601String(),
    };
