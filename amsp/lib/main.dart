import 'package:amsp/pages/home_page.dart';
import 'package:amsp/pages/inicio_sesion_screen.dart';
import 'package:amsp/pages/phone_number_screen.dart';
import 'package:amsp/pages/zona_riesgo_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:amsp/services/location_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await dotenv.load(fileName: ".env");

  final token = dotenv.env["MAPBOX_ACCESS_TOKEN"];
  if (token == null) {
    throw Exception("MAPBOX_ACCESS_TOKEN no encontrado");
  }
  MapboxOptions.setAccessToken(token);

  LocationService.startLocationUpdates(); // Solo esta llamada para la ubicación en stream

  runApp(const MainApp());
  print('Conexión a Firebase establecida');
}

Future<gl.Position?> getCurrentLocation() async {
  bool serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) return null;

  gl.LocationPermission permission = await gl.Geolocator.checkPermission();
  if (permission == gl.LocationPermission.denied) {
    permission = await gl.Geolocator.requestPermission();
    if (permission == gl.LocationPermission.denied) return null;
  }

  return await gl.Geolocator.getCurrentPosition(
    desiredAccuracy: gl.LocationAccuracy.high,
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF248448),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF248448),
          secondary: const Color(0xFFFF6C00),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF248448),
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
            backgroundColor: const Color(0xFF248448),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            textStyle: const TextStyle(fontSize: 14),
          ),
        ),
        bottomAppBarTheme: const BottomAppBarTheme(
          color: Color(0xFF248448),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.black),
        ),
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
      // No está autenticado, mostrar pantalla de inicio de sesión
      return  InicioSesion();
    } else {
      // Ya está autenticado, navegar a HomePage
      return const HomePage(circleId: null);
    }
  }
}
