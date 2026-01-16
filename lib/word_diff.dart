/// Computes a word-level diff between original and transcribed text
/// Uses a simple greedy matching algorithm
WordDiff computeWordDiff(String originalText, String transcribedText) {
  // Normalize and split into words
  final originalWords = _normalizeAndSplit(originalText);
  final transcribedWords = _normalizeAndSplit(transcribedText);
  
  // Track which transcribed words have been matched
  final matched = List<bool>.filled(transcribedWords.length, false);
  
  // Create diff for original words
  final originalDiff = <DiffWord>[];
  for (final origWord in originalWords) {
    // Try to find a matching transcribed word (case-insensitive)
    int matchIndex = -1;
    for (int i = 0; i < transcribedWords.length; i++) {
      if (!matched[i] && 
          transcribedWords[i].toLowerCase() == origWord.toLowerCase()) {
        matchIndex = i;
        break;
      }
    }
    
    if (matchIndex >= 0) {
      matched[matchIndex] = true;
      originalDiff.add(DiffWord(text: origWord, status: DiffStatus.correct));
    } else {
      originalDiff.add(DiffWord(text: origWord, status: DiffStatus.missing));
    }
  }
  
  // Create diff for transcribed words (only mark unmatched ones)
  final transcribedDiff = <DiffWord>[];
  for (int i = 0; i < transcribedWords.length; i++) {
    if (!matched[i]) {
      transcribedDiff.add(
        DiffWord(text: transcribedWords[i], status: DiffStatus.extra)
      );
    }
  }
  
  return WordDiff(original: originalDiff, transcribed: transcribedDiff);
}

/// Result of a word-level diff operation
class WordDiff {
  final List<DiffWord> original;
  final List<DiffWord> transcribed;
  
  WordDiff({required this.original, required this.transcribed});
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
      case DiffStatus.substituted:
        return '↻';
    }
  }
}

/// Status of a word in the diff
enum DiffStatus {
  correct,    // ✓ Word is correct
  missing,    // − Word is missing from recitation
  extra,      // + Word is extra in recitation
  substituted // ↻ Word is different from original
}

/// Normalizes text and splits into words
List<String> _normalizeAndSplit(String text) {
  // Remove extra whitespace, convert to words
  return text
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .split(' ')
      .where((word) => word.isNotEmpty)
      .toList();
}
