import 'package:daily_manna/settings_service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class WhisperService {
  final SettingsService settingsService;
  static const String _baseUrl = 'https://api.openai.com/v1/audio/transcriptions';

  WhisperService(this.settingsService);

  Future<String> transcribeAudio(String audioFilePath) async {
    throw Exception('Use transcribeAudioBytes instead');
  }

  Future<String> transcribeAudioBytes(List<int> audioBytes, String filename) async {
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
        http.MultipartFile.fromBytes(
          'file',
          audioBytes,
          filename: filename,
        ),
      );

    final response = await request.send();
    
    debugPrint('[Whisper] Response status: ${response.statusCode}');

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to transcribe audio: ${response.statusCode} ${response.reasonPhrase}',
      );
    }

    final responseBody = await response.stream.bytesToString();
    debugPrint('[Whisper] Response body: $responseBody');
    
    // Parse JSON response
    final Map<String, dynamic> json = _parseJsonSimple(responseBody);

    if (json.containsKey('text')) {
      final text = json['text'] as String;
      debugPrint('[Whisper] Transcribed text: "$text"');
      return text;
    } else if (json.containsKey('error')) {
      debugPrint('[Whisper] Error: ${json['error']}');
      throw Exception('Whisper error: ${json['error']}');
    } else {
      throw Exception('Unexpected response format from Whisper API');
    }
  }

  // Simple JSON parser to avoid dart:convert dependency issues
  Map<String, dynamic> _parseJsonSimple(String jsonString) {
    // Basic JSON parsing for the expected response format
    final textMatch = RegExp(r'"text"\s*:\s*"([^"]*)"').firstMatch(jsonString);
    if (textMatch != null) {
      return {'text': textMatch.group(1)};
    }

    final errorMatch =
        RegExp(r'"error"\s*:\s*"([^"]*)"').firstMatch(jsonString);
    if (errorMatch != null) {
      return {'error': errorMatch.group(1)};
    }

    throw Exception('Could not parse JSON response');
  }
}
