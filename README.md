# Daily Manna 🤗📖
An app for building strong daily habits in interacting with the Word of God.

## Development Setup

### With Nix (NixOS)

A `flake.nix` is provided for reproducible Flutter Android development:

```bash
nix develop                   # Enter the dev environment
```

This provides:
- Flutter (latest stable)
- JDK 17
- Android SDK (API 36, build tools 36.0.0 and 28.0.3, arm64-v8a)
- NDK 26.1
- Proper environment variables (`ANDROID_HOME`, `ANDROID_SDK_ROOT`, `JAVA_HOME`)

Once in the dev shell, run:

```bash
just android                  # Build and run on Android
just build-apk-prod         # Build release APK
just web                      # Run web version
just test                     # Run tests
```

For more details, see the [NixOS Flutter docs](https://nixos.wiki/wiki/Flutter).

### Without Nix

Install Flutter and Android SDK manually following the [official Flutter documentation](https://flutter.dev/docs/get-started/install).

## Sources

KJV Bible in OSIS format is from [here](https://github.com/gratis-bible/bible/blob/master/en/kjv.xml).
