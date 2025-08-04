import 'package:amsp/models/user_model.dart'; // Modelo de usuario personalizado
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore de Firebase

class CloudFirestoreService {
  // Instancia privada estática para implementar singleton (una única instancia)
  static final CloudFirestoreService _instance = 
      CloudFirestoreService._internal();

  // Referencia a la instancia de Firestore
  final FirebaseFirestore _cloudFirestore = FirebaseFirestore.instance;

  // Constructor factory que siempre devuelve la misma instancia
  factory CloudFirestoreService() {
    return _instance;
  }

  // Constructor interno privado para evitar que se creen otras instancias
  CloudFirestoreService._internal();

  // Método que devuelve un stream de lista de usuarios desde una colección Firestore
  Stream<List<UserModel>> getUser(String collection) {
    return _cloudFirestore
        .collection(collection) // Accede a la colección especificada
        .snapshots()            // Obtiene un stream de snapshots (cambios en tiempo real)
        .map((Snapshot) {
          // Por cada snapshot, transforma los documentos en una lista de UserModel
          return Snapshot.docs
              .map((doc) => UserModel.fromDocumentSnapshot(doc)) // Convierte cada doc a UserModel
              .toList(); // Convierte el iterable a lista
        });
  }
}
