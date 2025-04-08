import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CollectionApi {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Obtenir l'ID de l'utilisateur connecté
  String? get _userId => _auth.currentUser?.uid;

  // Vérifier si un élément est déjà dans la collection
  Future<bool> isItemInCollection(String collectionName, String itemId) async {
    try {
      if (_userId == null) return false;
      
      final doc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection(collectionName)
          .doc(itemId)
          .get();
          
      return doc.exists;
    } catch (e) {
      print('Error checking if item is in collection: $e');
      return false;
    }
  }

  // Ajouter un élément à la collection
  Future<void> addToCollection(String collectionName, Map<String, dynamic> data) async {
    try {
      if (_userId == null) {
        throw Exception('Vous devez être connecté pour ajouter à votre collection');
      }
      
      // Ajouter la date d'ajout
      data['added_at'] = FieldValue.serverTimestamp();
      
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection(collectionName)
          .doc(data['id'])
          .set(data);
    } catch (e) {
      print('Error adding to collection: $e');
      rethrow; // Relancer l'exception pour la gérer au niveau supérieur
    }
  }

  // Supprimer un élément de la collection
  Future<void> removeFromCollection(String collectionName, String itemId) async {
    try {
      if (_userId == null) {
        throw Exception('Vous devez être connecté pour supprimer de votre collection');
      }
      
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection(collectionName)
          .doc(itemId)
          .delete();
    } catch (e) {
      print('Error removing from collection: $e');
      rethrow;
    }
  }

  // Obtenir tous les éléments d'une collection
  Future<List<Map<String, dynamic>>> getCollection(String collectionName) async {
    try {
      if (_userId == null) return [];
      
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection(collectionName)
          .orderBy('added_at', descending: true)
          .get();
          
      return snapshot.docs
          .map((doc) => doc.data())
          .toList();
    } catch (e) {
      print('Error getting collection: $e');
      return [];
    }
  }
}
