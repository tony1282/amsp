import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:amsp/pages/crear_circulo_screen.dart';
import 'package:amsp/pages/zona_riesgo_screen.dart';
import 'package:amsp/services/inegi_service.dart';
import 'package:amsp/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:url_launcher/url_launcher.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:audioplayers/audioplayers.dart';


// Importar pantallas
import 'conf_screen.dart';
import 'family_screen.dart';
import 'notifications_screen.dart';
import 'user_screen_con.dart';
import 'unirse_circulo_screen.dart';
import 'agregar_dispositivo_screen.dart';
import 'package:amsp/models/user_model.dart';



class HomePage extends StatefulWidget {
  final String? circleId;
  const HomePage({super.key, required this.circleId});

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




@override
void initState() {
  super.initState();
  LocationService.startLocationUpdates();
  cargarDatosUsuario();
  _escucharAlertasSmart();
  _escucharAlertasEnTiempoReal();

  _ultimoTimestampPorCirculo = {};
    Future.delayed(const Duration(seconds: 10), () {
    _escucharAlertasTodosCirculos();
  });


  _ref.onValue.listen((event) {
    final data = event.snapshot.value as Map<dynamic, dynamic>?;
    if (data != null) {
      final mensaje = data['mensaje']?.toString() ?? '';
      final lat = (data['latitud'] as num?)?.toDouble();
      final lng = (data['longitud'] as num?)?.toDouble();
      final timestamp = data['timestamp']?.toString() ?? "Sin fecha";

      if (lat != null && lng != null) {
        _mostrarAlertaEnMapa("Alerta IoT\n$timestamp", lat, lng);
      }
    }
  });

  _accelerometerSubscription = accelerometerEvents.listen((event) {
    final double aceleracion = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    if (aceleracion > 30) {
      final ahora = DateTime.now();
      if (ahora.difference(_ultimaSacudida).inSeconds > 10) {
        _ultimaSacudida = ahora;

        if (!_mostrarModalAlerta) {
          _showSosModal(context); 
        }
      }
    }
  });

  _setupPositionTracking();
}



  @override
  void dispose() {
    userPositionStream?.cancel();
    for (var sub in miembrosListeners.values) {
      sub.cancel();
    }
    _cancelarEscuchasAlertas();
    miembrosListeners.clear();
    pointAnnotationManager?.deleteAll();
    _accelerometerSubscription?.cancel();
    _alertasSubscription?.cancel();
    super.dispose();
  }



//  Datos del usuario
  Future<void> cargarDatosUsuario() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() {
        esCreadorFamilia = false;
        cargandoUsuario = false;
      });
      return;
    }

    try {
      final docUser = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final userModel = docUser.exists ? UserModel.fromDocumentSnapshot(docUser) : null;

      setState(() {
        esCreadorFamilia = userModel?.tipoUsuario == TipoUsuario.admin;
        cargandoUsuario = false;
      });

      try {
        gl.LocationPermission permission = await gl.Geolocator.checkPermission();
        if (permission == gl.LocationPermission.denied || permission == gl.LocationPermission.deniedForever) {
          permission = await gl.Geolocator.requestPermission();
        }
        final position = await gl.Geolocator.getCurrentPosition(
          desiredAccuracy: gl.LocationAccuracy.high,
        );

        await FirebaseFirestore.instance.collection('ubicaciones').doc(currentUser.uid).update({
          'lat': position.latitude,
          'lng': position.longitude,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print('Error al obtener/guardar ubicación: $e');
      }
    } catch (e) {
      print('Error cargando usuario: $e');
      setState(() {
        esCreadorFamilia = false;
        cargandoUsuario = false;
      });
    }
  }
//




// circulos del usuario
  Future<List<QueryDocumentSnapshot>> _getCirculosUsuario() async {
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


Future<void> _mostrarModalSeleccionCirculo() async {
  final circulos = await _getCirculosUsuario();

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
                            onTap: () {
                              setState(() {
                                circuloSeleccionadoId = doc.id;
                                circuloSeleccionadoNombre = nombre;
                                _seguirUsuario = false; 
                              });
                              Navigator.pop(context);
                              if (mapboxMapController != null) {
                                _escucharUbicacionesDelCirculo(doc.id);
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    },
  );
}



Future<void> _escucharUbicacionesDelCirculo(String circleId) async {
  await _limpiarEscuchasYMarcadores();
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

      _moverMarcadorFluido(uid, puntoNuevo, name);

      if (!_zoomAjustadoParaCirculo && mapboxMapController != null) {
        todasPosiciones[uid] = puntoNuevo;
        await _ajustarZoomParaTodos(todasPosiciones, forzar: true);
      }
    });

    miembrosListeners[uid] = sub;
  }
}





