// Importaciones necesarias
import 'package:amsp/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Pantalla para unirse a un círculo familiar o de amigos
class UnirseCirculoScreen extends StatefulWidget {
  const UnirseCirculoScreen({super.key});

  @override
  State<UnirseCirculoScreen> createState() => _UnirseCirculoScreenState();
}

class _UnirseCirculoScreenState extends State<UnirseCirculoScreen> {
  final _codigoController = TextEditingController(); // Controlador para el campo del código
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false; // Indicador de carga para desactivar botón durante operación

  // Función principal para unirse al círculo
  Future<void> _unirseACirculo() async {
    final codigo = _codigoController.text.trim(); // Elimina espacios

    // Verifica que el campo no esté vacío
    if (codigo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor escribe un código')),
      );
      return;
    }

    setState(() => _isLoading = true); // Inicia el estado de carga

    try {
      // Busca un círculo con ese código
      final circleSnap = await _firestore
          .collection('circulos')
          .where('codigo', isEqualTo: codigo)
          .limit(1)
          .get();

      // Si no se encuentra el círculo, mostrar mensaje
      if (circleSnap.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontró ningún círculo con ese código')),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Se obtiene el documento del círculo
      final circleDoc = circleSnap.docs.first;
      final circleId = circleDoc.id;
      final circleRef = _firestore.collection('circulos').doc(circleId);
      final user = _auth.currentUser;

      // Verifica si hay sesión iniciada
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No has iniciado sesión')),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Obtiene datos del usuario desde la colección 'users'
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final data = userDoc.data();

      // Si no se encuentran los datos del usuario
      if (data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontraron tus datos')),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Datos que se agregarán al círculo
      final miembroData = {
        'uid': user.uid,
        'name': data['name'] ?? 'desconocido',
        'phone': data['phone'] ?? 'desconocido',
        'email': data['email'] ?? 'sin correo',
        'rol': data['rol'] ?? 'familiar',
      };

      // Verifica si el usuario ya es miembro del círculo
      final miembrosArray = List.from(circleDoc.data()?['miembros'] ?? []);
      final yaExiste = miembrosArray.any((m) {
        if (m is Map && m['uid'] == user.uid) return true;
        return false;
      });

      if (yaExiste) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ya eres parte de este círculo')),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Agrega al usuario a los arrays de miembros y miembrosUids
      await circleRef.update({
        'miembros': FieldValue.arrayUnion([miembroData]),
        'miembrosUids': FieldValue.arrayUnion([user.uid]),
      });

      // También lo guarda como documento en la subcolección 'miembros'
      await circleRef
          .collection('miembros')
          .doc(user.uid)
          .set(miembroData, SetOptions(merge: true));

      // Muestra mensaje de éxito y navega a HomePage con el círculo
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Te has unido al círculo exitosamente')),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(circleId: circleId),
        ),
      );
    } catch (e) {
      // Manejo de errores en consola y snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false); // Finaliza estado de carga
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final greenColor = theme.primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Unirse a un círculo'),
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 90, left: 40, right: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Introduce el código del círculo para unirte",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Campo para ingresar el código
              TextField(
                controller: _codigoController,
                decoration: InputDecoration(
                  labelText: 'Código del círculo',
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(7)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                    borderSide: BorderSide(color: greenColor, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                    borderSide: BorderSide(color: greenColor, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              // Botón para unirse
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: greenColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isLoading ? null : _unirseACirculo,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Unirse',
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
