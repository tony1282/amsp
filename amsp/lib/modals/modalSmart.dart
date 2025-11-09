import 'dart:async';
import 'dart:typed_data';
import 'package:amsp/functions/callFunctions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:firebase_database/firebase_database.dart';
import 'package:audioplayers/audioplayers.dart';

class ModalSmart {
  mp.MapboxMap? mapboxMapController;
  mp.PointAnnotationManager? pointAnnotationManager;
  Map<String, mp.PointAnnotation> alertasAnnotations = {};

  bool _seguirUsuario = true;
  bool _dialogoAbierto = false;

  final DatabaseReference _ref = FirebaseDatabase.instance.ref();
  final AudioPlayer _player = AudioPlayer();
  final calls = Callfunctions();

  void escucharAlertasSmart(BuildContext context) {
    _ref.child('smartAlerts').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return;

      final double? lat = (data['lat'] as num?)?.toDouble();
      final double? lon = (data['lon'] as num?)?.toDouble();
      final String userName = data['nombre']?.toString() ?? 'Usuario';
      final String phone = data['numero']?.toString() ?? '';

      if (lat != null && lon != null && context.mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          mostrarAlertaSmartwatch(context, Map<String, dynamic>.from(data));
        });
      }
    });
  }

  Future<void> mostrarAlertaSmartwatch(BuildContext context, Map<String, dynamic> alerta) async {
    if (mapboxMapController == null) return;

    final double? lat = (alerta['lat'] as num?)?.toDouble();
    final double? lon = (alerta['lon'] as num?)?.toDouble();
    final mensaje = alerta['mensaje']?.toString() ?? "Alerta sin mensaje";
    final phone = alerta['numero']?.toString() ?? '';
    final userName = alerta['nombre']?.toString() ?? 'Usuario';

    if (lat == null || lon == null) return;

    _seguirUsuario = false;

    await mapboxMapController!.flyTo(
      mp.CameraOptions(
        center: mp.Point(coordinates: mp.Position(lon, lat)),
        zoom: 15.0,
      ),
      mp.MapAnimationOptions(duration: 1000),
    );

    if (pointAnnotationManager != null) {
      final idAlerta = "$lat-$lon";
      if (!alertasAnnotations.containsKey(idAlerta)) {
        final ByteData bytes = await rootBundle.load("assets/alert.png");
        final Uint8List imageData = bytes.buffer.asUint8List();

        final annotation = await pointAnnotationManager!.create(
          mp.PointAnnotationOptions(
            geometry: mp.Point(coordinates: mp.Position(lon, lat)),
            image: imageData,
            iconSize: 0.35,
            iconOffset: [0, -80],
            textField: "$userName: $mensaje",
            textSize: 14.0,
            textOffset: [0, 2.0],
            textColor: Colors.black.value,
            textHaloColor: Colors.white.value,
            textHaloWidth: 2,
          ),
        );
        if (annotation != null) alertasAnnotations[idAlerta] = annotation;
      }
    }

    _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(AssetSource('sounds/alert.mp3'));

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.watch, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      "Alerta Smartwatch",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 26),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  mensaje,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  "De: $userName",
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  "Ubicación: ${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}",
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Protocolo:",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  "1. Llama inmediatamente al usuario o servicios de emergencia.\n"
                  "2. Dirígete a la ubicación si es seguro.\n"
                  "3. No ignores la alerta.",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (phone.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          _player.stop();
                          Navigator.of(context, rootNavigator: true).pop();
                          calls.llamarNumero(context, phone);
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text(
                          "Llamar",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _player.stop();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text(
                        "Cerrar",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  
}
