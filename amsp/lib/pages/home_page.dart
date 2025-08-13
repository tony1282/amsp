import 'dart:async';
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
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:async/async.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:firebase_database/firebase_database.dart';


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

// Clase para calcular acelerómetro (valor de gravedad y su raíz cuadrada para detectar sacudidas)
class MiClase {
  late double valor;
  late double raiz;

  MiClase() {
    valor = 9.0;
    raiz = sqrt(valor); // raiz cuadrada para detectar cambios bruscos
  }
}
//

class _HomePageState extends State<HomePage> {
  mp.MapboxMap? mapboxMapController;
  StreamSubscription? userPositionStream;

  // Manejadores para anotaciones (marcadores) en el mapa
  mp.PointAnnotationManager? pointAnnotationManager;
  mp.CircleAnnotationManager? circleAnnotationManager;
  //

  //
  bool esCreadorFamilia = false;  // Para saber si el usuario es admin/creador de círculo
  bool cargandoUsuario = true;    // Estado para mostrar carga mientras se obtiene info usuario
  bool _mostrarNotificacion = true; // Para mostrar una notificación visual (bolita)
  bool _cargandoZonas = false;    // Estado para carga de zonas de riesgo
  bool _modalVisible = false;     // Control para modales
  bool _mostrarModalAlerta = false; // Control para mostrar modal SOS
  bool _dialogoAbierto = false; // para evitar que se abran muchos alert dialog
  //

  //
  StreamSubscription? _alertasSubscription;       // Suscripción para alertas en tiempo real
  StreamSubscription? _accelerometerSubscription; // Suscripción para sensor acelerómetro
  //

//
   final DatabaseReference _ref = FirebaseDatabase.instance.ref();
//

  //
  Map<String, dynamic>? _geojsonZonasRiesgo;  // GeoJSON para zonas de riesgo
  String? _ultimoMensajeMostrado;
  //

  //
  String? circuloSeleccionadoId;    // ID del círculo seleccionado para mostrar info
  String? circuloSeleccionadoNombre; // Nombre del círculo seleccionado
  //


//
String? _ultimoMensajeIot;
//

  //
  Map<String, StreamSubscription<DocumentSnapshot>> miembrosListeners = {}; // Listeners por miembro para ubicación
  Map<String, mp.PointAnnotation> marcadores = {}; // Marcadores en el mapa por UID
  //

  //
  Timestamp? _ultimoTimestampVisto; // Para controlar alertas nuevas y evitar duplicados
  //

  //
  DateTime _ultimaSacudida = DateTime.now().subtract(const Duration(seconds: 10)); // Para controlar tiempo entre sacudidas detectadas
  //

  //
  String? _mensajeAlerta;  // Mensaje de alerta actual
  final Set<String> _alertasMostradasIds = {};  // IDs de alertas ya mostradas para evitar repetir
  final Set<String> _alertasMostradas = {}; // ✅ Set para alertas ya mostradas
  //

