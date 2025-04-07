import 'package:flutter/material.dart';
import 'package:colligere/api/api.dart';
import 'package:colligere/api/spotify_api.dart';
import 'package:colligere/model/model_movie.dart';
import 'package:colligere/model/model_album.dart';
import 'package:colligere/search_page.dart';
import 'package:colligere/logout.dart';
import 'package:colligere/settings_page.dart';
import 'package:colligere/movie_details_page.dart'; // Nouvel import
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with TickerProviderStateMixin {
  late TabController _tabController;

  // Films
  late Future<List<Movie>> upcomingMovies;
  late Future<List<Movie>> popularMovies;
  late Future<List<Movie>> topRatedMovies;

  // Albums
  late Future<List<Album>> newReleases;
  late Future<List<Album>> popularAlbums;

  String userEmail = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Initialisation des données films
    upcomingMovies = Api().getUpcomingMovies();
    popularMovies = Api().getPopularMovies();
    topRatedMovies = Api().getTopRatedMovies();

    // Initialisation des données albums
    newReleases = SpotifyApi().getNewReleases();
    popularAlbums = SpotifyApi().getPopularAlbums();

    _precacheMovieImages();
    _getUserInfo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userEmail = prefs.getString('userEmail') ?? '';
    });
  }

  void _precacheMovieImages() async {
    try {
      final upcoming = await upcomingMovies;
      final popular = await popularMovies;
      final topRated = await topRatedMovies;

      final allMovies = [...upcoming, ...popular, ...topRated];

      for (var movie in allMovies) {
        precacheImage(
          CachedNetworkImageProvider(
            "https://image.tmdb.org/t/p/w500/${movie.posterPath}"
          ),
          context
        );
      }
    } catch (e) {
      print('Erreur lors du préchargement des images: $e');
    }
  }

  Widget _buildMovieList(Future<List<Movie>> moviesFuture) {
    return FutureBuilder(
      future: moviesFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              itemBuilder: (context, index) {
                double leftMargin = index == 0 ? 0 : 10;

                return Container(
                  width: 150,
                  margin: EdgeInsets.only(left: leftMargin, right: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        }

        final movies = snapshot.data!;
        return SizedBox(
          height: 200,
          child: ListView.builder(
            padding: EdgeInsets.zero,
            scrollDirection: Axis.horizontal,
            itemCount: movies.length,
            itemBuilder: (context, index) {
              final movie = movies[index];
              double leftMargin = index == 0 ? 0 : 10;
              double rightMargin = index == movies.length - 1 ? 0 : 10;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MovieDetailsPage(movie: movie)),
                  );
                },
                child: Container(
                  width: 150,
                  margin: EdgeInsets.only(left: leftMargin, right: rightMargin),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: CachedNetworkImage(
                      imageUrl: "https://image.tmdb.org/t/p/w500/${movie.posterPath}",
                      height: 200,
                      width: 150,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[800],
                        child: const Center(
                          child: SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[800],
                        child: const Center(child: Text('Image non disponible', style: TextStyle(color: Colors.white70))),
                      ),
                      memCacheHeight: 400,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildAlbumList(Future<List<Album>> albumsFuture) {
    return FutureBuilder(
      future: albumsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              itemBuilder: (context, index) {
                double leftMargin = index == 0 ? 0 : 10;
                return Container(
                  width: 150,
                  margin: EdgeInsets.only(left: leftMargin, right: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        }

        final albums = snapshot.data!;
        return SizedBox(
          height: 200,
          child: ListView.builder(
            padding: EdgeInsets.zero,
            scrollDirection: Axis.horizontal,
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final album = albums[index];
              double leftMargin = index == 0 ? 0 : 10;
              double rightMargin = index == albums.length - 1 ? 0 : 10;

              return Container(
                width: 150,
                margin: EdgeInsets.only(left: leftMargin, right: rightMargin),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: CachedNetworkImage(
                        imageUrl: album.imageUrl,
                        height: 150,
                        width: 150,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[800],
                          child: const Center(
                            child: SizedBox(
                              width: 30,
                              height: 30,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[800],
                          child: const Center(child: Text('Image non disponible', style: TextStyle(color: Colors.white70))),
                        ),
                        memCacheHeight: 400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      album.name,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      album.artist,
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 40, 55, 71),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(249, 52, 73, 94),
        foregroundColor: const Color.fromARGB(255, 245, 238, 248),
        leading: Builder(
          builder: (context) => IconButton(
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu),
          ),
        ),
        title: const Text("Colligere"),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchPage()),
              );
            },
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications)),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.movie_outlined), text: "Films"),
            Tab(icon: Icon(Icons.music_note_outlined), text: "Musique"),
          ],
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color.fromARGB(249, 52, 73, 94),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 40, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    userEmail,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text("Paramètres"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Déconnexion"),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              },
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Onglet Films
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    "À venir",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
                _buildMovieList(upcomingMovies),
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    "Populaires",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
                _buildMovieList(popularMovies),
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    "Les mieux notés",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
                _buildMovieList(topRatedMovies),
              ],
            ),
          ),
          // Onglet Albums
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    "Nouveautés",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
                _buildAlbumList(newReleases),
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    "Populaires",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
                _buildAlbumList(popularAlbums),
              ],
            ),
          ),
        ],
      ),
    );
  }
}