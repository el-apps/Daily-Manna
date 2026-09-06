import 'recording_platform_io.dart'
    if (dart.library.html) 'recording_platform_web.dart'
    as platform;

import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';

Future<Uint8List> readRecordingBytes(String path) =>
    platform.readRecordingBytes(path);

Future<String> recordingPath() => platform.recordingPath();

Future<void> deleteRecording(String path) => platform.deleteRecording(path);

Future<AudioSource> createRecordingAudioSource(String path) =>
    platform.createRecordingAudioSource(path);
