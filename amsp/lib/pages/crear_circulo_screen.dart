import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:amsp/models/user_model.dart';
import 'mostrar_codigo_screen.dart';

class CrearCirculoScreen extends StatefulWidget {
  const CrearCirculoScreen({super.key});

  @override
  State<CrearCirculoScreen> createState() => _CrearCirculoScreenState();
}

class _CrearCirculoScreenState extends State<CrearCirculoScreen> {
  Future<void> _mostrarModalNombre(BuildContext context, String tipo) async {
    final TextEditingController _controller = TextEditingController();

    final BuildContext parentContext = context;
    final Color modalVerde = Theme.of(context).primaryColor;

    await showDialog(
      context: context,
      builder: (contextDialog) {
        return AlertDialog(
          backgroundColor: modalVerde,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          title: const Text(
            'Nombre del círculo',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'Ej. Familia López',
              hintStyle: const TextStyle(color: Colors.white70),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.white70),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.white),
              ),
            ),
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              child: const Text('Cancelar', style: TextStyle(color: Colors.white)),
              onPressed: () => Navigator.pop(contextDialog),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Crear'),
              onPressed: () async {
                final nombre = _controller.text.trim();
                if (nombre.isNotEmpty) {
                  Navigator.pop(contextDialog);
                  await _crearCirculo(parentContext, tipo, nombre);
                } else {
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    const SnackBar(content: Text('Por favor escribe un nombre')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _crearCirculo(
      BuildContext context, String tipo, String nombre) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario no autenticado')),
        );
        return;
      }

      final usuarioDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!usuarioDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario no encontrado')),
        );
        return;
      }

      final userData = usuarioDoc.data();
      final codigo = _generarCodigo();

      final miembro = {
        'uid': uid,
        'name': userData?['name'] ?? 'Sin nombre',
        'phone': userData?['phone'] ?? 'desconocido',
        'email': userData?['email'] ?? 'sin correo',
        'rol': userData?['rol'] ?? 'admin',
      };

      final nuevoCirculo = {
        'tipo': tipo,
        'nombre': nombre,
        'codigo': codigo,
        'creador': uid,
        'miembros': [miembro],
        'miembrosUids': [uid],
        'creadoEn': FieldValue.serverTimestamp(),
      };

      final docRef =
          await FirebaseFirestore.instance.collection('circulos').add(nuevoCirculo);

      // Guardar el mismo miembro como documento en subcolección
      await docRef.collection('miembros').doc(uid).set(miembro);

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MostrarCodigoScreen(
              codigo: codigo,
              tipo: tipo,
              nombre: nombre,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al crear círculo: $e')),
      );
    }
  }

  String _generarCodigo() {
    const letras = 'ABCDEFGHJKLMNPQRSTUVWXYZ123456789';
    final rand = Random();
    return List.generate(6, (_) => letras[rand.nextInt(letras.length)]).join();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final greenColor = theme.primaryColor;

    return Scaffold(
      appBar: AppBar(title: const Text('Crear un círculo')),
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 90, left: 40, right: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: greenColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 50,
                    vertical: 18,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _mostrarModalNombre(context, 'familia'),
                child: const Text('Crear Círculo Familiar'),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: greenColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 50,
                    vertical: 18,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _mostrarModalNombre(context, 'amistad'),
                child: const Text('Crear Círculo de Amigos'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
