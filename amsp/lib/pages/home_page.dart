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
import 'package:url_launcher/url_launcher.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:firebase_database/firebase_database.dart';

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
  mp.Point? ultimaPosicion;


  Map<String, DateTime> _ultimoUpdateMarcador = {};
  Map<String, StreamSubscription<DocumentSnapshot>> miembrosListeners = {};
  Map<String, mp.PointAnnotation> marcadores = {}; 



  bool esCreadorFamilia = false;
  bool cargandoUsuario = true;
  bool _mostrarNotificacion = true;
  bool _mostrarModalAlerta = false;
  bool _dialogoAbierto = false;
  bool _primerZoomUsuario = true;

  StreamSubscription? _alertasSubscription;
  StreamSubscription? _accelerometerSubscription;

  final DatabaseReference _ref = FirebaseDatabase.instance.ref();


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



@override
void initState() {
  super.initState();
  _escucharAlertasSmart();
  _escucharAlertasEnTiempoReal(); 
  LocationService.startLocationUpdates(); 
  cargarDatosUsuario(); 


  _ref.child('').once().then((event) {
  final data = event.snapshot.value as Map?;
  if (data != null && data["mensaje"] != null) {
    _ultimoMensajeIot = data["mensaje"].toString();
  }
  irALaUltimaAlerta();
  });

  _ref.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        final lat = (data['latitud'] as num?)?.toDouble();
        final lng = (data['longitud'] as num?)?.toDouble();
        final timestamp = data['timestamp']?.toString() ?? "Sin fecha";
        if (lat != null && lng != null) {
          _mostrarAlertaEnMapa("Alerta IoT\n$timestamp", lat, lng);
        }
      }
    });



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

  _setupPositionTracking();
}




  @override
  void dispose() {
    userPositionStream?.cancel();
    for (var sub in miembrosListeners.values) {
      sub.cancel();
    }
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

 if (mapboxMapController != null) {
  await mapboxMapController!.flyTo(
    mp.CameraOptions(
 
      center: ultimaPosicion,
      zoom: 8.0, 
    ),
    mp.MapAnimationOptions(duration: 1000), 
  );
}

  final circleDoc = await FirebaseFirestore.instance
      .collection('circulos')
      .doc(circleId)
      .get();

  if (!circleDoc.exists) {
    print("El círculo no existe!!!!");
    return;
  }

  final miembros = circleDoc.data()?['miembros'] as List<dynamic>? ?? [];
  print('Miembros del círculo ($circleId): $miembros');

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
      print("Formato de miembro desconocido: $member!!!!!");
      continue;
    }

    if (user != null && uid == user.uid) {
      print("Omitiendo marcador del usuario actual");
      continue;
    }

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

      _actualizarMarcador(uid, lat, lng, name);
    });

    miembrosListeners[uid] = sub;
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
        _mostrarAlertaEnMapa("$mensaje\n$fecha", lat, lon);
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
        _mostrarAlertaEnMapa("Alerta IoT\n$timestamp", lat, lng);
      } else {
        print("No hay coordenadas disponibles en la última alerta");
      }
    }
  } catch (e) {
    print("Error al obtener última alerta: $e");
  }
}



