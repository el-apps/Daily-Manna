# Daily Manna - Agent Guidelines

> **Note:** Essential information only. Keep context window lean.
> **Updates to this file:** Concise prose only. Include code examples only when high-impact and necessary. No verbose explanations, multiple examples, or unnecessary bulleted lists of benefits.

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
├── prompts.dart                   # LLM prompts
│
├── models/                        # Freezed classes only
│
├── services/                      # Business logic & integrations
│   ├── database/database.dart     # Drift ORM
│   ├── bible_service.dart
│   ├── results_service.dart
│   ├── settings_service.dart
│   ├── spaced_repetition_service.dart
│   └── openrouter_service.dart    # LLM transcription & passage recognition
│
├── utils/
│   └── date_utils.dart            # DateOnlyExtension
│
├── ui/
│   ├── app_scaffold.dart          # Standard page wrapper
│   ├── theme_card.dart            # Shared container
│   ├── empty_state.dart           # Shared empty state
│   ├── action_button_row.dart     # Cancel/Submit button pair
│   ├── loading_section.dart       # Shared loading indicator
│   ├── memorization/
│   ├── recitation/
│   ├── verse_selection/
│   ├── history/
│   ├── review/
│   ├── practice/
│   └── study/
│
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

**Always use conventional commit format.** Every commit message must start with a type prefix. Make new commits for fixes—don't use `--amend` + force push to rewrite history.

**Never rebase pushed branches.** Once a branch is pushed, use `git merge origin/main` to incorporate upstream changes, not rebase. Rebase requires force push, which rewrites public history.

Format: `type(scope): description` or `type: description`

Types:
- `feat:` - New feature
- `fix:` - Bug fix
- `refactor:` - Code change that neither fixes a bug nor adds a feature
- `chore:` - Build, config, or tooling changes
- `docs:` - Documentation only
- `style:` - Formatting, whitespace (no code change)
- `test:` - Adding or updating tests

Optional scope in parentheses: `feat(web):`, `fix(android):`

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

**Reuse existing widgets** before creating new ones. Check `lib/ui/` for shared components like `ThemeCard`, `VerseSelector`, `LoadingSection`.

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

**Widget naming:**

- Use `_PrivateWidget` prefix for internal-only widgets (used only in their own file or within a parent widget)
- Public widgets (reusable or imported elsewhere) have no underscore: `PublicWidget`

### Page Structure

**Always use `AppScaffold` (not `Scaffold` directly).** It provides consistent AppBar and share button. Set `showShareButton: false` only on Settings page.

**Prefer existing navigation patterns.** Use push/pop with return values rather than adding callbacks to existing pages.

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

### UI Conventions

- **Button text**: Clean text only, no emojis or decorative elements
- **Dialog actions**: Cancel button goes last (right-most), primary actions first
- **Don't assume styling**: Ask before adding decorative elements

## Releases

Update version in `pubspec.yaml`, merge to `main` to trigger automatic workflow: creates git tag, builds APK, and creates GitHub Release.

## Web Support

Custom Python server with CORS headers.

**Local dev:** `just web` → http://localhost:8000

**Headless browser gotcha:** Locale strings like `en-US@posix` break Flutter's parser, causing silent white-screen failures. Normalization is handled in `web/index.html`.

**Production** (exe.dev VM):

- `just start-web-prod` - Build & serve on 0.0.0.0:8000 (background)
- `just stop-web-prod` - Stop server
- `just logs-web-prod` - View logs

### Testing Database Changes

When testing changes to database behavior in the browser, clear IndexedDB storage first. Old persisted data will mask whether your fix works. Use browser devtools or JS to clear storage before testing.

## Important Notes

- KJV XML ~5MB: initial load may be slow
- Web uses CanvasKit renderer (requires WebGL)
- Drift database: web requires `sqlite3.wasm` and `drift_worker.js` in `web/`
- `share_plus` handles mobile/web sharing
- `word_tools` for memorization scoring
- Whisper API for speech-to-text
- OpenRouter LLM for passage recognition
- Audio: PCM 16-bit at 16kHz, encoded to WAV

## Before Writing Code

**Study existing patterns first.** Before adding new functions or methods, read the surrounding code to understand existing patterns. Reuse existing helpers instead of creating new ones.

## Tidy First Principles

**Goal: Write code that is maintainable long-term.** Avoid unnecessary couplings (dependencies between components) that make future changes expensive.

Apply Kent Beck's "Tidy First?" concepts at all times:

**Tidyings** - Small, reversible structural changes that don't alter behavior:
- **Guard clauses**: Replace nested conditions with early returns
- **Normalize symmetries**: Make similar code look similar
- **Extract helper**: Pull out reusable logic into named functions/methods
- **Dead code removal**: Delete unused code paths
- **Explaining variables**: Extract complex expressions into named variables
- **Explaining constants**: Replace magic numbers/strings with named constants

**When to tidy:**
- **Before** a behavior change if it makes the change easier
- **After** if you notice mess in code you're modifying
- **Stay focused**: Don't tidy unrelated code—note it for later

**Commit discipline:** Each tidying is one small commit. Don't mix tidyings with behavior changes.

## Subagent Delegation

When using subagents for parallel work:

**Two-phase approach:**
1. **Analysis phase** - Launch read-only subagents to gather findings. Can overlap.
2. **Editing phase** - Dispatch subagents with one file each. No overlap.

**Editing subagent rules:**
- Assign one file per subagent to prevent conflicts
- Provide exact code snippets to add/replace
- Run `just analyze` after each batch
- Commit between batches as checkpoints

**Subagents are workers, not planners.** Do planning yourself, give them precise tasks.


