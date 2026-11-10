# Auralis v2 - correcciones del Build

Correcciones aplicadas tras el informe de `flutter analyze`:

- `MusicFeedService.merge`: valor por defecto `const []`.
- `AudioCore.playAt`: usa `AudioPlayer.setAudioSources` en lugar del método obsoleto `setAudioSource`.
- Importador ZIP: elimina una comprobación de tipo redundante sobre `ArchiveFile.content`.
- `lyrics.dart`, `pages.dart` y `provider_track.dart`: bloques `if` con llaves.
- Callback SAF: comprueba `context.mounted` antes de usar el contexto después de operaciones asíncronas.
- Workflow: elimina el `test/widget_test.dart` de plantilla que Flutter puede generar y que referencia una clase `MyApp` inexistente.

## Verificación pendiente

Este entorno no tiene Flutter/Dart/Cargo instalados. El ZIP fue creado y su integridad puede comprobarse con `unzip -t`, pero todavía se debe ejecutar GitHub Actions para confirmar análisis, tests y APK Release.
