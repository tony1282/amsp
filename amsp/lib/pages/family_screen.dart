import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi familia'),
        centerTitle: true,
      ),
      body: FutureBuilder<List<List<QueryDocumentSnapshot>>>(
        future: Future.wait([
          _getCirculosCreados(),
          _getCirculosUnido(),
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
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
                Text(
                  'Círculos que creaste:',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                if (creados.isEmpty)
                  const Text('No has creado ningún círculo.'),
                ...creados.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text(data['nombre'] ?? 'Sin nombre'),
                    subtitle: Text(data['tipo'] ?? ''),
                    leading: const Icon(Icons.family_restroom),
                  );
                }),
                const Divider(),
                Text(
                  'Círculos donde eres miembro:',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                if (unidos.isEmpty)
                  const Text('No perteneces a ningún círculo.'),
                ...unidos.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text(data['nombre'] ?? 'Sin nombre'),
                    subtitle: Text(data['tipo'] ?? ''),
                    leading: const Icon(Icons.group),
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
