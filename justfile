# Default recipe - show available commands
default:
    @just --list

# Clean build artifacts
clean:
    flutter clean

# Run code generation (freezed)
gen:
    flutter pub run build_runner build --delete-conflicting-outputs

# Format code
format:
    dart format lib test

# Analyze code
analyze:
    flutter analyze

# Run tests
test:
    flutter test

# Run the app on web (debug mode)
web:
    flutter run -d web-server

# Build web release
build-web:
    flutter build web --release

# Build web production release and start server on 0.0.0.0:8000 (background)
start-web-prod: build-web
    cp web/server.py build/web/server.py
    cd build/web && nohup python3 server.py 8000 > server.log 2>&1 &
    @echo "Web server started on 0.0.0.0:8000"

# Stop the production web server running on port 8000
stop-web-prod:
    lsof -ti:8000 | xargs kill -9 2>/dev/null || echo "No server running on port 8000"

# Check production web server logs
logs-web-prod:
    tail -f build/web/server.log

# Run the app on Android (first device)
run-android:
    #!/usr/bin/env bash
    device=$(flutter devices | grep android | awk -F'•' '{print $2}' | head -1 | xargs);
    if [ -z "$device" ]; then
      echo "No Android device found"
      flutter devices
      exit 1
    fi
    flutter run -d "$device"

# Run the app on Android through nix shell
run-android-nix:
    nix develop -c "just run-android"

# Build Android APK
build-apk-prod:
    flutter build apk --release
