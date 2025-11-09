import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_database/firebase_database.dart';

class Callfunctions {
  final DatabaseReference _ref = FirebaseDatabase.instance.ref();
  final AudioPlayer _player = AudioPlayer();

  Timestamp? _ultimoTimestampVisto; 
  DateTime _ultimaSacudida = DateTime.now().subtract(const Duration(seconds: 10));
  DateTime _sessionStart = DateTime.now();
  DateTime _appStartTime = DateTime.now();
  DateTime? _ultimoTimestampAlertasIoT;

  // Función para eliminar contacto
  void eliminarContacto(BuildContext context, String id) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    await FirebaseFirestore.instance
        .collection('contactos')
        .doc(userId)
        .collection('contactos_emergencia')
        .doc(id)
        .delete();
  }

  // Función para llamar a un número
  Future<void> llamarNumero(BuildContext context, String numero) async {
    final Uri telUri = Uri(scheme: 'tel', path: numero);

    try {
      if (await canLaunchUrl(telUri)) {
        await launchUrl(telUri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se puede llamar a $numero')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al intentar llamar: $e')),
      );
    }
  }
}
