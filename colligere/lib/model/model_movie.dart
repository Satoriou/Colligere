class Movie {
  final int id;
  final String title;
  final String backdropPath;
  final String overview;
  final String posterPath;
  final String releaseDate;
  

  Movie({
    required this.id,
    required this.title,
    required this.backdropPath,
    required this.overview,
    required this.posterPath,
    required this.releaseDate,
  });

  factory Movie.fromMap(Map<String, dynamic> map) {
    return Movie(
      id: map['id'] ?? 0,
      title: map['title'] ?? '',
      backdropPath: map['backdrop_path'] ?? '',  
      overview: map['overview'] ?? '',
      posterPath: map['poster_path'] ?? '',
      releaseDate: map['release_date'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'backdropPath': backdropPath,
      'overview': overview,
      'posterPath': posterPath,
      'releaseDate': releaseDate,
    };
  }
}