import 'package:cloud_firestore/cloud_firestore.dart';
enum TipoUsuario { admin, familiar }

class UserModel {
  final String id; 
  final String nombreUsuario; 
  final String numeroTelefono; 
  final String email; 

  UserModel({
    required this.id,
    required this.nombreUsuario,
    required this.numeroTelefono,
    required this.email,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': nombreUsuario,
      'phone': numeroTelefono,
      'email': email,
    };
  }

  factory UserModel.fromDocumentSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    if (data == null) {
      return UserModel(
        id: doc.id,
        nombreUsuario: 'desconocido',
        numeroTelefono: 'desconocido',
        email: 'sin correo',
      );
    }

    return UserModel(
      id: doc.id,
      nombreUsuario: data['name'] ?? 'desconocido',
      numeroTelefono: data['phone'] ?? 'desconocido',
      email: data['email'] ?? 'sin correo',
    );
  }


}
