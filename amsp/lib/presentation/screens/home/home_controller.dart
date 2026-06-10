import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;

import 'package:amsp/alerts/handlers/iot_alert_handler.dart';
import 'package:amsp/alerts/handlers/smart_alert_handler.dart';
import 'package:amsp/alerts/modals/iot_alert_modal.dart';
import 'package:amsp/alerts/modals/smart_alert_modal.dart';
import 'package:amsp/contacts/call_manager.dart';
import 'package:amsp/contacts/contacts_manager.dart';
import 'package:amsp/data/repositories/circle_repository.dart';
import 'package:amsp/data/repositories/user_repository.dart';
import 'package:amsp/map/managers/circles_manager.dart';
import 'package:amsp/map/managers/map_manager.dart';
import 'package:amsp/map/managers/alerts_manager.dart';
import 'package:amsp/map/managers/markers_manager.dart';
import 'package:amsp/map/managers/risk_zones_manager.dart';
import 'package:amsp/reports/historical_reports_manager.dart';
import 'package:amsp/map/services/location_service.dart';

import 'home_state.dart';

class HomeController extends ChangeNotifier {
  final MapAlerts alerts;
  final CircleUbications circleUbi;
  final MapFunctions map;
  final UserData user;
  final riskZones zone;
  final iotAlerts iot;
  final smartAlerts smart;
  final ModalIot modalI;
  final ModalSmart modalS;
  final CirculosService circleSer;
  final Markers mark;
  final Callfunctions calls;
  final PhoneNumberFunctions number;
  final HistoricalReport report;

  HomeState _state = HomeState();
  HomeState get state => _state;

  StreamSubscription<gl.Position>? _userPositionStream;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  final DatabaseReference _ref = FirebaseDatabase.instance.ref();
  final AudioPlayer _player = AudioPlayer();

  HomeController({
    MapAlerts? alerts,
    CircleUbications? circleUbi,
    MapFunctions? map,
    UserData? user,
    riskZones? zone,
    iotAlerts? iot,
    smartAlerts? smart,
    ModalIot? modalI,
    ModalSmart? modalS,
    CirculosService? circleSer,
    Markers? mark,
    Callfunctions? calls,
    PhoneNumberFunctions? number,
    HistoricalReport? report,
  }) :
    alerts = alerts ?? MapAlerts(),
    circleUbi = circleUbi ?? CircleUbications(),
    map = map ?? MapFunctions(),
    user = user ?? UserData(),
    zone = zone ?? riskZones(),
    iot = iot ?? iotAlerts(),
    smart = smart ?? smartAlerts(),
    modalI = modalI ?? ModalIot(),
    modalS = modalS ?? ModalSmart(),
    circleSer = circleSer ?? CirculosService(),
    mark = mark ?? Markers(),
    calls = calls ?? Callfunctions(),
    number = number ?? PhoneNumberFunctions(),
    report = report ?? HistoricalReport() {
    _init();
  }

  void _init() {
    map.seguirUsuario = true;
    _setupSensors();
    _loadUserData();
  }

  void _setupSensors() {
    _accelerometerSubscription = accelerometerEvents.listen((event) {
      final aceleracion = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      if (aceleracion > 30) {
        final ahora = DateTime.now();
        if (ahora.difference(_state.ultimaSacudida).inSeconds > 10) {
          _state = _state.copyWith(ultimaSacudida: ahora);
        }
      }
    });
  }

  Future<void> _loadUserData() async {
    await user.cargarDatosUsuario();
    _state = _state.copyWith(cargandoUsuario: false);
    notifyListeners();
  }

  void updateState(HomeState newState) {
    _state = newState;
    notifyListeners();
  }

  void toggleSeguirUsuario() {
    _state = _state.copyWith(seguirUsuario: !_state.seguirUsuario);
    notifyListeners();
  }

  void selectCircle(String id, String name) {
    _state = _state.copyWith(
      circuloSeleccionadoId: id,
      circuloSeleccionadoNombre: name,
    );
    notifyListeners();
  }

  void closeCircle() {
    _state = _state.copyWith(
      circuloSeleccionadoId: null,
      circuloSeleccionadoNombre: null,
    );
    notifyListeners();
  }

  void markNotificationAsRead() {
    _state = _state.copyWith(mostrarNotificacion: false);
    notifyListeners();
  }

  @override
  void dispose() {
    _userPositionStream?.cancel();
    _accelerometerSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }
}
