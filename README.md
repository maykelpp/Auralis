# Auralis v2

Reproductor Android Flutter/Dart con un crate Rust experimental. El estado de implementación y las limitaciones se detallan en [README_V2_PROGRESS.md](README_V2_PROGRESS.md).

## Compilar en GitHub Actions
1. Sube el proyecto a un repositorio GitHub.
2. Abre **Actions → Auralis Android APK → Run workflow**.
3. Si todas las etapas pasan, descarga el artefacto `Auralis-Android-debug`.

El workflow genera el proyecto Android, instala el puente SAF y ejecuta `cargo test`, `flutter analyze`, `flutter test` y `flutter build apk --debug`.

## Compilar localmente
Requisitos: Flutter estable, Rust estable y Android SDK.

```bash
flutter create . --platforms=android --org app.auralis --project-name auralis_player
mkdir -p android/app/src/main/kotlin/app/auralis/auralis_player
cp native/android/MainActivity.kt android/app/src/main/kotlin/app/auralis/auralis_player/MainActivity.kt
flutter pub get
flutter analyze
flutter test
cargo test --manifest-path rust_backend/Cargo.toml
flutter build apk --debug
```

APK esperado: `build/app/outputs/flutter-apk/app-debug.apk`.

**Aviso:** la compatibilidad completa con extensiones Mornye/SpotiFLAC y la reproducción externa aún no están implementadas. No se debe anunciar esta versión como compatible con todas las extensiones.

## Provider playback status
A provider result is playable only when it contains an explicit `stream_url` or
`audio_url` using HTTPS. A provider `uri`/track ID is not an audio URL. The
normalizer and `AudioCore.playProviderTrack()` are present, but they are not yet
connected to a fully compatible Mornye extension runtime. Third-party extension
execution remains disabled/pending until the host APIs and permission sandbox
are implemented and verified.
