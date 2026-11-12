// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mood_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MoodEntry {

 String get id;/// Member who logged the check-in, or null for the whole system.
 String? get memberId;/// Valence on a 1–5 scale (1 = very low, 5 = great).
 int get mood;/// How strongly the mood is felt, 1–10.
 int get intensity;/// Emotion keys from the emotion library (or free-form labels).
 List<String> get emotions;/// Optional 1–5 energy level.
 int? get energy;/// Optional 1–5 stress level.
 int? get stress;/// Optional 1–5 sleep quality for the previous night.
 int? get sleepQuality;/// Body regions where a sensation was noticed (keys from the body map).
 List<String> get bodySensations; String? get note; DateTime get recordedAt; DateTime get createdAt; DateTime get modifiedAt;
/// Create a copy of MoodEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MoodEntryCopyWith<MoodEntry> get copyWith => _$MoodEntryCopyWithImpl<MoodEntry>(this as MoodEntry, _$identity);

  /// Serializes this MoodEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MoodEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.memberId, memberId) || other.memberId == memberId)&&(identical(other.mood, mood) || other.mood == mood)&&(identical(other.intensity, intensity) || other.intensity == intensity)&&const DeepCollectionEquality().equals(other.emotions, emotions)&&(identical(other.energy, energy) || other.energy == energy)&&(identical(other.stress, stress) || other.stress == stress)&&(identical(other.sleepQuality, sleepQuality) || other.sleepQuality == sleepQuality)&&const DeepCollectionEquality().equals(other.bodySensations, bodySensations)&&(identical(other.note, note) || other.note == note)&&(identical(other.recordedAt, recordedAt) || other.recordedAt == recordedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.modifiedAt, modifiedAt) || other.modifiedAt == modifiedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,memberId,mood,intensity,const DeepCollectionEquality().hash(emotions),energy,stress,sleepQuality,const DeepCollectionEquality().hash(bodySensations),note,recordedAt,createdAt,modifiedAt);

@override
String toString() {
  return 'MoodEntry(id: $id, memberId: $memberId, mood: $mood, intensity: $intensity, emotions: $emotions, energy: $energy, stress: $stress, sleepQuality: $sleepQuality, bodySensations: $bodySensations, note: $note, recordedAt: $recordedAt, createdAt: $createdAt, modifiedAt: $modifiedAt)';
}


}

