import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/firebase_environment.dart';

/// Fuente remota, exclusivamente de lectura. Ningún widget usa Firestore.
class FirestoreCatalogDataSource {
  FirestoreCatalogDataSource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseEnvironment.firestore;

  final FirebaseFirestore _firestore;

  Stream<QuerySnapshot<Map<String, dynamic>>> watchActiveProducts() =>
      _firestore
          .collection('productos')
          .where('estado', isEqualTo: true)
          .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchCategories() =>
      _firestore.collection('categorias').snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchBatches() =>
      _firestore.collection('lotes_productos').snapshots();
}
