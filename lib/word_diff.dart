/// Computes a word-level diff between original and transcribed text
/// Uses Longest Common Subsequence (LCS) to find matching words
/// Returns a flat list of DiffWord objects in original word order
List<DiffWord> computeWordDiff(String originalText, String transcribedText) {
  // Normalize and split into words
  final originalWords = _normalizeAndSplit(originalText);
  final transcribedWords = _normalizeAndSplit(transcribedText);
  
  // Find matching word indices using LCS
  final (originalIndices, transcribedIndices) = _findLCS(originalWords, transcribedWords);
  
  // Track which transcribed words have been matched
  final matchedTranscribedSet = transcribedIndices.toSet();
  
  // Build result by iterating through original words in order
  final result = <DiffWord>[];
  int lastTranscribedIndex = -1;
  
  for (int i = 0; i < originalWords.length; i++) {
    if (originalIndices.contains(i)) {
      // This word is in the LCS - find its matched transcribed index
      final transcribedIndex = transcribedIndices[originalIndices.indexOf(i)];
      
      // Insert any extra words that appeared between last match and this match
      for (int j = lastTranscribedIndex + 1; j < transcribedIndex; j++) {
        if (!matchedTranscribedSet.contains(j)) {
          result.add(DiffWord(text: transcribedWords[j], status: DiffStatus.extra));
        }
      }
      
      result.add(DiffWord(text: originalWords[i], status: DiffStatus.correct));
      lastTranscribedIndex = transcribedIndex;
    } else {
      // This word is not in the LCS - it's missing
      result.add(DiffWord(text: originalWords[i], status: DiffStatus.missing));
    }
  }
  
  // Collect any remaining extra words at the end
  for (int i = lastTranscribedIndex + 1; i < transcribedWords.length; i++) {
    if (!matchedTranscribedSet.contains(i)) {
      result.add(DiffWord(text: transcribedWords[i], status: DiffStatus.extra));
    }
  }
  
  return result;
}
/// Represents a single word in a diff with its status
class DiffWord {
  final String text;
  final DiffStatus status;
  
  DiffWord({required this.text, required this.status});
  
  String get displayLabel {
    switch (status) {
      case DiffStatus.correct:
        return '✓';
      case DiffStatus.missing:
        return '−';
      case DiffStatus.extra:
        return '+';
    }
  }
  
  @override
  String toString() => '$displayLabel "$text"';
}

/// Status of a word in the diff
enum DiffStatus {
  correct,  // ✓ Word is correct
  missing,  // − Word is missing from recitation
  extra,    // + Word is extra in recitation
}

/// Finds the Longest Common Subsequence of words
/// When multiple LCS exist, prefers the one with earliest match positions
/// Returns (originalIndices, transcribedIndices) - parallel lists of matching word positions
(List<int>, List<int>) _findLCS(List<String> original, List<String> transcribed) {
  final n = original.length;
  final m = transcribed.length;
  
  // DP table: dp[i][j] = (length, sumOfPositions) tuple
  // sumOfPositions helps break ties - prefer earlier matches
  final dp = List<List<(int, int)>>.generate(
      n + 1, (_) => List<(int, int)>.filled(m + 1, (0, 0)));
  
  for (int i = 1; i <= n; i++) {
    for (int j = 1; j <= m; j++) {
      final score = _computeWordSimilarity(original[i - 1], transcribed[j - 1]);
      if (score >= 0.9) {
        // Match found
        final (len, pos) = dp[i - 1][j - 1];
        dp[i][j] = (len + 1, pos + i + j); // Sum positions to break ties by earliness
      } else {
        final (len1, pos1) = dp[i - 1][j];
        final (len2, pos2) = dp[i][j - 1];
        if (len1 > len2) {
          dp[i][j] = (len1, pos1);
        } else if (len2 > len1) {
          dp[i][j] = (len2, pos2);
        } else if (len1 > 0) {
          // Tie in length - prefer lower sum (earlier matches)
          dp[i][j] = pos1 < pos2 ? (len1, pos1) : (len2, pos2);
        }
      }
    }
  }
  
  // Backtrack
  final originalIndices = <int>[];
  final transcribedIndices = <int>[];
  
  int i = n;
  int j = m;
  while (i > 0 && j > 0) {
    final score = _computeWordSimilarity(original[i - 1], transcribed[j - 1]);
    final (dpLen, _) = dp[i][j];
    final (upLen, _) = dp[i - 1][j];
    final (leftLen, _) = dp[i][j - 1];
    
    if (score >= 0.9 && dpLen == upLen + 1) {
      // This is a match
      originalIndices.add(i - 1);
      transcribedIndices.add(j - 1);
      i--;
      j--;
    } else if (upLen > leftLen) {
      i--;
    } else if (leftLen > upLen) {
      j--;
    } else if (upLen > 0) {
      // Both equal - need to figure out which path leads to earlier matches
      // For safety, prefer going up (skipping original) to stay in earlier j
      i--;
    } else {
      // Both zero
      if (j > i) j--; else i--;
    }
  }
  
  // Reverse to get correct order
  return (originalIndices.reversed.toList(), transcribedIndices.reversed.toList());
}

/// Normalizes text and splits into words, removing punctuation
List<String> _normalizeAndSplit(String text) {
  return text
      .replaceAll(RegExp(r'[^\w\s]'), '') // Remove punctuation
      .replaceAll(RegExp(r'\s+'), ' ')    // Normalize whitespace
      .trim()
      .split(' ')
      .where((word) => word.isNotEmpty)
      .toList();
}

/// Computes word similarity using Levenshtein distance
/// Returns a score from 0.0 to 1.0, where 1.0 is identical
/// Ignores punctuation and case
double _computeWordSimilarity(String word1, String word2) {
  final normalized1 = word1
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w]'), '');
  final normalized2 = word2
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w]'), '');
  
  if (normalized1 == normalized2) return 1.0;
  
  final maxLen = normalized1.length > normalized2.length
      ? normalized1.length
      : normalized2.length;
  
  if (maxLen == 0) return 1.0;
  
  final distance = _levenshteinDistance(normalized1, normalized2);
  return 1.0 - (distance / maxLen);
}

/// Calculates Levenshtein distance between two strings
int _levenshteinDistance(String s1, String s2) {
  if (s1 == s2) return 0;
  if (s1.isEmpty) return s2.length;
  if (s2.isEmpty) return s1.length;
  
  final v0 = List<int>.generate(s2.length + 1, (i) => i);
  final v1 = List<int>.filled(s2.length + 1, 0);
  
  for (var i = 0; i < s1.length; i++) {
    v1[0] = i + 1;
    for (var j = 0; j < s2.length; j++) {
      final cost = (s1[i] == s2[j]) ? 0 : 1;
      v1[j + 1] = [
        v1[j] + 1,      // insertion
        v0[j + 1] + 1,  // deletion
        v0[j] + cost,   // substitution
      ].reduce((a, b) => a < b ? a : b);
    }
    // Copy v1 to v0 for next iteration
    for (var j = 0; j <= s2.length; j++) {
      v0[j] = v1[j];
    }
  }
  return v1[s2.length];
}

