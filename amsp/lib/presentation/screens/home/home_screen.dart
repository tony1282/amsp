import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:geolocator/geolocator.dart' as gl;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'package:amsp/map/managers/alerts_manager.dart';
import 'package:amsp/map/managers/circles_manager.dart';
import 'package:amsp/map/managers/map_manager.dart';
import 'package:amsp/map/managers/markers_manager.dart';
import 'package:amsp/map/managers/risk_zones_manager.dart';
import 'package:amsp/alerts/handlers/iot_alert_handler.dart';
import 'package:amsp/alerts/handlers/smart_alert_handler.dart';
import 'package:amsp/alerts/modals/iot_alert_modal.dart';
import 'package:amsp/alerts/modals/smart_alert_modal.dart';
import 'package:amsp/data/repositories/circle_repository.dart';
import 'package:amsp/data/repositories/user_repository.dart';
import 'package:amsp/contacts/call_manager.dart';
import 'package:amsp/contacts/contacts_manager.dart';
import 'package:amsp/reports/historical_reports_manager.dart';
import 'package:amsp/map/services/location_service.dart';

import 'package:amsp/presentation/screens/home/{widgets}/circle_selector_button.dart';
import 'package:amsp/presentation/screens/home/{widgets}/device_button.dart';
import 'package:amsp/presentation/screens/home/{widgets}/home_app_bar.dart';
import 'package:amsp/presentation/screens/home/{widgets}/home_bottom_nav.dart';
import 'package:amsp/presentation/screens/home/{widgets}/report_button.dart';
import 'package:amsp/presentation/screens/home/{widgets}/sos_button.dart';
import 'package:amsp/presentation/screens/home/{widgets}/contact_tile.dart';
import 'package:amsp/presentation/screens/settings/settings_screen.dart';
import 'package:amsp/presentation/screens/alerts/notifications_screen.dart';
import 'package:amsp/presentation/screens/circles/family_screen.dart';
import 'package:amsp/presentation/screens/profile/profile_screen.dart';
import 'package:amsp/presentation/screens/devices/add_device_screen.dart';
import 'package:amsp/presentation/screens/circles/create_circle_screen.dart';
import 'package:amsp/presentation/screens/circles/join_circle_screen.dart';

