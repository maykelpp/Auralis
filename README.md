# Auralis — Android music player (working codename)

Independent Android project. Initial scaffold: Flutter/Dart UI + Rust core workspace. No Mornye source code is copied in this starter.

## Current scope
- Minimalist Material 3 shell: Library, Search, Settings.
- Mini-player placeholder (not yet connected to audio playback).
- Rust core crate with tests.
- GitHub Actions workflow for Rust tests and Android debug APK.

## Build
Requirements: Flutter stable, Rust stable, Android SDK/NDK.

Generate Android platform files if absent:
```bash
flutter create . --platforms=android --org app.auralis
flutter pub get
flutter analyze
flutter test
```
Rust tests:
```bash
cd rust_backend && cargo test
```
Android debug APK:
```bash
flutter build apk --debug
```
Output: `build/app/outputs/flutter-apk/app-debug.apk`

## Roadmap
1. Foundation and Android permissions.
2. Local library via Android Storage Access Framework.
3. Background playback, notification, queue and lock-screen controls.
4. Audio formats, gapless playback and output handling.
5. Equalizer, normalization, synchronized lyrics and visualizer.

The name Auralis is provisional. Change it before public release if desired.
