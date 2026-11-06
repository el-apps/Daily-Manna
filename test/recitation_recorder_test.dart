import 'dart:async';

import 'package:daily_manna/services/recitation_call_service.dart';
import 'package:daily_manna/services/recitation_recorder.dart';
import 'package:daily_manna/ui/recitation/recording_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late _Recorder audio;
  late _CallService calls;
  late RecitationRecorder recorder;

  setUp(() {
    audio = _Recorder();
    calls = _CallService();
    recorder = RecitationRecorder(
      recorder: audio,
      callService: calls,
      pathProvider: () async => '/recording.wav',
    );
  });

  tearDown(() async {
    await recorder.close();
    recorder.dispose();
    await audio.events.close();
  });

  test(
    'screen and notification share mute state and hang up saves audio',
    () async {
      await recorder.start();
      audio.speak('In the beginning');
      await calls.onToggleMute();
      expect(recorder.isMuted, isTrue);
      expect(calls.muted, isTrue);
      audio.speak('not part of the recitation');
      await recorder.toggleMute();
      audio.speak('God created');
      expect(recorder.isMuted, isFalse);
      expect(calls.muted, isFalse);

      await calls.onHangUp();
      expect(recorder.state, RecitationRecordingState.saved);
      expect(recorder.path, '/recording.wav');
      expect(audio.saved, ['In the beginning', 'God created']);
      expect(audio.active, isFalse);
      expect(calls.visible, isFalse);
      expect(recorder.error, isNull);
    },
  );

  test(
    'hang up while muted and duplicate stop preserve the same recording',
    () async {
      await recorder.start();
      audio.speak('The Lord is my shepherd');
      await recorder.toggleMute();
      await Future.wait([calls.onHangUp(), recorder.stop()]);
      expect(recorder.path, '/recording.wav');
      expect(audio.saved, ['The Lord is my shepherd']);
      expect(recorder.state, RecitationRecordingState.saved);
      expect(calls.visible, isFalse);
    },
  );

  test(
    'failed permissions or foreground startup never leave capture running',
    () async {
      audio.permission = Future.value(false);
      await recorder.start();
      expect(recorder.error, contains('Microphone permission denied'));
      expect(audio.active, isFalse);
      expect(calls.visible, isFalse);

      audio.permission = Future.value(true);
      calls.startError = StateError('Notifications disabled');
      await recorder.start();
      expect(recorder.error, contains('Notifications disabled'));
      expect(recorder.state, RecitationRecordingState.idle);
      expect(audio.active, isFalse);
      expect(calls.visible, isFalse);

      calls.startError = null;
      audio.startError = StateError('Microphone unavailable');
      await recorder.start();
      expect(recorder.error, contains('Microphone unavailable'));
      expect(calls.visible, isFalse);
    },
  );

  test(
    'leaving during permission request cannot start a late recording',
    () async {
      final permission = Completer<bool>();
      audio.permission = permission.future;
      final starting = recorder.start();
      await Future<void>.delayed(Duration.zero);
      expect(recorder.state, RecitationRecordingState.starting);
      final closing = recorder.close();
      permission.complete(true);
      await Future.wait([starting, closing]);
      expect(audio.active, isFalse);
      expect(audio.disposed, isTrue);
      expect(calls.visible, isFalse);
      expect(recorder.path, isNull);
    },
  );

  test(
    'audio interruptions update both controls without automatic unmute',
    () async {
      await recorder.start();
      final muted = Completer<void>();
      recorder.addListener(() {
        if (recorder.isMuted && !muted.isCompleted) muted.complete();
      });
      audio.paused = true;
      audio.events.add(RecordState.pause);
      await muted.future;
      expect(calls.muted, isTrue);
      expect(audio.paused, isTrue);
      await recorder.toggleMute();
      expect(audio.paused, isFalse);
    },
  );

  test(
    'failed notification update stops capture but preserves review audio',
    () async {
      await recorder.start();
      audio.speak('Jesus wept');
      calls.updateError = StateError('Service unavailable');
      await recorder.toggleMute();
      expect(audio.active, isFalse);
      expect(calls.visible, isFalse);
      expect(recorder.path, '/recording.wav');
      expect(audio.saved, ['Jesus wept']);
      expect(recorder.error, contains('Service unavailable'));
    },
  );

  test('asynchronous recorder errors release background controls', () async {
    await recorder.start();
    final failed = Completer<void>();
    recorder.addListener(() {
      if (recorder.error != null && !failed.isCompleted) failed.complete();
    });
    audio.events.addError(StateError('Microphone disconnected'));
    await failed.future;
    expect(recorder.error, contains('Microphone disconnected'));
    expect(audio.active, isFalse);
    expect(calls.visible, isFalse);
  });

  test(
    'native actions reach the owner and stale cleanup cannot stop a new call',
    () async {
      const channel = MethodChannel('daily_manna/recitation_call');
      const notifications = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      var visible = false;
      var muted = false;
      final first = RecitationCallService();
      final second = RecitationCallService();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        notifications,
        (_) async => true,
      );
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        switch (call.method) {
          case 'start':
            visible = true;
          case 'update':
            muted = (call.arguments as Map)['muted'] as bool;
          case 'stop':
            visible = false;
        }
        return null;
      });
      Future<void> action(String method) async {
        final response = Completer<void>();
        await binding.defaultBinaryMessenger.handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(MethodCall(method)),
          (data) {
            try {
              const StandardMethodCodec().decodeEnvelope(data!);
              response.complete();
            } catch (error, stack) {
              response.completeError(error, stack);
            }
          },
        );
        await response.future;
      }

      try {
        await first.start(
          onToggleMute: () => first.update(muted: true),
          onHangUp: first.stop,
        );
        await action('toggleMute');
        expect(muted, isTrue);
        await expectLater(
          second.start(onToggleMute: () async {}, onHangUp: () async {}),
          throwsStateError,
        );
        await second.stop();
        expect(visible, isTrue);
        await action('hangUp');
        expect(visible, isFalse);
        await second.start(
          onToggleMute: () => second.update(muted: false),
          onHangUp: second.stop,
        );
        await first.stop();
        expect(visible, isTrue);
        await action('toggleMute');
        expect(muted, isFalse);
        await action('hangUp');
        expect(visible, isFalse);
      } finally {
        await first.stop();
        await second.stop();
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
        binding.defaultBinaryMessenger.setMockMethodCallHandler(
          notifications,
          null,
        );
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'recording card exposes mute, unmute, and disabled busy controls',
    (tester) async {
      Widget card(RecordingState state, {bool busy = false}) => MaterialApp(
        home: Scaffold(
          body: RecordingCard(
            state: state,
            isBusy: busy,
            onToggle: () {},
            onToggleMute: () {},
          ),
        ),
      );

      await tester.pumpWidget(card(RecordingState.idle));
      expect(find.text('Start Recording'), findsOneWidget);
      expect(find.text('Mute'), findsNothing);
      await tester.pumpWidget(card(RecordingState.recording));
      expect(find.text('Mute'), findsOneWidget);
      expect(find.text('Stop Recording'), findsOneWidget);
      await tester.pumpWidget(card(RecordingState.muted, busy: true));
      expect(find.text('Recording paused'), findsOneWidget);
      expect(find.text('Unmute'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byWidgetPredicate((widget) => widget is OutlinedButton),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byWidgetPredicate((widget) => widget is FilledButton),
            )
            .onPressed,
        isNull,
      );
    },
  );
}