Future<void> _escucharAlertasTodosCirculos() async {
  print('Iniciando _escucharAlertasTodosCirculos');
  _cancelarEscuchasAlertas();
  _initialCircleFetched.clear();

  final currentUser = FirebaseAuth.instance.currentUser;
  print('currentUser: ${currentUser?.uid}');
  if (currentUser == null) return;

  final circulos = await _getCirculosUsuario();
  final circleIds = circulos.map((d) => d.id).toList();
  print('círculos encontrados: $circleIds');
  if (circleIds.isEmpty) return;

  for (var id in circleIds) {
    _ultimoTimestampPorCirculo.remove(id);
  }

  final query = FirebaseFirestore.instance
    .collection('alertasCirculos')
    .where('destinatarios', arrayContains: currentUser.uid)
    .where('circleId', whereIn: circleIds)
    .orderBy('timestamp', descending: true);

  print('   creando listener global (saltando primer snapshot)');
  final sub = query
    .snapshots()
    .skip(1)          
    .listen((snapshot) {
      print('snapshot recibe ${snapshot.docChanges.length} cambios');

      for (var change in snapshot.docChanges) {
        print('change.type=${change.type} docId=${change.doc.id}');
        if (change.type != DocumentChangeType.added) continue;

        final data = change.doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final circleId = data['circleId'] as String?;
        final emisor   = data['emisorId'] as String?;
        if (circleId == null || emisor == currentUser.uid) continue;

        final ts = data['timestamp'] as Timestamp?;
        if (ts == null) continue;

        final lastTs = _ultimoTimestampPorCirculo[circleId];
        if (lastTs != null &&
            ts.millisecondsSinceEpoch <= lastTs.millisecondsSinceEpoch) {
          continue;
        }

        _ultimoTimestampPorCirculo[circleId] = ts;
        _agregarAlerta(data);
      }
    }, onError: (e) {
      print('Error listener global: $e');
    });

  _alertSubs['global'] = sub;
}




final Queue<Map<String, dynamic>> _alertaQueue = Queue();

void _agregarAlerta(Map<String, dynamic> alerta) {
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
  _procesarAlertas();
}

void _procesarAlertas() async {
  if (_dialogoAbierto || _alertaQueue.isEmpty) return;

  final alerta = _alertaQueue.removeFirst();
  _dialogoAbierto = true;

  _seguirUsuario = false;

  await _player.stop();
  _player.setReleaseMode(ReleaseMode.loop);
  await _player.play(AssetSource('sounds/alert.mp3'));

  if (mapboxMapController != null) {
    await mapboxMapController!.flyTo(
      mp.CameraOptions(
        center: mp.Point(
          coordinates: mp.Position(
            alerta['ubicacion']['lng'],
            alerta['ubicacion']['lat'],
          ),
        ),
        zoom: 16.0,
      ),
      mp.MapAnimationOptions(duration: 1000),
    );
  }

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      backgroundColor: Colors.red,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: const [
          Icon(Icons.warning, color: Colors.white),
          SizedBox(width: 8),
          Text(
            "Alerta SOS",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ],
      ),
      content: Text(
        alerta['mensaje'],
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            "Cerrar",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  ).whenComplete(() async {
    _dialogoAbierto = false;
    await _player.stop();
    _procesarAlertas();
  });
}



  void _cancelarEscuchasAlertas() {
    for (var sub in _alertSubs.values) {
      sub.cancel();
    }
    _alertSubs.clear();
  }




