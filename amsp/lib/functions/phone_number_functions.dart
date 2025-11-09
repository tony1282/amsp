import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PhoneNumberFunctions {

  /// Muestra un formulario para agregar un nuevo contacto de emergencia
  void mostrarFormularioAgregar(BuildContext context) {
    final theme = Theme.of(context);
    final greenColor = theme.primaryColor;
    final _nombreController = TextEditingController();
    final _numeroController = TextEditingController();
    final userId = FirebaseAuth.instance.currentUser?.uid;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: greenColor,
        title: const Text("Agregar Contacto", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nombreController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: "Nombre",
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white70),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            TextField(
              controller: _numeroController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: const InputDecoration(
                labelText: "Número",
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white70),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar", style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: greenColor,
            ),
            onPressed: () async {
              final nombre = _nombreController.text.trim();
              final numero = _numeroController.text.trim();

              if (nombre.isEmpty || numero.isEmpty || numero.length != 10) return;

              await FirebaseFirestore.instance
                  .collection('contactos')
                  .doc(userId)
                  .collection('contactos_emergencia')
                  .add({
                'nombreContacto': nombre,
                'numeroContacto': numero,
                'fechaAgregado': FieldValue.serverTimestamp(),
              });

              Navigator.pop(context);
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  /// Muestra un formulario para editar un contacto existente
  void editarContacto(
      BuildContext context, String id, String nombreActual, String numeroActual) {
    final theme = Theme.of(context);
    final greenColor = theme.primaryColor;
    final _nombreController = TextEditingController(text: nombreActual);
    final _numeroController = TextEditingController(text: numeroActual);
    final userId = FirebaseAuth.instance.currentUser?.uid;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: greenColor,
        title: const Text("Editar Contacto", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nombreController,
              decoration: const InputDecoration(
                labelText: "Nombre",
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white70),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            TextField(
              controller: _numeroController,
              decoration: const InputDecoration(
                labelText: "Número",
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white70),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar", style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: greenColor,
            ),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('contactos')
                  .doc(userId)
                  .collection('contactos_emergencia')
                  .doc(id)
                  .update({
                'nombreContacto': _nombreController.text.trim(),
                'numeroContacto': _numeroController.text.trim(),
              });
              Navigator.pop(context);
            },
            child: const Text("Actualizar"),
          ),
        ],
      ),
    );
  }
}
