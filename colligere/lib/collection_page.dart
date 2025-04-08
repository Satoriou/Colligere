import 'package:flutter/material.dart';
import 'package:colligere/services/collection_service.dart';
import 'package:colligere/model/model_collection_item.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CollectionPage extends StatefulWidget {
  const CollectionPage({Key? key}) : super(key: key);

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> with SingleTickerProviderStateMixin {
  final CollectionService _collectionService = CollectionService();
  String _userEmail = '';
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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

  Future<void> _refreshCollection() async {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ma Collection'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Films', icon: Icon(Icons.movie)),
            Tab(text: 'Albums', icon: Icon(Icons.album)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Movies tab
          _buildCollectionList('movie'),
          // Albums tab
          _buildCollectionList('album'),
        ],
      ),
    );
  }

  Widget _buildCollectionList(String type) {
    return RefreshIndicator(
      onRefresh: _refreshCollection,
      child: FutureBuilder<List<dynamic>>(
        future: type == 'movie' 
            ? _collectionService.getUserCollection(_userEmail) 
            : _collectionService.getUserAlbumCollection(_userEmail),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                type == 'movie' 
                    ? 'Aucun film dans votre collection' 
                    : 'Aucun album dans votre collection'
              ),
            );
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final item = snapshot.data![index];
                
                if (type == 'movie') {
                  // Movie item
                  final movie = item as CollectionItem;
                  return _buildMovieItem(movie);
                } else {
                  // Album item
                  return _buildAlbumItem(item);
                }
              },
            );
          }
        },
      ),
    );
  }

  Widget _buildMovieItem(CollectionItem movie) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ListTile(
        leading: movie.posterPath.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: 'https://image.tmdb.org/t/p/w92${movie.posterPath}',
                width: 50,
                placeholder: (context, url) => const CircularProgressIndicator(),
                errorWidget: (context, url, error) => const Icon(Icons.movie),
              )
            : const Icon(Icons.movie, size: 50),
        title: Text(movie.title),
        subtitle: Text('Format: ${movie.format}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () async {
            await _collectionService.removeFromCollection(movie.id);
            setState(() {});
          },
        ),
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(album['artist'] ?? 'Unknown Artist'),
            Text('Format: ${album['format']}'),
          ],
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () async {
            await _collectionService.removeAlbumFromCollection(album['id']);
            setState(() {});
          },
        ),
      ),
    );
  }
}
