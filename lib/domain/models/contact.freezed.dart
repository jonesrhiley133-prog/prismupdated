// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'contact.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Contact {

 String get id; String get displayName; List<String> get phones; List<String> get emails;/// `yyyy-MM-dd`, or `0004-MM-dd` when the year is unknown.
 String? get birthday; String? get notes; String get source; String? get externalId; bool get isFavorite; DateTime get createdAt; DateTime get modifiedAt;
/// Create a copy of Contact
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ContactCopyWith<Contact> get copyWith => _$ContactCopyWithImpl<Contact>(this as Contact, _$identity);

  /// Serializes this Contact to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Contact&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&const DeepCollectionEquality().equals(other.phones, phones)&&const DeepCollectionEquality().equals(other.emails, emails)&&(identical(other.birthday, birthday) || other.birthday == birthday)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.source, source) || other.source == source)&&(identical(other.externalId, externalId) || other.externalId == externalId)&&(identical(other.isFavorite, isFavorite) || other.isFavorite == isFavorite)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.modifiedAt, modifiedAt) || other.modifiedAt == modifiedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,displayName,const DeepCollectionEquality().hash(phones),const DeepCollectionEquality().hash(emails),birthday,notes,source,externalId,isFavorite,createdAt,modifiedAt);

@override
String toString() {
  return 'Contact(id: $id, displayName: $displayName, phones: $phones, emails: $emails, birthday: $birthday, notes: $notes, source: $source, externalId: $externalId, isFavorite: $isFavorite, createdAt: $createdAt, modifiedAt: $modifiedAt)';
}


}

/// @nodoc
abstract mixin class $ContactCopyWith<$Res>  {
  factory $ContactCopyWith(Contact value, $Res Function(Contact) _then) = _$ContactCopyWithImpl;
@useResult
$Res call({
 String id, String displayName, List<String> phones, List<String> emails, String? birthday, String? notes, String source, String? externalId, bool isFavorite, DateTime createdAt, DateTime modifiedAt
});




}
/// @nodoc
class _$ContactCopyWithImpl<$Res>
    implements $ContactCopyWith<$Res> {
  _$ContactCopyWithImpl(this._self, this._then);

  final Contact _self;
  final $Res Function(Contact) _then;

/// Create a copy of Contact
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? displayName = null,Object? phones = null,Object? emails = null,Object? birthday = freezed,Object? notes = freezed,Object? source = null,Object? externalId = freezed,Object? isFavorite = null,Object? createdAt = null,Object? modifiedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,phones: null == phones ? _self.phones : phones // ignore: cast_nullable_to_non_nullable
as List<String>,emails: null == emails ? _self.emails : emails // ignore: cast_nullable_to_non_nullable
as List<String>,birthday: freezed == birthday ? _self.birthday : birthday // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,externalId: freezed == externalId ? _self.externalId : externalId // ignore: cast_nullable_to_non_nullable
as String?,isFavorite: null == isFavorite ? _self.isFavorite : isFavorite // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,modifiedAt: null == modifiedAt ? _self.modifiedAt : modifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [Contact].
extension ContactPatterns on Contact {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Contact value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Contact() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Contact value)  $default,){
final _that = this;
switch (_that) {
case _Contact():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Contact value)?  $default,){
final _that = this;
switch (_that) {
case _Contact() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String displayName,  List<String> phones,  List<String> emails,  String? birthday,  String? notes,  String source,  String? externalId,  bool isFavorite,  DateTime createdAt,  DateTime modifiedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Contact() when $default != null:
return $default(_that.id,_that.displayName,_that.phones,_that.emails,_that.birthday,_that.notes,_that.source,_that.externalId,_that.isFavorite,_that.createdAt,_that.modifiedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String displayName,  List<String> phones,  List<String> emails,  String? birthday,  String? notes,  String source,  String? externalId,  bool isFavorite,  DateTime createdAt,  DateTime modifiedAt)  $default,) {final _that = this;
switch (_that) {
case _Contact():
return $default(_that.id,_that.displayName,_that.phones,_that.emails,_that.birthday,_that.notes,_that.source,_that.externalId,_that.isFavorite,_that.createdAt,_that.modifiedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String displayName,  List<String> phones,  List<String> emails,  String? birthday,  String? notes,  String source,  String? externalId,  bool isFavorite,  DateTime createdAt,  DateTime modifiedAt)?  $default,) {final _that = this;
switch (_that) {
case _Contact() when $default != null:
return $default(_that.id,_that.displayName,_that.phones,_that.emails,_that.birthday,_that.notes,_that.source,_that.externalId,_that.isFavorite,_that.createdAt,_that.modifiedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Contact implements Contact {
  const _Contact({required this.id, required this.displayName, final  List<String> phones = const <String>[], final  List<String> emails = const <String>[], this.birthday, this.notes, this.source = ContactSource.manual, this.externalId, this.isFavorite = false, required this.createdAt, required this.modifiedAt}): _phones = phones,_emails = emails;
  factory _Contact.fromJson(Map<String, dynamic> json) => _$ContactFromJson(json);

@override final  String id;
@override final  String displayName;
 final  List<String> _phones;
@override@JsonKey() List<String> get phones {
  if (_phones is EqualUnmodifiableListView) return _phones;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_phones);
}

 final  List<String> _emails;
@override@JsonKey() List<String> get emails {
  if (_emails is EqualUnmodifiableListView) return _emails;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_emails);
}

/// `yyyy-MM-dd`, or `0004-MM-dd` when the year is unknown.
@override final  String? birthday;
@override final  String? notes;
@override@JsonKey() final  String source;
@override final  String? externalId;
@override@JsonKey() final  bool isFavorite;
@override final  DateTime createdAt;
@override final  DateTime modifiedAt;

/// Create a copy of Contact
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ContactCopyWith<_Contact> get copyWith => __$ContactCopyWithImpl<_Contact>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ContactToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Contact&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&const DeepCollectionEquality().equals(other._phones, _phones)&&const DeepCollectionEquality().equals(other._emails, _emails)&&(identical(other.birthday, birthday) || other.birthday == birthday)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.source, source) || other.source == source)&&(identical(other.externalId, externalId) || other.externalId == externalId)&&(identical(other.isFavorite, isFavorite) || other.isFavorite == isFavorite)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.modifiedAt, modifiedAt) || other.modifiedAt == modifiedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,displayName,const DeepCollectionEquality().hash(_phones),const DeepCollectionEquality().hash(_emails),birthday,notes,source,externalId,isFavorite,createdAt,modifiedAt);

