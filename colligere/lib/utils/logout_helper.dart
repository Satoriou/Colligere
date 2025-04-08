import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
 // Assurez-vous que ce chemin est correct
// Utilisez l'un de ces imports selon l'emplacement de votre fichier login_page.dart
// import '../login_page.dart';
import '../main.dart'; // Si LoginPage est définie dans main.dart
// import 'package:colligere/login_page.dart'; // Import absolu si le fichier est à la racine de lib

class LogoutHelper {
  static Future<void> logout(BuildContext context) async {
    // Effacer les informations de connexion des préférences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('userEmail');
    await prefs.remove('username');
    
    if (context.mounted) {
      // Utiliser pushAndRemoveUntil pour effacer tout l'historique de navigation
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false, // Ne garde aucune route dans la pile
      );
    }
  }

  // Affiche une boîte de dialogue de confirmation avant la déconnexion
  static Future<void> confirmAndLogout(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 50, 65, 81),
        title: const Text('Déconnexion', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Voulez-vous vraiment vous déconnecter ?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Déconnexion', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await logout(context);
    }
  }
}
