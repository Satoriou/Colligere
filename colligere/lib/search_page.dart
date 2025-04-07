import 'package:flutter/material.dart';
import 'package:colligere/api/api.dart';
import 'package:colligere/api/spotify_api.dart';
import 'package:colligere/model/model_movie.dart';
import 'package:colligere/model/model_album.dart';
import 'package:colligere/movie_details_page.dart'; // Ajout de l'import pour la page de détails
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<Movie> _movieResults = [];
  List<Album> _albumResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  
  // Variables pour le debounce
  Timer? _debounce;
  String _lastQuery = '';
  
  // Tab controller pour basculer entre films et albums
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Ajouter un listener pour le changement de texte
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _tabController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // Cette méthode est appelée chaque fois que le texte change
  void _onSearchChanged() {
    final query = _searchController.text.trim();
    
    // Ne rien faire si le texte est vide ou n'a pas changé
    if (query.isEmpty || query == _lastQuery) return;
    
    // Stocker la requête actuelle
    _lastQuery = query;
    
    // Annuler le précédent timer si une nouvelle frappe est détectée
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    // Paramétrer un délai avant de lancer la recherche
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.length >= 2) { // Au moins 2 caractères pour lancer une recherche
        _searchResults(query);
      } else {
        // Effacer les résultats si moins de 2 caractères
        setState(() {
          _movieResults = [];
          _albumResults = [];
          _hasSearched = false;
        });
      }
    });
  }

  Future<void> _searchResults(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      // Recherche simultanée de films et d'albums
      final movieFuture = Api().searchMovies(query);
      final albumFuture = SpotifyApi().searchAlbums(query);
      
      // Attendre les deux résultats
      final results = await Future.wait([movieFuture, albumFuture]);
      
      setState(() {
        _movieResults = results[0] as List<Movie>;
        _albumResults = results[1] as List<Album>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la recherche: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 40, 55, 71),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(249, 52, 73, 94),
        foregroundColor: const Color.fromARGB(255, 245, 238, 248),
        title: const Text("Rechercher"),
        centerTitle: true,
        bottom: _hasSearched && !_isLoading ? TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: "Films (${_movieResults.length})"),
            Tab(text: "Albums (${_albumResults.length})"),
          ],
        ) : null,
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Rechercher films, albums...',
                hintStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white70),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _movieResults = [];
                            _albumResults = [];
                            _hasSearched = false;
                            _lastQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color.fromARGB(249, 52, 73, 94),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          
          // Indicateur de saisie
          if (_searchController.text.isNotEmpty && _searchController.text.length < 2)
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text(
                'Continuez à saisir pour rechercher...',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
            
          // Corps de la page
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : !_hasSearched
                    ? _buildInitialSearchState()
                    : _movieResults.isEmpty && _albumResults.isEmpty
                        ? _buildNoResultsState()
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              // Onglet Films
                              _buildMovieResults(),
                              
                              // Onglet Albums
                              _buildAlbumResults(),
                            ],
                          ),
          ),
        ],
      ),
    );
  }
  
  // État initial de la recherche
  Widget _buildInitialSearchState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Recherchez un film ou un album',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
  
  // État sans résultats
  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun résultat trouvé pour "${_searchController.text}"',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  // Construction de la grille de résultats de films
  Widget _buildMovieResults() {
    if (_movieResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.movie_filter_outlined,
              size: 80,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun film trouvé pour "${_searchController.text}"',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 16.0,
        mainAxisSpacing: 16.0,
      ),
      itemCount: _movieResults.length,
      itemBuilder: (context, index) {
        final movie = _movieResults[index];
        return GestureDetector(
          // Ajouter la navigation vers la page de détails
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MovieDetailsPage(movie: movie),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: movie.posterPath != null
                      ? CachedNetworkImage(
                          imageUrl: "https://image.tmdb.org/t/p/w500/${movie.posterPath}",
                          fit: BoxFit.cover,
                          width: double.infinity,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[800],
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[800],
                            child: const Center(child: Text('Image non disponible', style: TextStyle(color: Colors.white70))),
                          ),
                        )
                      : Container(
                          color: Colors.grey[800],
                          child: const Center(child: Text('Pas d\'image', style: TextStyle(color: Colors.white70))),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                movie.title,
                style: GoogleFonts.roboto(
                  fontSize: 14, 
                  color: Colors.white,
                  fontWeight: FontWeight.bold
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
  
  // Construction de la grille de résultats d'albums
  Widget _buildAlbumResults() {
    if (_albumResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.album_outlined,
              size: 80,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun album trouvé pour "${_searchController.text}"',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16.0,
        mainAxisSpacing: 16.0,
      ),
      itemCount: _albumResults.length,
      itemBuilder: (context, index) {
        final album = _albumResults[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: CachedNetworkImage(
                  imageUrl: album.imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[800],
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[800],
                    child: const Center(child: Text('Image non disponible', style: TextStyle(color: Colors.white70))),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              album.name,
              style: GoogleFonts.roboto(
                fontSize: 14, 
                color: Colors.white,
                fontWeight: FontWeight.bold
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              album.artist,
              style: GoogleFonts.roboto(
                fontSize: 12, 
                color: Colors.white70,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      },
    );
  }
}
