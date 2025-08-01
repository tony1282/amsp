import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

  bool _isEditingNombre = false;
  bool _isEditingTipo = false;

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
        // Reiniciar estados edición
        _isEditingNombre = false;
        _isEditingTipo = false;
      });
    }
  }

  Future<void> _guardarCambios({required bool nombre}) async {
    String nombreText = _nombreController.text.trim();
    String tipoText = _tipoController.text.trim();

    if (nombre && nombreText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre no puede estar vacío')),
      );
      return;
    }
    if (!nombre && tipoText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El tipo no puede estar vacío')),
      );
      return;
    }

    // Solo actualizamos el campo que se está editando
    await _firestore.collection('circulos').doc(widget.circleId).update({
      if (nombre) 'nombre': nombreText,
      if (!nombre) 'tipo': tipoText,
    });

    setState(() {
      if (nombre) {
        _isEditingNombre = false;
      } else {
        _isEditingTipo = false;
      }
    });
    await _fetchCircleData();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Datos actualizados')),
    );
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Miembro eliminado')),
      );
      await _fetchCircleData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar miembro: $e')),
      );
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Círculo eliminado')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar círculo: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final greenColor = theme.primaryColor;

    if (_circleData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detalle del círculo'),
          backgroundColor: greenColor,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final miembros = List<Map<String, dynamic>>.from(_circleData?['miembros'] ?? []);
    final codigo = _circleData?['codigo'] ?? '';

    Widget buildEditableCard({
      required String label,
      required TextEditingController controller,
      required bool enabled,
      required bool isEditing,
      required VoidCallback onEditPressed,
    }) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: label,
                    border: InputBorder.none,
                  ),
                  readOnly: !enabled,
                  style: TextStyle(
                    color: enabled ? Colors.black : Colors.grey[700],
                    fontSize: 16,
                  ),
                ),
              ),
              if (widget.esCreador)
                IconButton(
                  icon: Icon(isEditing ? Icons.check : Icons.edit, color: greenColor),
                  tooltip: isEditing ? 'Guardar' : 'Editar',
                  onPressed: onEditPressed,
                ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del círculo'),
        backgroundColor: greenColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Código del círculo:', style: theme.textTheme.titleMedium),
            SelectableText(codigo, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // Nombre editable
            buildEditableCard(
              label: 'Nombre',
              controller: _nombreController,
              enabled: _isEditingNombre,
              isEditing: _isEditingNombre,
              onEditPressed: () async {
                if (_isEditingNombre) {
                  await _guardarCambios(nombre: true);
                } else {
                  setState(() {
                    _isEditingNombre = true;
                    _isEditingTipo = false; // Desactivar otro campo
                  });
                }
              },
            ),

            // Tipo editable
            buildEditableCard(
              label: 'Tipo',
              controller: _tipoController,
              enabled: _isEditingTipo,
              isEditing: _isEditingTipo,
              onEditPressed: () async {
                if (_isEditingTipo) {
                  await _guardarCambios(nombre: false);
                } else {
                  setState(() {
                    _isEditingTipo = true;
                    _isEditingNombre = false; // Desactivar otro campo
                  });
                }
              },
            ),

            const SizedBox(height: 30),

            Text('Miembros:', style: theme.textTheme.headlineSmall),
            Expanded(
              child: ListView.builder(
                itemCount: miembros.length,
                itemBuilder: (context, index) {
                  final miembro = miembros[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 2,
                    child: ListTile(
                      title: Text(miembro['name'] ?? 'Sin nombre'),
                      subtitle: Text(miembro['email'] ?? ''),
                      trailing: widget.esCreador
                          ? IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Eliminar miembro',
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Confirmar eliminación'),
                                    content: Text('¿Eliminar a ${miembro['name']}?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancelar'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Eliminar'),
                                      ),
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
                },
              ),
            ),

            if (widget.esCreador)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Eliminar Círculo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Confirmar eliminación'),
                          content: const Text('¿Seguro que quieres eliminar este círculo?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancelar'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Eliminar'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await _eliminarCirculo();
                      }
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
