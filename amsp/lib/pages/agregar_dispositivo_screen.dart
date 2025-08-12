import 'package:flutter/material.dart';

class AgregarDispositivoScreen extends StatefulWidget {
  const AgregarDispositivoScreen({super.key});

  @override
  State<AgregarDispositivoScreen> createState() =>
      _AgregarDispositivoScreenState();
}

class _AgregarDispositivoScreenState extends State<AgregarDispositivoScreen>
    with SingleTickerProviderStateMixin {
  bool _checking = false;
  bool _connected = false;

  String _deviceName = '—';
  String _battery = '—';
  String _lastSync = '—';

  // Animación suave (scale + opacity) para la tarjeta al conectar
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _scale = Tween<double>(
      begin: 0.98,
      end: 1.0,
    ).chain(CurveTween(curve: Curves.easeOut)).animate(_controller);
    _fade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).chain(CurveTween(curve: Curves.easeOut)).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verificarConexion() async {
    setState(() => _checking = true);

    // Simulación de escaneo/conexión (2 segundos)
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _connected = true;
      _checking = false;
      _deviceName = 'Galaxy Watch7';
      _battery = '82%';
      _lastSync = _timestampNow();
    });

    // Dispara animación cuando se conecta
    _controller.forward(from: 0);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conectado a Galaxy Watch7')),
      );
    }
  }

  void _desconectar() {
    setState(() {
      _connected = false;
      _deviceName = '—';
      _battery = '—';
      _lastSync = '—';
    });

    // Reinicia estado visual
    _controller.reset();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Reloj desconectado')));
  }

  String _timestampNow() {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final green = const Color(0xFF248448);
    final orange = const Color(0xFFF47405);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispositivo'),
        backgroundColor: green,
        actions: [
          if (_connected)
            IconButton(
              tooltip: 'Desconectar',
              onPressed: _desconectar,
              icon: const Icon(Icons.link_off),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 👉 subí la tarjeta: menos espacio arriba, más abajo
            const Spacer(flex: 1),

            // Tarjeta con animaciones
            ScaleTransition(
              scale: _scale,
              child: FadeTransition(
                opacity: _connected ? _fade : kAlwaysCompleteAnimation,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  // cambia levemente la sombra/tono al conectar
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      if (_connected)
                        BoxShadow(
                          color: green.withOpacity(0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                    ],
                  ),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: (_connected
                                      ? green
                                      : Colors.grey)
                                  .withOpacity(0.12),
                              child: const Icon(
                                Icons.watch,
                                color: Colors.black87,
                              ),
                            ),
                            title: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              transitionBuilder:
                                  (child, anim) => FadeTransition(
                                    opacity: anim,
                                    child: child,
                                  ),
                              child: Text(
                                _connected
                                    ? 'Conectado a Samsung'
                                    : 'Sin conexión',
                                key: ValueKey(_connected),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _connected ? green : Colors.black87,
                                ),
                              ),
                            ),
                            subtitle: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: Text(
                                _connected
                                    ? 'Tu teléfono está enlazado con el reloj'
                                    : 'Pulsa “Verificar conexión” para enlazar',
                                key: ValueKey('${_connected}_subtitle'),
                              ),
                            ),
                            trailing: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    _connected
                                        ? green.withOpacity(0.12)
                                        : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color:
                                      _connected ? green : Colors.grey.shade400,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _connected
                                        ? Icons.check_circle
                                        : Icons.info_outline,
                                    size: 16,
                                    color:
                                        _connected
                                            ? green
                                            : Colors.grey.shade700,
                                  ),
                                  const SizedBox(width: 6),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: Text(
                                      _connected ? 'Conectado' : 'Desconectado',
                                      key: ValueKey(_connected),
                                      style: TextStyle(
                                        color:
                                            _connected
                                                ? green
                                                : Colors.grey.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Divider(height: 1),
                          const SizedBox(height: 8),

                          // Detalles del dispositivo
                          Row(
                            children: [
                              _InfoChip(
                                label: 'Dispositivo',
                                value: _deviceName,
                                icon: Icons.watch_outlined,
                                accent: orange,
                              ),
                              const SizedBox(width: 8),
                              _InfoChip(
                                label: 'Batería',
                                value: _battery,
                                icon: Icons.battery_full,
                                accent: orange,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _InfoChip(
                                label: 'Última sync',
                                value: _lastSync,
                                icon: Icons.sync,
                                accent: orange,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const Spacer(flex: 2),

            // Botones de acción
            if (_checking)
              const _CheckingButton()
            else if (_connected)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: green,
                    side: BorderSide(color: green, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _desconectar,
                  icon: const Icon(Icons.link_off),
                  label: const Text('Desconectar'),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _verificarConexion,
                  icon: const Icon(Icons.link),
                  label: const Text('Verificar conexión'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _InfoChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final border = BorderSide(color: accent.withOpacity(0.5), width: 1.2);
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.fromBorderSide(border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: accent),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckingButton extends StatelessWidget {
  const _CheckingButton();

  @override
  Widget build(BuildContext context) {
    final green = const Color(0xFF248448);
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: null,
        icon: const SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
        label: const Text('Comprobando…'),
      ),
    );
  }
}