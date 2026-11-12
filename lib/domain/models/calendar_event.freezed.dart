// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'calendar_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CalendarEvent {

 String get id; String get title; String? get description; String? get location;/// Start of the first occurrence. For all-day events only the date part
/// is meaningful.
 DateTime get startAt;/// End of the first occurrence. For all-day events this is the last day
/// the event covers (inclusive).
 DateTime get endAt; bool get isAllDay;/// `#RRGGBB` colour, or null for the theme accent.
 String? get colorHex; String? get category; CalendarRecurrence get recurrence;/// Repeat every N units of [recurrence].
 int get recurrenceInterval;/// Weekdays (0 = Sunday … 6 = Saturday) for weekly rules. Empty means
/// "the weekday of [startAt]".
 List<int> get recurrenceWeekdays;/// Last day the series may produce an occurrence on (inclusive).
 DateTime? get recurrenceUntil;/// Maximum number of occurrences in the series.
 int? get recurrenceCount;/// `yyyy-MM-dd` keys of occurrences removed from the series.
 List<String> get recurrenceExceptions;/// Notification offsets in minutes before each occurrence starts.
 List<int> get alertMinutes;/// Attending member ids.
 List<String> get memberIds; DateTime get createdAt; DateTime get modifiedAt;
/// Create a copy of CalendarEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CalendarEventCopyWith<CalendarEvent> get copyWith => _$CalendarEventCopyWithImpl<CalendarEvent>(this as CalendarEvent, _$identity);

  /// Serializes this CalendarEvent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CalendarEvent&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.location, location) || other.location == location)&&(identical(other.startAt, startAt) || other.startAt == startAt)&&(identical(other.endAt, endAt) || other.endAt == endAt)&&(identical(other.isAllDay, isAllDay) || other.isAllDay == isAllDay)&&(identical(other.colorHex, colorHex) || other.colorHex == colorHex)&&(identical(other.category, category) || other.category == category)&&(identical(other.recurrence, recurrence) || other.recurrence == recurrence)&&(identical(other.recurrenceInterval, recurrenceInterval) || other.recurrenceInterval == recurrenceInterval)&&const DeepCollectionEquality().equals(other.recurrenceWeekdays, recurrenceWeekdays)&&(identical(other.recurrenceUntil, recurrenceUntil) || other.recurrenceUntil == recurrenceUntil)&&(identical(other.recurrenceCount, recurrenceCount) || other.recurrenceCount == recurrenceCount)&&const DeepCollectionEquality().equals(other.recurrenceExceptions, recurrenceExceptions)&&const DeepCollectionEquality().equals(other.alertMinutes, alertMinutes)&&const DeepCollectionEquality().equals(other.memberIds, memberIds)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.modifiedAt, modifiedAt) || other.modifiedAt == modifiedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,title,description,location,startAt,endAt,isAllDay,colorHex,category,recurrence,recurrenceInterval,const DeepCollectionEquality().hash(recurrenceWeekdays),recurrenceUntil,recurrenceCount,const DeepCollectionEquality().hash(recurrenceExceptions),const DeepCollectionEquality().hash(alertMinutes),const DeepCollectionEquality().hash(memberIds),createdAt,modifiedAt]);

@override
String toString() {
  return 'CalendarEvent(id: $id, title: $title, description: $description, location: $location, startAt: $startAt, endAt: $endAt, isAllDay: $isAllDay, colorHex: $colorHex, category: $category, recurrence: $recurrence, recurrenceInterval: $recurrenceInterval, recurrenceWeekdays: $recurrenceWeekdays, recurrenceUntil: $recurrenceUntil, recurrenceCount: $recurrenceCount, recurrenceExceptions: $recurrenceExceptions, alertMinutes: $alertMinutes, memberIds: $memberIds, createdAt: $createdAt, modifiedAt: $modifiedAt)';
}


}