  //
  List<String> codigosRiesgo = [];  // Lista de códigos para filtrar zonas de riesgo
  //

@override
void initState() {
  super.initState();

  // Primero obtener el mensaje actual sin mostrar diálogo
  _ref.child('mensaje').once().then((event) {
    final data = event.snapshot.value;
    if (data != null && data.toString().isNotEmpty) {
      _ultimoMensajeMostrado = data.toString(); // Guardamos el mensaje para no mostrar diálogo al iniciar
      setState(() {
        _ultimoMensajeIot = _ultimoMensajeMostrado;
      });
    }

    // Luego iniciar la escucha continua
    _escucharMensajesIot();
  });

  _escucharAlertasEnTiempoReal(); // Inicia la escucha de alertas SOS en tiempo real
  LocationService.startLocationUpdates(); // Inicia actualización de ubicación en background
  cargarDatosUsuario(); // Carga datos del usuario actual

  // Escuchar acelerómetro para detectar sacudidas fuertes
  _accelerometerSubscription = accelerometerEvents.listen((event) {
    final double aceleracion = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

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

  _setupPositionTraking();
}

  //
  @override
  void dispose() {
    userPositionStream?.cancel(); // Cancelar stream de posición usuario
    for (var sub in miembrosListeners.values) {
      sub.cancel(); // Cancelar escuchas de miembros
    }
    miembrosListeners.clear();
    pointAnnotationManager?.deleteAll(); // Eliminar todos los marcadores del mapa
    _accelerometerSubscription?.cancel(); // Cancelar escucha acelerómetro
    _alertasSubscription?.cancel();       // Cancelar escucha de alertas
    super.dispose();
  }
  //

  //
  // Cargar datos del usuario actual desde Firestore y obtener permiso/ubicación para actualizar Firestore
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
      // Obtener documento del usuario
      final docUser = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      // Convertir a modelo usuario
      final userModel = docUser.exists ? UserModel.fromDocumentSnapshot(docUser) : null;

      setState(() {
        // Definir si el usuario es creador/admin según su tipo
        esCreadorFamilia = userModel?.tipoUsuario == TipoUsuario.admin;
        cargandoUsuario = false;
      });

      // Obtener ubicación actual y actualizar en Firestore
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

  //
  // Obtener lista de círculos a los que pertenece o que creó el usuario
  Future<List<QueryDocumentSnapshot>> _getCirculosUsuario() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];

    // Obtener círculos creados por el usuario
    final circulosCreadosSnap = await FirebaseFirestore.instance
        .collection('circulos')
        .where('creador', isEqualTo: currentUser.uid)
        .get();

    // Obtener todos los círculos
    final circulosColeccion = await FirebaseFirestore.instance.collection('circulos').get();

    List<QueryDocumentSnapshot> circulosUsuario = [...circulosCreadosSnap.docs];

    // Agregar círculos donde el usuario es miembro (no creador)
    for (var doc in circulosColeccion.docs) {
      final data = doc.data();
      final rawMiembros = data['miembros'] ?? [];

      final miembros = (rawMiembros as List)
          .where((e) => e is Map<String, dynamic>)
          .cast<Map<String, dynamic>>();

      // Si el usuario está en la lista de miembros, agregar círculo a la lista
      if (miembros.any((m) => m['uid'] == currentUser.uid)) {
        if (!circulosUsuario.any((d) => d.id == doc.id)) {
          circulosUsuario.add(doc);
        }
      }
    }
    return circulosUsuario;
  }
  //

  //
  // Limpiar escuchas activas y eliminar todos los marcadores en el mapa
  Future<void> _limpiarEscuchasYMarcadores() async {
    for (var sub in miembrosListeners.values) {
      await sub.cancel();
    }
    miembrosListeners.clear();
    await pointAnnotationManager?.deleteAll();
    marcadores.clear();
  }
  //

  //
  // Crear un círculo en el mapa en una posición dada (usado para zonas o selecciones)
  Future<void> _crearCirculo(mp.Point posicion) async {
    if (circleAnnotationManager == null) {
      print("❌ circleAnnotationManager no está inicializado");
      return;
    }

    await circleAnnotationManager!.create(
      mp.CircleAnnotationOptions(
        geometry: posicion,
        circleRadius: 10,
        circleColor: 0xFF007AFF, // Azul sólido ARGB
        circleOpacity: 0.8,
      ),
    );
  }
  //
  
  //
  // Refrescar (recargar) las zonas de riesgo en el mapa, recargando el estilo actual
  Future<void> refrescarZonasTlaxcala(mp.MapboxMap mapboxMap) async {
    // Recargar el estilo actual (puedes usar el mismo que tenías)
    await mapboxMap.loadStyleURI('mapbox://styles/mapbox/streets-v12'); // o tu estilo personalizado

    // Esperar a que se cargue antes de agregar capas
    _mostrarGeoJsonTlaxcala(mapboxMap);
  }
  //


//
Future<void> _mostrarGeoJsonTlaxcala(mp.MapboxMap mapboxMap) async {
  print("Iniciando carga del GeoJSON...");

  // Cargar archivo GeoJSON desde assets
  final geoJsonData = await rootBundle.loadString('assets/geojson/tlaxcala_zonas.geojson');
  print("GeoJSON cargado, tamaño: ${geoJsonData.length} caracteres");

  try {
    // Agregar la fuente GeoJSON al estilo del mapa
    await mapboxMap.style.addSource(
      mp.GeoJsonSource(id: "tlaxcala-source", data: geoJsonData),
    );
    print("Fuente 'tlaxcala-source' agregada al mapa");
  } catch (e) {
    print("Error agregando fuente: $e");
  }

  // Definir filtro para mostrar solo polígonos con propiedad 'riesgo' igual a 'Alto'
  final filtroAlto = ['==', ['get', 'riesgo'], 'Alto'];
  print("Filtro para riesgo alto definido: $filtroAlto");

  // Crear capa de relleno con color rojo semitransparente para zonas de riesgo alto
  final fillLayerAlto = mp.FillLayer(
    id: "tlaxcala-layer-alto",
    sourceId: "tlaxcala-source",
    filter: filtroAlto,
    fillColor: 0x80FF0000, // rojo semitransparente
    fillOpacity: 0.5,
  );

  try {
    // Agregar la capa al mapa
    await mapboxMap.style.addLayer(fillLayerAlto);
    print("Capa de riesgo 'Alto' agregada al mapa");
  } catch (e) {
    print("Error agregando capa de riesgo: $e");
  }

  print("Proceso terminado");
}
//

//
Future<void> _setupPositionTraking() async {
  // Verificar si el servicio de ubicación está activo
  bool serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) return;

