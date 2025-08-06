import 'package:flutter/material.dart';

class PrivacidadScreen extends StatelessWidget {
  const PrivacidadScreen({super.key});

  static const Color backgroundColor = Color(0xFF248448);
  static const Color orangeColor = Color(0xFFF47405);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: backgroundColor,
        centerTitle: true,
        title: const Text(
          'Privacidad',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView( // <-- Aquí la única adición
          child: Column(
            children: [
              buildOrangeContainer(
                title: 'Política de privacidad',
                description:
                    'Esta aplicación móvil de seguridad personal recopila y utiliza datos personales con el fin de proteger al usuario en situaciones de emergencia. Entre sus funciones están el botón SOS, alertas, visualización de zonas de riesgo y la gestión de círculos de confianza (familiares o contactos cercanos).',
              ),
              buildOrangeContainer(
                title:'Datos que recopilamos',
                  description: '''
• Información del usuario: nombre, correo, teléfono.
• Ubicación en tiempo real (GPS).
• Contactos de emergencia registrados por el usuario.
• Datos del dispositivo (modelo, sistema operativo).
• Reportes y alertas generadas desde la app.
''',
              ),

              buildOrangeContainer(
                title:'Uso de los datos',
                subtitle: 'Los datos se utilizan para:',
             description: '''
• Activar funciones de emergencia (SOS, ubicación, alertas).
• Mostrar zonas de riesgo.
• Enviar notificaciones a usuarios en caso de peligro.
• Mejorar el funcionamiento general de la aplicación.
''',
                ),

                buildOrangeContainer(
                  title: 'Seguridad',
                  description: '''
• La información se protege mediante cifrado y medidas técnicas que evitan accesos no autorizados. 
• El usuario puede modificar o eliminar su información desde la app o solicitarlo por correo.

''',
                  ),
                  buildOrangeContainer(
                    title:'Permisos y control',
                    subtitle: 'El usuario puede:',
                    description: '''
• Activar o desactivar permisos de ubicación y notificaciones.
• Eliminar su cuenta en cualquier momento.
• Contactarnos en caso de dudas: Amsp@gmail.com
''',
                    ),


            ],
          ),
        ),
      ),
    );
  }

 Widget buildOrangeContainer({
  required String title,
  String? subtitle,
  String? description,
}) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 15),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: orangeColor,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (description != null) ...[
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.justify,
          ),
        ],
      ],
    ),
  );
}
}