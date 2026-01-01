import 'dart:typed_data';

/// Encodes raw PCM16 audio data into WAV format
class WavEncoder {
  static List<int> encodePcm16ToWav(
    List<int> pcmData, {
    int numChannels = 1,
    int sampleRate = 16000,
    int bitsPerSample = 16,
  }) {
    final bytesPerSample = bitsPerSample ~/ 8;
    final byteRate = sampleRate * numChannels * bytesPerSample;
    final blockAlign = numChannels * bytesPerSample;

    final header = BytesBuilder();

    // RIFF header
    header.addByte(0x52); // 'R'
    header.addByte(0x49); // 'I'
    header.addByte(0x46); // 'F'
    header.addByte(0x46); // 'F'

    // File size - 8 (will fill in later)
    final fileSizePos = header.length;
    header.add([0, 0, 0, 0]); // Placeholder

    // WAVE header
    header.addByte(0x57); // 'W'
    header.addByte(0x41); // 'A'
    header.addByte(0x56); // 'V'
    header.addByte(0x45); // 'E'

    // fmt subchunk
    header.addByte(0x66); // 'f'
    header.addByte(0x6D); // 'm'
    header.addByte(0x74); // 't'
    header.addByte(0x20); // ' '

    // Subchunk1Size (16 for PCM)
    header.add(_int32ToBytes(16));

    // AudioFormat (1 for PCM)
    header.add(_int16ToBytes(1));

    // NumChannels
    header.add(_int16ToBytes(numChannels));

    // SampleRate
    header.add(_int32ToBytes(sampleRate));

    // ByteRate
    header.add(_int32ToBytes(byteRate));

    // BlockAlign
    header.add(_int16ToBytes(blockAlign));

    // BitsPerSample
    header.add(_int16ToBytes(bitsPerSample));

    // data subchunk
    header.addByte(0x64); // 'd'
    header.addByte(0x61); // 'a'
    header.addByte(0x74); // 't'
    header.addByte(0x61); // 'a'

    // Subchunk2Size (audio data size)
    header.add(_int32ToBytes(pcmData.length));

    // Add audio data
    header.add(pcmData);

    final wavData = header.toBytes();

    // Update file size
    final fileSize = wavData.length - 8;
    final fileSizeBytes = _int32ToBytes(fileSize);
    for (int i = 0; i < 4; i++) {
      wavData[fileSizePos + i] = fileSizeBytes[i];
    }

    return wavData.toList();
  }

  static List<int> _int32ToBytes(int value) {
    return [
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    ];
  }

  static List<int> _int16ToBytes(int value) {
    return [
      value & 0xFF,
      (value >> 8) & 0xFF,
    ];
  }
}
