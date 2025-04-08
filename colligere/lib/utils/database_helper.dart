import 'package:flutter/material.dart';
import 'package:path/path.dart' as Path;
import 'package:sqflite/sqflite.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class DatabaseHelper {
  static String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }
  
  // Create sample users for testing
  static Future<void> createSampleUsers() async {
    try {
      final db = await openDatabase(
        Path.join(await getDatabasesPath(), 'login_database.db'),
        version: 2,
      );
      
      // Check if users table exists
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='users'"
      );
      
      if (tables.isEmpty) {
        // Create users table if it doesn't exist
        await db.execute(
          "CREATE TABLE users(email TEXT PRIMARY KEY, username TEXT, password TEXT)"
        );
      }
      
      // Sample user data with SHA-256 hashed passwords
      final sampleUsers = [
        {
          'email': 'admin@example.com',
          'username': 'admin',
          'password': _hashPassword('admin123')
        },
        {
          'email': 'banane@example.com',
          'username': 'banane',
          'password': _hashPassword('banane123')
        }
      ];
      
      // Insert sample users
      for (var user in sampleUsers) {
        await db.insert(
          'users',
          user,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      
      print('Sample users created successfully');
    } catch (e) {
      print('Error creating sample users: $e');
    }
  }
  
  // Display a database utility dialog
  static void showDatabaseUtilityDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Database Utilities'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: () async {
                await createSampleUsers();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sample users created')),
                );
              },
              child: const Text('Create Sample Users'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                final db = await openDatabase(
                  Path.join(await getDatabasesPath(), 'login_database.db'),
                );
                final users = await db.query('users');
                await db.close();
                
                if (context.mounted) {
                  Navigator.pop(context);
                  
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('All Users'),
                      content: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: users.map((user) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                'Username: ${user['username']}\nEmail: ${user['email']}',
                                style: const TextStyle(fontSize: 16),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                }
              },
              child: const Text('List All Users'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
