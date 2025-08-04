// Importaciones necesarias
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'circulo_detalle_screen.dart'; // Pantalla para ver detalles del círculo

// Widget principal de estado para mostrar los círculos
class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  late final String uid; // UID del usuario actual

  @override
  void initState() {
    super.initState();
    uid = _auth.currentUser!.uid; // Se obtiene el UID al iniciar
  }

  // 🔹 Obtener círculos creados por el usuario
  Future<List<QueryDocumentSnapshot>> _getCirculosCreados() async {
    final snapshot = await _firestore
        .collection('circulos')
        .where('creador', isEqualTo: uid)
        .get();
    return snapshot.docs;
  }

  // 🔹 Obtener círculos donde el usuario es miembro
  Future<List<QueryDocumentSnapshot>> _getCirculosUnido() async {
    final todosLosCirculos = await _firestore.collection('circulos').get();

    List<QueryDocumentSnapshot> unidos = [];

    for (var circulo in todosLosCirculos.docs) {
      final data = circulo.data() as Map<String, dynamic>;
      final miembros = data['miembros'] as List<dynamic>? ?? [];

      // Verifica si el UID está en la lista de miembros
      final estaEnCirculo = miembros.any((miembro) {
        return miembro['uid'] == uid;
      });

      if (estaEnCirculo) {
        unidos.add(circulo);
      }
    }

    return unidos;
  }

  // 🔴 Función para eliminar un círculo (y su subcolección de miembros)
  Future<void> _eliminarCirculo(String circleId) async {
    try {
      final miembrosSnapshot = await _firestore
          .collection('circulos')
          .doc(circleId)
          .collection('miembros')
          .get();

      for (var doc in miembrosSnapshot.docs) {
        await doc.reference.delete(); // Elimina cada miembro
      }

      await _firestore.collection('circulos').doc(circleId).delete(); // Elimina el círculo

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Círculo eliminado')),
        );
        setState(() {}); // Refresca la pantalla
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
    }
  }

  // ✏️ Función para editar el nombre y tipo del círculo
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

  // 🖼️ Interfaz principal
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
            return const Center(child: CircularProgressIndicator(color: Colors.green));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final creados = snapshot.data![0]; // círculos creados por el usuario
          final unidos = snapshot.data![1]; // círculos donde es miembro

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🟩 Lista de círculos creados
                Text(
                  'Círculos que creaste:',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: greenColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                if (creados.isEmpty)
                  Text('No has creado ningún círculo.'),
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
                      title: Text(data['nombre'] ?? 'Sin nombre'),
                      subtitle: Text(data['tipo'] ?? ''),
                      leading: Icon(Icons.family_restroom, color: greenColor),
                    ),
                  );
                }),

                const Divider(height: 40, thickness: 1.5),

                // 🟦 Lista de círculos unidos
                Text(
                  'Círculos donde eres miembro:',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: greenColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                if (unidos.isEmpty)
                  Text('No perteneces a ningún círculo.'),
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
                      title: Text(data['nombre'] ?? 'Sin nombre'),
                      subtitle: Text(data['tipo'] ?? ''),
                      leading: Icon(Icons.group, color: greenColor),
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
