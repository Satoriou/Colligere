import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/model_album.dart';

class SpotifyApi {
  // Pour une application réelle, ces informations devraient être sécurisées
  // et ne pas être en dur dans le code
  final String clientId = '53c63f7574f04d9ca9d470d8de11c11b';
  final String clientSecret = 'c710621426f5457e929a0b4e72efe013';
  String? _accessToken;
  DateTime? _tokenExpiry;

  // Obtenir un token d'accès
  Future<String> _getAccessToken() async {
    if (_accessToken != null && _tokenExpiry != null && _tokenExpiry!.isAfter(DateTime.now())) {
      return _accessToken!;
    }

    final response = await http.post(
      Uri.parse('https://accounts.spotify.com/api/token'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': 'Basic ${base64Encode(utf8.encode('$clientId:$clientSecret'))}',
      },
      body: {
        'grant_type': 'client_credentials',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      _accessToken = data['access_token'];
      _tokenExpiry = DateTime.now().add(Duration(seconds: data['expires_in']));
      return _accessToken!;
    } else {
      throw Exception('Failed to get access token');
    }
  }

  // Récupérer les nouveaux albums
  Future<List<Album>> getNewReleases() async {
    final token = await _getAccessToken();
    final response = await http.get(
      Uri.parse('https://api.spotify.com/v1/browse/new-releases?limit=20'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> albums = data['albums']['items'];
      return albums.map((album) => Album.fromMap(album)).toList();
    } else {
      throw Exception('Failed to load new releases');
    }
  }

  // Récupérer les albums populaires (basés sur les listes de lecture populaires)
  Future<List<Album>> getPopularAlbums() async {
    final token = await _getAccessToken();
    // En réalité, Spotify n'a pas d'endpoint direct pour les albums populaires,
    // donc nous utilisons des playlists populaires comme approximation
    final response = await http.get(
      Uri.parse('https://api.spotify.com/v1/browse/featured-playlists?limit=20'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      // Simulons des albums populaires en récupérant des albums récents
      return getNewReleases();
    } else {
      throw Exception('Failed to load popular albums');
    }
  }

  // Rechercher des albums
  Future<List<Album>> searchAlbums(String query) async {
    if (query.isEmpty) return [];
    
    final token = await _getAccessToken();
    final response = await http.get(
      Uri.parse('https://api.spotify.com/v1/search?q=$query&type=album&limit=20'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> albums = data['albums']['items'];
      return albums.map((album) => Album.fromMap(album)).toList();
    } else {
      throw Exception('Failed to search albums');
    }
  }
}
