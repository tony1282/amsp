import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserScreenCon extends StatefulWidget {
  const UserScreenCon({super.key});

  // Aquí las constantes estáticas de color
  static const Color backgroundColor = Color(0xFF248448);
  static const Color accentColor = Color.fromARGB(255, 0, 0, 0);

  @override
  State<UserScreenCon> createState() => _UserScreenConState();
}

class _UserScreenConState extends State<UserScreenCon> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  String? _correo;
  String? _nombre;
  String? _telefono;
  String? _tipoUsuario;
  String? _fotoURL;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _obtenerDatos();
  }

  Future<void> _obtenerDatos() async {
    final user = _auth.currentUser;

    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data();

      setState(() {
        _correo = user.email;
        _fotoURL = user.photoURL;
        _nombre = data?['name'] ?? 'No disponible';
        _telefono = data?['phone'] ?? 'No registrado';
        _tipoUsuario = data?['tipo_usuario'] ?? 'No especificado';
        _cargando = false;
      });
    }
  }

  Widget buildInfoBox(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color.fromARGB(255, 255, 249, 249),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color.fromARGB(255, 255, 123, 0), width: 1),
          ),
          child: Text(
            value,
            style: const TextStyle(color: Colors.black),
          ),
        ),
        const SizedBox(height: 15),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: UserScreenCon.backgroundColor,
        centerTitle: true,
        title: const Text(
          "Datos del usuario",
          style: TextStyle(
            color: Color.fromARGB(255, 255, 255, 255),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _fotoURL != null
                        ? CircleAvatar(
                            radius: 60,
                            backgroundImage: NetworkImage(_fotoURL!),
                          )
                        : const CircleAvatar(
                            radius: 60,
                          ),
                  ),
                  Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    color: UserScreenCon.backgroundColor,
                    child: Padding(
                      padding: const EdgeInsets.all(30.0),
                      child: Column(
                        children: [
                          buildInfoBox("Correo", _correo ?? ''),
                          buildInfoBox("Nombre", _nombre ?? ''),
                          buildInfoBox("Teléfono", _telefono ?? ''),
                          buildInfoBox("Tipo de usuario", _tipoUsuario ?? ''),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
