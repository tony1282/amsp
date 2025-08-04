// Importación de paquetes necesarios
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:amsp/pages/phone_number_screen.dart';

// Pantalla para registrarse con correo electrónico
class LoginEmailScreen extends StatefulWidget {
  const LoginEmailScreen({super.key});

  @override
  State<LoginEmailScreen> createState() => _LoginEmailScreenState();
}

class _LoginEmailScreenState extends State<LoginEmailScreen> {
  // Controladores para los campos de texto
  final _nameController = TextEditingController();     // Campo para el nombre del usuario
  final _emailController = TextEditingController();    // Campo para el correo electrónico
  final _passwordController = TextEditingController(); // Campo para la contraseña

  // Método que se ejecuta al presionar el botón de registro
  Future<void> _submit() async {
    try {
      // Crea una nueva cuenta con correo y contraseña en Firebase
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Guarda el nombre proporcionado como displayName del usuario
      await credential.user?.updateDisplayName(_nameController.text.trim());
      await credential.user?.reload(); // Actualiza la información del usuario

      // Navega a la pantalla para ingresar el número de teléfono
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PhoneNumberScreen()),
        );
      }
    } catch (e) {
      // Muestra un error en un SnackBar si algo falla
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final greenColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 90, left: 40, right: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Encabezado con avatar e ícono
                const Padding(
                  padding: EdgeInsets.only(bottom: 50),
                  child: Column(
                    children: [
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
                  'Registrarse con correo electrónico',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),

                // Campo de texto para el nombre
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Nombre completo',
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
                  textCapitalization: TextCapitalization.words,
                ),

                const SizedBox(height: 15),

                // Campo de texto para el correo electrónico
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Correo electrónico',
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
                  keyboardType: TextInputType.emailAddress,
                ),

                const SizedBox(height: 15),

                // Campo de texto para la contraseña
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
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
                  obscureText: true, // Oculta el texto por seguridad
                ),

                const SizedBox(height: 30),

                // Botón para enviar el formulario y registrarse
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
                  onPressed: _submit,
                  child: const Text(
                    'Registrarse',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
