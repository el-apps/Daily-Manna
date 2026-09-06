import 'dart:io';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

Future<String> recordingPath() async {
  final tempDir = await getTemporaryDirectory();
  return '${tempDir.path}/recitation_${DateTime.now().millisecondsSinceEpoch}.wav';
}

Future<Uint8List> readRecordingBytes(String path) => File(path).readAsBytes();

Future<void> deleteRecording(String path) async {
  await File(path).delete();
}

Future<AudioSource> createRecordingAudioSource(String path) async =>
    AudioSource.file(path);
