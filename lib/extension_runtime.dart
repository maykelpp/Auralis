import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_js/flutter_js.dart';

import 'extensions.dart';

/// JS runtime adapter. Only documented host operations are exposed here.
/// It deliberately does not expose Node, arbitrary paths, or raw Dart objects.
class AuralisExtensionRuntime {
  AuralisExtensionRuntime({required this.manager});

  final ExtensionManager manager;
  JavascriptRuntime? _runtime;
  AuralisExtension? _active;
  final Map<String, FutureOr<dynamic> Function(Map<String, dynamic>)> _handlers = {};
  final Set<String> _registeredFunctions = {};
  Map<String, dynamic> _manifest = const {};
  bool _initialized = false;
  Completer<void>? _registrationCompleter;
  int _callSequence = 0;
  final Map<String, Completer<dynamic>> _pendingCalls = {};
  final StreamController<ExtensionEvent> _events =
      StreamController<ExtensionEvent>.broadcast();

  Stream<ExtensionEvent> get events => _events.stream;
  bool get isRunning => _runtime != null;
  String? get activeExtensionId => _active?.id;

  Future<void> start(AuralisExtension extension) async {
    await stop();
    final root = Directory(extension.path);
    final script = File('${root.path}/index.js');
    final manifestFile = File('${root.path}/manifest.json');
    if (!await script.exists() || !await manifestFile.exists()) {
      throw const FormatException('La extensión no contiene manifest.json e index.js.');
    }
    final manifest = jsonDecode(await manifestFile.readAsString());
    if (manifest is! Map || manifest['name'] != extension.id) {
      throw const FormatException('El manifiesto no coincide con la extensión instalada.');
    }
    _manifest = Map<String, dynamic>.from(manifest);
    _registeredFunctions.clear();
    _initialized = false;
    _registrationCompleter = Completer<void>();

    final runtime = getJavascriptRuntime();
    _runtime = runtime;
    _active = extension;
    _registerHandlers();
    runtime.onMessage('auralisHostCall', (dynamic raw) {
      unawaited(_handleHostCall(raw));
    });
    runtime.onMessage('auralisInvokeResult', (dynamic raw) {
      _handleInvokeResult(raw);
    });

    // This shim captures the Mornye registration entry point and provides a
    // narrow async bridge. Compatibility APIs are added only when implemented.
    final bootstrap = '''
      globalThis.__auralisExtension = null;
      globalThis.registerExtension = function(definition) {
        if (!definition || typeof definition !== 'object') {
          throw new Error('registerExtension requires an object');
        }
        globalThis.__auralisExtension = definition;
        sendMessage('auralisHostCall', JSON.stringify({
          id: 'register', method: 'register', payload: {
            name: definition.name || '',
            version: definition.version || '',
            description: definition.description || '',
            types: definition.type || definition.types || [],
            functions: Object.keys(definition)
          }
        }));
      };
      globalThis.auralis = Object.freeze({
        call: function(method, payload) {
          return new Promise(function(resolve, reject) {
            var id = 'c' + Date.now() + Math.random().toString(16).slice(2);
            globalThis.__auralisPending = globalThis.__auralisPending || {};
            globalThis.__auralisPending[id] = {resolve:resolve,reject:reject};
            sendMessage('auralisHostCall', JSON.stringify({id:id,method:method,payload:payload||{}}));
          });
        }
      });
      globalThis.__auralisResolve = function(id, ok, value) {
        var p = globalThis.__auralisPending && globalThis.__auralisPending[id];
        if (!p) return;
        delete globalThis.__auralisPending[id];
        if (ok) p.resolve(value); else p.reject(new Error(String(value)));
      };
    ''';
    runtime.evaluate(bootstrap);
    final source = await script.readAsString();
    final result = runtime.evaluate(source, sourceUrl: 'extension://${extension.id}/index.js');
    if (result.isError) {
      await stop();
      throw FormatException('Error JavaScript: ${result.stringResult}');
    }
    try {
      await _registrationCompleter!.future.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      await stop();
      throw const FormatException('La extensión no llamó registerExtension() correctamente.');
    } catch (_) {
      await stop();
      rethrow;
    }
    _events.add(ExtensionEvent(extension.id, 'loaded', {'name': extension.name}));
  }

  /// Initializes the currently loaded provider using its lifecycle hook.
  Future<dynamic> initializeExtension({Map<String, dynamic> settings = const {}}) async {
    final result = await invoke('initialize', [settings]);
    _initialized = result != false;
    if (!_initialized) throw StateError('La extensión rechazó la inicialización.');
    _events.add(ExtensionEvent(_active?.id ?? '', 'initialized', {}));
    return result;
  }

  /// Calls an exported function. Only functions declared by registerExtension
  /// can be invoked. Values cross the JS/Dart boundary as JSON only.
  Future<dynamic> invoke(String function, [List<dynamic> args = const []]) async {
    final runtime = _runtime;
    if (runtime == null) throw StateError('No hay extensión cargada.');
    if (!_registeredFunctions.contains(function)) {
      throw UnsupportedError('La extensión no exporta $function.');
    }
    if (args.length > 8) throw ArgumentError('Demasiados argumentos.');
    final id = 'invoke_${++_callSequence}';
    final completer = Completer<dynamic>();
    _pendingCalls[id] = completer;
    final encodedArgs = jsonEncode(args);
    final expression = """
      (() => {
        const fn = globalThis.__auralisExtension && globalThis.__auralisExtension[${jsonEncode(function)}];
        if (typeof fn !== 'function') throw new Error('Missing extension function');
        Promise.resolve().then(() => fn.apply(globalThis.__auralisExtension, $encodedArgs))
          .then(value => sendMessage('auralisInvokeResult', JSON.stringify({
            id: ${jsonEncode(id)}, ok: true, value: value === undefined ? null : value
          })))
          .catch(error => sendMessage('auralisInvokeResult', JSON.stringify({
            id: ${jsonEncode(id)}, ok: false, error: String(error && error.message || error)
          })));
      })()
    """;
    final result = runtime.evaluate(expression);
    if (result.isError) {
      _pendingCalls.remove(id);
      throw FormatException('Error en $function: ${result.stringResult}');
    }
    try {
      return await completer.future.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      _pendingCalls.remove(id);
      throw TimeoutException('La función $function superó 30 segundos.');
    }
  }

