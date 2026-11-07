import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Android owns the ongoing notification, not the recorder or its audio session.
class RecitationCallService {
  static const _channel = MethodChannel('daily_manna/recitation_call');
  static RecitationCallService? _owner;

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> start({
    required AsyncCallback onToggleMute,
    required AsyncCallback onHangUp,
  }) async {
    if (!isSupported) return;
    if (_owner != null) {
      throw StateError('The previous recitation is still closing. Try again.');
    }
    _owner = this;

    try {
      final notifications = FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (await notifications?.requestNotificationsPermission() != true) {
        throw StateError(
          'Allow notifications in Android Settings to use recitation controls.',
        );
      }

      _channel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'toggleMute':
            await onToggleMute();
          case 'hangUp':
            await onHangUp();
          default:
            throw MissingPluginException('Unknown recitation action');
        }
      });
      await _channel.invokeMethod<void>('start');
    } catch (_) {
      _channel.setMethodCallHandler(null);
      _owner = null;
      rethrow;
    }
  }

  Future<void> update({required bool muted}) async {
    if (!isSupported) return;
    if (_owner != this) throw StateError('Recitation controls are unavailable');
    await _channel.invokeMethod<void>('update', {'muted': muted});
  }

  Future<void> stop() async {
    // A disposed screen must not remove a newer screen's controls/handler.
    if (!isSupported || _owner != this) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } finally {
      _channel.setMethodCallHandler(null);
      _owner = null;
    }
  }
}
