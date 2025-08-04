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

// Función principal que se ejecuta al iniciar la app
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Asegura la inicialización correcta de Flutter

  await Firebase.initializeApp(); // Inicializa Firebase en la app
  await dotenv.load(fileName: ".env"); // Carga variables de entorno desde el archivo .env

  final token = dotenv.env["MAPBOX_ACCESS_TOKEN"]; // Obtiene el token de Mapbox desde variables de entorno
  if (token == null) {
    throw Exception("MAPBOX_ACCESS_TOKEN no encontrado"); // Si no existe token, lanza un error
  }
  MapboxOptions.setAccessToken(token); // Configura el token para Mapbox

  LocationService.startLocationUpdates(); // Inicia la actualización continua de ubicación (stream)

  runApp(const MainApp()); // Ejecuta la app con el widget principal MainApp
  print('Conexión a Firebase establecida'); // Mensaje en consola para confirmar conexión a Firebase
}

// Función para obtener la ubicación actual del dispositivo
Future<gl.Position?> getCurrentLocation() async {
  bool serviceEnabled = await gl.Geolocator.isLocationServiceEnabled(); // Verifica si el servicio de ubicación está activo
  if (!serviceEnabled) return null; // Si no está activo, devuelve null

  // Revisa y solicita permisos de ubicación si es necesario
  gl.LocationPermission permission = await gl.Geolocator.checkPermission();
  if (permission == gl.LocationPermission.denied) {
    permission = await gl.Geolocator.requestPermission();
    if (permission == gl.LocationPermission.denied) return null; // Si sigue negado, devuelve null
  }

  // Retorna la posición actual con alta precisión
  return await gl.Geolocator.getCurrentPosition(
    desiredAccuracy: gl.LocationAccuracy.high,
  );
}

// Widget principal de la aplicación
class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Oculta la etiqueta de debug en la app
      theme: ThemeData(
        primaryColor: const Color(0xFF248448), // Color principal verde oscuro
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF248448),
          secondary: const Color(0xFFFF6C00), // Color secundario naranja
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF248448), // Color del AppBar
          foregroundColor: Colors.white, // Color del texto y iconos del AppBar
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF248448), // Color de fondo botones elevados
            foregroundColor: Colors.white, // Color del texto botones
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6), // Bordes redondeados
            ),
            textStyle: const TextStyle(fontSize: 14),
          ),
        ),
        bottomAppBarTheme: const BottomAppBarTheme(
          color: Color(0xFF248448), // Color del BottomAppBar
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.black), // Color por defecto para textos del cuerpo
        ),
      ),
      home: const AuthWrapper(), // Widget que decide si mostrar pantalla de login o Home
    );
  }
}

// Widget que determina si el usuario está autenticado o no
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser; // Obtiene el usuario autenticado actual

    if (user == null) {
      // Si no hay usuario autenticado, muestra la pantalla de inicio de sesión
      return  InicioSesion();
    } else {
      // Si el usuario está autenticado, muestra la pantalla principal (HomePage)
      return const HomePage(circleId: null);
    }
  }
}
