import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:colligere/model/model_collection_item.dart';

class CollectionService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'collection_database.db');
    return await openDatabase(
      path,
      version: 4, // Increased version for books tables
      onCreate: (Database db, int version) async {
        await db.execute(
          'CREATE TABLE collection('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'userEmail TEXT, '
          'movieId INTEGER, '
          'title TEXT, '
          'posterPath TEXT, '
          'format TEXT, '
          'addedDate TEXT)'
        );
        
        await db.execute(
          'CREATE TABLE album_collection('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'userEmail TEXT, '
          'albumId TEXT, '
          'albumName TEXT, '
          'artist TEXT, '
          'imageUrl TEXT, '
          'format TEXT, '
          'addedDate TEXT)'
        );

        // Create book collection table
        await db.execute(
          'CREATE TABLE book_collection('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'userEmail TEXT, '
          'bookId TEXT, '
          'title TEXT, '
          'author TEXT, '
          'coverUrl TEXT, '
          'format TEXT, '
          'addedDate TEXT)'
        );

        // Create favorites tables
        await db.execute(
          'CREATE TABLE movie_favorites('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'userEmail TEXT, '
          'movieId INTEGER, '
          'title TEXT, '
          'posterPath TEXT, '
          'addedDate TEXT)'
        );
        
        await db.execute(
          'CREATE TABLE album_favorites('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'userEmail TEXT, '
          'albumId TEXT, '
          'albumName TEXT, '
          'artist TEXT, '
          'imageUrl TEXT, '
          'addedDate TEXT)'
        );
        
        await db.execute(
          'CREATE TABLE book_favorites('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'userEmail TEXT, '
          'bookId TEXT, '
          'title TEXT, '
          'author TEXT, '
          'coverUrl TEXT, '
          'addedDate TEXT)'
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'CREATE TABLE album_collection('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'userEmail TEXT, '
            'albumId TEXT, '
            'albumName TEXT, '
            'artist TEXT, '
            'imageUrl TEXT, '
            'format TEXT, '
            'addedDate TEXT)'
          );
        }
        
        if (oldVersion < 3) {
          // Add favorites tables
          await db.execute(
            'CREATE TABLE movie_favorites('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'userEmail TEXT, '
            'movieId INTEGER, '
            'title TEXT, '
            'posterPath TEXT, '
            'addedDate TEXT)'
          );
          
          await db.execute(
            'CREATE TABLE album_favorites('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'userEmail TEXT, '
            'albumId TEXT, '
            'albumName TEXT, '
            'artist TEXT, '
            'imageUrl TEXT, '
            'addedDate TEXT)'
          );
        }

        if (oldVersion < 4) {
          // Add books tables
          await db.execute(
            'CREATE TABLE book_collection('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'userEmail TEXT, '
            'bookId TEXT, '
            'title TEXT, '
            'author TEXT, '
            'coverUrl TEXT, '
            'format TEXT, '
            'addedDate TEXT)'
          );
          
          await db.execute(
            'CREATE TABLE book_favorites('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'userEmail TEXT, '
            'bookId TEXT, '
            'title TEXT, '
            'author TEXT, '
            'coverUrl TEXT, '
            'addedDate TEXT)'
          );
        }
      },
    );
  }

  Future<bool> addMovieToCollection(
    String userEmail, 
    int movieId, 
    String title,
    String posterPath, 
    String format
  ) async {
    try {
      final db = await database;
      
      // Check if movie already exists with this format in collection
      final List<Map<String, dynamic>> existingItems = await db.query(
        'collection',
        where: 'userEmail = ? AND movieId = ? AND format = ?',
        whereArgs: [userEmail, movieId, format],
      );

      if (existingItems.isNotEmpty) {
        return false; // Item already exists
      }

      await db.insert(
        'collection',
        {
          'userEmail': userEmail,
          'movieId': movieId,
          'title': title,
          'posterPath': posterPath,
          'format': format,
          'addedDate': DateTime.now().toIso8601String(),
        },
      );
      return true;
    } catch (e) {
      print('Error adding movie to collection: $e');
      return false;
    }
  }

  Future<bool> addAlbumToCollection(
    String userEmail,
    String albumId,
    String albumName,
    String artist,
    String imageUrl,
    String format
  ) async {
    try {
      final db = await database;
      
      // Vérifier si l'album existe déjà dans la collection avec ce format
      final List<Map<String, dynamic>> existingItems = await db.query(
        'album_collection',
        where: 'userEmail = ? AND albumId = ? AND format = ?',
        whereArgs: [userEmail, albumId, format],
      );

      if (existingItems.isNotEmpty) {
        return false; // L'élément existe déjà
      }

      await db.insert(
        'album_collection',
        {
          'userEmail': userEmail,
          'albumId': albumId,
          'albumName': albumName,
          'artist': artist,
          'imageUrl': imageUrl,
          'format': format,
          'addedDate': DateTime.now().toIso8601String(),
        },
      );
      return true;
    } catch (e) {
      print('Error adding album to collection: $e');
      return false;
    }
  }

  Future<bool> addBookToCollection(
    String userEmail,
    String bookId,
    String title,
    String author,
    String coverUrl,
    String format
  ) async {
    try {
      final db = await database;
      
      // Check if book already exists with this format in collection
      final List<Map<String, dynamic>> existingItems = await db.query(
        'book_collection',
        where: 'userEmail = ? AND bookId = ? AND format = ?',
        whereArgs: [userEmail, bookId, format],
      );

      if (existingItems.isNotEmpty) {
        return false; // Item already exists
      }

      await db.insert(
        'book_collection',
        {
          'userEmail': userEmail,
          'bookId': bookId,
          'title': title,
          'author': author,
          'coverUrl': coverUrl,
          'format': format,
          'addedDate': DateTime.now().toIso8601String(),
        },
      );
      return true;
    } catch (e) {
      print('Error adding book to collection: $e');
      return false;
    }
  }

  Future<List<CollectionItem>> getUserCollection(String userEmail) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'collection',
        where: 'userEmail = ?',
        whereArgs: [userEmail],
        orderBy: 'addedDate DESC',
      );

      return List.generate(maps.length, (i) {
        return CollectionItem(
          id: maps[i]['id'],
          userEmail: maps[i]['userEmail'],
          movieId: maps[i]['movieId'],
          title: maps[i]['title'],
          posterPath: maps[i]['posterPath'],
          format: maps[i]['format'],
          addedDate: DateTime.parse(maps[i]['addedDate']),
        );
      });
    } catch (e) {
      print('Error getting user collection: $e');
      return [];
    }
  }

  Future<List<dynamic>> getUserAlbumCollection(String userEmail) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'album_collection',
        where: 'userEmail = ?',
        whereArgs: [userEmail],
        orderBy: 'addedDate DESC',
      );

      return maps.map((item) {
        return {
          'id': item['id'],
          'userEmail': item['userEmail'],
          'albumId': item['albumId'],
          'albumName': item['albumName'],
          'artist': item['artist'],
          'imageUrl': item['imageUrl'],
          'format': item['format'],
          'addedDate': DateTime.parse(item['addedDate']),
          'type': 'album'  // Add type to distinguish from movies
        };
      }).toList();
    } catch (e) {
      print('Error getting user album collection: $e');
      return [];
    }
  }

  Future<List<dynamic>> getUserBookCollection(String userEmail) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'book_collection',
        where: 'userEmail = ?',
        whereArgs: [userEmail],
        orderBy: 'addedDate DESC',
      );

      return maps.map((item) {
        return {
          'id': item['id'],
          'userEmail': item['userEmail'],
          'bookId': item['bookId'],
          'title': item['title'],
          'author': item['author'],
          'coverUrl': item['coverUrl'],
          'format': item['format'],
          'addedDate': DateTime.parse(item['addedDate']),
          'type': 'book'
        };
      }).toList();
    } catch (e) {
      print('Error getting user book collection: $e');
      return [];
    }
  }

  Future<bool> removeFromCollection(int id) async {
    try {
      final db = await database;
      await db.delete(
        'collection',
        where: 'id = ?',
        whereArgs: [id],
      );
      return true;
    } catch (e) {
      print('Error removing from collection: $e');
      return false;
    }
  }

  Future<bool> removeAlbumFromCollection(int id) async {
    try {
      final db = await database;
      await db.delete(
        'album_collection',
        where: 'id = ?',
        whereArgs: [id],
      );
      return true;
    } catch (e) {
      print('Error removing album from collection: $e');
      return false;
    }
  }

  Future<bool> removeBookFromCollection(int id) async {
    try {
      final db = await database;
      await db.delete(
        'book_collection',
        where: 'id = ?',
        whereArgs: [id],
      );
      return true;
    } catch (e) {
      print('Error removing book from collection: $e');
      return false;
    }
  }

  Future<List<dynamic>> getFullUserCollection(String userEmail) async {
    // Get movies, albums and books
    final movies = await getUserCollection(userEmail);
    final albums = await getUserAlbumCollection(userEmail);
    final books = await getUserBookCollection(userEmail);
    
    // Convert movies to the same format as albums for consistency
    final formattedMovies = movies.map((movie) => {
      'id': movie.id,
      'userEmail': movie.userEmail,
      'movieId': movie.movieId,
      'title': movie.title,
      'posterPath': movie.posterPath,
      'format': movie.format,
      'addedDate': movie.addedDate,
      'type': 'movie'  // Add type to distinguish from albums
    }).toList();
    
    // Return combined list
    return [...formattedMovies, ...albums, ...books];
  }

  // ===== FAVORITES METHODS =====
  
  // Add a movie to favorites
  Future<bool> addMovieToFavorites(
    String userEmail,
    int movieId,
    String title,
    String posterPath,
  ) async {
    try {
      final db = await database;
      
      // Check if movie already exists in favorites
      final List<Map<String, dynamic>> existingItems = await db.query(
        'movie_favorites',
        where: 'userEmail = ? AND movieId = ?',
        whereArgs: [userEmail, movieId],
      );

      if (existingItems.isNotEmpty) {
        return false; // Already favorited
      }

      await db.insert(
        'movie_favorites',
        {
          'userEmail': userEmail,
          'movieId': movieId,
          'title': title,
          'posterPath': posterPath,
          'addedDate': DateTime.now().toIso8601String(),
        },
      );
      return true;
    } catch (e) {
      print('Error adding movie to favorites: $e');
      return false;
    }
  }
  
  // Remove a movie from favorites
  Future<bool> removeMovieFromFavorites(
    String userEmail,
    int movieId,
  ) async {
    try {
      final db = await database;
      await db.delete(
        'movie_favorites',
        where: 'userEmail = ? AND movieId = ?',
        whereArgs: [userEmail, movieId],
      );
      return true;
    } catch (e) {
      print('Error removing movie from favorites: $e');
      return false;
    }
  }
  
  // Check if a movie is favorited
  Future<bool> isMovieFavorite(
    String userEmail,
    int movieId,
  ) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> results = await db.query(
        'movie_favorites',
        where: 'userEmail = ? AND movieId = ?',
        whereArgs: [userEmail, movieId],
      );
      return results.isNotEmpty;
    } catch (e) {
      print('Error checking if movie is favorite: $e');
      return false;
    }
  }
  
  // Get all favorited movies
  Future<List<Map<String, dynamic>>> getFavoriteMovies(String userEmail) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'movie_favorites',
        where: 'userEmail = ?',
        whereArgs: [userEmail],
        orderBy: 'addedDate DESC',
      );
      
      return maps.map((item) => {
        ...item,
        'type': 'movie'
      }).toList();
    } catch (e) {
      print('Error getting favorite movies: $e');
      return [];
    }
  }
  
  // Album favorites methods
  Future<bool> addAlbumToFavorites(
    String userEmail,
    String albumId,
    String albumName,
    String artist,
    String imageUrl,
  ) async {
    try {
      final db = await database;
      
      // Check if album already exists in favorites
      final List<Map<String, dynamic>> existingItems = await db.query(
        'album_favorites',
        where: 'userEmail = ? AND albumId = ?',
        whereArgs: [userEmail, albumId],
      );

      if (existingItems.isNotEmpty) {
        return false; // Already favorited
      }

      await db.insert(
        'album_favorites',
        {
          'userEmail': userEmail,
          'albumId': albumId,
          'albumName': albumName,
          'artist': artist,
          'imageUrl': imageUrl,
          'addedDate': DateTime.now().toIso8601String(),
        },
      );
      return true;
    } catch (e) {
      print('Error adding album to favorites: $e');
      return false;
    }
  }
  
  Future<bool> removeAlbumFromFavorites(
    String userEmail,
    String albumId,
  ) async {
    try {
      final db = await database;
      await db.delete(
        'album_favorites',
        where: 'userEmail = ? AND albumId = ?',
        whereArgs: [userEmail, albumId],
      );
      return true;
    } catch (e) {
      print('Error removing album from favorites: $e');
      return false;
    }
  }
  
  Future<bool> isAlbumFavorite(
    String userEmail,
    String albumId,
  ) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> results = await db.query(
        'album_favorites',
        where: 'userEmail = ? AND albumId = ?',
        whereArgs: [userEmail, albumId],
      );
      return results.isNotEmpty;
    } catch (e) {
      print('Error checking if album is favorite: $e');
      return false;
    }
  }
  
  Future<List<Map<String, dynamic>>> getFavoriteAlbums(String userEmail) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'album_favorites',
        where: 'userEmail = ?',
        whereArgs: [userEmail],
        orderBy: 'addedDate DESC',
      );
      
      return maps.map((item) => {
        ...item,
        'type': 'album'
      }).toList();
    } catch (e) {
      print('Error getting favorite albums: $e');
      return [];
    }
  }

  // Book favorites methods
  Future<bool> addBookToFavorites(
    String userEmail,
    String bookId,
    String title,
    String author,
    String coverUrl,
  ) async {
    try {
      final db = await database;
      
      // Check if book already exists in favorites
      final List<Map<String, dynamic>> existingItems = await db.query(
        'book_favorites',
        where: 'userEmail = ? AND bookId = ?',
        whereArgs: [userEmail, bookId],
      );

      if (existingItems.isNotEmpty) {
        return false; // Already favorited
      }

      await db.insert(
        'book_favorites',
        {
          'userEmail': userEmail,
          'bookId': bookId,
          'title': title,
          'author': author,
          'coverUrl': coverUrl,
          'addedDate': DateTime.now().toIso8601String(),
        },
      );
      return true;
    } catch (e) {
      print('Error adding book to favorites: $e');
      return false;
    }
  }
  
  Future<bool> removeBookFromFavorites(
    String userEmail,
    String bookId,
  ) async {
    try {
      final db = await database;
      final count = await db.delete(
        'book_favorites',
        where: 'userEmail = ? AND bookId = ?',
        whereArgs: [userEmail, bookId],
      );
      return count > 0;
    } catch (e) {
      print('Error removing book from favorites: $e');
      return false;
    }
  }
  
  Future<bool> isBookFavorite(
    String userEmail,
    String bookId,
  ) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> result = await db.query(
        'book_favorites',
        where: 'userEmail = ? AND bookId = ?',
        whereArgs: [userEmail, bookId],
      );
      return result.isNotEmpty;
    } catch (e) {
      print('Error checking if book is favorite: $e');
      return false;
    }
  }
  
  Future<List<Map<String, dynamic>>> getFavoriteBooks(String userEmail) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'book_favorites',
        where: 'userEmail = ?',
        whereArgs: [userEmail],
        orderBy: 'addedDate DESC',
      );
      
      return maps.map((item) => {
        ...item,
        'type': 'book'
      }).toList();
    } catch (e) {
      print('Error getting favorite books: $e');
      return [];
    }
  }
  
  // Get all favorites (movies, albums and books)
  Future<List<Map<String, dynamic>>> getAllFavorites(String userEmail) async {
    final movies = await getFavoriteMovies(userEmail);
    final albums = await getFavoriteAlbums(userEmail);
    final books = await getFavoriteBooks(userEmail);
    return [...movies, ...albums, ...books];
  }

  // Méthode pour fermer la base de données
  Future<void> closeDatabase() async {
    final db = await database;
    db.close();
  }
}