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
    cd backend && go build -o ../build/daily-manna-api .

# Create the PocketBase superuser used to manage the embedded database.
create-superuser:
    #!/usr/bin/env bash
    set -euo pipefail
    : "${DAILY_MANNA_ADMIN_PASSWORD:?Set DAILY_MANNA_ADMIN_PASSWORD to a password}"
    build/daily-manna-api --dir="{{justfile_directory()}}/pb_data" admin create addison@kwila.dev "$DAILY_MANNA_ADMIN_PASSWORD"

# Deploy production assets, install/restart the systemd backend. Caddy owns port
# 8000, serves build/web, and reverse-proxies /api to the backend on 8080.
deploy: build-web build-backend
    #!/usr/bin/env bash
    set -e
    app_dir="{{justfile_directory()}}"

    # Install service unit, pointing at this checkout
    sed "s|__APP_DIR__|$app_dir|g" backend/daily-manna-api.service | sudo tee /etc/systemd/system/daily-manna-api.service >/dev/null
    sudo systemctl daemon-reload
    sudo systemctl enable daily-manna-api
    sudo systemctl restart daily-manna-api

    # Caddy serves build/web and reverse-proxies /api to the backend on 8080.
    # Allow the caddy user to traverse to the web build (execute-only, no listing).
    chmod o+x "$HOME" "$app_dir" "$app_dir/build"
    sudo install -d -m 0755 /opt/daily-manna/build
    sudo ln -sfn "$app_dir/build/web" /opt/daily-manna/build/web
    sudo install -m 0644 backend/Caddyfile /etc/caddy/Caddyfile
    sudo systemctl reload caddy || sudo systemctl restart caddy

    echo "Production web and API are available through Caddy on port 8000"

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
