import 'dart:async';
import 'dart:collection' show Queue;
import 'package:amsp/functions/callFunctions.dart';
import 'package:amsp/functions/circleUbications.dart';
import 'package:amsp/functions/iotAlerts.dart';
import 'package:amsp/functions/mapFunctions.dart';
import 'package:amsp/functions/markers.dart';
import 'package:amsp/functions/phone_number_functions.dart';
import 'package:amsp/functions/riskZones.dart';
import 'package:amsp/functions/smartAlerts.dart';
import 'package:amsp/functions/userData.dart';
import 'package:amsp/modals/modalIot.dart';
import 'package:amsp/modals/modalSmart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:firebase_database/firebase_database.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:amsp/services/circulos_service.dart';
import 'package:amsp/functions/map_alerts.dart';

class HistoricalReport {
  final alerts = MapAlerts();
  final circleUbi = CircleUbications();
  final map = MapFunctions();
  final user = UserData();
  final zone = riskZones();
  final iot = iotAlerts();
  final smart = smartAlerts();
  final modalI = ModalIot();
  final modalS = ModalSmart();
  final circleSer = CirculosService();
  final mark = Markers();
  final calls = Callfunctions();
  final number = PhoneNumberFunctions();

  StreamSubscription? userPositionStream;  
  mp.MapboxMap? mapboxMapController;
  mp.PointAnnotation? usuarioAnnotation;
  mp.PointAnnotation? usuarioTextoAnnotation;
  mp.PointAnnotationManager? pointAnnotationManager;
  mp.CircleAnnotationManager? circleAnnotationManager;
  mp.CircleAnnotation? usuarioCircleAnnotation;
  mp.Point? ultimaPosicion;
  mp.Point? _ultimaUbicacionPendiente;

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
  bool _alertaActiva = false;

  StreamSubscription? _alertasSubscription;
  StreamSubscription? _accelerometerSubscription;

  final DatabaseReference _ref = FirebaseDatabase.instance.ref();
  final AudioPlayer _player = AudioPlayer();
  final Set<String> _processedAlertIds = {};
  final Queue<Map<String,dynamic>> _alertaQueue = Queue();

  Set<String> _alertasProcesadas = {};
  String? circuloSeleccionadoId;
  String? circuloSeleccionadoNombre;
  String? _ultimoMensajeIot;
  String? _ultimoMensajeMostrado;
  String? _mensajeAlerta;

  List<String> codigosRiesgo = [];

  final Set<String> _alertasMostradasIds = {};
  final Set<String> _alertasMostradas = {};
  final Map<String, bool> _initialCircleFetched = {};

  Timestamp? _ultimoTimestampVisto; 
  DateTime _ultimaSacudida = DateTime.now().subtract(const Duration(seconds: 10));
  DateTime _sessionStart = DateTime.now();
  DateTime _appStartTime = DateTime.now();
  DateTime? _ultimoTimestampAlertasIoT;

  // 🔹 Reporte histórico
  void mostrarModalReporteHistorico(BuildContext context) {
    final TextEditingController descripcionController = TextEditingController();
    final user = FirebaseAuth.instance.currentUser;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);
        final theme = Theme.of(context);
        final greenColor = theme.primaryColor;
        final orangeColor = theme.colorScheme.secondary;

        return Container(
          color: greenColor, 
          child: Padding(
            padding: EdgeInsets.only(
              bottom: mediaQuery.viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min, 
              children: [
                Text(
                  'Reporte',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: descripcionController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: orangeColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: orangeColor, width: 2),
                    ),
                    labelText: 'Descripción',
                    hintText: 'Escribe aquí la descripción del reporte...',
                  ),
                ),
                const SizedBox(height: 15),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final descripcion = descripcionController.text.trim();

                    if (descripcion.isEmpty) {
                      return;
                    }

                    if (user == null) {
                      Navigator.pop(context);
                      return;
                    }

                    final userDoc = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .get();
                    final nombre = userDoc.data()?['name'] ?? 'Amsp';

                    gl.Position? posicion;
                    try {
                      bool servicioActivo = await gl.Geolocator.isLocationServiceEnabled();
                      if (servicioActivo) {
                        gl.LocationPermission permiso = await gl.Geolocator.checkPermission();
                        if (permiso == gl.LocationPermission.denied || permiso == gl.LocationPermission.deniedForever) {
                          permiso = await gl.Geolocator.requestPermission();
                        }
                        if (permiso != gl.LocationPermission.denied && permiso != gl.LocationPermission.deniedForever) {
                          posicion = await gl.Geolocator.getCurrentPosition(desiredAccuracy: gl.LocationAccuracy.high);
                        }
                      }
                    } catch (e) {
                      posicion = null;
                    }

                    Map<String, dynamic> reporteData = {
                      'mensaje': descripcion,
                      'name': nombre,
                      'timestamp': FieldValue.serverTimestamp(),
                      'uid': user.uid,
                    };

                    if (posicion != null) {
                      reporteData['ubicacion'] = {
                        'lat': posicion.latitude,
                        'lng': posicion.longitude,
                      };
                    }

                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('reportes_historicos')
                        .add(reporteData);

                    Navigator.pop(context);
                  },
                  child: Text(
                    'Guardar reporte',
                    style: TextStyle(color: greenColor),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
