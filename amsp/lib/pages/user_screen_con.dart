import 'package:amsp/pages/inicio_sesion_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

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

  Future<void> _cerrarSesion() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const InicioSesion()),
    );
  }

  Future<void> _editarCampo({required String campo}) async {
    String valorActual = campo == 'name' ? (_nombre ?? '') : (_telefono ?? '');
    final controller = TextEditingController(text: valorActual);

    final resultado = await showDialog<String>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final primaryColor = theme.primaryColor; 

        return AlertDialog(
          backgroundColor: primaryColor, 
          title: Text(
            'Editar ${campo == 'name' ? 'Nombre' : 'Teléfono'}',
            style: const TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            keyboardType:
                campo == 'phone' ? TextInputType.phone : TextInputType.text,
            style: const TextStyle(color: Colors.white),
            inputFormatters: campo == 'phone'
                ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)]
                : null,
            decoration: InputDecoration(
              labelText: campo == 'name' ? 'Nombre' : 'Teléfono',
              labelStyle: const TextStyle(color: Colors.white70),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white70),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
            ),
            cursorColor: Colors.white,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.white),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white, 
                foregroundColor: primaryColor, 
              ),
              onPressed: () {
                if (controller.text.trim().isEmpty) return;
                Navigator.pop(context, controller.text.trim());
              },
              child: Text(
                'Guardar',
                style: TextStyle(color: primaryColor),
              ),
            ),
          ],
        );
      },
    );

    if (resultado != null) {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set(
          {campo: resultado},
          SetOptions(merge: true),
        );

        setState(() {
          if (campo == 'name') {
            _nombre = resultado;
          } else if (campo == 'phone') {
            _telefono = resultado;
          }
        });
      }
    }
  }

  Widget buildInfoBox(String label, String value, ThemeData theme,
      {VoidCallback? onEdit}) {
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
        if (onEdit != null)
          GestureDetector(
            onTap: onEdit,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.secondary, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: const TextStyle(color: Colors.black),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.edit,
                    size: 20,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          )
        else
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
              softWrap: true,
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
                          buildInfoBox(
                            "Correo",
                            _correo ?? '',
                            theme,
                          ),
                          buildInfoBox(
                            "Nombre",
                            _nombre ?? '',
                            theme,
                            onEdit: () => _editarCampo(campo: 'name'),
                          ),
                          buildInfoBox(
                            "Teléfono",
                            _telefono ?? '',
                            theme,
                            onEdit: () => _editarCampo(campo: 'phone'),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _cerrarSesion,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: secondaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                            ),
                            icon: const Icon(Icons.logout),
                            label: const Text("Cerrar sesión"),
                          ),
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
