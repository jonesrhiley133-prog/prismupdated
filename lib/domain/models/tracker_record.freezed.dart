// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tracker_record.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TrackerRecord {

 String get id; String get kind; String? get parentId; String get title; String? get body; String? get data; List<String> get tags; DateTime? get occurredAt; DateTime? get endedAt; int? get amount; String? get memberId; bool get isPrivate; bool get isPinned; int get sortOrder; DateTime get createdAt; DateTime get modifiedAt;
/// Create a copy of TrackerRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrackerRecordCopyWith<TrackerRecord> get copyWith => _$TrackerRecordCopyWithImpl<TrackerRecord>(this as TrackerRecord, _$identity);

  /// Serializes this TrackerRecord to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrackerRecord&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body)&&(identical(other.data, data) || other.data == data)&&const DeepCollectionEquality().equals(other.tags, tags)&&(identical(other.occurredAt, occurredAt) || other.occurredAt == occurredAt)&&(identical(other.endedAt, endedAt) || other.endedAt == endedAt)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.memberId, memberId) || other.memberId == memberId)&&(identical(other.isPrivate, isPrivate) || other.isPrivate == isPrivate)&&(identical(other.isPinned, isPinned) || other.isPinned == isPinned)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.modifiedAt, modifiedAt) || other.modifiedAt == modifiedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,kind,parentId,title,body,data,const DeepCollectionEquality().hash(tags),occurredAt,endedAt,amount,memberId,isPrivate,isPinned,sortOrder,createdAt,modifiedAt);

@override
String toString() {
  return 'TrackerRecord(id: $id, kind: $kind, parentId: $parentId, title: $title, body: $body, data: $data, tags: $tags, occurredAt: $occurredAt, endedAt: $endedAt, amount: $amount, memberId: $memberId, isPrivate: $isPrivate, isPinned: $isPinned, sortOrder: $sortOrder, createdAt: $createdAt, modifiedAt: $modifiedAt)';
}


}

