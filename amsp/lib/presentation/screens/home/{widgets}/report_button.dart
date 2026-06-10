import 'package:flutter/material.dart';

class ReportButton extends StatelessWidget {
  final VoidCallback onPressed;
  
  const ReportButton({
    super.key,
    required this.onPressed,
  });
  
  @override
  Widget build(BuildContext context) {
    final orangeTrans = const Color.fromARGB(221, 255, 120, 23);
    
    return Positioned(
      bottom: 37,
      left: 25,
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              spreadRadius: 2,
              blurRadius: 7,
              offset: const Offset(0, 7),
            ),
          ],
          shape: BoxShape.circle,
        ),
        child: RawMaterialButton(
          onPressed: onPressed,
          fillColor: orangeTrans,
          shape: const CircleBorder(),
          constraints: const BoxConstraints.tightFor(width: 110, height: 110),
          elevation: 0,
          child: const Text(
            'Reporte',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}