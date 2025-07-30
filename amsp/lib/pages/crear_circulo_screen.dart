// CrearCirculoScreen (modificado)
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

    await showDialog(
      context: context,
      builder: (contextDialog) {
        return AlertDialog(
          title: const Text('Nombre del círculo'),
          content: TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: 'Ej. Familia López',
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.pop(contextDialog),
            ),
            ElevatedButton(
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

      final docRef = await FirebaseFirestore.instance.collection('circulos').add(nuevoCirculo);

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
    return Scaffold(
      appBar: AppBar(title: const Text('Crear un círculo')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _mostrarModalNombre(context, 'familia'),
              child: const Text('Crear Círculo Familiar'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _mostrarModalNombre(context, 'amistad'),
              child: const Text('Crear Círculo de Amigos'),
            ),
          ],
        ),
      ),
    );
  }
}
