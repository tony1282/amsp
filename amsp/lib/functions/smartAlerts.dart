// smartAlerts.dart
import 'dart:async';
import 'package:amsp/modals/modalSmart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;

class smartAlerts {
  final modalS = ModalSmart();
  StreamSubscription? alertStream;

  mp.MapboxMap? mapboxMapController;

  DateTime _appStartTime = DateTime.now();

  void escucharAlertasSmart(BuildContext context) {
    alertStream = FirebaseFirestore.instance
        .collection('alertas')
        .where('origen', isEqualTo: 'wear')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data();
        final lat = (data['lat'] as num?)?.toDouble();
        final lon = (data['lon'] as num?)?.toDouble();
        final fecha = data['createdAt']?.toDate();

        if (lat != null && lon != null && fecha != null && fecha.isAfter(_appStartTime)) {
          if (context.mounted) {
            modalS.mostrarAlertaSmartwatch(context, data);
          }
        }
      }
    }, onError: (e) {
      print('Error escuchando alertas: $e');
    });
  }

  void dispose() {
    alertStream?.cancel();
  }
}
