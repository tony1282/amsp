import 'package:flutter/material.dart';

class AgregarDispositivoScreen extends StatefulWidget {
  const AgregarDispositivoScreen({super.key});

  @override
  State<AgregarDispositivoScreen> createState() => _AgregarDispositivoScreenState();
}

class _AgregarDispositivoScreenState extends State<AgregarDispositivoScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _deviceNameController = TextEditingController();

  @override
  void dispose() {
    _deviceNameController.dispose();
    super.dispose();
  }

  void _agregarDispositivo() {
    if (_formKey.currentState!.validate()) {
      String deviceName = _deviceNameController.text.trim();

      // Aquí podrías agregar la lógica para guardar el dispositivo
      // en tu base de datos o enviarlo a backend.

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dispositivo "$deviceName" agregado con éxito.')),
      );

      // Limpiar el campo o regresar a la pantalla anterior:
      _deviceNameController.clear();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar Dispositivo'),
        backgroundColor: const Color(0xFF248448),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _deviceNameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del dispositivo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.watch),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor ingresa un nombre';
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
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: _agregarDispositivo,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
