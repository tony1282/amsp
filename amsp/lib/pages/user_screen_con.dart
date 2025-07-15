import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserScreenCon extends StatefulWidget {
  const UserScreenCon({super.key});

  @override
  State<UserScreenCon> createState() => _UserScreenConState();
}

class _UserScreenConState extends State<UserScreenCon> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  String? _correo;
  String? _nombre;
  String? _telefono;
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
        _cargando = false;
      });
    }
  }

  Widget buildInfoBox(String label, String value, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
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
            border: Border.all(color: theme.colorScheme.secondary, width: 1),
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
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final secondaryColor = theme.colorScheme.secondary;
    final contrastColor = theme.appBarTheme.foregroundColor ?? Colors.white;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        centerTitle: true,
        title: Text(
          "Datos del usuario",
          style: theme.appBarTheme.titleTextStyle ??
              TextStyle(
                color: contrastColor,
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
                        : const CircleAvatar(radius: 60),
                  ),
                  Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    color: primaryColor,
                    child: Padding(
                      padding: const EdgeInsets.all(30.0),
                      child: Column(
                        children: [
                          buildInfoBox("Correo", _correo ?? '', theme),
                          buildInfoBox("Nombre", _nombre ?? '', theme),
                          buildInfoBox("Teléfono", _telefono ?? '', theme),
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
