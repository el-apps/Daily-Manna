import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/prompts.dart';
import 'package:daily_manna/services/settings_service.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class OpenRouterService {
  final SettingsService settingsService;
  static const String _chatBaseUrl =
      'https://openrouter.ai/api/v1/chat/completions';

  OpenRouterService(this.settingsService);

  Future<String> transcribeAudio(
    List<int> audioBytes,
    String filename,
  ) async {
    debugPrint('[OpenRouter Audio] Starting transcription');
    debugPrint('[OpenRouter Audio] Audio size: ${audioBytes.length} bytes');

    final apiKey = settingsService.getOpenRouterApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('OpenRouter API key not configured');
    }

    // Base64 encode audio
    final base64Audio = base64Encode(audioBytes);
    debugPrint('[OpenRouter Audio] Base64 encoded audio size: ${base64Audio.length} chars');

    // Determine audio format from filename
    final audioFormat = _getAudioFormat(filename);

    final requestBody = {
      'model': 'openai/gpt-4o-audio-preview',
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text': 'Please transcribe this audio file.',
            },
            {
              'type': 'input_audio',
              'input_audio': {
                'data': base64Audio,
                'format': audioFormat,
              },
            },
          ],
        },
      ],
    };

    debugPrint('[OpenRouter Audio] Sending audio to chat API');
    final response = await http
        .post(
          Uri.parse(_chatBaseUrl),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(requestBody),
        )
        .timeout(const Duration(seconds: 60));

    debugPrint('[OpenRouter Audio] Response status: ${response.statusCode}');
    debugPrint('[OpenRouter Audio] Response body: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to transcribe audio: ${response.statusCode} ${response.reasonPhrase}',
      );
    }

    final responseBody = jsonDecode(response.body) as Map<String, dynamic>;

    if (responseBody.containsKey('error')) {
      final errorMsg = responseBody['error'];
      debugPrint('[OpenRouter Audio] Error: $errorMsg');
      throw Exception('OpenRouter audio error: $errorMsg');
    }

    if (!responseBody.containsKey('choices') ||
        (responseBody['choices'] as List).isEmpty) {
      throw Exception('No response from OpenRouter');
    }

    final String content =
        responseBody['choices'][0]['message']['content'] as String;

    debugPrint('[OpenRouter Audio] Transcribed text: "$content"');
    return content;
  }

  String _getAudioFormat(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    const supportedFormats = ['wav', 'mp3', 'aiff', 'aac', 'ogg', 'flac', 'm4a', 'pcm16', 'pcm24'];
    return supportedFormats.contains(ext) ? ext : 'wav';
  }

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
        {'role': 'system', 'content': systemPrompt},
        {
          'role': 'user',
          'content':
              'Identify this Bible passage from the transcribed text:\n\n"$transcribedText"',
        },
      ],
      'temperature': 0.3,
      'response_format': {'type': 'json_object'},
    };

    debugPrint('[RecognizePassage] Sending request to OpenRouter');
    final response = await http
        .post(
          Uri.parse(_chatBaseUrl),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(requestBody),
        )
        .timeout(const Duration(seconds: 30));

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

    try {
      final parsedContent = jsonDecode(content) as Map<String, dynamic>;
      debugPrint('[RecognizePassage] Parsed JSON: $parsedContent');

      final bookId = parsedContent['bookId'] as String?;
      final startChapter = parsedContent['startChapter'] as int?;
      final startVerse = parsedContent['startVerse'] as int?;

      if (bookId == null || startChapter == null || startVerse == null) {
        debugPrint('[RecognizePassage] Missing essential fields');
        return null;
      }

      final result = ScriptureRangeRef(
        bookId: bookId,
        startChapter: startChapter,
        startVerse: startVerse,
        endChapter: parsedContent['endChapter'] as int?,
        endVerse: parsedContent['endVerse'] as int?,
      );

      debugPrint(
        '[RecognizePassage] Recognition result: ${result.bookId} '
        '${result.startChapter}:${result.startVerse}',
      );
      return result;
    } catch (e) {
      debugPrint('[RecognizePassage] Failed to parse response: $e');
      throw Exception('Failed to parse passage recognition. Please try again.');
    }
  }
}