  void _handleInvokeResult(dynamic raw) {
    try {
      final message = raw is String ? jsonDecode(raw) : raw;
      if (message is! Map || message['id'] is! String) return;
      final completer = _pendingCalls.remove(message['id']);
      if (completer == null || completer.isCompleted) return;
      if (message['ok'] == true) {
        completer.complete(message['value']);
      } else {
        completer.completeError(FormatException(
          message['error']?.toString() ?? 'Error en la extensión.'));
      }
    } catch (_) {
      // Malformed messages are ignored; the invocation will hit its timeout.
    }
  }

  Future<List<Map<String, dynamic>>> searchTracks(String query, {int limit = 20}) async {
    if (!_initialized) await initializeExtension();
    final function = _registeredFunctions.contains('searchTracks')
        ? 'searchTracks' : 'customSearch';
    final safeLimit = limit.clamp(1, 50);
    final result = function == 'searchTracks'
        ? await invoke(function, [query, safeLimit])
        : await invoke(function, [query, {'limit': safeLimit}]);
    if (result is! List) return const [];
    return result.whereType<Map>().map((e) => Map<String, dynamic>.from(e))
        .where((e) => (e['name'] ?? e['title']) is String &&
            ((e['name'] ?? e['title']) as String).trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<Map<String, dynamic>?> getHomeFeed() async {
    if (!_registeredFunctions.contains('getHomeFeed')) return null;
    if (!_initialized) await initializeExtension();
    final result = await invoke('getHomeFeed');
    return result is Map ? Map<String, dynamic>.from(result) : null;
  }

  void _registerHandlers() {
    _handlers
      ..clear()
      ..['register'] = (payload) async {
        final id = _active?.id;
        if (id == null) throw StateError('No hay extensión activa.');
        final functions = (payload['functions'] as List? ?? [])
            .whereType<String>().toSet();
        final types = (_manifest['type'] as List? ?? []).whereType<String>().toSet();
        if (!functions.contains('initialize') || !functions.contains('cleanup')) {
          throw const FormatException('La extensión debe declarar initialize y cleanup.');
        }
        if (types.contains('metadata_provider') &&
            !functions.contains('searchTracks') && !functions.contains('customSearch')) {
          throw const FormatException('Proveedor metadata sin searchTracks ni customSearch.');
        }
        if (types.contains('download_provider') &&
            !{'checkAvailability', 'getDownloadUrl', 'download'}.every(functions.contains)) {
          throw const FormatException('Proveedor download incompleto.');
        }
        _registeredFunctions
          ..clear()
          ..addAll(functions);
        if (!(_registrationCompleter?.isCompleted ?? true)) {
          _registrationCompleter!.complete();
        }
        return {'accepted': true, 'extensionId': id,
          'functions': functions.toList(), 'types': types.toList()};
      }
      ..['extension.getInfo'] = (_) => {
        'id': _active?.id,
        'name': _active?.name,
        'version': _active?.version,
      };
  }

  Future<void> _handleHostCall(dynamic raw) async {
    final runtime = _runtime;
    if (runtime == null) return;
    String? id;
    try {
      final message = raw is String ? jsonDecode(raw) : raw;
      if (message is! Map) throw const FormatException('Mensaje JS inválido.');
      id = message['id'] as String?;
      final method = message['method'];
      final payload = message['payload'];
      if (id == null || method is! String || payload is! Map) {
        throw const FormatException('Llamada JS incompleta.');
      }
      final handler = _handlers[method];
      if (handler == null) {
        throw UnsupportedError('API todavía no implementada: $method');
      }
      final result = await handler(Map<String, dynamic>.from(payload));
      runtime.evaluate('globalThis.__auralisResolve(${jsonEncode(id)},true,${jsonEncode(result)});');
    } catch (error) {
      if (id != null) {
        runtime.evaluate('globalThis.__auralisResolve(${jsonEncode(id)},false,${jsonEncode(error.toString())});');
      }
      _events.add(ExtensionEvent(_active?.id ?? '', 'error', {'message': error.toString()}));
    }
  }

  Future<void> stop() async {
    final runtime = _runtime;
    if (runtime != null && _initialized && _registeredFunctions.contains('cleanup')) {
      try {
        await invoke('cleanup');
      } catch (error) {
        _events.add(ExtensionEvent(_active?.id ?? '', 'cleanup_error',
            {'message': error.toString()}));
      }
    }
    _runtime = null;
    _active = null;
    _initialized = false;
    _registeredFunctions.clear();
    for (final pending in _pendingCalls.values) {
      if (!pending.isCompleted) pending.completeError(StateError('Extensión detenida.'));
    }
    _pendingCalls.clear();
    _manifest = const {};
    _registrationCompleter = null;
    if (runtime != null) {
      try { runtime.dispose(); } catch (_) {}
    }
  }

  Future<void> dispose() async {
    await stop();
    await _events.close();
  }
}

class ExtensionEvent {
  const ExtensionEvent(this.extensionId, this.type, this.data);
  final String extensionId;
  final String type;
  final Map<String, dynamic> data;
}
