import 'package:flutter/material.dart';
import 'package:colligere/services/collection_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:colligere/movie_details_page.dart';
import 'package:colligere/cd_details_page.dart';
import 'package:colligere/book_details_page.dart';
import 'package:colligere/model/model_movie.dart';
import 'package:colligere/model/model_album.dart';
import 'package:colligere/model/model_book.dart';
import 'package:colligere/api/api.dart';
import 'package:colligere/api/spotify_api.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({Key? key}) : super(key: key);

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> with SingleTickerProviderStateMixin {
  final CollectionService _collectionService = CollectionService();
  String _userEmail = '';
  late TabController _tabController;
  final Api _api = Api();
  final SpotifyApi _spotifyApi = SpotifyApi();
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      _userEmail = prefs.getString('userEmail') ?? '';
    });
  }

  Future<void> _refreshFavorites() async {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Favoris'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Films', icon: Icon(Icons.movie)),
            Tab(text: 'Albums', icon: Icon(Icons.album)),
            Tab(text: 'Livres', icon: Icon(Icons.book)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Movies tab
          _buildFavoritesList('movie'),
          // Albums tab
          _buildFavoritesList('album'),
          // Books tab
          _buildFavoritesList('book'),
        ],
      ),
    );
  }

  Widget _buildFavoritesList(String type) {
    Future<List<Map<String, dynamic>>> futureToUse;
    switch (type) {
      case 'movie':
        futureToUse = _collectionService.getFavoriteMovies(_userEmail);
        break;
      case 'album':
        futureToUse = _collectionService.getFavoriteAlbums(_userEmail);
        break;
      case 'book':
        futureToUse = _collectionService.getFavoriteBooks(_userEmail);
        break;
      default:
        futureToUse = Future.value([]);
    }
    
    return RefreshIndicator(
      onRefresh: _refreshFavorites,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: futureToUse,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                type == 'movie' 
                    ? 'Aucun film dans vos favoris'
                    : type == 'album'
                        ? 'Aucun album dans vos favoris'
                        : 'Aucun livre dans vos favoris'
              ),
            );
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final item = snapshot.data![index];
                
                if (type == 'movie') {
                  return _buildMovieItem(item);
                } else if (type == 'album') {
                  return _buildAlbumItem(item);
                } else {
                  return _buildBookItem(item);
                }
              },
            );
          }
        },
      ),
    );
  }

  Widget _buildMovieItem(Map<String, dynamic> movie) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ListTile(
        leading: movie['posterPath'] != null && movie['posterPath'].isNotEmpty
            ? CachedNetworkImage(
                imageUrl: 'https://image.tmdb.org/t/p/w92${movie['posterPath']}',
                width: 50,
                placeholder: (context, url) => const CircularProgressIndicator(),
                errorWidget: (context, url, error) => const Icon(Icons.movie),
              )
            : const Icon(Icons.movie, size: 50),
        title: Text(movie['title'] ?? 'Untitled'),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () async {
            await _collectionService.removeMovieFromFavorites(
              _userEmail, 
              movie['movieId']
            );
            setState(() {});
          },
        ),
        onTap: () async {
          // Navigate to movie details
          try {
            final movieDetails = Movie(
              id: movie['movieId'],
              title: movie['title'],
              posterPath: movie['posterPath'],
              backdropPath: '',
              overview: '',
              releaseDate: '',
            );
            
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MovieDetailsPage(movie: movieDetails)
              ),
            );
            
            // Refresh on return
            setState(() {});
          } catch (e) {
            print('Error navigating to movie details: $e');
          }
        },
      ),
    );
  }

  Widget _buildAlbumItem(Map<String, dynamic> album) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ListTile(
        leading: album['imageUrl']?.isNotEmpty ?? false
            ? CachedNetworkImage(
                imageUrl: album['imageUrl'],
                width: 50,
                placeholder: (context, url) => const CircularProgressIndicator(),
                errorWidget: (context, url, error) => const Icon(Icons.album),
              )
            : const Icon(Icons.album, size: 50),
        title: Text(album['albumName'] ?? 'Unknown Album'),
        subtitle: Text(album['artist'] ?? 'Unknown Artist'),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () async {
            await _collectionService.removeAlbumFromFavorites(
              _userEmail, 
              album['albumId']
            );
            setState(() {});
          },
        ),
        onTap: () async {
          // Navigate to album details
          try {
            final albumDetails = Album(
              id: album['albumId'],
              name: album['albumName'],
              artist: album['artist'],
              imageUrl: album['imageUrl'],
              releaseDate: '',
            );
            
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CdDetailsPage(album: albumDetails)
              ),
            );
            
            // Refresh on return
            setState(() {});
          } catch (e) {
            print('Error navigating to album details: $e');
          }
        },
      ),
    );
  }

  Widget _buildBookItem(Map<String, dynamic> book) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ListTile(
        leading: book['coverUrl']?.isNotEmpty ?? false
            ? CachedNetworkImage(
                imageUrl: book['coverUrl'],
                width: 50,
                placeholder: (context, url) => const CircularProgressIndicator(),
                errorWidget: (context, url, error) => const Icon(Icons.book),
              )
            : const Icon(Icons.book, size: 50),
        title: Text(book['title'] ?? 'Unknown Book'),
        subtitle: Text(book['author'] ?? 'Unknown Author'),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () async {
            await _collectionService.removeBookFromFavorites(
              _userEmail, 
              book['bookId']
            );
            setState(() {});
          },
        ),
        onTap: () async {
          // Navigate to book details
          try {
            final bookDetails = Book(
              id: book['bookId'],
              title: book['title'],
              author: book['author'],
              coverUrl: book['coverUrl'],
              publishDate: '',
            );
            
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BookDetailsPage(book: bookDetails)
              ),
            );
            
            // Refresh on return
            setState(() {});
          } catch (e) {
            print('Error navigating to book details: $e');
          }
        },
      ),
    );
  }
}
