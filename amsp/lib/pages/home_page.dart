import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'conf_screen.dart';
import 'family_screen.dart';
import 'notifications_screen.dart';
import 'user_screen_con.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'crear_familia_screen.dart';
import 'unirse_familia_screen.dart';
import 'agregar_dispositivo_screen.dart';  // Importa tu pantalla aquí

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const greenColor = Color(0xFF248448);
  static const contrastColor = Color.fromARGB(255, 255, 255, 255);

  mp.MapboxMap? mapboxMapController;
  StreamSubscription? userPositionStream;

  @override
  void initState() {
    super.initState();
    _setupPositionTraking();
  }

  @override
  void dispose() {
    userPositionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: greenColor,
        centerTitle: true,
        title: const Text(
          'AMSP',
          style: TextStyle(
            color: contrastColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        leading: _iconButton(Icons.settings, () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ConfScreen()));
        }),
        actions: [
          _iconButton(Icons.notifications, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen()));
          }),
        ],
      ),

      backgroundColor: Colors.white,
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
              style: ElevatedButton.styleFrom(
                backgroundColor: greenColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(fontSize: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: _mostrarOpcionesFamilia,
            ),
          ),
          Positioned(
            top: 30,
            right: 16,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.watch, size: 20),
              label: const Text("Dispositivo"),
              style: ElevatedButton.styleFrom(
                backgroundColor: greenColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(fontSize: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AgregarDispositivoScreen()));
              },
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
            backgroundColor: const Color.fromARGB(255, 255, 17, 0),
            onPressed: () => _showSosModal(context),
            shape: const CircleBorder(
              side: BorderSide(color: Colors.black, width: 3),
            ),
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
              _bottomIcon(Icons.location_on, () => print('Ubicación presionado')),
              _bottomIcon(Icons.family_restroom, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const FamilyScreen()));
              }),
              _bottomIcon(Icons.person, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const UserScreenCon()));
              }),
              _bottomIcon(Icons.phone, () => _modalTelefono(context)),
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
    bool serviceEnebled;
    gl.LocationPermission permission;
    serviceEnebled = await gl.Geolocator.isLocationServiceEnabled();
    if (!serviceEnebled) return Future.error('servicios de localizacion desactivados');

    permission = await gl.Geolocator.checkPermission();
    if (permission == gl.LocationPermission.denied) {
      permission = await gl.Geolocator.requestPermission();
      if (permission == gl.LocationPermission.denied) {
        return Future.error('servicios de localizacion denegados');
      }
    }

    if (permission == gl.LocationPermission.deniedForever) {
      return Future.error('servicios de localizacion denegados para siempre');
    }

    gl.LocationSettings locationSettings = gl.LocationSettings(
      accuracy: gl.LocationAccuracy.high,
      distanceFilter: 100,
    );

    userPositionStream?.cancel();
    userPositionStream = gl.Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (gl.Position? position) {
        if (position != null) {
          mapboxMapController?.setCamera(
            mp.CameraOptions(
              zoom: 10,
              center: mp.Point(
                coordinates: mp.Position(position.longitude, position.latitude),
              ),
            ),
          );
        }
      },
    );
  }

  void _mostrarOpcionesFamilia() {
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
              const Icon(Icons.family_restroom, size: 50, color: Colors.white),
              const SizedBox(height: 16),
              const Text(
                "Opciones de Familia",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.group_add),
                label: const Text("Crear familia"),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CrearFamiliaScreen()));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: greenColor,
                  side: const BorderSide(color: Colors.black, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text("Unirse a una familia"),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const UnirseAFamiliaScreen()));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: greenColor,
                  side: const BorderSide(color: Colors.black, width: 1.5),
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

  static Widget _iconButton(IconData icon, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, color: contrastColor),
      iconSize: 35,
      onPressed: onPressed,
    );
  }

  static Widget _bottomIcon(IconData icon, VoidCallback onPressed) {
    return _iconButton(icon, onPressed);
  }

  void _modalTelefono(BuildContext context) {
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
              Icon(Icons.phone, color: contrastColor, size: 35),
              const Text(
                'Contactos de Emergencia',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
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
        title: const Text('Contacto', style: TextStyle(color: Colors.black)),
        subtitle: Text(number, style: const TextStyle(color: Colors.black)),
        onTap: () => Navigator.pop(context),
      ),
    );
  }

  void _showSosModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color.fromARGB(255, 220, 7, 7),
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
              child: const Text(
                'Cerrar',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          ],
        );
      },
    );
  }
}
