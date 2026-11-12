// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tracker_record.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TrackerRecord _$TrackerRecordFromJson(Map<String, dynamic> json) =>
    _TrackerRecord(
      id: json['id'] as String,
      kind: json['kind'] as String,
      parentId: json['parentId'] as String?,
      title: json['title'] as String? ?? '',
      body: json['body'] as String?,
      data: json['data'] as String?,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const <String>[],
      occurredAt: json['occurredAt'] == null
          ? null
          : DateTime.parse(json['occurredAt'] as String),
      endedAt: json['endedAt'] == null
          ? null
          : DateTime.parse(json['endedAt'] as String),
      amount: (json['amount'] as num?)?.toInt(),
      memberId: json['memberId'] as String?,
      isPrivate: json['isPrivate'] as bool? ?? false,
      isPinned: json['isPinned'] as bool? ?? false,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      modifiedAt: DateTime.parse(json['modifiedAt'] as String),
    );

Map<String, dynamic> _$TrackerRecordToJson(_TrackerRecord instance) =>
    <String, dynamic>{
      'id': instance.id,
      'kind': instance.kind,
      'parentId': instance.parentId,
      'title': instance.title,
      'body': instance.body,
      'data': instance.data,
      'tags': instance.tags,
      'occurredAt': instance.occurredAt?.toIso8601String(),
      'endedAt': instance.endedAt?.toIso8601String(),
      'amount': instance.amount,
      'memberId': instance.memberId,
      'isPrivate': instance.isPrivate,
      'isPinned': instance.isPinned,
      'sortOrder': instance.sortOrder,
      'createdAt': instance.createdAt.toIso8601String(),
      'modifiedAt': instance.modifiedAt.toIso8601String(),
    };
