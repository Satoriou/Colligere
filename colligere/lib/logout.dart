import 'package:flutter/material.dart';
import 'utils/logout_helper.dart';

// Fonction pour déconnecter l'utilisateur
Future<void> logout(BuildContext context) async {
  await LogoutHelper.confirmAndLogout(context);
}
