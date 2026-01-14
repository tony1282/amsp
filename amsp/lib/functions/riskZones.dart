import 'dart:async';

import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;


class riskZones { 

  StreamSubscription? userPositionStream;
  
  mp.MapboxMap? mapboxMapController;
  mp.PointAnnotationManager? pointAnnotationManager;
  mp.CircleAnnotationManager? circleAnnotationManager;

  bool esCreadorFamilia = false;
  bool cargandoUsuario = true;


  String? circuloSeleccionadoId;
  String? circuloSeleccionadoNombre;


  Future<void> refrescarZonasTlaxcala(mp.MapboxMap mapboxMap) async {
    await mapboxMap.loadStyleURI('mapbox://styles/mapbox/streets-v12'); 
    mostrarGeoJsonTlaxcala(mapboxMap);
  }
  

  Future<void> mostrarGeoJsonTlaxcala(mp.MapboxMap mapboxMap) async {
    print("Iniciando carga del GeoJSON...");

    final geoJsonData = await rootBundle.loadString('assets/geojson/tlaxcala_zonas.geojson');
    print("GeoJSON cargado, tamaño: ${geoJsonData.length} caracteres");

    try {
      await mapboxMap.style.addSource(
        mp.GeoJsonSource(id: "tlaxcala-source", data: geoJsonData),
      );
      print("Fuente 'tlaxcala-source' agregada al mapa");
    } catch (e) {
      print("Error agregando fuente: $e");
    }

    final filtroAlto = ['==', ['get', 'riesgo'], 'Alto'];
    print("Filtro para riesgo alto definido: $filtroAlto");

    final fillLayerAlto = mp.FillLayer(
      id: "tlaxcala-layer-alto",
      sourceId: "tlaxcala-source",
      filter: filtroAlto,
      fillColor: 0x80FF0000, 
      fillOpacity: 0.5,
    );

    try {
      await mapboxMap.style.addLayer(fillLayerAlto);
      print("Capa de riesgo 'Alto' agregada al mapa");
    } catch (e) {
      print("Error agregando capa de riesgo: $e");
    }

    print("Proceso terminado");
  }

  /*

  void _abrirZonasRiesgo() async {
    final codigos = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(builder: (context) => ZonasRiesgoScreen()),
    );
    if (codigos != null) {
      setState(() {
        codigosRiesgo = codigos;
      });
      if (mapboxMapController != null) {
        await _mostrarGeoJsonTlaxcala(mapboxMapController!);
      }
    }
  }
  */
  
}
