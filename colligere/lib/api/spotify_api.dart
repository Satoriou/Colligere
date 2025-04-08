import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:colligere/model/model_album.dart';

class SpotifyApi {
  static const String _baseUrl = 'api.spotify.com';
  static const String _apiVersion = 'v1';
  static const String _authUrl = 'accounts.spotify.com';
  
  final String _clientId = '53c63f7574f04d9ca9d470d8de11c11b';
  final String _clientSecret = 'c710621426f5457e929a0b4e72efe013';
  
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  final List<String> _bestAlbumsOfAllTimeIds = [
    '4LH4d3cOWNNsVw41Gqt2kv',
    '2fenSS68JI1h4Fo296JfGr',
    '0ETFjACtuP2ADo6LFhL6HN',
    '1weenld61qoidwYuZ1GESA',
    '7rSZXXHHvIhF4yUFdaOCy9',
    '392p3shh2jkxUxY2VHvlH8',
    '1C2h7mLntPSeVYciMRTF4a',
    '19AUoKWRAX8asNiv5krRdG',
    '4Gfnly5CzMJQqkUFfoHaP3',
    '2V6WXbBY1pw9gQdv8EVZ1S',
    '48D1hRORqJq52qsnUYiP49',
    '2T7DdrOvsqOqU9bGTkjBYu',
    '6QaVfG1pHYl1z15ZxkvVDW',
    '2guirTSEqLizK7j9i1MTTZ',
    '7KCwEVtA0pJJTU5nHAp6Lc',
  ];

  Future<String> _getAccessToken() async {
    String? token = await _secureStorage.read(key: 'spotify_token');
    String? expiry = await _secureStorage.read(key: 'spotify_token_expiry');
    
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiryTime = expiry != null ? int.parse(expiry) : 0;
    
    if (token != null && expiryTime > now) {
      return token;
    }
    
    final credentials = base64.encode(utf8.encode('$_clientId:$_clientSecret'));
    final response = await http.post(
      Uri.https(_authUrl, '/api/token'),
      headers: {
        'Authorization': 'Basic $credentials',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'grant_type': 'client_credentials',
      },
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      token = data['access_token'];
      final expiresIn = data['expires_in'] as int;
      
      final expiryTimestamp = now + (expiresIn * 1000);
      await _secureStorage.write(key: 'spotify_token', value: token);
      await _secureStorage.write(key: 'spotify_token_expiry', value: expiryTimestamp.toString());
      
      return token!;
    } else {
      throw Exception('Failed to get access token: ${response.body}');
    }
  }
  
