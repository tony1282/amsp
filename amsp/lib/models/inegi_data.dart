class IndicadorInegi {
  final String periodo;
  final double valor;
  final String geoCode;

  IndicadorInegi({required this.periodo, required this.valor, required this.geoCode});

  factory IndicadorInegi.fromJson(Map<String, dynamic> json) {
    return IndicadorInegi(
      periodo: json['TIME_PERIOD'],
      valor: double.tryParse(json['OBS_VALUE']) ?? 0.0,
      geoCode: json['COBER_GEO'],
    );
  }
}
