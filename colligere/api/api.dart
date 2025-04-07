import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/model_movie.dart';

class Api {
  final upcomingUrl = 'https://api.themoviedb.org/3/movie/upcoming?api_key=d7d864448666f098544ca631c3776a3d&language=fr-FR&page=1';
  final popularUrl = 'https://api.themoviedb.org/3/movie/popular?api_key=d7d864448666f098544ca631c3776a3d&language=fr-FR&page=1';
  final topRatedUrl = 'https://api.themoviedb.org/3/movie/top_rated?api_key=d7d864448666f098544ca631c3776a3d&language=fr-FR&page=1';

  Future<List<Movie>> getUpcomingMovies() async {
    final response = await http.get(Uri.parse(upcomingUrl));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body)['results'];
      List<Movie> movies = data.map((movie) => Movie.fromMap(movie)).toList();
      return movies;
    } else {
      throw Exception('Failed to load upcoming movies');
    }
  }

  Future<List<Movie>> getPopularMovies() async {
    final response = await http.get(Uri.parse(popularUrl));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body)['results'];
      List<Movie> movies = data.map((movie) => Movie.fromMap(movie)).toList();
      return movies;
    } else {
      throw Exception('Failed to load popular movies');
    }
  }

  Future<List<Movie>> getTopRatedMovies() async {
    final response = await http.get(Uri.parse(topRatedUrl));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body)['results'];
      List<Movie> movies = data.map((movie) => Movie.fromMap(movie)).toList();
      return movies;
    } else {
      throw Exception('Failed to load top rated movies');
    }
  }

  Future<List<Movie>> searchMovies(String query) async {
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
}