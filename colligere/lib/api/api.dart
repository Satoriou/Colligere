import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../model/model_movie.dart';


class Api {
  final upcomingUrl = 'https://api.themoviedb.org/3/movie/upcoming?api_key=d7d864448666f098544ca631c3776a3d&language=fr-FR&page=1';
  final popularUrl = 'https://api.themoviedb.org/3/movie/popular?api_key=d7d864448666f098544ca631c3776a3d&language=fr-FR&page=1';
  final topRatedUrl = 'https://api.themoviedb.org/3/movie/top_rated?api_key=d7d864448666f098544ca631c3776a3d&language=fr-FR&page=1';

  Future<List<Movie>> getUpcomingMovies() async {  // Renommé de GetUpcoming
    final response = await http.get(Uri.parse(upcomingUrl));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body)['results'];
      List<Movie> movies = data.map((movie) => Movie.fromMap(movie)).toList();
      return movies;
    } else {
      throw Exception('Failed to load upcoming movies');
    }
  }

  Future<List<Movie>> getPopularMovies() async {  // Liste des films populaires (donnée recuperée sur l'API)
    final response = await http.get(Uri.parse(popularUrl));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body)['results'];
      List<Movie> movies = data.map((movie) => Movie.fromMap(movie)).toList();
      return movies;
    } else {
      throw Exception('Failed to load popular movies');
    }
  }

  Future<List<Movie>> getTopRatedMovies() async {  // Liste des films les mieux notés (donnée recuperée sur l'API)
    final response = await http.get(Uri.parse(topRatedUrl));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body)['results'];
      List<Movie> movies = data.map((movie) => Movie.fromMap(movie)).toList();
      return movies;
    } else {
      throw Exception('Failed to load top rated movies');
    }
  }

  
  Future<List<Movie>> searchMovies(String query) async { // Méthode pour rechercher des films par mots-clés
    final searchUrl = 'https://api.themoviedb.org/3/search/movie?api_key=d7d864448666f098544ca631c3776a3d&language=fr-FR&query=$query&page=1&include_adult=false';
    
    final response = await http.get(Uri.parse(searchUrl));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body)['results'];
      List<Movie> movies = data.map((movie) => Movie.fromMap(movie)).toList();
      return movies;
    } else {
      throw Exception('Failed to search movies');
    }
  }

  // Récupérer les détails d'un film spécifique
  Future<Map<String, dynamic>> getMovieDetails(int movieId) async {
    final detailsUrl = 'https://api.themoviedb.org/3/movie/$movieId?api_key=d7d864448666f098544ca631c3776a3d&language=fr-FR';
    final creditsUrl = 'https://api.themoviedb.org/3/movie/$movieId/credits?api_key=d7d864448666f098544ca631c3776a3d&language=fr-FR';
    
    try {
      // Récupérer les détails du film et les crédits en parallèle
      final responses = await Future.wait([
        http.get(Uri.parse(detailsUrl)),
        http.get(Uri.parse(creditsUrl)),
      ]);
      
      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        final details = json.decode(responses[0].body);
        final credits = json.decode(responses[1].body);
        
        // Extraire les acteurs (limité aux 5 premiers)
        List<Map<String, dynamic>> cast = [];
        if (credits['cast'] != null) {
          int count = 0;
          for (var actor in credits['cast']) {
            if (count < 5) {
              cast.add({
                'name': actor['name'],
                'character': actor['character'],
                'profile_path': actor['profile_path'],
              });
              count++;
            } else {
              break;
            }
          }
        }
        
        // Extraire uniquement les producteurs (sans réalisateur)
        List<String> producers = [];
        
        if (credits['crew'] != null) {
          for (var crew in credits['crew']) {
            if (crew['job'] == 'Producer') {
              producers.add(crew['name']);
            }
          }
        }
        
        // Retourner les données sans le réalisateur
        return {
          'details': details,
          'cast': cast,
          'producers': producers,
        };
      } else {
        throw Exception('Failed to load movie details');
      }
    } catch (e) {
      throw Exception('Error fetching movie details: $e');
    }
  }
}