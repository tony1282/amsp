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
    throw Exception("Token MAPBOX_ACCESS_TOKEN no encontrado");
  }
  MapboxOptions.setAccessToken(token);
  runApp(const MainApp());
  print('Conexión a Firebase establecida');
}


class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}
