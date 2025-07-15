import 'package:flutter/material.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final contrastColor = theme.appBarTheme.foregroundColor ?? Colors.white;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        centerTitle: true,
        title: Text(
          'AMSP',
          style: theme.appBarTheme.titleTextStyle ??
              TextStyle(
                color: contrastColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
        ),
      ),
      backgroundColor: Colors.white,
      body: const SizedBox.shrink(), // Pantalla en blanco
      bottomNavigationBar: BottomAppBar(
        color: primaryColor,
        child: const SizedBox(height: 50), // Altura del BottomAppBar vacía
      ),
    );
  }
}
