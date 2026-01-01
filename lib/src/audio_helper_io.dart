import 'dart:io';

Future<List<int>?> readAudioFile(String path, {dynamic recorder}) async {
  try {
    final file = File(path);
    return await file.readAsBytes();
  } catch (e) {
    return null;
  }
}
