import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:colligere/model/model_book.dart';

class OpenLibraryApi {
  static const String _baseUrl = 'openlibrary.org';
  
  // Map pour traduire les genres courants de l'anglais vers le français
  final Map<String, String> _genreTranslations = {
    'fiction': 'Fiction',
    'non-fiction': 'Non-fiction',
    'science fiction': 'Science-fiction',
    'fantasy': 'Fantasy',
    'mystery': 'Mystère',
    'thriller': 'Thriller',
    'romance': 'Romance',
    'horror': 'Horreur',
    'historical': 'Historique',
    'biography': 'Biographie',
    'autobiography': 'Autobiographie',
    'memoir': 'Mémoires',
    'classic': 'Classique',
    'poetry': 'Poésie',
    'drama': 'Drame',
    'adventure': 'Aventure',
    'children': 'Jeunesse',
    'young adult': 'Jeune adulte',
    'crime': 'Policier',
    'history': 'Histoire',
    'philosophy': 'Philosophie',
    'psychology': 'Psychologie',
    'politics': 'Politique',
    'science': 'Science',
    'art': 'Art',
    'music': 'Musique',
    'travel': 'Voyage',
    'cookbook': 'Cuisine',
    'best_books': 'Meilleurs livres',
  };

  // Traduit un genre de l'anglais au français
  String _translateGenre(String genre) {
    return _genreTranslations[genre.toLowerCase()] ?? genre;
  }

  // Traduit une liste de genres
  List<String> _translateGenres(List<String> genres) {
    return genres.map((genre) => _translateGenre(genre)).toList();
  }
  
