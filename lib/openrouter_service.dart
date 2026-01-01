import 'package:daily_manna/prompts.dart';
import 'package:daily_manna/settings_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class PassageRecognitionResult {
  final String? book;
  final int? startChapter;
  final int? startVerse;
  final int? endChapter;
  final int? endVerse;
  final String rawResponse;

  PassageRecognitionResult({
    required this.book,
    required this.startChapter,
    required this.startVerse,
    required this.endChapter,
    required this.endVerse,
    required this.rawResponse,
  });
}

class OpenRouterService {
  final SettingsService settingsService;
  static const String _baseUrl =
      'https://openrouter.ai/api/v1/chat/completions';

  OpenRouterService(this.settingsService);

  Future<PassageRecognitionResult> recognizePassage(
    String transcribedText,
  ) async {
    final apiKey = settingsService.getOpenRouterApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('OpenRouter API key not configured');
    }

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'openai/gpt-5-mini',
        'messages': [
          {
            'role': 'system',
            'content': Prompts.biblePassageRecognitionSystem,
          },
          {
            'role': 'user',
            'content': 'Identify this Bible passage from the transcribed text:\n\n"$transcribedText"'
          },
        ],
        'temperature': 0.3,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to recognize passage: ${response.statusCode} ${response.reasonPhrase}',
      );
    }

    final Map<String, dynamic> responseBody = jsonDecode(response.body);

    if (responseBody.containsKey('error')) {
      throw Exception('OpenRouter error: ${responseBody['error']}');
    }

    if (!responseBody.containsKey('choices') ||
        (responseBody['choices'] as List).isEmpty) {
      throw Exception('No response from OpenRouter');
    }

    final String content =
        responseBody['choices'][0]['message']['content'] as String;

    // Parse the JSON response from the LLM
    try {
      final Map<String, dynamic> parsedContent = jsonDecode(content);

      return PassageRecognitionResult(
        book: parsedContent['book'] as String?,
        startChapter: parsedContent['startChapter'] as int?,
        startVerse: parsedContent['startVerse'] as int?,
        endChapter: parsedContent['endChapter'] as int?,
        endVerse: parsedContent['endVerse'] as int?,
        rawResponse: content,
      );
    } catch (e) {
      throw Exception('Failed to parse passage recognition response: $e');
    }
  }
}
