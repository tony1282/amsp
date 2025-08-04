import 'dart:convert'; // Para convertir texto JSON a objetos de Dart
import 'package:http/http.dart' as http; // Librería para hacer solicitudes HTTP
import '../models/inegi_data.dart'; // Modelo para los datos del INEGI

class InegiService {
  // Token de acceso para la API del INEGI (reemplaza con tu token real)
  static const String _token = '84a5a5b9-ffa1-47f5-9147-1e44f68822eb';

  // URL completa de la API con parámetros para obtener indicadores específicos en formato JSON
  static const String _url = 'https://www.inegi.org.mx/app/api/indicadores/desarrolladores/jsonxml/INDICATOR/6200028526/es/0700/true/BISE/2.0/$_token?type=json';

  // Método estático para obtener la lista de indicadores desde la API del INEGI
  static Future<List<IndicadorInegi>> obtenerIndicadores() async {
    // Realiza la petición HTTP GET a la URL
    final response = await http.get(Uri.parse(_url));

    // Si la respuesta es exitosa (código 200)
    if (response.statusCode == 200) {
      // Decodifica la respuesta JSON en un mapa de datos
      final data = json.decode(response.body);

      // Extrae la lista de observaciones dentro del JSON (camino: Series -> primer elemento -> OBSERVATIONS)
      final observaciones = data['Series'][0]['OBSERVATIONS'] as List;

      // Convierte cada observación en un objeto IndicadorInegi usando el método fromJson del modelo
      return observaciones.map((obs) => IndicadorInegi.fromJson(obs)).toList();
    } else {
      // Si la respuesta no fue exitosa, lanza una excepción con mensaje de error
      throw Exception('Error al obtener datos del INEGI');
    }
  }
}
