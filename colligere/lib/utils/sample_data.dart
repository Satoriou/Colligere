import 'package:sqflite/sqflite.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class SampleDataGenerator {
  // Hash function for creating passwords
  static String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  // Add sample users to the login database
  static Future<void> addSampleUsers(Database loginDatabase) async {
    final sampleUsers = [
      {
        'email': 'test@example.com',
        'username': 'TestUser',
        'password': _hashPassword('password123')
      },
      {
        'email': 'user1@example.com',
        'username': 'User1',
        'password': _hashPassword('password123')
      },
      {
        'email': 'user2@example.com',
        'username': 'User2',
        'password': _hashPassword('password123')
      }
    ];
    
    // Check if table exists
    final tables = await loginDatabase.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='users'");
    
    if (tables.isEmpty) {
      // Create the users table if it doesn't exist
      await loginDatabase.execute(
        'CREATE TABLE users(id INTEGER PRIMARY KEY, email TEXT, username TEXT, password TEXT)'
      );
    }
    
    // Insert sample users
    for (var user in sampleUsers) {
      // Check if user already exists
      final existingUser = await loginDatabase.query(
        'users',
        where: 'email = ?',
        whereArgs: [user['email']],
      );
      
      // Only insert if the user doesn't exist
      if (existingUser.isEmpty) {
        await loginDatabase.insert('users', user);
        print('Added sample user: ${user['email']}');
      }
    }
  }
  
  // Create sample collections in collection database
  static Future<void> createSampleCollections(Database collectionDatabase) async {
    // Add some sample movies to collections for various users
    final sampleMovies = [
      {
        'userEmail': 'test@example.com',
        'movieId': 550,
        'title': 'Fight Club',
        'posterPath': '/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg',
        'format': 'Blu-ray',
        'addedDate': DateTime.now().toIso8601String(),
      },
      {
        'userEmail': 'user1@example.com',
        'movieId': 278,
        'title': 'The Shawshank Redemption',
        'posterPath': '/q6y0Go1tsGEsmtFryDOJo3dEmqu.jpg',
        'format': 'DVD',
        'addedDate': DateTime.now().toIso8601String(),
      },
    ];
    
    for (var movie in sampleMovies) {
      // Insert if not exists
      final existing = await collectionDatabase.query(
        'collection',
        where: 'userEmail = ? AND movieId = ? AND format = ?',
        whereArgs: [movie['userEmail'], movie['movieId'], movie['format']],
      );
      
      if (existing.isEmpty) {
        await collectionDatabase.insert('collection', movie);
        print('Added sample movie to collection: ${movie['title']} for ${movie['userEmail']}');
      }
    }
  }
}
