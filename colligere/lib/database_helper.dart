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
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sample users created')),
                  );
                }
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
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                // Ajoutons un bouton pour tester la connexion avec le nom d'utilisateur
                final usernameController = TextEditingController();
                final passwordController = TextEditingController();
                
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Test de connexion'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: usernameController,
                          decoration: const InputDecoration(labelText: 'Nom d\'utilisateur ou email'),
                        ),
                        TextField(
                          controller: passwordController,
                          decoration: const InputDecoration(labelText: 'Mot de passe'),
                          obscureText: true,
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Annuler'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final db = await openDatabase(
                            Path.join(await getDatabasesPath(), 'login_database.db'),
                          );
                          
                          final username = usernameController.text.trim();
                          final password = passwordController.text;
                          final hashedPassword = _hashPassword(password);
                          
                          // Recherche par email
                          final usersByEmail = await db.query(
                            'users',
                            where: 'email = ? AND password = ?',
                            whereArgs: [username, hashedPassword],
                          );
                          
                          // Recherche par nom d'utilisateur
                          final usersByUsername = await db.query(
                            'users',
                            where: 'username = ? AND password = ?',
                            whereArgs: [username, hashedPassword],
                          );
                          
                          await db.close();
                          
                          if (context.mounted) {
                            Navigator.pop(context);
                            
                            if (usersByEmail.isNotEmpty || usersByUsername.isNotEmpty) {
                              final user = usersByEmail.isNotEmpty ? usersByEmail.first : usersByUsername.first;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Connexion réussie - Email: ${user['email']}, Username: ${user['username']}')),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Échec de connexion - Identifiants incorrects')),
                              );
                            }
                          }
                        },
                        child: const Text('Tester'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Test de connexion'),
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

  static void changeUsername(String userEmail, String newUsername) {}
}
