import 'package:amsp/functions/markers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:amsp/functions/circleUbications.dart';
import 'package:amsp/pages/crear_circulo_screen.dart';
import 'package:amsp/pages/zona_riesgo_screen.dart';
import 'package:amsp/services/inegi_service.dart';
import 'package:amsp/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:url_launcher/url_launcher.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:amsp/services/circulos_service.dart';





class CirculosService {
  

  StreamSubscription? userPositionStream;
  
  
  mp.MapboxMap? mapboxMapController;
  mp.PointAnnotation? usuarioAnnotation;
  mp.PointAnnotation? usuarioTextoAnnotation;
  mp.PointAnnotationManager? pointAnnotationManager;
  mp.CircleAnnotationManager? circleAnnotationManager;
  mp.CircleAnnotation? usuarioCircleAnnotation;
  mp.Point? ultimaPosicion;
  


  Map<String, DateTime> _ultimoUpdateMarcador = {};
  Map<String, StreamSubscription<DocumentSnapshot>> miembrosListeners = {};
  Map<String, mp.PointAnnotation> marcadores = {}; 
  Map<String, mp.PointAnnotation> miembrosAnnotations = {};
  Map<String, mp.PointAnnotation> miembrosTextAnnotations = {};
  Map<String, mp.Point> todasPosiciones = {};
  Map<String, mp.PointAnnotation> alertasAnnotations = {};
  Map<String, Timestamp> _ultimoTimestampPorCirculo = {};
  Map<String, StreamSubscription> _alertSubs = {};
  


  bool esCreadorFamilia = false;
  bool cargandoUsuario = true;
  bool _mostrarNotificacion = true;
  bool _mostrarModalAlerta = false;
  bool _dialogoAbierto = false;
  bool _primerZoomUsuario = true;
  bool _zoomAjustadoParaCirculo = false;
  bool _yaCargoInicial = false;
  bool _seguirUsuarioTemporal = true;
  bool _seguirUsuario = true;
  bool _alertaActiva = false;




  StreamSubscription? _alertasSubscription;
  StreamSubscription? _accelerometerSubscription;

  final DatabaseReference _ref = FirebaseDatabase.instance.ref();
  final AudioPlayer _player = AudioPlayer();
  final Set<String> _processedAlertIds = {};


  Set<String> _alertasProcesadas = {};
  String? circuloSeleccionadoId;
  String? circuloSeleccionadoNombre;
  String? _ultimoMensajeIot;
  String? _ultimoMensajeMostrado;
  String? _mensajeAlerta;
  List<String> codigosRiesgo = [];
  final Set<String> _alertasMostradasIds = {};
  final Set<String> _alertasMostradas = {};
  

  Timestamp? _ultimoTimestampVisto; 
  DateTime _ultimaSacudida = DateTime.now().subtract(const Duration(seconds: 10));
  DateTime _sessionStart = DateTime.now();


final Map<String, bool> _initialCircleFetched = {};


DateTime? _ultimoTimestampAlertasIoT;
final circleU = CircleUbications();
final mark = Markers();



  static Future<List<QueryDocumentSnapshot>> getCirculosUsuario() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];

    final circulosCreadosSnap = await FirebaseFirestore.instance
        .collection('circulos')
        .where('creador', isEqualTo: currentUser.uid)
        .get();

    final circulosColeccion = await FirebaseFirestore.instance.collection('circulos').get();

    List<QueryDocumentSnapshot> circulosUsuario = [...circulosCreadosSnap.docs];

    for (var doc in circulosColeccion.docs) {
      final data = doc.data();
      final rawMiembros = data['miembros'] ?? [];

      final miembros = (rawMiembros as List)
          .where((e) => e is Map<String, dynamic>)
          .cast<Map<String, dynamic>>();

      if (miembros.any((m) => m['uid'] == currentUser.uid)) {
        if (!circulosUsuario.any((d) => d.id == doc.id)) {
          circulosUsuario.add(doc);
        }
      }
    }
    return circulosUsuario;
  } 

  Future<void> abrirCirculoPorAlerta(String circleId, String emisorId) async {
  //await _limpiarEscuchasYMarcadores(); 
  circuloSeleccionadoId = circleId;
  _zoomAjustadoParaCirculo = false;

  final circleDoc = await FirebaseFirestore.instance
      .collection('circulos')
      .doc(circleId)
      .get();

  if (!circleDoc.exists) return;

  final miembros = circleDoc.data()?['miembros'] as List<dynamic>? ?? [];
  double? latEmisor;
  double? lngEmisor;

final currentUser = FirebaseAuth.instance.currentUser;

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

  if (uid == currentUser?.uid) continue;

  final snapshot = await FirebaseFirestore.instance
      .collection('ubicaciones')
      .doc(uid)
      .get();

  final data = snapshot.data();
  final lat = (data?['lat'] ?? data?['latitude'])?.toDouble();
  final lng = (data?['lng'] ?? data?['longitude'])?.toDouble();
  if (lat == null || lng == null) continue;

  final punto = mp.Point(coordinates: mp.Position(lng, lat));
  mark.moverMarcadorFluido(uid, punto, name);

  if (uid == emisorId) {
    latEmisor = lat;
    lngEmisor = lng;
  }
}
_alertaActiva = true;



if (latEmisor != null && lngEmisor != null && mapboxMapController != null) {
  await mapboxMapController!.flyTo(
    mp.CameraOptions(
      center: mp.Point(coordinates: mp.Position(lngEmisor, latEmisor)),
      zoom: 14, 
    ),
    mp.MapAnimationOptions(duration: 1000),
  );
}

  circleU.escucharUbicacionesDelCirculo(circleId);
}




}
