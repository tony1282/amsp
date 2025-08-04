class IndicadorInegi {
  final String periodo; // Periodo del indicador (por ejemplo, año o trimestre)
  final double valor;   // Valor numérico del indicador
  final String geoCode; // Código geográfico asociado al dato

  // Constructor con parámetros requeridos
  IndicadorInegi({
    required this.periodo,
    required this.valor,
    required this.geoCode,
  });

  // Fábrica para crear una instancia desde un JSON (mapa)
  factory IndicadorInegi.fromJson(Map<String, dynamic> json) {
    return IndicadorInegi(
      periodo: json['TIME_PERIOD'],                         // Obtiene el periodo
      valor: double.tryParse(json['OBS_VALUE']) ?? 0.0,     // Intenta convertir a double o pone 0.0
      geoCode: json['COBER_GEO'],                           // Código geográfico
    );
  }
}
