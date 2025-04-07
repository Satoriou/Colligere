import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';

// Fonction pour déconnecter l'utilisateur
Future<void> logout(BuildContext context) async {
  // Afficher un dialogue de confirmation
  final shouldLogout = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color.fromARGB(255, 50, 65, 81),
      title: const Text('Déconnexion', style: TextStyle(color: Colors.white)),
      content: const Text('Voulez-vous vraiment vous déconnecter ?', style: TextStyle(color: Colors.white70)),
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
  ) ?? false;

  if (shouldLogout) {
    // Effacer les informations de connexion des préférences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('userEmail');

    // Redirection vers la page de connexion
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }
}
