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

- `just gen` - Run code generation (freezed)
- `just web` - Run web version on local debug server (port 8000)
- `just android` - Run on Android device/emulator
- `just build-web` - Build web production release
- `just start-web-prod` - Build web production release and start server on 0.0.0.0:8000 (background)
- `just stop-web-prod` - Stop the production web server
- `just logs-web-prod` - Check production web server logs
- `just build-apk-prod` - Build Android APK (release)
- `just test` - Run tests
- `just analyze` - Analyze code
- `just format` - Format code
- `just clean` - Clean build artifacts

## Development Guidelines

### Just Recipe Naming

Recipe names use verb-first format: `verb-noun`

Examples:
- `build-web` - build something
- `start-web-prod` - start something
- `stop-web-prod` - stop something
- `logs-web-prod` - view logs for something
- `format` - simple verbs stand alone

### Git Commits

Use conventional commit format:

- `feat:` - New features
- `fix:` - Bug fixes
- `chore:` - Maintenance tasks
- `docs:` - Documentation changes
- `refactor:` - Code refactoring
- `style:` - Formatting changes
- `test:` - Adding/updating tests

Include scope when relevant: `fix(web):`, `feat(android):`

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

Flutter web support is enabled. A custom Python server with CORS headers is used for serving the production build.

**For local development:**

```bash
just web
```

The app will be served at http://localhost:8000 in debug mode.

**For production deployment:**

The app can be deployed inside an [exe.dev](https://exe.dev) VM, a service providing virtual machines with persistent disks and HTTPS access. From within the exe.dev VM, use:

```bash
just start-web-prod
```

This builds a production release and starts the server on 0.0.0.0:8000 in the background, making it accessible to external clients. Stop the server with:

```bash
just stop-web-prod
```

View logs with:

```bash
just logs-web-prod
```

For manual production builds without serving:

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