@override
String toString() {
  return 'Contact(id: $id, displayName: $displayName, phones: $phones, emails: $emails, birthday: $birthday, notes: $notes, source: $source, externalId: $externalId, isFavorite: $isFavorite, createdAt: $createdAt, modifiedAt: $modifiedAt)';
}


}

/// @nodoc
abstract mixin class _$ContactCopyWith<$Res> implements $ContactCopyWith<$Res> {
  factory _$ContactCopyWith(_Contact value, $Res Function(_Contact) _then) = __$ContactCopyWithImpl;
@override @useResult
$Res call({
 String id, String displayName, List<String> phones, List<String> emails, String? birthday, String? notes, String source, String? externalId, bool isFavorite, DateTime createdAt, DateTime modifiedAt
});




}
/// @nodoc
class __$ContactCopyWithImpl<$Res>
    implements _$ContactCopyWith<$Res> {
  __$ContactCopyWithImpl(this._self, this._then);

  final _Contact _self;
  final $Res Function(_Contact) _then;

/// Create a copy of Contact
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? displayName = null,Object? phones = null,Object? emails = null,Object? birthday = freezed,Object? notes = freezed,Object? source = null,Object? externalId = freezed,Object? isFavorite = null,Object? createdAt = null,Object? modifiedAt = null,}) {
  return _then(_Contact(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,phones: null == phones ? _self._phones : phones // ignore: cast_nullable_to_non_nullable
as List<String>,emails: null == emails ? _self._emails : emails // ignore: cast_nullable_to_non_nullable
as List<String>,birthday: freezed == birthday ? _self.birthday : birthday // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,externalId: freezed == externalId ? _self.externalId : externalId // ignore: cast_nullable_to_non_nullable
as String?,isFavorite: null == isFavorite ? _self.isFavorite : isFavorite // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,modifiedAt: null == modifiedAt ? _self.modifiedAt : modifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
