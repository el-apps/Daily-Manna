# Daily Manna - Justfile
# A Bible memorization app built with Flutter

# Default recipe - show available commands
default:
    @just --list

# Install dependencies
deps:
    flutter pub get

# Run code generation (freezed)
gen:
    dart run build_runner build --delete-conflicting-outputs

# Watch for changes and run code generation
watch:
    dart run build_runner watch --delete-conflicting-outputs

# Run the app on web (debug mode)
web:
    flutter run -d web-server --web-port=8000 --web-hostname=0.0.0.0

# Run the app on Android
android:
    flutter run -d android

# Build web release
build-web:
    flutter build web --release

# Build Android APK
build-apk:
    flutter build apk --release

# Build Android App Bundle
build-aab:
    flutter build appbundle --release

# Run tests
test:
    flutter test

# Run tests with coverage
test-cov:
    flutter test --coverage

# Analyze code
analyze:
    flutter analyze

# Format code
fmt:
    dart format lib test

# Check formatting
fmt-check:
    dart format --set-exit-if-changed lib test

# Clean build artifacts
clean:
    flutter clean

# Full rebuild
rebuild: clean deps gen

# Serve the web build (after building)
serve-web:
    cd build/web && python3 -m http.server 8000

# Generate launcher icons
icons:
    dart run flutter_launcher_icons
