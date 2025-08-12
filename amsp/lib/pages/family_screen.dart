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

  // Suscripción para normalizar nombres en BD
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

  Future<void> _guardarCirculo(String nombre, String tipo) async {
    final nombreFormateado = _capitalizarCadaPalabra(nombre);
    await _firestore.collection('circulos').add({
      'nombre': nombreFormateado,
      'tipo': tipo,
      'creador': uid,
      'miembros': [],
    });
  }

  // Stream para círculos creados por el usuario
  Stream<List<QueryDocumentSnapshot>> _streamCirculosCreados() {
    return _firestore
      .collection('circulos')
      .where('creador', isEqualTo: uid)
      .snapshots()
      .map((snapshot) => snapshot.docs);
  }

  // Stream para círculos donde es miembro (pero no creador)
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
      body: StreamBuilder<List<QueryDocumentSnapshot>>(
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
                            const Text('No has creado ningún círculo.',
                                style: TextStyle(color: Colors.white)),
                          ...creados.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final circleId = doc.id;
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
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
                                title: Text(_capitalizarCadaPalabra(
                                    data['nombre'] ?? 'Sin nombre')),
                                subtitle: Text(data['tipo'] ?? ''),
                                leading:
                                    Icon(Icons.family_restroom, color: greenColor),
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
                            const Text('No perteneces a ningún círculo.',
                                style: TextStyle(color: Colors.white)),
                          ...unidos.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final circleId = doc.id;
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
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
                                title: Text(_capitalizarCadaPalabra(
                                    data['nombre'] ?? 'Sin nombre')),
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
          );
        },
      ),
    );
  }
}