Future<void> _moverMarcadorFluido(
    String uid, mp.Point destino, String name) async {
  final marcador = miembrosAnnotations[uid];
  final texto = miembrosTextAnnotations[uid];

  if (marcador == null || texto == null) {
    await _actualizarMarcadorMiembro(
      uid,
      destino.coordinates.lat.toDouble(),
      destino.coordinates.lng.toDouble(),
      name,
    );
    return;
  }

  final origen = marcador.geometry!;
  final frames = 30; 
  const frameDelay = Duration(milliseconds: 33);

  for (int i = 1; i <= frames; i++) {
    final t = i / frames;
    final lat = origen.coordinates.lat +
        (destino.coordinates.lat - origen.coordinates.lat) * t;
    final lng = origen.coordinates.lng +
        (destino.coordinates.lng - origen.coordinates.lng) * t;

    final puntoInterpolado = mp.Point(coordinates: mp.Position(lng, lat));
    marcador.geometry = puntoInterpolado;
    texto.geometry = puntoInterpolado;

    await pointAnnotationManager?.update(marcador);
    await pointAnnotationManager?.update(texto);

    await Future.delayed(frameDelay);
  }
}


Future<void> _actualizarMarcadorMiembro(
    String uid, double lat, double lng, String name) async {
  final punto = mp.Point(coordinates: mp.Position(lng, lat));

  if (miembrosAnnotations.containsKey(uid)) {
    miembrosAnnotations[uid]!.geometry = punto;
    await pointAnnotationManager?.update(miembrosAnnotations[uid]!);

    if (miembrosTextAnnotations.containsKey(uid)) {
      miembrosTextAnnotations[uid]!.geometry = punto;
      await pointAnnotationManager?.update(miembrosTextAnnotations[uid]!);
    }
  } else {
    final ByteData bytes = await rootBundle.load("assets/user.png");
    final Uint8List imageData = bytes.buffer.asUint8List();

    final annotation = await pointAnnotationManager?.create(
      mp.PointAnnotationOptions(
        geometry: punto,
        image: imageData,
        iconSize: 0.24,
        iconOffset: [0, -1],
      ),
    );
    miembrosAnnotations[uid] = annotation!;

    final textAnnotation = await pointAnnotationManager?.create(
      mp.PointAnnotationOptions(
        geometry: punto,
        textField: name,
        textSize: 18.0,
        textOffset: [0, 1.5],
        textColor: const Color.fromARGB(255, 0, 0, 0).value,
        textHaloColor: Colors.white.value,
        textHaloWidth: 3,
      ),
    );
    miembrosTextAnnotations[uid] = textAnnotation!;
  }
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

//



//Zonas de riesgo
Future<void> refrescarZonasTlaxcala(mp.MapboxMap mapboxMap) async {
  await mapboxMap.loadStyleURI('mapbox://styles/mapbox/streets-v12'); 
  _mostrarGeoJsonTlaxcala(mapboxMap);
}


Future<void> _mostrarGeoJsonTlaxcala(mp.MapboxMap mapboxMap) async {
  print("Iniciando carga del GeoJSON...");

  final geoJsonData = await rootBundle.loadString('assets/geojson/tlaxcala_zonas.geojson');
  print("GeoJSON cargado, tamaño: ${geoJsonData.length} caracteres");

  try {
    await mapboxMap.style.addSource(
      mp.GeoJsonSource(id: "tlaxcala-source", data: geoJsonData),
    );
    print("Fuente 'tlaxcala-source' agregada al mapa");
  } catch (e) {
    print("Error agregando fuente: $e");
  }

  final filtroAlto = ['==', ['get', 'riesgo'], 'Alto'];
  print("Filtro para riesgo alto definido: $filtroAlto");

  final fillLayerAlto = mp.FillLayer(
    id: "tlaxcala-layer-alto",
    sourceId: "tlaxcala-source",
    filter: filtroAlto,
    fillColor: 0x80FF0000, 
    fillOpacity: 0.5,
  );

  try {
    await mapboxMap.style.addLayer(fillLayerAlto);
    print("Capa de riesgo 'Alto' agregada al mapa");
  } catch (e) {
    print("Error agregando capa de riesgo: $e");
  }

  print("Proceso terminado");
}

void _abrirZonasRiesgo() async {
  final codigos = await Navigator.push<List<String>>(
    context,
    MaterialPageRoute(builder: (context) => ZonasRiesgoScreen()),
  );
  if (codigos != null) {
    setState(() {
      codigosRiesgo = codigos;
    });
    if (mapboxMapController != null) {
      await _mostrarGeoJsonTlaxcala(mapboxMapController!);
    }
  }
}
//



// Contactos de emergencia
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
                      contacto['nombre'],
                      contacto['numero'],
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
            final nombre = _nombreController.text.trim();
            final numero = _numeroController.text.trim();
            if (nombre.isEmpty || numero.isEmpty) return;

            await FirebaseFirestore.instance
                .collection('contactos')
                .doc(userId)
                .collection('contactos_emergencia')
                .add({
              'nombre': nombre,
              'numero': numero,
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
              'nombre': _nombreController.text.trim(),
              'numero': _numeroController.text.trim(),
            });
            Navigator.pop(context);
          },
          child: const Text("Actualizar"),
        ),
      ],
    ),
  );
}


