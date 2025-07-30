import 'dart:async';
import 'package:amsp/pages/crear_circulo_screen.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:async/async.dart';


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

class _HomePageState extends State<HomePage> {
  mp.MapboxMap? mapboxMapController;
  StreamSubscription? userPositionStream;
  mp.PointAnnotationManager? pointAnnotationManager;
  mp.CircleAnnotationManager? circleAnnotationManager;

  bool esCreadorFamilia = false;
  bool cargandoUsuario = true;

  String? circuloSeleccionadoId;
  String? circuloSeleccionadoNombre;

  Map<String, StreamSubscription<DocumentSnapshot>> miembrosListeners = {};
  Map<String, mp.PointAnnotation> marcadores = {};



  


  Stream<QuerySnapshot> _alertasStream() {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const Stream.empty();

  final ref = FirebaseFirestore.instance.collection('circulos');
  return ref.snapshots().asyncExpand((snapshot) {
    final userCircles = snapshot.docs.where((doc) {
      final miembros = doc.data()['miembros'] as List<dynamic>? ?? [];
      return miembros.any((m) => m['uid'] == uid);
    });

    final streams = userCircles.map((doc) {
      return ref
          .doc(doc.id)
          .collection('alertas')
          // Solo alertas recientes, opcional:
          .where('timestamp', isGreaterThan: DateTime.now().subtract(const Duration(minutes: 10)))
          .snapshots();
    });

    return StreamGroup.merge(streams);
  });
}

  bool _mostrarModalAlerta = false;
  String? _mensajeAlerta;


@override
void initState() {
  super.initState();
  cargarDatosUsuario();
  _setupPositionTraking();

  _alertasStream().listen((snapshot) async {
    if (!mounted) return;

    final uidActual = FirebaseAuth.instance.currentUser?.uid;
    if (uidActual == null) return;

    if (snapshot.docs.isNotEmpty) {
      final alerta = snapshot.docs.first.data() as Map<String, dynamic>;
      final uidEmisor = alerta['uid'];
      final nombreEmisor = alerta['name'] ?? 'Alguien';
      final mensaje = alerta['mensaje'] ?? '🚨 ¡$nombreEmisor ha enviado una alerta SOS!';

      // Depuración
      print('🔔 Nueva alerta recibida');
      print('👤 UID actual: $uidActual');
      print('📢 UID emisor: $uidEmisor');
      print('📝 Mensaje: $mensaje');

      if (uidEmisor == uidActual) {
        print('🚫 Alerta ignorada porque fue enviada por el mismo usuario.');
        return;
      }

      if (!_mostrarModalAlerta) {
        setState(() {
          _mostrarModalAlerta = true;
          _mensajeAlerta = mensaje;
        });

        _mostrarAlertaModal(mensaje);
      }
    }
  });
}



 void _mostrarAlertaModal(String mensaje) {
    showDialog(
      context: context,
      barrierDismissible: false, // No cerrar tocando fuera
      builder: (context) {
        return AlertDialog(
          title: const Text('🚨 Alerta SOS'),
          content: Text(mensaje),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _mostrarModalAlerta = false;
                });
                Navigator.of(context).pop();
              },
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }


  @override
  void dispose() {
    userPositionStream?.cancel();
    for (var sub in miembrosListeners.values) {
      sub.cancel();
    }
    miembrosListeners.clear();
    pointAnnotationManager?.deleteAll();
    super.dispose();
  }



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

      

