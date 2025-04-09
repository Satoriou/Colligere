import 'package:flutter/foundation.dart';

class Book {
  final String id;
  final String title;
  final String author;
  final String coverUrl;
  final String publishDate;
  final String description;
  final List<String>? subjects; // Ajout de la propriété subjects pour les genres

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.publishDate,
    this.description = '',
    this.subjects,
  });

  factory Book.fromMap(Map<String, dynamic> book) {
    // Extrait l'identifiant
    String id = book['key'] ?? '';
    if (!id.startsWith('/works/') && id.isNotEmpty) {
      id = '/works/$id';
    }

    // Extrait l'auteur
    String author = 'Inconnu';
    if (book['author_name'] != null && book['author_name'] is List && book['author_name'].isNotEmpty) {
      author = book['author_name'][0];
    }

    // Extrait l'URL de la couverture
    String coverUrl = '';
    if (book['cover_i'] != null) {
      coverUrl = 'https://covers.openlibrary.org/b/id/${book['cover_i']}-L.jpg';
    } else if (book['isbn'] != null && book['isbn'] is List && book['isbn'].isNotEmpty) {
      coverUrl = 'https://covers.openlibrary.org/b/isbn/${book['isbn'][0]}-L.jpg';
    }

    // Extrait la date de publication
    String publishDate = 'Date inconnue';
    if (book['first_publish_year'] != null) {
      publishDate = book['first_publish_year'].toString();
    } else if (book['publish_year'] != null && book['publish_year'] is List && book['publish_year'].isNotEmpty) {
      publishDate = book['publish_year'][0].toString();
    } else if (book['publish_date'] != null && book['publish_date'] is List && book['publish_date'].isNotEmpty) {
      publishDate = book['publish_date'][0];
    }

    // Extrait les sujets/genres
    List<String>? subjects;
    if (book['subject'] != null && book['subject'] is List) {
      subjects = List<String>.from(book['subject']);
    }

    return Book(
      id: id,
      title: book['title'] ?? 'Titre inconnu',
      author: author,
      coverUrl: coverUrl,
      publishDate: publishDate,
      subjects: subjects,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Book && 
           other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
