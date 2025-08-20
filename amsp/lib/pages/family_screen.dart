import 'dart:async'; 
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
  StreamSubscription<QuerySnapshot>? _circulosNombreSubscription;

  @override
  void initState() {
    super.initState();
    uid = _auth.currentUser!.uid;
    _iniciarNormalizadorNombresCirculos();
  }

  @override
  void dispose() {
    _circulosNombreSubscription?.cancel();
    super.dispose();
  }

  String _capitalizarCadaPalabra(String texto) {
    return texto.trim().split(RegExp(r'\s+')).map((palabra) {
      if (palabra.isEmpty) return '';
      return palabra[0].toUpperCase() + palabra.substring(1).toLowerCase();
    }).join(' ');
  }

  void _iniciarNormalizadorNombresCirculos() {
    try {
      _circulosNombreSubscription = _firestore.collection('circulos').snapshots().listen(
        (snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added ||
                change.type == DocumentChangeType.modified) {
              final data = change.doc.data();
              if (data == null) continue;
              final nombreRaw = (data['nombre'] as String?) ?? '';
              final nombreCap = _capitalizarCadaPalabra(nombreRaw);
              if (nombreRaw.isNotEmpty && nombreRaw != nombreCap) {
                change.doc.reference.update({'nombre': nombreCap}).catchError((e) {
                  print('Error actualizando nombre capitalizado: $e');
                });
              }
            }
          }
        },
        onError: (e) {
          print('Error en listener normalizador nombres: $e');
        },
      );
    } catch (e) {
      print('Excepción al iniciar normalizador de nombres: $e');
    }
  }



  Stream<List<QueryDocumentSnapshot>> _streamCirculosCreados() {
    return _firestore
        .collection('circulos')
        .where('creador', isEqualTo: uid)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  Stream<List<QueryDocumentSnapshot>> _streamCirculosUnidos() {
    return _firestore
        .collection('circulos')
        .where('creador', isNotEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final miembros = data['miembros'] as List<dynamic>? ?? [];
        return miembros.any((miembro) => miembro['uid'] == uid);
      }).toList();
    });
  }

  Widget buildCirculosContainer(
      String title, List<QueryDocumentSnapshot> circulos, IconData icon, bool esCreador) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 150),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 10),
          if (circulos.isEmpty)
            const Text(
              'No hay círculos.',
              style: TextStyle(color: Colors.white),
            )
          else
            Column(
              children: circulos.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final circleId = doc.id;
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 3,
                    child: ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CirculoDetalleScreen(
                              circleId: circleId,
                              esCreador: esCreador,
                            ),
                          ),
                        );
                      },
                      title: Text(
                        _capitalizarCadaPalabra(data['nombre'] ?? 'Sin nombre'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        data['tipo'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      leading: Icon(icon, color: Colors.green),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final greenColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Círculo'),
        centerTitle: true,
        backgroundColor: greenColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<List<QueryDocumentSnapshot>>(
          stream: _streamCirculosCreados(),
          builder: (context, snapshotCreados) {
            if (snapshotCreados.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.green));
            }
            if (snapshotCreados.hasError) {
              return Center(child: Text('Error: ${snapshotCreados.error}'));
            }
            final creados = snapshotCreados.data ?? [];
            return StreamBuilder<List<QueryDocumentSnapshot>>(
              stream: _streamCirculosUnidos(),
              builder: (context, snapshotUnidos) {
                if (snapshotUnidos.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.green));
                }
                if (snapshotUnidos.hasError) {
                  return Center(child: Text('Error: ${snapshotUnidos.error}'));
                }
                final unidos = snapshotUnidos.data ?? [];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildCirculosContainer(
                      'Círculos que creaste:',
                      creados,
                      Icons.family_restroom,
                      true,
                    ),
                    const SizedBox(height: 30),
                    buildCirculosContainer(
                      'Círculos donde eres miembro:',
                      unidos,
                      Icons.group,
                      false,
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
