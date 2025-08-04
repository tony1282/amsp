// Importaciones necesarias
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart';

// Pantalla para ingresar y guardar el número telefónico del usuario
class PhoneNumberScreen extends StatefulWidget {
  const PhoneNumberScreen({super.key});

  @override
  State<PhoneNumberScreen> createState() => _PhoneNumberScreenState();
}

class _PhoneNumberScreenState extends State<PhoneNumberScreen> {
  final _controller = TextEditingController(); // Controlador para el campo de texto
  final _firestore = FirebaseFirestore.instance; // Instancia de Firestore
  final _auth = FirebaseAuth.instance; // Instancia de FirebaseAuth

  // Función para guardar el número de teléfono del usuario
  void _savePhoneNumber() async {
    final user = _auth.currentUser; // Usuario actual autenticado
    final phone = _controller.text.trim(); // Número ingresado sin espacios

    // Verifica si hay usuario y si el campo no está vacío
    if (user != null && phone.isNotEmpty) {
      // Guarda el número junto con otros datos en Firestore (merge evita sobrescribir campos existentes)
      await _firestore.collection('users').doc(user.uid).set({
        'phone': phone,
        'email': user.email,
        'name': user.displayName,
      }, SetOptions(merge: true));

      // Si el widget está montado aún, redirige a la HomePage
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage(circleId: '',)),
        );
      }
    } else {
      // Muestra mensaje si el número está vacío o no hay usuario
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor ingresa un número válido")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final greenColor = theme.primaryColor; // Color principal (verde)

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 90, left: 40, right: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo y nombre de la app
              Padding(
                padding: const EdgeInsets.only(bottom: 50),
                child: Column(
                  children: const [
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: AssetImage('assets/images1.jpg'),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'AMSP',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Título de la pantalla
              const Text(
                "Ingresa tu número de teléfono",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Campo para ingresar el número telefónico
              TextField(
                controller: _controller,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Número de teléfono',
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(7)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                    borderSide: BorderSide(color: greenColor, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                    borderSide: BorderSide(color: greenColor, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              // Botón para guardar el número
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: greenColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _savePhoneNumber,
                child: const Text(
                  'Aceptar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
