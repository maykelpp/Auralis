import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuralisExtension {
  const AuralisExtension({required this.id, required this.name,
    required this.version, required this.description, required this.types,
    required this.path, required this.status});
  final String id, name, version, description, path, status;
  final List<String> types;
  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'version': version, 'description': description,
    'types': types, 'path': path, 'status': status};
  factory AuralisExtension.fromJson(Map<String, dynamic> j) => AuralisExtension(
    id: j['id'] as String, name: j['name'] as String,
    version: j['version'] as String, description: j['description'] as String? ?? '',
    types: List<String>.from(j['types'] as List? ?? []),
    path: j['path'] as String? ?? '',
    status: j['status'] as String? ?? 'Compatibilidad pendiente');
}

class ExtensionManager {
  static String _validatedArchivePath(String raw) {
    final name = raw.replaceAll(r'\', '/');
    final parts = name.split('/');
    if (name.isEmpty || name.startsWith('/') || name.contains(':') ||
        name.contains('\u0000') || parts.any((part) => part == '..' || part == '.')) {
      throw const FormatException('Ruta no permitida dentro del paquete.');
    }
    return name;
  }

  static const officialRepo =
    'https://raw.githubusercontent.com/mornyeapp/Mornye-Extension/main/registry.json';
  final List<AuralisExtension> installed = [];
  List<Map<String, dynamic>> available = [];

  Future<File> _catalog() async {
    final d = await getApplicationDocumentsDirectory();
    final dir = Directory('${d.path}/auralis_extensions');
    await dir.create(recursive: true);
    return File('${dir.path}/catalog.json');
  }

  Future<void> load() async {
    final f = await _catalog();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('auralis_extensions') ?? '[]';
    try {
      final data = jsonDecode(raw) as List;
      installed
        ..clear()
        ..addAll(data.map((e) => AuralisExtension.fromJson(
          Map<String, dynamic>.from(e as Map))));
    } catch (_) {}
    if (!await f.exists()) await f.writeAsString('[]');
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auralis_extensions',
      jsonEncode(installed.map((e) => e.toJson()).toList()));
  }

