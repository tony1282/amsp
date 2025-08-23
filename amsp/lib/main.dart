import 'package:amsp/pages/home_page.dart';
import 'package:amsp/pages/inicio_sesion_screen.dart';
import 'package:amsp/pages/phone_number_screen.dart';
import 'package:amsp/pages/zona_riesgo_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:amsp/services/location_service.dart';

const Color kPrimaryColor = Color(0xFF248448);
const Color kSecondaryColor = Color(0xFFFF6C00);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppInitWrapper());
}

class AppInitWrapper extends StatefulWidget {
  const AppInitWrapper({super.key});

  @override
  State<AppInitWrapper> createState() => _AppInitWrapperState();
}

class _AppInitWrapperState extends State<AppInitWrapper> {
  late Future<void> _initializationFuture;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializationFuture = _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await Firebase.initializeApp();
      FirebaseDatabase.instance.setPersistenceEnabled(false);
      await dotenv.load(fileName: ".env");

      final token = dotenv.env["MAPBOX_ACCESS_TOKEN"];
      if (token == null) {
        throw Exception("MAPBOX_ACCESS_TOKEN no encontrado en .env");
      }
      MapboxOptions.setAccessToken(token);

      LocationService.startLocationUpdates();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Error al iniciar la app:\n$_error', textAlign: TextAlign.center),
          ),
        ),
      );
    }

    return FutureBuilder(
      future: _initializationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return const MainApp();
        } else if (snapshot.hasError) {
          return MaterialApp(
            home: Scaffold(
              body: Center(
                child: Text('Error al iniciar la app:\n${snapshot.error}', textAlign: TextAlign.center),
              ),
            ),
          );
        }
        // Mientras carga la inicialización, mostrar indicador
        return const MaterialApp(
          home: Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        );
      },
    );
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: kPrimaryColor,
        colorScheme: ColorScheme.fromSeed(seedColor: kPrimaryColor, secondary: kSecondaryColor),
        appBarTheme: const AppBarTheme(
          backgroundColor: kPrimaryColor,
          foregroundColor: Colors.white,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            textStyle: const TextStyle(fontSize: 14),
          ),
        ),
        bottomAppBarTheme: const BottomAppBarTheme(color: kPrimaryColor),
        textTheme: const TextTheme(bodyMedium: TextStyle(color: Colors.black)),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const InicioSesion();
    }
    return const HomePage(circleId: null);
  }
}

Future<gl.Position?> getCurrentLocation() async {
  final serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) return null;

  var permission = await gl.Geolocator.checkPermission();
  if (permission == gl.LocationPermission.denied) {
    permission = await gl.Geolocator.requestPermission();
    if (permission == gl.LocationPermission.denied) return null;
  }

  return await gl.Geolocator.getCurrentPosition(desiredAccuracy: gl.LocationAccuracy.high);
}
