import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'provider_track.dart';

class LocalTrack {
  const LocalTrack({required this.path, required this.title, this.artist = 'Artista desconocido'});
  final String path, title, artist;
  Map<String, dynamic> toJson() => {'path': path, 'title': title, 'artist': artist};
  factory LocalTrack.fromJson(Map<String, dynamic> j) => LocalTrack(
    path: j['path'] as String, title: j['title'] as String,
    artist: j['artist'] as String? ?? 'Artista desconocido');
}

class AudioCore {
  AudioCore._();
  static final AudioCore instance = AudioCore._();
  final AudioPlayer player = AudioPlayer();
  final List<LocalTrack> tracks = [];
  final Set<String> favorites = {};
  final List<String> history = [];
  int currentIndex = -1;
  bool initialized = false;

  Future<void> initialize() async {
    if (initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('auralis_tracks') ?? [];
    for (final item in raw) {
      try {
        final track = LocalTrack.fromJson(jsonDecode(item) as Map<String, dynamic>);
        if (await File(track.path).exists()) tracks.add(track);
      } catch (_) {}
    }
    favorites.addAll(prefs.getStringList('auralis_favorites') ?? []);
    history.addAll(prefs.getStringList('auralis_history') ?? []);
    history.removeWhere((path) => !tracks.any((track) => track.path == path));
    initialized = true;
    try { await syncPersistentMusicFolder(); } catch (_) { /* SAF puede no estar disponible fuera de Android. */ }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('auralis_tracks',
      tracks.map((t) => jsonEncode(t.toJson())).toList());
    await prefs.setStringList('auralis_favorites', favorites.toList());
    await prefs.setStringList('auralis_history', history.take(100).toList());
  }

  List<LocalTrack> get favoriteTracks => tracks
      .where((track) => favorites.contains(track.path)).toList(growable: false);

  List<LocalTrack> get recentTracks => history
      .map((path) => tracks.where((track) => track.path == path).firstOrNull)
      .whereType<LocalTrack>().toList(growable: false);

  Future<void> _recordPlayed(LocalTrack track) async {
    history.remove(track.path);
    history.insert(0, track.path);
    if (history.length > 100) history.removeRange(100, history.length);
    await _save();
  }

  Future<int> importAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio, allowMultiple: true, withData: false);
    if (result == null) return 0;
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/music');
    await folder.create(recursive: true);
    var added = 0;
    for (final item in result.files) {
      final source = item.path;
      if (source == null) continue;
      final safeName = item.name.replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_');
      final target = File('${folder.path}/$safeName');
      if (!await target.exists()) await File(source).copy(target.path);
      final track = LocalTrack(path: target.path,
        title: item.name.replaceAll(RegExp(r'\.[^.]+$'), ''));
      if (!tracks.any((t) => t.path == track.path)) {
        tracks.add(track);
        added++;
      }
    }
    await _save();
    return added;
  }

  static const MethodChannel _saf = MethodChannel('app.auralis/saf');

  Future<int> importMusicFolderSaf() async {
    final rows = await _saf.invokeListMethod<dynamic>('selectMusicFolder');
    if (rows == null || rows.isEmpty) return 0;
    var added = 0;
    for (final row in rows) {
      if (row is! Map) continue;
      final path = row['path'];
      final title = row['title'];
      if (path is! String || title is! String ||
          tracks.any((track) => track.path == path)) continue;
      tracks.add(LocalTrack(path: path, title: title,
          artist: row['artist'] as String? ?? 'Artista desconocido'));
      added++;
    }
    await _save();
    return added;
  }

  Future<bool> hasPersistentMusicFolder() async {
    try { return await _saf.invokeMethod<bool>('hasMusicFolder') ?? false; }
    on PlatformException { return false; }
  }

  Future<int> syncPersistentMusicFolder() async {
    final rows = await _saf.invokeListMethod<dynamic>('syncMusicFolder');
    if (rows == null || rows.isEmpty) return 0;
    var added = 0;
    for (final row in rows) {
      if (row is! Map) continue;
      final path = row['path'];
      final title = row['title'];
      if (path is! String || title is! String ||
          tracks.any((track) => track.path == path)) continue;
      tracks.add(LocalTrack(path: path, title: title,
          artist: row['artist'] as String? ?? 'Artista desconocido'));
      added++;
    }
    if (added > 0) await _save();
    return added;
  }

  Future<int> importFolder() async {
    final selected = await FilePicker.platform.getDirectoryPath();
    if (selected == null) return 0;
    final sourceDir = Directory(selected);
    if (!await sourceDir.exists()) return 0;
    final appDir = await getApplicationDocumentsDirectory();
    final destination = Directory('${appDir.path}/music');
    await destination.create(recursive: true);
    const allowed = {'.mp3', '.m4a', '.aac', '.flac', '.wav', '.ogg', '.opus', '.wma'};
    var added = 0;
    await for (final entity in sourceDir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final extension = entity.path.contains('.')
          ? '.${entity.path.split('.').last.toLowerCase()}' : '';
      if (!allowed.contains(extension)) continue;
      final base = entity.uri.pathSegments.isEmpty
          ? 'audio$extension' : entity.uri.pathSegments.last;
      final safe = base.replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_');
      var target = File('${destination.path}/$safe');
      var suffix = 1;
      while (await target.exists()) {
        final dot = safe.lastIndexOf('.');
        final stem = dot > 0 ? safe.substring(0, dot) : safe;
        final ext = dot > 0 ? safe.substring(dot) : '';
        target = File('${destination.path}/${stem}_$suffix$ext');
        suffix++;
      }
      await entity.copy(target.path);
      tracks.add(LocalTrack(path: target.path,
        title: safe.replaceFirst(RegExp(r'\.[^.]+$'), '')));
      added++;
    }
    await _save();
    return added;
  }

  Future<void> playAt(int index) async {
    if (index < 0 || index >= tracks.length) return;
    currentIndex = index;
    final children = tracks.map((t) => AudioSource.uri(
      Uri.file(t.path), tag: MediaItem(id: t.path, title: t.title, artist: t.artist))).toList();
    await player.setAudioSources(children, initialIndex: index);
    await player.play();
    await _recordPlayed(tracks[index]);
  }

  Future<void> next() async {
    if (player.hasNext) {
      await player.seekToNext();
      final tag = player.sequenceState.currentSource?.tag;
      if (tag is MediaItem) {
        final track = tracks.where((t) => t.path == tag.id).firstOrNull;
        if (track != null) await _recordPlayed(track);
      }
    }
  }

  Future<void> previous() async {
    if (player.hasPrevious) {
      await player.seekToPrevious();
    } else {
      await player.seek(Duration.zero);
    }
  }

  /// Plays a provider track only when it contains a validated HTTPS stream URL.
  /// Provider IDs and generic `uri` fields are never treated as playable media.
  Future<void> playProviderTrack(ProviderTrack track) async {
    if (track.streamUrl.scheme != 'https' || track.streamUrl.host.isEmpty ||
        track.streamUrl.userInfo.isNotEmpty) {
      throw const FormatException('La URL de audio no es segura.');
    }
    currentIndex = -1;
    await player.setAudioSource(AudioSource.uri(
      track.streamUrl,
      tag: MediaItem(
        id: track.id,
        title: track.title,
        artist: track.artist,
        album: track.provider,
        artUri: track.coverUrl,
      ),
    ));
    await player.play();
  }

  Future<void> toggleFavorite(LocalTrack track) async {
    if (!favorites.add(track.path)) favorites.remove(track.path);
    await _save();
  }

  Future<void> removeTrack(LocalTrack track) async {
    tracks.removeWhere((t) => t.path == track.path);
    favorites.remove(track.path);
    history.remove(track.path);
    if (currentIndex >= tracks.length) currentIndex = tracks.length - 1;
    await _save();
  }
}
