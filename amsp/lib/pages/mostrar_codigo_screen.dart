import 'package:flutter/material.dart';

class MostrarCodigoScreen extends StatelessWidget {
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
    final theme = Theme.of(context);
    final primary = theme.primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Código del círculo'),
        backgroundColor: primary,
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 50),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primary, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.groups, size: 48, color: Colors.white),
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
                  nombre,
                  style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white),
                ),

                const SizedBox(height: 20),

                /// Tipo de círculo
                Text(
                  'Tipo de círculo:',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  tipo.toUpperCase(),
                  style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
                ),

                const SizedBox(height: 30),

                /// Código
                Text(
                  'Código para unirse:',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SelectableText(
                  codigo,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),
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
