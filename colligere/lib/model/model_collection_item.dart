class CollectionItem {
  final int id;
  final String userEmail;
  final int movieId;
  final String title;
  final String posterPath;
  final String format;
  final DateTime addedDate;

  CollectionItem({
    required this.id,
    required this.userEmail,
    required this.movieId,
    required this.title,
    required this.posterPath,
    required this.format,
    required this.addedDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userEmail': userEmail,
      'movieId': movieId,
      'title': title,
      'posterPath': posterPath,
      'format': format,
      'addedDate': addedDate.toIso8601String(),
    };
  }

}
