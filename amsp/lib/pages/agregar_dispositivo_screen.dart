import 'package:flutter/material.dart';

class AgregarDispositivoScreen extends StatefulWidget {
  const AgregarDispositivoScreen({super.key});

  @override
  State<AgregarDispositivoScreen> createState() => _AgregarDispositivoScreenState();
}

class _AgregarDispositivoScreenState extends State<AgregarDispositivoScreen> {
  final _formKey = GlobalKey<FormState>(); // Clave para el formulario y validación
  final TextEditingController _deviceNameController = TextEditingController(); // Controlador para el nombre del dispositivo

  @override
  void dispose() {
    _deviceNameController.dispose(); // Liberar recursos del controlador
    super.dispose();
  }

  // Método para agregar el dispositivo cuando el formulario es válido
  void _agregarDispositivo() {
    if (_formKey.currentState!.validate()) {
      String deviceName = _deviceNameController.text.trim();

      // Aquí podrías agregar la lógica para guardar el dispositivo
      // en tu base de datos o enviarlo a backend.

      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dispositivo "$deviceName" agregado con éxito.')),
      );

      // Limpiar campo y regresar a la pantalla anterior
      _deviceNameController.clear();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar Dispositivo'),
        backgroundColor: const Color(0xFF248448), // Color verde oscuro
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey, // Asociar el formulario con la clave para validación
          child: Column(
            children: [
              TextFormField(
                controller: _deviceNameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del dispositivo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.watch), // Icono de reloj
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor ingresa un nombre'; // Mensaje si el campo está vacío
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Agregar dispositivo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF248448),
                  minimumSize: const Size.fromHeight(50), // Botón ancho con altura fija
                ),
                onPressed: _agregarDispositivo, // Llama a la función para agregar
              ),
            ],
          ),
        ),
      ),
    );
  }
}
