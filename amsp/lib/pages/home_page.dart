import 'dart:async';
import 'dart:collection' show Queue;
import 'dart:math';
import 'package:amsp/functions/callFunctions.dart';
import 'package:amsp/functions/circleUbications.dart';
import 'package:amsp/functions/iotAlerts.dart';
import 'package:amsp/functions/mapFunctions.dart';
import 'package:amsp/functions/markers.dart';
import 'package:amsp/functions/riskZones.dart';
import 'package:amsp/functions/smartAlerts.dart';
import 'package:amsp/functions/userData.dart';
import 'package:amsp/modals/modalIot.dart';
import 'package:amsp/modals/modalSmart.dart';
import 'package:amsp/pages/crear_circulo_screen.dart';
import 'package:amsp/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:url_launcher/url_launcher.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:amsp/services/circulos_service.dart';


// Importar pantallas
import 'conf_screen.dart';
import 'family_screen.dart';
import 'notifications_screen.dart';
import 'user_screen_con.dart';
import 'unirse_circulo_screen.dart';
import 'agregar_dispositivo_screen.dart';
import 'package:amsp/functions/map_alerts.dart';



class HomePage extends StatefulWidget {
  final String? circleId;
  final MapFunctions mapFunctions = MapFunctions();

  
  HomePage({super.key, required this.circleId});
  

  @override
  State<HomePage> createState() => _HomePageState();
}


class MiClase {
  late double valor;
  late double raiz;

  MiClase() {
    valor = 9.0;
    raiz = sqrt(valor); 
  }
}


class _HomePageState extends State<HomePage> {
  
  
  //
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
  // 



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


@override
void initState() {
  
  super.initState();
  map.centrarEnUbicacionActual();
  setupPositionTracking();

  

  print("initState ejecutado");

  _appStartTime = DateTime.now();
  _ultimaSacudida = DateTime.now().subtract(const Duration(seconds: 10));

  _accelerometerSubscription = accelerometerEvents.listen((event) {
    final double aceleracion = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    if (aceleracion > 30) {
      final ahora = DateTime.now();
      if (ahora.difference(_ultimaSacudida).inSeconds > 10) {
        _ultimaSacudida = ahora;

        if (!_mostrarModalAlerta) {
          _mostrarModalAlerta = true;
          print("Sacudida detectada: mostrando modal SOS");
          _showSosModal(context);
        }
      }
    }
  });

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    print("Post-frame callback iniciado");

    try {
      print("Iniciando LocationService");
      await LocationService.startLocationUpdates();

      print("Cargando datos de usuario");
      await user.cargarDatosUsuario();

      print("Escuchando alertas Smartwatch");
      smart.escucharAlertasSmart(context);

      print("Escuchando alertas en tiempo real");
      alerts.escucharAlertasEnTiempoReal();

      print("Escuchando alertas IoT (con filtro de tiempo)");

      // Delay para asegurar que todo esté inicializado
      Future.delayed(const Duration(seconds: 3), () {
        iot.init(context);
        print("Escucha IoT iniciada después del delay");
      });

      print("Escuchando alertas de todos los círculos");
      alerts.escucharAlertasTodosCirculos(() => procesarAlertas(context));

      print("Escuchando registros históricos en Firebase");
      _ref.child('registros').onValue.listen((event) {});

      print("Post frame callback finalizado: todo listo");
    } catch (e) {
      print("Error al inicializar HomePage: $e");
    }

    if (mounted) {
      setState(() {
        cargandoUsuario = false;
      });
    }

    map.iniciarSeguimientoContinuo();
  });
}





@override
void dispose() {
  userPositionStream?.cancel();

  for (var sub in miembrosListeners.values) {
    sub.cancel();
  }
  miembrosListeners.clear();

  alerts.cancelarEscuchasAlertas();
  _accelerometerSubscription?.cancel();
  _alertasSubscription?.cancel();

  pointAnnotationManager?.deleteAll();
  circleAnnotationManager?.deleteAll();

  super.dispose();
}



