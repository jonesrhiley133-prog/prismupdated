// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cycle_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CycleEntry _$CycleEntryFromJson(Map<String, dynamic> json) => _CycleEntry(
  id: json['id'] as String,
  date: json['date'] as String,
  flow: (json['flow'] as num?)?.toInt() ?? 0,
  symptoms:
      (json['symptoms'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  note: json['note'] as String?,
  memberId: json['memberId'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  modifiedAt: DateTime.parse(json['modifiedAt'] as String),
);

Map<String, dynamic> _$CycleEntryToJson(_CycleEntry instance) =>
    <String, dynamic>{
      'id': instance.id,
      'date': instance.date,
      'flow': instance.flow,
      'symptoms': instance.symptoms,
      'note': instance.note,
      'memberId': instance.memberId,
      'createdAt': instance.createdAt.toIso8601String(),
      'modifiedAt': instance.modifiedAt.toIso8601String(),
    };
