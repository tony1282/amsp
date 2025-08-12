import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MostrarCodigoScreen extends StatefulWidget {
  final String codigo; // ID del documento Firestore
  final String tipo;
  final String nombre;

  const MostrarCodigoScreen({
    super.key,
    required this.codigo,
    required this.tipo,
    required this.nombre,
  });

  @override
  State<MostrarCodigoScreen> createState() => _MostrarCodigoScreenState();
}

class _MostrarCodigoScreenState extends State<MostrarCodigoScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Capitaliza cada palabra
  String _capitalizarCadaPalabra(String texto) {
    return texto.trim().split(RegExp(r'\s+')).map((palabra) {
      if (palabra.isEmpty) return '';
      return palabra[0].toUpperCase() + palabra.substring(1).toLowerCase();
    }).join(' ');
  }

  @override
  void initState() {
    super.initState();
    _actualizarNombreYTipo();
  }

  Future<void> _actualizarNombreYTipo() async {
    final nombreCap = _capitalizarCadaPalabra(widget.nombre);
    final tipoCap = _capitalizarCadaPalabra(widget.tipo);

    try {
      final docRef = _firestore.collection('circulos').doc(widget.codigo);
      final snapshot = await docRef.get();

      if (snapshot.exists) {
        final data = snapshot.data();
        final nombreActual = (data?['nombre'] ?? '') as String;
        final tipoActual = (data?['tipo'] ?? '') as String;

        if (nombreActual != nombreCap || tipoActual != tipoCap) {
          await docRef.update({
            'nombre': nombreCap,
            'tipo': tipoCap,
          });
          print('Nombre y tipo actualizados en Firestore');
        }
      }
    } catch (e) {
      print('Error actualizando nombre y tipo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Código del círculo'),
        backgroundColor: primary,
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 50),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primary, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.groups, size: 48, color: Colors.white),
                const SizedBox(height: 20),
                Text(
                  'Nombre del círculo:',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _capitalizarCadaPalabra(widget.nombre),
                  style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 20),
                Text(
                  'Tipo de círculo:',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _capitalizarCadaPalabra(widget.tipo).toUpperCase(),
                  style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 30),
                Text(
                  'Código para unirse:',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SelectableText(
                  widget.codigo,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Comparte este código con las personas que quieras agregar al círculo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
