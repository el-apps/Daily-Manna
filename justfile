# Daily Manna - Justfile
# A Bible memorization app built with Flutter

# Default recipe - show available commands
default:
    @just --list

# Install dependencies
deps:
    flutter pub get

# Clean build artifacts
clean:
    flutter clean

# Full rebuild
rebuild: clean deps gen

# Run code generation (freezed)
gen:
    dart run build_runner build --delete-conflicting-outputs

# Watch for changes and run code generation
watch:
    dart run build_runner watch --delete-conflicting-outputs

# Generate launcher icons
icons:
    dart run flutter_launcher_icons

# Format code
fmt:
    dart format lib test

# Check formatting
fmt-check:
    dart format --set-exit-if-changed lib test

# Analyze code
analyze:
    flutter analyze

# Run tests
test:
    flutter test

# Run tests with coverage
test-cov:
    flutter test --coverage

# Run the app on web (debug mode)
web:
    flutter run -d web-server

# Build web release
build-web:
    flutter build web --release

# Build web production release and start server on 0.0.0.0:8000 (background)
start-web-prod: build-web
    cp web/server.py build/web/server.py
    cd build/web && nohup python3 server.py > server.log 2>&1 &
    @echo "Web server started on 0.0.0.0:8000"

# Stop the production web server running on port 8000
stop-web-prod:
    lsof -ti:8000 | xargs kill -9 2>/dev/null || echo "No server running on port 8000"

# Check production web server logs
logs-web-prod:
    tail -f build/web/server.log

# Run the app on Android
android:
    flutter run -d android

# Build Android APK
build-apk:
    flutter build apk --release

# Build Android App Bundle
build-aab:
    flutter build appbundle --release
