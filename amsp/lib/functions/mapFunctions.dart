import 'dart:async';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:firebase_database/firebase_database.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class MapFunctions {
  StreamSubscription? userPositionStream;

  mp.MapboxMap? mapboxMapController;
  mp.PointAnnotationManager? pointAnnotationManager;
  mp.CircleAnnotationManager? circleAnnotationManager;

  bool seguirUsuario = true;
  mp.Point? ultimaUbicacion;

  final DatabaseReference _ref = FirebaseDatabase.instance.ref();
  final AudioPlayer _player = AudioPlayer();

  /// 🔹 Toggle seguro para seguir al usuario
  Future<void> toggleSeguirUsuario() async {
    seguirUsuario = !seguirUsuario;

    if (seguirUsuario) {
      print("🛰️ Seguimiento activado");

      // 🔹 Centrar el mapa inmediatamente usando la última ubicación conocida
      await centrarEnUbicacionActual();

      // 🔹 Iniciar seguimiento continuo
      iniciarSeguimientoContinuo();
    } else {
      print("🛰️ Seguimiento desactivado");
      userPositionStream?.cancel();
    }
  }

  Future<void> centrarEnUbicacionActual() async {
    try {
      final serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print("⚠️ Servicio de ubicación desactivado");
        return;
      }

      var permission = await gl.Geolocator.checkPermission();
      if (permission == gl.LocationPermission.denied) {
        permission = await gl.Geolocator.requestPermission();
      }

      if (permission == gl.LocationPermission.denied ||
          permission == gl.LocationPermission.deniedForever) {
        print("🚫 Permiso de ubicación denegado");
        return;
      }

      // 🔹 Mostrar ubicación aproximada inmediatamente
      final lastPos = await gl.Geolocator.getLastKnownPosition();
      if (lastPos != null && mapboxMapController != null) {
        await mapboxMapController!.easeTo(
          mp.CameraOptions(
            center: mp.Point(
              coordinates: mp.Position(lastPos.longitude, lastPos.latitude),
            ),
            zoom: 15.5,
          ),
          mp.MapAnimationOptions(duration: 500),
        );
      }

      // 🔹 Obtener la ubicación exacta
      final pos = await gl.Geolocator.getCurrentPosition(
        desiredAccuracy: gl.LocationAccuracy.high,
      );
      ultimaUbicacion = mp.Point(
        coordinates: mp.Position(pos.longitude, pos.latitude),
      );

      if (mapboxMapController != null) {
        await mapboxMapController!.easeTo(
          mp.CameraOptions(center: ultimaUbicacion, zoom: 16),
          mp.MapAnimationOptions(duration: 500),
        );
      }
    } catch (e) {
      print("❌ Error al centrar en ubicación: $e");
    }
  }

  /// 🚀 Escucha la ubicación en tiempo real y actualiza el mapa
  void iniciarSeguimientoContinuo() {
    userPositionStream?.cancel();

    userPositionStream = gl.Geolocator.getPositionStream(
      locationSettings: const gl.LocationSettings(
        accuracy: gl.LocationAccuracy.best,
        distanceFilter: 5, // 🔹 Evita demasiadas animaciones
      ),
    ).listen((pos) async {
      if (!seguirUsuario || mapboxMapController == null) return;

      try {
        final punto = mp.Point(
          coordinates: mp.Position(pos.longitude, pos.latitude),
        );

        ultimaUbicacion = punto;

        await mapboxMapController!.easeTo(
          mp.CameraOptions(center: punto, zoom: 16),
          mp.MapAnimationOptions(duration: 500),
        );
      } catch (e) {
        print("❌ Error en seguimiento continuo: $e");
      }
    });
  }

  /// 📍 Ajusta el zoom para mostrar todos los puntos
Future<void> ajustarZoomParaTodos(Map<String, mp.Point> posiciones) async {
  if (mapboxMapController == null || posiciones.isEmpty) return;

  double minLat = double.infinity, maxLat = -double.infinity;
  double minLng = double.infinity, maxLng = -double.infinity;

  for (final punto in posiciones.values) {
    final lat = punto.coordinates.lat.toDouble();
    final lng = punto.coordinates.lng.toDouble();
    if (lat < minLat) minLat = lat;
    if (lat > maxLat) maxLat = lat;
    if (lng < minLng) minLng = lng;
    if (lng > maxLng) maxLng = lng;
  }

  final centerLat = (minLat + maxLat) / 2;
  final centerLng = (minLng + maxLng) / 2;

  final latDiff = maxLat - minLat;
  final lngDiff = maxLng - minLng;

  // Alejar dependiendo de la dispersión de puntos
  double maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
  double zoom = 16 - (maxDiff * 20); // Ajusta el multiplicador según cuánto quieras alejar

  // Limitar zoom
  if (zoom < 3) zoom = 3;  // mínimo más alejado
  if (zoom > 16) zoom = 16; // máximo cercano

  await mapboxMapController!.easeTo(
    mp.CameraOptions(
      center: mp.Point(coordinates: mp.Position(centerLng, centerLat)),
      zoom: zoom,
    ),
    mp.MapAnimationOptions(duration: 1000),
  );
}

}
