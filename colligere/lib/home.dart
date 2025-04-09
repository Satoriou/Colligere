import 'package:flutter/material.dart';
import 'package:colligere/api/api.dart';
import 'package:colligere/api/spotify_api.dart';
import 'package:colligere/api/openlibrary_api.dart';
import 'package:colligere/model/model_movie.dart';
import 'package:colligere/model/model_album.dart';
import 'package:colligere/model/model_book.dart';
import 'package:colligere/search_page.dart';
import 'package:colligere/logout.dart';
import 'package:colligere/settings_page.dart';
import 'package:colligere/movie_details_page.dart';
import 'package:colligere/cd_details_page.dart';
import 'package:colligere/book_details_page.dart';
import 'package:colligere/collection_page.dart';
import 'package:colligere/services/collection_service.dart';
import 'package:colligere/favorites_page.dart';
import 'package:colligere/utils/logout_helper.dart'; // Ajout de cet import pour LogoutHelper
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

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
  late Future<List<Album>> bestAlbumsOfAllTime;

  // Books
  late Future<List<Book>> popularBooks;
  late Future<List<Book>> newBooks;
  late Future<List<Book>> bestBooks;

  String userEmail = '';
  String username = '';
  String? _profileImagePath;
  late CollectionService _collectionService;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Initialisation des données films
    upcomingMovies = Api().getUpcomingMovies();
    popularMovies = Api().getPopularMovies();
    topRatedMovies = Api().getTopRatedMovies();

    // Initialisation des données albums
    newReleases = SpotifyApi().getNewReleases();
    popularAlbums = SpotifyApi().getPopularAlbums();
    bestAlbumsOfAllTime = SpotifyApi().getBestAlbumsOfAllTime();

    // Initialisation des données livres
    popularBooks = OpenLibraryApi().getPopularBooks();
    newBooks = OpenLibraryApi().getNewReleases();
    bestBooks = OpenLibraryApi().getBestBooks();

    _precacheMovieImages();
    _precacheAlbumImages();
    _precacheBookImages();
    _getUserInfo();
    _collectionService = CollectionService();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('userEmail') ?? '';
    final name = prefs.getString('username') ?? email.split('@')[0];
    final profileImagePath = prefs.getString('profileImagePath');
    
    setState(() {
      userEmail = email;
      username = name;
      _profileImagePath = profileImagePath;
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

  void _precacheAlbumImages() async {
    try {
      final newReleasesList = await newReleases;
      final popularList = await popularAlbums;
      final bestList = await bestAlbumsOfAllTime;

      final allAlbums = [...newReleasesList, ...popularList, ...bestList];

      for (var album in allAlbums) {
        if (album.imageUrl.isNotEmpty) {
          precacheImage(
            CachedNetworkImageProvider(album.imageUrl),
            context
          );
        }
      }
    } catch (e) {
      print('Error preloading album images: $e');
    }
  }

  void _precacheBookImages() async {
    try {
      final popularList = await popularBooks;
      final newList = await newBooks;
      final bestList = await bestBooks;

      final allBooks = [...popularList, ...newList, ...bestList];

      for (var book in allBooks) {
        if (book.coverUrl.isNotEmpty) {
          precacheImage(
            CachedNetworkImageProvider(book.coverUrl),
            context
          );
        }
      }
    } catch (e) {
      print('Error preloading book images: $e');
    }
  }

  void _addToCollection(Movie movie) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 40, 55, 71),
        title: const Text('Ajouter à ma collection', 
          style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Sélectionnez le format:', 
              style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),
            _buildFormatButton(movie, 'Blu-Ray'),
            _buildFormatButton(movie, 'DVD'),
            _buildFormatButton(movie, 'Steelbook'),
            _buildFormatButton(movie, '4K Blu-Ray'),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatButton(Movie movie, String format) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(249, 52, 73, 94),
          minimumSize: const Size(double.infinity, 44),
        ),
        onPressed: () async {
          final result = await _collectionService.addMovieToCollection(
            userEmail, 
            movie.id, 
            movie.title,
            movie.posterPath,
            format
          );
          
          Navigator.of(context).pop();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result ? 'Ajouté à votre collection' : 'Erreur lors de l\'ajout'
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        child: Text(format, style: const TextStyle(color: Colors.white)),
      ),
    );
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

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CdDetailsPage(album: album)),
                  );
                },
                child: Container(
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
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBookList(Future<List<Book>> booksFuture) {
    return FutureBuilder(
      future: booksFuture,
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

        final books = snapshot.data!;
        return SizedBox(
          height: 240,
          child: ListView.builder(
            padding: EdgeInsets.zero,
            scrollDirection: Axis.horizontal,
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              double leftMargin = index == 0 ? 0 : 10;
              double rightMargin = index == books.length - 1 ? 0 : 10;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => BookDetailsPage(book: book)),
                  );
                },
                child: Container(
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
                        child: book.coverUrl.isNotEmpty
                          ? CachedNetworkImage(
                            imageUrl: book.coverUrl,
                            height: 180,
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
                              child: const Center(
                                child: Icon(Icons.book, size: 50, color: Colors.white70),
                              ),
                            ),
                            memCacheHeight: 400,
                          )
                          : Container(
                            height: 180,
                            width: 150,
                            color: Colors.grey[800],
                            child: const Center(
                              child: Icon(Icons.book, size: 50, color: Colors.white70),
                            ),
                          ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        book.title,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        book.author,
                        style: const TextStyle(color: Colors.white70, fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
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
            Tab(icon: Icon(Icons.book_outlined), text: "Livres"),
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
                  _profileImagePath != null
                    ? CircleAvatar(
                        radius: 30,
                        backgroundImage: FileImage(File(_profileImagePath!)),
                      )
                    : const CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, size: 40, color: Colors.grey),
                      ),
                  const SizedBox(height: 10),
                  Text(
                    username,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    userEmail,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.collections_bookmark),
              title: const Text("Ma Collection"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CollectionPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text("Mes Favoris"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FavoritesPage()),
                );
              },
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
              onTap: () => LogoutHelper.confirmAndLogout(context),
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
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    "Albums Cultes",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
                _buildAlbumList(bestAlbumsOfAllTime),
              ],
            ),
          ),
          // Onglet Livres
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    "Livres Populaires",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
                _buildBookList(popularBooks),
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    "Nouveautés",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
                _buildBookList(newBooks),
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    "Grands Classiques",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
                _buildBookList(bestBooks),
              ],
            ),
          ),
        ],
      ),
    );
  }
}