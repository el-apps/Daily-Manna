import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';

class RecitationInput {
  const RecitationInput({
    required this.id,
    required this.label,
    required this.bluetooth,
  });

  static const phone = RecitationInput(
    id: 'phone',
    label: 'Phone microphone',
    bluetooth: false,
  );

  final String id;
  final String label;
  final bool bluetooth;

  String get displayName => bluetooth
      ? label.replaceFirst(RegExp(r'^Bluetooth(?: LE)? microphone · '), '')
      : 'Phone mic';
}

/// Owns Android routing independently of the foreground notification.
class RecitationAudioInput {
  static const _channel = MethodChannel('daily_manna/recitation_input');
  static RecitationAudioInput? _owner;

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<List<RecitationInput>> list() async {
    if (!isSupported) return const [];
    final inputs = await _channel.invokeListMethod<dynamic>('list') ?? [];
    return inputs.map((input) {
      final map = input as Map;
      return RecitationInput(
        id: map['id'] as String,
        label: map['label'] as String,
        bluetooth: map['bluetooth'] as bool,
      );
    }).toList();
  }

  Future<InputDevice?> prepare(
    RecitationInput input, {
    required Future<void> Function(String message) onLost,
  }) async {
    if (!isSupported) return null;
    if (_owner != null) {
      throw StateError('The previous microphone session is still closing.');
    }
    _owner = this;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'inputLost') {
        throw MissingPluginException('Unknown microphone action');
      }
      await onLost(call.arguments as String);
    });
    try {
      final device = await _channel.invokeMapMethod<String, dynamic>(
        'prepare',
        {'id': input.id},
      );
      if (device == null) throw StateError('Microphone unavailable');
      return InputDevice.fromMap(device);
    } catch (_) {
      await release();
      rethrow;
    }
  }

  Future<void> verify() async {
    if (!isSupported) return;
    if (_owner != this) throw StateError('Microphone session unavailable');
    await _channel.invokeMethod<void>('verify');
  }

  Future<void> release() async {
    if (!isSupported || _owner != this) return;
    try {
      await _channel.invokeMethod<void>('release');
    } finally {
      _channel.setMethodCallHandler(null);
      _owner = null;
    }
  }
}
