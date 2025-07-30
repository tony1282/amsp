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
  print('Nueva ubicación: lat=${position.latitude}, lng=${position.longitude}');

  final locationData = {
    'lat': position.latitude,
    'lng': position.longitude,
    'timestamp': FieldValue.serverTimestamp(),
  };

  // Guardar en 'ubicaciones'
  await FirebaseFirestore.instance.collection('ubicaciones').doc(user.uid).set(
    locationData,
    SetOptions(merge: true),
  );

  // Guardar también en 'users'
  try {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'ubicacion': locationData,
    });
  } catch (e) {
    // Si falla (por ejemplo, documento no existe), lo crea con merge
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
      {'ubicacion': locationData},
      SetOptions(merge: true),
    );
  }
});
  }

  static Future<void> stopLocationUpdates() async {
    await _positionSubscription?.cancel();
  }
}