class HomeScreen extends StatefulWidget {
  final String? circleId;
  const HomeScreen({super.key, this.circleId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Services
  final MapAlerts alerts = MapAlerts();
  final CircleUbications circleUbi = CircleUbications();
  final MapFunctions map = MapFunctions();
  final UserData user = UserData();
  final riskZones zone = riskZones();
  final iotAlerts iot = iotAlerts();
  final smartAlerts smart = smartAlerts();
  final ModalIot modalI = ModalIot();
  final ModalSmart modalS = ModalSmart();
  final CirculosService circleSer = CirculosService();
  final Markers mark = Markers();
  final Callfunctions calls = Callfunctions();
  final PhoneNumberFunctions number = PhoneNumberFunctions();
  final HistoricalReport report = HistoricalReport();

  // Map state
  final Completer<mp.MapboxMap> _mapReady = Completer<mp.MapboxMap>();
  StreamSubscription<gl.Position>? userPositionStream;
  mp.MapboxMap? mapboxMapController;
  mp.PointAnnotationManager? pointAnnotationManager;
  mp.CircleAnnotationManager? circleAnnotationManager;
  mp.Point? _ultimaUbicacionPendiente;

  // Firebase / audio
  final DatabaseReference _ref = FirebaseDatabase.instance.ref();
  final AudioPlayer _player = AudioPlayer();

  // UI state
  bool cargandoUsuario = true;
  bool _mostrarNotificacion = true;
  bool _mostrarModalAlerta = false;
  bool _debeCentrarDespuesDeCerrar = false;
  String? circuloSeleccionadoId;
  String? circuloSeleccionadoNombre;

  // Streams
  StreamSubscription? _alertasSubscription;
  StreamSubscription? _accelerometerSubscription;

  DateTime _ultimaSacudida = DateTime.now().subtract(const Duration(seconds: 10));

  @override
  void initState() {
    super.initState();
    map.seguirUsuario = true;
    setupPositionTracking();

    _accelerometerSubscription = accelerometerEvents.listen((event) {
      final aceleracion = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      if (aceleracion > 30) {
        final ahora = DateTime.now();
        if (ahora.difference(_ultimaSacudida).inSeconds > 10) {
          _ultimaSacudida = ahora;
          if (!_mostrarModalAlerta) {
            _mostrarModalAlerta = true;
            _showSosModal(context);
          }
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await LocationService.startLocationUpdates();
        await user.cargarDatosUsuario();
        smart.escucharAlertasSmart(context);
        alerts.escucharAlertasEnTiempoReal();
        Future.delayed(const Duration(seconds: 3), () => iot.init(context));
        alerts.escucharAlertasTodosCirculos(() => procesarAlertas(context));
        _ref.child('registros').onValue.listen((event) {});
      } catch (e) {
        debugPrint('Error al inicializar HomeScreen: $e');
      }
      if (mounted) setState(() => cargandoUsuario = false);
      map.iniciarSeguimientoContinuo();
    });
  }

  @override
  void dispose() {
    userPositionStream?.cancel();
    alerts.cancelarEscuchasAlertas();
    _accelerometerSubscription?.cancel();
    _alertasSubscription?.cancel();
    pointAnnotationManager?.deleteAll();
    circleAnnotationManager?.deleteAll();
    _player.dispose();
    super.dispose();
  }

  Future<void> setupPositionTracking() async {
    final serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    var permission = await gl.Geolocator.checkPermission();
    if (permission == gl.LocationPermission.denied) {
      permission = await gl.Geolocator.requestPermission();
    }
    if (permission == gl.LocationPermission.denied || permission == gl.LocationPermission.deniedForever) return;

    userPositionStream = gl.Geolocator.getPositionStream(
      locationSettings: const gl.LocationSettings(accuracy: gl.LocationAccuracy.best, distanceFilter: 10),
    ).listen((gl.Position? position) async {
      if (position == null) return;
      final punto = mp.Point(coordinates: mp.Position(position.longitude, position.latitude));
      if (map.seguirUsuario) {
        if (mapboxMapController != null) {
          await mapboxMapController!.easeTo(mp.CameraOptions(center: punto, zoom: 13), mp.MapAnimationOptions(duration: 500));
        } else {
          _ultimaUbicacionPendiente = punto;
        }
      }
    });
  }

  void onMapCreated(mp.MapboxMap controller) async {
    mapboxMapController = controller;
    await zone.mostrarGeoJsonTlaxcala(controller);
    if (!_mapReady.isCompleted) _mapReady.complete(controller);
    await controller.location.updateSettings(mp.LocationComponentSettings(enabled: true));

    pointAnnotationManager = await controller.annotations.createPointAnnotationManager();
    circleAnnotationManager = await controller.annotations.createCircleAnnotationManager();

    circleUbi.mapboxMapController = controller;
    circleUbi.pointAnnotationManager = pointAnnotationManager;
    circleUbi.circleAnnotationManager = circleAnnotationManager;
    circleUbi.mark.pointAnnotationManager = pointAnnotationManager;
    circleUbi.mark.mapboxMapController = controller;
    circleUbi.map.mapboxMapController = controller;
    circleUbi.map.pointAnnotationManager = pointAnnotationManager;

    iot.modalI.mapboxMapController = controller;
    iot.modalI.pointAnnotationManager = pointAnnotationManager;
    iot.modalI.escucharAlertasIoT(context);

    smart.modalS.mapboxMapController = controller;
    smart.modalS.pointAnnotationManager = pointAnnotationManager;
    smart.escucharAlertasSmart(context);

    Future.delayed(const Duration(seconds: 2), () async {
      await map.centrarEnUbicacionActual();
      map.iniciarSeguimientoContinuo();
    });

    if (circuloSeleccionadoId != null && circuloSeleccionadoId!.isNotEmpty) {
      await circleUbi.escucharUbicacionesDelCirculo(circuloSeleccionadoId!);
      Future.delayed(const Duration(milliseconds: 400), () async => await circleUbi.reajustarZoomSiNecesario());
    }

    if (_debeCentrarDespuesDeCerrar) {
      _debeCentrarDespuesDeCerrar = false;
      await Future.delayed(const Duration(milliseconds: 900));
      await map.centrarEnUbicacionActual();
    }
  }

  Future<void> _mostrarModalSeleccionCirculo() async {
    final circulos = await CirculosService.getCirculosUsuario();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
      builder: (context) {
        final theme = Theme.of(context);
        final greenColor = theme.primaryColor;
        final contrastColor = theme.appBarTheme.foregroundColor ?? Colors.white;
        final orangeColor = theme.colorScheme.secondary;
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(color: greenColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
          child: Column(
            children: [
              Icon(Icons.list, size: 40, color: contrastColor),
              const SizedBox(height: 10),
              Text('Selecciona un círculo', style: theme.textTheme.titleLarge?.copyWith(color: contrastColor, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Expanded(
                child: circulos.isEmpty
                    ? Center(child: Text('No tienes círculos', style: theme.textTheme.bodyLarge?.copyWith(color: contrastColor)))
                    : ListView.builder(
                        itemCount: circulos.length,
                        itemBuilder: (context, index) {
                          final doc = circulos[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final nombre = data['nombre'] ?? 'Sin nombre';
                          final tipo = data['tipo'] ?? '';
                          return Card(
                            color: Colors.white,
                            child: ListTile(
                              title: Text(nombre),
                              subtitle: Text(tipo),
                              onTap: () async {
                                setState(() {
                                  circuloSeleccionadoId = doc.id;
                                  circuloSeleccionadoNombre = nombre;
                                  map.seguirUsuario = false;
                                });
                                Navigator.pop(context);
                                if (mapboxMapController != null) {
                                  await circleUbi.escucharUbicacionesDelCirculo(doc.id);
                                  while (circleUbi.todasPosiciones.isEmpty) {
                                    await Future.delayed(const Duration(milliseconds: 200));
                                  }
                                  await map.ajustarZoomParaTodos(circleUbi.todasPosiciones);
                                }
                              },
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.close),
                label: const Text("Cerrar círculo actual"),
                onPressed: () async { Navigator.pop(context); await cerrarCirculoSeleccionado(); },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: orangeColor,
                  side: BorderSide(color: orangeColor, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> cerrarCirculoSeleccionado() async {
    await map.centrarInmediato(mapboxMapController);
    Future.delayed(const Duration(seconds: 3), () async => await map.centrarEnUbicacionActual());
    if (circuloSeleccionadoId == null) return;
    for (var sub in circleUbi.miembrosListeners.values) await sub.cancel();
    circleUbi.miembrosListeners.clear();
    if (circleUbi.pointAnnotationManager != null) {
      for (var marker in circleUbi.mark.miembrosAnnotations.values) await circleUbi.pointAnnotationManager!.delete(marker);
      for (var text in circleUbi.mark.miembrosTextAnnotations.values) await circleUbi.pointAnnotationManager!.delete(text);
    }
    circleUbi.todasPosiciones.clear();
    circleUbi.mark.miembrosAnnotations.clear();
    circleUbi.mark.miembrosTextAnnotations.clear();
    map.seguirUsuario = true;
    _debeCentrarDespuesDeCerrar = true;
    setState(() { circuloSeleccionadoId = null; circuloSeleccionadoNombre = null; });
  }

  void procesarAlertas(BuildContext context) async {
    final alerta = alerts.obtenerSiguienteAlerta();
    if (alerta == null || alerts.dialogoAbierto) return;
    alerts.dialogoAbierto = true;
    await _player.stop();
    _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(AssetSource('sounds/alert.mp3'));

    final mensaje = alerta['mensaje'] ?? "Alerta sin mensaje";
    final emisorId = alerta['emisorId'] as String?;
    String telefonoEmisor = '';
    if (emisorId != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(emisorId).get();
        telefonoEmisor = (doc.data()?['phone'] ?? '') as String;
      } catch (_) {}
    }

    final ubicacion = alerta['ubicacion'] as Map<String, dynamic>?;
    if (ubicacion != null) {
      final lat = (ubicacion['lat'] as num?)?.toDouble();
      final lng = (ubicacion['lng'] as num?)?.toDouble();
      if (lat != null && lng != null && mapboxMapController != null) {
        alerts.pointAnnotationManager ??= await mapboxMapController!.annotations.createPointAnnotationManager();
        await mapboxMapController!.flyTo(mp.CameraOptions(center: mp.Point(coordinates: mp.Position(lng, lat)), zoom: 15.0), mp.MapAnimationOptions(duration: 1000));
        final idAlerta = "$lat-$lng";
        if (!alerts.alertasAnnotations.containsKey(idAlerta)) {
          final bytes = await rootBundle.load("assets/alert.png");
          final annotation = await alerts.pointAnnotationManager!.create(mp.PointAnnotationOptions(
            geometry: mp.Point(coordinates: mp.Position(lng, lat)),
            image: bytes.buffer.asUint8List(), iconSize: 0.35, iconOffset: [0, -80],
            textField: mensaje, textSize: 14, textOffset: [0, 2.0],
            textColor: Colors.black.value, textHaloColor: Colors.white.value, textHaloWidth: 2,
          ));
          if (annotation != null) alerts.alertasAnnotations[idAlerta] = annotation;
        }
      }
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(16)),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [Icon(Icons.warning, color: Colors.white), SizedBox(width: 8), Text("Alerta SOS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 25))]),
                const SizedBox(height: 16),
                Text(mensaje, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (emisorId != null && telefonoEmisor.isNotEmpty) Text("De: $telefonoEmisor", style: const TextStyle(color: Colors.white, fontSize: 18)),
                if (ubicacion != null) Text("Ubicación: ${ubicacion['lat'].toStringAsFixed(6)}, ${ubicacion['lng'].toStringAsFixed(6)}", style: const TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 16),
                const Text("Protocolo:", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text("1. Llama de inmediato al usuario en riesgo.\n2. Verifica su ubicación en el mapa.\n3. Notifica a las autoridades si no responde.\n4. Manten comunicación con los demás miembros del círculo.", style: TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (telefonoEmisor.isNotEmpty)
                      TextButton(
                        onPressed: () { _player.stop(); Navigator.of(context, rootNavigator: true).pop(); calls.llamarNumero(context, telefonoEmisor); },
                        style: TextButton.styleFrom(foregroundColor: Colors.red, backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        child: const Text("Llamar", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () { Navigator.pop(context); _player.stop(); alerts.dialogoAbierto = false; },
                      style: TextButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      child: const Text("Cerrar", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() async { alerts.dialogoAbierto = false; await _player.stop(); procesarAlertas(context); });
  }

  void _showSosModal(BuildContext context) {
    int countdown = 5;
    Timer? timer;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          timer ??= Timer.periodic(const Duration(seconds: 1), (t) {
            if (countdown == 1) { t.cancel(); Navigator.of(context).pop(); alerts.enviarAlerta(); }
            else setState(() => countdown--);
          });
          return AlertDialog(
            backgroundColor: Colors.red.shade700,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('¡EMERGENCIA SOS!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Enviando alerta en $countdown segundos...', style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
              const SizedBox(height: 10),
              const Text('Pulsa "Cancelar" si fue un error.', style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
            ]),
            actions: [TextButton(onPressed: () { timer?.cancel(); Navigator.of(context).pop(); }, child: const Text('Cancelar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))],
          );
        },
      ),
    ).then((_) { timer?.cancel(); _mostrarModalAlerta = false; });
  }

  void _mostrarOpcionesCirculo() {
    final theme = Theme.of(context);
    final greenColor = theme.primaryColor;
    final contrastColor = theme.appBarTheme.foregroundColor ?? Colors.white;
    final orangeColor = theme.colorScheme.secondary;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
      backgroundColor: greenColor,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(25),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.family_restroom, size: 50, color: contrastColor),
          const SizedBox(height: 16),
          Text("Opciones de Círculo", style: theme.textTheme.titleLarge?.copyWith(color: contrastColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.group_add),
            label: const Text("Crear círculo", style: TextStyle(color: Colors.black)),
            onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const CrearCirculoScreen())); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: orangeColor, side: BorderSide(color: orangeColor, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), minimumSize: const Size.fromHeight(50)),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.login),
            label: const Text("Unirse a un círculo", style: TextStyle(color: Colors.black)),
            onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const UnirseCirculoScreen())); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: orangeColor, side: BorderSide(color: orangeColor, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), minimumSize: const Size.fromHeight(50)),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.list),
            label: const Text("Seleccionar círculo para mostrar"),
            onPressed: () async { Navigator.pop(context); await _mostrarModalSeleccionCirculo(); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: orangeColor, side: BorderSide(color: orangeColor, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), minimumSize: const Size.fromHeight(50)),
          ),
        ]),
      ),
    );
  }

  Future<void> _modalTelefono(BuildContext context) async {
    final theme = Theme.of(context);
    final greenColor = theme.primaryColor;
    final contrastColor = theme.appBarTheme.foregroundColor ?? Colors.white;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      backgroundColor: greenColor,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.phone, size: 35, color: contrastColor),
          Text('Contactos de Emergencia', style: theme.textTheme.titleLarge?.copyWith(color: contrastColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('contactos').doc(userId).collection('contactos_emergencia').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              return ListView.builder(
                shrinkWrap: true,
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final c = snapshot.data!.docs[index];
                  return ContactTile(id: c.id, nombre: c['nombreContacto'], numero: c['numeroContacto'], calls: calls, number: number);
                },
              );
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => number.mostrarFormularioAgregar(context),
            icon: const Icon(Icons.add),
            label: const Text('Agregar Contacto'),
            style: ElevatedButton.styleFrom(backgroundColor: contrastColor, foregroundColor: greenColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final greenColor = theme.primaryColor;

    if (cargandoUsuario) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: HomeAppBar(
        mostrarNotificacion: _mostrarNotificacion,
        onSettingsPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConfScreen())),
        onNotificationsPressed: () {
          setState(() => _mostrarNotificacion = false);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen()));
        },
      ),
      body: Stack(children: [
        mp.MapWidget(onMapCreated: onMapCreated, styleUri: 'mapbox://styles/mapbox/streets-v12'),
        CircleSelectorButton(onPressed: _mostrarOpcionesCirculo),
        DeviceButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgregarDispositivoScreen()))),
        ReportButton(onPressed: () => report.mostrarModalReporteHistorico(context)),
      ]),
      floatingActionButton: SosButton(onPressed: () => _showSosModal(context)),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: BottomAppBar(
        color: greenColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            IconButton(
              icon: Icon(Icons.location_on, color: map.seguirUsuario ? const Color(0xFFFF6C00) : Colors.white, size: 45),
              onPressed: () async { await map.toggleSeguirUsuario(); setState(() {}); },
            ),
            IconButton(icon: const Icon(Icons.family_restroom, size: 45, color: Colors.white), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FamilyScreen()))),
            IconButton(icon: const Icon(Icons.person, size: 45, color: Colors.white), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserScreenCon()))),
            IconButton(icon: const Icon(Icons.phone, size: 45, color: Colors.white), onPressed: () => _modalTelefono(context)),
          ]),
        ),
      ),
    );
  }
}
