# Auralis v2 — preparación de build Android

## Compilación recomendada (GitHub Actions)

1. Sube el contenido de esta carpeta a la rama `main` del repositorio.
2. Abre **Actions → Auralis Android APK → Run workflow**.
3. Espera a que terminen `cargo test`, `flutter analyze`, `flutter test` y `flutter build apk --release`.
4. Descarga el artefacto `Auralis-Android-release` del workflow completado.

El workflow genera el proyecto Android con Flutter, instala el puente SAF Kotlin,
ajusta el manifiesto para reproducción en segundo plano y compila el APK release.

## Compilación local

Requiere Flutter estable, Android SDK/NDK, Java compatible y Rust/Cargo.

```bash
flutter create . --platforms=android --org app.auralis --project-name auralis_player
mkdir -p android/app/src/main/kotlin/app/auralis/auralis_player
cp native/android/MainActivity.kt android/app/src/main/kotlin/app/auralis/auralis_player/MainActivity.kt
python3 tool/prepare_android.py
cargo test --manifest-path rust_backend/Cargo.toml
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

APK esperado: `build/app/outputs/flutter-apk/app-release.apk`.

## Estado real de funciones

- Reproductor Flutter local, importación de archivos, favoritos, historial, letras LRC y puente SAF: implementados en el código fuente; requieren validación en dispositivo.
- Reproducción remota: solo admite URL HTTPS directa validada; no resuelve enlaces de plataformas por sí sola.
- Extensiones: importación y catálogo están preparados, pero las extensiones permanecen sin habilitar automáticamente. No se declara compatibilidad completa Mornye/SpotiFLAC: faltan APIs host, permisos por extensión y pruebas de compatibilidad.
- Rust: crate de base con prueba unitaria; todavía no está conectado a Dart mediante FFI.
- Build: workflow configurado; no se declara compilación exitosa hasta que GitHub Actions termine sin errores.
