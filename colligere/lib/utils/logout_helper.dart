import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class LogoutHelper {
  static Future<void> logout(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Conserver les données importantes pour le débogage
      final email = prefs.getString('userEmail');
      final username = prefs.getString('username');
      print('Déconnexion - Email: $email, Username: $username');
      
      // Marquer l'utilisateur comme déconnecté mais conserver les identifiants
      // pour faciliter la reconnexion
      await prefs.setBool('isLoggedIn', false);
      
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      print('Erreur lors de la déconnexion: $e');
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }
  
  static void confirmAndLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 50, 65, 81),
        title: const Text('Déconnexion', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Êtes-vous sûr de vouloir vous déconnecter ?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Appeler la méthode statique correctement
              logout(context);
            },
            child: const Text('Se déconnecter', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }
}