  Future<List<Album>> getNewReleases() async {
    try {
      final token = await _getAccessToken();
      final response = await http.get(
        Uri.https(_baseUrl, '/$_apiVersion/browse/new-releases', {'limit': '20'}),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['albums'] == null || data['albums']['items'] == null) {
          return [];
        }
        final albums = data['albums']['items'] as List;
        
        return albums.where((album) => album != null).map((album) {
          final images = album['images'] as List? ?? [];
          String imageUrl = '';
          if (images.isNotEmpty && images[0]['url'] != null) {
            imageUrl = images[0]['url'];
          }
          
          final artists = album['artists'] as List? ?? [];
          
          return Album(
            id: album['id'] ?? '',
            name: album['name'] ?? 'Unknown',
            artist: artists.isNotEmpty && artists[0]['name'] != null 
                ? artists[0]['name'] 
                : 'Unknown Artist',
            imageUrl: imageUrl,
            releaseDate: album['release_date'] ?? '',
          );
        }).toList();
      } else {
        throw Exception('Failed to load new releases');
      }
    } catch (e) {
      print('Error getting new releases: $e');
      return [];
    }
  }
  
  Future<List<Album>> getPopularAlbums() async {
    try {
      final token = await _getAccessToken();
      
      // Instead of selecting a random artist, search for multiple popular artists at once
      final response = await http.get(
        Uri.https(_baseUrl, '/$_apiVersion/search', {
          'q': 'artist:Drake OR artist:Kendrick Lamar OR artist:Beyonce OR artist:Billie Eilish OR artist:Bad Bunny',
          'type': 'album',
          'limit': '20',
          'include_external': 'audio'
        }),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['albums'] != null && data['albums']['items'] != null && data['albums']['items'].isNotEmpty) {
          final albums = data['albums']['items'] as List;
          
          // Remove duplicate albums by the same artist to ensure diversity
          final Map<String, Album> uniqueArtistAlbums = {};
          for (var album in albums) {
            final artists = album['artists'] as List? ?? [];
            final artistName = artists.isNotEmpty && artists[0]['name'] != null
                ? artists[0]['name']
                : 'Unknown Artist';
                
            // Only add one album per artist to ensure variety
            if (!uniqueArtistAlbums.containsKey(artistName)) {
              final images = album['images'] as List? ?? [];
              String imageUrl = '';
              if (images.isNotEmpty && images[0]['url'] != null) {
                imageUrl = images[0]['url'];
              }
              
              uniqueArtistAlbums[artistName] = Album(
                id: album['id'] ?? '',
                name: album['name'] ?? 'Unknown',
                artist: artistName,
                imageUrl: imageUrl,
                releaseDate: album['release_date'] ?? '',
              );
            }
          }
          
          final albumsList = uniqueArtistAlbums.values.toList();
          if (albumsList.isNotEmpty) {
            return albumsList;
          }
        }
      }
      
      // If API call failed or returned empty results, return hardcoded popular albums
      print('Using hardcoded popular albums');
      return _getHardcodedPopularAlbums();
    } catch (e) {
      print('Error getting popular albums: $e');
      return _getHardcodedPopularAlbums();
    }
  }
  
  // Updated method to provide reliable hardcoded popular albums with verified image URLs
  List<Album> _getHardcodedPopularAlbums() {
    return [
      Album(
        id: '5r36AJ6VOJtp00oxSkBZ5h',
        name: 'Renaissance',
        artist: 'Beyoncé',
        imageUrl: 'https://i.scdn.co/image/ab67616d0000b273365b9f2815b5a08db1ac349c',
        releaseDate: '2022-07-29',
      ),
      Album(
        id: '7dSZ6zGTQSNQJ32HpDsbJk',
        name: 'Midnights',
        artist: 'Taylor Swift',
        imageUrl: 'https://i.scdn.co/image/ab67616d0000b273bb54dde68cd23e2a268ae0f5',
        releaseDate: '2022-10-21',
      ),
      Album(
        id: '6FJxoadUE4JNVwWHghBwnb',
        name: 'Un Verano Sin Ti',
        artist: 'Bad Bunny',
        imageUrl: 'https://i.scdn.co/image/ab67616d0000b273a0c71ebeabae746218407b2e',
        releaseDate: '2022-05-06',
      ),
      Album(
        id: '2nkto6YNI4rUYTLqEwWJ3o',
        name: 'Flower Boy',
        artist: 'Tyler, The Creator',
        imageUrl: 'https://i.scdn.co/image/ab67616d0000b273c0bda1f457c0df8904f5b089',
        releaseDate: '2017-07-21',
      ),
      Album(
        id: '4m2880jivSbbyEGAKfITCa',
        name: 'Dawn FM',
        artist: 'The Weeknd',
        imageUrl: 'https://i.scdn.co/image/ab67616d0000b2730a8b3f4705d83f28ca40169e',
        releaseDate: '2022-01-07',
      ),
      Album(
        id: '1atjqOZTCdrjxjMyCPZc2g',
        name: 'SOS',
        artist: 'SZA',
        imageUrl: 'https://i.scdn.co/image/ab67616d0000b273e75d30e76273d6b45d93c89e',
        releaseDate: '2022-12-09',
      ),
      Album(
        id: '43HVsVQfDwCnNC1e3ciYP3',
        name: 'Heroes & Villains',
        artist: 'Metro Boomin',
        imageUrl: 'https://i.scdn.co/image/ab67616d0000b273c6f28a5f32802d5e121f80f8',
        releaseDate: '2022-12-02',
      ),
      Album(
        id: '1yOEeuCPvxBEkm9xU0n7TI',
        name: 'Harry\'s House',
        artist: 'Harry Styles',
        imageUrl: 'https://i.scdn.co/image/ab67616d0000b273eec048ab238e00172a7e32d4',
        releaseDate: '2022-05-20',
      ),
      Album(
        id: '1s9tU91VJt4sU5h0hA0nLl',
        name: 'Utopia',
        artist: 'Travis Scott',
        imageUrl: 'https://i.scdn.co/image/ab67616d0000b27340e3c06be84b79fa44d4a305',
        releaseDate: '2023-07-28',
      ),
      Album(
        id: '1YZ3k65Mqw3G8FzYlW1mmp',
        name: 'GUTS',
        artist: 'Olivia Rodrigo',
        imageUrl: 'https://i.scdn.co/image/ab67616d0000b273e85259a1cae29a8d91f2093d',
        releaseDate: '2023-09-08',
      ),
    ];
  }

  Future<List<Album>> getMostStreamedAlbums() async {
    try {
      final token = await _getAccessToken();
      final response = await http.get(
        Uri.https(_baseUrl, '/$_apiVersion/browse/categories/toplists/playlists', {'limit': '10'}),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['playlists'] == null || data['playlists']['items'] == null) {
          return getNewReleases();
        }

        final playlists = data['playlists']['items'] as List? ?? [];
        return playlists.map<Album>((playlist) {
          if (playlist == null) {
            return Album(id: '', name: 'Unknown', artist: 'Unknown', imageUrl: '', releaseDate: '');
          }
          final images = playlist['images'] as List? ?? [];
          String imageUrl = images.isNotEmpty && images[0]['url'] != null ? images[0]['url'] : '';
          final owner = playlist['owner'] ?? {};
          String ownerName = owner['display_name'] ?? 'Unknown';

          return Album(
            id: playlist['id'] ?? '',
            name: playlist['name'] ?? 'Unknown',
            artist: ownerName,
            imageUrl: imageUrl,
            releaseDate: playlist['release_date'] ?? '',
          );
        }).toList();
      } else {
        print('Failed to load top albums: ${response.statusCode} ${response.body}');
        return getNewReleases();
      }
    } catch (e) {
      print('Error getting most streamed albums: $e');
      return getNewReleases();
    }
  }

  Future<List<Album>> getBestAlbumsOfAllTime() async {
    try {
      final token = await _getAccessToken();
      
      final response = await http.get(
        Uri.https(_baseUrl, '/$_apiVersion/albums', {'ids': _bestAlbumsOfAllTimeIds.join(',')}),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['albums'] == null) {
          return _getFallbackBestAlbums();
        }
        
        final albums = data['albums'] as List;
        
        return albums
            .where((album) => album != null)
            .map((album) {
              final images = album['images'] as List? ?? [];
              String imageUrl = '';
              if (images.isNotEmpty && images[0]['url'] != null) {
                imageUrl = images[0]['url'];
              }
              
              final artists = album['artists'] as List? ?? [];
              
              return Album(
                id: album['id'] ?? '',
                name: album['name'] ?? 'Unknown Album',
                artist: artists.isNotEmpty && artists[0]['name'] != null 
                    ? artists[0]['name'] 
                    : 'Unknown Artist',
                imageUrl: imageUrl,
                releaseDate: album['release_date'] ?? '',
              );
            })
            .toList();
      } else {
        print('Failed to load best albums: ${response.statusCode} ${response.body}');
        return _getFallbackBestAlbums();
      }
    } catch (e) {
      print('Error getting best albums of all time: $e');
      return _getFallbackBestAlbums();
    }
  }

  List<Album> _getFallbackBestAlbums() {
    return [
      Album(
        id: '4LH4d3cOWNNsVw41Gqt2kv',
        name: 'The Dark Side of the Moon',
        artist: 'Pink Floyd',
        imageUrl: 'https://i.scdn.co/image/ab67616d0000b273ea7caaff71dea1051d49b2fe',
        releaseDate: '1973-03-01',
      ),
      Album(
        id: '2fenSS68JI1h4Fo296JfGr',
        name: 'Thriller',
        artist: 'Michael Jackson',
        imageUrl: 'https://i.scdn.co/image/ab67616d0000b2734121faee8df82c526cbab2be',
        releaseDate: '1982-11-30',
      ),
      Album(
        id: '0ETFjACtuP2ADo6LFhL6HN',
        name: 'Abbey Road',
        artist: 'The Beatles',
        imageUrl: 'https://i.scdn.co/image/ab67616d0000b273dc30583ba717007b00cceb25',
        releaseDate: '1969-09-26',
      ),
    ];
  }

  Future<List<Album>> searchAlbums(String query) async {
    try {
      if (query.trim().isEmpty) {
        return [];
      }
      
      final token = await _getAccessToken();
      final response = await http.get(
        Uri.https(
          _baseUrl, 
          '/$_apiVersion/search',
          {
            'q': query,
            'type': 'album',
            'limit': '20'
          }
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['albums'] == null || data['albums']['items'] == null) {
          return [];
        }
        
        final albums = data['albums']['items'] as List;
        
        return albums.where((album) => album != null).map((album) {
          final images = album['images'] as List? ?? [];
          String imageUrl = '';
          if (images.isNotEmpty && images[0]['url'] != null) {
            imageUrl = images[0]['url'];
          }
          
          final artists = album['artists'] as List? ?? [];
          
          return Album(
            id: album['id'] ?? '',
            name: album['name'] ?? 'Unknown',
            artist: artists.isNotEmpty && artists[0]['name'] != null
                ? artists[0]['name']
                : 'Unknown Artist',
            imageUrl: imageUrl,
            releaseDate: album['release_date'] ?? '',
          );
        }).toList();
      } else {
        print('Failed to search albums: ${response.statusCode} ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error searching albums: $e');
      return [];
    }
  }

  Future<Album?> getAlbum(String id) async {
    try {
      if (id.trim().isEmpty) {
        return null;
      }
      
      final token = await _getAccessToken();
      final response = await http.get(
        Uri.https(_baseUrl, '/$_apiVersion/albums/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (response.statusCode == 200) {
        final album = json.decode(response.body);
        
        final images = album['images'] as List? ?? [];
        String imageUrl = '';
        if (images.isNotEmpty && images[0]['url'] != null) {
          imageUrl = images[0]['url'];
        }
        
        final artists = album['artists'] as List? ?? [];
        
        return Album(
          id: album['id'] ?? '',
          name: album['name'] ?? 'Unknown',
          artist: artists.isNotEmpty && artists[0]['name'] != null
              ? artists[0]['name']
              : 'Unknown Artist',
          imageUrl: imageUrl,
          releaseDate: album['release_date'] ?? '',
        );
      } else {
        print('Failed to get album: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error getting album details: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> getAlbumDetails(String id) async {
    try {
      if (id.trim().isEmpty) {
        return {"error": "Album ID is empty"};
      }
      
      final token = await _getAccessToken();
      final response = await http.get(
        Uri.https(_baseUrl, '/$_apiVersion/albums/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (response.statusCode == 200) {
        final album = json.decode(response.body);
        return album;
      } else {
        print('Failed to get album details: ${response.statusCode} ${response.body}');
        return {"error": "Failed to load album details"};
      }
    } catch (e) {
      print('Error getting album details: $e');
      return {"error": "Exception: $e"};
    }
  }
}