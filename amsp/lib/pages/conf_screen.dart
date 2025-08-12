import 'package:flutter/material.dart';


import 'conf_ubication_screen.dart';
import 'conf_privacy_screen.dart';
import 'conf_security_screen.dart';
import 'conf_about_screen.dart';
import 'conf_support_screen.dart';
import 'conf_help_screen.dart';

class ConfScreen extends StatelessWidget {
  const ConfScreen({super.key});

  // Colores personalizados
  static const Color orangeColor = Color(0xFFF47405);
  static const Color backgroundColor = Color(0xFF248448);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: backgroundColor,
        centerTitle: true,
        title: const Text(
          'Configuración',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            ..._buildButtonList(context, [
              'Compartir Ubicación',
              'Privacidad',
              'Seguridad',
              'Acerca de',
              'Soporte',
              'Ayuda',
            ]),
            const SizedBox(height: 20),

            // Botón de cerrar sesión
            Center(
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Agregar lógica de cerrar sesión
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: orangeColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Cerrar sesión',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  List<Widget> _buildButtonList(BuildContext context, List<String> items) {
    return items.map((text) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        child: ElevatedButton(
          onPressed: () {
            switch (text) {
              case 'Compartir Ubicación':
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CompartirUbicacionScreen()));
                break;
              case 'Privacidad':
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacidadScreen()));
                break;
              case 'Seguridad':
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SeguridadScreen()));
                break;
              case 'Acerca de':
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AcercaDeScreen()));
                break;
              case 'Soporte':
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SoporteScreen()));
                break;
              case 'Ayuda':
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AyudaScreen()));
                break;
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: orangeColor,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }).toList();
  }
}
