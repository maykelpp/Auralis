# Auralis v2 — estado de desarrollo

## Incluido
- Aplicación Flutter con pestañas Inicio, Biblioteca, Buscar, Letras, Extensiones y Ajustes.
- Reproductor con `just_audio` y `just_audio_background`.
- Importación de audio, copia privada, biblioteca persistente, favoritos e historial.
- Puente Android Kotlin para seleccionar una carpeta SAF y sincronizar archivos.
- Letras LRC sincronizadas con la posición del reproductor.
- Catálogo e importación ZIP de extensiones con límites de tamaño, validación de rutas y SHA-256 cuando el registro lo proporciona.
- Adaptador JavaScript con llamadas Promise y transporte JSON.
- Workflow de GitHub Actions para pruebas y APK Release.

## Pendiente / no afirmar como terminado
- Compatibilidad completa con las APIs Mornye (HTTP, storage, auth, file, callbacks, permisos y comportamiento exacto de cada extensión).
- Sandbox y modelo de permisos auditado para ejecutar código de terceros. Por seguridad, las extensiones no deben considerarse activadas para uso general.
- Integración real Rust ↔ Dart mediante FFI/JNI. El crate Rust actual es una base independiente.
- Resolución de URL de plataformas y reproducción protegida/firmada. Solo se aceptan URLs HTTPS directas de audio.
- Pruebas instrumentadas en Android físico, permisos SAF tras reinicio y validación de notificaciones en diferentes versiones Android.

## Verificación
Este entorno de edición no dispone de Flutter, Dart ni Cargo instalados. Por ello no se han ejecutado `flutter analyze`, `flutter test`, `cargo test` ni la compilación APK. El workflow `Actions → Auralis Android APK` ejecuta esas comprobaciones y produce el artefacto Release si todas pasan.
