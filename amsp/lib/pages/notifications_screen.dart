import 'package:flutter/material.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  // Colores estáticos
  static const Color orangeColor = Color.fromARGB(255, 0, 0, 0);
  static const Color backgroundColor = Color(0xFF248448);
  static const Color bottomBarColor = Color(0xFF248448);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: backgroundColor,
        centerTitle: true,
        title: const Text(
          'AMSP',
          style: TextStyle(
            color: Color.fromARGB(255, 255, 255, 255),
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
      backgroundColor: Colors.white,
      body: const SizedBox.shrink(), // Pantalla en blanco
      bottomNavigationBar: BottomAppBar(
        color: bottomBarColor,
        child: const SizedBox(height: 50), // Altura del BottomAppBar vacía
      ),
    );
  }
}
