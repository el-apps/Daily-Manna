import 'package:daily_manna/models/scripture_range_ref.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Client for the Daily Manna API. OpenRouter credentials never reach the app.
class BackendService {
  static const String _apiBaseUrl = String.fromEnvironment(
    'DAILY_MANNA_API_URL',
    defaultValue: 'https://dailymanna.kwila.cloud/api',
  );
  static const transcriptionModel = 'nvidia/parakeet-tdt-0.6b-v3';
  static const transcriptionTimeout = Duration(seconds: 120);
  static const recognitionTimeout = Duration(seconds: 30);

  BackendService();

  Future<String> transcribeAudio(List<int> audioBytes, String filename) async {
    debugPrint('[Backend Audio] Starting transcription');
    debugPrint('[Backend Audio] Audio size: ${audioBytes.length} bytes');

    // Base64 encode audio
    final base64Audio = base64Encode(audioBytes);
    debugPrint(
      '[Backend Audio] Base64 encoded audio size: ${base64Audio.length} chars',
    );

    final requestBody = {
      'audioBase64': base64Audio,
      'filename': filename,
    };

    debugPrint('[Backend Audio] Sending audio to Daily Manna API');
    final response = await http
        .post(
          Uri.parse('$_apiBaseUrl/transcribe'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        )
        .timeout(transcriptionTimeout);

    debugPrint('[Backend Audio] Response status: ${response.statusCode}');
    debugPrint('[Backend Audio] Response body: ${response.body}');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint('[Backend Audio] Error response body: ${response.body}');
      throw Exception(
        'Failed to transcribe audio: ${response.statusCode} - ${_parseErrorDetail(response)}',
      );
    }

    final responseBody = jsonDecode(response.body) as Map<String, dynamic>;

    final transcript = responseBody['text'];
    if (transcript is! String) {
      throw Exception('No transcription text found in backend response');
    }

    debugPrint('[Backend Audio] Transcribed text: "$transcript"');
    return transcript;
  }

  String _parseErrorDetail(http.Response response) {
    try {
      final errorBody = jsonDecode(response.body) as Map<String, dynamic>;
      if (errorBody.containsKey('error')) {
        final error = errorBody['error'];
        if (error is Map) {
          // Try to get detailed message, code, and metadata
          final message = error['message'] as String? ?? '';
          final code = error['code']?.toString() ?? '';
          final metadata = error['metadata']?.toString() ?? '';
          final parts = [message, if (code.isNotEmpty) 'code: $code', if (metadata.isNotEmpty) metadata]
              .where((s) => s.isNotEmpty)
              .join(', ');
          if (parts.isNotEmpty) return parts;
        } else if (error is String) {
          return error;
        }
      }
    } catch (_) {
      // Ignore JSON parse errors
    }
    return response.reasonPhrase ?? 'Unknown error';
  }

  Future<ScriptureRangeRef?> recognizePassage(
    String transcribedText, {
    List<String>? availableBookIds,
  }) async {
    debugPrint('[RecognizePassage] Starting passage recognition');
    debugPrint('[RecognizePassage] Transcribed text: "$transcribedText"');
    debugPrint('[RecognizePassage] Available book IDs: $availableBookIds');

    if (availableBookIds == null) {
      throw Exception('Book IDs have not loaded');
    }

    final requestBody = {
      'transcribedText': transcribedText,
      'availableBookIds': availableBookIds,
    };

    debugPrint('[RecognizePassage] Sending request to OpenRouter');
    final response = await http
        .post(
          Uri.parse('$_apiBaseUrl/recognize-passage'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        )
        .timeout(recognitionTimeout);

    debugPrint('[RecognizePassage] Response status: ${response.statusCode}');
    debugPrint('[RecognizePassage] Response body: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to recognize passage: ${response.statusCode} - ${_parseErrorDetail(response)}',
      );
    }

    try {
      final parsedContent = jsonDecode(response.body) as Map<String, dynamic>;
      debugPrint('[RecognizePassage] Parsed JSON: $parsedContent');

      final bookId = parsedContent['bookId'] as String?;
      final chapter = parsedContent['chapter'] as int?;
      final startVerse = parsedContent['startVerse'] as int?;

      if (bookId == null || chapter == null || startVerse == null) {
        debugPrint('[RecognizePassage] Missing essential fields');
        return null;
      }

      final result = ScriptureRangeRef(
        bookId: bookId,
        chapter: chapter,
        startVerse: startVerse,
        endVerse: parsedContent['endVerse'] as int?,
      );

      debugPrint(
        '[RecognizePassage] Recognition result: ${result.bookId} '
        '${result.chapter}:${result.startVerse}',
      );
      return result;
    } catch (e) {
      debugPrint('[RecognizePassage] Failed to parse response: $e');
      throw Exception('Failed to parse passage recognition. Please try again.');
    }
  }
}
