import 'package:flutter/material.dart';
import 'package:colligere/model/model_book.dart';
import 'package:colligere/api/openlibrary_api.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:colligere/services/collection_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BookDetailsPage extends StatefulWidget {
  final Book book;

  const BookDetailsPage({super.key, required this.book});

  @override
  State<BookDetailsPage> createState() => _BookDetailsPageState();
}

class _BookDetailsPageState extends State<BookDetailsPage> {
  late Future<Map<String, dynamic>> _bookDetailsFuture;
  String _userEmail = '';
  late CollectionService _collectionService;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    try {
      _bookDetailsFuture = widget.book.id.isNotEmpty 
          ? OpenLibraryApi().getBookDetails(widget.book.id) 
          : Future.value({"error": "Book ID is empty"});
    } catch (e) {
      _bookDetailsFuture = Future.value({"error": "Failed to load book details: $e"});
    }
    _collectionService = CollectionService();
    _getUserInfo();
  }

  Future<void> _getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('userEmail') ?? '';
    
    setState(() {
      _userEmail = email;
    });
    
    if (email.isNotEmpty && widget.book.id.isNotEmpty) {
      final isFav = await _collectionService.isBookFavorite(email, widget.book.id);
      setState(() {
        _isFavorite = isFav;
      });
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
            _buildFormatButton('Broché'),
            _buildFormatButton('Relié'),
            _buildFormatButton('Poche'),
            _buildFormatButton('Numérique'),
          ],
        ),
      ),
    );
  }
              
  Widget _buildFormatButton(String format) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: ElevatedButton(
        onPressed: () {
          _collectionService.addBookToCollection(
            _userEmail, 
            widget.book.id, 
            widget.book.title,
            widget.book.author,
            widget.book.coverUrl,
            format
          );
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$format ajouté à votre collection'))
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(249, 52, 73, 94),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 44),
        ),
        child: Text(format),
      ),
    );
  }
                
  Future<void> _toggleFavorite() async {
    if (_userEmail.isEmpty) return;
    
    try {
      bool success;
      if (_isFavorite) {
        success = await _collectionService.removeBookFromFavorites(
          _userEmail, 
          widget.book.id
        );
      } else {
        success = await _collectionService.addBookToFavorites(
          _userEmail, 
          widget.book.id, 
          widget.book.title,
          widget.book.author,
          widget.book.coverUrl
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
      body: FutureBuilder<Map<String, dynamic>>(
        future: _bookDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
          } else if (snapshot.hasData) {
            final bookData = snapshot.data!;
            final description = widget.book.description.isNotEmpty 
                ? widget.book.description
                : bookData['description'] is String 
                    ? bookData['description'] 
                    : bookData['description']?['value'] ?? "Aucune description disponible.";
                
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero section with book cover
                  Container(
                    color: Colors.blueGrey[900],
                    child: Padding(
                      padding: const EdgeInsets.only(top: 80.0, bottom: 20.0),
                      child: Center(
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: widget.book.coverUrl,
                                height: 200,
                                fit: BoxFit.contain,
                                placeholder: (context, url) => Container(
                                  height: 200,
                                  width: 150,
                                  color: Colors.grey[800],
                                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  height: 200,
                                  width: 150,
                                  color: Colors.grey[800],
                                  child: const Icon(Icons.book, size: 60, color: Colors.white70),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20.0),
                              child: Text(
                                widget.book.title,
                                style: GoogleFonts.roboto(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.book.author,
                              style: GoogleFonts.roboto(
                                fontSize: 18,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Action buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  onPressed: _toggleFavorite,
                                  icon: Icon(
                                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                                    color: _isFavorite ? Colors.red : Colors.white,
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                IconButton(
                                  onPressed: _addToCollection,
                                  icon: const Icon(Icons.add, color: Colors.white, size: 30),
                                ),
                                const SizedBox(width: 16),
                                IconButton(
                                  onPressed: () {},
                                  icon: const Icon(Icons.share, color: Colors.white, size: 30),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Book info
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          color: Colors.blueGrey[700],
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInfoRow('Date de publication', widget.book.publishDate),
                                if (bookData['number_of_pages'] != null) ...[
                                  const SizedBox(height: 8),
                                  _buildInfoRow('Nombre de pages', bookData['number_of_pages'].toString()),
                                ],
                                if (bookData['publishers'] != null) ...[
                                  const SizedBox(height: 8),
                                  _buildInfoRow('Éditeur', 
                                    (bookData['publishers'] as List?)?.isNotEmpty == true 
                                      ? bookData['publishers'][0]
                                      : 'Inconnu'),
                                ],
                                if (bookData['subjects'] != null) ...[
                                  const SizedBox(height: 8),
                                  _buildInfoRow('Genres', 
                                    (bookData['subjects'] as List?)?.isNotEmpty == true 
                                      ? (bookData['subjects'] as List).take(3).join(', ')
                                      : 'Non spécifié'),
                                ],
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        Text(
                          'Résumé',
                          style: GoogleFonts.roboto(
                            fontSize: 20, 
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Divider(color: Colors.white24),
                        const SizedBox(height: 8),
                        
                        if (description != null && description.toString().isNotEmpty)
                          Text(
                            description.toString(),
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                              height: 1.5,
                            ),
                          )
                        else
                          const Text(
                            "Aucune description disponible pour ce livre.",
                            style: TextStyle(color: Colors.white70, fontSize: 16)
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          } else {
            return const Center(
              child: Text(
                'Aucune donnée disponible',
                style: TextStyle(color: Colors.white)
              )
            );
          }
        },
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
