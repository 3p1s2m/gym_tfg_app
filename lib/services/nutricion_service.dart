import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/alimento.dart';

class NutricionService {
  final String _apiKey = "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";

  Future<List<Alimento>> buscarAlimentos(String consulta) async {
    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

    final body = {
      "model": "openrouter/auto",
      "messages": [
        {
          "role": "user",
          "content": "Analiza: $consulta. Devuelve solo un JSON array con este formato: [{\"label\": \"nombre\", \"nutrients\": {\"ENERC_KCAL\": 100, \"PROCNT\": 10, \"CHOCDF\": 5, \"FAT\": 2}}]. Sin texto extra, solo el JSON."
        }
      ]
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode(body),
      );

      print("Status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String textOutput = data['choices'][0]['message']['content'];
        textOutput = textOutput.replaceAll('```json', '').replaceAll('```', '').trim();
        print("Texto recibido: $textOutput");
        final List<dynamic> jsonData = jsonDecode(textOutput);
        return jsonData.map((item) => Alimento.fromJson(item)).toList();
      } else {
        print("❌ Error: ${response.body}");
      }
    } catch (e) {
      print("❌ Error crítico: $e");
    }
    return [];
  }
}