import 'package:flutter/material.dart';

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool mostrarNotificacion;
  final VoidCallback onSettingsPressed;
  final VoidCallback onNotificationsPressed;
  
  const HomeAppBar({
    super.key,
    required this.mostrarNotificacion,
    required this.onSettingsPressed,
    required this.onNotificationsPressed,
  });
  
  @override
  Widget build(BuildContext context) {
    return AppBar(
      centerTitle: true,
      title: const Text('AMSP'),
      leading: IconButton(
        icon: const Icon(Icons.settings, size: 45),
        onPressed: onSettingsPressed,
      ),
      actions: [
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications, size: 45),
              onPressed: onNotificationsPressed,
            ),
            if (mostrarNotificacion)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
  
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}