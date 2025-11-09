import 'dart:async';
import 'dart:collection';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:firebase_database/firebase_database.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:amsp/services/circulos_service.dart';

class MapAlerts {
  // Anotaciones y mapas
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
  DateTime appStartTime = DateTime.now();

  // Estados de la app
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

  // Firebase y audio
  final DatabaseReference _ref = FirebaseDatabase.instance.ref();
  final AudioPlayer _player = AudioPlayer();
  final Set<String> _processedAlertIds = {};

  // Datos de alertas
  final Queue<Map<String, dynamic>> _alertaQueue = Queue();
  final Map<String, bool> _initialCircleFetched = {};
  Timestamp? _ultimoTimestampVisto;

  final circulosService = CirculosService();

  bool _enviandoAlerta = false;
  DateTime _appStartTime = DateTime.now();

  // ⚡ Getter/Setter para controlar diálogo
  bool get dialogoAbierto => _dialogoAbierto;
  set dialogoAbierto(bool value) => _dialogoAbierto = value;

  // -------------------------
  // Agregar alerta a la cola
  // -------------------------
  void agregarAlerta(Map<String, dynamic> alerta, void Function() callback) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final docId = alerta['docId'] ?? '';
    if (currentUser != null && alerta['emisorId'] == currentUser.uid) return;
    if (_processedAlertIds.contains(docId)) return;

    _processedAlertIds.add(docId);

    if (_dialogoAbierto || _alertaQueue.isNotEmpty) {
      print('Ignorando alerta porque ya hay un modal en proceso');
      return;
    }

    _alertaQueue.add(alerta);
    callback(); // ⚡ Llamar a HomePage para procesar UI
  }

  // Obtener siguiente alerta de la cola
  Map<String, dynamic>? obtenerSiguienteAlerta() {
    if (_alertaQueue.isEmpty) return null;
    return _alertaQueue.removeFirst();
  }

  // --------------------------------------
  // Escuchar alertas de todos los círculos
  // --------------------------------------
  Future<void> escucharAlertasTodosCirculos(void Function() callback) async {
    print('Iniciando _escucharAlertasTodosCirculos');
    cancelarEscuchasAlertas();
    _initialCircleFetched.clear();

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final circulos = await CirculosService.getCirculosUsuario();
    final circleIds = circulos.map((d) => d.id).toList();
    if (circleIds.isEmpty) return;

    for (var id in circleIds) _ultimoTimestampPorCirculo.remove(id);

    final query = FirebaseFirestore.instance
        .collection('alertasCirculos')
        .where('destinatarios', arrayContains: currentUser.uid)
        .orderBy('timestamp', descending: true);

    final sub = query.snapshots().skip(1).listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added) continue;

        final data = change.doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final emisor = data['emisorId'] as String?;
        if (emisor == currentUser.uid) continue;

        final ts = data['timestamp'] as Timestamp?;
        if (ts == null) continue;

        final List<dynamic>? alertaCircleIds = data['circleIds'] as List<dynamic>?;
        if (alertaCircleIds == null || alertaCircleIds.isEmpty) continue;

        String? circleIdParaMostrar;
        for (var cid in alertaCircleIds) {
          if (circleIds.contains(cid)) {
            circleIdParaMostrar = cid as String;
            break;
          }
        }
        if (circleIdParaMostrar == null) continue;

        final lastTs = _ultimoTimestampPorCirculo[circleIdParaMostrar];
        if (lastTs != null && ts.millisecondsSinceEpoch <= lastTs.millisecondsSinceEpoch) continue;

        _ultimoTimestampPorCirculo[circleIdParaMostrar] = ts;

        final alertaConCircleId = Map<String, dynamic>.from(data);
        alertaConCircleId['circleId'] = circleIdParaMostrar;

        // ⚡ Agregar alerta y llamar callback a HomePage
        agregarAlerta(alertaConCircleId, callback);
      }
    });

    _alertSubs['global'] = sub;
  }

  // Cancelar todos los listeners de alertas
  void cancelarEscuchasAlertas() {
    for (var sub in _alertSubs.values) sub.cancel();
    _alertSubs.clear();
  }

  // ---------------------------
  // Enviar alerta SOS
  // ---------------------------
  Future<void> enviarAlerta() async {
    if (_enviandoAlerta) return;
    _enviandoAlerta = true;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final uid = user.uid;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final nombre = userDoc.data()?['name'] ?? 'Usuario';
      final phone = userDoc.data()?['phone'] ?? 'N/A';

      gl.Position? posicion;
      try {
        bool servicioActivo = await gl.Geolocator.isLocationServiceEnabled();
        if (!servicioActivo) {
          print("GPS no está activo");
        } else {
          gl.LocationPermission permiso = await gl.Geolocator.checkPermission();
          if (permiso == gl.LocationPermission.denied || permiso == gl.LocationPermission.deniedForever) {
            permiso = await gl.Geolocator.requestPermission();
          }
          if (permiso != gl.LocationPermission.denied && permiso != gl.LocationPermission.deniedForever) {
            posicion = await gl.Geolocator.getCurrentPosition(desiredAccuracy: gl.LocationAccuracy.high);
          }
        }
      } catch (e) {
        print("Error al obtener ubicación: $e");
      }

      final circulos = await FirebaseFirestore.instance
          .collection('circulos')
          .where('miembrosUids', arrayContains: uid)
          .get();

      if (circulos.docs.isEmpty) return;

      Set<String> destinatariosGlobal = {};
      List<String> circleIds = [];

      for (var doc in circulos.docs) {
        final miembrosUids = List<String>.from(doc.data()['miembrosUids'] ?? []);
        destinatariosGlobal.addAll(miembrosUids);
        circleIds.add(doc.id);
      }

      final alertaRef = FirebaseFirestore.instance.collection('alertasCirculos').doc();
      Map<String, dynamic> alertaData = {
        'docId': alertaRef.id,
        'circleIds': circleIds,
        'mensaje': '¡$nombre ha enviado una alerta SOS!',
        'emisorId': uid,
        'name': nombre,
        'phone': phone,
        'timestamp': FieldValue.serverTimestamp(),
        'destinatarios': destinatariosGlobal.toList(),
        'activa': true,
        if (posicion != null) 'ubicacion': {'lat': posicion.latitude, 'lng': posicion.longitude},
      };

      await alertaRef.set(alertaData);
      print("Alerta global enviada correctamente.");
    } catch (e) {
      print("Error al enviar alerta: $e");
    } finally {
      _enviandoAlerta = false;
    }
  }

  void escucharAlertasEnTiempoReal() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _alertasSubscription = FirebaseFirestore.instance
        .collectionGroup('alertasCirculos')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isEmpty) return;

      final alerta = snapshot.docs.first;
      final data = alerta.data() as Map<String, dynamic>;
      final emisorId = data['emisorId'];
      final timestamp = data['timestamp'] as Timestamp;
      final vistas = List<String>.from(data['vistas'] ?? []);

      if ((_ultimoTimestampVisto == null || timestamp.compareTo(_ultimoTimestampVisto!) > 0) &&
          emisorId != uid &&
          !vistas.contains(uid)) {
        _mostrarNotificacion = true;
        _ultimoTimestampVisto = timestamp;
      } else {
        _mostrarNotificacion = false;
      }
    });
  }
}
