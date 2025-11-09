import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;

class Markers {
  mp.MapboxMap? mapboxMapController;
  mp.PointAnnotationManager? pointAnnotationManager;

  Map<String, mp.PointAnnotation> miembrosAnnotations = {};
  Map<String, mp.PointAnnotation> miembrosTextAnnotations = {};
  Map<String, mp.PointAnnotation> marcadores = {};
  Map<String, StreamSubscription<DocumentSnapshot>> miembrosListeners = {};
  Map<String, DateTime> _ultimoUpdateMarcador = {};

  Future<void> moverMarcadorFluido(
      String uid, mp.Point destino, String name) async {
    final marcador = miembrosAnnotations[uid];
    final texto = miembrosTextAnnotations[uid];

    if (marcador == null || texto == null) {
      await _actualizarMarcadorMiembro(
        uid,
        destino.coordinates.lat.toDouble(),
        destino.coordinates.lng.toDouble(),
        name,
      );
      return;
    }

    final origen = marcador.geometry;

    if (origen.coordinates.lat == destino.coordinates.lat &&
        origen.coordinates.lng == destino.coordinates.lng) {
      return;
    }

    final distancia = Geolocator.distanceBetween(
      origen.coordinates.lat.toDouble(),
      origen.coordinates.lng.toDouble(),
      destino.coordinates.lat.toDouble(),
      destino.coordinates.lng.toDouble(),
    );
    if (distancia < 4) return;

    final frames = 10; 
    const frameDelay = Duration(milliseconds: 33);

    for (int i = 1; i <= frames; i++) {
      final t = i / frames;
      final lat = origen.coordinates.lat +
          (destino.coordinates.lat - origen.coordinates.lat) * t;
      final lng = origen.coordinates.lng +
          (destino.coordinates.lng - origen.coordinates.lng) * t;

      final puntoInterpolado = mp.Point(coordinates: mp.Position(lng, lat));
      marcador.geometry = puntoInterpolado;
      texto.geometry = puntoInterpolado;

      if (pointAnnotationManager != null) {
        await pointAnnotationManager!.update(marcador);
        await pointAnnotationManager!.update(texto);
      }

      await Future.delayed(frameDelay);
    }
  }

  Future<void> _actualizarMarcadorMiembro(
      String uid, double lat, double lng, String name) async {
    if (pointAnnotationManager == null) {
      print('pointAnnotationManager no está inicializado, no se puede actualizar marcador.');
      return;
    }

    final punto = mp.Point(coordinates: mp.Position(lng, lat));

    if (miembrosAnnotations.containsKey(uid)) {
      final marcador = miembrosAnnotations[uid];
      if (marcador != null) {
        marcador.geometry = punto;
        await pointAnnotationManager!.update(marcador);
      }

      final texto = miembrosTextAnnotations[uid];
      if (texto != null) {
        texto.geometry = punto;
        await pointAnnotationManager!.update(texto);
      }
    } else {
      try {
        final ByteData bytes = await rootBundle.load("assets/user.png");
        final Uint8List imageData = bytes.buffer.asUint8List();

        final annotation = await pointAnnotationManager?.create(
          mp.PointAnnotationOptions(
            geometry: punto,
            image: imageData,
            iconSize: 0.24,
            iconOffset: [0, -2],
          ),
        );

        if (annotation != null) {
          miembrosAnnotations[uid] = annotation;
        } else {
          print('No se pudo crear el marcador para $uid');
        }

        final textAnnotation = await pointAnnotationManager?.create(
          mp.PointAnnotationOptions(
            geometry: punto,
            textField: name,
            textSize: 18.0,
            textOffset: [0, 2.1],
            textColor: const Color.fromARGB(255, 0, 0, 0).value,
            textHaloColor: Colors.white.value,
            textHaloWidth: 3.0,
          ),
        );

        if (textAnnotation != null) {
          miembrosTextAnnotations[uid] = textAnnotation;
        } else {
          print('No se pudo crear el texto del marcador para $uid');
        }
      } catch (e) {
        print('Error al crear marcador de $uid: $e');
      }
    }
  }

  Future<void> limpiarEscuchasYMarcadores() async {
    for (final sub in miembrosListeners.values) {
      await sub.cancel();
    }
    miembrosListeners.clear();

    if (pointAnnotationManager != null) {
      for (var entry in marcadores.entries) {
        await pointAnnotationManager!.delete(entry.value);
      }
    }

    marcadores.clear();
    _ultimoUpdateMarcador.clear();
  }
}
