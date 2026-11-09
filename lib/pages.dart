import 'package:file_picker/file_picker.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'audio_core.dart';
import 'extensions.dart';
import 'lyrics.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final core = AudioCore.instance;
  int tab = 0;
  bool ready = false;
  final pages = const [
    LibraryPage(), SearchPage(), LyricsPage(), ExtensionsPage(), SettingsPage()
  ];
  final labels = const ['Biblioteca', 'Buscar', 'Letras', 'Extensiones', 'Ajustes'];

  @override
  void initState() {
    super.initState();
    core.initialize().then((_) {
      if (mounted) {
        setState(() => ready = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Auralis · ${labels[tab]}')),
    body: !ready ? const Center(child: CircularProgressIndicator())
      : Column(children: [
        Expanded(child: IndexedStack(index: tab, children: pages)),
        const MiniPlayer(),
      ]),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (v) => setState(() => tab = v),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.library_music), label: 'Música'),
        NavigationDestination(icon: Icon(Icons.search), label: 'Buscar'),
        NavigationDestination(icon: Icon(Icons.lyrics_outlined), label: 'Letras'),
        NavigationDestination(icon: Icon(Icons.extension_outlined), label: 'Extensiones'),
        NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Ajustes'),
      ],
    ),
  );
}

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}
class _LibraryPageState extends State<LibraryPage> {
  final core = AudioCore.instance;
  Future<void> add() async {
    try {
      final n = await core.importAudio();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(n == 0 ? 'No se importaron archivos' : '$n canciones importadas')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')));
    }
  }
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text('Tu música, a tu manera',
        style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 6),
      Text('${core.tracks.length} canciones en este dispositivo',
        style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 16),
      FilledButton.icon(onPressed: add,
        icon: const Icon(Icons.add), label: const Text('Importar música')),
      const SizedBox(height: 12),
      if (core.tracks.isEmpty)
        const Card(child: Padding(padding: EdgeInsets.all(24),
          child: Column(children: [
            Icon(Icons.music_off_outlined, size: 44),
            SizedBox(height: 10), Text('Tu biblioteca está vacía'),
            Text('Importa archivos de audio para empezar.')
          ])))
      else ...[
        Text('Todas las canciones',
          style: Theme.of(context).textTheme.titleLarge),
        for (var i = 0; i < core.tracks.length; i++)
          TrackTile(track: core.tracks[i], index: i,
            onChanged: () => setState(() {})),
      ],
    ],
  );
}

class TrackTile extends StatelessWidget {
  const TrackTile({super.key, required this.track, required this.index,
    this.onChanged});
  final LocalTrack track;
  final int index;
  final VoidCallback? onChanged;
  @override
  Widget build(BuildContext context) {
    final core = AudioCore.instance;
    final favorite = core.favorites.contains(track.path);
    return Card(child: ListTile(
      leading: const CircleAvatar(child: Icon(Icons.music_note)),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(track.artist),
      onTap: () => core.playAt(index),
      trailing: IconButton(
        icon: Icon(favorite ? Icons.favorite : Icons.favorite_border),
        onPressed: () async { await core.toggleFavorite(track); onChanged?.call(); },
      ),
    ));
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}
class _SearchPageState extends State<SearchPage> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final tracks = AudioCore.instance.tracks.where((t) =>
      ('${t.title} ${t.artist}').toLowerCase().contains(query.toLowerCase())).toList();
    return Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      TextField(onChanged: (v) => setState(() => query = v),
        decoration: const InputDecoration(
          hintText: 'Buscar en tu biblioteca',
          prefixIcon: Icon(Icons.search), border: OutlineInputBorder())),
      const SizedBox(height: 12),
      Expanded(child: ListView(children: [
        for (final track in tracks)
          TrackTile(track: track, index: AudioCore.instance.tracks.indexOf(track)),
        if (query.isNotEmpty && tracks.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(24),
            child: Text('No hay coincidencias en tu biblioteca local.'))),
      ])),
    ]));
  }
}

class LyricsPage extends StatefulWidget {
  const LyricsPage({super.key});
  @override
  State<LyricsPage> createState() => _LyricsPageState();
}
class _LyricsPageState extends State<LyricsPage> {
  List<LyricLine> lines = [];
  String? loadedFor;
  Future<void> loadLrc() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['lrc', 'txt'], withData: true);
    if (result == null || result.files.single.bytes == null) return;
    final source = String.fromCharCodes(result.files.single.bytes!);
    setState(() { lines = LrcLyrics.parse(source); loadedFor = result.files.single.name; });
  }
  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.all(16), child: Row(children: [
      Expanded(child: Text(loadedFor ?? 'Letras sincronizadas (.LRC)',
        maxLines: 1, overflow: TextOverflow.ellipsis)),
      FilledButton.tonalIcon(onPressed: loadLrc,
        icon: const Icon(Icons.file_open), label: const Text('Abrir LRC')),
    ])),
    Expanded(child: StreamBuilder<Duration>(
      stream: AudioCore.instance.player.positionStream,
      builder: (context, snapshot) {
        final active = LrcLyrics.activeIndex(lines, snapshot.data ?? Duration.zero);
        if (lines.isEmpty) return const Center(child: Text(
          'Importa un archivo LRC para ver las letras sincronizadas.'));
        return ListView.builder(itemCount: lines.length,
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(lines[i].text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: i == active ? 22 : 16,
                fontWeight: i == active ? FontWeight.bold : FontWeight.normal,
                color: i == active ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant)),
          ));
      },
    )),
  ]);
}

