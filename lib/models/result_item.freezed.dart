// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'result_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ResultItem {

 double get score; String get reference; int get attempts; String? get notes;
/// Create a copy of ResultItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ResultItemCopyWith<ResultItem> get copyWith => _$ResultItemCopyWithImpl<ResultItem>(this as ResultItem, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ResultItem&&(identical(other.score, score) || other.score == score)&&(identical(other.reference, reference) || other.reference == reference)&&(identical(other.attempts, attempts) || other.attempts == attempts)&&(identical(other.notes, notes) || other.notes == notes));
}


@override
int get hashCode => Object.hash(runtimeType,score,reference,attempts,notes);

@override
String toString() {
  return 'ResultItem(score: $score, reference: $reference, attempts: $attempts, notes: $notes)';
}


}

/// @nodoc
abstract mixin class $ResultItemCopyWith<$Res>  {
  factory $ResultItemCopyWith(ResultItem value, $Res Function(ResultItem) _then) = _$ResultItemCopyWithImpl;
@useResult
$Res call({
 double score, String reference, int attempts, String? notes
});




}
/// @nodoc
class _$ResultItemCopyWithImpl<$Res>
    implements $ResultItemCopyWith<$Res> {
  _$ResultItemCopyWithImpl(this._self, this._then);

  final ResultItem _self;
  final $Res Function(ResultItem) _then;

/// Create a copy of ResultItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? score = null,Object? reference = null,Object? attempts = null,Object? notes = freezed,}) {
  return _then(_self.copyWith(
score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as double,reference: null == reference ? _self.reference : reference // ignore: cast_nullable_to_non_nullable
as String,attempts: null == attempts ? _self.attempts : attempts // ignore: cast_nullable_to_non_nullable
as int,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ResultItem].
extension ResultItemPatterns on ResultItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ResultItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ResultItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ResultItem value)  $default,){
final _that = this;
switch (_that) {
case _ResultItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ResultItem value)?  $default,){
final _that = this;
switch (_that) {
case _ResultItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double score,  String reference,  int attempts,  String? notes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ResultItem() when $default != null:
return $default(_that.score,_that.reference,_that.attempts,_that.notes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double score,  String reference,  int attempts,  String? notes)  $default,) {final _that = this;
switch (_that) {
case _ResultItem():
return $default(_that.score,_that.reference,_that.attempts,_that.notes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double score,  String reference,  int attempts,  String? notes)?  $default,) {final _that = this;
switch (_that) {
case _ResultItem() when $default != null:
return $default(_that.score,_that.reference,_that.attempts,_that.notes);case _:
  return null;

}
}

}

/// @nodoc


class _ResultItem implements ResultItem {
  const _ResultItem({required this.score, required this.reference, this.attempts = 1, this.notes});
  

@override final  double score;
@override final  String reference;
@override@JsonKey() final  int attempts;
@override final  String? notes;

/// Create a copy of ResultItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ResultItemCopyWith<_ResultItem> get copyWith => __$ResultItemCopyWithImpl<_ResultItem>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ResultItem&&(identical(other.score, score) || other.score == score)&&(identical(other.reference, reference) || other.reference == reference)&&(identical(other.attempts, attempts) || other.attempts == attempts)&&(identical(other.notes, notes) || other.notes == notes));
}


@override
int get hashCode => Object.hash(runtimeType,score,reference,attempts,notes);

@override
String toString() {
  return 'ResultItem(score: $score, reference: $reference, attempts: $attempts, notes: $notes)';
}


}

/// @nodoc
abstract mixin class _$ResultItemCopyWith<$Res> implements $ResultItemCopyWith<$Res> {
  factory _$ResultItemCopyWith(_ResultItem value, $Res Function(_ResultItem) _then) = __$ResultItemCopyWithImpl;
@override @useResult
$Res call({
 double score, String reference, int attempts, String? notes
});




}
/// @nodoc
class __$ResultItemCopyWithImpl<$Res>
    implements _$ResultItemCopyWith<$Res> {
  __$ResultItemCopyWithImpl(this._self, this._then);

  final _ResultItem _self;
  final $Res Function(_ResultItem) _then;

/// Create a copy of ResultItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? score = null,Object? reference = null,Object? attempts = null,Object? notes = freezed,}) {
  return _then(_ResultItem(
score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as double,reference: null == reference ? _self.reference : reference // ignore: cast_nullable_to_non_nullable
as String,attempts: null == attempts ? _self.attempts : attempts // ignore: cast_nullable_to_non_nullable
as int,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
