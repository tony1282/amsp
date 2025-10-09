import 'dart:async';
import 'dart:io' show Platform;

import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LocationService {
  static StreamSubscription<Position>? _positionSubscription;
  static Position? _lastPosition;

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
        accuracy: LocationAccuracy.medium, // menos consumo que high
        intervalDuration: const Duration(seconds: 15), // cada 15s
        distanceFilter: 20, // solo si se movió más de 20m
      );
    } else if (Platform.isIOS || Platform.isMacOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 20,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 20,
      );
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) async {
      final lat = position.latitude;
      final lng = position.longitude;

      // Solo guardar si la ubicación cambió más de 20 metros
      if (_lastPosition == null || Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      ) > 20) {
        
        _lastPosition = position;

        print('Nueva ubicación recibida: lat=$lat, lng=$lng');
        final locationData = {
          'lat': lat,
          'lng': lng,
          'timestamp': FieldValue.serverTimestamp(),
        };

        await FirebaseFirestore.instance.collection('ubicaciones').doc(user.uid).set(
          locationData,
          SetOptions(merge: true), 
        );

        print('Ubicación guardada en Firestore para UID: ${user.uid}');
      }
    });
  }

  static Future<void> stopLocationUpdates() async {
    await _positionSubscription?.cancel();
  }
}

