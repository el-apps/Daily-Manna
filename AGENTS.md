# Daily Manna - Agent Guidelines

## Project Overview

Daily Manna is a Flutter application for building strong daily habits in interacting with the Word of God. The primary feature is Bible verse memorization.

## Tech Stack

- **Framework**: Flutter (Dart)
- **State Management**: Provider
- **Code Generation**: Freezed (for immutable data classes)
- **Bible Data**: bible_parser_flutter (parses KJV XML)
- **Platforms**: Android, Web

## Project Structure

```
lib/
├── main.dart              # App entry point and root widget
├── home_page.dart         # Main home screen with feature cards
├── bible_service.dart     # Bible parsing and verse retrieval service
├── verse_memorization.dart # Core memorization practice feature
├── verse_selector.dart    # UI for selecting book/chapter/verse
├── scripture_ref.dart     # Freezed model for scripture references
├── scripture_ref.freezed.dart # Generated freezed code
├── practice_result.dart   # Memorization result tracking
└── share_dialog.dart      # Share progress with others

assets/
└── kjv.xml               # King James Version Bible data (~5MB)

web/                       # Flutter web support files
android/                   # Android platform files
```

## Key Commands

Use `just` to run common tasks:

- `just deps` - Install dependencies
- `just gen` - Run code generation (freezed)
- `just web` - Run web version in debug mode
- `just chrome` - Run in Chrome browser
- `just android` - Run on Android device/emulator
- `just build-web` - Build web release
- `just build-apk` - Build Android APK
- `just test` - Run tests
- `just analyze` - Analyze code
- `just fmt` - Format code

## Development Guidelines

### Code Generation

After modifying any `@freezed` annotated classes, run:
```bash
just gen
```

### Adding New Features

1. Features are displayed on the HomePage as cards
2. Add new feature widgets in `lib/`
3. Register them in the `features` list in `home_page.dart`

### Bible Data Access

Use `BibleService` via Provider:
```dart
final bibleService = context.read<BibleService>();
final verse = bibleService.getVerse('Gen', 1, 1);
```

### Scripture References

Use the `ScriptureRef` freezed class:
```dart
final ref = ScriptureRef(bookId: 'Gen', chapterNumber: 1, verseNumber: 1);
if (ref.complete) { /* all fields are set */ }
```

## Web Support

Flutter web support is enabled. To run locally:
```bash
just web
```

The app will be served at http://localhost:8000

For production builds:
```bash
just build-web
```

## Notes

- The KJV Bible XML file is ~5MB, so initial load may take a moment
- Web version uses CanvasKit renderer by default (requires WebGL)
- The `share_plus` package handles sharing on both mobile and web
- Memorization scoring uses `word_tools` package for text comparison

## TODO Items

See TODO comments in code for planned features:
- Persistent storage of memorization results (currently in-memory)
- User verse queue management
- Additional features beyond memorization
