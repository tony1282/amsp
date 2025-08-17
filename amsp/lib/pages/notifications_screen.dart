import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  Stream<List<QueryDocumentSnapshot>> _alertasStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('alertasCirculos')
        .where('destinatarios', arrayContains: uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  Future<void> _darDeBajaAlerta(String alertaId, String uid) async {
    await FirebaseFirestore.instance
        .collection('alertasCirculos')
        .doc(alertaId)
        .update({
      'vistas': FieldValue.arrayUnion([uid]),
    });
  }

  Future<void> _darDeBajaTodas(String uid) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('alertasCirculos')
        .where('destinatarios', arrayContains: uid)
        .get();

    for (final doc in snapshot.docs) {
      await doc.reference.update({
        'vistas': FieldValue.arrayUnion([uid]),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final contrastColor = theme.appBarTheme.foregroundColor ?? Colors.white;
    final uidActual = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        centerTitle: true,
        title: Text(
          'Alertas',
          style: theme.appBarTheme.titleTextStyle ??
              TextStyle(
                color: contrastColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.white),
            onPressed: () async {
              await _darDeBajaTodas(uidActual);
            },
          )
        ],
      ),
      backgroundColor: Colors.white,
      body: StreamBuilder<List<QueryDocumentSnapshot>>(
        stream: _alertasStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Error al cargar alertas. Intenta más tarde.'),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                'No hay alertas recientes.',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
            );
          }

          final docs = snapshot.data!;
          final alertasFiltradas = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final emisorId = data['emisorId']?.toString() ?? '';
            final vistas = List<String>.from(data['vistas'] ?? []);
            return emisorId != uidActual && !vistas.contains(uidActual);
          }).toList();

          if (alertasFiltradas.isEmpty) {
            return Center(
              child: Text(
                'No hay alertas nuevas.',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await Future.delayed(const Duration(seconds: 1));
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
              itemCount: alertasFiltradas.length,
              itemBuilder: (context, index) {
                final alerta = alertasFiltradas[index];
                final data = alerta.data() as Map<String, dynamic>;
                final mensaje = data['mensaje'] ?? 'Alerta';
                final timestamp = data['timestamp']?.toDate();
                final ubicacion = data['ubicacion'];

                String ubicacionTexto = '';
                if (ubicacion != null && ubicacion is Map<String, dynamic>) {
                  final lat = ubicacion['lat'];
                  final lng = ubicacion['lng'];
                  if (lat != null && lng != null) {
                    ubicacionTexto = '\nUbicación: ($lat, $lng)';
                  }
                }

                String tiempoFormateado = '';
                if (timestamp != null) {
                  final ahora = DateTime.now();
                  final diferencia = ahora.difference(timestamp);

                  if (diferencia.inSeconds < 60) {
                    tiempoFormateado = 'Hace unos segundos';
                  } else if (diferencia.inMinutes < 60) {
                    tiempoFormateado = 'Hace ${diferencia.inMinutes} min';
                  } else if (diferencia.inHours < 24) {
                    tiempoFormateado = 'Hace ${diferencia.inHours} h';
                  } else {
                    tiempoFormateado =
                        DateFormat('dd/MM/yyyy').format(timestamp);
                  }
                }

                return Dismissible(
                  key: Key(alerta.id),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) async {
                    await _darDeBajaAlerta(alerta.id, uidActual);
                  },
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.warning,
                          color: Color.fromARGB(255, 208, 8, 8)),
                      title: Text(
                        mensaje,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '$tiempoFormateado$ubicacionTexto',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
