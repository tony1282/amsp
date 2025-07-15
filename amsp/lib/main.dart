import 'package:amsp/pages/home_page.dart';
import 'package:amsp/pages/number_screen.dart';
import 'package:amsp/pages/user_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await dotenv.load(fileName: ".env");
  final token = dotenv.env["MAPBOX_ACCESS_TOKEN"];
  if (token == null) {
    throw Exception("MAPBOX_ACCESS_TOKEN no encontrado");
  }
  MapboxOptions.setAccessToken(token);
  runApp(const MainApp());
  print('Conexión a Firebase establecida');
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

        // Barra inferior
        bottomAppBarTheme: const BottomAppBarTheme(
          color: Color(0xFF248448),  
        ),


        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.black),
        ),
      ),
      home: const InicioSesion(),
    );
  }
}
