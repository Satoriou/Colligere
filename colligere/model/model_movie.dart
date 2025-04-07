class Movie {
  final String title;
  final String backdropPath;
  final String overview;
  final String posterPath;
  

  Movie({
    required this.title,
    required this.backdropPath,
    required this.overview,
    required this.posterPath,
    
  });

factory Movie.fromMap(Map<String, dynamic> map) {
    return Movie(
      title: map['title'] ?? '',
      backdropPath: map['backdropPath'] ?? '',
      overview: map['overview'] ?? '',
      posterPath: map['posterPath'] ?? '',
    );
  }
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'backdropPath': backdropPath,
      'overview': overview,
      'posterPath': posterPath,
    };
  }
}