Future<void> _mostrarModalSeleccionCirculo() async {
  final circulos = await CirculosService.getCirculosUsuario();

  if (!mounted) return;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
    ),
    builder: (context) {
      final theme = Theme.of(context);
      final greenColor = theme.primaryColor;
      final contrastColor = theme.appBarTheme.foregroundColor ?? Colors.white;
      final orangeColor = theme.colorScheme.secondary;

      return Container(
        padding: const EdgeInsets.all(16),
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: greenColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        ),
        child: Column(
          children: [
            Icon(Icons.list, size: 40, color: contrastColor),
            const SizedBox(height: 10),
            Text(
              'Selecciona un círculo',
              style: theme.textTheme.titleLarge
                  ?.copyWith(color: contrastColor, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: circulos.isEmpty
                  ? Center(
                      child: Text(
                        'No tienes círculos',
                        style: theme.textTheme.bodyLarge?.copyWith(color: contrastColor),
                      ),
                    )
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

                                Future.delayed(const Duration(milliseconds: 800), () async {
                                  if (circleUbi.todasPosiciones.isNotEmpty) {
                                    await map.ajustarZoomParaTodos(circleUbi.todasPosiciones);
                                  } else {
                                    Timer.periodic(const Duration(milliseconds: 300), (timer) async {
                                      if (circleUbi.todasPosiciones.isNotEmpty) {
                                        timer.cancel();
                                        await map.ajustarZoomParaTodos(circleUbi.todasPosiciones);
                                      }
                                    });
                                  }
                                });
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
              onPressed: () async {
                Navigator.pop(context);
                await cerrarCirculoSeleccionado();
              },
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




void procesarAlertas(BuildContext context) async {
  final alerta = alerts.obtenerSiguienteAlerta();
  if (alerta == null || alerts.dialogoAbierto) return;

  alerts.dialogoAbierto = true;

  await _player.stop();
  _player.setReleaseMode(ReleaseMode.loop);
  await _player.play(AssetSource('sounds/alert.mp3'));

  final mensaje = alerta['mensaje'] ?? "Alerta sin mensaje";
  final circleId = alerta['circleId'] as String?;
  final emisorId = alerta['emisorId'] as String?;

  String telefonoEmisor = '';
  if (emisorId != null) {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(emisorId).get();
      final dataUser = userDoc.data();
      if (dataUser != null) telefonoEmisor = (dataUser['phone'] ?? '') as String;
    } catch (_) {}
  }

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      backgroundColor: Colors.red,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: const [
          Icon(Icons.warning, color: Colors.white),
          SizedBox(width: 8),
          Text("Alerta SOS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 25)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(mensaje, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text("Protocolo de emergencia:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          const Text(
            "1. Llama de inmediato al usuario en riesgo.\n"
            "2. Verifica su ubicación en el mapa.\n"
            "3. Notifica a las autoridades si no responde.\n"
            "4. Manten comunicación con los demás miembros del círculo.",
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
      actions: [
        if (telefonoEmisor.isNotEmpty)
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              calls.llamarNumero(context, telefonoEmisor);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red, backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text("Llamar", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          child: const Text("Cerrar", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  ).whenComplete(() async {
    alerts.dialogoAbierto = false;
    await _player.stop();
    procesarAlertas(context);
  });
}




void _mostrarOpcionesCirculo() {
  final theme = Theme.of(context);
  final greenColor = theme.primaryColor;
  final contrastColor = theme.appBarTheme.foregroundColor ?? Colors.white;
  final orangeColor = theme.colorScheme.secondary;

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
    ),
    backgroundColor: greenColor,
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.family_restroom, size: 50, color: contrastColor),
            const SizedBox(height: 16),
            Text(
              "Opciones de Círculo",
              style: theme.textTheme.titleLarge
                  ?.copyWith(color: contrastColor, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.group_add),
              label: const Text("Crear círculo", style: TextStyle(color: Colors.black)),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CrearCirculoScreen()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: orangeColor,
                side: BorderSide(color: orangeColor, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.login),
              label: const Text("Unirse a un círculo", style: TextStyle(color: Colors.black)),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const UnirseCirculoScreen()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: orangeColor,
                side: BorderSide(color: orangeColor, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.list),
              label: const Text("Seleccionar círculo para mostrar"),
              onPressed: () async {
                Navigator.pop(context);
                await _mostrarModalSeleccionCirculo();
              },
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

Future<void> _modalTelefono(BuildContext context) async {
  final theme = Theme.of(context);
  final greenColor = theme.primaryColor;
  final contrastColor = theme.appBarTheme.foregroundColor ?? Colors.white;
  final userId = FirebaseAuth.instance.currentUser?.uid;

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    backgroundColor: greenColor,
    isScrollControlled: true,
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.phone, size: 35, color: contrastColor),
            Text(
              'Contactos de Emergencia',
              style: theme.textTheme.titleLarge?.copyWith(
                color: contrastColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('contactos')
                  .doc(userId)
                  .collection('contactos_emergencia')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                final contactos = snapshot.data!.docs;

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: contactos.length,
                  itemBuilder: (context, index) {
                    final contacto = contactos[index];
                    return _contactTile(
                      context,
                      contacto.id,
                      contacto['nombreContacto'],
                      contacto['numeroContacto'],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _mostrarFormularioAgregar(context),
              icon: const Icon(Icons.add),
              label: const Text('Agregar Contacto'),
              style: ElevatedButton.styleFrom(
                backgroundColor: contrastColor,
                foregroundColor: greenColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

void _mostrarFormularioAgregar(BuildContext context) {
  final theme = Theme.of(context);
  final greenColor = theme.primaryColor;
  final _nombreController = TextEditingController();
  final _numeroController = TextEditingController();
  final userId = FirebaseAuth.instance.currentUser?.uid;

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: greenColor,
      title: const Text("Agregar Contacto", style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nombreController,
            textCapitalization: TextCapitalization.words, 
            decoration: const InputDecoration(
              labelText: "Nombre",
              labelStyle: TextStyle(color: Colors.white70),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white70),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
            ),
            style: const TextStyle(color: Colors.white),
          ),
          TextField(
            controller: _numeroController,
            keyboardType: TextInputType.number, 
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10), 
            ],
            decoration: const InputDecoration(
              labelText: "Número",
              labelStyle: TextStyle(color: Colors.white70),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white70),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
            ),
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancelar", style: TextStyle(color: Colors.white)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: greenColor,
          ),
          onPressed: () async {
            final nombre = _nombreController.text.trim();
            final numero = _numeroController.text.trim();
            if (nombre.isEmpty || numero.isEmpty || numero.length != 10) return;

            await FirebaseFirestore.instance
                .collection('contactos')
                .doc(userId)
                .collection('contactos_emergencia')
                .add({
              'nombreContacto': nombre,
              'numeroContacto': numero,
              'fechaAgregado': FieldValue.serverTimestamp(),
            });

            Navigator.pop(context);
          },
          child: const Text("Guardar"),
        ),
      ],
    ),
  );
}

void _editarContacto(BuildContext context, String id, String nombreActual, String numeroActual) {
  final theme = Theme.of(context);
  final greenColor = theme.primaryColor;
  final _nombreController = TextEditingController(text: nombreActual);
  final _numeroController = TextEditingController(text: numeroActual);
  final userId = FirebaseAuth.instance.currentUser?.uid;

showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: greenColor,
      title: const Text("Editar Contacto", style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nombreController,
            decoration: const InputDecoration(
              labelText: "Nombre",
              labelStyle: TextStyle(color: Colors.white70),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white70),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
            ),
            style: const TextStyle(color: Colors.white),
          ),
          TextField(
            controller: _numeroController,
            decoration: const InputDecoration(
              labelText: "Número",
              labelStyle: TextStyle(color: Colors.white70),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white70),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
            ),
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancelar", style: TextStyle(color: Colors.white)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: greenColor,
          ),
          onPressed: () async {
            await FirebaseFirestore.instance
                .collection('contactos')
                .doc(userId)
                .collection('contactos_emergencia')
                .doc(id)
                .update({
              'nombreContacto': _nombreController.text.trim(),
              'numeroContacto': _numeroController.text.trim(),
            });
            Navigator.pop(context);
          },
          child: const Text("Actualizar"),
        ),
      ],
    ),
  );
}




