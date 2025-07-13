import 'package:cloud_firestore/cloud_firestore.dart';

enum TipoUsuario { admin, familiar }

class UserModel {
  final String id;
  final String nombreUsuario;
  final String numeroTelefono;
  final TipoUsuario tipoUsuario; 


UserModel({
  required this.id,
  required this.nombreUsuario,
  required this.numeroTelefono,
  required this.tipoUsuario,
});

Map<String, dynamic> toMap() {
  return{
    'nombre': nombreUsuario,
    'numero': numeroTelefono,
    'rol': tipoUsuario.name,
  };
}

factory UserModel.fromDocumentSnapshot(DocumentSnapshot doc) {
  final data = doc.data() as Map<String,dynamic>?;
     
      if (data == null) {
      throw Exception('Documento sin datos');
    }

  return UserModel(
    id: doc.id,
    nombreUsuario: data['nombre'] ?? 'desconocido',
    numeroTelefono: data['numero'] ?? 'desconocido',
    tipoUsuario: _rolFromString(data['rol'] ?? 'familiar'),
  );
}

static TipoUsuario _rolFromString(String rol) {
    return TipoUsuario.values.firstWhere(
      (e) => e.name == rol,
      orElse: () => TipoUsuario.admin,
    );
  }
}