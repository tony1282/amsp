import 'package:flutter/material.dart';

class ConfScreen extends StatelessWidget {
  const ConfScreen({super.key});

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
            color: Color.fromARGB(255, 255, 255, 255),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Familia',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10,),
            ..._buildButtonList([
              'Notificaciones',
              'Compartir Ubicación',
              'Administrar Familia',
            ]),
            const SizedBox(height: 20),
            const Text(
              'Configuración',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            ..._buildButtonList([
              'Cuenta',
              'Privacidad',
              'Seguridad',
              'Acerca de',
              'Soporte',
              'Ayuda',
            ]),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  // Acción para cerrar sesión
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: orangeColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Colors.black, width: 2), // ← borde negro
                  ),
                ),
                child: const Text(
                  'Cerrar sesión',
                  style: TextStyle(color: Color.fromARGB(255, 255, 255, 255),  fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildButtonList(List<String> items) {
    return items.map((text) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        child: ElevatedButton(
          onPressed: () {
            // Acción para cada botón
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: orangeColor,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Colors.black, width: 2), // ← borde negro
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(fontSize: 16, color: Color.fromARGB(255, 255, 255, 255),  fontWeight: FontWeight.bold),
          ),
        ),
      );
    }).toList();
  }
}
