// Importación de paquetes necesarios
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
        .map((snapshot) {
          print('Alertas recibidas: ${snapshot.docs.length}');
          return snapshot.docs;
        });
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
      ),
      backgroundColor: Colors.white,
      body: StreamBuilder<List<QueryDocumentSnapshot>>(
        stream: _alertasStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
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
            return emisorId != uidActual;
          }).toList();

          if (alertasFiltradas.isEmpty) {
            return Center(
              child: Text(
                'No hay alertas de otros usuarios.',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              // Al refrescar simplemente espera un segundo, pues el Stream ya escucha en tiempo real
              await Future.delayed(const Duration(seconds: 1));
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
              itemCount: alertasFiltradas.length,
              itemBuilder: (context, index) {
                final data = alertasFiltradas[index].data() as Map<String, dynamic>;
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
                    tiempoFormateado = DateFormat('dd/MM/yyyy').format(timestamp);
                  }
                }

                return Container(
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
                    leading: const Icon(Icons.warning, color: Color.fromARGB(255, 208, 8, 8)),
                    title: Text(
                      mensaje,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '$tiempoFormateado$ubicacionTexto',
                      style: const TextStyle(color: Colors.white70),
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
