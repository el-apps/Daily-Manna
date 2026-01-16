// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'scripture_range_ref.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ScriptureRangeRef {

 String get bookId; int get startChapter; int get startVerse; int? get endChapter; int? get endVerse;
/// Create a copy of ScriptureRangeRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScriptureRangeRefCopyWith<ScriptureRangeRef> get copyWith => _$ScriptureRangeRefCopyWithImpl<ScriptureRangeRef>(this as ScriptureRangeRef, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScriptureRangeRef&&(identical(other.bookId, bookId) || other.bookId == bookId)&&(identical(other.startChapter, startChapter) || other.startChapter == startChapter)&&(identical(other.startVerse, startVerse) || other.startVerse == startVerse)&&(identical(other.endChapter, endChapter) || other.endChapter == endChapter)&&(identical(other.endVerse, endVerse) || other.endVerse == endVerse));
}


@override
int get hashCode => Object.hash(runtimeType,bookId,startChapter,startVerse,endChapter,endVerse);

@override
String toString() {
  return 'ScriptureRangeRef(bookId: $bookId, startChapter: $startChapter, startVerse: $startVerse, endChapter: $endChapter, endVerse: $endVerse)';
}


}

/// @nodoc
abstract mixin class $ScriptureRangeRefCopyWith<$Res>  {
  factory $ScriptureRangeRefCopyWith(ScriptureRangeRef value, $Res Function(ScriptureRangeRef) _then) = _$ScriptureRangeRefCopyWithImpl;
@useResult
$Res call({
 String bookId, int startChapter, int startVerse, int? endChapter, int? endVerse
});




}
/// @nodoc
class _$ScriptureRangeRefCopyWithImpl<$Res>
    implements $ScriptureRangeRefCopyWith<$Res> {
  _$ScriptureRangeRefCopyWithImpl(this._self, this._then);

  final ScriptureRangeRef _self;
  final $Res Function(ScriptureRangeRef) _then;

/// Create a copy of ScriptureRangeRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? bookId = null,Object? startChapter = null,Object? startVerse = null,Object? endChapter = freezed,Object? endVerse = freezed,}) {
  return _then(_self.copyWith(
bookId: null == bookId ? _self.bookId : bookId // ignore: cast_nullable_to_non_nullable
as String,startChapter: null == startChapter ? _self.startChapter : startChapter // ignore: cast_nullable_to_non_nullable
as int,startVerse: null == startVerse ? _self.startVerse : startVerse // ignore: cast_nullable_to_non_nullable
as int,endChapter: freezed == endChapter ? _self.endChapter : endChapter // ignore: cast_nullable_to_non_nullable
as int?,endVerse: freezed == endVerse ? _self.endVerse : endVerse // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [ScriptureRangeRef].
extension ScriptureRangeRefPatterns on ScriptureRangeRef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ScriptureRangeRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ScriptureRangeRef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ScriptureRangeRef value)  $default,){
final _that = this;
switch (_that) {
case _ScriptureRangeRef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ScriptureRangeRef value)?  $default,){
final _that = this;
switch (_that) {
case _ScriptureRangeRef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String bookId,  int startChapter,  int startVerse,  int? endChapter,  int? endVerse)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ScriptureRangeRef() when $default != null:
return $default(_that.bookId,_that.startChapter,_that.startVerse,_that.endChapter,_that.endVerse);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String bookId,  int startChapter,  int startVerse,  int? endChapter,  int? endVerse)  $default,) {final _that = this;
switch (_that) {
case _ScriptureRangeRef():
return $default(_that.bookId,_that.startChapter,_that.startVerse,_that.endChapter,_that.endVerse);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String bookId,  int startChapter,  int startVerse,  int? endChapter,  int? endVerse)?  $default,) {final _that = this;
switch (_that) {
case _ScriptureRangeRef() when $default != null:
return $default(_that.bookId,_that.startChapter,_that.startVerse,_that.endChapter,_that.endVerse);case _:
  return null;

}
}

}

/// @nodoc


class _ScriptureRangeRef extends ScriptureRangeRef {
  const _ScriptureRangeRef({required this.bookId, required this.startChapter, required this.startVerse, this.endChapter, this.endVerse}): super._();
  

@override final  String bookId;
@override final  int startChapter;
@override final  int startVerse;
@override final  int? endChapter;
@override final  int? endVerse;

/// Create a copy of ScriptureRangeRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScriptureRangeRefCopyWith<_ScriptureRangeRef> get copyWith => __$ScriptureRangeRefCopyWithImpl<_ScriptureRangeRef>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScriptureRangeRef&&(identical(other.bookId, bookId) || other.bookId == bookId)&&(identical(other.startChapter, startChapter) || other.startChapter == startChapter)&&(identical(other.startVerse, startVerse) || other.startVerse == startVerse)&&(identical(other.endChapter, endChapter) || other.endChapter == endChapter)&&(identical(other.endVerse, endVerse) || other.endVerse == endVerse));
}


@override
int get hashCode => Object.hash(runtimeType,bookId,startChapter,startVerse,endChapter,endVerse);

@override
String toString() {
  return 'ScriptureRangeRef(bookId: $bookId, startChapter: $startChapter, startVerse: $startVerse, endChapter: $endChapter, endVerse: $endVerse)';
}


}

/// @nodoc
abstract mixin class _$ScriptureRangeRefCopyWith<$Res> implements $ScriptureRangeRefCopyWith<$Res> {
  factory _$ScriptureRangeRefCopyWith(_ScriptureRangeRef value, $Res Function(_ScriptureRangeRef) _then) = __$ScriptureRangeRefCopyWithImpl;
@override @useResult
$Res call({
 String bookId, int startChapter, int startVerse, int? endChapter, int? endVerse
});




}
/// @nodoc
class __$ScriptureRangeRefCopyWithImpl<$Res>
    implements _$ScriptureRangeRefCopyWith<$Res> {
  __$ScriptureRangeRefCopyWithImpl(this._self, this._then);

  final _ScriptureRangeRef _self;
  final $Res Function(_ScriptureRangeRef) _then;

/// Create a copy of ScriptureRangeRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? bookId = null,Object? startChapter = null,Object? startVerse = null,Object? endChapter = freezed,Object? endVerse = freezed,}) {
  return _then(_ScriptureRangeRef(
bookId: null == bookId ? _self.bookId : bookId // ignore: cast_nullable_to_non_nullable
as String,startChapter: null == startChapter ? _self.startChapter : startChapter // ignore: cast_nullable_to_non_nullable
as int,startVerse: null == startVerse ? _self.startVerse : startVerse // ignore: cast_nullable_to_non_nullable
as int,endChapter: freezed == endChapter ? _self.endChapter : endChapter // ignore: cast_nullable_to_non_nullable
as int?,endVerse: freezed == endVerse ? _self.endVerse : endVerse // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
