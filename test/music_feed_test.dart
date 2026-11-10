import 'package:flutter_test/flutter_test.dart';
import 'package:auralis_player/audio_core.dart';
import 'package:auralis_player/music_feed.dart';

void main() {
  group('MusicFeedService', () {
    final service = MusicFeedService();
    test('converts local tracks to feed items', () {
      final feed = service.buildLocalFeed([
        const LocalTrack(path: '/music/a.mp3', title: 'Tema A', artist: 'Artista A'),
      ]);
      expect(feed, hasLength(1));
      expect(feed.single.isLocal, isTrue);
      expect(feed.single.title, 'Tema A');
    });

    test('merges sources and removes duplicate IDs', () {
      const external = MusicFeedItem(
        id: 'provider:1', title: 'Remoto', artist: 'X', source: 'Extensión');
      const duplicate = MusicFeedItem(
        id: 'provider:1', title: 'Duplicado', artist: 'Y', source: 'Otra');
      const local = MusicFeedItem(
        id: 'local:1', title: 'Local', artist: 'Z', source: 'Biblioteca');
      final result = service.merge(local: [local], external: [external, duplicate]);
      expect(result.map((e) => e.id), ['provider:1', 'local:1']);
      expect(result.first.title, 'Remoto');
    });

    test('accepts artwork represented as an object list and rejects HTTP artwork', () {
      final item = MusicFeedItem.fromProvider({
        'id': 'track-8', 'title': 'Tema', 'stream_url': 'https://cdn.example.test/a.mp3',
        'images': [{'url': 'http://insecure.example/cover.jpg'}],
      }, extensionId: 'provider', extensionName: 'Proveedor');
      expect(item.streamUrl, 'https://cdn.example.test/a.mp3');
      expect(item.artworkUrl, isNull);
    });

    test('does not mistake provider URI for a playable audio URL', () {
      final item = MusicFeedItem.fromProvider({
        'id': 'track-7',
        'name': 'Canción',
        'artists': 'Artista',
        'uri': 'provider:track:track-7',
        'images': [{'url': 'https://cdn.example.test/cover.jpg'}],
      }, extensionId: 'provider', extensionName: 'Proveedor');
      expect(item.providerTrackId, 'track-7');
      expect(item.providerUri, 'provider:track:track-7');
      expect(item.streamUrl, isNull);
      expect(item.artworkUrl, 'https://cdn.example.test/cover.jpg');
    });
  });
}
