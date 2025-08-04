import 'package:amsp/models/inegi_data.dart'; // Modelo para datos INEGI
import 'package:amsp/services/inegi_service.dart'; // Servicio para obtener datos del INEGI
import 'package:flutter/material.dart'; // Widgets de Flutter
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp; // Mapbox para Flutter (aunque aquí no se usa)
import 'package:flutter/services.dart' show rootBundle; // Para carga de recursos (no usado en este fragmento)

class ZonasRiesgoScreen extends StatefulWidget {
  @override
  _ZonasRiesgoScreenState createState() => _ZonasRiesgoScreenState();
}

class _ZonasRiesgoScreenState extends State<ZonasRiesgoScreen> {
  List<IndicadorInegi> indicadores = []; // Lista para guardar indicadores obtenidos
  bool cargando = true; // Estado para mostrar si está cargando datos
  List<String> codigosRiesgo = []; // Lista para guardar códigos de zonas de riesgo

  @override
  void initState() {
    super.initState();
    cargarDatos(); // Al iniciar el widget, se cargan los datos del INEGI
  }

  Future<void> cargarDatos() async {
    try {
      // Obtiene la lista de indicadores del servicio INEGI
      indicadores = await InegiService.obtenerIndicadores();

      const double umbral = 50.0; // Define un umbral para considerar zona de riesgo

      // Filtra los indicadores que superan el umbral y adapta su código a formato esperado
      codigosRiesgo = indicadores
          .where((ind) => ind.valor > umbral)
          .map((ind) => adaptarCodigoInegi(ind.geoCode))
          .toList();

      // Actualiza el estado para indicar que terminó la carga
      setState(() {
        cargando = false;
      });

      // Regresa a la pantalla anterior enviando los códigos de riesgo obtenidos
      Navigator.pop(context, codigosRiesgo);

    } catch (e) {
      print("Error cargando datos INEGI: $e"); // Imprime error si falla la carga
      setState(() {
        cargando = false; // También actualiza el estado para dejar de mostrar carga
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cargando zonas de riesgo...")), // Barra con título
      body: Center(
        child: cargando
            ? const CircularProgressIndicator() // Muestra indicador de carga mientras true
            : const Text('Cargando finalizado, regresando...'), // Texto cuando carga termina
      ),
    );
  }
}

// Función que adapta códigos INEGI a formato estándar de 5 dígitos (2 dígitos para estado + 3 para municipio)
String adaptarCodigoInegi(String codigoOriginal) {
  // Elimina guiones y espacios del código original
  String limpio = codigoOriginal.replaceAll('-', '').replaceAll(' ', '');

  if (limpio.length == 5) return limpio; // Si ya tiene 5 caracteres, lo devuelve tal cual

  if (limpio.length == 4) {
    // Si tiene 4 caracteres, agrega un cero delante del municipio
    final cveEnt = limpio.substring(0, 2);
    final cveMun = '0' + limpio.substring(2, 4);
    return cveEnt + cveMun;
  }

  if (limpio.length == 3) {
    // Si tiene 3 caracteres, agrega dos ceros delante del municipio
    final cveEnt = limpio.substring(0, 2);
    final cveMun = '00' + limpio.substring(2, 3);
    return cveEnt + cveMun;
  }

  return limpio; // Si no cumple ninguna condición, devuelve el código limpio sin cambios
}
