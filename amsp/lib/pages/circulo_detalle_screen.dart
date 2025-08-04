import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CirculoDetalleScreen extends StatefulWidget {
  final String circleId; // ID del círculo a mostrar
  final bool esCreador;  // Indica si el usuario actual es creador del círculo

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

  late TextEditingController _nombreController; // Controlador para el campo Nombre
  late TextEditingController _tipoController;   // Controlador para el campo Tipo

  bool _isEditingNombre = false; // Controla si está en modo edición del nombre
  bool _isEditingTipo = false;   // Controla si está en modo edición del tipo

  Map<String, dynamic>? _circleData; // Datos del círculo obtenidos de Firestore

  @override
  void initState() {
    super.initState();
    _fetchCircleData(); // Carga inicial de datos del círculo
  }

  // Método para obtener los datos del círculo desde Firestore
  Future<void> _fetchCircleData() async {
    final doc = await _firestore.collection('circulos').doc(widget.circleId).get();
    if (doc.exists) {
      setState(() {
        _circleData = doc.data();
        // Inicializa los controladores con los valores actuales
        _nombreController = TextEditingController(text: _circleData?['nombre'] ?? '');
        _tipoController = TextEditingController(text: _circleData?['tipo'] ?? '');
        // Reiniciar estados de edición
        _isEditingNombre = false;
        _isEditingTipo = false;
      });
    }
  }

  // Método para guardar cambios de nombre o tipo en Firestore
  Future<void> _guardarCambios({required bool nombre}) async {
    String nombreText = _nombreController.text.trim();
    String tipoText = _tipoController.text.trim();

    // Validaciones para evitar campos vacíos
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

    // Actualiza solo el campo correspondiente
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
    // Refresca los datos para sincronizar UI
    await _fetchCircleData();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Datos actualizados')),
    );
  }

  // Método para eliminar un miembro del círculo
  Future<void> _eliminarMiembro(String uid) async {
    try {
      // Crea copias de las listas actuales para modificar
      final miembros = List.from(_circleData?['miembros'] ?? []);
      miembros.removeWhere((m) => m['uid'] == uid);

      final miembrosUids = List.from(_circleData?['miembrosUids'] ?? []);
      miembrosUids.remove(uid);

      // Actualiza el documento del círculo con las listas modificadas
      await _firestore.collection('circulos').doc(widget.circleId).update({
        'miembros': miembros,
        'miembrosUids': miembrosUids,
      });

      // Elimina el documento del miembro en la subcolección "miembros"
      await _firestore
          .collection('circulos')
          .doc(widget.circleId)
          .collection('miembros')
          .doc(uid)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Miembro eliminado')),
      );
      // Refresca los datos para actualizar la UI
      await _fetchCircleData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar miembro: $e')),
      );
    }
  }

  // Método para eliminar todo el círculo, incluyendo subcolección miembros
  Future<void> _eliminarCirculo() async {
    try {
      // Obtiene todos los documentos de la subcolección miembros
      final miembrosSnapshot = await _firestore
          .collection('circulos')
          .doc(widget.circleId)
          .collection('miembros')
          .get();
      // Elimina todos los documentos de miembros
      for (var doc in miembrosSnapshot.docs) {
        await doc.reference.delete();
      }
      // Elimina el documento del círculo
      await _firestore.collection('circulos').doc(widget.circleId).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Círculo eliminado')),
        );
        Navigator.pop(context); // Vuelve a la pantalla anterior
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

    // Si aún no se cargaron los datos, muestra un indicador de carga
    if (_circleData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detalle del círculo'),
          backgroundColor: greenColor,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Obtiene lista de miembros y código del círculo
    final miembros = List<Map<String, dynamic>>.from(_circleData?['miembros'] ?? []);
    final codigo = _circleData?['codigo'] ?? '';

    // Widget auxiliar para mostrar campos editables (nombre y tipo)
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
              if (widget.esCreador) // Solo el creador puede editar
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

            // Campo editable para el nombre del círculo
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
                    _isEditingTipo = false; // Desactiva edición del otro campo
                  });
                }
              },
            ),

            // Campo editable para el tipo del círculo
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
                    _isEditingNombre = false; // Desactiva edición del otro campo
                  });
                }
              },
            ),

            const SizedBox(height: 30),

            Text('Miembros:', style: theme.textTheme.headlineSmall),

            // Lista de miembros del círculo
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

            // Botón para eliminar todo el círculo, visible solo para creador
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
