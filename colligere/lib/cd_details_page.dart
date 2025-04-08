import 'package:flutter/material.dart';
import 'package:colligere/model/model_album.dart';
import 'package:colligere/api/spotify_api.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:colligere/services/collection_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CdDetailsPage extends StatefulWidget {
  final Album album;

  const CdDetailsPage({super.key, required this.album});

  @override
  State<CdDetailsPage> createState() => _CdDetailsPageState();
}

class _CdDetailsPageState extends State<CdDetailsPage> {
  late Future<Map<String, dynamic>> _albumDetailsFuture;
  String _userEmail = '';
  late CollectionService _collectionService;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    try {
      _albumDetailsFuture = widget.album.id.isNotEmpty 
          ? SpotifyApi().getAlbumDetails(widget.album.id) 
          : Future.value({"error": "Album ID is empty"});
    } catch (e) {
      _albumDetailsFuture = Future.value({"error": "Failed to load album details: $e"});
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
    
    if (email.isNotEmpty && widget.album.id.isNotEmpty) {
      final isFav = await _collectionService.isAlbumFavorite(email, widget.album.id);
      setState(() {
        _isFavorite = isFav;
      });
    }
  }

  String _formatReleaseDate(String releaseDate) {
    if (releaseDate.isEmpty) return 'Date inconnue';
    try {
      if (releaseDate.length >= 10) {
        final date = DateTime.parse(releaseDate);
        return '${date.day}/${date.month}/${date.year}';
      } else if (releaseDate.length >= 4) {
        return releaseDate.substring(0, 4);
      }
      return releaseDate;
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
            _buildFormatButton('CD'),
            _buildFormatButton('Vinyle'),
            _buildFormatButton('Edition Limitée'),
            _buildFormatButton('Cassette'),
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
          _collectionService.addAlbumToCollection(
            _userEmail, 
            widget.album.id, 
            widget.album.name,
            widget.album.artist,
            widget.album.imageUrl,
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
        success = await _collectionService.removeAlbumFromFavorites(
          _userEmail, 
          widget.album.id
        );
      } else {
        success = await _collectionService.addAlbumToFavorites(
          _userEmail, 
          widget.album.id, 
          widget.album.name,
          widget.album.artist,
          widget.album.imageUrl
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
        future: _albumDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
          } else if (snapshot.hasData) {
            final albumData = snapshot.data!;
            final label = albumData['label'] ?? 'Label inconnu';
            final releaseDate = widget.album.releaseDate.isNotEmpty 
                ? widget.album.releaseDate 
                : (albumData['release_date'] ?? '');
            final formattedReleaseDate = _formatReleaseDate(releaseDate);
            final totalTracks = albumData['total_tracks']?.toString() ?? 'N/A';
            
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Container(
                        height: 260,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: CachedNetworkImageProvider(widget.album.imageUrl),
                            fit: BoxFit.cover,
                            colorFilter: ColorFilter.mode(
                              Colors.black.withOpacity(0.3),
                              BlendMode.darken,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        height: 260,
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
                      Positioned(
                        bottom: 10,
                        left: 16,
                        right: 16,
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: widget.album.imageUrl,
                                height: 120,
                                width: 120,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.album.name,
                                    style: GoogleFonts.roboto(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.album.artist,
                                    style: GoogleFonts.roboto(
                                      fontSize: 18,
                                      color: Colors.white70,
                                    ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
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
                  ),
                  
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
                                _buildInfoRow('Date de sortie', formattedReleaseDate),
                                const SizedBox(height: 8),
                                _buildInfoRow('Label', label),
                                const SizedBox(height: 8),
                                _buildInfoRow('Nombre de pistes', totalTracks),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        Text(
                          'Titres de l\'album',
                          style: GoogleFonts.roboto(
                            fontSize: 20, 
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Divider(color: Colors.white24),
                        const SizedBox(height: 8),
                        
                        if (snapshot.data != null && 
                            snapshot.data!['tracks'] != null && 
                            snapshot.data!['tracks']['items'] != null)
                          _buildTracksList(snapshot.data!['tracks']['items'])
                        else
                          const Text(
                            "Aucune information de piste disponible",
                            style: TextStyle(color: Colors.white70)
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
  
  Widget _buildTracksList(List<dynamic> tracks) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        final trackNumber = track['track_number'] ?? (index + 1);
        final trackName = track['name'] ?? 'Unknown track';
        
        String duration = '';
        if (track['duration_ms'] != null) {
          final durationMs = track['duration_ms'] as int;
          final minutes = (durationMs / 60000).floor();
          final seconds = ((durationMs % 60000) / 1000).floor();
          duration = '$minutes:${seconds.toString().padLeft(2, '0')}';
        }
        
        final bool isExplicit = track['explicit'] ?? false;
        
        return Card(
          color: Colors.blueGrey.withOpacity(0.2),
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: Colors.blueGrey[700],
              child: Text(
                trackNumber.toString(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    trackName,
                    style: const TextStyle(color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isExplicit)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text(
                      'E',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            trailing: Text(
              duration,
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
            dense: true,
          ),
        );
      },
    );
  }
}

