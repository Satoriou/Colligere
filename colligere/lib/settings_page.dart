import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as Path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'main.dart';
import 'package:colligere/utils/logout_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:colligere/utils/database_helper.dart';

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
  final ImagePicker _picker = ImagePicker();

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
      // Utiliser l'email de l'utilisateur comme partie de la clé pour charger la photo
      _profileImagePath = prefs.getString('profileImagePath_$email');

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

  // Version corrigée utilisant DatabaseHelper avec gestion d'erreurs améliorée
  Future<void> _updateUsername() async {
    String newUsername = _usernameController.text.trim();

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

    try {
      // Utiliser la méthode statique de DatabaseHelper pour changer le nom d'utilisateur
      await DatabaseHelper.changeUsername(userEmail, newUsername);
      
      // Mise à jour des préférences seulement après réussite de la mise à jour de la BD
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', newUsername);

      setState(() {
        username = newUsername;
      });

      _showMessage('Nom d\'utilisateur mis à jour avec succès');
      
      // Afficher le dialogue pour se déconnecter
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color.fromARGB(255, 50, 65, 81),
            title: const Text('Nom d\'utilisateur mis à jour', style: TextStyle(color: Colors.white)),
            content: const Text(
              'Votre nom d\'utilisateur a été mis à jour. Pour utiliser votre nouveau nom d\'utilisateur à la connexion, vous devez vous déconnecter puis vous reconnecter.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Plus tard', style: TextStyle(color: Colors.white70)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  LogoutHelper.logout(context);
                },
                child: const Text('Se déconnecter', style: TextStyle(color: Colors.blue)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('Erreur lors de la mise à jour du nom d\'utilisateur: $e');
      _showMessage('Erreur lors de la mise à jour: ${e.toString()}');
    }
  }

  // Méthode pour mettre à jour le mot de passe utilisant DatabaseHelper
  Future<void> _updatePassword() async {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      _showMessage('Tous les champs doivent être remplis');
      return;
    }

    if (newPassword != confirmPassword) {
      _showMessage('Les nouveaux mots de passe ne correspondent pas');
      return;
    }

    if (newPassword.length < 6) {
      _showMessage('Le nouveau mot de passe doit contenir au moins 6 caractères');
      return;
    }

    // Vérifier l'ancien mot de passe
    final hashedCurrentPassword = _hashPassword(currentPassword);
    List<Map<String, dynamic>> result = await _database.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [userEmail, hashedCurrentPassword],
    );

    if (result.isEmpty) {
      _showMessage('Mot de passe actuel incorrect');
      return;
    }

    try {
      // Utiliser la méthode statique de DatabaseHelper pour changer le mot de passe
      await DatabaseHelper.changePassword(userEmail, newPassword);
      
      // Réinitialiser les contrôleurs
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      _showMessage('Mot de passe mis à jour avec succès');
    } catch (e) {
      print('Erreur lors de la mise à jour du mot de passe: $e');
      _showMessage('Erreur lors de la mise à jour: ${e.toString()}');
    }
  }

  // Méthode pour supprimer le compte
  Future<void> _deleteAccount() async {
    final password = _deletePasswordController.text;

    if (password.isEmpty) {
      _showMessage('Veuillez entrer votre mot de passe pour confirmer');
      return;
    }

    // Vérifier le mot de passe
    final hashedPassword = _hashPassword(password);
    List<Map<String, dynamic>> result = await _database.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [userEmail, hashedPassword],
    );

    if (result.isEmpty) {
      _showMessage('Mot de passe incorrect');
      return;
    }

    // Supprimer le compte
    await _database.delete(
      'users',
      where: 'email = ?',
      whereArgs: [userEmail],
    );

    // Supprimer les données des préférences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // Retourner à l'écran de connexion
    if (context.mounted) {
      _showMessage('Compte supprimé avec succès');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }
  
  // Méthode pour changer la photo de profil
  Future<void> _changeProfileImage() async {
    try {
      // Afficher une boîte de dialogue pour choisir entre la caméra et la galerie
      showModalBottomSheet(
        backgroundColor: const Color.fromARGB(255, 50, 65, 81),
        context: context,
        builder: (BuildContext context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Colors.white),
                  title: const Text('Galerie de photos', style: TextStyle(color: Colors.white)),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _pickImageFrom(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera, color: Colors.white),
                  title: const Text('Appareil photo', style: TextStyle(color: Colors.white)),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _pickImageFrom(ImageSource.camera);
                  },
                ),
                if (_profileImagePath != null)
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text('Supprimer la photo', style: TextStyle(color: Colors.red)),
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _removeProfileImage();
                    },
                  ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      print('Erreur dans _changeProfileImage: $e');
      _showMessage('Erreur lors de l\'ouverture du sélecteur d\'image: $e');
    }
  }
  
  // Méthode auxiliaire pour sélectionner une image
  Future<void> _pickImageFrom(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (pickedFile != null) {
        print('Image sélectionnée: ${pickedFile.path}');
        
        // Vérifier si le fichier existe
        if (!File(pickedFile.path).existsSync()) {
          _showMessage('Erreur: le fichier image n\'existe pas');
          return;
        }
        
        // Enregistrer le chemin de l'image avec une clé spécifique à l'utilisateur
        final prefs = await SharedPreferences.getInstance();
        // Utiliser l'email de l'utilisateur comme partie de la clé
        await prefs.setString('profileImagePath_$userEmail', pickedFile.path);
        
        setState(() {
          _profileImagePath = pickedFile.path;
        });
        
        _showMessage('Photo de profil mise à jour');
      } else {
        print('Aucune image sélectionnée');
      }
    } catch (e) {
      print('Erreur dans _pickImageFrom: $e');
      _showMessage('Erreur lors de la sélection de l\'image: $e');
    }
  }
  
  // Méthode pour supprimer la photo de profil
  Future<void> _removeProfileImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Utiliser l'email de l'utilisateur comme partie de la clé
      await prefs.remove('profileImagePath_$userEmail');
      
      setState(() {
        _profileImagePath = null;
      });
      
      _showMessage('Photo de profil supprimée');
    } catch (e) {
      print('Erreur dans _removeProfileImage: $e');
      _showMessage('Erreur lors de la suppression de la photo: $e');
    }
  }

  // Méthode améliorée pour afficher la boîte de dialogue de changement de nom d'utilisateur
  void _showUsernameDialog() {
    _usernameController.text = username; // Remplir avec le nom d'utilisateur actuel
    
    showDialog(
      context: context,
      barrierDismissible: false, // L'utilisateur doit utiliser les boutons
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 50, 65, 81),
        title: const Text('Modifier le nom d\'utilisateur', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _usernameController,
              style: const TextStyle(color: Colors.white),
              autofocus: true, // Mettre le focus automatiquement
              decoration: InputDecoration(
                labelText: 'Nouveau nom d\'utilisateur',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Le nom d\'utilisateur doit contenir au moins 3 caractères.',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _updateUsername(); // Appeler _updateUsername après fermeture de la boîte de dialogue
            },
            child: const Text('Enregistrer', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
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
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.white24,
                                backgroundImage: _profileImagePath != null && File(_profileImagePath!).existsSync()
                                  ? FileImage(File(_profileImagePath!))
                                  : null,
                                child: _profileImagePath == null || !File(_profileImagePath!).existsSync()
                                  ? const Icon(
                                      Icons.person,
                                      size: 50,
                                      color: Colors.white,
                                    )
                                  : null,
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
  
  void _showPasswordDialog() {
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    
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
                labelStyle: const TextStyle(color: Colors.white70),
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
                labelStyle: const TextStyle(color: Colors.white70),
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
                labelStyle: const TextStyle(color: Colors.white70),
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
    _deletePasswordController.clear();
    
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
                labelStyle: const TextStyle(color: Colors.white70),
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
