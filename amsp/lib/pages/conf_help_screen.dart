import 'package:flutter/material.dart';

class AyudaScreen extends StatelessWidget {
  const AyudaScreen({super.key});

  static const Color backgroundColor = Color(0xFF248448);
  static const Color orangeColor = Color(0xFFF47405);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: backgroundColor,
        centerTitle: true,
        title: const Text(
          'Ayuda',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              buildExpansionTile(
                title: '¿Para qué sirve la sección de Ayuda?',
                content:
                    'Esta aplicación cuenta con un apartado de Ayuda que permite a los usuarios consultar información relevante sobre el uso de sus principales funciones. Está pensada para resolver dudas frecuentes y facilitar la navegación dentro de la app, especialmente en situaciones de emergencia.',
              ),
              buildExpansionTile(
                title: 'Cómo activar el botón SOS y qué sucede al hacerlo',
                content:
                    'Para activar el botón SOS, mantén presionado el ícono de emergencia. Al hacerlo, la app enviará inmediatamente tu ubicación actual a los contactos de emergencia registrados y activará las alertas de seguridad necesarias. Esta función está diseñada para situaciones críticas.',
              ),
              buildExpansionTile(
                title: 'Cómo registrar y editar contactos de emergencia',
                content:
                    'Ve al menú principal > Contactos de emergencia. Allí podrás agregar personas de tu agenda o escribir sus datos manualmente. También puedes editar o eliminar contactos cuando lo necesites. Solo los contactos agregados recibirán alertas SOS.',
              ),
              buildExpansionTile(
                title: 'Cómo ver zonas peligrosas en el mapa',
                content:
                    'Desde el mapa principal, activa la opción "Zonas de riesgo". Verás marcadas áreas que se consideran de alta peligrosidad, basadas en datos oficiales o reportes ciudadanos. Evita estas zonas cuando sea posible.',
              ),
              buildExpansionTile(
                title: 'Cómo unirse o crear círculos de confianza',
                content:
                    'Dirígete al apartado "Círculos de confianza". Puedes crear un nuevo grupo y compartir el código con tus familiares o amigos, o unirte a uno ingresando su código. Esto permite ver su ubicación en tiempo real y compartir alertas de seguridad.',
              ),
              buildExpansionTile(
                title: 'Qué hacer si la app no accede al GPS o hay problemas de conexión',
                content:
                    'Asegúrate de tener activada la ubicación del dispositivo y otorgados los permisos necesarios a la app. Si hay fallas en la conexión a internet, la app funcionará en modo limitado, pero aún podrá registrar eventos importantes localmente.',
              ),
              buildExpansionTile(
                title: 'Acceso rápido desde la app',
                content:
                    'Puedes acceder a esta sección desde el menú principal o desde los ajustes. Está disponible 24/7, incluso sin conexión a internet (en su versión básica).',
              ),
              buildExpansionTile(
                title: '¿Qué hacer si no encuentras la solución?',
                content:
                    'Si la información disponible en la sección de ayuda no resuelve el problema, puedes comunicarte con el equipo de soporte técnico por correo electrónico: soporte@tuapp.com',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildExpansionTile({required String title, required String content}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: orangeColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Theme(
        data: ThemeData().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          collapsedIconColor: Colors.white,
          iconColor: Colors.white,
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                content,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.justify,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
