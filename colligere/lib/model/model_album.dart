class Album {
  final String id;
  final String name;
  final String artist;
  final String imageUrl;
  final String releaseDate;

  Album({
    required this.id,
    required this.name,
    required this.artist,
    required this.imageUrl,
    required this.releaseDate,
  });

  factory Album.fromMap(Map<String, dynamic> map) {
    return Album(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      artist: map['artists'][0]['name'] ?? '',
      imageUrl: map['images'].isNotEmpty ? map['images'][0]['url'] ?? '' : '',
      releaseDate: map['release_date'] ?? ''
    );
  }
}
