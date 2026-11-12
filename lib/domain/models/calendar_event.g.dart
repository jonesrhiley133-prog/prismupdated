// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CalendarEvent _$CalendarEventFromJson(
  Map<String, dynamic> json,
) => _CalendarEvent(
  id: json['id'] as String,
  title: json['title'] as String,
  description: json['description'] as String?,
  location: json['location'] as String?,
  startAt: DateTime.parse(json['startAt'] as String),
  endAt: DateTime.parse(json['endAt'] as String),
  isAllDay: json['isAllDay'] as bool? ?? false,
  colorHex: json['colorHex'] as String?,
  category: json['category'] as String?,
  recurrence:
      $enumDecodeNullable(_$CalendarRecurrenceEnumMap, json['recurrence']) ??
      CalendarRecurrence.none,
  recurrenceInterval: (json['recurrenceInterval'] as num?)?.toInt() ?? 1,
  recurrenceWeekdays:
      (json['recurrenceWeekdays'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const <int>[],
  recurrenceUntil: json['recurrenceUntil'] == null
      ? null
      : DateTime.parse(json['recurrenceUntil'] as String),
  recurrenceCount: (json['recurrenceCount'] as num?)?.toInt(),
  recurrenceExceptions:
      (json['recurrenceExceptions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  alertMinutes:
      (json['alertMinutes'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const <int>[],
  memberIds:
      (json['memberIds'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  createdAt: DateTime.parse(json['createdAt'] as String),
  modifiedAt: DateTime.parse(json['modifiedAt'] as String),
);

Map<String, dynamic> _$CalendarEventToJson(_CalendarEvent instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'location': instance.location,
      'startAt': instance.startAt.toIso8601String(),
      'endAt': instance.endAt.toIso8601String(),
      'isAllDay': instance.isAllDay,
      'colorHex': instance.colorHex,
      'category': instance.category,
      'recurrence': _$CalendarRecurrenceEnumMap[instance.recurrence]!,
      'recurrenceInterval': instance.recurrenceInterval,
      'recurrenceWeekdays': instance.recurrenceWeekdays,
      'recurrenceUntil': instance.recurrenceUntil?.toIso8601String(),
      'recurrenceCount': instance.recurrenceCount,
      'recurrenceExceptions': instance.recurrenceExceptions,
      'alertMinutes': instance.alertMinutes,
      'memberIds': instance.memberIds,
      'createdAt': instance.createdAt.toIso8601String(),
      'modifiedAt': instance.modifiedAt.toIso8601String(),
    };

const _$CalendarRecurrenceEnumMap = {
  CalendarRecurrence.none: 'none',
  CalendarRecurrence.daily: 'daily',
  CalendarRecurrence.weekly: 'weekly',
  CalendarRecurrence.monthly: 'monthly',
  CalendarRecurrence.yearly: 'yearly',
};
