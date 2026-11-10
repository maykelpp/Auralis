import 'package:flutter_test/flutter_test.dart';
import 'package:auralis_player/provider_track.dart';

void main() {
  group('ProviderTrack', () {
    test('does not mistake provider uri for a playable stream', () {
      expect(ProviderTrack.tryParse({
        'title': 'Song', 'uri': 'provider:track:123',
      }), isNull);
    });

    test('accepts a direct HTTPS stream and HTTPS cover', () {
      final track = ProviderTrack.tryParse({
        'id': 'abc', 'title': 'Song', 'artist': 'Artist',
        'stream_url': 'https://media.example/song.mp3',
        'cover_url': 'https://img.example/cover.jpg',
      });
      expect(track, isNotNull);
      expect(track!.streamUrl.host, 'media.example');
      expect(track.coverUrl!.host, 'img.example');
    });

    test('rejects insecure and credential-bearing URLs', () {
      expect(ProviderTrack.tryParse({
        'title': 'Song', 'audio_url': 'http://media.example/song.mp3',
      }), isNull);
      expect(ProviderTrack.tryParse({
        'title': 'Song', 'audio_url': 'https://user:pass@media.example/a.mp3',
      }), isNull);
    });

    test('ignores malformed list entries', () {
      final tracks = ProviderTrack.parseList([
        {'title': 'Good', 'stream_url': 'https://media.example/a.mp3'},
        {'title': 'No stream'},
        'invalid',
      ]);
      expect(tracks, hasLength(1));
    });
  });
}
