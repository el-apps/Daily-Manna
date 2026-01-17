# Daily Manna - Agent Guidelines

> **Note:** Essential information only. Keep context window lean.

## Project Overview

Daily Manna is a Flutter app for building strong daily habits in interacting with the Word of God. Primary feature: Bible verse memorization.

## Tech Stack

- **Framework**: Flutter (Dart)
- **State Management**: Provider
- **Code Generation**: Freezed (immutable data classes)
- **Bible Data**: bible_parser_flutter (KJV XML parser)
- **Platforms**: Android, Web

## Project Structure

```
lib/
├── main.dart
├── home_page.dart                 # Feature cards registered here
├── settings_page.dart             # API keys config
├── share_dialog.dart
├── prompts.dart                   # LLM prompts
│
├── models/                        # Freezed classes only
│   ├── scripture_ref.dart
│   ├── scripture_range_ref.dart
│   ├── recitation_result.dart
│   ├── result_item.dart
│   └── result_section.dart
│
├── services/                      # Business logic & integrations
│   ├── bible_service.dart
│   ├── results_service.dart
│   ├── settings_service.dart
│   ├── whisper_service.dart       # OpenAI Whisper
│   └── openrouter_service.dart    # LLM passage recognition
│
├── ui/
│   ├── theme_card.dart            # Shared container
│   ├── mode_card.dart             # Home card
│   ├── loading_section.dart       # Shared loading indicator
│   ├── memorization/
│   │   ├── verse_memorization.dart
│   │   ├── verse_selector.dart
│   │   └── practice_result.dart
│   └── recitation/                # Audio practice
│       ├── recitation_mode.dart
│       ├── recording_card.dart
│       ├── recitation_playback_section.dart
│       ├── recitation_confirmation_section.dart
│       └── results/
│           ├── recitation_results.dart
│           ├── diff_comparison.dart
│           ├── diff_legend.dart
│           └── diff_colors.dart
│
├── bytes_audio_source.dart
├── wav_encoder.dart
└── passage_range_selector.dart

assets/
└── kjv.xml                        # ~5MB

web/                               # Flutter web support
android/                           # Android platform
```

## Key Commands

```bash
just gen              # Code generation (freezed)
just web              # Local debug server (port 8000)
just android          # Run on device/emulator
just build-web        # Production web build
just start-web-prod   # Build & serve production (0.0.0.0:8000)
just stop-web-prod    # Stop production server
just logs-web-prod    # View production logs
just build-apk-prod   # Android release APK
just test             # Run tests
just analyze          # Lint analysis
just format           # Format code
just clean            # Clean build artifacts
```

## Development Guidelines

### Just Recipe Naming

Verb-first format: `verb-noun`. Simple verbs stand alone: `format`, `test`.

### Git Commits

Use conventional format with optional scope:

- `feat(web):` / `fix(android):` - Feature or fix with scope
- `chore:` `docs:` `refactor:` `style:` `test:` - Other changes

### Code Organization

Organize by importance: **Public APIs first**, then supporting code.

**File structure:**

1. Main functions/classes (`computeWordDiff()`, `MyWidget`)
2. Data classes (`WordDiff`, `DiffWord`)
3. Enums and constants
4. Helper/private functions

**Within classes:** Public methods → methods they call → private utilities.

### Freezed Data Classes

Always `abstract class X with _$X`. Place in `/lib/models/`. Use domain-specific names, not UI context.

```dart
@freezed
abstract class ResultItem with _$ResultItem {
  const factory ResultItem({
    required String score,
    required String reference,
  }) = _ResultItem;
}
```

After modifying: `just gen`

### Enhanced Enums with Extensions

Prefer extension methods on enums over standalone utility functions:

```dart
extension DiffStatusColors on DiffStatus {
  MaterialColor get primaryColor => switch (this) {
    DiffStatus.correct => Colors.green,
    DiffStatus.missing => Colors.red,
    DiffStatus.extra => Colors.yellow,
  };
}
```

Call as `status.primaryColor` instead of `getPrimaryColor(status)`.

### Business Logic in Services

Format and transform data in service classes, not widgets. Example: `ResultsService.getSections()` returns display-ready sections rather than raw data.

### Widget Creation and Organization

**Critical:** Prefer separate widgets over helper methods.

**Why:** Helper methods create new widget instances on every parent rebuild, bypassing Flutter's widget tree diffing. Actual Widget classes enable the framework to skip unnecessary rebuilds—fundamental to rendering performance.

**Extract a widget if it:**

- Represents a distinct UI concept (`RecordingCard`, `LoadingSection`)
- Is reused across multiple places
- Has parameters or state management
- Is more than a few lines

**When NOT to extract:** Trivial spacing (`SizedBox(height: 16)`) or single widgets (`Text('Hello')`).

**File organization:**

- **Shared** (reusable): `lib/ui/widget_name.dart`
- **Feature-specific**: `lib/ui/feature_name/widget_name.dart`
- **Sections**: `lib/ui/feature_name/*_section.dart`
- **Results/dialogs/pages**: With the feature that uses them

**Widget structure:**

1. Simple stateless → expression body: `Widget build(BuildContext context) => Container(...);`
2. Widgets with parameters → `final` fields
3. Stateful → keep state in `State` class, not widget class

### Page Structure

**Always use `AppScaffold` (not `Scaffold` directly).** It provides consistent AppBar and share button. Set `showShareButton: false` only on Settings page.

### Adding New Features

1. Create feature widget in `lib/`
2. Register in `features` list in `home_page.dart`
3. Use `AppScaffold` for page structure

### Data Access Patterns

**Bible service:**

```dart
final bibleService = context.read<BibleService>();
final verse = bibleService.getVerse('Gen', 1, 1);
```

**Scripture references:**

```dart
final ref = ScriptureRef(bookId: 'Gen', chapterNumber: 1, verseNumber: 1);
if (ref.complete) { /* all fields set */ }
```

### Fallback UI States

Always show helpful feedback when data is empty. Don't leave views blank.

Examples: "No results to share yet", loading indicators, error messages.

## Web Support

Flask web support enabled. Custom Python server with CORS headers.

**Local dev:** `just web` → http://localhost:8000

**Production** (exe.dev VM):

- `just start-web-prod` - Build & serve on 0.0.0.0:8000 (background)
- `just stop-web-prod` - Stop server
- `just logs-web-prod` - View logs

## Important Notes

- KJV XML ~5MB: initial load may be slow
- Web uses CanvasKit renderer (requires WebGL)
- `share_plus` handles mobile/web sharing
- `word_tools` for memorization scoring
- Whisper API for speech-to-text
- OpenRouter LLM for passage recognition
- Audio: PCM 16-bit at 16kHz, encoded to WAV

## TODO Items

See code comments for planned features:

- Persistent storage of memorization results (currently in-memory)
- User verse queue management
