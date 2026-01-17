import 'dart:convert';
import 'package:daily_manna/services/settings_service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class WhisperService {
  final SettingsService settingsService;
  static const String _baseUrl =
      'https://api.openai.com/v1/audio/transcriptions';

  WhisperService(this.settingsService);

  Future<String> transcribeAudioBytes(
    List<int> audioBytes,
    String filename,
  ) async {
    debugPrint('[Whisper] Starting transcription with gpt-4o-transcribe');
    debugPrint('[Whisper] Audio size: ${audioBytes.length} bytes');

    final apiKey = settingsService.getWhisperApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Whisper API key not configured');
    }

    debugPrint('[Whisper] Sending audio to API');
    final request = http.MultipartRequest('POST', Uri.parse(_baseUrl))
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..fields['model'] = 'gpt-4o-transcribe'
      ..files.add(
        http.MultipartFile.fromBytes('file', audioBytes, filename: filename),
      );

    final response = await request.send().timeout(const Duration(seconds: 30));
    debugPrint('[Whisper] Response status: ${response.statusCode}');

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to transcribe audio: ${response.statusCode} ${response.reasonPhrase}',
      );
    }

    final responseBody = await response.stream.bytesToString();
    debugPrint('[Whisper] Response body: $responseBody');

    final json = _parseJson(responseBody);

    if (json case {'text': String text}) {
      debugPrint('[Whisper] Transcribed text: "$text"');
      return text;
    }

    if (json case {'error': var error}) {
      throw Exception('Whisper error: $error');
    }

    throw Exception('Unexpected response format from Whisper API');
  }

  Map<String, dynamic> _parseJson(String jsonString) {
    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to parse Whisper response: $e');
    }
  }
}
