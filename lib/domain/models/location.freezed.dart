// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'location.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SavedLocation {

 String get id; String get name; String? get emoji; String? get colorHex; String? get address; String? get notes; bool get isFavorite; int get sortOrder; DateTime get createdAt; DateTime get modifiedAt;
/// Create a copy of SavedLocation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SavedLocationCopyWith<SavedLocation> get copyWith => _$SavedLocationCopyWithImpl<SavedLocation>(this as SavedLocation, _$identity);

  /// Serializes this SavedLocation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SavedLocation&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.emoji, emoji) || other.emoji == emoji)&&(identical(other.colorHex, colorHex) || other.colorHex == colorHex)&&(identical(other.address, address) || other.address == address)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.isFavorite, isFavorite) || other.isFavorite == isFavorite)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.modifiedAt, modifiedAt) || other.modifiedAt == modifiedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,emoji,colorHex,address,notes,isFavorite,sortOrder,createdAt,modifiedAt);

@override
String toString() {
  return 'SavedLocation(id: $id, name: $name, emoji: $emoji, colorHex: $colorHex, address: $address, notes: $notes, isFavorite: $isFavorite, sortOrder: $sortOrder, createdAt: $createdAt, modifiedAt: $modifiedAt)';
}


}

/// @nodoc
abstract mixin class $SavedLocationCopyWith<$Res>  {
  factory $SavedLocationCopyWith(SavedLocation value, $Res Function(SavedLocation) _then) = _$SavedLocationCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? emoji, String? colorHex, String? address, String? notes, bool isFavorite, int sortOrder, DateTime createdAt, DateTime modifiedAt
});




}
/// @nodoc
class _$SavedLocationCopyWithImpl<$Res>
    implements $SavedLocationCopyWith<$Res> {
  _$SavedLocationCopyWithImpl(this._self, this._then);

  final SavedLocation _self;
  final $Res Function(SavedLocation) _then;

/// Create a copy of SavedLocation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? emoji = freezed,Object? colorHex = freezed,Object? address = freezed,Object? notes = freezed,Object? isFavorite = null,Object? sortOrder = null,Object? createdAt = null,Object? modifiedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,emoji: freezed == emoji ? _self.emoji : emoji // ignore: cast_nullable_to_non_nullable
as String?,colorHex: freezed == colorHex ? _self.colorHex : colorHex // ignore: cast_nullable_to_non_nullable
as String?,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,isFavorite: null == isFavorite ? _self.isFavorite : isFavorite // ignore: cast_nullable_to_non_nullable
as bool,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,modifiedAt: null == modifiedAt ? _self.modifiedAt : modifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [SavedLocation].
extension SavedLocationPatterns on SavedLocation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SavedLocation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SavedLocation() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SavedLocation value)  $default,){
final _that = this;
switch (_that) {
case _SavedLocation():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SavedLocation value)?  $default,){
final _that = this;
switch (_that) {
case _SavedLocation() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? emoji,  String? colorHex,  String? address,  String? notes,  bool isFavorite,  int sortOrder,  DateTime createdAt,  DateTime modifiedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SavedLocation() when $default != null:
return $default(_that.id,_that.name,_that.emoji,_that.colorHex,_that.address,_that.notes,_that.isFavorite,_that.sortOrder,_that.createdAt,_that.modifiedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? emoji,  String? colorHex,  String? address,  String? notes,  bool isFavorite,  int sortOrder,  DateTime createdAt,  DateTime modifiedAt)  $default,) {final _that = this;
switch (_that) {
case _SavedLocation():
return $default(_that.id,_that.name,_that.emoji,_that.colorHex,_that.address,_that.notes,_that.isFavorite,_that.sortOrder,_that.createdAt,_that.modifiedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? emoji,  String? colorHex,  String? address,  String? notes,  bool isFavorite,  int sortOrder,  DateTime createdAt,  DateTime modifiedAt)?  $default,) {final _that = this;
switch (_that) {
case _SavedLocation() when $default != null:
return $default(_that.id,_that.name,_that.emoji,_that.colorHex,_that.address,_that.notes,_that.isFavorite,_that.sortOrder,_that.createdAt,_that.modifiedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SavedLocation implements SavedLocation {
  const _SavedLocation({required this.id, required this.name, this.emoji, this.colorHex, this.address, this.notes, this.isFavorite = false, this.sortOrder = 0, required this.createdAt, required this.modifiedAt});
  factory _SavedLocation.fromJson(Map<String, dynamic> json) => _$SavedLocationFromJson(json);

@override final  String id;
@override final  String name;
@override final  String? emoji;
@override final  String? colorHex;
@override final  String? address;
@override final  String? notes;
@override@JsonKey() final  bool isFavorite;
@override@JsonKey() final  int sortOrder;
@override final  DateTime createdAt;
@override final  DateTime modifiedAt;

/// Create a copy of SavedLocation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SavedLocationCopyWith<_SavedLocation> get copyWith => __$SavedLocationCopyWithImpl<_SavedLocation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SavedLocationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SavedLocation&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.emoji, emoji) || other.emoji == emoji)&&(identical(other.colorHex, colorHex) || other.colorHex == colorHex)&&(identical(other.address, address) || other.address == address)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.isFavorite, isFavorite) || other.isFavorite == isFavorite)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.modifiedAt, modifiedAt) || other.modifiedAt == modifiedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,emoji,colorHex,address,notes,isFavorite,sortOrder,createdAt,modifiedAt);

@override
String toString() {
  return 'SavedLocation(id: $id, name: $name, emoji: $emoji, colorHex: $colorHex, address: $address, notes: $notes, isFavorite: $isFavorite, sortOrder: $sortOrder, createdAt: $createdAt, modifiedAt: $modifiedAt)';
}


}

/// @nodoc
abstract mixin class _$SavedLocationCopyWith<$Res> implements $SavedLocationCopyWith<$Res> {
  factory _$SavedLocationCopyWith(_SavedLocation value, $Res Function(_SavedLocation) _then) = __$SavedLocationCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? emoji, String? colorHex, String? address, String? notes, bool isFavorite, int sortOrder, DateTime createdAt, DateTime modifiedAt
});




}
/// @nodoc
class __$SavedLocationCopyWithImpl<$Res>
    implements _$SavedLocationCopyWith<$Res> {
  __$SavedLocationCopyWithImpl(this._self, this._then);

  final _SavedLocation _self;
  final $Res Function(_SavedLocation) _then;

/// Create a copy of SavedLocation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? emoji = freezed,Object? colorHex = freezed,Object? address = freezed,Object? notes = freezed,Object? isFavorite = null,Object? sortOrder = null,Object? createdAt = null,Object? modifiedAt = null,}) {
  return _then(_SavedLocation(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,emoji: freezed == emoji ? _self.emoji : emoji // ignore: cast_nullable_to_non_nullable
as String?,colorHex: freezed == colorHex ? _self.colorHex : colorHex // ignore: cast_nullable_to_non_nullable
as String?,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,isFavorite: null == isFavorite ? _self.isFavorite : isFavorite // ignore: cast_nullable_to_non_nullable
as bool,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,modifiedAt: null == modifiedAt ? _self.modifiedAt : modifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$LocationSession {

 String get id; String get locationId; DateTime get startedAt; DateTime? get endedAt; String? get note; DateTime get createdAt; DateTime get modifiedAt;
/// Create a copy of LocationSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LocationSessionCopyWith<LocationSession> get copyWith => _$LocationSessionCopyWithImpl<LocationSession>(this as LocationSession, _$identity);

  /// Serializes this LocationSession to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LocationSession&&(identical(other.id, id) || other.id == id)&&(identical(other.locationId, locationId) || other.locationId == locationId)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.endedAt, endedAt) || other.endedAt == endedAt)&&(identical(other.note, note) || other.note == note)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.modifiedAt, modifiedAt) || other.modifiedAt == modifiedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,locationId,startedAt,endedAt,note,createdAt,modifiedAt);

@override
String toString() {
  return 'LocationSession(id: $id, locationId: $locationId, startedAt: $startedAt, endedAt: $endedAt, note: $note, createdAt: $createdAt, modifiedAt: $modifiedAt)';
}


}

/// @nodoc
abstract mixin class $LocationSessionCopyWith<$Res>  {
  factory $LocationSessionCopyWith(LocationSession value, $Res Function(LocationSession) _then) = _$LocationSessionCopyWithImpl;
@useResult
$Res call({
 String id, String locationId, DateTime startedAt, DateTime? endedAt, String? note, DateTime createdAt, DateTime modifiedAt
});




}
/// @nodoc
class _$LocationSessionCopyWithImpl<$Res>
    implements $LocationSessionCopyWith<$Res> {
  _$LocationSessionCopyWithImpl(this._self, this._then);

  final LocationSession _self;
  final $Res Function(LocationSession) _then;

/// Create a copy of LocationSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? locationId = null,Object? startedAt = null,Object? endedAt = freezed,Object? note = freezed,Object? createdAt = null,Object? modifiedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,locationId: null == locationId ? _self.locationId : locationId // ignore: cast_nullable_to_non_nullable
as String,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,endedAt: freezed == endedAt ? _self.endedAt : endedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,modifiedAt: null == modifiedAt ? _self.modifiedAt : modifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [LocationSession].
extension LocationSessionPatterns on LocationSession {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LocationSession value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LocationSession() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LocationSession value)  $default,){
final _that = this;
switch (_that) {
case _LocationSession():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LocationSession value)?  $default,){
final _that = this;
switch (_that) {
case _LocationSession() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String locationId,  DateTime startedAt,  DateTime? endedAt,  String? note,  DateTime createdAt,  DateTime modifiedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LocationSession() when $default != null:
return $default(_that.id,_that.locationId,_that.startedAt,_that.endedAt,_that.note,_that.createdAt,_that.modifiedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String locationId,  DateTime startedAt,  DateTime? endedAt,  String? note,  DateTime createdAt,  DateTime modifiedAt)  $default,) {final _that = this;
switch (_that) {
case _LocationSession():
return $default(_that.id,_that.locationId,_that.startedAt,_that.endedAt,_that.note,_that.createdAt,_that.modifiedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String locationId,  DateTime startedAt,  DateTime? endedAt,  String? note,  DateTime createdAt,  DateTime modifiedAt)?  $default,) {final _that = this;
switch (_that) {
case _LocationSession() when $default != null:
return $default(_that.id,_that.locationId,_that.startedAt,_that.endedAt,_that.note,_that.createdAt,_that.modifiedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LocationSession extends LocationSession {
  const _LocationSession({required this.id, required this.locationId, required this.startedAt, this.endedAt, this.note, required this.createdAt, required this.modifiedAt}): super._();
  factory _LocationSession.fromJson(Map<String, dynamic> json) => _$LocationSessionFromJson(json);

@override final  String id;
@override final  String locationId;
@override final  DateTime startedAt;
@override final  DateTime? endedAt;
@override final  String? note;
@override final  DateTime createdAt;
@override final  DateTime modifiedAt;

/// Create a copy of LocationSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LocationSessionCopyWith<_LocationSession> get copyWith => __$LocationSessionCopyWithImpl<_LocationSession>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LocationSessionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LocationSession&&(identical(other.id, id) || other.id == id)&&(identical(other.locationId, locationId) || other.locationId == locationId)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.endedAt, endedAt) || other.endedAt == endedAt)&&(identical(other.note, note) || other.note == note)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.modifiedAt, modifiedAt) || other.modifiedAt == modifiedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,locationId,startedAt,endedAt,note,createdAt,modifiedAt);

@override
String toString() {
  return 'LocationSession(id: $id, locationId: $locationId, startedAt: $startedAt, endedAt: $endedAt, note: $note, createdAt: $createdAt, modifiedAt: $modifiedAt)';
}


}

/// @nodoc
abstract mixin class _$LocationSessionCopyWith<$Res> implements $LocationSessionCopyWith<$Res> {
  factory _$LocationSessionCopyWith(_LocationSession value, $Res Function(_LocationSession) _then) = __$LocationSessionCopyWithImpl;
@override @useResult
$Res call({
 String id, String locationId, DateTime startedAt, DateTime? endedAt, String? note, DateTime createdAt, DateTime modifiedAt
});




}
/// @nodoc
class __$LocationSessionCopyWithImpl<$Res>
    implements _$LocationSessionCopyWith<$Res> {
  __$LocationSessionCopyWithImpl(this._self, this._then);

  final _LocationSession _self;
  final $Res Function(_LocationSession) _then;

/// Create a copy of LocationSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? locationId = null,Object? startedAt = null,Object? endedAt = freezed,Object? note = freezed,Object? createdAt = null,Object? modifiedAt = null,}) {
  return _then(_LocationSession(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,locationId: null == locationId ? _self.locationId : locationId // ignore: cast_nullable_to_non_nullable
as String,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,endedAt: freezed == endedAt ? _self.endedAt : endedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,modifiedAt: null == modifiedAt ? _self.modifiedAt : modifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
