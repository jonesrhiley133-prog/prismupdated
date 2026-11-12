// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'work.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Job _$JobFromJson(Map<String, dynamic> json) => _Job(
  id: json['id'] as String,
  name: json['name'] as String,
  hourlyRateCents: (json['hourlyRateCents'] as num?)?.toInt() ?? 0,
  currencyCode: json['currencyCode'] as String? ?? 'USD',
  colorHex: json['colorHex'] as String?,
  notes: json['notes'] as String?,
  isArchived: json['isArchived'] as bool? ?? false,
  createdAt: DateTime.parse(json['createdAt'] as String),
  modifiedAt: DateTime.parse(json['modifiedAt'] as String),
);

Map<String, dynamic> _$JobToJson(_Job instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'hourlyRateCents': instance.hourlyRateCents,
  'currencyCode': instance.currencyCode,
  'colorHex': instance.colorHex,
  'notes': instance.notes,
  'isArchived': instance.isArchived,
  'createdAt': instance.createdAt.toIso8601String(),
  'modifiedAt': instance.modifiedAt.toIso8601String(),
};

_WorkSession _$WorkSessionFromJson(Map<String, dynamic> json) => _WorkSession(
  id: json['id'] as String,
  jobId: json['jobId'] as String,
  startedAt: DateTime.parse(json['startedAt'] as String),
  endedAt: json['endedAt'] == null
      ? null
      : DateTime.parse(json['endedAt'] as String),
  hourlyRateCents: (json['hourlyRateCents'] as num?)?.toInt() ?? 0,
  currencyCode: json['currencyCode'] as String? ?? 'USD',
  breakSeconds: (json['breakSeconds'] as num?)?.toInt() ?? 0,
  memberId: json['memberId'] as String?,
  note: json['note'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  modifiedAt: DateTime.parse(json['modifiedAt'] as String),
);

Map<String, dynamic> _$WorkSessionToJson(_WorkSession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'jobId': instance.jobId,
      'startedAt': instance.startedAt.toIso8601String(),
      'endedAt': instance.endedAt?.toIso8601String(),
      'hourlyRateCents': instance.hourlyRateCents,
      'currencyCode': instance.currencyCode,
      'breakSeconds': instance.breakSeconds,
      'memberId': instance.memberId,
      'note': instance.note,
      'createdAt': instance.createdAt.toIso8601String(),
      'modifiedAt': instance.modifiedAt.toIso8601String(),
    };
