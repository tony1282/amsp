import 'dart:async';
import 'dart:io' show Platform;

import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LocationService {
  static StreamSubscription<Position>? _positionSubscription;

  static Future<void> startLocationUpdates() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    LocationPermission permisos = await Geolocator.checkPermission();
    if (permisos == LocationPermission.denied || permisos == LocationPermission.deniedForever) {
      permisos = await Geolocator.requestPermission();
      if (permisos == LocationPermission.denied || permisos == LocationPermission.deniedForever) {
        return;
      }
    }

    bool servicioActivo = await Geolocator.isLocationServiceEnabled();
    if (!servicioActivo) {
      return;
    }

    await _positionSubscription?.cancel();

    LocationSettings locationSettings;

    if (Platform.isAndroid) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        intervalDuration: const Duration(seconds: 20), // Aquí sí funciona
        distanceFilter: 0,
        // other Android-specific options...
      );
    } else if (Platform.isIOS || Platform.isMacOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        // iOS no tiene intervalo configurable en LocationSettings
      );
    } else {
      // Otros (Windows, Linux, web, etc)
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      );
    }

_positionSubscription = Geolocator.getPositionStream(
  locationSettings: locationSettings,
).listen((Position position) async {
  final lat = position.latitude;
  final lng = position.longitude;

  print('📍 Nueva ubicación recibida: lat=$lat, lng=$lng');

  final locationData = {
    'lat': lat,
    'lng': lng,
    'timestamp': FieldValue.serverTimestamp(),
  };

  await FirebaseFirestore.instance.collection('ubicaciones').doc(user.uid).set(
    locationData,
    SetOptions(merge: true),
  );

  print('✅ Ubicación guardada en Firestore para UID: ${user.uid}');
});
  }

  static Future<void> stopLocationUpdates() async {
    await _positionSubscription?.cancel();
  }
} 