import 'package:amsp/models/inegi_data.dart';
import 'package:amsp/services/inegi_service.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:flutter/services.dart' show rootBundle;

class ZonasRiesgoScreen extends StatefulWidget {
  @override
  _ZonasRiesgoScreenState createState() => _ZonasRiesgoScreenState();
}

class _ZonasRiesgoScreenState extends State<ZonasRiesgoScreen> {
  List<IndicadorInegi> indicadores = [];
  bool cargando = true;
  List<String> codigosRiesgo = [];

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  Future<void> cargarDatos() async {
    try {
      indicadores = await InegiService.obtenerIndicadores();
      const double umbral = 50.0;
      codigosRiesgo = indicadores
          .where((ind) => ind.valor > umbral)
          .map((ind) => adaptarCodigoInegi(ind.geoCode))
          .toList();

      setState(() {
        cargando = false;
      });

      Navigator.pop(context, codigosRiesgo);
    } catch (e) {
      print("Error cargando datos INEGI: $e");
      setState(() {
        cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cargando zonas de riesgo...")),
      body: Center(
        child: cargando
            ? const CircularProgressIndicator()
            : const Text('Cargando finalizado, regresando...'),
      ),
    );
  }
}

String adaptarCodigoInegi(String codigoOriginal) {
  String limpio = codigoOriginal.replaceAll('-', '').replaceAll(' ', '');

  if (limpio.length == 5) return limpio;

  if (limpio.length == 4) {
    final cveEnt = limpio.substring(0, 2);
    final cveMun = '0' + limpio.substring(2, 4);
    return cveEnt + cveMun;
  }

  if (limpio.length == 3) {
    final cveEnt = limpio.substring(0, 2);
    final cveMun = '00' + limpio.substring(2, 3);
    return cveEnt + cveMun;
  }

  return limpio;
}
