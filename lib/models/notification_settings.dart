import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_settings.freezed.dart';

@freezed
abstract class NotificationSettings with _$NotificationSettings {
  const factory NotificationSettings({
    required bool enabled,
    required TimeOfDay time,
  }) = _NotificationSettings;
  
  factory NotificationSettings.defaults() => const NotificationSettings(
    enabled: true,
    time: TimeOfDay(hour: 6, minute: 0),
  );
}
