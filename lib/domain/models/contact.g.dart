// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contact.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Contact _$ContactFromJson(Map<String, dynamic> json) => _Contact(
  id: json['id'] as String,
  displayName: json['displayName'] as String,
  phones:
      (json['phones'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  emails:
      (json['emails'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  birthday: json['birthday'] as String?,
  notes: json['notes'] as String?,
  source: json['source'] as String? ?? ContactSource.manual,
  externalId: json['externalId'] as String?,
  isFavorite: json['isFavorite'] as bool? ?? false,
  createdAt: DateTime.parse(json['createdAt'] as String),
  modifiedAt: DateTime.parse(json['modifiedAt'] as String),
);

Map<String, dynamic> _$ContactToJson(_Contact instance) => <String, dynamic>{
  'id': instance.id,
  'displayName': instance.displayName,
  'phones': instance.phones,
  'emails': instance.emails,
  'birthday': instance.birthday,
  'notes': instance.notes,
  'source': instance.source,
  'externalId': instance.externalId,
  'isFavorite': instance.isFavorite,
  'createdAt': instance.createdAt.toIso8601String(),
  'modifiedAt': instance.modifiedAt.toIso8601String(),
};