class _Recorder implements AudioRecorder {
  final events = StreamController<RecordState>.broadcast();
  Future<bool> permission = Future.value(true);
  Object? startError;
  bool active = false;
  bool paused = false;
  bool disposed = false;
  List<String> captured = [];
  List<String>? saved;

  void speak(String words) {
    if (active && !paused) captured.add(words);
  }

  @override
  Future<bool> hasPermission() => permission;
  @override
  Stream<RecordState> onStateChanged() => events.stream;
  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    if (startError != null) throw startError!;
    active = true;
    paused = false;
    captured = [];
  }

  @override
  Future<void> pause() async => paused = true;
  @override
  Future<void> resume() async => paused = false;
  @override
  Future<bool> isRecording() async => active;
  @override
  Future<bool> isPaused() async => paused;
  @override
  Future<String?> stop() async {
    if (!active) return null;
    active = false;
    saved = List.of(captured);
    return '/recording.wav';
  }

  @override
  Future<void> cancel() async {
    active = false;
    captured.clear();
  }

  @override
  Future<void> dispose() async {
    active = false;
    disposed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CallService implements RecitationCallService {
  late AsyncCallback onToggleMute;
  late AsyncCallback onHangUp;
  bool visible = false;
  bool muted = false;
  Object? startError;
  Object? updateError;

  @override
  bool get isSupported => true;
  @override
  Future<void> start({
    required AsyncCallback onToggleMute,
    required AsyncCallback onHangUp,
  }) async {
    if (startError != null) throw startError!;
    this.onToggleMute = onToggleMute;
    this.onHangUp = onHangUp;
    visible = true;
  }

  @override
  Future<void> update({required bool muted}) async {
    if (updateError != null) throw updateError!;
    this.muted = muted;
  }

  @override
  Future<void> stop() async => visible = false;
}
