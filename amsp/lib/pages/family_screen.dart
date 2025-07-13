import 'package:flutter/material.dart';

class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key});

  static const Color orangeColor = Color.fromARGB(255, 255, 108, 0);
  static const Color backgroundColor = Color(0xFF248448);

  final String? _fotoURL = null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: backgroundColor,
        centerTitle: true,
        title: const Text(
          'AMSP',
          style: TextStyle(
            color: Colors.black,
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
                      backgroundImage: NetworkImage(_fotoURL!),
                    )
                  : const CircleAvatar(radius: 60),
            ),
            ElevatedButton(
              onPressed: () {
                // Acción para agregar familiar
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: backgroundColor,
                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Agregar familiar',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            const SizedBox(height: 30),

            // Tarjeta verde
            Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              color: backgroundColor,
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  children: [
                    const Text(
                      "Familia",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 25),

                    // Lista de familiares con dos tarjetas cada uno
                    _buildFamilyDoubleCard("Usuario 1", "Protegido"),
                    const SizedBox(height: 20),
                    _buildFamilyDoubleCard("Usuario 2", "Guardián"),
                    const SizedBox(height: 20),
                    _buildFamilyDoubleCard("Usuario 3", "Protegido"),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyDoubleCard(String name, String role) {
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
        const SizedBox(height: 4), // menos espacio aquí

        // Tarjeta del rol + iconos, más corta y alineada a la izquierda
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 200, // ancho fijo más corto que el nombre
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
