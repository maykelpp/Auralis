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
    available = (data['extensions'] as List)
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
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
      final name = entry.name.replaceAll(r'\', '/');
      if (name.startsWith('/') || name.contains(':') ||
          name.split('/').contains('..')) {
        throw const FormatException('Ruta no permitida dentro del ZIP.');
      }
      final content = entry.content;
      if (content is! List<int>) continue;
      expanded += content.length;
      if (expanded > 50 * 1024 * 1024) {
        throw const FormatException('El paquete expandido supera 50 MB.');
      }
      entries[name] = content;
    }
    final manifestBytes = entries['manifest.json'];
    final js = entries['index.js'];
    if (manifestBytes == null || js == null) {
      throw const FormatException('Faltan manifest.json o index.js.');
    }
    final manifest = jsonDecode(utf8.decode(manifestBytes));
    if (manifest is! Map) throw const FormatException('Manifiesto inválido.');
    final id = manifest['name'];
    final name = manifest['displayName'];
    final version = manifest['version'];
    final types = manifest['type'];
    if (id is! String || name is! String || version is! String ||
        types is! List || !RegExp(r'^[a-z0-9._-]+$').hasMatch(id)) {
      throw const FormatException('Campos obligatorios del manifiesto inválidos.');
    }
    final docs = await getApplicationDocumentsDirectory();
    final versionFolder = version.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final dir = Directory('${docs.path}/auralis_extensions/$id/$versionFolder');
    await dir.create(recursive: true);
    await File('${dir.path}/package.zip').writeAsBytes(bytes, flush: true);
    for (final item in entries.entries) {
      final target = File('${dir.path}/${item.key}');
      await target.parent.create(recursive: true);
      await target.writeAsBytes(item.value, flush: true);
    }
    // Intentionally not executed: extension JS must wait for sandbox/runtime
    // and permission-gated host APIs before it can run.
    if (installed.any((e) => e.id == id && e.version == version)) {
      throw const FormatException('Esta versión de la extensión ya está instalada.');
    }
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
    final archive = ZipDecoder().decodeBytes(bytes);
    ArchiveFile? manifestEntry;
    for (final entry in archive) {
      if (entry.isFile && entry.name == 'manifest.json') {
        manifestEntry = entry;
        break;
      }
    }
    if (manifestEntry == null) {
      throw const FormatException('Paquete remoto sin manifest.json.');
    }
    final manifest = jsonDecode(utf8.decode(manifestEntry.content as List<int>));
    if (manifest is! Map || manifest['name'] is! String) {
      throw const FormatException('Manifiesto remoto no válido.');
    }
    final id = manifest['name'] as String;
    final docs = await getApplicationDocumentsDirectory();
    final version = (manifest['version'] as String? ?? '0.0.0').replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final dir = Directory('${docs.path}/auralis_extensions/$id/$version');
    await dir.create(recursive: true);
    await File('${dir.path}/package.zip').writeAsBytes(bytes, flush: true);
    for (final entry in archive.where((e) => e.isFile)) {
      final name = entry.name.replaceAll(r'\', '/');
      if (name.startsWith('/') || name.split('/').contains('..')) continue;
      final target = File('${dir.path}/$name');
      await target.parent.create(recursive: true);
      await target.writeAsBytes(entry.content as List<int>, flush: true);
    }
    final installedVersion = manifest['version'] as String? ?? '0.0.0';
    if (installed.any((e) => e.id == id && e.version == installedVersion)) {
      throw const FormatException('Esta versión de la extensión ya está instalada.');
    }
    installed.add(AuralisExtension(id: id,
      name: manifest['displayName'] as String? ?? id,
      version: installedVersion,
      description: manifest['description'] as String? ?? '',
      types: (manifest['type'] as List? ?? []).whereType<String>().toList(),
      path: dir.path, status: 'Compatibilidad pendiente'));
    await save();
  }
}
