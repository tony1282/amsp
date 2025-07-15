import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'conf_screen.dart';
import 'family_screen.dart';
import 'notifications_screen.dart';
import 'user_screen_con.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'crear_familia_screen.dart';
import 'unirse_familia_screen.dart';
import 'agregar_dispositivo_screen.dart';
import 'package:amsp/models/user_model.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  mp.MapboxMap? mapboxMapController;
  StreamSubscription? userPositionStream;

  bool esCreadorFamilia = false;
  bool cargandoUsuario = true;

  @override
  void initState() {
    super.initState();
    _setupPositionTraking();
    cargarDatosUsuario();
  }

  @override
  void dispose() {
    userPositionStream?.cancel();
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
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (doc.exists) {
        final userModel = UserModel.fromDocumentSnapshot(doc);
        setState(() {
          esCreadorFamilia = userModel.tipoUsuario == TipoUsuario.admin;
          cargandoUsuario = false;
        });
      } else {
        setState(() {
          esCreadorFamilia = false;
          cargandoUsuario = false;
        });
      }
    } catch (e) {
      print('Error cargando usuario: $e');
      setState(() {
        esCreadorFamilia = false;
        cargandoUsuario = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final greenColor = theme.primaryColor;
    final contrastColor = theme.appBarTheme.foregroundColor ?? Colors.white;
    final orangeColor = theme.colorScheme.secondary;

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
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ConfScreen()));
        }, contrastColor),
        actions: [
          _iconButton(Icons.notifications, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen()));
          }, contrastColor),
        ],
      ),
      body: Stack(
        children: [
          mp.MapWidget(
            onMapCreated: _onMapCreated,
            styleUri: mp.MapboxStyles.STANDARD,
          ),
          Positioned(
            top: 30,
            left: 16,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.family_restroom, size: 20),
              label: const Text("Familia"),
              onPressed: _mostrarOpcionesFamilia, 
              style: ElevatedButton.styleFrom(
                backgroundColor: greenColor,
                foregroundColor: contrastColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                textStyle: const TextStyle(fontSize: 14),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
          Positioned(
            top: 30,
            right: 16,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.watch, size: 20),
              label: const Text("Dispositivo"),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AgregarDispositivoScreen()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: greenColor,
                foregroundColor: contrastColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                textStyle: const TextStyle(fontSize: 14),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20, right: 20),
        child: SizedBox(
          width: 90,
          height: 90,
          child: FloatingActionButton(
            backgroundColor: Colors.red,
            onPressed: () => _showSosModal(context),
            shape: const CircleBorder(
              side: BorderSide(color: Colors.black, width: 3),
            ),
            child: const Text(
              'SOS',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
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
                if (esCreadorFamilia) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const FamilyScreen()));
                } else {
                  _mostrarOpcionesFamilia();
                }
              }, contrastColor),
              _bottomIcon(Icons.person, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const UserScreenCon()));
              }, contrastColor),
              _bottomIcon(Icons.phone, () => _modalTelefono(context), contrastColor),
            ],
          ),
        ),
      ),
    );
  }

  void _onMapCreated(mp.MapboxMap controller) {
    setState(() {
      mapboxMapController = controller;
    });
    mapboxMapController?.location.updateSettings(
      mp.LocationComponentSettings(enabled: true),
    );
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
      locationSettings: const gl.LocationSettings(accuracy: gl.LocationAccuracy.high, distanceFilter: 100),
    ).listen((gl.Position? position) {
      if (position != null) {
        mapboxMapController?.setCamera(
          mp.CameraOptions(
            zoom: 10,
            center: mp.Point(coordinates: mp.Position(position.longitude, position.latitude)),
          ),
        );
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
                style: theme.textTheme.titleLarge?.copyWith(color: contrastColor, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.group_add),
                label: const Text("Crear familia", style: TextStyle(color: Colors.black)),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const FamilyScreen()));
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
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const UnirseAFamiliaScreen()));
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

  static Widget _iconButton(IconData icon, VoidCallback onPressed, Color color) {
    return IconButton(
      icon: Icon(icon, color: color),
      iconSize: 35,
      onPressed: onPressed,
    );
  }

  static Widget _bottomIcon(IconData icon, VoidCallback onPressed, Color color) {
    return _iconButton(icon, onPressed, color);
  }

  void _modalTelefono(BuildContext context) {
    final theme = Theme.of(context);
    final greenColor = theme.primaryColor;
    final contrastColor = theme.appBarTheme.foregroundColor ?? Colors.white;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: greenColor,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.phone, size: 35, color: contrastColor),
              Text(
                'Contactos de Emergencia',
                style: theme.textTheme.titleLarge?.copyWith(color: contrastColor, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _contactTile('2471351234'),
              _contactTile('2471351234'),
            ],
          ),
        );
      },
    );
  }

  Widget _contactTile(String number) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF6C00), width: 2),
      ),
      child: ListTile(
        leading: const Icon(Icons.phone, color: Color(0xFFF47405)),
        title: const Text('Contacto'),
        subtitle: Text(number),
        onTap: () => Navigator.pop(context),
      ),
    );
  }

  void _showSosModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.red.shade700,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            '¡EMERGENCIA SOS!',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'Se ha activado la señal SOS.\nPor favor, mantén la calma y espera ayuda.',
            style: TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        );
      },
    );
  }
}
