import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

Future<String> recordingPath() async => '';

Future<Uint8List> readRecordingBytes(String path) async {
  final response = await http.get(Uri.parse(path));
  if (response.statusCode != 200) {
    throw Exception('Unable to read recording (${response.statusCode})');
  }
  return response.bodyBytes;
}

Future<void> deleteRecording(String path) async {
  // The record web plugin owns the blob URL and releases it when recording
  // stops. There is no filesystem entry to remove in the browser.
}

Future<AudioSource> createRecordingAudioSource(String path) async =>
    AudioSource.uri(Uri.parse(path));