void _mostrarAlertaEnMapa(String mensaje, double lat, double lng) async {
  if (mapboxMapController == null) return;

  await mapboxMapController!.flyTo(
    mp.CameraOptions(
      center: mp.Point(coordinates: mp.Position(lng, lat)),
      zoom: 15.0,
    ),
    mp.MapAnimationOptions(duration: 1000),
  );

  if (pointAnnotationManager != null) {
    await pointAnnotationManager!.create(
      mp.PointAnnotationOptions(
        geometry: mp.Point(coordinates: mp.Position(lng, lat)),
        iconImage: "marker",
        iconSize: 5.0,
        textField: mensaje,
        textOffset: [3, 3.0],
      ),
    );
  }

  if (!_dialogoAbierto) {
    _dialogoAbierto = true;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("⚠ Alerta IoT"),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _dialogoAbierto = false;
            },
            child: const Text("Cerrar"),
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
Future<void> _actualizarMarcador(
    String uid, double lat, double lng, String nombre) async {
  final ahora = DateTime.now();
  final ultimo = _ultimoUpdateMarcador[uid];
  if (ultimo != null && ahora.difference(ultimo).inMilliseconds < 500) {
    return; 
  }
  _ultimoUpdateMarcador[uid] = ahora;

  final posicion = mp.Point(coordinates: mp.Position(lng, lat));

  try {
    if (marcadores.containsKey(uid)) {
      final marcadorExistente = marcadores[uid]!;
      marcadorExistente.geometry = posicion;
      marcadorExistente.textField = nombre;
      await pointAnnotationManager!.update(marcadorExistente);
    } else {
      final nuevoMarcador = await pointAnnotationManager!.create(
        mp.PointAnnotationOptions(
          geometry: posicion,
          iconImage: "marker",
          iconSize: 4,
          textField: nombre,
          textOffset: [0, 3.0],
          textSize: 13,
          textHaloWidth: 1.0,
        ),
      );
      marcadores[uid] = nuevoMarcador;
    }
  } catch (e) {
    print("Error al actualizar marcador para $uid: $e");
  }
}



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

//





// Configuración del seguimiento de la posición del usuario
Future<void> _setupPositionTracking() async {
  print(" Iniciando seguimiento de ubicación...");

  final serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    print("⚠️ Servicio de ubicación desactivado");
    return;
  }

  var permission = await gl.Geolocator.checkPermission();
  if (permission == gl.LocationPermission.denied) {
    permission = await gl.Geolocator.requestPermission();
  }
  if (permission == gl.LocationPermission.denied ||
      permission == gl.LocationPermission.deniedForever) {
    print("🚫 Permiso de ubicación denegado");
    return;
  }

  userPositionStream = gl.Geolocator.getPositionStream(
    locationSettings: const gl.LocationSettings(
      accuracy: gl.LocationAccuracy.high,
      distanceFilter: 50,
    ),
  ).listen((gl.Position? position) {
    if (position == null) return;

    print("Nueva ubicación: ${position.latitude}, ${position.longitude}");

    final puntoUsuario = mp.Point(
      coordinates: mp.Position(position.longitude, position.latitude),
    );

    if (circleAnnotationManager != null) {
      _crearCirculoUsuario(puntoUsuario);
    }
  });
}



Future<void> _crearCirculoUsuario(mp.Point punto) async {
  if (_primerZoomUsuario && mapboxMapController != null) {
    await mapboxMapController!.flyTo(
      mp.CameraOptions(
        center: punto,
        zoom: 15.0, 
      ),
      mp.MapAnimationOptions(duration: 1000), 
    );
    _primerZoomUsuario = false;
  }

  if (usuarioAnnotation != null) {
    usuarioAnnotation!.geometry = punto;
    await pointAnnotationManager?.update(usuarioAnnotation!);

    if (usuarioTextoAnnotation != null) {
      usuarioTextoAnnotation!.geometry = punto;
      await pointAnnotationManager?.update(usuarioTextoAnnotation!);
    }
    return;
  }


  final ByteData bytes = await rootBundle.load("assets/user.png");
  final Uint8List imageData = bytes.buffer.asUint8List();

  usuarioAnnotation = await pointAnnotationManager?.create(
    mp.PointAnnotationOptions(
      geometry: punto,
      image: imageData,
      iconSize: 0.15,
    ),
  );

  usuarioTextoAnnotation = await pointAnnotationManager?.create(
    mp.PointAnnotationOptions(
      geometry: punto,
      textField: "Tú",
      textSize: 16.0,
      textOffset: [0, 2.0],
      textColor: Colors.black.value,
    ),
  );
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
    IconButton(
      icon: const Icon(Icons.location_pin),
      tooltip: 'Ir a la última alerta',
      onPressed: () async {
        await irALaUltimaAlerta();
      },
    ),

       IconButton(
      icon: const Icon(Icons.location_city_outlined),
      tooltip: 'Ir a la última alerta',
      onPressed: () async {
         _escucharAlertasSmart();
      },
    ),

      
        
        Stack(
          children: [
          _iconButton(
            Icons.notifications,() {
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
    bottomNavigationBar: BottomAppBar(
      color: greenColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _bottomIcon(Icons.location_on, () async {
              _abrirZonasRiesgo();
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

// widget para el botón de icono
Widget _iconButton(IconData icon, VoidCallback onPressed, Color color) {
  return IconButton(
    icon: Icon(icon, color: color, size: 40),
    onPressed: onPressed,
  );
}

Widget _bottomIcon(IconData icon, VoidCallback onPressed, Color color) {
  return IconButton(
    icon: Icon(icon, color: color, size: 40),
    onPressed: onPressed,
  );
}
//


}
