import 'dart:convert';

/// A normalized track returned by a metadata provider.
/// `uri` and provider IDs are identifiers only; playback requires an explicit
/// HTTPS stream URL supplied by the provider.
class ProviderTrack {
  const ProviderTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.streamUrl,
    this.coverUrl,
    this.provider = 'Extensión',
  });

  final String id;
  final String title;
  final String artist;
  final Uri streamUrl;
  final Uri? coverUrl;
  final String provider;

  static ProviderTrack? tryParse(Map<String, dynamic> json,
      {String provider = 'Extensión'}) {
    final title = (json['title'] ?? json['name'])?.toString().trim() ?? '';
    final artist = (json['artist'] ?? json['artists'] ?? 'Artista desconocido').toString();
    final rawStream = json['stream_url'] ?? json['audio_url'];
    if (title.isEmpty || rawStream is! String) return null;
    final stream = Uri.tryParse(rawStream);
    if (stream == null || stream.scheme != 'https' || stream.host.isEmpty ||
        stream.userInfo.isNotEmpty) {
      return null;
    }
    final rawCover = json['cover_url'] ?? json['image_url'];
    Uri? cover;
    if (rawCover is String) {
      final parsed = Uri.tryParse(rawCover);
      if (parsed != null && parsed.scheme == 'https' && parsed.host.isNotEmpty &&
          parsed.userInfo.isEmpty) {
        cover = parsed;
      }
    }
    final id = (json['id'] ?? json['track_id'] ?? stream.toString()).toString();
    return ProviderTrack(id: id, title: title, artist: artist,
        streamUrl: stream, coverUrl: cover, provider: provider);
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'artist': artist,
    'stream_url': streamUrl.toString(),
    if (coverUrl != null) 'cover_url': coverUrl.toString(),
    'provider': provider,
  };

  static List<ProviderTrack> parseList(dynamic value,
      {String provider = 'Extensión'}) {
    if (value is! List) return const [];
    return value.whereType<Map>().map((item) => tryParse(
      Map<String, dynamic>.from(item), provider: provider))
      .whereType<ProviderTrack>().toList(growable: false);
  }

  static String encodeList(List<ProviderTrack> tracks) =>
      jsonEncode(tracks.map((track) => track.toJson()).toList());
}
