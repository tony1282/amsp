import 'package:cloud_firestore/cloud_firestore.dart';

// Enum para definir los tipos de usuario posibles
enum TipoUsuario { admin, familiar }

// Modelo de usuario con sus propiedades y métodos para conversión
class UserModel {
  final String id; // ID único del usuario (generalmente el documento Firestore)
  final String nombreUsuario; // Nombre del usuario
  final String numeroTelefono; // Teléfono del usuario
  final String email; // Correo electrónico del usuario

  // Constructor con parámetros requeridos
  UserModel({
    required this.id,
    required this.nombreUsuario,
    required this.numeroTelefono,
    required this.email,
  });

  // Convierte el modelo a un mapa para guardar en Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': nombreUsuario,
      'phone': numeroTelefono,
      'email': email,
    };
  }

  // Crea una instancia de UserModel a partir de un DocumentSnapshot de Firestore
  factory UserModel.fromDocumentSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    // Si el documento no tiene datos, retornamos valores por defecto
    if (data == null) {
      return UserModel(
        id: doc.id,
        nombreUsuario: 'desconocido',
        numeroTelefono: 'desconocido',
        email: 'sin correo',
        //tipoUsuario: TipoUsuario.familiar,
      );
    }

    // Si existen datos, los extraemos con valores por defecto si faltan
    return UserModel(
      id: doc.id,
      nombreUsuario: data['name'] ?? 'desconocido',
      numeroTelefono: data['phone'] ?? 'desconocido',
      email: data['email'] ?? 'sin correo',
    );
  }


}
