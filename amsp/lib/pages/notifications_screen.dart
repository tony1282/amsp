import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:async/async.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  Stream<QuerySnapshot> _alertasStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Stream.empty();
    }

    // Buscar los círculos a los que pertenece el usuario
    final ref = FirebaseFirestore.instance.collection('circulos');
    return ref.snapshots().asyncExpand((snapshot) {
      final userCircles = snapshot.docs.where((doc) {
        final miembros = doc.data()['miembros'] as List<dynamic>;
        return miembros.any((m) => m['uid'] == uid);
      });

      final streams = userCircles.map((doc) {
        return ref.doc(doc.id).collection('alertas').orderBy('timestamp', descending: true).snapshots();
      });

      return StreamGroup.merge(streams);
    });
  }
@override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final primaryColor = theme.primaryColor;
  final contrastColor = theme.appBarTheme.foregroundColor ?? Colors.white;
  final uidActual = FirebaseAuth.instance.currentUser?.uid ?? '';

  print('UID actual: $uidActual'); // Para depurar

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
   body: StreamBuilder<QuerySnapshot>(
  stream: _alertasStream(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

    final docs = snapshot.data!.docs;

    // Filtrar alertas para ignorar las enviadas por el usuario actual
    final alertasFiltradas = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final emisorId = data['emisorid']?.toString() ?? '';
      final uidActual = FirebaseAuth.instance.currentUser?.uid ?? '';
      return emisorId != uidActual;
    }).toList();

    if (alertasFiltradas.isEmpty) {
      return const Center(child: Text('No hay alertas.'));
    }

    return ListView(
      children: alertasFiltradas.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final mensaje = data['mensaje'] ?? 'Alerta';
        final timestamp = data['timestamp']?.toDate().toString() ?? '';
        final ubicacion = data['ubicacion'];

        String ubicacionTexto = '';
        if (ubicacion != null && ubicacion is Map<String, dynamic>) {
          final lat = ubicacion['lat'];
          final lng = ubicacion['lng'];
          if (lat != null && lng != null) {
            ubicacionTexto = '\nUbicación: ($lat, $lng)';
          }
        }

        return ListTile(
          leading: const Icon(Icons.warning, color: Colors.red),
          title: Text(mensaje),
          subtitle: Text('$timestamp$ubicacionTexto'),
        );
      }).toList(),
    );
  },
),

    bottomNavigationBar: BottomAppBar(
      color: primaryColor,
      child: const SizedBox(height: 50),
    ),
  );
}
}