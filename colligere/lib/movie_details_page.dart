import 'package:flutter/material.dart';
import 'package:colligere/model/model_movie.dart';
import 'package:colligere/api/api.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:colligere/services/collection_service.dart'; // Nouvel import
import 'package:shared_preferences/shared_preferences.dart'; // Nouvel import

class MovieDetailsPage extends StatefulWidget {
  final Movie movie;

  const MovieDetailsPage({super.key, required this.movie});

  @override
  State<MovieDetailsPage> createState() => _MovieDetailsPageState();
}

class _MovieDetailsPageState extends State<MovieDetailsPage> {
  late Future<Map<String, dynamic>> _movieDetailsFuture;
  late CollectionService _collectionService;
  String _userEmail = '';
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _movieDetailsFuture = Api().getMovieDetails(widget.movie.id);
    _collectionService = CollectionService();
    _getUserInfo();
  }

  Future<void> _getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('userEmail') ?? '';
    
    setState(() {
      _userEmail = email;
    });
    
    if (email.isNotEmpty) {
      final isFav = await _collectionService.isMovieFavorite(email, widget.movie.id);
      setState(() {
        _isFavorite = isFav;
      });
    }
  }

  String _formatReleaseYear(String releaseDate) {
    if (releaseDate.isEmpty) return 'Date inconnue';
    try {
      return releaseDate.substring(0, 4); // Extraire l'année (YYYY-MM-DD)
    } catch (e) {
      return releaseDate;
    }
  }

  void _addToCollection() {
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
            _buildFormatButton('Blu-Ray'),
            _buildFormatButton('DVD'),
            _buildFormatButton('Steelbook'),
            _buildFormatButton('4K Blu-Ray'),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatButton(String format) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(249, 52, 73, 94),
          minimumSize: const Size(double.infinity, 44),
        ),
        onPressed: () async {
          final result = await _collectionService.addMovieToCollection(
            _userEmail, 
            widget.movie.id, 
            widget.movie.title,
            widget.movie.posterPath,
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

  Future<void> _toggleFavorite() async {
    if (_userEmail.isEmpty) return;
    
    try {
      bool success;
      if (_isFavorite) {
        success = await _collectionService.removeMovieFromFavorites(
          _userEmail, 
          widget.movie.id
        );
      } else {
        success = await _collectionService.addMovieToFavorites(
          _userEmail, 
          widget.movie.id, 
          widget.movie.title,
          widget.movie.posterPath
        );
      }
      
      if (success) {
        setState(() {
          _isFavorite = !_isFavorite;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isFavorite 
              ? 'Ajouté aux favoris' 
              : 'Retiré des favoris'
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Une erreur est survenue'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Erreur dans _toggleFavorite: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Une erreur est survenue'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 40, 55, 71),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image de fond du film
            Stack(
              children: [
                // Image de fond
                if (widget.movie.backdropPath.isNotEmpty)
                  SizedBox(
                    height: 250,
                    width: double.infinity,
                    child: CachedNetworkImage(
                      imageUrl: "https://image.tmdb.org/t/p/w500/${widget.movie.backdropPath}",
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[800],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[800],
                        child: const Center(child: Icon(Icons.error, color: Colors.white)),
                      ),
                    ),
                  ),
                // Dégradé pour faciliter la lecture du titre
                Container(
                  height: 250,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color.fromARGB(255, 40, 55, 71).withOpacity(0.7),
                        const Color.fromARGB(255, 40, 55, 71),
                      ],
                      stops: const [0.0, 0.7, 1.0],
                    ),
                  ),
                ),
                // Titre du film
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.movie.title,
                        style: GoogleFonts.roboto(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              offset: const Offset(1, 1),
                              blurRadius: 2.0,
                              color: Colors.black.withOpacity(0.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatReleaseYear(widget.movie.releaseDate),
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          color: Colors.white70,
                          shadows: [
                            Shadow(
                              offset: const Offset(1, 1),
                              blurRadius: 2.0,
                              color: Colors.black.withOpacity(0.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Affiche du film
                  if (widget.movie.posterPath.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: "https://image.tmdb.org/t/p/w500/${widget.movie.posterPath}",
                        height: 180,
                        width: 120,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 180,
                          width: 120,
                          color: Colors.grey[800],
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 180,
                          width: 120,
                          color: Colors.grey[800],
                          child: const Center(child: Icon(Icons.image_not_supported, color: Colors.white70)),
                        ),
                      ),
                    ),
                  const SizedBox(width: 16),
                  
                  // Informations et boutons
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Boutons d'action
                        Row(
                          children: [
                            IconButton(
                              onPressed: _toggleFavorite,
                              icon: Icon(
                                _isFavorite ? Icons.favorite : Icons.favorite_border,
                                color: _isFavorite ? Colors.red : Colors.white,
                              ),
                            ),
                            IconButton(
                              onPressed: _addToCollection,
                              icon: const Icon(Icons.add, color: Colors.white),
                            ),
                            IconButton(
                              onPressed: () {},
                              icon: const Icon(Icons.share, color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Évaluation
                        FutureBuilder<Map<String, dynamic>>(
                          future: _movieDetailsFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Text('Chargement des détails...', style: TextStyle(color: Colors.white70));
                            }
                            
                            if (snapshot.hasError || !snapshot.hasData) {
                              return const SizedBox.shrink();
                            }
                            
                            final details = snapshot.data!['details'];
                            final double voteAverage = (details['vote_average'] ?? 0.0).toDouble();
                            
                            return Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  "${voteAverage.toStringAsFixed(1)}/10", 
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Détails du film: uniquement les producteurs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: FutureBuilder<Map<String, dynamic>>(
                future: _movieDetailsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (snapshot.hasError || !snapshot.hasData) {
                    return const Text(
                      'Erreur lors du chargement des informations',
                      style: TextStyle(color: Colors.white70),
                    );
                  }
                  
                  final data = snapshot.data!;
                  final List<String> producers = data['producers'] ?? [];
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Producteurs
                      Text(
                        "Producteurs",
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        producers.isEmpty ? 'Information non disponible' : producers.join(', '),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  );
                },
              ),
            ),
            
            // Acteurs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                "Acteurs principaux",
                style: GoogleFonts.roboto(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            
            SizedBox(
              height: 120,
              child: FutureBuilder<Map<String, dynamic>>(
                future: _movieDetailsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (snapshot.hasError || !snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'Erreur lors du chargement des acteurs',
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }
                  
                  final cast = snapshot.data!['cast'] as List<Map<String, dynamic>>;
                  
                  if (cast.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'Information non disponible',
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: cast.length,
                    itemBuilder: (context, index) {
                      final actor = cast[index];
                      return Container(
                        width: 80,
                        margin: const EdgeInsets.only(right: 12),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.grey[700],
                              backgroundImage: actor['profile_path'] != null
                                  ? CachedNetworkImageProvider('https://image.tmdb.org/t/p/w200${actor['profile_path']}')
                                  : null,
                              child: actor['profile_path'] == null
                                  ? const Icon(Icons.person, color: Colors.white70)
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              actor['name'],
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Synopsis
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Synopsis",
                    style: GoogleFonts.roboto(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.movie.overview,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
