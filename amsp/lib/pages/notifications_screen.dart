// Importación de paquetes necesarios
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:async/async.dart';

// Pantalla para mostrar alertas emitidas por miembros de los círculos del usuario
class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  // Función que devuelve un stream con todas las alertas de los círculos donde está el usuario
  Stream<QuerySnapshot> _alertasStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid; // UID del usuario actual

    if (uid == null) {
      return const Stream.empty(); // Si no hay usuario autenticado, no emitimos nada
    }

    // Referencia a la colección de círculos
    final ref = FirebaseFirestore.instance.collection('circulos');

    // Escuchamos todos los documentos en la colección 'circulos'
    return ref.snapshots().asyncExpand((snapshot) {
      // Filtramos los círculos donde el usuario actual es miembro
      final userCircles = snapshot.docs.where((doc) {
        final miembros = doc.data()['miembros'] as List<dynamic>;
        return miembros.any((m) => m['uid'] == uid);
      });

      // Por cada círculo, obtenemos el stream de su subcolección 'alertas'
      final streams = userCircles.map((doc) {
        return ref.doc(doc.id)
                  .collection('alertas')
                  .orderBy('timestamp', descending: true)
                  .snapshots();
      });

      // Unimos todos los streams en uno solo
      return StreamGroup.merge(streams);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final contrastColor = theme.appBarTheme.foregroundColor ?? Colors.white;
    final uidActual = FirebaseAuth.instance.currentUser?.uid ?? '';

    print('UID actual: $uidActual'); // Debug: Imprime el UID actual en consola

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

      // Cuerpo principal con StreamBuilder para mostrar alertas en tiempo real
      body: StreamBuilder<QuerySnapshot>(
        stream: _alertasStream(), // Escuchamos las alertas
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          // Filtra alertas que no hayan sido enviadas por el propio usuario
          final alertasFiltradas = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final emisorId = data['emisorid']?.toString() ?? '';
            final uidActual = FirebaseAuth.instance.currentUser?.uid ?? '';
            return emisorId != uidActual;
          }).toList();

          // Si no hay alertas válidas, se muestra mensaje
          if (alertasFiltradas.isEmpty) {
            return const Center(child: Text('No hay alertas.'));
          }

          // Muestra las alertas en una lista
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
            children: alertasFiltradas.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final mensaje = data['mensaje'] ?? 'Alerta';
              final timestamp = data['timestamp']?.toDate().toString() ?? '';
              final ubicacion = data['ubicacion'];

              // Construimos texto para la ubicación si está disponible
              String ubicacionTexto = '';
              if (ubicacion != null && ubicacion is Map<String, dynamic>) {
                final lat = ubicacion['lat'];
                final lng = ubicacion['lng'];
                if (lat != null && lng != null) {
                  ubicacionTexto = '\nUbicación: ($lat, $lng)';
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
                    '$timestamp$ubicacionTexto',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
