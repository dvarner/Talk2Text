# Talk2Text Mobile

A cross-platform [Flutter](https://flutter.dev) port of [Talk2Text](../README.md) for **Android and iOS**. Record, speak, and get a transcript — on-device, multilingual, no API keys required.

## Features

- **On-device transcription** via Whisper (whisper.cpp / whisper_ggml) — works fully offline
- **Multiple engines** — on-device Whisper, platform speech-to-text, or a cloud backend (selectable in Settings)
- **Multilingual** — auto-detects and transcribes many languages (Spanish, French, Korean, Japanese, …) in their native script
- **Share-to-Talk2Text** (Android) — share/highlight text into the app to dictate
- **Settings** — engine selection, model, and language options

## Run from source

```bash
cd mobile
flutter pub get
flutter run        # with a device or emulator attached
```

First transcription downloads the Whisper model (~142 MB for base), then runs offline.

### Requirements

- Flutter (stable channel)
- Android: Android SDK + NDK (CI uses NDK 29); `compileSdk` 35+
- iOS: Xcode; running on a physical device needs an Apple Developer account for signing

## Builds (CI)

The [Mobile workflow](../.github/workflows/mobile.yml) runs `flutter analyze`, tests, and builds both platforms on every push that touches `mobile/`:

- **Android** — builds a debug APK and uploads it as the `Talk2Text-Android-debug` artifact. Download it from the latest green run under **Actions → Mobile → Artifacts**.
- **iOS** — compiles an unsigned device build (validates the build without an Apple account).

## Stack

| Package | Purpose |
|---------|---------|
| [whisper_ggml](https://pub.dev/packages/whisper_ggml) | On-device Whisper (whisper.cpp) |
| [record](https://pub.dev/packages/record) | Microphone capture |
| [flutter_riverpod](https://pub.dev/packages/flutter_riverpod) | State management |
| [permission_handler](https://pub.dev/packages/permission_handler) | Mic permissions |

## License

[MIT](../LICENSE)