  // Verificar permisos de ubicación y solicitarlos si es necesario
  gl.LocationPermission permission = await gl.Geolocator.checkPermission();
  if (permission == gl.LocationPermission.denied) {
    permission = await gl.Geolocator.requestPermission();
    if (permission == gl.LocationPermission.denied) return;
  }
  if (permission == gl.LocationPermission.deniedForever) return;

  // Escuchar actualizaciones de posición con alta precisión y filtro de 100 metros
  userPositionStream = gl.Geolocator.getPositionStream(
    locationSettings: const gl.LocationSettings(
      accuracy: gl.LocationAccuracy.high,
      distanceFilter: 100,
    ),
  ).listen((gl.Position? position) {
    if (position != null) {
      // Crear punto con coordenadas recibidas
      final puntoUsuario = mp.Point(coordinates: mp.Position(position.longitude, position.latitude));
      if (circleAnnotationManager != null) {
        // Crear círculo en el mapa en la posición actual
        _crearCirculo(puntoUsuario);
      }
    }
  });
}
//

//
Future<void> _mostrarModalSeleccionCirculo() async {
  // Obtener los círculos del usuario
  final circulos = await _getCirculosUsuario();

  if (!mounted) return;

  // Mostrar modal tipo bottom sheet para selección de círculo
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
                              // Al seleccionar un círculo, actualizar estado y cerrar modal
                              setState(() {
                                circuloSeleccionadoId = doc.id;
                                circuloSeleccionadoNombre = nombre;
                              });
                              Navigator.pop(context);
                              // Iniciar escucha de ubicaciones de los miembros del círculo
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
//

//
Future<void> _modalTelefono(BuildContext context) async {
  final theme = Theme.of(context);
  final greenColor = theme.primaryColor;
  final contrastColor = theme.appBarTheme.foregroundColor ?? Colors.white;
  final userId = FirebaseAuth.instance.currentUser?.uid;

  // Mostrar modal con lista de contactos de emergencia
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
              // Escuchar contactos de emergencia en tiempo real
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
              // Botón para agregar nuevo contacto
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
//

//
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

  // Obtener los círculos del usuario
  final circulos = await FirebaseFirestore.instance
      .collection('circulos')
      .where('miembrosUids', arrayContains: uid)
      .get();

  WriteBatch batch = FirebaseFirestore.instance.batch();

for (var doc in circulos.docs) {
  final circleId = doc.id;

  // Obtén la lista de UIDs de los miembros del círculo
  final miembrosUids = List<String>.from(doc.data()['miembrosUids'] ?? []);

  Map<String, dynamic> alertaData = {
    'circleId': circleId, // IMPORTANTE para identificar el círculo
    'mensaje': '¡$nombre ha enviado una alerta SOS!',
    'emisorId': uid,
    'name': nombre,
    'phone': phone,
    'timestamp': FieldValue.serverTimestamp(),
    'destinatarios': miembrosUids,  // <<-- aquí agregas la lista para filtrar rápido
  };

  if (posicion != null) {
    alertaData['ubicacion'] = {
      'lat': posicion.latitude,
      'lng': posicion.longitude,
    };
  }

  // Guardar en colección global
  final alertaRef = FirebaseFirestore.instance.collection('alertasCirculos').doc();
  batch.set(alertaRef, alertaData);
}

  await batch.commit();
}




//
void _escucharMensajesIot() {
  _ref.child('mensaje').onValue.listen((event) {
    final data = event.snapshot.value;
    if (data != null && data.toString().isNotEmpty) {
      final nuevoMensaje = data.toString();

      // Actualizamos variable del último mensaje recibido siempre
      setState(() {
        _ultimoMensajeIot = nuevoMensaje;
      });

      // Mostrar diálogo solo si el mensaje es diferente al último mostrado
      if (_ultimoMensajeMostrado != nuevoMensaje) {
        _mostrarDialogoMensajeIot(nuevoMensaje);
        _ultimoMensajeMostrado = nuevoMensaje;  // Guardamos el mensaje que mostramos
      }
    }
  });
}
//

//

  void _mostrarDialogoMensajeIot(String mensaje) async {
  if (_dialogoAbierto) return; // Si ya hay un diálogo abierto, no abrir otro
  _dialogoAbierto = true;

  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.red.shade700,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Alerta IoT',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
      content: Text(
        mensaje,
        style: const TextStyle(color: Colors.white, fontSize: 18),
        textAlign: TextAlign.center,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cerrar',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        )
      ],
    ),
  );

  _dialogoAbierto = false; // Se cerró el diálogo, puede abrirse otro ahora
}


