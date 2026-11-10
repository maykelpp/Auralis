import 'audio_core.dart';

class MusicFeedItem {
  const MusicFeedItem({required this.id, required this.title,
    required this.artist, required this.source, this.localTrack,
    this.artworkUrl, this.streamUrl, this.extensionId,
    this.providerTrackId, this.providerUri});
  final String id, title, artist, source;
  final LocalTrack? localTrack;
  final String? artworkUrl, streamUrl, extensionId, providerTrackId, providerUri;
  bool get isLocal => localTrack != null;

  factory MusicFeedItem.fromProvider(Map<String, dynamic> item,
      {required String extensionId, required String extensionName}) {
    final id = item['id']?.toString() ?? '';
    final title = item['name']?.toString() ?? item['title']?.toString() ?? '';
    final artist = item['artists']?.toString() ?? item['artist']?.toString() ?? 'Artista desconocido';
    final images = item['images'];
    String? image;
    if (images is String) image = images;
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      if (first is String) image = first;
      if (first is Map) image = first['url']?.toString();
    }
    image ??= item['cover_url']?.toString() ?? item['image_url']?.toString();
    // Mornye `uri` is a provider/deep-link identifier, not necessarily an
    // audio stream. Never pass it to the audio engine as a playable URL.
    final providerUri = item['uri']?.toString();
    final stream = item['stream_url']?.toString() ?? item['audio_url']?.toString();
    return MusicFeedItem(id: '$extensionId:$id', title: title,
      artist: artist, source: extensionName, extensionId: extensionId,
      artworkUrl: _https(image), streamUrl: _https(stream),
      providerTrackId: id, providerUri: providerUri);
  }

  static String? _https(String? value) {
    if (value == null) return null;
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' ? value : null;
  }
}

class MusicFeedService {
  List<MusicFeedItem> buildLocalFeed(List<LocalTrack> tracks) => tracks
      .map((track) => MusicFeedItem(id: 'local:${track.path}',
        title: track.title, artist: track.artist, source: 'Biblioteca',
        localTrack: track)).toList(growable: false);

  List<MusicFeedItem> merge({required List<MusicFeedItem> local,
    List<MusicFeedItem> external = []}) {
    final seen = <String>{};
    final result = <MusicFeedItem>[];
    for (final item in [...external, ...local]) {
      if (item.title.trim().isNotEmpty && seen.add(item.id)) result.add(item);
    }
    return result;
  }
}
