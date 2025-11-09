import 'package:amsp/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:firebase_database/firebase_database.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class UserData {
  bool esCreadorFamilia = false;
  bool cargandoUsuario = true;

  /// Función para cargar datos del usuario
  Future<void> cargarDatosUsuario({VoidCallback? onUpdate}) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      esCreadorFamilia = false;
      cargandoUsuario = false;
      onUpdate?.call(); 
      return;
    }

    try {
      // Cargar documento de usuario
      final docUser = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      // Marcar que ya se cargó la info básica del usuario
      cargandoUsuario = false;
      onUpdate?.call(); 

      // Intentar obtener ubicación sin bloquear la UI
      gl.Geolocator.checkPermission().then((permission) async {
        if (permission == gl.LocationPermission.denied || permission == gl.LocationPermission.deniedForever) {
          permission = await gl.Geolocator.requestPermission();
        }

        if (permission != gl.LocationPermission.denied &&
            permission != gl.LocationPermission.deniedForever) {
          try {
            final position = await gl.Geolocator.getCurrentPosition(
              desiredAccuracy: gl.LocationAccuracy.high,
            );

            await FirebaseFirestore.instance
                .collection('ubicaciones')
                .doc(currentUser.uid)
                .update({
              'lat': position.latitude,
              'lng': position.longitude,
              'timestamp': FieldValue.serverTimestamp(),
            });

          } catch (e) {
            print('Error al obtener/guardar ubicación: $e');
          }
        } else {
          print('Permiso de ubicación denegado.');
        }
      });

    } catch (e) {
      print('Error cargando usuario: $e');
      esCreadorFamilia = false;
      cargandoUsuario = false;
      onUpdate?.call(); // Actualiza UI incluso en error
    }
  }
}
