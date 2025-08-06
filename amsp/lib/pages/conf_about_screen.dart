import 'package:flutter/material.dart';

class AcercaDeScreen extends StatelessWidget {
  const AcercaDeScreen({super.key});

  static const Color backgroundColor = Color(0xFF248448);
  static const Color orangeColor = Color(0xFFF47405);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: backgroundColor,
        centerTitle: true,
        title: const Text(
          'Acerca de',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            // Botones con modales
            _buildModalButton(context, 'Términos de uso', '''
Términos de uso

Al descargar, instalar y utilizar esta aplicación móvil de seguridad personal, el usuario acepta cumplir con los siguientes términos y condiciones. Si el usuario no está de acuerdo con alguno de estos términos, deberá abstenerse de utilizar la aplicación.
            '''),
            _buildModalButton(context, 'Nosotros', '''
Somos un equipo comprometido con la seguridad y el bienestar de las personas. Nuestra aplicación móvil nace con el propósito de ofrecer una herramienta confiable y accesible que permita a los usuarios protegerse, comunicarse y reaccionar rápidamente en situaciones de emergencia.
            '''),
          ],
        ),
      ),
    );
  }

  Widget _buildModalButton(BuildContext context, String titulo, String contenido) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: orangeColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: orangeColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Text(
                titulo,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                contenido,
                style: const TextStyle(
                  color: Colors.white,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cerrar',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        },
        child: Text(
          titulo,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
