import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'circulo_detalle_screen.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  late final String uid;

  static const Color backgroundColor = Color(0xFF248448);

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
  final todosLosCirculos = await _firestore
      .collection('circulos')
      .where('creador', isNotEqualTo: uid) // <-- Excluye los que creó
      .get();

  List<QueryDocumentSnapshot> unidos = [];

  for (var circulo in todosLosCirculos.docs) {
    final data = circulo.data() as Map<String, dynamic>;
    final miembros = data['miembros'] as List<dynamic>? ?? [];

    final estaEnCirculo = miembros.any((miembro) => miembro['uid'] == uid);

    if (estaEnCirculo) {
      unidos.add(circulo);
    }
  }

  return unidos;
}

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final greenColor = theme.primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Círculo'),
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

          final creados = snapshot.data![0];
          final unidos = snapshot.data![1];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Círculos que creaste:',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (creados.isEmpty)
                        const Text('No has creado ningún círculo.', style: TextStyle(color: Colors.white)),
                      ...creados.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final circleId = doc.id;
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0, // SIN sombra
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
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                Container(
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Círculos donde eres miembro:',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (unidos.isEmpty)
                        const Text('No perteneces a ningún círculo.', style: TextStyle(color: Colors.white)),
                      ...unidos.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final circleId = doc.id;
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0, // SIN sombra
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
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