void _eliminarContacto(BuildContext context, String id) async {
  final userId = FirebaseAuth.instance.currentUser?.uid;

  await FirebaseFirestore.instance
      .collection('contactos')
      .doc(userId)
      .collection('contactos_emergencia')
      .doc(id)
      .delete();
}

Future<void> _llamarNumero(BuildContext context, String numero) async {
  final Uri telUri = Uri(scheme: 'tel', path: numero);

  try {
    if (await canLaunchUrl(telUri)) {
      await launchUrl(telUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se puede llamar a $numero')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al intentar llamar: $e')),
    );
  }
}

//






// Alertas SOS
Future<void> _enviarAlerta() async {
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

  WriteBatch batch = FirebaseFirestore.instance.batch();

  for (var doc in circulos.docs) {
    final circleId = doc.id;

    final miembrosUids = List<String>.from(doc.data()['miembrosUids'] ?? []);

    Map<String, dynamic> alertaData = {
      'circleId': circleId,
      'mensaje': '¡$nombre ha enviado una alerta SOS!',
      'emisorId': uid,
      'name': nombre,
      'phone': phone,
      'timestamp': FieldValue.serverTimestamp(),
      'destinatarios': miembrosUids,
      'activa': true,
    };

    if (posicion != null) {
      alertaData['ubicacion'] = {
        'lat': posicion.latitude,
        'lng': posicion.longitude,
      };
    }

    final alertaRef = FirebaseFirestore.instance.collection('alertasCirculos').doc();
    batch.set(alertaRef, alertaData);
  }

  await batch.commit();
}

// alertas Smart e Iot
void _escucharAlertasSmart() {
  FirebaseFirestore.instance
      .collection('alertas')
      .orderBy('createdAt', descending: true)
      .limit(1) 
      .snapshots()
      .listen((snapshot) {
    if (snapshot.docs.isNotEmpty) {
      final doc = snapshot.docs.first;
      final data = doc.data();
      final lat = (data['lat'] as num?)?.toDouble();
      final lon = (data['lon'] as num?)?.toDouble();
      final mensaje = data['mensaje']?.toString() ?? "Alerta sin mensaje";
      final fecha = data['createdAt']?.toString() ?? "Sin fecha";

      if (lat != null && lon != null) {
        _mostrarAlertaEnMapa("Alerta SmartWatch\n¡$mensaje!", lat, lon);
      }
    }
  });
}


Future<void> irALaUltimaAlerta() async {
  try {
    final snapshot = await _ref.child('mensaje').get(); 
    final data = snapshot.value as Map<dynamic, dynamic>?;

    if (data != null) {
      final double? lat = (data['latitud'] as num?)?.toDouble();
      final double? lng = (data['longitud'] as num?)?.toDouble();
      final String timestamp = data['timestamp']?.toString() ?? "Sin fecha";

      if (lat != null && lng != null) {
        _mostrarAlertaEnMapa("Alerta IoT\n¡Estoy en peligro!", lat, lng);
      } else {
        print("No hay coordenadas disponibles en la última alerta");
      }
    }
  } catch (e) {
    print("Error al obtener última alerta: $e");
  }
}




