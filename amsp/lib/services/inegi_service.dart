import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/inegi_data.dart';

class InegiService {
  static const String _token = '84a5a5b9-ffa1-47f5-9147-1e44f68822eb'; // Sustituye con tu token
  static const String _url = 'https://www.inegi.org.mx/app/api/indicadores/desarrolladores/jsonxml/INDICATOR/6200028526/es/0700/true/BISE/2.0/$_token?type=json';

  static Future<List<IndicadorInegi>> obtenerIndicadores() async {
    final response = await http.get(Uri.parse(_url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final observaciones = data['Series'][0]['OBSERVATIONS'] as List;

      return observaciones.map((obs) => IndicadorInegi.fromJson(obs)).toList();
    } else {
      throw Exception('Error al obtener datos del INEGI');
    }
  }
}
