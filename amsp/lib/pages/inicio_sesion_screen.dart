// Importaciones necesarias
import 'package:amsp/pages/phone_number_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:amsp/pages/login_email_screen.dart';

// Pantalla principal de inicio de sesión
class InicioSesion extends StatelessWidget {
  const InicioSesion({super.key});

  // Función para iniciar sesión con Google
  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      // Inicia el flujo de autenticación de Google
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return; // Usuario canceló

      // Obtiene el token de autenticación de Google
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Crea las credenciales de Firebase con los tokens de Google
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Inicia sesión en Firebase con las credenciales
      await FirebaseAuth.instance.signInWithCredential(credential);

      // Redirige a la pantalla para ingresar el número de teléfono
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PhoneNumberScreen()),
        );
      }
    } catch (e) {
      // Muestra mensaje de error en caso de fallo
      print('Error al iniciar sesión con Google: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al iniciar sesión con Google')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final greenColor = theme.primaryColor;
    final contrastColor = theme.appBarTheme.foregroundColor ?? Colors.white;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            children: [
              const SizedBox(height: 84),

              // Avatar del logo de la app
              const CircleAvatar(
                radius: 60,
                backgroundImage: AssetImage('assets/images1.jpg'),
              ),
              const SizedBox(height: 10),

              // Nombre de la aplicación
              Text(
                'AMSP',
                style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ) ??
                    const TextStyle(
                      color: Colors.black,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
              ),

              const Spacer(),

              // Botón para iniciar sesión con Google
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: greenColor,
                  foregroundColor: contrastColor,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _signInWithGoogle(context),
                child: const Text('Iniciar sesión con Google'),
              ),

              const SizedBox(height: 12),

              // Botón para registrarse/iniciar sesión con correo electrónico
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: greenColor,
                  foregroundColor: contrastColor,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  // Navega a la pantalla de registro con correo
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginEmailScreen()),
                  );
                },
                child: const Text('Iniciar sesión con correo electrónico'),
              ),

              const SizedBox(height: 249), // Espacio inferior fijo
            ],
          ),
        ),
      ),
    );
  }
}
