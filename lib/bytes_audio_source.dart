import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';

Future<AudioSource> createBytesAudioSource(List<int> bytes) async {
  final tempDir = await getTemporaryDirectory();
  final tempFile = File(
    '${tempDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav',
  );
  await tempFile.writeAsBytes(bytes);
  return AudioSource.file(tempFile.path);
}
