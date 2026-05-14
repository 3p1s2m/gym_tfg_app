import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_constants.dart';

class ExerciseService {
  static const String _storageKey = 'cached_exercises';

  // Memoria RAM ultrarrápida (para no tener que leer el disco duro del móvil todo el rato)
  static List<Map<String, dynamic>> _memCache = [];

  // --- 1. LEER LOS EJERCICIOS (Velocidad de la luz) ---
  static Future<List<Map<String, dynamic>>> getExercises() async {
    // Si ya los tenemos en la memoria RAM, los devolvemos en 0.001 segundos
    if (_memCache.isNotEmpty) return _memCache;

    // Si no están en RAM, miramos en el disco duro del móvil (SharedPreferences)
    final prefs = await SharedPreferences.getInstance();
    final String? cachedData = prefs.getString(_storageKey);

    if (cachedData != null) {
      // Traducimos el texto guardado a una Lista de Flutter
      List<dynamic> decoded = jsonDecode(cachedData);
      _memCache = List<Map<String, dynamic>>.from(decoded);
      return _memCache;
    }

    // Si no hay absolutamente nada guardado, devolvemos una lista vacía
    return [];
  }

  // --- 2. DESCARGAR DE JAVA Y GUARDAR EN EL MÓVIL (Silencioso) ---
  static Future<void> syncExercisesWithServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return; // Si no hay usuario logueado, no hacemos nada

      // OJO: Esta URL debe ser tu endpoint real de Java que devuelve la lista de ejercicios
      final url = Uri.parse(ApiConstants.getEjercicios);

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // 1. Guardamos el texto JSON gigante en el disco del móvil
        await prefs.setString(_storageKey, response.body);

        // 2. Lo cargamos en la memoria RAM para usarlo hoy
        List<dynamic> decoded = jsonDecode(response.body);
        _memCache = List<Map<String, dynamic>>.from(decoded);

        print("✅ ÉXITO: Ejercicios descargados de Java y guardados en la caché local.");
      } else {
        print("⚠️ Fallo al descargar ejercicios. Código: ${response.statusCode}");
      }
    } catch (e) {
      print("⚠️ Error de red sincronizando ejercicios: $e");
    }
  }
}