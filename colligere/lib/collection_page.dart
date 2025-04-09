import 'package:flutter/material.dart';
import 'package:colligere/services/collection_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:colligere/movie_details_page.dart';
import 'package:colligere/cd_details_page.dart';
import 'package:colligere/book_details_page.dart';
import 'package:colligere/api/api.dart';
import 'package:colligere/model/model_movie.dart';
import 'package:colligere/model/model_album.dart';
import 'package:colligere/model/model_book.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> with SingleTickerProviderStateMixin {
  final CollectionService _collectionService = CollectionService();
  String _userEmail = '';
  late TabController _tabController;
  List<dynamic> _allCollectionItems = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // Updated to 3 tabs
    _getUserInfo();
  }
  
  Future<void> _getUserInfo() async {
    setState(() {
      _isLoading = true;
    });
    
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('userEmail') ?? '';
    
    setState(() {
      _userEmail = email;
    });
    
    await _loadCollection();
  }
  
  Future<void> _loadCollection() async {
    if (_userEmail.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }
    
    final collection = await _collectionService.getFullUserCollection(_userEmail);
    
    setState(() {
      _allCollectionItems = collection;
      _isLoading = false;
    });
  }
  
  Future<void> _refreshCollection() async {
    setState(() {
      _isLoading = true;
    });
    
    await _loadCollection();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  List<dynamic> _getFilteredItems(String type) {
    return _allCollectionItems.where((item) => item['type'] == type).toList();
  }
  
  void _removeItem(dynamic item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmation'),
        content: const Text('Êtes-vous sûr de vouloir retirer cet élément de votre collection ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              bool success = false;
              
              if (item['type'] == 'movie') {
                success = await _collectionService.removeFromCollection(item['id']);
              } else if (item['type'] == 'album') {
                success = await _collectionService.removeAlbumFromCollection(item['id']);
              } else if (item['type'] == 'book') {
                success = await _collectionService.removeBookFromCollection(item['id']);
              }
              
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Élément retiré de votre collection')),
                );
                _refreshCollection();
              }
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 40, 55, 71),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(249, 52, 73, 94),
        foregroundColor: const Color.fromARGB(255, 245, 238, 248),
        title: const Text('Ma Collection'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.movie), text: "Films"),
            Tab(icon: Icon(Icons.album), text: "Albums"),
            Tab(icon: Icon(Icons.book), text: "Livres"), // Added books tab
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Films tab
                _buildCollectionList('movie'),
                // Albums tab
                _buildCollectionList('album'),
                // Books tab
                _buildCollectionList('book'), // Added books tab content
              ],
            ),
    );
  }
  
  Widget _buildCollectionList(String type) {
    final items = _getFilteredItems(type);
    
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'movie' ? Icons.movie_outlined :
              type == 'album' ? Icons.album_outlined : 
              Icons.book_outlined,
              size: 80,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              type == 'movie'
                  ? 'Aucun film dans votre collection'
                  : type == 'album'
                      ? 'Aucun album dans votre collection'
                      : 'Aucun livre dans votre collection',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Return to home page
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(249, 52, 73, 94),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Explorer le catalogue'),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _refreshCollection,
      child: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          
          if (type == 'movie') {
            return _buildMovieItem(item);
          } else if (type == 'album') {
            return _buildAlbumItem(item);
          } else {
            return _buildBookItem(item);
          }
        },
      ),
    );
  }
  
  Widget _buildMovieItem(dynamic movie) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.blueGrey[700],
      child: ListTile(
        contentPadding: const EdgeInsets.all(8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: movie['posterPath'] != null
              ? CachedNetworkImage(
                  imageUrl: 'https://image.tmdb.org/t/p/w500/${movie['posterPath']}',
                  width: 60,
                  height: 90,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 60,
                    height: 90,
                    color: Colors.grey[850],
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 60,
                    height: 90,
                    color: Colors.grey[850],
                    child: const Icon(Icons.movie, size: 30, color: Colors.white70),
                  ),
                )
              : Container(
                  width: 60,
                  height: 90,
                  color: Colors.grey[850],
                  child: const Icon(Icons.movie, size: 30, color: Colors.white70),
                ),
        ),
        title: Text(
          movie['title'] ?? 'Titre inconnu',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Format: ${movie['format']}',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
            Text(
              'Ajouté le: ${movie['addedDate'].day}/${movie['addedDate'].month}/${movie['addedDate'].year}',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.white70),
          onPressed: () => _removeItem(movie),
        ),
        onTap: () async {
          try {
            final Api api = Api();
            final details = await api.getMovieDetails(movie['movieId']);
            
            if (mounted && details['details'] != null) {
              final movieObj = Movie(
                id: movie['movieId'],
                title: movie['title'],
                overview: details['details']['overview'] ?? '',
                posterPath: movie['posterPath'],
                backdropPath: details['details']['backdrop_path'] ?? '',
                releaseDate: details['details']['release_date'] ?? '',
              );
              
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MovieDetailsPage(movie: movieObj),
                ),
              );
              
              _refreshCollection();
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erreur: $e')),
              );
            }
          }
        },
      ),
    );
  }

  Widget _buildAlbumItem(dynamic album) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.blueGrey[700],
      child: ListTile(
        contentPadding: const EdgeInsets.all(8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: album['imageUrl'] != null && album['imageUrl'].isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: album['imageUrl'],
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey[850],
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey[850],
                    child: const Icon(Icons.album, size: 30, color: Colors.white70),
                  ),
                )
              : Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey[850],
                  child: const Icon(Icons.album, size: 30, color: Colors.white70),
                ),
        ),
        title: Text(
          album['albumName'] ?? 'Titre inconnu',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Artiste: ${album['artist']}',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
            Text(
              'Format: ${album['format']}',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
            Text(
              'Ajouté le: ${album['addedDate'].day}/${album['addedDate'].month}/${album['addedDate'].year}',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.white70),
          onPressed: () => _removeItem(album),
        ),
        onTap: () async {
          try {
            final albumObj = Album(
              id: album['albumId'],
              name: album['albumName'],
              artist: album['artist'],
              imageUrl: album['imageUrl'],
              releaseDate: '',
            );
            
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CdDetailsPage(album: albumObj),
              ),
            );
            
            _refreshCollection();
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erreur: $e')),
              );
            }
          }
        },
      ),
    );
  }
  
  Widget _buildBookItem(dynamic book) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.blueGrey[700],
      child: ListTile(
        contentPadding: const EdgeInsets.all(8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: book['coverUrl'] != null && book['coverUrl'].isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: book['coverUrl'],
                  width: 60,
                  height: 90,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 60,
                    height: 90,
                    color: Colors.grey[850],
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 60,
                    height: 90,
                    color: Colors.grey[850],
                    child: const Icon(Icons.book, size: 30, color: Colors.white70),
                  ),
                )
              : Container(
                  width: 60,
                  height: 90,
                  color: Colors.grey[850],
                  child: const Icon(Icons.book, size: 30, color: Colors.white70),
                ),
        ),
        title: Text(
          book['title'] ?? 'Titre inconnu',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Auteur: ${book['author']}',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
            Text(
              'Format: ${book['format']}',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
            Text(
              'Ajouté le: ${book['addedDate'].day}/${book['addedDate'].month}/${book['addedDate'].year}',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.white70),
          onPressed: () => _removeItem(book),
        ),
        onTap: () async {
          try {
            final bookObj = Book(
              id: book['bookId'],
              title: book['title'],
              author: book['author'],
              coverUrl: book['coverUrl'],
              publishDate: '',
            );
            
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BookDetailsPage(book: bookObj),
              ),
            );
            
            _refreshCollection();
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erreur: $e')),
              );
            }
          }
        },
      ),
    );
  }
}
