import 'package:cloud_firestore/cloud_firestore.dart';

enum TipoUsuario { admin, familiar }

class UserModel {
  final String id;
  final String nombreUsuario;
  final String numeroTelefono;
  final String email;
  final TipoUsuario tipoUsuario;

  UserModel({
    required this.id,
    required this.nombreUsuario,
    required this.numeroTelefono,
    required this.email,
    required this.tipoUsuario,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': nombreUsuario,
      'phone': numeroTelefono,
      'email': email,
      'rol': tipoUsuario.name,
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
        tipoUsuario: TipoUsuario.familiar,
      );
    }

    return UserModel(
      id: doc.id,
      nombreUsuario: data['name'] ?? 'desconocido',
      numeroTelefono: data['phone'] ?? 'desconocido',
      email: data['email'] ?? 'sin correo',
      tipoUsuario: _rolFromString(data['rol'] ?? 'familiar'),
    );
  }

  static TipoUsuario _rolFromString(String rol) {
    final rolLower = rol.toLowerCase();
    return TipoUsuario.values.firstWhere(
      (e) => e.name.toLowerCase() == rolLower,
      orElse: () => TipoUsuario.familiar,
    );
  }
}