/// @nodoc
abstract mixin class $CalendarEventCopyWith<$Res>  {
  factory $CalendarEventCopyWith(CalendarEvent value, $Res Function(CalendarEvent) _then) = _$CalendarEventCopyWithImpl;
@useResult
$Res call({
 String id, String title, String? description, String? location, DateTime startAt, DateTime endAt, bool isAllDay, String? colorHex, String? category, CalendarRecurrence recurrence, int recurrenceInterval, List<int> recurrenceWeekdays, DateTime? recurrenceUntil, int? recurrenceCount, List<String> recurrenceExceptions, List<int> alertMinutes, List<String> memberIds, DateTime createdAt, DateTime modifiedAt
});




}
/// @nodoc
class _$CalendarEventCopyWithImpl<$Res>
    implements $CalendarEventCopyWith<$Res> {
  _$CalendarEventCopyWithImpl(this._self, this._then);

  final CalendarEvent _self;
  final $Res Function(CalendarEvent) _then;

/// Create a copy of CalendarEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? description = freezed,Object? location = freezed,Object? startAt = null,Object? endAt = null,Object? isAllDay = null,Object? colorHex = freezed,Object? category = freezed,Object? recurrence = null,Object? recurrenceInterval = null,Object? recurrenceWeekdays = null,Object? recurrenceUntil = freezed,Object? recurrenceCount = freezed,Object? recurrenceExceptions = null,Object? alertMinutes = null,Object? memberIds = null,Object? createdAt = null,Object? modifiedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,location: freezed == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String?,startAt: null == startAt ? _self.startAt : startAt // ignore: cast_nullable_to_non_nullable
as DateTime,endAt: null == endAt ? _self.endAt : endAt // ignore: cast_nullable_to_non_nullable
as DateTime,isAllDay: null == isAllDay ? _self.isAllDay : isAllDay // ignore: cast_nullable_to_non_nullable
as bool,colorHex: freezed == colorHex ? _self.colorHex : colorHex // ignore: cast_nullable_to_non_nullable
as String?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,recurrence: null == recurrence ? _self.recurrence : recurrence // ignore: cast_nullable_to_non_nullable
as CalendarRecurrence,recurrenceInterval: null == recurrenceInterval ? _self.recurrenceInterval : recurrenceInterval // ignore: cast_nullable_to_non_nullable
as int,recurrenceWeekdays: null == recurrenceWeekdays ? _self.recurrenceWeekdays : recurrenceWeekdays // ignore: cast_nullable_to_non_nullable
as List<int>,recurrenceUntil: freezed == recurrenceUntil ? _self.recurrenceUntil : recurrenceUntil // ignore: cast_nullable_to_non_nullable
as DateTime?,recurrenceCount: freezed == recurrenceCount ? _self.recurrenceCount : recurrenceCount // ignore: cast_nullable_to_non_nullable
as int?,recurrenceExceptions: null == recurrenceExceptions ? _self.recurrenceExceptions : recurrenceExceptions // ignore: cast_nullable_to_non_nullable
as List<String>,alertMinutes: null == alertMinutes ? _self.alertMinutes : alertMinutes // ignore: cast_nullable_to_non_nullable
as List<int>,memberIds: null == memberIds ? _self.memberIds : memberIds // ignore: cast_nullable_to_non_nullable
as List<String>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,modifiedAt: null == modifiedAt ? _self.modifiedAt : modifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [CalendarEvent].
extension CalendarEventPatterns on CalendarEvent {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CalendarEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CalendarEvent() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CalendarEvent value)  $default,){
final _that = this;
switch (_that) {
case _CalendarEvent():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CalendarEvent value)?  $default,){
final _that = this;
switch (_that) {
case _CalendarEvent() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String? description,  String? location,  DateTime startAt,  DateTime endAt,  bool isAllDay,  String? colorHex,  String? category,  CalendarRecurrence recurrence,  int recurrenceInterval,  List<int> recurrenceWeekdays,  DateTime? recurrenceUntil,  int? recurrenceCount,  List<String> recurrenceExceptions,  List<int> alertMinutes,  List<String> memberIds,  DateTime createdAt,  DateTime modifiedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CalendarEvent() when $default != null:
return $default(_that.id,_that.title,_that.description,_that.location,_that.startAt,_that.endAt,_that.isAllDay,_that.colorHex,_that.category,_that.recurrence,_that.recurrenceInterval,_that.recurrenceWeekdays,_that.recurrenceUntil,_that.recurrenceCount,_that.recurrenceExceptions,_that.alertMinutes,_that.memberIds,_that.createdAt,_that.modifiedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String? description,  String? location,  DateTime startAt,  DateTime endAt,  bool isAllDay,  String? colorHex,  String? category,  CalendarRecurrence recurrence,  int recurrenceInterval,  List<int> recurrenceWeekdays,  DateTime? recurrenceUntil,  int? recurrenceCount,  List<String> recurrenceExceptions,  List<int> alertMinutes,  List<String> memberIds,  DateTime createdAt,  DateTime modifiedAt)  $default,) {final _that = this;
switch (_that) {
case _CalendarEvent():
return $default(_that.id,_that.title,_that.description,_that.location,_that.startAt,_that.endAt,_that.isAllDay,_that.colorHex,_that.category,_that.recurrence,_that.recurrenceInterval,_that.recurrenceWeekdays,_that.recurrenceUntil,_that.recurrenceCount,_that.recurrenceExceptions,_that.alertMinutes,_that.memberIds,_that.createdAt,_that.modifiedAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String? description,  String? location,  DateTime startAt,  DateTime endAt,  bool isAllDay,  String? colorHex,  String? category,  CalendarRecurrence recurrence,  int recurrenceInterval,  List<int> recurrenceWeekdays,  DateTime? recurrenceUntil,  int? recurrenceCount,  List<String> recurrenceExceptions,  List<int> alertMinutes,  List<String> memberIds,  DateTime createdAt,  DateTime modifiedAt)?  $default,) {final _that = this;
switch (_that) {
case _CalendarEvent() when $default != null:
return $default(_that.id,_that.title,_that.description,_that.location,_that.startAt,_that.endAt,_that.isAllDay,_that.colorHex,_that.category,_that.recurrence,_that.recurrenceInterval,_that.recurrenceWeekdays,_that.recurrenceUntil,_that.recurrenceCount,_that.recurrenceExceptions,_that.alertMinutes,_that.memberIds,_that.createdAt,_that.modifiedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CalendarEvent extends CalendarEvent {
  const _CalendarEvent({required this.id, required this.title, this.description, this.location, required this.startAt, required this.endAt, this.isAllDay = false, this.colorHex, this.category, this.recurrence = CalendarRecurrence.none, this.recurrenceInterval = 1, final  List<int> recurrenceWeekdays = const <int>[], this.recurrenceUntil, this.recurrenceCount, final  List<String> recurrenceExceptions = const <String>[], final  List<int> alertMinutes = const <int>[], final  List<String> memberIds = const <String>[], required this.createdAt, required this.modifiedAt}): _recurrenceWeekdays = recurrenceWeekdays,_recurrenceExceptions = recurrenceExceptions,_alertMinutes = alertMinutes,_memberIds = memberIds,super._();
  factory _CalendarEvent.fromJson(Map<String, dynamic> json) => _$CalendarEventFromJson(json);

@override final  String id;
@override final  String title;
@override final  String? description;
@override final  String? location;
/// Start of the first occurrence. For all-day events only the date part
/// is meaningful.
@override final  DateTime startAt;
/// End of the first occurrence. For all-day events this is the last day
/// the event covers (inclusive).
@override final  DateTime endAt;
@override@JsonKey() final  bool isAllDay;
/// `#RRGGBB` colour, or null for the theme accent.
@override final  String? colorHex;
@override final  String? category;
@override@JsonKey() final  CalendarRecurrence recurrence;
/// Repeat every N units of [recurrence].
@override@JsonKey() final  int recurrenceInterval;
/// Weekdays (0 = Sunday … 6 = Saturday) for weekly rules. Empty means
/// "the weekday of [startAt]".
 final  List<int> _recurrenceWeekdays;
/// Weekdays (0 = Sunday … 6 = Saturday) for weekly rules. Empty means
/// "the weekday of [startAt]".
@override@JsonKey() List<int> get recurrenceWeekdays {
  if (_recurrenceWeekdays is EqualUnmodifiableListView) return _recurrenceWeekdays;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_recurrenceWeekdays);
}

/// Last day the series may produce an occurrence on (inclusive).
@override final  DateTime? recurrenceUntil;
/// Maximum number of occurrences in the series.
@override final  int? recurrenceCount;
/// `yyyy-MM-dd` keys of occurrences removed from the series.
 final  List<String> _recurrenceExceptions;
/// `yyyy-MM-dd` keys of occurrences removed from the series.
@override@JsonKey() List<String> get recurrenceExceptions {
  if (_recurrenceExceptions is EqualUnmodifiableListView) return _recurrenceExceptions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_recurrenceExceptions);
}

/// Notification offsets in minutes before each occurrence starts.
 final  List<int> _alertMinutes;
/// Notification offsets in minutes before each occurrence starts.
@override@JsonKey() List<int> get alertMinutes {
  if (_alertMinutes is EqualUnmodifiableListView) return _alertMinutes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_alertMinutes);
}

/// Attending member ids.
 final  List<String> _memberIds;
/// Attending member ids.
@override@JsonKey() List<String> get memberIds {
  if (_memberIds is EqualUnmodifiableListView) return _memberIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_memberIds);
}

@override final  DateTime createdAt;
@override final  DateTime modifiedAt;

/// Create a copy of CalendarEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CalendarEventCopyWith<_CalendarEvent> get copyWith => __$CalendarEventCopyWithImpl<_CalendarEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CalendarEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CalendarEvent&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.location, location) || other.location == location)&&(identical(other.startAt, startAt) || other.startAt == startAt)&&(identical(other.endAt, endAt) || other.endAt == endAt)&&(identical(other.isAllDay, isAllDay) || other.isAllDay == isAllDay)&&(identical(other.colorHex, colorHex) || other.colorHex == colorHex)&&(identical(other.category, category) || other.category == category)&&(identical(other.recurrence, recurrence) || other.recurrence == recurrence)&&(identical(other.recurrenceInterval, recurrenceInterval) || other.recurrenceInterval == recurrenceInterval)&&const DeepCollectionEquality().equals(other._recurrenceWeekdays, _recurrenceWeekdays)&&(identical(other.recurrenceUntil, recurrenceUntil) || other.recurrenceUntil == recurrenceUntil)&&(identical(other.recurrenceCount, recurrenceCount) || other.recurrenceCount == recurrenceCount)&&const DeepCollectionEquality().equals(other._recurrenceExceptions, _recurrenceExceptions)&&const DeepCollectionEquality().equals(other._alertMinutes, _alertMinutes)&&const DeepCollectionEquality().equals(other._memberIds, _memberIds)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.modifiedAt, modifiedAt) || other.modifiedAt == modifiedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,title,description,location,startAt,endAt,isAllDay,colorHex,category,recurrence,recurrenceInterval,const DeepCollectionEquality().hash(_recurrenceWeekdays),recurrenceUntil,recurrenceCount,const DeepCollectionEquality().hash(_recurrenceExceptions),const DeepCollectionEquality().hash(_alertMinutes),const DeepCollectionEquality().hash(_memberIds),createdAt,modifiedAt]);

@override
String toString() {
  return 'CalendarEvent(id: $id, title: $title, description: $description, location: $location, startAt: $startAt, endAt: $endAt, isAllDay: $isAllDay, colorHex: $colorHex, category: $category, recurrence: $recurrence, recurrenceInterval: $recurrenceInterval, recurrenceWeekdays: $recurrenceWeekdays, recurrenceUntil: $recurrenceUntil, recurrenceCount: $recurrenceCount, recurrenceExceptions: $recurrenceExceptions, alertMinutes: $alertMinutes, memberIds: $memberIds, createdAt: $createdAt, modifiedAt: $modifiedAt)';
}


}

/// @nodoc
abstract mixin class _$CalendarEventCopyWith<$Res> implements $CalendarEventCopyWith<$Res> {
  factory _$CalendarEventCopyWith(_CalendarEvent value, $Res Function(_CalendarEvent) _then) = __$CalendarEventCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String? description, String? location, DateTime startAt, DateTime endAt, bool isAllDay, String? colorHex, String? category, CalendarRecurrence recurrence, int recurrenceInterval, List<int> recurrenceWeekdays, DateTime? recurrenceUntil, int? recurrenceCount, List<String> recurrenceExceptions, List<int> alertMinutes, List<String> memberIds, DateTime createdAt, DateTime modifiedAt
});




}
/// @nodoc
class __$CalendarEventCopyWithImpl<$Res>
    implements _$CalendarEventCopyWith<$Res> {
  __$CalendarEventCopyWithImpl(this._self, this._then);

  final _CalendarEvent _self;
  final $Res Function(_CalendarEvent) _then;

/// Create a copy of CalendarEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? description = freezed,Object? location = freezed,Object? startAt = null,Object? endAt = null,Object? isAllDay = null,Object? colorHex = freezed,Object? category = freezed,Object? recurrence = null,Object? recurrenceInterval = null,Object? recurrenceWeekdays = null,Object? recurrenceUntil = freezed,Object? recurrenceCount = freezed,Object? recurrenceExceptions = null,Object? alertMinutes = null,Object? memberIds = null,Object? createdAt = null,Object? modifiedAt = null,}) {
  return _then(_CalendarEvent(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,location: freezed == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String?,startAt: null == startAt ? _self.startAt : startAt // ignore: cast_nullable_to_non_nullable
as DateTime,endAt: null == endAt ? _self.endAt : endAt // ignore: cast_nullable_to_non_nullable
as DateTime,isAllDay: null == isAllDay ? _self.isAllDay : isAllDay // ignore: cast_nullable_to_non_nullable
as bool,colorHex: freezed == colorHex ? _self.colorHex : colorHex // ignore: cast_nullable_to_non_nullable
as String?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,recurrence: null == recurrence ? _self.recurrence : recurrence // ignore: cast_nullable_to_non_nullable
as CalendarRecurrence,recurrenceInterval: null == recurrenceInterval ? _self.recurrenceInterval : recurrenceInterval // ignore: cast_nullable_to_non_nullable
as int,recurrenceWeekdays: null == recurrenceWeekdays ? _self._recurrenceWeekdays : recurrenceWeekdays // ignore: cast_nullable_to_non_nullable
as List<int>,recurrenceUntil: freezed == recurrenceUntil ? _self.recurrenceUntil : recurrenceUntil // ignore: cast_nullable_to_non_nullable
as DateTime?,recurrenceCount: freezed == recurrenceCount ? _self.recurrenceCount : recurrenceCount // ignore: cast_nullable_to_non_nullable
as int?,recurrenceExceptions: null == recurrenceExceptions ? _self._recurrenceExceptions : recurrenceExceptions // ignore: cast_nullable_to_non_nullable
as List<String>,alertMinutes: null == alertMinutes ? _self._alertMinutes : alertMinutes // ignore: cast_nullable_to_non_nullable
as List<int>,memberIds: null == memberIds ? _self._memberIds : memberIds // ignore: cast_nullable_to_non_nullable
as List<String>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,modifiedAt: null == modifiedAt ? _self.modifiedAt : modifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
