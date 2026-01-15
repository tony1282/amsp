import 'dart:async';
import 'package:amsp/functions/mapFunctions.dart';
import 'package:amsp/functions/markers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;

class CircleUbications {
  mp.MapboxMap? mapboxMapController;

  mp.PointAnnotationManager? pointAnnotationManager;
  mp.CircleAnnotationManager? circleAnnotationManager;

  mp.PointAnnotation? usuarioAnnotation;
  mp.PointAnnotation? usuarioTextoAnnotation;
  mp.CircleAnnotation? usuarioCircleAnnotation;

  mp.Point? ultimaPosicion;

  final mark = Markers();
  final map = MapFunctions();

  final Map<String, StreamSubscription<DocumentSnapshot>> miembrosListeners = {};
  final Map<String, mp.PointAnnotation> marcadores = {};
  final Map<String, mp.Point> todasPosiciones = {};

  bool _zoomAjustadoParaCirculo = false;
  bool _escuchando = false;

  /// 🔹 Limpia todas las suscripciones activas y marcadores previos
  Future<void> limpiarEscuchasYMarcadores() async {
    for (final sub in miembrosListeners.values) {
      await sub.cancel();
    }
    miembrosListeners.clear();
    marcadores.clear();
    todasPosiciones.clear();
    _zoomAjustadoParaCirculo = false;
    await mark.limpiarEscuchasYMarcadores();
    print("🧹 Limpieza completa de escuchas y marcadores.");
  }

  /// 🔹 Escucha las ubicaciones de todos los miembros del círculo en tiempo real
  Future<void> escucharUbicacionesDelCirculo(String circleId) async {
    if (_escuchando) {
      await limpiarEscuchasYMarcadores();
    }
    _escuchando = true;

    print("📡 Escuchando ubicaciones para círculo: $circleId");

    final circleDoc = await FirebaseFirestore.instance
        .collection('circulos')
        .doc(circleId)
        .get();

    if (!circleDoc.exists) {
      print(" El círculo no existe o fue eliminado.");
      return;
    }

    final miembros = circleDoc.data()?['miembros'] as List<dynamic>? ?? [];
    final user = FirebaseAuth.instance.currentUser;

    for (final member in miembros) {
      String uid;
      String name = 'Sin nombre';

      if (member is String) {
        uid = member;
      } else if (member is Map<String, dynamic>) {
        uid = member['uid'] ?? '';
        name = member['name'] ?? 'Sin nombre';
      } else {
        continue;
      }

      if (uid.isEmpty || (user != null && uid == user.uid)) continue;

      // 🔹 Suscripción a los cambios de ubicación
      final sub = FirebaseFirestore.instance
          .collection('ubicaciones')
          .doc(uid)
          .snapshots()
          .listen((snapshot) async {
        if (!snapshot.exists) return;

        final data = snapshot.data();
        final lat = (data?['lat'] ?? data?['latitude'])?.toDouble();
        final lng = (data?['lng'] ?? data?['longitude'])?.toDouble();
        if (lat == null || lng == null) return;

        final puntoNuevo = mp.Point(coordinates: mp.Position(lng, lat));

        // Mover o crear marcador
        mark.moverMarcadorFluido(uid, puntoNuevo, name);

        // Guardar posición
        todasPosiciones[uid] = puntoNuevo;

        // 🔹 Solo ajustar zoom una vez al principio
        if (!_zoomAjustadoParaCirculo &&
            mapboxMapController != null &&
            todasPosiciones.isNotEmpty) {
          _zoomAjustadoParaCirculo = true;
          await Future.delayed(const Duration(milliseconds: 200));
          await map.ajustarZoomParaTodos(todasPosiciones);
        }
      });

      miembrosListeners[uid] = sub;
    }
  }

  /// 🔹 Reajusta el zoom al mostrar nuevamente el círculo
  Future<void> reajustarZoomSiNecesario() async {
    if (mapboxMapController == null || todasPosiciones.isEmpty) return;
    await map.ajustarZoomParaTodos(todasPosiciones);
  }

  /// 🔹 Detiene escuchas activas (al cerrar o cambiar de círculo)
  Future<void> detenerEscuchas() async {
    for (final sub in miembrosListeners.values) {
      await sub.cancel();
    }
    miembrosListeners.clear();
    _escuchando = false;
    print("Escuchas detenidas correctamente.");
  }
}
