import 'dart:io';
import 'package:daily_manna/settings_service.dart';
import 'package:http/http.dart' as http;

class WhisperService {
  final SettingsService settingsService;
  static const String _baseUrl = 'https://api.openai.com/v1/audio/transcriptions';

  WhisperService(this.settingsService);

  Future<String> transcribeAudio(String audioFilePath) async {
    final apiKey = settingsService.getWhisperApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Whisper API key not configured');
    }

    final audioFile = File(audioFilePath);
    if (!audioFile.existsSync()) {
      throw Exception('Audio file not found: $audioFilePath');
    }

    final request = http.MultipartRequest('POST', Uri.parse(_baseUrl))
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..fields['model'] = 'whisper-1'
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          audioFilePath,
          filename: 'audio.m4a',
        ),
      );

    final response = await request.send();

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to transcribe audio: ${response.statusCode} ${response.reasonPhrase}',
      );
    }

    final responseBody = await response.stream.bytesToString();
    // Parse JSON response
    final Map<String, dynamic> json = _parseJsonSimple(responseBody);

    if (json.containsKey('text')) {
      return json['text'] as String;
    } else if (json.containsKey('error')) {
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
