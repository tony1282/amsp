// Importa el paquete de Flutter para construir interfaces gráficas
import 'package:flutter/material.dart';

// Pantalla que muestra el código de un círculo recién creado
class MostrarCodigoScreen extends StatelessWidget {
  // Parámetros requeridos: código del círculo, tipo de círculo, nombre del círculo
  final String codigo;
  final String tipo;
  final String nombre;

  const MostrarCodigoScreen({
    super.key,
    required this.codigo,
    required this.tipo,
    required this.nombre,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);        // Obtiene el tema actual
    final primary = theme.primaryColor;     // Color principal del tema

    return Scaffold(
      appBar: AppBar(
        title: const Text('Código del círculo'), // Título del AppBar
        backgroundColor: primary,               // Color de fondo del AppBar
        centerTitle: true,                      // Centrar el título
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 50), // Margen general
          child: Container(
            padding: const EdgeInsets.all(24), // Relleno interno del contenedor
            decoration: BoxDecoration(
              color: primary,                     // Fondo con color principal
              borderRadius: BorderRadius.circular(16), // Bordes redondeados
              border: Border.all(color: primary, width: 2), // Borde con color primario
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Ocupa solo el espacio necesario
              children: [
                const Icon(Icons.groups, size: 48, color: Colors.white), // Icono principal
                const SizedBox(height: 20),

                /// Nombre del círculo
                Text(
                  'Nombre del círculo:',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  nombre, // Nombre recibido como parámetro
                  style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white),
                ),

                const SizedBox(height: 20),

                /// Tipo de círculo (familiar, escolar, etc.)
                Text(
                  'Tipo de círculo:',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  tipo.toUpperCase(), // Muestra el tipo en mayúsculas
                  style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
                ),

                const SizedBox(height: 30),

                /// Código generado para invitar a otros miembros
                Text(
                  'Código para unirse:',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SelectableText(
                  codigo, // Código único del círculo
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2, // Espaciado entre letras
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),

                // Mensaje de ayuda para compartir el código
                const Text(
                  'Comparte este código con las personas que quieras agregar al círculo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
