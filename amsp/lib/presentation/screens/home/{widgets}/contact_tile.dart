import 'package:flutter/material.dart';
import 'package:amsp/contacts/call_manager.dart';
import 'package:amsp/contacts/contacts_manager.dart';

class ContactTile extends StatelessWidget {
  final String id;
  final String nombre;
  final String numero;
  final Callfunctions calls;
  final PhoneNumberFunctions number;
  
  const ContactTile({
    super.key,
    required this.id,
    required this.nombre,
    required this.numero,
    required this.calls,
    required this.number,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF6C00), width: 2),
      ),
      child: ListTile(
        leading: const Icon(Icons.phone, color: Color(0xFFF47405)),
        title: Text(nombre),
        subtitle: Text(numero),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.black),
              onPressed: () => number.editarContacto(context, id, nombre, numero),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.black),
              onPressed: () => calls.eliminarContacto(context, id),
            ),
          ],
        ),
        onTap: () => calls.llamarNumero(context, numero),
      ),
    );
  }
}