import 'package:daily_manna/scripture_range_ref.dart';
import 'package:daily_manna/prompts.dart';
import 'package:daily_manna/settings_service.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class OpenRouterService {
  final SettingsService settingsService;
  static const String _baseUrl =
      'https://openrouter.ai/api/v1/chat/completions';

  OpenRouterService(this.settingsService);

  Future<ScriptureRangeRef?> recognizePassage(
    String transcribedText, {
    List<String>? availableBookIds,
  }) async {
    debugPrint('[RecognizePassage] Starting passage recognition');
    debugPrint('[RecognizePassage] Transcribed text: "$transcribedText"');
    debugPrint('[RecognizePassage] Available book IDs: $availableBookIds');
    
    final apiKey = settingsService.getOpenRouterApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('OpenRouter API key not configured');
    }

    final systemPrompt = availableBookIds != null && availableBookIds.isNotEmpty
        ? Prompts.biblePassageRecognitionSystemWithBooks(availableBookIds)
        : Prompts.biblePassageRecognitionSystem;

    final requestBody = {
      'model': 'openai/gpt-5-mini',
      'messages': [
        {
          'role': 'system',
          'content': systemPrompt,
        },
        {
          'role': 'user',
          'content': 'Identify this Bible passage from the transcribed text:\n\n"$transcribedText"'
        },
      ],
      'temperature': 0.3,
    };
    
    debugPrint('[RecognizePassage] Sending request to OpenRouter');
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(requestBody),
    );

    debugPrint('[RecognizePassage] Response status: ${response.statusCode}');
    debugPrint('[RecognizePassage] Response body: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to recognize passage: ${response.statusCode} ${response.reasonPhrase}',
      );
    }

    final Map<String, dynamic> responseBody = jsonDecode(response.body);

    if (responseBody.containsKey('error')) {
      final errorMsg = responseBody['error'];
      debugPrint('[RecognizePassage] OpenRouter error: $errorMsg');
      throw Exception('OpenRouter error: $errorMsg');
    }

    if (!responseBody.containsKey('choices') ||
        (responseBody['choices'] as List).isEmpty) {
      throw Exception('No response from OpenRouter');
    }

    final String content =
        responseBody['choices'][0]['message']['content'] as String;
    
    debugPrint('[RecognizePassage] LLM response content: "$content"');

    // Parse the JSON response from the LLM
    try {
      final Map<String, dynamic> parsedContent = jsonDecode(content);
      debugPrint('[RecognizePassage] Parsed JSON: $parsedContent');

      final bookId = parsedContent['bookId'] as String?;
      final startChapter = parsedContent['startChapter'] as int?;
      final startVerse = parsedContent['startVerse'] as int?;
      final endChapter = parsedContent['endChapter'] as int?;
      final endVerse = parsedContent['endVerse'] as int?;

      // Return null if essential fields are missing
      if (bookId == null || startChapter == null || startVerse == null) {
        debugPrint('[RecognizePassage] Missing essential fields, returning null');
        return null;
      }

      final result = ScriptureRangeRef(
        bookId: bookId,
        startChapter: startChapter,
        startVerse: startVerse,
        endChapter: endChapter,
        endVerse: endVerse,
      );
      
      debugPrint('[RecognizePassage] Recognition result: bookId=${result.bookId}, '
          'chapter=${result.startChapter}:${result.startVerse}');
      
      return result;
    } catch (e) {
      debugPrint('[RecognizePassage] Failed to parse JSON: $e');
      throw Exception('Failed to parse passage recognition response: $e');
    }
  }
}