  // Get popular books - using a list of classics since OpenLibrary doesn't have a trending API
  Future<List<Book>> getPopularBooks() async {
    try {
      final response = await http.get(
        Uri.https(_baseUrl, '/search.json', {
          'q': 'subject:classic',
          'limit': '20',
          'lang': 'fr',
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> docs = data['docs'] as List? ?? [];
        
        return docs.map((book) {
          // Pour traduire les genres dans les résultats de l'API
          if (book['subject'] != null && book['subject'] is List) {
            List<String> originalSubjects = List<String>.from(book['subject']);
            book['subject'] = _translateGenres(originalSubjects);
          }
          return Book.fromMap(book);
        }).toList();
      } else {
        print('Failed to load popular books: ${response.statusCode}');
        return _getHardcodedPopularBooks();
      }
    } catch (e) {
      print('Error getting popular books: $e');
      return _getHardcodedPopularBooks();
    }
  }
  
  // Get new releases - using recent books as proxy
  Future<List<Book>> getNewReleases() async {
    try {
      // Current year
      final currentYear = DateTime.now().year;
      
      final response = await http.get(
        Uri.https(_baseUrl, '/search.json', {
          'q': 'publish_year: 2024',
          'limit': '20',
          'sort': 'newest',
          'lang': 'fr',
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> docs = data['docs'] as List? ?? [];
        
        return docs.map((book) {
          // Pour traduire les genres dans les résultats de l'API
          if (book['subject'] != null && book['subject'] is List) {
            List<String> originalSubjects = List<String>.from(book['subject']);
            book['subject'] = _translateGenres(originalSubjects);
          }
          return Book.fromMap(book);
        }).toList();
      } else {
        print('Failed to load new books: ${response.statusCode}');
        return _getHardcodedNewBooks();
      }
    } catch (e) {
      print('Error getting new books: $e');
      return _getHardcodedNewBooks();
    }
  }
  
  // Get best books of all time
  Future<List<Book>> getBestBooks() async {
    try {
      final response = await http.get(
        Uri.https(_baseUrl, '/search.json', {
          'q': 'subject:best_books',
          'limit': '30',
          'lang': 'fr',
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> docs = data['docs'] as List? ?? [];
        
        return docs.map((book) {
          // Pour traduire les genres dans les résultats de l'API
          if (book['subject'] != null && book['subject'] is List) {
            List<String> originalSubjects = List<String>.from(book['subject']);
            book['subject'] = _translateGenres(originalSubjects);
          }
          return Book.fromMap(book);
        }).toList();
      } else {
        print('Failed to load best books: ${response.statusCode}');
        return _getHardcodedBestBooks();
      }
    } catch (e) {
      print('Error getting best books: $e');
      return _getHardcodedBestBooks();
    }
  }
  
  // Search for books
  Future<List<Book>> searchBooks(String query) async {
    try {
      if (query.trim().isEmpty) {
        return [];
      }
      
      final response = await http.get(
        Uri.https(_baseUrl, '/search.json', {
          'q': query,
          'limit': '30',
          'lang': 'fr',
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> docs = data['docs'] as List? ?? [];
        
        return docs.map((book) {
          // Pour traduire les genres dans les résultats de l'API
          if (book['subject'] != null && book['subject'] is List) {
            List<String> originalSubjects = List<String>.from(book['subject']);
            book['subject'] = _translateGenres(originalSubjects);
          }
          return Book.fromMap(book);
        }).toList();
      } else {
        print('Failed to search books: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error searching books: $e');
      return [];
    }
  }
  
  // Get book details
  Future<Map<String, dynamic>> getBookDetails(String bookId) async {
    try {
      if (bookId.trim().isEmpty || !bookId.startsWith('/works/')) {
        return {"error": "Invalid book ID"};
      }
      
      // Remove the leading slash if present
      final cleanId = bookId.startsWith('/') ? bookId.substring(1) : bookId;
      
      final response = await http.get(
        Uri.https(_baseUrl, '/$cleanId.json'),
      );
      
      if (response.statusCode == 200) {
        final bookData = json.decode(response.body);
        
        // Traduire les sujets/genres si disponibles
        if (bookData['subjects'] != null && bookData['subjects'] is List) {
          List<String> originalSubjects = List<String>.from(bookData['subjects']);
          bookData['subjects'] = _translateGenres(originalSubjects);
        }
        
        return bookData;
      } else {
        print('Failed to get book details: ${response.statusCode}');
        return {"error": "Failed to load book details"};
      }
    } catch (e) {
      print('Error getting book details: $e');
      return {"error": "Exception: $e"};
    }
  }
  
  // Fallback data for when the API fails
  List<Book> _getHardcodedPopularBooks() {
    return [
      Book(
        id: '/works/OL45883W',
        title: 'Pride and Prejudice',
        author: 'Jane Austen',
        coverUrl: 'https://covers.openlibrary.org/b/id/8091016-L.jpg',
        publishDate: '1813',
        description: 'Orgueil et Préjugés est un roman de la femme de lettres anglaise Jane Austen paru en 1813. Il est considéré comme l\'une de ses œuvres les plus significatives et est aussi la plus connue.',
      ),
      Book(
        id: '/works/OL66539W',
        title: 'To Kill a Mockingbird',
        author: 'Harper Lee',
        coverUrl: 'https://covers.openlibrary.org/b/id/8095751-L.jpg',
        publishDate: '1960',
        description: 'Ne tirez pas sur l\'oiseau moqueur est un roman de Harper Lee publié en 1960. Immense succès dès sa parution, il a été traduit en plus de quarante langues et vendu à plus de 30 millions d\'exemplaires.',
      ),
      Book(
        id: '/works/OL17861084W',
        title: '1984',
        author: 'George Orwell',
        coverUrl: 'https://covers.openlibrary.org/b/id/8575111-L.jpg',
        publishDate: '1949',
        description: '1984 est un roman de fiction dystopique de George Orwell publié en 1949. Il décrit une Grande-Bretagne trente ans après une guerre nucléaire entre l\'Est et l\'Ouest censée avoir eu lieu dans les années 1950.',
      ),
    ];
  }
  
  List<Book> _getHardcodedNewBooks() {
    return [
      Book(
        id: '/works/OL20639540W',
        title: 'The Midnight Library',
        author: 'Matt Haig',
        coverUrl: 'https://covers.openlibrary.org/b/isbn/9780525559474-L.jpg',
        publishDate: '2020',
        description: 'La Bibliothèque de Minuit est un roman sur le regret, l\'espoir et les secondes chances. Il raconte l\'histoire d\'une bibliothèque entre la vie et la mort où chaque livre représente une vie que l\'on aurait pu mener.',
      ),
      Book(
        id: '/works/OL20817430W',
        title: 'Project Hail Mary',
        author: 'Andy Weir',
        coverUrl: 'https://covers.openlibrary.org/b/isbn/9780593135204-L.jpg',
        publishDate: '2021',
        description: 'Le Projet Dernière Chance est un roman de science-fiction d\'Andy Weir publié en 2021. Il suit un enseignant devenu astronaute qui se réveille amnésique dans un vaisseau spatial, avec pour mission de sauver la Terre d\'une extinction imminente.',
      ),
      Book(
        id: '/works/OL17590514W',
        title: 'Dune',
        author: 'Frank Herbert',
        coverUrl: 'https://covers.openlibrary.org/b/id/10288522-L.jpg',
        publishDate: '1965',
        description: 'Dune est un roman de science-fiction de Frank Herbert, publié en 1965. Il s\'agit du premier roman du cycle de Dune, une saga épique se déroulant dans un futur lointain où l\'humanité est répartie sur plusieurs planètes formant un empire féodal interstellaire.',
      ),
    ];
  }
  
  List<Book> _getHardcodedBestBooks() {
    return [
      Book(
        id: '/works/OL262758W',
        title: 'The Great Gatsby',
        author: 'F. Scott Fitzgerald',
        coverUrl: 'https://covers.openlibrary.org/b/id/8152359-L.jpg',
        publishDate: '1925',
        description: 'Gatsby le Magnifique est un roman de Francis Scott Fitzgerald publié en 1925. Il dépeint l\'époque des années folles aux États-Unis, à travers l\'histoire d\'un millionnaire mystérieux, Jay Gatsby, et de son amour pour Daisy Buchanan.',
      ),
      Book(
        id: '/works/OL2163649W',
        title: 'The Catcher in the Rye',
        author: 'J.D. Salinger',
        coverUrl: 'https://covers.openlibrary.org/b/id/8231488-L.jpg',
        publishDate: '1951',
        description: 'L\'Attrape-cœurs est un roman de J. D. Salinger publié en 1951. Il raconte l\'histoire d\'un adolescent, Holden Caulfield, qui fait le récit de trois jours de sa vie après avoir été renvoyé de son école préparatoire.',
      ),
      Book(
        id: '/works/OL16329317W',
        title: 'The Hobbit',
        author: 'J.R.R. Tolkien',
        coverUrl: 'https://covers.openlibrary.org/b/id/8406786-L.jpg',
        publishDate: '1937',
        description: 'Le Hobbit est un roman fantastique de J. R. R. Tolkien publié en 1937. L\'histoire raconte les aventures de Bilbo Bessac, un hobbit casanier qui se lance dans une quête aux côtés de treize nains et du magicien Gandalf pour récupérer un trésor gardé par un dragon.',
      ),
    ];
  }
}