Future<void> setupPositionTracking() async {
  final serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) return;

  var permission = await gl.Geolocator.checkPermission();
  if (permission == gl.LocationPermission.denied) {
    permission = await gl.Geolocator.requestPermission();
  }
  if (permission == gl.LocationPermission.denied ||
      permission == gl.LocationPermission.deniedForever) {
    return;
  }

  await mapboxMapController?.location.updateSettings(
    mp.LocationComponentSettings(enabled: true, pulsingEnabled: true),
  );

  userPositionStream = gl.Geolocator.getPositionStream(
  locationSettings: const gl.LocationSettings(
    accuracy: gl.LocationAccuracy.best,
    distanceFilter: 0,
  ),
).listen((gl.Position? position) async {
  if (position == null) return;

  final puntoUsuario = mp.Point(
    coordinates: mp.Position(position.longitude, position.latitude),
  );

  if (map.seguirUsuario) {
    if (mapboxMapController != null) {
      await mapboxMapController!.easeTo(
        mp.CameraOptions(center: puntoUsuario, zoom: 13),
        mp.MapAnimationOptions(duration: 500),
      );
    } else {
      _ultimaUbicacionPendiente = puntoUsuario;
    }
  }
  });
}







void _onMapCreated(mp.MapboxMap controller) async {
  mapboxMapController = controller;
  await aplicarUbicacionPendiente();

  await controller.location.updateSettings(
    mp.LocationComponentSettings(enabled: true),
  );

  pointAnnotationManager = await controller.annotations.createPointAnnotationManager();
  circleAnnotationManager = await controller.annotations.createCircleAnnotationManager();

  // Inyecciones de dependencias
  circleUbi.mapboxMapController = mapboxMapController;
  circleUbi.pointAnnotationManager = pointAnnotationManager;
  circleUbi.circleAnnotationManager = circleAnnotationManager;

  // conectar el mapa interno de circleUbi con el controlador real
  circleUbi.map.mapboxMapController = mapboxMapController; 
  circleUbi.map.pointAnnotationManager = pointAnnotationManager; 

  circleUbi.mark.pointAnnotationManager = pointAnnotationManager;
  circleUbi.mark.mapboxMapController = mapboxMapController;

  iot.modalI.mapboxMapController = mapboxMapController;
  iot.modalI.pointAnnotationManager = pointAnnotationManager;
  iot.modalI.escucharAlertasIoT(context);

  smart.modalS.mapboxMapController = mapboxMapController;
  smart.modalS.pointAnnotationManager = pointAnnotationManager;
  smart.escucharAlertasSmart(context);

  // 🔹 Centrar automáticamente y activar seguimiento si _seguirUsuario es true
  if (map.seguirUsuario) {
    await map.toggleSeguirUsuario(); // 🔹 Esto centra la cámara y activa seguimiento
    setState(() {}); // 🔁 actualiza color del botón
  }

  // 🔹 Escuchar ubicaciones del círculo si se seleccionó
  if (circuloSeleccionadoId != null && circuloSeleccionadoId!.isNotEmpty) {
    await circleUbi.escucharUbicacionesDelCirculo(circuloSeleccionadoId!);

    // 🔹 Ajustar zoom automáticamente para mostrar todos los miembros
    Future.delayed(const Duration(milliseconds: 500), () async {
      if (circleUbi.todasPosiciones.isNotEmpty) {
        await map.ajustarZoomParaTodos(circleUbi.todasPosiciones);
      }
    });
  } else {
    print('No se ha seleccionado ningún círculo.');
  }
}