class ExtensionsPage extends StatefulWidget {
  const ExtensionsPage({super.key});
  @override
  State<ExtensionsPage> createState() => _ExtensionsPageState();
}
class _ExtensionsPageState extends State<ExtensionsPage> {
  final manager = ExtensionManager();
  bool loading = true, busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    manager.load().then((_) { if (mounted) setState(() => loading = false); });
  }
  Future<void> refresh() async {
    setState(() { busy = true; error = null; });
    try {
      await manager.refreshRepository(ExtensionManager.officialRepo);
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => busy = false);
  }
  Future<void> importLocal() async {
    setState(() { busy = true; error = null; });
    try { await manager.importPackage(); }
    catch (e) { error = e.toString(); }
    if (mounted) setState(() => busy = false);
  }
  Future<void> install(Map<String, dynamic> item) async {
    setState(() { busy = true; error = null; });
    try { await manager.installFromRegistry(item); }
    catch (e) { error = e.toString(); }
    if (mounted) setState(() => busy = false);
  }
  @override
  Widget build(BuildContext context) => loading
    ? const Center(child: CircularProgressIndicator())
    : ListView(padding: const EdgeInsets.all(16), children: [
      const Card(child: Padding(padding: EdgeInsets.all(14), child: Text(
        'Los paquetes se conservan aunque no sean compatibles. Las APIs '
        'faltantes se irán agregando paulatinamente. Los scripts JavaScript '
        'no se ejecutan hasta integrar un runtime aislado y sus permisos.'))),
      Row(children: [
        Expanded(child: FilledButton.icon(onPressed: busy ? null : refresh,
          icon: const Icon(Icons.refresh), label: const Text('Catálogo Mornye'))),
        const SizedBox(width: 8),
        IconButton(onPressed: busy ? null : importLocal,
          icon: const Icon(Icons.file_open), tooltip: 'Importar paquete'),
      ]),
      if (busy) const LinearProgressIndicator(),
      if (error != null) Text(error!,
        style: TextStyle(color: Theme.of(context).colorScheme.error)),
      Text('Instaladas (${manager.installed.length})',
        style: Theme.of(context).textTheme.titleLarge),
      for (final e in manager.installed)
        Card(child: ListTile(
          leading: const Icon(Icons.extension),
          title: Text(e.name),
          subtitle: Text('${e.version} · ${e.status}'),
          trailing: const Icon(Icons.info_outline),
        )),
      const SizedBox(height: 16),
      Text('Repositorio (${manager.available.length})',
        style: Theme.of(context).textTheme.titleLarge),
      for (final item in manager.available)
        Card(child: ListTile(
          title: Text(item['display_name'] as String? ??
            item['name'] as String? ?? 'Extensión'),
          subtitle: Text('${item['description'] ?? ''}\n'
            'Versión ${item['version'] ?? '?'} · Requiere Auralis compatible'),
          isThreeLine: true,
          trailing: IconButton(
            icon: const Icon(Icons.download),
            onPressed: busy ? null : () => install(item)),
        )),
    ]);
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16),
    children: const [
      ListTile(leading: Icon(Icons.phone_android),
        title: Text('Biblioteca local'),
        subtitle: Text('Los archivos importados se copian al almacenamiento privado de Auralis.')),
      ListTile(leading: Icon(Icons.security),
        title: Text('Seguridad de extensiones'),
        subtitle: Text('JavaScript externo permanece desactivado hasta contar con sandbox.')),
      ListTile(leading: Icon(Icons.info_outline),
        title: Text('Auralis v1.0.0'),
        subtitle: Text('Flutter · Android')),
    ]);
}

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});
  @override
  Widget build(BuildContext context) {
    final player = AudioCore.instance.player;
    return StreamBuilder<SequenceState?>(
      stream: player.sequenceStateStream,
      builder: (context, snapshot) {
        final item = snapshot.data?.currentSource?.tag;
        final title = item is MediaItem ? item.title : 'Nada reproduciéndose';
        return Card(margin: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          child: ListTile(
            leading: const Icon(Icons.album),
            title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: StreamBuilder<PlayerState>(
              stream: player.playerStateStream,
              builder: (context, s) => Text(s.data?.playing == true ? 'Reproduciendo' : 'En pausa')),
            trailing: StreamBuilder<PlayerState>(
              stream: player.playerStateStream,
              builder: (context, s) => IconButton(
                icon: Icon(s.data?.playing == true ? Icons.pause : Icons.play_arrow),
                onPressed: () {
                  if (player.playing) { player.pause(); }
                  else { player.play(); }
                }),
            ),
          ));
      },
    );
  }
}
