import 'package:cloud_firestore/cloud_firestore.dart';

class AlbumService {
  final FirebaseFirestore firestore;

  AlbumService(this.firestore);

  Future<Map<String, dynamic>> getAlbumDetails(String albumId) async {
    try {
      final doc = await firestore.collection('albums').doc(albumId).get();
      if (doc.exists && doc.data() != null) {
        return doc.data()!;
      } else {
        // Retourner un map vide au lieu de null
        return {'error': 'Album non trouvé'};
      }
    } catch (e) {
      print("Erreur lors de la récupération de l'album: $e");
      // Retourner un map avec l'erreur au lieu de null
      return {'error': 'Erreur de chargement: ${e.toString()}'};
    }
  }
}