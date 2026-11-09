import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    initialized = true;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('auralis_tracks',
      tracks.map((t) => jsonEncode(t.toJson())).toList());
    await prefs.setStringList('auralis_favorites', favorites.toList());
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

  Future<void> playAt(int index) async {
    if (index < 0 || index >= tracks.length) return;
    currentIndex = index;
    final children = tracks.map((t) => AudioSource.uri(
      Uri.file(t.path), tag: MediaItem(id: t.path, title: t.title, artist: t.artist))).toList();
    await player.setAudioSource(ConcatenatingAudioSource(children: children),
      initialIndex: index);
    await player.play();
  }

  Future<void> toggleFavorite(LocalTrack track) async {
    if (!favorites.add(track.path)) favorites.remove(track.path);
    await _save();
  }

  Future<void> removeTrack(LocalTrack track) async {
    tracks.removeWhere((t) => t.path == track.path);
    favorites.remove(track.path);
    if (currentIndex >= tracks.length) currentIndex = tracks.length - 1;
    await _save();
  }
}