//






void _escucharUbicacionesDelCirculo(String circleId) async {
  // Limpiar escuchas y marcadores previos
  await _limpiarEscuchasYMarcadores();
  print("Escuchando ubicaciones para círculo: $circleId");

  // Obtener documento del círculo
  final circleDoc = await FirebaseFirestore.instance.collection('circulos').doc(circleId).get();
  if (!circleDoc.exists) return;

  // Obtener lista de miembros (UIDs o mapas con datos)
  final miembros = circleDoc.data()?['miembros'] as List<dynamic>? ?? [];
  print('Miembros del círculo ($circleId): $miembros');

  // Función auxiliar para crear o actualizar marcador
  Future<void> _actualizarMarcador(String uid, double lat, double lng, String nombre) async {
    final posicion = mp.Point(coordinates: mp.Position(lng, lat));
    try {
      if (marcadores.containsKey(uid)) {
        await pointAnnotationManager!.delete(marcadores[uid]!);
        marcadores.remove(uid);
      }
      final nuevoMarcador = await pointAnnotationManager!.create(
        mp.PointAnnotationOptions(
          geometry: posicion,
          iconImage: "marker",
          iconSize: 4,
          textField: nombre,
          textOffset: [0, 3.5],
          textSize: 13,
          textHaloWidth: 1.0,
        ),
      );
      marcadores[uid] = nuevoMarcador;
      print('✅ Marcador actualizado para $uid ($lat, $lng)');
    } catch (e) {
      print("❌ Error al crear marcador para $uid: $e");
    }
  }

  // Escuchar ubicación de cada miembro sin bloquear el loop con await
  for (final member in miembros) {
    String uid;
    String name = 'Sin nombre';

    if (member is String) {
      uid = member;
      print("🧩 Miembro con solo UID: $uid");
    } else if (member is Map<String, dynamic>) {
      uid = member['uid'];
      name = member['name'] ?? 'Sin nombre';
      print("🧩 Miembro con datos: $uid, nombre: $name");
    } else {
      print("⚠️ Formato desconocido: $member");
      continue;
    }

    // Guardar la suscripción, que se maneja fuera con _limpiarEscuchasYMarcadores
    final sub = FirebaseFirestore.instance
        .collection('ubicaciones')
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) return;
      final data = snapshot.data();
      final lat = data?['lat'] ?? data?['latitude'];
      final lng = data?['lng'] ?? data?['longitude'];
      if (lat == null || lng == null) return;

      // Actualizar marcador async sin bloquear el stream
      _actualizarMarcador(uid, lat, lng, name);
    });

    miembrosListeners[uid] = sub;
  }

  // Agregar marcador para usuario autenticado, sin esperar (más rápido)
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    final uid = user.uid;
    final userLocDoc = await FirebaseFirestore.instance.collection('ubicaciones').doc(uid).get();
    if (userLocDoc.exists) {
      final data = userLocDoc.data();
      final lat = data?['lat'] ?? data?['latitude'];
      final lng = data?['lng'] ?? data?['longitude'];
      if (lat != null && lng != null) {
        // Reutilizar la función para crear marcador de usuario
        await _actualizarMarcador(uid, lat, lng, "Tú");
      }
    }
  }
}

