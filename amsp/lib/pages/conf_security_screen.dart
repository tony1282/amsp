import 'package:flutter/material.dart';

class SeguridadScreen extends StatelessWidget {
  const SeguridadScreen({super.key});

  static const Color backgroundColor = Color(0xFF248448);
  static const Color orangeColor = Color(0xFFF47405);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: backgroundColor,
        centerTitle: true,
        title: const Text(
          'Seguridad',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              buildOrangeContainer(
                title: 'Compromiso con tu seguridad',
                description:
                    'La seguridad del usuario es una prioridad fundamental en nuestra aplicación de seguridad personal. Por ello, implementamos medidas técnicas y organizativas para garantizar la protección de los datos, el funcionamiento confiable de las funciones críticas (como el botón de pánico) y la confidencialidad de la información personal y geolocalización del usuario.',
              ),
              buildOrangeContainer(
                title: 'Protección de datos',
                description: '''
• Toda la información sensible (como ubicación, contactos de emergencia y datos de cuenta) se almacena de forma segura y cifrada.
• La comunicación entre la app y los servidores se realiza a través de canales cifrados (HTTPS/SSL).
• Los datos solo son accesibles por el usuario y por los sistemas autorizados, nunca por terceros sin consentimiento.
''',
              ),
              buildOrangeContainer(
                title: 'Seguridad en emergencias',
                description: '''
• Al presionar el botón SOS, la aplicación activa protocolos inmediatos para compartir la ubicación actual con contactos de emergencia previamente registrados.
• El sistema responde incluso si la app está en segundo plano, para asegurar su uso en momentos críticos.
''',
              ),
              buildOrangeContainer(
                title: 'Prevención de fallos',
                description: '''
• La aplicación incluye mecanismos para seguir funcionando incluso si hay interrupciones de red, batería baja o problemas del dispositivo.
• El botón SOS puede enviar señales locales si no hay conexión a Internet disponible.
''',
              ),
              buildOrangeContainer(
                title: 'Actualizaciones seguras',
                description:
                    'Las actualizaciones de la aplicación se distribuyen de forma segura a través de tiendas oficiales (Google Play).',
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
