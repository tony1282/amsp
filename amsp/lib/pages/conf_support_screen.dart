import 'package:flutter/material.dart';

class SoporteScreen extends StatelessWidget {
  const SoporteScreen({super.key});

  static const Color backgroundColor = Color(0xFF248448);
  static const Color orangeColor = Color(0xFFF47405);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: backgroundColor,
        centerTitle: true,
        title: const Text(
          'Soporte',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              buildOrangeContainer(
                title: 'Política de soporte técnico',
                description:
                    'Nuestro compromiso es ofrecer un servicio de soporte técnico eficiente y accesible para todos los usuarios de la aplicación móvil de seguridad personal. Esta política describe los canales disponibles, tiempos de respuesta y el tipo de asistencia que brindamos.',
              ),
              buildOrangeContainer(
                title: '1. Alcance del soporte',
                description: '''
• Problemas con el inicio de sesión o recuperación de cuenta.
• Fallas en el funcionamiento del botón SOS, alertas o mapas.
• Configuración de contactos de emergencia o círculos de miembros.
• Reportes de errores, fallos o comportamiento inesperado de la app.
• Dudas sobre permisos, notificaciones o funcionamiento general.
''',
              ),
              buildOrangeContainer(
                title: '2. Canales de atención',
                description: '''
• Correo electrónico: soporte@tuapp.com
• Formulario de contacto: disponible dentro de la app en el apartado "Ayuda" o "Soporte".
• Redes sociales oficiales (opcional): para consultas generales (no técnicas).
''',
              ),
              buildOrangeContainer(
                title: '3. Horarios de atención',
                description:
                    'El equipo de soporte atiende de lunes a viernes de 9:00 a.m. a 6:00 p.m. (hora local). Las solicitudes recibidas fuera del horario serán atendidas al siguiente día hábil.',
              ),
              buildOrangeContainer(
                title: '4. Tiempos de respuesta',
                description: '''
• Consultas generales: en un plazo máximo de 48 horas.
• Incidentes críticos (ej. botón SOS no funciona): prioridad alta, respuesta en menos de 12 horas.
• Errores menores o sugerencias: entre 2 y 5 días hábiles.
''',
              ),
              buildOrangeContainer(
                title: '5. Actualizaciones y mejoras',
                description: '''
• Corregir errores detectados.
• Mejorar el rendimiento de la app.
• Incluir nuevas funcionalidades de seguridad.
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
