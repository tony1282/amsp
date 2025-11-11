import 'dart:async';
import 'package:amsp/functions/mapFunctions.dart';
import 'package:amsp/functions/markers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;

class CircleUbications {
  mp.MapboxMap? mapboxMapController;

  mp.PointAnnotation? usuarioAnnotation;
  mp.PointAnnotation? usuarioTextoAnnotation;
  mp.PointAnnotationManager? pointAnnotationManager;
  mp.CircleAnnotationManager? circleAnnotationManager;
  mp.CircleAnnotation? usuarioCircleAnnotation;

  mp.Point? ultimaPosicion;

  Map<String, StreamSubscription<DocumentSnapshot>> miembrosListeners = {};
  Map<String, mp.PointAnnotation> marcadores = {};
  Map<String, mp.PointAnnotation> miembrosAnnotations = {};
  Map<String, mp.PointAnnotation> miembrosTextAnnotations = {};
  Map<String, mp.Point> todasPosiciones = {};

  bool _zoomAjustadoParaCirculo = false;
  bool _alertaActiva = false;

  final mark = Markers();
  final map = MapFunctions();

  

  Future<void> escucharUbicacionesDelCirculo(String circleId) async {
  await mark.limpiarEscuchasYMarcadores();
  print("Escuchando ubicaciones para círculo: $circleId");

  final circleDoc = await FirebaseFirestore.instance
      .collection('circulos')
      .doc(circleId)
      .get();

  if (!circleDoc.exists) return;

  final miembros = circleDoc.data()?['miembros'] as List<dynamic>? ?? [];
  final user = FirebaseAuth.instance.currentUser;

  for (final member in miembros) {
    String uid;
    String name = 'Sin nombre';

    if (member is String) {
      uid = member;
    } else if (member is Map<String, dynamic>) {
      uid = member['uid'];
      name = member['name'] ?? 'Sin nombre';
    } else {
      continue;
    }

    if (user != null && uid == user.uid) continue;

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

      mark.moverMarcadorFluido(uid, puntoNuevo, name);

      // 🔹 Guardamos la posición siempre
      todasPosiciones[uid] = puntoNuevo;
      ajustarZoomInicial();

      // 🔹 Ajustamos el zoom solo una vez
      if (!_zoomAjustadoParaCirculo && mapboxMapController != null) {
        _zoomAjustadoParaCirculo = true;

        // 🔹 Desactivar seguimiento temporalmente si estaba activo
        final seguirAnterior = map.seguirUsuario;
        map.seguirUsuario = false;

        await Future.delayed(const Duration(milliseconds: 300)); // esperar que se agreguen anotaciones
        await map.ajustarZoomParaTodos(todasPosiciones);

        map.seguirUsuario = seguirAnterior;
      }
    });

    miembrosListeners[uid] = sub;
  }
}

void ajustarZoomInicial() async {
  if (_zoomAjustadoParaCirculo) return; // solo una vez
  if (todasPosiciones.isEmpty || mapboxMapController == null) return;

  _zoomAjustadoParaCirculo = true;

  // Esperar un momento para asegurarnos que se agregaron las anotaciones
  await Future.delayed(const Duration(milliseconds: 300));

  await map.ajustarZoomParaTodos(todasPosiciones);
}






  
}
