// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'scripture_ref.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ScriptureRef {

 String? get bookId; int? get chapterNumber; int? get verseNumber;
/// Create a copy of ScriptureRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScriptureRefCopyWith<ScriptureRef> get copyWith => _$ScriptureRefCopyWithImpl<ScriptureRef>(this as ScriptureRef, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScriptureRef&&(identical(other.bookId, bookId) || other.bookId == bookId)&&(identical(other.chapterNumber, chapterNumber) || other.chapterNumber == chapterNumber)&&(identical(other.verseNumber, verseNumber) || other.verseNumber == verseNumber));
}


@override
int get hashCode => Object.hash(runtimeType,bookId,chapterNumber,verseNumber);



}

/// @nodoc
abstract mixin class $ScriptureRefCopyWith<$Res>  {
  factory $ScriptureRefCopyWith(ScriptureRef value, $Res Function(ScriptureRef) _then) = _$ScriptureRefCopyWithImpl;
@useResult
$Res call({
 String? bookId, int? chapterNumber, int? verseNumber
});




}
/// @nodoc
class _$ScriptureRefCopyWithImpl<$Res>
    implements $ScriptureRefCopyWith<$Res> {
  _$ScriptureRefCopyWithImpl(this._self, this._then);

  final ScriptureRef _self;
  final $Res Function(ScriptureRef) _then;

/// Create a copy of ScriptureRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? bookId = freezed,Object? chapterNumber = freezed,Object? verseNumber = freezed,}) {
  return _then(_self.copyWith(
bookId: freezed == bookId ? _self.bookId : bookId // ignore: cast_nullable_to_non_nullable
as String?,chapterNumber: freezed == chapterNumber ? _self.chapterNumber : chapterNumber // ignore: cast_nullable_to_non_nullable
as int?,verseNumber: freezed == verseNumber ? _self.verseNumber : verseNumber // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [ScriptureRef].
extension ScriptureRefPatterns on ScriptureRef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ScriptureRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ScriptureRef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ScriptureRef value)  $default,){
final _that = this;
switch (_that) {
case _ScriptureRef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ScriptureRef value)?  $default,){
final _that = this;
switch (_that) {
case _ScriptureRef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? bookId,  int? chapterNumber,  int? verseNumber)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ScriptureRef() when $default != null:
return $default(_that.bookId,_that.chapterNumber,_that.verseNumber);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? bookId,  int? chapterNumber,  int? verseNumber)  $default,) {final _that = this;
switch (_that) {
case _ScriptureRef():
return $default(_that.bookId,_that.chapterNumber,_that.verseNumber);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? bookId,  int? chapterNumber,  int? verseNumber)?  $default,) {final _that = this;
switch (_that) {
case _ScriptureRef() when $default != null:
return $default(_that.bookId,_that.chapterNumber,_that.verseNumber);case _:
  return null;

}
}

}

/// @nodoc


class _ScriptureRef extends ScriptureRef {
  const _ScriptureRef({this.bookId, this.chapterNumber, this.verseNumber}): super._();
  

@override final  String? bookId;
@override final  int? chapterNumber;
@override final  int? verseNumber;

/// Create a copy of ScriptureRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScriptureRefCopyWith<_ScriptureRef> get copyWith => __$ScriptureRefCopyWithImpl<_ScriptureRef>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScriptureRef&&(identical(other.bookId, bookId) || other.bookId == bookId)&&(identical(other.chapterNumber, chapterNumber) || other.chapterNumber == chapterNumber)&&(identical(other.verseNumber, verseNumber) || other.verseNumber == verseNumber));
}


@override
int get hashCode => Object.hash(runtimeType,bookId,chapterNumber,verseNumber);



}

/// @nodoc
abstract mixin class _$ScriptureRefCopyWith<$Res> implements $ScriptureRefCopyWith<$Res> {
  factory _$ScriptureRefCopyWith(_ScriptureRef value, $Res Function(_ScriptureRef) _then) = __$ScriptureRefCopyWithImpl;
@override @useResult
$Res call({
 String? bookId, int? chapterNumber, int? verseNumber
});




}
/// @nodoc
class __$ScriptureRefCopyWithImpl<$Res>
    implements _$ScriptureRefCopyWith<$Res> {
  __$ScriptureRefCopyWithImpl(this._self, this._then);

  final _ScriptureRef _self;
  final $Res Function(_ScriptureRef) _then;

/// Create a copy of ScriptureRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? bookId = freezed,Object? chapterNumber = freezed,Object? verseNumber = freezed,}) {
  return _then(_ScriptureRef(
bookId: freezed == bookId ? _self.bookId : bookId // ignore: cast_nullable_to_non_nullable
as String?,chapterNumber: freezed == chapterNumber ? _self.chapterNumber : chapterNumber // ignore: cast_nullable_to_non_nullable
as int?,verseNumber: freezed == verseNumber ? _self.verseNumber : verseNumber // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
