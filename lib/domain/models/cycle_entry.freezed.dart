// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cycle_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CycleEntry {

 String get id;/// `yyyy-MM-dd`.
 String get date; int get flow; List<String> get symptoms; String? get note; String? get memberId; DateTime get createdAt; DateTime get modifiedAt;
/// Create a copy of CycleEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CycleEntryCopyWith<CycleEntry> get copyWith => _$CycleEntryCopyWithImpl<CycleEntry>(this as CycleEntry, _$identity);

  /// Serializes this CycleEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CycleEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.date, date) || other.date == date)&&(identical(other.flow, flow) || other.flow == flow)&&const DeepCollectionEquality().equals(other.symptoms, symptoms)&&(identical(other.note, note) || other.note == note)&&(identical(other.memberId, memberId) || other.memberId == memberId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.modifiedAt, modifiedAt) || other.modifiedAt == modifiedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,date,flow,const DeepCollectionEquality().hash(symptoms),note,memberId,createdAt,modifiedAt);

@override
String toString() {
  return 'CycleEntry(id: $id, date: $date, flow: $flow, symptoms: $symptoms, note: $note, memberId: $memberId, createdAt: $createdAt, modifiedAt: $modifiedAt)';
}


}

/// @nodoc
abstract mixin class $CycleEntryCopyWith<$Res>  {
  factory $CycleEntryCopyWith(CycleEntry value, $Res Function(CycleEntry) _then) = _$CycleEntryCopyWithImpl;
@useResult
$Res call({
 String id, String date, int flow, List<String> symptoms, String? note, String? memberId, DateTime createdAt, DateTime modifiedAt
});




}
/// @nodoc
class _$CycleEntryCopyWithImpl<$Res>
    implements $CycleEntryCopyWith<$Res> {
  _$CycleEntryCopyWithImpl(this._self, this._then);

  final CycleEntry _self;
  final $Res Function(CycleEntry) _then;

/// Create a copy of CycleEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? date = null,Object? flow = null,Object? symptoms = null,Object? note = freezed,Object? memberId = freezed,Object? createdAt = null,Object? modifiedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,flow: null == flow ? _self.flow : flow // ignore: cast_nullable_to_non_nullable
as int,symptoms: null == symptoms ? _self.symptoms : symptoms // ignore: cast_nullable_to_non_nullable
as List<String>,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,memberId: freezed == memberId ? _self.memberId : memberId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,modifiedAt: null == modifiedAt ? _self.modifiedAt : modifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [CycleEntry].
extension CycleEntryPatterns on CycleEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CycleEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CycleEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CycleEntry value)  $default,){
final _that = this;
switch (_that) {
case _CycleEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CycleEntry value)?  $default,){
final _that = this;
switch (_that) {
case _CycleEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String date,  int flow,  List<String> symptoms,  String? note,  String? memberId,  DateTime createdAt,  DateTime modifiedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CycleEntry() when $default != null:
return $default(_that.id,_that.date,_that.flow,_that.symptoms,_that.note,_that.memberId,_that.createdAt,_that.modifiedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String date,  int flow,  List<String> symptoms,  String? note,  String? memberId,  DateTime createdAt,  DateTime modifiedAt)  $default,) {final _that = this;
switch (_that) {
case _CycleEntry():
return $default(_that.id,_that.date,_that.flow,_that.symptoms,_that.note,_that.memberId,_that.createdAt,_that.modifiedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String date,  int flow,  List<String> symptoms,  String? note,  String? memberId,  DateTime createdAt,  DateTime modifiedAt)?  $default,) {final _that = this;
switch (_that) {
case _CycleEntry() when $default != null:
return $default(_that.id,_that.date,_that.flow,_that.symptoms,_that.note,_that.memberId,_that.createdAt,_that.modifiedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CycleEntry extends CycleEntry {
  const _CycleEntry({required this.id, required this.date, this.flow = 0, final  List<String> symptoms = const <String>[], this.note, this.memberId, required this.createdAt, required this.modifiedAt}): _symptoms = symptoms,super._();
  factory _CycleEntry.fromJson(Map<String, dynamic> json) => _$CycleEntryFromJson(json);

@override final  String id;
/// `yyyy-MM-dd`.
@override final  String date;
@override@JsonKey() final  int flow;
 final  List<String> _symptoms;
@override@JsonKey() List<String> get symptoms {
  if (_symptoms is EqualUnmodifiableListView) return _symptoms;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_symptoms);
}

@override final  String? note;
@override final  String? memberId;
@override final  DateTime createdAt;
@override final  DateTime modifiedAt;

/// Create a copy of CycleEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CycleEntryCopyWith<_CycleEntry> get copyWith => __$CycleEntryCopyWithImpl<_CycleEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CycleEntryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CycleEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.date, date) || other.date == date)&&(identical(other.flow, flow) || other.flow == flow)&&const DeepCollectionEquality().equals(other._symptoms, _symptoms)&&(identical(other.note, note) || other.note == note)&&(identical(other.memberId, memberId) || other.memberId == memberId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.modifiedAt, modifiedAt) || other.modifiedAt == modifiedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,date,flow,const DeepCollectionEquality().hash(_symptoms),note,memberId,createdAt,modifiedAt);

@override
String toString() {
  return 'CycleEntry(id: $id, date: $date, flow: $flow, symptoms: $symptoms, note: $note, memberId: $memberId, createdAt: $createdAt, modifiedAt: $modifiedAt)';
}


}

/// @nodoc
abstract mixin class _$CycleEntryCopyWith<$Res> implements $CycleEntryCopyWith<$Res> {
  factory _$CycleEntryCopyWith(_CycleEntry value, $Res Function(_CycleEntry) _then) = __$CycleEntryCopyWithImpl;
@override @useResult
$Res call({
 String id, String date, int flow, List<String> symptoms, String? note, String? memberId, DateTime createdAt, DateTime modifiedAt
});




}
/// @nodoc
class __$CycleEntryCopyWithImpl<$Res>
    implements _$CycleEntryCopyWith<$Res> {
  __$CycleEntryCopyWithImpl(this._self, this._then);

  final _CycleEntry _self;
  final $Res Function(_CycleEntry) _then;

/// Create a copy of CycleEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? date = null,Object? flow = null,Object? symptoms = null,Object? note = freezed,Object? memberId = freezed,Object? createdAt = null,Object? modifiedAt = null,}) {
  return _then(_CycleEntry(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,flow: null == flow ? _self.flow : flow // ignore: cast_nullable_to_non_nullable
as int,symptoms: null == symptoms ? _self._symptoms : symptoms // ignore: cast_nullable_to_non_nullable
as List<String>,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,memberId: freezed == memberId ? _self.memberId : memberId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,modifiedAt: null == modifiedAt ? _self.modifiedAt : modifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