void _mostrarAlertaEnMapa(String mensaje, double lat, double lng, {Timestamp? createdAt}) async {
  if (mapboxMapController == null) return;

  if (createdAt != null) {
    final ahora = DateTime.now();
    final alertaFecha = createdAt.toDate();
    final diferencia = ahora.difference(alertaFecha);
    if (diferencia.inSeconds >= 5) {
      final idAlerta = "$lat-$lng";
      if (alertasAnnotations.containsKey(idAlerta)) {
        await pointAnnotationManager?.delete(alertasAnnotations[idAlerta]!);
        alertasAnnotations.remove(idAlerta);
      }
      return;
    }
  }

  await mapboxMapController!.flyTo(
    mp.CameraOptions(
      center: mp.Point(coordinates: mp.Position(lng, lat)),
      zoom: 15.0,
    ),
    mp.MapAnimationOptions(duration: 1000),
  );

  if (pointAnnotationManager != null) {
    final idAlerta = "$lat-$lng";
    if (!alertasAnnotations.containsKey(idAlerta)) {
      final ByteData bytes = await rootBundle.load("assets/alert.png");
      final Uint8List imageData = bytes.buffer.asUint8List();

      final annotation = await pointAnnotationManager!.create(
        mp.PointAnnotationOptions(
          geometry: mp.Point(coordinates: mp.Position(lng, lat)),
          image: imageData,
          iconSize: 0.35,
          iconOffset: [0, -80],
          textField: mensaje,
          textSize: 14.0,
          textOffset: [0, 2.0],
          textColor: Colors.black.value,
          textHaloColor: Colors.white.value,
          textHaloWidth: 2,
        ),
      );
      alertasAnnotations[idAlerta] = annotation!;
    }
  }

  if (!_dialogoAbierto) {
    _dialogoAbierto = true;

    //
    _seguirUsuario = false;

    _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(AssetSource('sounds/alert.mp3'));

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.red,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning, color: Colors.white),
            SizedBox(width: 8),
            Text(
              "Alerta",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mensaje,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Ubicación: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}",
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _dialogoAbierto = false;
              _player.stop();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              "Cerrar",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}


void _escucharAlertasEnTiempoReal() {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  _alertasSubscription = FirebaseFirestore.instance
      .collectionGroup('alertas')
      .orderBy('timestamp', descending: true)
      .snapshots()
      .listen((snapshot) {
    if (snapshot.docs.isEmpty) return;

    final alerta = snapshot.docs.first;
    final emisorId = alerta['emisorid'];
    final timestamp = alerta['timestamp'] as Timestamp;

    if ((_ultimoTimestampVisto == null || timestamp.compareTo(_ultimoTimestampVisto!) > 0) &&
        emisorId != uid) {
      setState(() {
        _mostrarNotificacion = true;
        _ultimoTimestampVisto = timestamp;
      });
    }
  });
}
//


// Marcadores de ubicación
Future<void> _limpiarEscuchasYMarcadores() async {
  for (final sub in miembrosListeners.values) {
    await sub.cancel();
  }
  miembrosListeners.clear();

  if (pointAnnotationManager != null) {
    for (var entry in marcadores.entries) {
      await pointAnnotationManager!.delete(entry.value);
    }
  }

  marcadores.clear();
  _ultimoUpdateMarcador.clear();
}

Future<void> _ajustarZoomParaTodos(Map<String, mp.Point> posiciones, {bool forzar = false}) async {
  if (mapboxMapController == null || posiciones.isEmpty) return;

  if (_zoomAjustadoParaCirculo && !forzar) return;

  double minLat = double.infinity, maxLat = -double.infinity;
  double minLng = double.infinity, maxLng = -double.infinity;

  for (final punto in posiciones.values) {
    final lat = punto.coordinates.lat.toDouble();
    final lng = punto.coordinates.lng.toDouble();
    if (lat < minLat) minLat = lat;
    if (lat > maxLat) maxLat = lat;
    if (lng < minLng) minLng = lng;
    if (lng > maxLng) maxLng = lng;
  }

  final centerLat = (minLat + maxLat) / 2;
  final centerLng = (minLng + maxLng) / 2;

  final latDiff = maxLat - minLat;
  final lngDiff = maxLng - minLng;

  double zoom = 10 - ((latDiff + lngDiff) * 5);
  if (zoom < 3) zoom = 3;

  await mapboxMapController!.flyTo(
    mp.CameraOptions(
      center: mp.Point(coordinates: mp.Position(centerLng, centerLat)),
      zoom: zoom,
    ),
    mp.MapAnimationOptions(duration: 1000),
  );

  _zoomAjustadoParaCirculo = true; 
}
//