//
void _abrirZonasRiesgo() async {
  // Navegar a pantalla para seleccionar códigos de zonas de riesgo
  final codigos = await Navigator.push<List<String>>(
    context,
    MaterialPageRoute(builder: (context) => ZonasRiesgoScreen()),
  );

  if (codigos != null) {
    // Guardar los códigos seleccionados en el estado
    setState(() {
      codigosRiesgo = codigos;
    });

    // Pintar las zonas en el mapa si el controlador está disponible
    if (mapboxMapController != null) {
      await _mostrarGeoJsonTlaxcala(mapboxMapController!);
    }
  }
}
//

//
void _escucharAlertasEnTiempoReal() {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  // Escuchar en tiempo real las alertas en todas las subcolecciones 'alertas'
  _alertasSubscription = FirebaseFirestore.instance
      .collectionGroup('alertas')
      .orderBy('timestamp', descending: true)
      .snapshots()
      .listen((snapshot) {
    if (snapshot.docs.isEmpty) return;

    final alerta = snapshot.docs.first;
    final emisorId = alerta['emisorid'];
    final timestamp = alerta['timestamp'] as Timestamp;

    // Mostrar notificación solo si la alerta es nueva y no es del usuario actual
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

//
void _onMapCreated(mp.MapboxMap controller) async {
  setState(() {
    mapboxMapController = controller;
  });

  // Navegar para obtener códigos de riesgo desde otra pantalla
  final resultado = await Navigator.push<List<String>>(
    context,
    MaterialPageRoute(builder: (_) => ZonasRiesgoScreen()),
  );

  if (resultado != null) {
    codigosRiesgo = resultado;
    await _mostrarGeoJsonTlaxcala(controller);
  }

  // Activar componente de ubicación en el mapa
  await controller.location.updateSettings(
    mp.LocationComponentSettings(enabled: true),
  );

  // Crear manejadores para anotaciones de puntos y círculos
  pointAnnotationManager = await controller.annotations.createPointAnnotationManager();
  circleAnnotationManager = await controller.annotations.createCircleAnnotationManager();

  // Si no hay círculo seleccionado, usar el que venga en widget.circleId
  if ((circuloSeleccionadoId == null || circuloSeleccionadoId!.isEmpty) &&
      widget.circleId != null &&
      widget.circleId!.isNotEmpty) {
    circuloSeleccionadoId = widget.circleId;
  }

  // Escuchar ubicaciones del círculo seleccionado si existe
  if (circuloSeleccionadoId != null && circuloSeleccionadoId!.isNotEmpty) {
    _escucharUbicacionesDelCirculo(circuloSeleccionadoId!);
  } else {
    print('❗ No se ha seleccionado ningún círculo. No se puede escuchar ubicaciones.');
  }
}
//

//
void _mostrarOpcionesFamilia() {
  final theme = Theme.of(context);
  final greenColor = theme.primaryColor;
  final contrastColor = theme.appBarTheme.foregroundColor ?? Colors.white;
  final orangeColor = theme.colorScheme.secondary;

  // Mostrar modal bottom sheet con opciones relacionadas a la familia/círculo
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

//
void _mostrarFormularioAgregar(BuildContext context) {
  // Controladores para inputs de nombre y número
  final theme = Theme.of(context);
  final greenColor = theme.primaryColor;
  final _nombreController = TextEditingController();
  final _numeroController = TextEditingController();
  final userId = FirebaseAuth.instance.currentUser?.uid;
  

  // Mostrar diálogo para agregar contacto
  showDialog(
    
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: greenColor, // Fondo verde
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
            backgroundColor: Colors.white, // Botón blanco
            foregroundColor: greenColor, // Texto verde
          ),
          onPressed: () async {
            final nombre = _nombreController.text.trim();
            final numero = _numeroController.text.trim();
            if (nombre.isEmpty || numero.isEmpty) return;

            // Guardar contacto en Firestore
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
//

//
void _editarContacto(BuildContext context, String id, String nombreActual, String numeroActual) {
  // Controladores inicializados con datos actuales del contacto
  final theme = Theme.of(context);
  final greenColor = theme.primaryColor;
  final _nombreController = TextEditingController(text: nombreActual);
  final _numeroController = TextEditingController(text: numeroActual);
  final userId = FirebaseAuth.instance.currentUser?.uid;

  // Mostrar diálogo para editar contacto
showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: greenColor, // Fondo verde
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
            backgroundColor: Colors.white, // Botón blanco
            foregroundColor: greenColor, // Texto verde
          ),
          onPressed: () async {
            // Actualizar contacto en Firestore
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
//

//
void _eliminarContacto(BuildContext context, String id) async {
  final userId = FirebaseAuth.instance.currentUser?.uid;

  // Eliminar contacto en Firestore
  await FirebaseFirestore.instance
      .collection('contactos')
      .doc(userId)
      .collection('contactos_emergencia')
      .doc(id)
      .delete();
}

Future<void> _llamarNumero(BuildContext context, String numero) async {
  // Construir URI para llamada telefónica
  final Uri telUri = Uri(scheme: 'tel', path: numero);

  try {
    // Intentar lanzar la llamada
    if (await canLaunchUrl(telUri)) {
      await launchUrl(telUri);
    } else {
      // Mostrar mensaje si no es posible llamar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se puede llamar a $numero')),
      );
    }
  } catch (e) {
    // Mostrar error en snackbar si falla la llamada
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al intentar llamar: $e')),
    );
  }
}

//
void _mostrarModalReporteHistorico(BuildContext context) {
  final TextEditingController descripcionController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;

  // Mostrar un modal bottom sheet para capturar un nuevo reporte histórico
showModalBottomSheet(
  context: context,
  isScrollControlled: true, // Permite que el modal se ajuste con el teclado
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
  ),
  builder: (context) {
    final mediaQuery = MediaQuery.of(context);
    final theme = Theme.of(context);
    final greenColor = theme.primaryColor;
    final orangeColor = theme.colorScheme.secondary;
    return Container(
      color: greenColor, // Fondo verde para todo el modal
      child: Padding(
        // Ajustar padding inferior para evitar solapamiento con teclado y dar espacio
        padding: EdgeInsets.only(
          bottom: mediaQuery.viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Ajustar tamaño vertical al contenido
          children: [
            Text(
            'Reporte',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            ),
          ),
            const SizedBox(height: 15),
            // Campo de texto para descripción del reporte
            TextField(
              controller: descripcionController,
              maxLines: 5,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white, // fondo blanco para el TextField
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: orangeColor), // borde naranja
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: orangeColor, width: 2), // borde naranja más grueso al enfocar
                ),
                labelText: 'Descripción',
                hintText: 'Escribe aquí la descripción del reporte...',
              ),
            ),
            const SizedBox(height: 15),
            // Botón para guardar el reporte
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white, // fondo blanco
              ),
              onPressed: () async {
                final descripcion = descripcionController.text.trim();

                // Validar que la descripción no esté vacía
                if (descripcion.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('La descripción no puede estar vacía')),
                  );
                  return;
                }

                // Si no hay usuario autenticado, cerrar modal
                if (user == null) {
                  Navigator.pop(context);
                  return;
                }

                // Obtener nombre del usuario desde Firestore
                final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                final nombre = userDoc.data()?['name'] ?? 'Amsp';

                // Intentar obtener la ubicación actual con permisos
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

                // Construir mapa con datos del reporte a guardar
                Map<String, dynamic> reporteData = {
                  'mensaje': descripcion,
                  'name': nombre,
                  'timestamp': FieldValue.serverTimestamp(),
                  'uid': user.uid,
                };

                // Agregar ubicación si está disponible
                if (posicion != null) {
                  reporteData['ubicacion'] = {
                    'lat': posicion.latitude,
                    'lng': posicion.longitude,
                  };
                }

                // Guardar el reporte en la subcolección reportes_historicos del usuario
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('reportes_historicos')
                    .add(reporteData);

                // Cerrar modal
                Navigator.pop(context);

                // Mostrar confirmación al usuario
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reporte histórico guardado')),
                );
              },
              child: Text(
                'Guardar reporte',
                style: TextStyle(color: greenColor), // texto verde
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

//
void _showSosModal(BuildContext context) {
  int countdown = 5; // Cuenta regresiva en segundos
  Timer? timer;

  // Mostrar un diálogo que no se puede cerrar tocando fuera
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      // Usar StatefulBuilder para poder actualizar estado local (countdown)
      return StatefulBuilder(
        builder: (context, setState) {
          // Inicializar temporizador solo una vez
          if (timer == null) {
            timer = Timer.periodic(const Duration(seconds: 1), (t) {
              if (countdown == 1) {
                t.cancel(); // Detener temporizador cuando llegue a 1
                Navigator.of(context).pop(); // Cerrar diálogo
                _enviarAlerta(); // Enviar alerta SOS
              } else {
                setState(() {
                  countdown--; // Reducir contador cada segundo
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
              // Botón para cancelar la alerta y cerrar el diálogo
              TextButton(
                onPressed: () {
                  timer?.cancel(); // Cancelar temporizador
                  Navigator.of(context).pop(); // Cerrar diálogo
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
    timer?.cancel(); // Asegurar que el temporizador se cancela al cerrar el diálogo
  });
}
//

//
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
          // Botón para editar contacto
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.black),
            onPressed: () => _editarContacto(context, id, nombre, numero),
          ),
          // Botón para eliminar contacto
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.black),
            onPressed: () => _eliminarContacto(context, id),
          ),
        ],
      ),
      // Al pulsar la fila, se realiza llamada al número
      onTap: () {
        _llamarNumero(context, numero);
      },
    ),
  );
}
//

//
@override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final greenColor = theme.primaryColor;
  final contrastColor = theme.appBarTheme.foregroundColor ?? Colors.white;
  final orangeColor = theme.colorScheme.secondary;
  final orangeTrans = const Color.fromARGB(221, 255, 120, 23);

  // Mostrar indicador de carga mientras se obtiene info del usuario
  if (cargandoUsuario) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }

  return Scaffold(
    appBar: AppBar(
      centerTitle: true,
      title: const Text('AMSP'),
      // Botón de configuración a la izquierda
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
            Icons.notifications,() {
            setState(() {
            _mostrarNotificacion = false; // Oculta indicador al abrir notificaciones
            });
            Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationScreen()),
            );
          },
        contrastColor,
        ),

            // Pequeño círculo rojo indicador de notificaciones
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
    // Cuerpo con mapa y botones posicionados
    body: Stack(
      children: [
        // Widget del mapa de Mapbox
        mp.MapWidget(
          onMapCreated: _onMapCreated,
          styleUri: 'mapbox://styles/mapbox/streets-v12',
        ),
        // Botón Familia arriba a la izquierda
        Positioned(
          top: 35,
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
              onPressed: _mostrarOpcionesFamilia,
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
        // Botón Dispositivo arriba a la derecha
        Positioned(
          top: 35,
          right: 9,
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

        // Botón de reporte histórico abajo a la izquierda
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
              fillColor: orangeTrans, // Color para diferenciar botón
              shape: const CircleBorder(),
              constraints: const BoxConstraints.tightFor(
                width: 90,
                height: 90,
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
    // Botón flotante SOS abajo a la derecha
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
            width: 90,
            height: 90,
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
    //
    // Barra de navegación inferior con íconos
    bottomNavigationBar: BottomAppBar(
      color: greenColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Icono para abrir zonas de riesgo
            _bottomIcon(Icons.location_on, () async {
              _abrirZonasRiesgo();
            }, contrastColor),
            // Icono para pantalla familia
            _bottomIcon(Icons.family_restroom, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FamilyScreen()),
              );
            }, contrastColor),
            // Icono para pantalla usuario
            _bottomIcon(Icons.person, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserScreenCon()),
              );
            }, contrastColor),
            // Icono para modal teléfono/contactos emergencia
            _bottomIcon(Icons.phone, () => _modalTelefono(context), contrastColor),
          ],
        ),
      ),
    ),
  );
}
//

//
Widget _iconButton(IconData icon, VoidCallback onPressed, Color color) {
  return IconButton(
    icon: Icon(icon, color: color, size: 40),
    onPressed: onPressed,
  );
}
//

//
Widget _bottomIcon(IconData icon, VoidCallback onPressed, Color color) {
  return IconButton(
    icon: Icon(icon, color: color, size: 40),
    onPressed: onPressed,
  );
}
//
}