      // Enviar ubicación actual del usuario
      try {
        gl.LocationPermission permission = await gl.Geolocator.checkPermission();
        if (permission == gl.LocationPermission.denied || permission == gl.LocationPermission.deniedForever) {
          permission = await gl.Geolocator.requestPermission();
        }
        final position = await gl.Geolocator.getCurrentPosition(
          desiredAccuracy: gl.LocationAccuracy.high,
        );

        await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
          'ubicacion': {
            'lat': position.latitude,
            'lng': position.longitude,
            'timestamp': FieldValue.serverTimestamp(),
          }
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

  Future<void> _limpiarEscuchasYMarcadores() async {
    for (var sub in miembrosListeners.values) {
      await sub.cancel();
    }
    miembrosListeners.clear();
    await pointAnnotationManager?.deleteAll();
    marcadores.clear();
  }

  void _escucharUbicacionesDelCirculo(String circleId) async {
    await _limpiarEscuchasYMarcadores();
    print("Escuchando ubicaciones para círculo: $circleId");

    final circleDoc = await FirebaseFirestore.instance.collection('circulos').doc(circleId).get();
    if (!circleDoc.exists) return;

    final miembros = circleDoc.data()?['miembros'] as List<dynamic>? ?? [];
    print('Miembros del círculo ($circleId): $miembros');

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

      final sub = FirebaseFirestore.instance
          .collection('ubicaciones')
          .doc(uid)
          .snapshots()
          .listen((snapshot) async {
        if (!snapshot.exists) return;

        final data = snapshot.data();
        final lat = data?['lat'] ?? data?['latitude'];
        final lng = data?['lng'] ?? data?['longitude'];
        if (lat == null || lng == null) return;

        final nuevaPosicion = mp.Point(coordinates: mp.Position(lng, lat));

        try {
          if (marcadores.containsKey(uid)) {
            await pointAnnotationManager!.delete(marcadores[uid]!);
            marcadores.remove(uid);
          }

          final nuevoMarcador = await pointAnnotationManager!.create(
            mp.PointAnnotationOptions(
              geometry: nuevaPosicion,
              iconImage: "marker",
              iconSize: 4,
              textField: name,
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
      });

      miembrosListeners[uid] = sub;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final uid = user.uid;
      final userLocDoc = await FirebaseFirestore.instance.collection('ubicaciones').doc(uid).get();
      if (userLocDoc.exists) {
        final data = userLocDoc.data();
        final lat = data?['lat'] ?? data?['latitude'];
        final lng = data?['lng'] ?? data?['longitude'];
        if (lat != null && lng != null) {
          final posUser = mp.Point(coordinates: mp.Position(lng, lat));

          if (marcadores.containsKey(uid)) {
            await pointAnnotationManager!.delete(marcadores[uid]!);
            marcadores.remove(uid);
          }

          final nuevoMarcador = await pointAnnotationManager!.create(
            mp.PointAnnotationOptions(
              geometry: posUser,
              iconImage: "marker-15",
              iconSize: 1.8,
              textField: "Tú",
              textOffset: [0, 1.5],
              textSize: 14,
              textHaloWidth: 1.5,
            ),
          );

          marcadores[uid] = nuevoMarcador;
        }
      }
    }
  }

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

void _onMapCreated(mp.MapboxMap controller) async {
  setState(() {
    mapboxMapController = controller;
  });

  await mapboxMapController?.location.updateSettings(
    mp.LocationComponentSettings(enabled: true),
  );

  pointAnnotationManager = await mapboxMapController!.annotations.createPointAnnotationManager();
  circleAnnotationManager = await mapboxMapController!.annotations.createCircleAnnotationManager();

  // Establece el ID del círculo si no está definido pero viene del widget
  if ((circuloSeleccionadoId == null || circuloSeleccionadoId!.isEmpty) &&
      widget.circleId != null &&
      widget.circleId!.isNotEmpty) {
    circuloSeleccionadoId = widget.circleId;
  }

  // Verifica que el ID no sea nulo ni vacío antes de llamar a Firestore
  if (circuloSeleccionadoId != null && circuloSeleccionadoId!.isNotEmpty) {
    _escucharUbicacionesDelCirculo(circuloSeleccionadoId!);
  } else {
    print('❗ No se ha seleccionado ningún círculo. No se puede escuchar ubicaciones.');
  }
}


Future<void> _setupPositionTraking() async {
  bool serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) return;

  gl.LocationPermission permission = await gl.Geolocator.checkPermission();
  if (permission == gl.LocationPermission.denied) {
    permission = await gl.Geolocator.requestPermission();
    if (permission == gl.LocationPermission.denied) return;
  }
  if (permission == gl.LocationPermission.deniedForever) return;

  userPositionStream = gl.Geolocator.getPositionStream(
    locationSettings: const gl.LocationSettings(
      accuracy: gl.LocationAccuracy.high,
      distanceFilter: 100,
    ),
  ).listen((gl.Position? position) {
    if (position != null) {
      final puntoUsuario = mp.Point(coordinates: mp.Position(position.longitude, position.latitude));
      if (circleAnnotationManager != null) {
        _crearCirculo(puntoUsuario);
      }
    }
  });
}

void _mostrarOpcionesFamilia() {
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
              "Opciones de Familia",
              style: theme.textTheme.titleLarge
                  ?.copyWith(color: contrastColor, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.group_add),
              label: const Text("Crear familia", style: TextStyle(color: Colors.black)),
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
              label: const Text("Unirse a una familia", style: TextStyle(color: Colors.black)),
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

void _mostrarFormularioAgregar(BuildContext context) {
  final _nombreController = TextEditingController();
  final _numeroController = TextEditingController();
  final userId = FirebaseAuth.instance.currentUser?.uid;

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Agregar Contacto"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _nombreController, decoration: const InputDecoration(labelText: "Nombre")),
          TextField(controller: _numeroController, decoration: const InputDecoration(labelText: "Número")),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancelar"),
        ),
        ElevatedButton(
          onPressed: () async {
            final nombre = _nombreController.text.trim();
            final numero = _numeroController.text.trim();
            if (nombre.isEmpty || numero.isEmpty) return;

            await FirebaseFirestore.instance
                .collection('usuarios')
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
  final _nombreController = TextEditingController(text: nombreActual);
  final _numeroController = TextEditingController(text: numeroActual);
  final userId = FirebaseAuth.instance.currentUser?.uid;

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Editar Contacto"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _nombreController, decoration: const InputDecoration(labelText: "Nombre")),
          TextField(controller: _numeroController, decoration: const InputDecoration(labelText: "Número")),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancelar"),
        ),
        ElevatedButton(
          onPressed: () async {
            await FirebaseFirestore.instance
                .collection('usuarios')
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
      .collection('usuarios')
      .doc(userId)
      .collection('contactos_emergencia')
      .doc(id)
      .delete();
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
            onPressed: () => _eliminarContacto(context, id),
          ),
        ],
      ),
      onTap: () => Navigator.pop(context),
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
                  .collection('usuarios')
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




@override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final greenColor = theme.primaryColor;
  final contrastColor = theme.appBarTheme.foregroundColor ?? Colors.white;
  final orangeColor = theme.colorScheme.secondary;
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
          StreamBuilder<QuerySnapshot>(
            stream: _alertasStream(),
            builder: (context, snapshot) {
              bool hayAlertas = false;
              if (snapshot.hasData) {
                hayAlertas = snapshot.data!.docs.isNotEmpty && _mostrarModalAlerta;
              }

              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    color: contrastColor,
                    onPressed: () {
                      setState(() {
                        _mostrarModalAlerta = false; // Se oculta la bolita si abren pantalla notificaciones
                      });
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificationScreen()),
                      );
                    },
                  ),
                  if (hayAlertas)
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
              );
            },
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
              label: const Text("Familia"),
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
      ],
    ),
    floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    floatingActionButton: Padding(
      padding: const EdgeInsets.only(bottom: 20, right: 20),
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
            _bottomIcon(Icons.location_on, () {}, contrastColor),
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
      icon: Icon(icon, color: color),
      onPressed: onPressed,
    );
  }

  Widget _bottomIcon(IconData icon, VoidCallback onPressed, Color color) {
    return IconButton(
      icon: Icon(icon, color: color, size: 30),
      onPressed: onPressed,
    );
  }




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
      posicion = null;
    } else {
      gl.LocationPermission permiso = await gl.Geolocator.checkPermission();
      if (permiso == gl.LocationPermission.denied || permiso == gl.LocationPermission.deniedForever) {
        permiso = await gl.Geolocator.requestPermission();
        if (permiso == gl.LocationPermission.denied || permiso == gl.LocationPermission.deniedForever) {
          print("Permiso de ubicación denegado");
          posicion = null;
        }
      }
      if (permiso != gl.LocationPermission.denied && permiso != gl.LocationPermission.deniedForever) {
        posicion = await gl.Geolocator.getCurrentPosition(desiredAccuracy: gl.LocationAccuracy.high);
      }
    }
  } catch (e) {
    print("Error al obtener ubicación: $e");
    posicion = null;
  }

  final circulos = await FirebaseFirestore.instance
      .collection('circulos')
      .where('miembrosUids', arrayContains: uid)
      .get();

  for (var doc in circulos.docs) {
    final circleId = doc.id;

    Map<String, dynamic> alertaData = {
      'mensaje': '🚨 ¡$nombre ha enviado una alerta SOS!',
      'uid': uid,
      'name': nombre,
      'phone': phone,
      'timestamp': FieldValue.serverTimestamp(),
    };

    if (posicion != null) {
      alertaData['ubicacion'] = {
        'lat': posicion.latitude,
        'lng': posicion.longitude,
      };
    }

    // Guardar la alerta
    await FirebaseFirestore.instance
        .collection('circulos')
        .doc(circleId)
        .collection('alertas')
        .add(alertaData);

    // Aquí se removió el código de enviar notificaciones push
  }
}

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
}