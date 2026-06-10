import 'package:flutter/material.dart';

class CircleSelectorButton extends StatelessWidget {
  final VoidCallback onPressed;
  
  const CircleSelectorButton({
    super.key,
    required this.onPressed,
  });
  
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final orangeTrans = const Color.fromARGB(221, 255, 120, 23);
    final contrastColor = Theme.of(context).appBarTheme.foregroundColor ?? Colors.white;
    
    return Positioned(
      top: screenHeight * 0.03,
      left: 16,
      child: Container(
        decoration: BoxDecoration(
          color: orangeTrans,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 7,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.family_restroom, size: 20),
          label: const Text("Círculo"),
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            foregroundColor: contrastColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            textStyle: const TextStyle(fontSize: 14),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            elevation: 0,
          ),
        ),
      ),
    );
  }
}