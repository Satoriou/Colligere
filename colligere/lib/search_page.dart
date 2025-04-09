import 'package:flutter/material.dart';
import 'package:colligere/api/api.dart';
import 'package:colligere/api/spotify_api.dart';
import 'package:colligere/api/openlibrary_api.dart';
import 'package:colligere/model/model_movie.dart';
import 'package:colligere/model/model_album.dart';
import 'package:colligere/model/model_book.dart';
import 'package:colligere/movie_details_page.dart';
import 'package:colligere/cd_details_page.dart';
import 'package:colligere/book_details_page.dart';
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
  List<Book> _bookResults = [];
  List<Movie> _filteredMovieResults = [];
  List<Album> _filteredAlbumResults = [];
  List<Book> _filteredBookResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  
  // Variables pour le debounce
  Timer? _debounce;
  String _lastQuery = '';
  
  // Tab controller pour basculer entre films, albums et livres
  late TabController _tabController;
  
  // Genres sélectionnés pour chaque catégorie
  String? _selectedMovieGenre;
  String? _selectedAlbumGenre;
  String? _selectedBookGenre;
  
  // Listes de genres pour chaque catégorie
  final List<String> _movieGenres = [
    'Action', 'Aventure', 'Animation', 'Comédie', 'Crime',
    'Documentaire', 'Drame', 'Famille', 'Fantaisie', 'Histoire',
    'Horreur', 'Musique', 'Mystère', 'Romance', 'Science-Fiction',
    'Thriller', 'Guerre', 'Western'
  ];
  
  final List<String> _albumGenres = [
    'Pop', 'Rock', 'Hip-Hop', 'Rap', 'Jazz',
    'Classique', 'Blues', 'Country', 'Électronique', 'Folk',
    'Metal', 'R&B', 'Soul', 'Reggae', 'Punk',
    'Indie', 'Dance', 'Alternative'
  ];
  
  final List<String> _bookGenres = [
    'Fiction', 'Non-fiction', 'Science-fiction', 'Fantasy', 'Mystère',
    'Thriller', 'Romance', 'Horreur', 'Historique', 'Biographie',
    'Autobiographie', 'Mémoires', 'Classique', 'Poésie', 'Drame',
    'Aventure', 'Jeunesse', 'Policier', 'Philosophie'
  ];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
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
          _bookResults = [];
          _filteredMovieResults = [];
          _filteredAlbumResults = [];
          _filteredBookResults = [];
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
      // Recherche simultanée de films, d'albums et de livres
      final movieFuture = Api().searchMovies(query);
      final albumFuture = SpotifyApi().searchAlbums(query);
      final bookFuture = OpenLibraryApi().searchBooks(query);
      
      // Attendre les trois résultats
      final results = await Future.wait([movieFuture, albumFuture, bookFuture]);
      
      setState(() {
        _movieResults = results[0] as List<Movie>;
        _albumResults = results[1] as List<Album>;
        _bookResults = results[2] as List<Book>;
        
        // Appliquer le filtrage initial
        _applyFilters();
        
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

  // Nouvelle méthode pour appliquer les filtres aux résultats
  void _applyFilters() {
    setState(() {
      // Filtrer les films - correction de la logique pour éviter l'erreur avec genreIds
      _filteredMovieResults = _selectedMovieGenre == null 
          ? List<Movie>.from(_movieResults)
          : _movieResults.where((movie) {
              // Rechercher le genre dans le titre ou la description
              return movie.title.toLowerCase().contains(_selectedMovieGenre!.toLowerCase()) ||
                     movie.overview.toLowerCase().contains(_selectedMovieGenre!.toLowerCase()) ||
                     (movie.releaseDate.isNotEmpty && movie.releaseDate.contains(_selectedMovieGenre!));
            }).toList();
      
      // Filtrer les albums
      _filteredAlbumResults = _selectedAlbumGenre == null
          ? List<Album>.from(_albumResults)
          : _albumResults.where((album) {
              return album.name.toLowerCase().contains(_selectedAlbumGenre!.toLowerCase()) ||
                     album.artist.toLowerCase().contains(_selectedAlbumGenre!.toLowerCase());
            }).toList();
      
      // Filtrer les livres
      _filteredBookResults = _selectedBookGenre == null
          ? List<Book>.from(_bookResults)
          : _bookResults.where((book) {
              if (book.subjects != null && book.subjects!.isNotEmpty) {
                return book.subjects!.any((subject) => 
                  subject.toLowerCase().contains(_selectedBookGenre!.toLowerCase()));
              }
              return book.title.toLowerCase().contains(_selectedBookGenre!.toLowerCase()) ||
                   (book.description.isNotEmpty && book.description.toLowerCase().contains(_selectedBookGenre!.toLowerCase()));
            }).toList();
    });
  }

  // Méthode pour réinitialiser les filtres
  void _resetFilters() {
    setState(() {
      _selectedMovieGenre = null;
      _selectedAlbumGenre = null;
      _selectedBookGenre = null;
      _applyFilters();
    });
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
            Tab(text: "Films (${_filteredMovieResults.length})"),
            Tab(text: "Albums (${_filteredAlbumResults.length})"),
            Tab(text: "Livres (${_filteredBookResults.length})"),
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
                hintText: 'Rechercher films, albums, livres...',
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
                            _bookResults = [];
                            _filteredMovieResults = [];
                            _filteredAlbumResults = [];
                            _filteredBookResults = [];
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
          
          // Filtre de genre (visible uniquement quand on a des résultats)
          if (_hasSearched && !_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildGenreDropdown(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.filter_list_off, color: Colors.white70),
                    onPressed: _resetFilters,
                    tooltip: 'Réinitialiser les filtres',
                  ),
                ],
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
                    : _filteredMovieResults.isEmpty && _filteredAlbumResults.isEmpty && _filteredBookResults.isEmpty
                        ? _buildNoResultsState()
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              // Onglet Films
                              _buildMovieResults(),
                              
                              // Onglet Albums
                              _buildAlbumResults(),
                              
                              // Onglet Livres
                              _buildBookResults(),
                            ],
                          ),
          ),
        ],
      ),
    );
  }
  
  // Widget pour construire le menu déroulant de genre approprié à l'onglet actuel
  Widget _buildGenreDropdown() {
    switch (_tabController.index) {
      case 0: // Films
        return _buildDropdown(
          _movieGenres,
          _selectedMovieGenre,
          (String? value) {
            setState(() {
              _selectedMovieGenre = value;
              _applyFilters();
            });
          },
          'Filtrer par genre de film',
        );
      case 1: // Albums
        return _buildDropdown(
          _albumGenres,
          _selectedAlbumGenre,
          (String? value) {
            setState(() {
              _selectedAlbumGenre = value;
              _applyFilters();
            });
          },
          'Filtrer par genre musical',
        );
      case 2: // Livres
        return _buildDropdown(
          _bookGenres,
          _selectedBookGenre,
          (String? value) {
            setState(() {
              _selectedBookGenre = value;
              _applyFilters();
            });
          },
          'Filtrer par genre littéraire',
        );
      default:
        return const SizedBox();
    }
  }
  
  // Méthode générique pour construire un menu déroulant
  Widget _buildDropdown(
    List<String> items,
    String? selectedValue,
    void Function(String?) onChanged,
    String hint
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color.fromARGB(249, 52, 73, 94),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<String>(
        value: selectedValue,
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
        iconSize: 24,
        elevation: 16,
        dropdownColor: const Color.fromARGB(255, 60, 75, 90),
        style: const TextStyle(color: Colors.white),
        isExpanded: true,
        underline: const SizedBox(),
        hint: Text(hint, style: const TextStyle(color: Colors.white70)),
        onChanged: onChanged,
        items: items.map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
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
            'Recherchez un film, un album ou un livre',
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
    if (_filteredMovieResults.isEmpty) {
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
              _selectedMovieGenre == null
                  ? 'Aucun film trouvé pour "${_searchController.text}"'
                  : 'Aucun film de genre "$_selectedMovieGenre" trouvé pour "${_searchController.text}"',
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
      itemCount: _filteredMovieResults.length,
      itemBuilder: (context, index) {
        final movie = _filteredMovieResults[index];
        return GestureDetector(
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
    if (_filteredAlbumResults.isEmpty) {
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
              _selectedAlbumGenre == null
                  ? 'Aucun album trouvé pour "${_searchController.text}"'
                  : 'Aucun album de genre "$_selectedAlbumGenre" trouvé pour "${_searchController.text}"',
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
      itemCount: _filteredAlbumResults.length,
      itemBuilder: (context, index) {
        final album = _filteredAlbumResults[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CdDetailsPage(album: album),
              ),
            ).then((_) {
              if (_searchController.text.isNotEmpty) {
                _searchResults(_searchController.text);
              }
            });
          },
          child: Column(
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
                  color: Colors.white70,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
  
  // Construction de la grille de résultats de livres
  Widget _buildBookResults() {
    if (_filteredBookResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.book_outlined,
              size: 80,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              _selectedBookGenre == null
                  ? 'Aucun livre trouvé pour "${_searchController.text}"'
                  : 'Aucun livre de genre "$_selectedBookGenre" trouvé pour "${_searchController.text}"',
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
        childAspectRatio: 0.65,
        crossAxisSpacing: 16.0,
        mainAxisSpacing: 16.0,
      ),
      itemCount: _filteredBookResults.length,
      itemBuilder: (context, index) {
        final book = _filteredBookResults[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BookDetailsPage(book: book),
              ),
            ).then((_) {
              if (_searchController.text.isNotEmpty) {
                _searchResults(_searchController.text);
              }
            });
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: book.coverUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: book.coverUrl,
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
                            child: const Center(
                              child: Icon(Icons.book, size: 40, color: Colors.white70),
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.grey[800],
                          child: const Center(
                            child: Icon(Icons.book, size: 40, color: Colors.white70),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                book.title,
                style: GoogleFonts.roboto(
                  fontSize: 14, 
                  color: Colors.white,
                  fontWeight: FontWeight.bold
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                book.author,
                style: GoogleFonts.roboto(
                  fontSize: 12,
                  color: Colors.white70,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}
