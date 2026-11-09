import 'package:flutter/material.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  final pages = const [LibraryPage(), SearchPage(), SettingsPage()];
  final titles = const ['Biblioteca', 'Buscar', 'Ajustes'];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(titles[index])),
    body: Column(children: [
      Expanded(child: IndexedStack(index: index, children: pages)),
      const MiniPlayer(),
    ]),
    bottomNavigationBar: NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (v) => setState(() => index = v),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.library_music_outlined), label: 'Biblioteca'),
        NavigationDestination(icon: Icon(Icons.search), label: 'Buscar'),
        NavigationDestination(icon: Icon(Icons.tune), label: 'Ajustes'),
      ],
    ),
  );
}

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text('Tu música, en un solo lugar', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text('La biblioteca local se conectará en la siguiente fase.'),
      const SizedBox(height: 20),
      const _Tile(Icons.music_note, 'Canciones', '0 canciones'),
      const _Tile(Icons.album_outlined, 'Álbumes', '0 álbumes'),
      const _Tile(Icons.person_outline, 'Artistas', '0 artistas'),
      const _Tile(Icons.queue_music, 'Listas', '0 listas'),
    ],
  );
}

class _Tile extends StatelessWidget {
  const _Tile(this.icon, this.title, this.subtitle);
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(leading: Icon(icon), title: Text(title), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right)),
  );
}

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(children: [
      TextField(decoration: InputDecoration(
        hintText: 'Canción, álbum o artista',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      )),
      const SizedBox(height: 16),
      const Text('La búsqueda se conectará a tu biblioteca local.'),
    ]),
  );
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: const [
    ListTile(leading: Icon(Icons.palette_outlined), title: Text('Apariencia'), subtitle: Text('Tema del sistema')),
    ListTile(leading: Icon(Icons.folder_open), title: Text('Carpetas de música'), subtitle: Text('Aún no configuradas')),
    ListTile(leading: Icon(Icons.graphic_eq), title: Text('Audio'), subtitle: Text('Motor en desarrollo')),
    ListTile(leading: Icon(Icons.info_outline), title: Text('Acerca de Auralis'), subtitle: Text('Versión 0.1.0')),
  ]);
}

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.fromLTRB(16, 8, 16, 10),
    child: ListTile(
      leading: Icon(Icons.music_note),
      title: Text('Nada reproduciéndose'),
      subtitle: Text('Selecciona una canción'),
      trailing: Icon(Icons.play_arrow),
    ),
  );
}
