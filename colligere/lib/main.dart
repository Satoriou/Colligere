import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as Path;
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home.dart'; // Ensure this file defines a widget named Home

void main() async {
  // S'assurer que les plugins Flutter sont initialisés
  WidgetsFlutterBinding.ensureInitialized();
  
  // Vérifier si un utilisateur est déjà connecté
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  final email = prefs.getString('userEmail') ?? '';
  final username = prefs.getString('username') ?? '';
  
  runApp(MyApp(isLoggedIn: isLoggedIn, userEmail: email, username: username));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  final String userEmail;
  final String username;
  
  const MyApp({
    super.key, 
    required this.isLoggedIn, 
    required this.userEmail,
    required this.username
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Colligere',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color.fromARGB(249, 52, 73, 94),
        scaffoldBackgroundColor: const Color.fromARGB(255, 40, 55, 71),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(249, 52, 73, 94),
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.robotoTextTheme(
          ThemeData.dark().textTheme,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white70, width: 1),
          ),
          labelStyle: const TextStyle(color: Colors.white70),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(249, 52, 73, 94),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: isLoggedIn ? const Home() : const LoginPage(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const Home(),
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController(); // Nouveau champ
  late Database _database;
  bool _isLogin = true; // Basculer entre login et signup
  bool _rememberMe = true; // Option pour rester connecté
  bool _isLoading = false; // État de chargement
  
  // Pour l'animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
    
    // Initialiser les animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose(); // Disposer le nouveau contrôleur
    _animationController.dispose();
    super.dispose();
  }

  // Initialiser la base de données
  Future<void> _initializeDatabase() async {
    _database = await openDatabase(
      Path.join(await getDatabasesPath(), 'login_database.db'),
      onCreate: (db, version) {
        return db.execute(
          "CREATE TABLE users(email TEXT PRIMARY KEY, username TEXT, password TEXT)",
        );
      },
      version: 2, // Version mise à jour pour le schéma modifié
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Ajouter la colonne username si on met à jour d'une ancienne version
          await db.execute("ALTER TABLE users ADD COLUMN username TEXT");
        }
      },
    );
  }

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
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

  // Méthode pour sauvegarder les informations de connexion
  Future<void> _saveLoginSession(String email, String username) async {
    if (_rememberMe) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userEmail', email);
      await prefs.setString('username', username);
    }
  }

  // Méthode de connexion
  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showMessage('Veuillez remplir tous les champs');
      return;
    }
    
    setState(() => _isLoading = true);
    
    String emailOrUsername = _emailController.text;
    String password = _hashPassword(_passwordController.text);

    try {
      // Recherche par email ou par nom d'utilisateur
      List<Map<String, dynamic>> result = await _database.query(
        'users',
        where: 'email = ? OR username = ?',
        whereArgs: [emailOrUsername, emailOrUsername],
      );

      if (result.isNotEmpty && result[0]['password'] == password) {
        // Récupérer le nom d'utilisateur et l'email
        final email = result[0]['email'] as String;
        final username = result[0]['username'] as String? ?? email.split('@')[0];

        // Sauvegarder la session si "Se souvenir de moi" est activé
        await _saveLoginSession(email, username);
        
        _showMessage('Connexion réussie');
        
        if (!context.mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Home()),
        );
      } else {
        _showMessage('Identifiants incorrects');
      }
    } catch (e) {
      print("Erreur de connexion: $e");
      _showMessage('Une erreur est survenue. Veuillez réessayer.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Méthode d'inscription
  Future<void> _register() async {
    if (_emailController.text.isEmpty || 
        _passwordController.text.isEmpty ||
        _usernameController.text.isEmpty) {
      _showMessage('Veuillez remplir tous les champs');
      return;
    }
    
    setState(() => _isLoading = true);
    
    String email = _emailController.text;
    String password = _passwordController.text;
    String username = _usernameController.text;

    if (!RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$").hasMatch(email)) {
      _showMessage('Email invalide');
      setState(() => _isLoading = false);
      return;
    }

    if (password.length < 6) {
      _showMessage('Mot de passe trop court (min. 6 caractères)');
      setState(() => _isLoading = false);
      return;
    }
    
    if (username.length < 3) {
      _showMessage('Nom d\'utilisateur trop court (min. 3 caractères)');
      setState(() => _isLoading = false);
      return;
    }
    
    // Vérifier si le nom d'utilisateur existe déjà
    List<Map<String, dynamic>> existingUsers = await _database.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );
    
    if (existingUsers.isNotEmpty) {
      _showMessage('Ce nom d\'utilisateur est déjà utilisé');
      setState(() => _isLoading = false);
      return;
    }

    String hashedPassword = _hashPassword(password);

    try {
      await _database.insert(
        'users',
        {'email': email, 'username': username, 'password': hashedPassword},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      _showMessage('Compte créé avec succès !');
      
      // Basculer automatiquement vers l'écran de connexion
      setState(() {
        _isLogin = true;
        _isLoading = false;
        // Pré-remplir le champ email avec l'email qui vient d'être enregistré
        _emailController.text = email;
        _passwordController.text = '';
      });
    } catch (e) {
      print("Erreur d'inscription: $e");
      _showMessage('Une erreur est survenue. Veuillez réessayer.');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 40, 55, 71),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Logo de l'application - remplacer par une image
                  Image.asset(
                    'assets/colligere_logo.png', // Chemin vers votre image de logo
                    height: 120, // Ajustez la taille selon vos besoins
                    width: 120,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Titre de l'application
                  Text(
                    'Colligere',
                    style: GoogleFonts.roboto(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Sous-titre
                  Text(
                    _isLogin ? 'Connexion à votre compte' : 'Créer un nouveau compte',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Champ pour le nom d'utilisateur (seulement à l'inscription)
                  if (!_isLogin)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: TextField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: 'Nom d\'utilisateur',
                          prefixIcon: const Icon(Icons.person_outline, color: Colors.white70),
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  
                  // Champ de texte pour l'email ou nom d'utilisateur
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: _isLogin ? 'Email ou nom d\'utilisateur' : 'Email',
                      prefixIcon: const Icon(Icons.email_outlined, color: Colors.white70),
                    ),
                    keyboardType: _isLogin ? TextInputType.text : TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Champ de texte pour le mot de passe
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
                    ),
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Option "Se souvenir de moi" (visible uniquement sur l'écran de connexion)
                  if (_isLogin)
                    Row(
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged: (value) {
                            setState(() {
                              _rememberMe = value ?? true;
                            });
                          },
                          fillColor: MaterialStateProperty.all(Colors.white70),
                          checkColor: const Color.fromARGB(249, 52, 73, 94),
                        ),
                        const Text(
                          'Se souvenir de moi',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Bouton principal (Connexion ou Inscription)
                  ElevatedButton(
                    onPressed: _isLoading ? null : (_isLogin ? _login : _register),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(_isLogin ? 'Se connecter' : 'S\'inscrire'),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Lien pour basculer entre connexion et inscription
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLogin = !_isLogin;
                        // Réinitialiser les champs
                        if (!_isLogin) {
                          _usernameController.clear();
                        }
                      });
                    },
                    child: Text(
                      _isLogin
                          ? 'Pas encore de compte ? S\'inscrire'
                          : 'Déjà un compte ? Se connecter',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
