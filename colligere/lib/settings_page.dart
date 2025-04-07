import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as Path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'main.dart';
import 'logout.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late String userEmail = '';
  late String username = '';
  late Database _database;
  bool _isLoading = true;
  
  // Contrôleurs pour les formulaires
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _deletePasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
    _loadUserData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _deletePasswordController.dispose();
    super.dispose();
  }

  Future<void> _initializeDatabase() async {
    _database = await openDatabase(
      Path.join(await getDatabasesPath(), 'login_database.db'),
      version: 2,
    );
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String email = prefs.getString('userEmail') ?? '';
      
      if (email.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }
      
      // Récupérer les données utilisateur depuis la base de données
      List<Map<String, dynamic>> result = await _database.query(
        'users',
        where: 'email = ?',
        whereArgs: [email],
      );
      
      if (result.isNotEmpty) {
        setState(() {
          userEmail = email;
          username = result[0]['username'] ?? email.split('@')[0];
          _usernameController.text = username;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Erreur lors du chargement des données utilisateur: $e');
      setState(() => _isLoading = false);
    }
  }
  
  void _showMessage(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }
  
  // Méthode pour mettre à jour le nom d'utilisateur
  Future<void> _updateUsername() async {
    String newUsername = _usernameController.text;
    
    if (newUsername.isEmpty || newUsername.length < 3) {
      _showMessage('Le nom d\'utilisateur doit contenir au moins 3 caractères');
      return;
    }
    
    if (newUsername == username) {
      _showMessage('Veuillez entrer un nom d\'utilisateur différent');
      return;
    }
    
    // Vérifier si le nom d'utilisateur existe déjà
    List<Map<String, dynamic>> existingUsers = await _database.query(
      'users',
      where: 'username = ? AND email != ?',
      whereArgs: [newUsername, userEmail],
    );
    
    if (existingUsers.isNotEmpty) {
      _showMessage('Ce nom d\'utilisateur est déjà utilisé');
      return;
    }
    
    // Mettre à jour dans la base de données
    await _database.update(
      'users',
      {'username': newUsername},
      where: 'email = ?',
      whereArgs: [userEmail],
    );
    
    // Mettre à jour dans les préférences partagées
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', newUsername);
    
    setState(() {
      username = newUsername;
    });
    
    _showMessage('Nom d\'utilisateur mis à jour avec succès');
  }
  
  // Méthode pour mettre à jour le mot de passe
  Future<void> _updatePassword() async {
    String currentPassword = _currentPasswordController.text;
    String newPassword = _newPasswordController.text;
    String confirmPassword = _confirmPasswordController.text;
    
    if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      _showMessage('Veuillez remplir tous les champs');
      return;
    }
    
    if (newPassword.length < 6) {
      _showMessage('Le nouveau mot de passe doit contenir au moins 6 caractères');
      return;
    }
    
    if (newPassword != confirmPassword) {
      _showMessage('Les mots de passe ne correspondent pas');
      return;
    }
    
    // Vérifier le mot de passe actuel
    String hashedCurrentPassword = _hashPassword(currentPassword);
    List<Map<String, dynamic>> user = await _database.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [userEmail, hashedCurrentPassword],
    );
    
    if (user.isEmpty) {
      _showMessage('Mot de passe actuel incorrect');
      return;
    }
    
    // Mettre à jour le mot de passe
    String hashedNewPassword = _hashPassword(newPassword);
    await _database.update(
      'users',
      {'password': hashedNewPassword},
      where: 'email = ?',
      whereArgs: [userEmail],
    );
    
    _showMessage('Mot de passe mis à jour avec succès');
    
    // Réinitialiser les champs
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
  }
  
  // Méthode pour supprimer le compte
  Future<void> _deleteAccount() async {
    String password = _deletePasswordController.text;
    
    if (password.isEmpty) {
      _showMessage('Veuillez entrer votre mot de passe pour confirmer la suppression');
      return;
    }
    
    // Vérifier le mot de passe
    String hashedPassword = _hashPassword(password);
    List<Map<String, dynamic>> user = await _database.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [userEmail, hashedPassword],
    );
    
    if (user.isEmpty) {
      _showMessage('Mot de passe incorrect');
      return;
    }
    
    // Confirmer la suppression
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 50, 65, 81),
        title: const Text('Supprimer le compte', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Cette action est irréversible. Tous vos données seront supprimées définitivement. Êtes-vous sûr de vouloir continuer?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmDelete != true) {
      return;
    }
    
    // Supprimer le compte de la base de données
    await _database.delete(
      'users',
      where: 'email = ?',
      whereArgs: [userEmail],
    );
    
    // Supprimer les informations de connexion des préférences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    _showMessage('Votre compte a été supprimé');
    
    // Rediriger vers la page de connexion
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 40, 55, 71),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(249, 52, 73, 94),
        foregroundColor: const Color.fromARGB(255, 245, 238, 248),
        title: const Text("Paramètres"),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Section info utilisateur
                  Card(
                    color: const Color.fromARGB(249, 52, 73, 94).withOpacity(0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Informations du compte',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ListTile(
                            title: const Text('Email', style: TextStyle(color: Colors.white70)),
                            subtitle: Text(userEmail, style: const TextStyle(color: Colors.white)),
                            leading: const Icon(Icons.email, color: Colors.white70),
                            contentPadding: EdgeInsets.zero,
                          ),
                          const Divider(color: Colors.white24),
                          const Text(
                            'Modifier le nom d\'utilisateur',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              labelText: 'Nouveau nom d\'utilisateur',
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.1),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _updateUsername,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(249, 52, 73, 94),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 48),
                            ),
                            child: const Text('Mettre à jour le nom d\'utilisateur'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Section changement de mot de passe
                  Card(
                    color: const Color.fromARGB(249, 52, 73, 94).withOpacity(0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Changer le mot de passe',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _currentPasswordController,
                            decoration: InputDecoration(
                              labelText: 'Mot de passe actuel',
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.1),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            obscureText: true,
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _newPasswordController,
                            decoration: InputDecoration(
                              labelText: 'Nouveau mot de passe',
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.1),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            obscureText: true,
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _confirmPasswordController,
                            decoration: InputDecoration(
                              labelText: 'Confirmer le nouveau mot de passe',
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.1),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            obscureText: true,
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _updatePassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(249, 52, 73, 94),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 48),
                            ),
                            child: const Text('Changer le mot de passe'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Section suppression de compte
                  Card(
                    color: Colors.redAccent.withOpacity(0.2),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Zone dangereuse',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'La suppression de votre compte est irréversible.',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _deletePasswordController,
                            decoration: InputDecoration(
                              labelText: 'Entrez votre mot de passe pour confirmer',
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.1),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            obscureText: true,
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _deleteAccount,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 48),
                            ),
                            child: const Text('Supprimer mon compte'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Bouton de déconnexion
                  ElevatedButton.icon(
                    onPressed: () => logout(context),
                    icon: const Icon(Icons.logout),
                    label: const Text('Déconnexion'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