Future<void> cerrarCirculoSeleccionado() async {
  if (circuloSeleccionadoId == null) {
    print("⚠️ No hay círculo seleccionado actualmente.");
    return;
  }

  print("Cerrando círculo: $circuloSeleccionadoNombre");

  // 🔹 Cancelar escuchas activas de los miembros
  for (var sub in circleUbi.miembrosListeners.values) {
    await sub.cancel();
  }
  circleUbi.miembrosListeners.clear();

  // 🔹 Borrar los marcadores de miembros del mapa
  if (circleUbi.pointAnnotationManager != null) {
    for (var marker in circleUbi.mark.miembrosAnnotations.values) {
      await circleUbi.pointAnnotationManager!.delete(marker);
    }
    for (var text in circleUbi.mark.miembrosTextAnnotations.values) {
      await circleUbi.pointAnnotationManager!.delete(text);
    }
  }

  // 🔹 Limpiar colecciones en memoria
  circleUbi.todasPosiciones.clear();
  circleUbi.mark.miembrosAnnotations.clear();
  circleUbi.mark.miembrosTextAnnotations.clear();

  // 🔹 Restaurar seguimiento y centrar en usuario
  map.seguirUsuario = true;
  await map.centrarEnUbicacionActual();

  // 🔹 Limpiar selección actual
  setState(() {
    circuloSeleccionadoId = null;
    circuloSeleccionadoNombre = null;
  });

  print("✅ Círculo cerrado y mapa centrado en el usuario.");
}



