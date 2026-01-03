# Daily Manna 🤗📖
An app for building strong daily habits in interacting with the Word of God.

## Development Setup

### With Nix (NixOS)

A reproducible Nix flake is provided using [android-nixpkgs](https://github.com/tadfisher/android-nixpkgs):

```bash
just nix-shell                # Enter the dev environment (updates flake first)
```

Or manually:

```bash
nix flake update              # Update flake inputs
nix develop                   # Enter the dev environment
```

This provides:
- Flutter (latest stable)
- JDK (default version)
- Android SDK (API 36, build-tools-36.0.0)
- NDK 26.1
- Gradle
- Git and Just for task automation
- Proper environment variables (`ANDROID_HOME`, `ANDROID_SDK_ROOT`, `JAVA_HOME`)

Once in the dev shell, run:

```bash
just android                  # Build and run on Android
just build-apk-prod         # Build release APK
just web                      # Run web version
just test                     # Run tests
just format                   # Format code
just analyze                  # Analyze code
```

The flake uses [android-nixpkgs](https://github.com/tadfisher/android-nixpkgs) for reproducible Android SDK packaging, updated daily from Google's repositories.

### Without Nix

Install Flutter and Android SDK manually following the [official Flutter documentation](https://flutter.dev/docs/get-started/install).

## Sources

KJV Bible in OSIS format is from [here](https://github.com/gratis-bible/bible/blob/master/en/kjv.xml).