// Configuración del seguimiento de la posición del usuario


Future<void> _setupPositionTracking() async {
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

  // Mostrar puck azul
  await mapboxMapController?.location.updateSettings(
    mp.LocationComponentSettings(enabled: true, pulsingEnabled: true),
  );

  // Escuchar ubicación
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

    if (_seguirUsuario) {
      await mapboxMapController!.easeTo(
        mp.CameraOptions(center: puntoUsuario, zoom: 15.0),
        mp.MapAnimationOptions(duration: 500),
      );
    }
  });
}

void activarSeguimiento() {
  _seguirUsuario = true;
}

void desactivarSeguimiento() {
  _seguirUsuario = false;
}


//


// Inicialización del mapa y configuración de eventos
void _onMapCreated(mp.MapboxMap controller) async {
  setState(() {
    mapboxMapController = controller;
  });

  final resultado = await Navigator.push<List<String>>(
    context,
    MaterialPageRoute(builder: (_) => ZonasRiesgoScreen()),
  );

  if (resultado != null) {
    codigosRiesgo = resultado;
    await _mostrarGeoJsonTlaxcala(controller);
  }

  await controller.location.updateSettings(
    mp.LocationComponentSettings(enabled: true),
  );

  pointAnnotationManager = await controller.annotations.createPointAnnotationManager();
  circleAnnotationManager = await controller.annotations.createCircleAnnotationManager();

  if ((circuloSeleccionadoId == null || circuloSeleccionadoId!.isEmpty) &&
      widget.circleId != null &&
      widget.circleId!.isNotEmpty) {
    circuloSeleccionadoId = widget.circleId;
  }

  if (circuloSeleccionadoId != null && circuloSeleccionadoId!.isNotEmpty) {
    _escucharUbicacionesDelCirculo(circuloSeleccionadoId!);
  } else {
    print('No se ha seleccionado ningún círculo. No se puede escuchar ubicaciones!!!!');
  }
}
//


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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('La descripción no puede estar vacía')),
                  );
                  return;
                }

                if (user == null) {
                  Navigator.pop(context);
                  return;
                }

                final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                final nombre = userDoc.data()?['name'] ?? 'Amsp';

                gl.Position? posicion;
                try {
                  bool servicioActivo = await gl.Geolocator.isLocationServiceEnabled();
                  if (!servicioActivo) {
                    posicion = null;
                  } else {
                    gl.LocationPermission permiso = await gl.Geolocator.checkPermission();
                    if (permiso == gl.LocationPermission.denied || permiso == gl.LocationPermission.deniedForever) {
                      permiso = await gl.Geolocator.requestPermission();
                      if (permiso == gl.LocationPermission.denied || permiso == gl.LocationPermission.deniedForever) {
                        posicion = null;
                      }
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

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reporte histórico guardado')),
                );
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
//


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
                _enviarAlerta();
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
  });
}
//



// widget para mostrar un contacto de emergencia
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
            onPressed: () => _eliminarContacto(context, id),
          ),
        ],
      ),
      onTap: () {
        _llamarNumero(context, numero);
      },
    ),
  );
}
//



// Construcción del widget principal de la página de inicio
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
        mp.MapWidget(
          onMapCreated: _onMapCreated,
          styleUri: 'mapbox://styles/mapbox/streets-v12',
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
            _bottomIcon(Icons.location_on, () {
              setState(() {
                _seguirUsuario = !_seguirUsuario;
              });
            }, contrastColor),
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
//


}
