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

# Fix lints automatically
fix:
    dart fix --apply lib

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

# Build backend binary
build-backend:
    mkdir -p build
    go build -o build/daily-manna-api ./backend

# Build production assets and restart the systemd backend. Caddy owns port
# 8000, serves build/web, and reverse-proxies /api to the backend on 8080.
# OPENROUTER_API_KEY is read by the systemd backend service.
production: build-web build-backend
    sudo systemctl restart daily-manna-api
    sudo systemctl reload caddy
    @echo "Production web and API are available through Caddy on port 8000"

# Build web production release and start server on 0.0.0.0:8000
start-web-prod: build-web
    cp web/server.py build/web/server.py
    python3 web/server.py 8000

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

# Build Android APK
build-apk-prod:
    flutter build apk --release