Future<void> aplicarUbicacionPendiente() async {
  if (_ultimaUbicacionPendiente != null && mapboxMapController != null) {
    await mapboxMapController!.easeTo(
      mp.CameraOptions(center: _ultimaUbicacionPendiente!, zoom: 13),
      mp.MapAnimationOptions(duration: 500),
    );
    _ultimaUbicacionPendiente = null;
  }
}

//Reporte histórico
void _mostrarModalReporteHistorico(BuildContext context) {
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

// Mostrar modal de alerta SOS
void _showSosModal(BuildContext context) {
  int countdown = 5;
  Timer? timer;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          if (timer == null) {
            timer = Timer.periodic(const Duration(seconds: 1), (t) {
              if (countdown == 1) {
                t.cancel(); 
                Navigator.of(context).pop();
                 alerts.enviarAlerta();
              } else {
                setState(() {
                  countdown--;
                });
              }
            });
          }

          return AlertDialog(
            backgroundColor: Colors.red.shade700,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              '¡EMERGENCIA SOS!',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enviando alerta en $countdown segundos...',
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Pulsa "Cancelar" si fue un error.',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  timer?.cancel(); 
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      );
    },
  ).then((_) {
    timer?.cancel();
    _mostrarModalAlerta = false;
  });
}

Widget _contactTile(BuildContext context, String id, String nombre, String numero) {
  return Container(
    margin: const EdgeInsets.only(bottom: 15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFFF6C00), width: 2),
    ),
    child: ListTile(
      leading: const Icon(Icons.phone, color: Color(0xFFF47405)),
      title: Text(nombre),
      subtitle: Text(numero),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.black),
            onPressed: () => _editarContacto(context, id, nombre, numero),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.black),
            onPressed: () => calls.eliminarContacto(context, id),
          ),
        ],
      ),
      onTap: () {
        calls.llamarNumero(context, numero);
      },
    ),
  );
}

