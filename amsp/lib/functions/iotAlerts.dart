import 'dart:async';
import 'package:amsp/modals/modalIot.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:firebase_database/firebase_database.dart';
import 'package:audioplayers/audioplayers.dart';

class iotAlerts {
  final modalI = ModalIot();
  final DatabaseReference _ref = FirebaseDatabase.instance.ref();
  final AudioPlayer _player = AudioPlayer();

  DateTime _appStartTime = DateTime.now();
  DateTime? _ultimoTimestampAlertasIoT; // Último timestamp procesado
  bool _alertaActiva = false;

  // Mapbox y demás
  mp.MapboxMap? mapboxMapController;
  mp.PointAnnotation? usuarioAnnotation;
  mp.PointAnnotation? usuarioTextoAnnotation;
  mp.PointAnnotationManager? pointAnnotationManager;
  mp.CircleAnnotationManager? circleAnnotationManager;
  mp.PointAnnotation? usuarioCircleAnnotation;
  mp.Point? ultimaPosicion;

  Map<String, DateTime> _ultimoUpdateMarcador = {};
  Map<String, StreamSubscription> _alertSubs = {};
  Map<String, mp.PointAnnotation> alertasAnnotations = {};

  String? circuloSeleccionadoId;
  String? circuloSeleccionadoNombre;
  String? _mensajeAlerta;
  StreamSubscription? userPositionStream;

  void init(BuildContext context) {
    _appStartTime = DateTime.now(); // Marca el inicio de la app
    escucharAlertasIoT(context);    // Solo nuevas alertas a partir de este momento
  }

  Future<void> irALaUltimaAlerta(BuildContext context) async {
    try {
      final snapshot = await _ref.child('mensaje').get();
      final data = snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        final double? lat = (data['latitud'] as num?)?.toDouble();
        final double? lng = (data['longitud'] as num?)?.toDouble();
        final String userName = data['nombre']?.toString() ?? 'Usuario';
        final String phone = data['numero']?.toString() ?? '';

        if (lat != null && lng != null && context.mounted) {
          await modalI.mostrarAlertaEnMapaIoT(
            context,
            "Alerta IoT\n¡Estoy en peligro!",
            lat,
            lng,
            userName,
            phone,
          );

          // ✅ Borramos el mensaje después de mostrarlo
          await _ref.child('mensaje').remove();
          print("Mensaje IoT eliminado tras mostrarse.");
        } else {
          print("No hay coordenadas disponibles en la última alerta");
        }
      }
    } catch (e) {
      print("Error al obtener última alerta: $e");
    }
  }

  /// Escucha cambios en el nodo 'mensaje' y solo muestra alertas nuevas
  void escucharAlertasIoT(BuildContext context) {
    _ref.child('mensaje').onValue.listen((event) async {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return;

      try {
        final timestampStr = data['timestamp']?.toString() ?? "";
        final fecha = timestampStr.isNotEmpty ? DateTime.tryParse(timestampStr) : null;

        if (fecha != null &&
            (_ultimoTimestampAlertasIoT == null || fecha.isAfter(_ultimoTimestampAlertasIoT!))) {
          _ultimoTimestampAlertasIoT = fecha; // Guardamos el último procesado

          final lat = (data['latitud'] as num?)?.toDouble();
          final lng = (data['longitud'] as num?)?.toDouble();
          final nombre = data['nombre']?.toString() ?? 'Usuario';
          final numero = data['numero']?.toString() ?? '';

          if (lat != null && lng != null && context.mounted) {
            await modalI.mostrarAlertaEnMapaIoT(
              context,
              "Alerta IoT\n¡Estoy en peligro!",
              lat,
              lng,
              nombre,
              numero,
            );

            // ✅ Borramos el mensaje tras mostrarlo
            await _ref.child('mensaje').remove();
            print("Mensaje IoT eliminado tras mostrarse.");
          }
        } else {
          print("Ignorada alerta antigua o repetida: $timestampStr");
        }
      } catch (e) {
        print("Error procesando alerta IoT: $e");
      }
    });
  }
}
