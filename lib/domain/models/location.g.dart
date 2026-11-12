// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'location.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SavedLocation _$SavedLocationFromJson(Map<String, dynamic> json) =>
    _SavedLocation(
      id: json['id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String?,
      colorHex: json['colorHex'] as String?,
      address: json['address'] as String?,
      notes: json['notes'] as String?,
      isFavorite: json['isFavorite'] as bool? ?? false,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      modifiedAt: DateTime.parse(json['modifiedAt'] as String),
    );

Map<String, dynamic> _$SavedLocationToJson(_SavedLocation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'emoji': instance.emoji,
      'colorHex': instance.colorHex,
      'address': instance.address,
      'notes': instance.notes,
      'isFavorite': instance.isFavorite,
      'sortOrder': instance.sortOrder,
      'createdAt': instance.createdAt.toIso8601String(),
      'modifiedAt': instance.modifiedAt.toIso8601String(),
    };

_LocationSession _$LocationSessionFromJson(Map<String, dynamic> json) =>
    _LocationSession(
      id: json['id'] as String,
      locationId: json['locationId'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      endedAt: json['endedAt'] == null
          ? null
          : DateTime.parse(json['endedAt'] as String),
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      modifiedAt: DateTime.parse(json['modifiedAt'] as String),
    );

Map<String, dynamic> _$LocationSessionToJson(_LocationSession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'locationId': instance.locationId,
      'startedAt': instance.startedAt.toIso8601String(),
      'endedAt': instance.endedAt?.toIso8601String(),
      'note': instance.note,
      'createdAt': instance.createdAt.toIso8601String(),
      'modifiedAt': instance.modifiedAt.toIso8601String(),
    };
