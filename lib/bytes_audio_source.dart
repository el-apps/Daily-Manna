import 'package:just_audio/just_audio.dart';

class BytesAudioSource extends StreamAudioSource {
  final List<int> bytes;

  BytesAudioSource(this.bytes);

  @override
  Future<StreamAudioResponse> request([int? offset, int? length]) async {
    final start = offset ?? 0;
    final end = length != null ? start + length : bytes.length;
    
    if (start < 0 || end > bytes.length) {
      throw RangeError('Invalid range');
    }
    
    return StreamAudioResponse(
      rangeRequestsSupported: true,
      sourceLength: bytes.length,
      contentLength: end - start,
      offset: start,
      contentType: 'audio/wav',
      stream: Stream.value(bytes.sublist(start, end)),
    );
  }
}