@override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final greenColor = theme.primaryColor;
  final contrastColor = theme.appBarTheme.foregroundColor ?? Colors.white;
  final orangeTrans = const Color.fromARGB(221, 255, 120, 23);
  final screenHeight = MediaQuery.of(context).size.height;

  if (cargandoUsuario) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }

  return Scaffold(
    appBar: AppBar(
      centerTitle: true,
      title: const Text('AMSP'),
      leading: _iconButton(Icons.settings, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ConfScreen()),
        );
      }, contrastColor),
      actions: [
        Stack(
          children: [
            _iconButton(
              Icons.notifications,
              () {
                setState(() {
                  _mostrarNotificacion = false;
                });
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationScreen()),
                );
              },
              contrastColor,
            ),
            if (_mostrarNotificacion)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
    body: Stack(
      children: [
        SizedBox.expand( 
          child: mp.MapWidget(
            onMapCreated: _onMapCreated,
            styleUri: 'mapbox://styles/mapbox/streets-v12',
          ),
        ),
        Positioned(
          top: screenHeight * 0.03,
          left: 16,
          child: Container(
            decoration: BoxDecoration(
              color: orangeTrans,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 7,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.family_restroom, size: 20),
              label: const Text("Círculo"),
              onPressed: _mostrarOpcionesCirculo,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                foregroundColor: contrastColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                textStyle: const TextStyle(fontSize: 14),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                elevation: 0,
              ),
            ),
          ),
        ),
        Positioned(
          top: screenHeight * 0.03,
          right: 16,
          child: Container(
            decoration: BoxDecoration(
              color: orangeTrans,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 7,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.watch, size: 20),
              label: const Text("Dispositivo"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AgregarDispositivoScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                foregroundColor: contrastColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                textStyle: const TextStyle(fontSize: 14),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                elevation: 0,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 37,
          left: 25,
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  spreadRadius: 2,
                  blurRadius: 7,
                  offset: const Offset(0, 7),
                ),
              ],
              shape: BoxShape.circle,
            ),
            child: RawMaterialButton(
              onPressed: () => _mostrarModalReporteHistorico(context),
              fillColor: orangeTrans,
              shape: const CircleBorder(),
              constraints: const BoxConstraints.tightFor(
                width: 110,
                height: 110,
              ),
              elevation: 0,
              child: const Text(
                'Reporte',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
    floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    floatingActionButton: Padding(
      padding: const EdgeInsets.only(bottom: 20, right: 15),
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              spreadRadius: 2,
              blurRadius: 7,
              offset: const Offset(0, 7),
            ),
          ],
          shape: BoxShape.circle,
        ),
        child: RawMaterialButton(
          onPressed: () => _showSosModal(context),
          fillColor: Colors.red,
          shape: const CircleBorder(),
          constraints: const BoxConstraints.tightFor(
            width: 110,
            height: 110,
          ),
          elevation: 0,
          child: const Text(
            'SOS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
        ),
      ),
    ),
    bottomNavigationBar: BottomAppBar(
      color: greenColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [



            _bottomIcon(
  Icons.location_on,
  () async {
    await map.toggleSeguirUsuario(); // activa o desactiva seguimiento
    setState(() {}); // 🔁 actualiza color del ícono
  },
  map.seguirUsuario ? const Color(0xFFFF6C00) : Colors.white,
),



            _bottomIcon(Icons.family_restroom, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FamilyScreen()),
              );
            }, contrastColor),
            _bottomIcon(Icons.person, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserScreenCon()),
              );
            }, contrastColor),
            _bottomIcon(Icons.phone, () => _modalTelefono(context), contrastColor),
          ],
        ),
      ),
    ),
  );
}


Widget _iconButton(IconData icon, VoidCallback onPressed, Color color) {
  return IconButton(
    icon: Icon(icon, color: color, size: 45),
    onPressed: onPressed,
  );
}

Widget _bottomIcon(IconData icon, VoidCallback onPressed, Color color) {
  return IconButton(
    icon: Icon(icon, color: color, size: 45),
    onPressed: onPressed,
  );
}
}