  Future<void> refreshRepository(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') {
      throw const FormatException('El repositorio debe usar HTTPS.');
    }
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw HttpException('Repositorio respondió ${response.statusCode}');
    }
    final data = jsonDecode(response.body);
    if (data is! Map || data['extensions'] is! List) {
      throw const FormatException('El registro no tiene formato reconocido.');
    }
    // Mornye registry uses id/name/display_name, download_url and sha256.
    // Normalize display_name for the UI while preserving the upstream fields.
    available = (data['extensions'] as List)
      .whereType<Map>()
      .map((entry) {
        final item = Map<String, dynamic>.from(entry);
        item['displayName'] = item['display_name'] ?? item['name'] ?? item['id'];
        item['id'] = item['id'] ?? item['name'];
        return item;
      })
      .where((item) => item['id'] is String &&
        item['download_url'] is String &&
        (item['download_url'] as String).startsWith('https://'))
      .toList();
  }

  Future<void> importPackage() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['spotiflac-ext', 'sflx', 'zip'],
      withData: true);
    if (picked == null || picked.files.isEmpty) return;
    final bytes = picked.files.single.bytes;
    if (bytes == null || bytes.length > 20 * 1024 * 1024) {
      throw const FormatException('No se pudo leer el paquete o supera 20 MB.');
    }
    final archive = ZipDecoder().decodeBytes(bytes);
    final entries = <String, List<int>>{};
    var expanded = 0;
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final name = _validatedArchivePath(entry.name);
      if (entries.containsKey(name)) {
        throw const FormatException('El ZIP contiene rutas duplicadas.');
      }
      final content = entry.content;
      if (content is! List<int>) continue;
      expanded += content.length;
      if (expanded > 50 * 1024 * 1024) {
        throw const FormatException('El paquete expandido supera 50 MB.');
      }
      entries[name] = content;
    }
    var normalized = entries;
    if (!normalized.containsKey('manifest.json')) {
      final roots = normalized.keys.where((k) => k.endsWith('/manifest.json')).toList();
      if (roots.length == 1) {
        final prefix = roots.single.substring(0, roots.single.length - 'manifest.json'.length);
        normalized = {for (final e in entries.entries) if (e.key.startsWith(prefix)) e.key.substring(prefix.length): e.value};
      }
    }
    final manifestBytes = normalized['manifest.json'];
    final js = normalized['index.js'];
    if (manifestBytes == null || js == null) {
      throw const FormatException('Faltan manifest.json o index.js.');
    }
    final manifest = jsonDecode(utf8.decode(manifestBytes));
    if (manifest is! Map) throw const FormatException('Manifiesto inválido.');
    final id = manifest['name'];
    final name = manifest['displayName'] ?? manifest['display_name'] ?? id;
    final version = manifest['version'];
    final types = manifest['type'];
    if (id is! String || name is! String || version is! String ||
        types is! List || !RegExp(r'^[a-z0-9._-]+$').hasMatch(id)) {
      throw const FormatException('Campos obligatorios del manifiesto inválidos.');
    }
    if (installed.any((e) => e.id == id && e.version == version)) {
      throw const FormatException('Esta versión de la extensión ya está instalada.');
    }
    final docs = await getApplicationDocumentsDirectory();
    final versionFolder = version.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final dir = Directory('${docs.path}/auralis_extensions/$id/$versionFolder');
    await dir.create(recursive: true);
    await File('${dir.path}/package.zip').writeAsBytes(bytes, flush: true);
    for (final item in normalized.entries) {
      final target = File('${dir.path}/${item.key}');
      await target.parent.create(recursive: true);
      await target.writeAsBytes(item.value, flush: true);
    }
    // Installed but disabled until all declared host APIs are supported.
    installed.add(AuralisExtension(id: id, name: name, version: version,
      description: manifest['description'] as String? ?? '',
      types: types.whereType<String>().toList(), path: dir.path,
      status: 'Compatibilidad pendiente'));
    await save();
  }

  Future<void> installFromRegistry(Map<String, dynamic> item) async {
    final url = item['download_url'];
    if (url is! String || !url.startsWith('https://')) {
      throw const FormatException('URL de descarga no válida.');
    }
    final response = await http.get(Uri.parse(url)).timeout(
      const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw HttpException('Descarga respondió ${response.statusCode}');
    }
    final bytes = response.bodyBytes;
    final expected = item['sha256'];
    if (expected is String && expected.isNotEmpty) {
      final actual = sha256.convert(bytes).toString();
      if (actual.toLowerCase() != expected.toLowerCase()) {
        throw const FormatException('La verificación SHA-256 del paquete falló.');
      }
    }
    if (bytes.length > 20 * 1024 * 1024) throw const FormatException('Paquete remoto demasiado grande.');
    final archive = ZipDecoder().decodeBytes(bytes);
    ArchiveFile? manifestEntry;
    for (final entry in archive) {
      if (entry.isFile && (entry.name == 'manifest.json' || entry.name.endsWith('/manifest.json'))) {
        manifestEntry = entry;
      }
    }
    if (manifestEntry == null) {
      throw const FormatException('Paquete remoto sin manifest.json.');
    }
    final prefix = manifestEntry.name == 'manifest.json' ? '' : manifestEntry.name.substring(0, manifestEntry.name.length - 'manifest.json'.length);
    final manifest = jsonDecode(utf8.decode(manifestEntry.content as List<int>));
    if (manifest is! Map || manifest['name'] is! String) {
      throw const FormatException('Manifiesto remoto no válido.');
    }
    final id = manifest['name'] as String;
    if (!RegExp(r'^[a-z0-9._-]+$').hasMatch(id)) {
      throw const FormatException('ID remoto inválido.');
    }
    final installedVersion = manifest['version'] as String? ?? '0.0.0';
    if (item['id'] is String && item['id'] != id) {
      throw const FormatException('El ID del catálogo no coincide con el manifiesto.');
    }
    if (installed.any((e) => e.id == id && e.version == installedVersion)) {
      throw const FormatException('Esta versión de la extensión ya está instalada.');
    }
    final files = <MapEntry<String, List<int>>>[];
    var expandedBytes = 0;
    for (final entry in archive.where((e) => e.isFile)) {
      var name = _validatedArchivePath(entry.name);
      if (prefix.isNotEmpty) {
        if (!name.startsWith(prefix)) continue;
        name = name.substring(prefix.length);
      }
      name = _validatedArchivePath(name);
      if (files.any((file) => file.key == name)) {
        throw const FormatException('El ZIP remoto contiene rutas duplicadas.');
      }
      final content = List<int>.from(entry.content as List);
      expandedBytes += content.length;
      if (expandedBytes > 50 * 1024 * 1024) {
        throw const FormatException('Paquete remoto expandido supera 50 MB.');
      }
      files.add(MapEntry(name, content));
    }
    if (!files.any((e) => e.key == 'manifest.json') ||
        !files.any((e) => e.key == 'index.js')) {
      throw const FormatException('Paquete remoto incompleto: falta manifest.json o index.js.');
    }
    final docs = await getApplicationDocumentsDirectory();
    final version = installedVersion.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final dir = Directory('${docs.path}/auralis_extensions/$id/$version');
    await dir.create(recursive: true);
    try {
      await File('${dir.path}/package.zip').writeAsBytes(bytes, flush: true);
      for (final file in files) {
        final target = File('${dir.path}/${file.key}');
        await target.parent.create(recursive: true);
        await target.writeAsBytes(file.value, flush: true);
      }
    } catch (_) {
      if (await dir.exists()) await dir.delete(recursive: true);
      rethrow;
    }
    installed.add(AuralisExtension(id: id,
      name: manifest['displayName'] as String? ?? manifest['display_name'] as String? ?? id,
      version: installedVersion,
      description: manifest['description'] as String? ?? '',
      types: (manifest['type'] as List? ?? []).whereType<String>().toList(),
      path: dir.path, status: 'Compatibilidad pendiente'));
    await save();
  }
}
