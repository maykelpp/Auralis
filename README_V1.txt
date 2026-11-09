AURALIS v1.0 CORE SYSTEM - CÓDIGO FUENTE

Incluye:
- Reproducción local con just_audio.
- Notificación/reproducción de fondo mediante just_audio_background.
- Importación de archivos de audio y copia a almacenamiento privado.
- Biblioteca persistente y favoritos.
- Búsqueda local.
- Parser LRC y resaltado sincronizado por posición.
- Catálogo remoto Mornye y gestor de paquetes .spotiflac-ext/.sflx.
- Conservación de extensiones no compatibles.

LÍMITES QUE NO SE DEBEN CONFUNDIR CON FUNCIONES TERMINADAS:
- No incluye todavía escaneo automático MediaStore de toda la memoria.
- No incluye runtime JavaScript sandbox; los scripts se almacenan, NO se ejecutan.
- No incluye todavía la totalidad de las APIs de Mornye (HTTP, storage, file, credentials, auth, crypto, FFmpeg, OAuth, download, etc.).
- No incluye streaming de un catálogo musical universal.
- No incluye descargador de vídeos de plataformas.
- La compatibilidad de cada extensión requiere implementar las APIs que utiliza y respetar derechos y términos de la fuente.

APLICAR:
Descomprime el ZIP sobre la raíz del proyecto existente. Luego:
flutter pub get
flutter analyze
flutter test

El proyecto original genera android/ durante GitHub Actions. El plugin just_audio_background debe integrar su servicio mediante manifest merger. Si el proyecto ya tiene android/, revisa la fusión de manifiestos.

NO EJECUTAR BUILD TODAVÍA: primero resolver todos los errores de análisis y completar la integración del runtime de extensiones.
