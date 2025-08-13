import 'dart:async';
import 'dart:io' show Platform;

import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LocationService {
  // Suscripción al stream de posición para poder cancelarla cuando se necesite
  static StreamSubscription<Position>? _positionSubscription;

  // Método para iniciar la actualización continua de ubicación
  static Future<void> startLocationUpdates() async {
    // Obtiene el usuario autenticado actual de Firebase
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // Si no hay usuario, no hace nada

    // Verifica los permisos de ubicación
    LocationPermission permisos = await Geolocator.checkPermission();
    if (permisos == LocationPermission.denied || permisos == LocationPermission.deniedForever) {
      // Solicita permisos si no están concedidos
      permisos = await Geolocator.requestPermission();
      if (permisos == LocationPermission.denied || permisos == LocationPermission.deniedForever) {
        // Si sigue sin permisos, termina la función
        return;
      }
    }

    // Verifica que el servicio de ubicación esté activo en el dispositivo
    bool servicioActivo = await Geolocator.isLocationServiceEnabled();
    if (!servicioActivo) {
      // Si el servicio está desactivado, termina la función
      return;
    }

    // Cancela cualquier suscripción previa para evitar múltiples streams activos
    await _positionSubscription?.cancel();

    LocationSettings locationSettings;

    // Define la configuración de ubicación según la plataforma
    if (Platform.isAndroid) {
      // Configuración específica para Android
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high, // Precisión alta
        intervalDuration: const Duration(seconds: 1), // Intervalo para recibir actualizaciones (cada 20 segundos)
        distanceFilter: 0, // Actualizar en cualquier cambio de ubicación, sin filtro de distancia mínima
        // otros parámetros específicos para Android podrían ir aquí
      );
    } else if (Platform.isIOS || Platform.isMacOS) {
      // Configuración específica para iOS y MacOS
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high, // Precisión alta
        distanceFilter: 0, // Actualizar con cualquier cambio de ubicación
        // iOS no permite configurar intervalo en LocationSettings
      );
    } else {
      // Configuración para otras plataformas (Windows, Linux, web, etc.)
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      );
    }

    // Escucha el stream de posiciones usando la configuración definida
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) async {
      // Obtiene latitud y longitud de la nueva posición
      final lat = position.latitude;
      final lng = position.longitude;

      print('📍 Nueva ubicación recibida: lat=$lat, lng=$lng');

      // Crea un mapa con los datos a guardar
      final locationData = {
        'lat': lat,
        'lng': lng,
        'timestamp': FieldValue.serverTimestamp(), // Marca de tiempo generada por el servidor
      };

      // Guarda o actualiza la ubicación en Firestore bajo el documento del usuario
      await FirebaseFirestore.instance.collection('ubicaciones').doc(user.uid).set(
        locationData,
        SetOptions(merge: true), // Combina con datos existentes sin sobrescribir todo
      );

      print('✅ Ubicación guardada en Firestore para UID: ${user.uid}');
    });
  }

  // Método para detener la actualización continua de ubicación
  static Future<void> stopLocationUpdates() async {
    await _positionSubscription?.cancel(); // Cancela la suscripción al stream
  }
}
