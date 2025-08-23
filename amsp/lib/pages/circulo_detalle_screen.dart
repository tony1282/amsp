import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'family_screen.dart';

class CirculoDetalleScreen extends StatefulWidget {
  final String circleId;
  final bool esCreador;

  const CirculoDetalleScreen({
    super.key,
    required this.circleId,
    required this.esCreador,
  });

  @override
  State<CirculoDetalleScreen> createState() => _CirculoDetalleScreenState();
}

class _CirculoDetalleScreenState extends State<CirculoDetalleScreen> {
  final _firestore = FirebaseFirestore.instance;

  late TextEditingController _nombreController;
  late TextEditingController _tipoController;

  Map<String, dynamic>? _circleData;

  @override
  void initState() {
    super.initState();
    _fetchCircleData();
  }

  Future<void> _fetchCircleData() async {
    final doc = await _firestore.collection('circulos').doc(widget.circleId).get();
    if (doc.exists) {
      setState(() {
        _circleData = doc.data();
        _nombreController = TextEditingController(text: _circleData?['nombre'] ?? '');
        _tipoController = TextEditingController(text: _circleData?['tipo'] ?? '');
      });
    }
  }

  Future<void> _mostrarModalEdicion({required bool editarNombre}) async {
    final controller = editarNombre ? _nombreController : _tipoController;
    final label = editarNombre ? 'Nombre' : 'Tipo';
    final theme = Theme.of(context);
    final greenColor = theme.primaryColor;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: greenColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Editar $label', style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Colors.white70),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white70),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
            onPressed: () async {
              await _guardarCambios(nombre: editarNombre);
              if (mounted) Navigator.pop(context);
            },
            child: Text('Guardar', style: TextStyle(color: greenColor)),
          ),
        ],
      ),
    );
  }

  Future<void> _guardarCambios({required bool nombre}) async {
    final nombreText = _nombreController.text.trim();
    final tipoText = _tipoController.text.trim();

    if (nombre && nombreText.isEmpty) return;
    if (!nombre && tipoText.isEmpty) return;

    await _firestore.collection('circulos').doc(widget.circleId).update({
      if (nombre) 'nombre': nombreText,
      if (!nombre) 'tipo': tipoText,
    });

    await _fetchCircleData();
  }

  Future<void> _eliminarMiembro(String uid) async {
    try {
      final miembros = List.from(_circleData?['miembros'] ?? []);
      miembros.removeWhere((m) => m['uid'] == uid);
      final miembrosUids = List.from(_circleData?['miembrosUids'] ?? []);
      miembrosUids.remove(uid);

      await _firestore.collection('circulos').doc(widget.circleId).update({
        'miembros': miembros,
        'miembrosUids': miembrosUids,
      });

      await _firestore
          .collection('circulos')
          .doc(widget.circleId)
          .collection('miembros')
          .doc(uid)
          .delete();

      await _fetchCircleData();
    } catch (_) {}
  }

  Future<void> _eliminarCirculo() async {
  try {
    final miembrosSnapshot = await _firestore
        .collection('circulos')
        .doc(widget.circleId)
        .collection('miembros')
        .get();
    for (var doc in miembrosSnapshot.docs) {
      await doc.reference.delete();
    }
    await _firestore.collection('circulos').doc(widget.circleId).delete();

    if (mounted) {
      Navigator.pop(context);
    }
  } catch (_) {}
}


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final greenColor = theme.primaryColor;
    final size = MediaQuery.of(context).size;

    if (_circleData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle del círculo'), backgroundColor: greenColor),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final miembros = List<Map<String, dynamic>>.from(_circleData?['miembros'] ?? []);
    final codigo = _circleData?['codigo'] ?? '';
    final creadorUid = _circleData?['creador'];

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del círculo'), backgroundColor: greenColor),
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: size.width * 0.05, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGreenContainer(
                greenColor,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('Código del círculo:', style: TextStyle(color: Colors.white, fontSize: 16)),
                    const SizedBox(height: 8),
                    SelectableText(
                      codigo,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              _buildGreenContainer(
                greenColor,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Círculo', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    const Text('Nombre del círculo', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    _buildEditableFieldModal('Nombre', () => _mostrarModalEdicion(editarNombre: true), _nombreController.text),
                    const SizedBox(height: 15),
                    const Text('Tipo de círculo', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    _buildEditableFieldModal('Tipo', () => _mostrarModalEdicion(editarNombre: false), _tipoController.text),
                  ],
                ),
              ),
              _buildGreenContainer(
                greenColor,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Miembros:', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    if (miembros.isEmpty)
                      const Text('No hay miembros', style: TextStyle(color: Colors.white)),
                    ...miembros.map((miembro) {
                      final esCreador = miembro['uid'] == creadorUid;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        child: ListTile(
                          title: Row(
                            children: [
                              Expanded(child: Text('Nombre: ${miembro['name'] ?? 'Sin nombre'}')),
                              if (esCreador)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: greenColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Guardián',
                                    style: TextStyle(
                                      color: greenColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Correo: ${miembro['email'] ?? 'Sin correo'}'),
                              Text('Número: ${miembro['phone'] ?? 'Sin número'}'),
                            ],
                          ),
                          trailing: (widget.esCreador && !esCreador)
                              ? IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Confirmar'),
                                        content: Text('¿Eliminar a ${miembro['name']}?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                                          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await _eliminarMiembro(miembro['uid']);
                                    }
                                  },
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              if (widget.esCreador)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Eliminar Círculo'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Confirmar'),
                          content: const Text('¿Seguro que quieres eliminar este círculo?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await _eliminarCirculo();
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreenContainer(Color color, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }

  Widget _buildEditableFieldModal(String label, VoidCallback onPressed, String value) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        title: Text(value.isNotEmpty ? value : 'Sin $label'),
        trailing: widget.esCreador
            ? Icon(Icons.edit, color: Theme.of(context).primaryColor)
            : null,
        onTap: widget.esCreador ? onPressed : null,
      ),
    );
  }
}
