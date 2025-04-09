import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as Path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'main.dart';
import 'package:colligere/utils/logout_helper.dart';
import 'package:flutter/foundation.dart';
import 'database_helper.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

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
  String? _profileImagePath;

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
      _profileImagePath = prefs.getString('profileImagePath');

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
        margin: const EdgeInsets.all(20),
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

  // Méthode pour changer la photo de profil
  Future<void> _changeProfileImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profileImagePath', image.path);
      
      setState(() {
        _profileImagePath = image.path;
      });
      
      _showMessage('Photo de profil mise à jour');
    }
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
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête avec info utilisateur
                  Container(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _changeProfileImage,
                          child: Stack(
                            children: [
                              _profileImagePath != null
                                ? CircleAvatar(
                                    radius: 50,
                                    backgroundImage: FileImage(File(_profileImagePath!)),
                                  )
                                : const CircleAvatar(
                                    radius: 50,
                                    backgroundColor: Colors.white24,
                                    child: Icon(
                                      Icons.person,
                                      size: 50,
                                      color: Colors.white,
                                    ),
                                  ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          username,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          userEmail,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const Divider(height: 1, thickness: 0.5, color: Colors.white10),
                  
                  // Section Compte
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Text(
                      'Compte',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  
                  // Modifier le nom d'utilisateur
                  _buildSettingItem(
                    icon: Icons.person_outline,
                    title: 'Nom d\'utilisateur',
                    onTap: () => _showUsernameDialog(),
                  ),
                  
                  // Modifier le mot de passe
                  _buildSettingItem(
                    icon: Icons.lock_outline,
                    title: 'Changer le mot de passe',
                    onTap: () => _showPasswordDialog(),
                  ),

                  // Modifier la photo de profil
                  _buildSettingItem(
                    icon: Icons.image_outlined,
                    title: 'Changer la photo de profil',
                    onTap: _changeProfileImage,
                  ),

                  const Divider(height: 1, thickness: 0.5, color: Colors.white10),
                  
                  // Section Debug (en mode debug seulement)
                  if (kDebugMode) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                      child: Text(
                        'Développement',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    _buildSettingItem(
                      icon: Icons.bug_report,
                      title: 'Outils de base de données',
                      onTap: () => DatabaseHelper.showDatabaseUtilityDialog(context),
                    ),
                    const Divider(height: 1, thickness: 0.5, color: Colors.white10),
                  ],

                  // Section Danger
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Text(
                      'Danger',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.red,
                      ),
                    ),
                  ),
                  
                  // Supprimer le compte
                  _buildSettingItem(
                    icon: Icons.delete_outline,
                    title: 'Supprimer mon compte',
                    textColor: Colors.red,
                    onTap: () => _showDeleteAccountDialog(),
                  ),
                  
                  // Déconnexion
                  _buildSettingItem(
                    icon: Icons.logout,
                    title: 'Déconnexion',
                    textColor: Colors.white70,
                    onTap: () => LogoutHelper.logout(context),
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
  
  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 20.0),
        child: Row(
          children: [
            Icon(icon, color: textColor ?? Colors.white, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: textColor ?? Colors.white,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withOpacity(0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // Dialogues
  void _showUsernameDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 50, 65, 81),
        title: const Text('Modifier le nom d\'utilisateur', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: _usernameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              _updateUsername();
              Navigator.pop(context);
            },
            child: const Text('Enregistrer', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }
  
  void _showPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 50, 65, 81),
        title: const Text('Changer le mot de passe', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _currentPasswordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Mot de passe actuel',
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Nouveau mot de passe',
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Confirmer le nouveau mot de passe',
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              _updatePassword();
              Navigator.pop(context);
            },
            child: const Text('Enregistrer', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }
  
  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 50, 65, 81),
        title: const Text('Supprimer le compte', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Cette action est irréversible. Toutes vos données seront supprimées définitivement.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _deletePasswordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Entrez votre mot de passe pour confirmer',
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              _deleteAccount();
              Navigator.pop(context);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
