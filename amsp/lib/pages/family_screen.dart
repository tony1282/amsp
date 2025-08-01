import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'circulo_detalle_screen.dart'; // Nuevo archivo para detalle

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  late final String uid;

  @override
  void initState() {
    super.initState();
    uid = _auth.currentUser!.uid;
  }

  Future<List<QueryDocumentSnapshot>> _getCirculosCreados() async {
    final snapshot = await _firestore
        .collection('circulos')
        .where('creador', isEqualTo: uid)
        .get();
    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot>> _getCirculosUnido() async {
    final todosLosCirculos = await _firestore.collection('circulos').get();

    List<QueryDocumentSnapshot> unidos = [];

    for (var circulo in todosLosCirculos.docs) {
      final data = circulo.data() as Map<String, dynamic>;
      final miembros = data['miembros'] as List<dynamic>? ?? [];

      final estaEnCirculo = miembros.any((miembro) {
        return miembro['uid'] == uid;
      });

      if (estaEnCirculo) {
        unidos.add(circulo);
      }
    }

    return unidos;
  }

  Future<void> _eliminarCirculo(String circleId) async {
    try {
      // Primero elimina subcolección miembros
      final miembrosSnapshot = await _firestore
          .collection('circulos')
          .doc(circleId)
          .collection('miembros')
          .get();
      for (var doc in miembrosSnapshot.docs) {
        await doc.reference.delete();
      }
      // Luego elimina el documento círculo
      await _firestore.collection('circulos').doc(circleId).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Círculo eliminado')),
        );
        setState(() {}); // refrescar lista
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
    }
  }

  Future<void> _editarCirculo(String circleId, String nombreActual, String tipoActual) async {
    final nombreController = TextEditingController(text: nombreActual);
    final tipoController = TextEditingController(text: tipoActual);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Círculo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: tipoController,
              decoration: const InputDecoration(labelText: 'Tipo'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nuevoNombre = nombreController.text.trim();
              final nuevoTipo = tipoController.text.trim();
              if (nuevoNombre.isEmpty || nuevoTipo.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Debe llenar ambos campos')),
                );
                return;
              }
              await _firestore.collection('circulos').doc(circleId).update({
                'nombre': nuevoNombre,
                'tipo': nuevoTipo,
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Círculo actualizado')),
                );
              }
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final greenColor = theme.primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi familia'),
        centerTitle: true,
        backgroundColor: greenColor,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<List<QueryDocumentSnapshot>>>(
        future: Future.wait([
          _getCirculosCreados(),
          _getCirculosUnido(),
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Colors.green,
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: theme.textTheme.bodyMedium,
              ),
            );
          }

          final creados = snapshot.data![0];
          final unidos = snapshot.data![1];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Círculos que creaste:',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: greenColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                if (creados.isEmpty)
                  Text(
                    'No has creado ningún círculo.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ...creados.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final circleId = doc.id;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 2,
                    child: ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CirculoDetalleScreen(
                              circleId: circleId,
                              esCreador: true,
                            ),
                          ),
                        );
                      },
                      title: Text(
                        data['nombre'] ?? 'Sin nombre',
                        style: theme.textTheme.bodyLarge,
                      ),
                      subtitle: Text(
                        data['tipo'] ?? '',
                        style: theme.textTheme.bodyMedium,
                      ),
                      leading: Icon(Icons.family_restroom, color: greenColor),
                      // ELIMINADOS botones editar y eliminar aquí
                    ),
                  );
                }),
                const Divider(height: 40, thickness: 1.5),
                Text(
                  'Círculos donde eres miembro:',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: greenColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                if (unidos.isEmpty)
                  Text(
                    'No perteneces a ningún círculo.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ...unidos.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final circleId = doc.id;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 2,
                    child: ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CirculoDetalleScreen(
                              circleId: circleId,
                              esCreador: false,
                            ),
                          ),
                        );
                      },
                      title: Text(
                        data['nombre'] ?? 'Sin nombre',
                        style: theme.textTheme.bodyLarge,
                      ),
                      subtitle: Text(
                        data['tipo'] ?? '',
                        style: theme.textTheme.bodyMedium,
                      ),
                      leading: Icon(Icons.group, color: greenColor),
                      // Sin botones aquí
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}
