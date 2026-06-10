
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeState {
  // Mapa
  mp.MapboxMap? mapboxMapController;
  mp.PointAnnotationManager? pointAnnotationManager;
  mp.CircleAnnotationManager? circleAnnotationManager;
  mp.Point? ultimaPosicion;
  mp.Point? ultimaUbicacionPendiente;
  bool seguirUsuario = true;
  bool primerZoomUsuario = true;
  bool yaCargoInicial = false;
  bool zoomAjustadoParaCirculo = false;
  bool debeCentrarDespuesDeCerrar = false;
  
  // Círculos
  String? circuloSeleccionadoId;
  String? circuloSeleccionadoNombre;
  bool esCreadorFamilia = false;
  
  // Alertas
  bool mostrarNotificacion = true;
  bool mostrarModalAlerta = false;
  bool dialogoAbierto = false;
  bool alertaActiva = false;
  String? ultimoMensajeIot;
  String? ultimoMensajeMostrado;
  String? mensajeAlerta;
  
  // UI
  bool cargandoUsuario = true;
  
  // Timestamps
  DateTime ultimaSacudida = DateTime.now();
  DateTime sessionStart = DateTime.now();
  DateTime appStartTime = DateTime.now();
  DateTime? ultimoTimestampAlertasIoT;
  Timestamp? ultimoTimestampVisto;
  
  // Colecciones
  final Map<String, mp.PointAnnotation> marcadores = {};
  final Map<String, mp.PointAnnotation> miembrosAnnotations = {};
  final Map<String, mp.PointAnnotation> miembrosTextAnnotations = {};
  final Map<String, mp.Point> todasPosiciones = {};
  final Map<String, mp.PointAnnotation> alertasAnnotations = {};
  final Map<String, Timestamp> ultimoTimestampPorCirculo = {};
  final Set<String> processedAlertIds = {};
  final Set<String> alertasProcesadas = {};
  final Set<String> alertasMostradasIds = {};
  final Set<String> alertasMostradas = {};
  final Map<String, bool> initialCircleFetched = {};
  final List<String> codigosRiesgo = [];
  
  HomeState({
    this.mapboxMapController,
    this.pointAnnotationManager,
    this.circleAnnotationManager,
    this.ultimaPosicion,
    this.ultimaUbicacionPendiente,
    this.seguirUsuario = true,
    this.primerZoomUsuario = true,
    this.yaCargoInicial = false,
    this.zoomAjustadoParaCirculo = false,
    this.debeCentrarDespuesDeCerrar = false,
    this.circuloSeleccionadoId,
    this.circuloSeleccionadoNombre,
    this.esCreadorFamilia = false,
    this.mostrarNotificacion = true,
    this.mostrarModalAlerta = false,
    this.dialogoAbierto = false,
    this.alertaActiva = false,
    this.ultimoMensajeIot,
    this.ultimoMensajeMostrado,
    this.mensajeAlerta,
    this.cargandoUsuario = true,
    this.ultimoTimestampAlertasIoT,
    this.ultimoTimestampVisto,
    DateTime? ultimaSacudida,
  }) : ultimaSacudida = ultimaSacudida ?? DateTime.now();
  
  HomeState copyWith({
    mp.MapboxMap? mapboxMapController,
    mp.PointAnnotationManager? pointAnnotationManager,
    mp.CircleAnnotationManager? circleAnnotationManager,
    mp.Point? ultimaPosicion,
    mp.Point? ultimaUbicacionPendiente,
    bool? seguirUsuario,
    bool? primerZoomUsuario,
    bool? yaCargoInicial,
    bool? zoomAjustadoParaCirculo,
    bool? debeCentrarDespuesDeCerrar,
    String? circuloSeleccionadoId,
    String? circuloSeleccionadoNombre,
    bool? esCreadorFamilia,
    bool? mostrarNotificacion,
    bool? mostrarModalAlerta,
    bool? dialogoAbierto,
    bool? alertaActiva,
    String? ultimoMensajeIot,
    String? ultimoMensajeMostrado,
    String? mensajeAlerta,
    bool? cargandoUsuario,
    DateTime? ultimoTimestampAlertasIoT,
    Timestamp? ultimoTimestampVisto,
    DateTime? ultimaSacudida,
  }) {
    return HomeState(
      mapboxMapController: mapboxMapController ?? this.mapboxMapController,
      pointAnnotationManager: pointAnnotationManager ?? this.pointAnnotationManager,
      circleAnnotationManager: circleAnnotationManager ?? this.circleAnnotationManager,
      ultimaPosicion: ultimaPosicion ?? this.ultimaPosicion,
      ultimaUbicacionPendiente: ultimaUbicacionPendiente ?? this.ultimaUbicacionPendiente,
      seguirUsuario: seguirUsuario ?? this.seguirUsuario,
      primerZoomUsuario: primerZoomUsuario ?? this.primerZoomUsuario,
      yaCargoInicial: yaCargoInicial ?? this.yaCargoInicial,
      zoomAjustadoParaCirculo: zoomAjustadoParaCirculo ?? this.zoomAjustadoParaCirculo,
      debeCentrarDespuesDeCerrar: debeCentrarDespuesDeCerrar ?? this.debeCentrarDespuesDeCerrar,
      circuloSeleccionadoId: circuloSeleccionadoId ?? this.circuloSeleccionadoId,
      circuloSeleccionadoNombre: circuloSeleccionadoNombre ?? this.circuloSeleccionadoNombre,
      esCreadorFamilia: esCreadorFamilia ?? this.esCreadorFamilia,
      mostrarNotificacion: mostrarNotificacion ?? this.mostrarNotificacion,
      mostrarModalAlerta: mostrarModalAlerta ?? this.mostrarModalAlerta,
      dialogoAbierto: dialogoAbierto ?? this.dialogoAbierto,
      alertaActiva: alertaActiva ?? this.alertaActiva,
      ultimoMensajeIot: ultimoMensajeIot ?? this.ultimoMensajeIot,
      ultimoMensajeMostrado: ultimoMensajeMostrado ?? this.ultimoMensajeMostrado,
      mensajeAlerta: mensajeAlerta ?? this.mensajeAlerta,
      cargandoUsuario: cargandoUsuario ?? this.cargandoUsuario,
      ultimoTimestampAlertasIoT: ultimoTimestampAlertasIoT ?? this.ultimoTimestampAlertasIoT,
      ultimoTimestampVisto: ultimoTimestampVisto ?? this.ultimoTimestampVisto,
      ultimaSacudida: ultimaSacudida ?? this.ultimaSacudida,
    );
  }
}
