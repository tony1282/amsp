import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final greenColor = theme.primaryColor; // Verde principal
    final orangeColor = theme.colorScheme.secondary; // Naranja
    final contrastColor = theme.appBarTheme.foregroundColor ?? Colors.white;

    final user = FirebaseAuth.instance.currentUser;
    final String? _fotoURL = user?.photoURL;


    return Scaffold(
      appBar: AppBar(
        backgroundColor: greenColor,
        centerTitle: true,
        title: Text(
          'AMSP',
          style: theme.appBarTheme.titleTextStyle?.copyWith(color: contrastColor) ??
              TextStyle(
                color: contrastColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
        ),
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: _fotoURL != null
                  ? CircleAvatar(
                      radius: 60,
                      backgroundImage: NetworkImage(_fotoURL),
                    )
                  : const CircleAvatar(radius: 60),
            ),
            ElevatedButton(
              onPressed: () {
                // Acción para agregar familiar
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: greenColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Agregar familiar',
                style: TextStyle(color: contrastColor, fontSize: 16),
              ),
            ),
            const SizedBox(height: 30),

            // Tarjeta verde
            Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              color: greenColor,
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  children: [
                    Text(
                      "Familia",
                      style: theme.textTheme.titleLarge?.copyWith(
                            color: contrastColor,
                            fontWeight: FontWeight.bold,
                          ) ??
                          TextStyle(
                            color: contrastColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 25),

                    // Lista de familiares con dos tarjetas cada uno
                    _buildFamilyDoubleCard("Usuario 1", "Protegido", orangeColor),
                    const SizedBox(height: 20),
                    _buildFamilyDoubleCard("Usuario 2", "Guardián", orangeColor),
                    const SizedBox(height: 20),
                    _buildFamilyDoubleCard("Usuario 3", "Protegido", orangeColor),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyDoubleCard(String name, String role, Color orangeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tarjeta del nombre
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: orangeColor, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 4),

        // Tarjeta del rol + iconos, más corta y alineada a la izquierda
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 200,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: orangeColor, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    role,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Row(
                  children: const [
                    Icon(Icons.edit, color: Colors.black),
                    SizedBox(width: 15),
                    Icon(Icons.delete, color: Colors.black),
                  ],
                )
              ],
            ),
          ),
        ),
      ],
    );
  }
}