/// @nodoc
abstract mixin class $MoodEntryCopyWith<$Res>  {
  factory $MoodEntryCopyWith(MoodEntry value, $Res Function(MoodEntry) _then) = _$MoodEntryCopyWithImpl;
@useResult
$Res call({
 String id, String? memberId, int mood, int intensity, List<String> emotions, int? energy, int? stress, int? sleepQuality, List<String> bodySensations, String? note, DateTime recordedAt, DateTime createdAt, DateTime modifiedAt
});




}
/// @nodoc
class _$MoodEntryCopyWithImpl<$Res>
    implements $MoodEntryCopyWith<$Res> {
  _$MoodEntryCopyWithImpl(this._self, this._then);

  final MoodEntry _self;
  final $Res Function(MoodEntry) _then;

/// Create a copy of MoodEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? memberId = freezed,Object? mood = null,Object? intensity = null,Object? emotions = null,Object? energy = freezed,Object? stress = freezed,Object? sleepQuality = freezed,Object? bodySensations = null,Object? note = freezed,Object? recordedAt = null,Object? createdAt = null,Object? modifiedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,memberId: freezed == memberId ? _self.memberId : memberId // ignore: cast_nullable_to_non_nullable
as String?,mood: null == mood ? _self.mood : mood // ignore: cast_nullable_to_non_nullable
as int,intensity: null == intensity ? _self.intensity : intensity // ignore: cast_nullable_to_non_nullable
as int,emotions: null == emotions ? _self.emotions : emotions // ignore: cast_nullable_to_non_nullable
as List<String>,energy: freezed == energy ? _self.energy : energy // ignore: cast_nullable_to_non_nullable
as int?,stress: freezed == stress ? _self.stress : stress // ignore: cast_nullable_to_non_nullable
as int?,sleepQuality: freezed == sleepQuality ? _self.sleepQuality : sleepQuality // ignore: cast_nullable_to_non_nullable
as int?,bodySensations: null == bodySensations ? _self.bodySensations : bodySensations // ignore: cast_nullable_to_non_nullable
as List<String>,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,recordedAt: null == recordedAt ? _self.recordedAt : recordedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,modifiedAt: null == modifiedAt ? _self.modifiedAt : modifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [MoodEntry].
extension MoodEntryPatterns on MoodEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MoodEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MoodEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MoodEntry value)  $default,){
final _that = this;
switch (_that) {
case _MoodEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MoodEntry value)?  $default,){
final _that = this;
switch (_that) {
case _MoodEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String? memberId,  int mood,  int intensity,  List<String> emotions,  int? energy,  int? stress,  int? sleepQuality,  List<String> bodySensations,  String? note,  DateTime recordedAt,  DateTime createdAt,  DateTime modifiedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MoodEntry() when $default != null:
return $default(_that.id,_that.memberId,_that.mood,_that.intensity,_that.emotions,_that.energy,_that.stress,_that.sleepQuality,_that.bodySensations,_that.note,_that.recordedAt,_that.createdAt,_that.modifiedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String? memberId,  int mood,  int intensity,  List<String> emotions,  int? energy,  int? stress,  int? sleepQuality,  List<String> bodySensations,  String? note,  DateTime recordedAt,  DateTime createdAt,  DateTime modifiedAt)  $default,) {final _that = this;
switch (_that) {
case _MoodEntry():
return $default(_that.id,_that.memberId,_that.mood,_that.intensity,_that.emotions,_that.energy,_that.stress,_that.sleepQuality,_that.bodySensations,_that.note,_that.recordedAt,_that.createdAt,_that.modifiedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String? memberId,  int mood,  int intensity,  List<String> emotions,  int? energy,  int? stress,  int? sleepQuality,  List<String> bodySensations,  String? note,  DateTime recordedAt,  DateTime createdAt,  DateTime modifiedAt)?  $default,) {final _that = this;
switch (_that) {
case _MoodEntry() when $default != null:
return $default(_that.id,_that.memberId,_that.mood,_that.intensity,_that.emotions,_that.energy,_that.stress,_that.sleepQuality,_that.bodySensations,_that.note,_that.recordedAt,_that.createdAt,_that.modifiedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MoodEntry extends MoodEntry {
  const _MoodEntry({required this.id, this.memberId, this.mood = 3, this.intensity = 5, final  List<String> emotions = const <String>[], this.energy, this.stress, this.sleepQuality, final  List<String> bodySensations = const <String>[], this.note, required this.recordedAt, required this.createdAt, required this.modifiedAt}): _emotions = emotions,_bodySensations = bodySensations,super._();
  factory _MoodEntry.fromJson(Map<String, dynamic> json) => _$MoodEntryFromJson(json);

@override final  String id;
/// Member who logged the check-in, or null for the whole system.
@override final  String? memberId;
/// Valence on a 1–5 scale (1 = very low, 5 = great).
@override@JsonKey() final  int mood;
/// How strongly the mood is felt, 1–10.
@override@JsonKey() final  int intensity;
/// Emotion keys from the emotion library (or free-form labels).
 final  List<String> _emotions;
/// Emotion keys from the emotion library (or free-form labels).
@override@JsonKey() List<String> get emotions {
  if (_emotions is EqualUnmodifiableListView) return _emotions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_emotions);
}

/// Optional 1–5 energy level.
@override final  int? energy;
/// Optional 1–5 stress level.
@override final  int? stress;
/// Optional 1–5 sleep quality for the previous night.
@override final  int? sleepQuality;
/// Body regions where a sensation was noticed (keys from the body map).
 final  List<String> _bodySensations;
/// Body regions where a sensation was noticed (keys from the body map).
@override@JsonKey() List<String> get bodySensations {
  if (_bodySensations is EqualUnmodifiableListView) return _bodySensations;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_bodySensations);
}

@override final  String? note;
@override final  DateTime recordedAt;
@override final  DateTime createdAt;
@override final  DateTime modifiedAt;

/// Create a copy of MoodEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MoodEntryCopyWith<_MoodEntry> get copyWith => __$MoodEntryCopyWithImpl<_MoodEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MoodEntryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MoodEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.memberId, memberId) || other.memberId == memberId)&&(identical(other.mood, mood) || other.mood == mood)&&(identical(other.intensity, intensity) || other.intensity == intensity)&&const DeepCollectionEquality().equals(other._emotions, _emotions)&&(identical(other.energy, energy) || other.energy == energy)&&(identical(other.stress, stress) || other.stress == stress)&&(identical(other.sleepQuality, sleepQuality) || other.sleepQuality == sleepQuality)&&const DeepCollectionEquality().equals(other._bodySensations, _bodySensations)&&(identical(other.note, note) || other.note == note)&&(identical(other.recordedAt, recordedAt) || other.recordedAt == recordedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.modifiedAt, modifiedAt) || other.modifiedAt == modifiedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,memberId,mood,intensity,const DeepCollectionEquality().hash(_emotions),energy,stress,sleepQuality,const DeepCollectionEquality().hash(_bodySensations),note,recordedAt,createdAt,modifiedAt);

@override
String toString() {
  return 'MoodEntry(id: $id, memberId: $memberId, mood: $mood, intensity: $intensity, emotions: $emotions, energy: $energy, stress: $stress, sleepQuality: $sleepQuality, bodySensations: $bodySensations, note: $note, recordedAt: $recordedAt, createdAt: $createdAt, modifiedAt: $modifiedAt)';
}


}

/// @nodoc
abstract mixin class _$MoodEntryCopyWith<$Res> implements $MoodEntryCopyWith<$Res> {
  factory _$MoodEntryCopyWith(_MoodEntry value, $Res Function(_MoodEntry) _then) = __$MoodEntryCopyWithImpl;
@override @useResult
$Res call({
 String id, String? memberId, int mood, int intensity, List<String> emotions, int? energy, int? stress, int? sleepQuality, List<String> bodySensations, String? note, DateTime recordedAt, DateTime createdAt, DateTime modifiedAt
});




}
/// @nodoc
class __$MoodEntryCopyWithImpl<$Res>
    implements _$MoodEntryCopyWith<$Res> {
  __$MoodEntryCopyWithImpl(this._self, this._then);

  final _MoodEntry _self;
  final $Res Function(_MoodEntry) _then;

/// Create a copy of MoodEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? memberId = freezed,Object? mood = null,Object? intensity = null,Object? emotions = null,Object? energy = freezed,Object? stress = freezed,Object? sleepQuality = freezed,Object? bodySensations = null,Object? note = freezed,Object? recordedAt = null,Object? createdAt = null,Object? modifiedAt = null,}) {
  return _then(_MoodEntry(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,memberId: freezed == memberId ? _self.memberId : memberId // ignore: cast_nullable_to_non_nullable
as String?,mood: null == mood ? _self.mood : mood // ignore: cast_nullable_to_non_nullable
as int,intensity: null == intensity ? _self.intensity : intensity // ignore: cast_nullable_to_non_nullable
as int,emotions: null == emotions ? _self._emotions : emotions // ignore: cast_nullable_to_non_nullable
as List<String>,energy: freezed == energy ? _self.energy : energy // ignore: cast_nullable_to_non_nullable
as int?,stress: freezed == stress ? _self.stress : stress // ignore: cast_nullable_to_non_nullable
as int?,sleepQuality: freezed == sleepQuality ? _self.sleepQuality : sleepQuality // ignore: cast_nullable_to_non_nullable
as int?,bodySensations: null == bodySensations ? _self._bodySensations : bodySensations // ignore: cast_nullable_to_non_nullable
as List<String>,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,recordedAt: null == recordedAt ? _self.recordedAt : recordedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,modifiedAt: null == modifiedAt ? _self.modifiedAt : modifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