/// @nodoc
abstract mixin class $TrackerRecordCopyWith<$Res>  {
  factory $TrackerRecordCopyWith(TrackerRecord value, $Res Function(TrackerRecord) _then) = _$TrackerRecordCopyWithImpl;
@useResult
$Res call({
 String id, String kind, String? parentId, String title, String? body, String? data, List<String> tags, DateTime? occurredAt, DateTime? endedAt, int? amount, String? memberId, bool isPrivate, bool isPinned, int sortOrder, DateTime createdAt, DateTime modifiedAt
});




}
/// @nodoc
class _$TrackerRecordCopyWithImpl<$Res>
    implements $TrackerRecordCopyWith<$Res> {
  _$TrackerRecordCopyWithImpl(this._self, this._then);

  final TrackerRecord _self;
  final $Res Function(TrackerRecord) _then;

/// Create a copy of TrackerRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? kind = null,Object? parentId = freezed,Object? title = null,Object? body = freezed,Object? data = freezed,Object? tags = null,Object? occurredAt = freezed,Object? endedAt = freezed,Object? amount = freezed,Object? memberId = freezed,Object? isPrivate = null,Object? isPinned = null,Object? sortOrder = null,Object? createdAt = null,Object? modifiedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,data: freezed == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as String?,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,occurredAt: freezed == occurredAt ? _self.occurredAt : occurredAt // ignore: cast_nullable_to_non_nullable
as DateTime?,endedAt: freezed == endedAt ? _self.endedAt : endedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,amount: freezed == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as int?,memberId: freezed == memberId ? _self.memberId : memberId // ignore: cast_nullable_to_non_nullable
as String?,isPrivate: null == isPrivate ? _self.isPrivate : isPrivate // ignore: cast_nullable_to_non_nullable
as bool,isPinned: null == isPinned ? _self.isPinned : isPinned // ignore: cast_nullable_to_non_nullable
as bool,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,modifiedAt: null == modifiedAt ? _self.modifiedAt : modifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [TrackerRecord].
extension TrackerRecordPatterns on TrackerRecord {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TrackerRecord value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TrackerRecord() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TrackerRecord value)  $default,){
final _that = this;
switch (_that) {
case _TrackerRecord():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TrackerRecord value)?  $default,){
final _that = this;
switch (_that) {
case _TrackerRecord() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String kind,  String? parentId,  String title,  String? body,  String? data,  List<String> tags,  DateTime? occurredAt,  DateTime? endedAt,  int? amount,  String? memberId,  bool isPrivate,  bool isPinned,  int sortOrder,  DateTime createdAt,  DateTime modifiedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TrackerRecord() when $default != null:
return $default(_that.id,_that.kind,_that.parentId,_that.title,_that.body,_that.data,_that.tags,_that.occurredAt,_that.endedAt,_that.amount,_that.memberId,_that.isPrivate,_that.isPinned,_that.sortOrder,_that.createdAt,_that.modifiedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String kind,  String? parentId,  String title,  String? body,  String? data,  List<String> tags,  DateTime? occurredAt,  DateTime? endedAt,  int? amount,  String? memberId,  bool isPrivate,  bool isPinned,  int sortOrder,  DateTime createdAt,  DateTime modifiedAt)  $default,) {final _that = this;
switch (_that) {
case _TrackerRecord():
return $default(_that.id,_that.kind,_that.parentId,_that.title,_that.body,_that.data,_that.tags,_that.occurredAt,_that.endedAt,_that.amount,_that.memberId,_that.isPrivate,_that.isPinned,_that.sortOrder,_that.createdAt,_that.modifiedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String kind,  String? parentId,  String title,  String? body,  String? data,  List<String> tags,  DateTime? occurredAt,  DateTime? endedAt,  int? amount,  String? memberId,  bool isPrivate,  bool isPinned,  int sortOrder,  DateTime createdAt,  DateTime modifiedAt)?  $default,) {final _that = this;
switch (_that) {
case _TrackerRecord() when $default != null:
return $default(_that.id,_that.kind,_that.parentId,_that.title,_that.body,_that.data,_that.tags,_that.occurredAt,_that.endedAt,_that.amount,_that.memberId,_that.isPrivate,_that.isPinned,_that.sortOrder,_that.createdAt,_that.modifiedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TrackerRecord extends TrackerRecord {
  const _TrackerRecord({required this.id, required this.kind, this.parentId, this.title = '', this.body, this.data, final  List<String> tags = const <String>[], this.occurredAt, this.endedAt, this.amount, this.memberId, this.isPrivate = false, this.isPinned = false, this.sortOrder = 0, required this.createdAt, required this.modifiedAt}): _tags = tags,super._();
  factory _TrackerRecord.fromJson(Map<String, dynamic> json) => _$TrackerRecordFromJson(json);

@override final  String id;
@override final  String kind;
@override final  String? parentId;
@override@JsonKey() final  String title;
@override final  String? body;
@override final  String? data;
 final  List<String> _tags;
@override@JsonKey() List<String> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

@override final  DateTime? occurredAt;
@override final  DateTime? endedAt;
@override final  int? amount;
@override final  String? memberId;
@override@JsonKey() final  bool isPrivate;
@override@JsonKey() final  bool isPinned;
@override@JsonKey() final  int sortOrder;
@override final  DateTime createdAt;
@override final  DateTime modifiedAt;

/// Create a copy of TrackerRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TrackerRecordCopyWith<_TrackerRecord> get copyWith => __$TrackerRecordCopyWithImpl<_TrackerRecord>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TrackerRecordToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TrackerRecord&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body)&&(identical(other.data, data) || other.data == data)&&const DeepCollectionEquality().equals(other._tags, _tags)&&(identical(other.occurredAt, occurredAt) || other.occurredAt == occurredAt)&&(identical(other.endedAt, endedAt) || other.endedAt == endedAt)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.memberId, memberId) || other.memberId == memberId)&&(identical(other.isPrivate, isPrivate) || other.isPrivate == isPrivate)&&(identical(other.isPinned, isPinned) || other.isPinned == isPinned)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.modifiedAt, modifiedAt) || other.modifiedAt == modifiedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,kind,parentId,title,body,data,const DeepCollectionEquality().hash(_tags),occurredAt,endedAt,amount,memberId,isPrivate,isPinned,sortOrder,createdAt,modifiedAt);

@override
String toString() {
  return 'TrackerRecord(id: $id, kind: $kind, parentId: $parentId, title: $title, body: $body, data: $data, tags: $tags, occurredAt: $occurredAt, endedAt: $endedAt, amount: $amount, memberId: $memberId, isPrivate: $isPrivate, isPinned: $isPinned, sortOrder: $sortOrder, createdAt: $createdAt, modifiedAt: $modifiedAt)';
}


}

/// @nodoc
abstract mixin class _$TrackerRecordCopyWith<$Res> implements $TrackerRecordCopyWith<$Res> {
  factory _$TrackerRecordCopyWith(_TrackerRecord value, $Res Function(_TrackerRecord) _then) = __$TrackerRecordCopyWithImpl;
@override @useResult
$Res call({
 String id, String kind, String? parentId, String title, String? body, String? data, List<String> tags, DateTime? occurredAt, DateTime? endedAt, int? amount, String? memberId, bool isPrivate, bool isPinned, int sortOrder, DateTime createdAt, DateTime modifiedAt
});




}
/// @nodoc
class __$TrackerRecordCopyWithImpl<$Res>
    implements _$TrackerRecordCopyWith<$Res> {
  __$TrackerRecordCopyWithImpl(this._self, this._then);

  final _TrackerRecord _self;
  final $Res Function(_TrackerRecord) _then;

/// Create a copy of TrackerRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? kind = null,Object? parentId = freezed,Object? title = null,Object? body = freezed,Object? data = freezed,Object? tags = null,Object? occurredAt = freezed,Object? endedAt = freezed,Object? amount = freezed,Object? memberId = freezed,Object? isPrivate = null,Object? isPinned = null,Object? sortOrder = null,Object? createdAt = null,Object? modifiedAt = null,}) {
  return _then(_TrackerRecord(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,data: freezed == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as String?,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,occurredAt: freezed == occurredAt ? _self.occurredAt : occurredAt // ignore: cast_nullable_to_non_nullable
as DateTime?,endedAt: freezed == endedAt ? _self.endedAt : endedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,amount: freezed == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as int?,memberId: freezed == memberId ? _self.memberId : memberId // ignore: cast_nullable_to_non_nullable
as String?,isPrivate: null == isPrivate ? _self.isPrivate : isPrivate // ignore: cast_nullable_to_non_nullable
as bool,isPinned: null == isPinned ? _self.isPinned : isPinned // ignore: cast_nullable_to_non_nullable
as bool,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,modifiedAt: null == modifiedAt ? _self.modifiedAt : modifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
