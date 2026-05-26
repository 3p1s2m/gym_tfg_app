import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_constants.dart';

class CoachCatalogScreen extends StatefulWidget {
  const CoachCatalogScreen({super.key});

  @override
  State<CoachCatalogScreen> createState() => _CoachCatalogScreenState();
}

class _CoachCatalogScreenState extends State<CoachCatalogScreen> {
  List<dynamic> _entrenadores = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarEntrenadores();
  }

  Future<void> _cargarEntrenadores() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final response = await http.get(
        Uri.parse("${ApiConstants.baseUrl}/usuarios/entrenadores"),
        headers: {'Authorization': 'Bearer $token'}
    );

    if (response.statusCode == 200) {
      if (mounted) setState(() {
        _entrenadores = jsonDecode(utf8.decode(response.bodyBytes));
        _cargando = false;
      });
    }
  }

  Future<void> _contratar(int idEntrenador) async {
    setState(() => _cargando = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final response = await http.post(
        Uri.parse("${ApiConstants.baseUrl}/usuarios/contratar/$idEntrenador"),
        headers: {'Authorization': 'Bearer $token'}
    );

    if (response.statusCode == 200) {
      // Guardamos en memoria que ya tenemos coach
      await prefs.setBool('tiene_entrenador', true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ ¡Entrenador contratado!'), backgroundColor: Colors.green));
        Navigator.pop(context, true); // Cerramos el catálogo devolviendo 'true'
      }
    }
  }

  void _mostrarConfirmacion(Map<String, dynamic> coach) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text("¿Elegir a ${coach["nombre"]}?"),
          content: const Text("Al confirmar, este entrenador tendrá acceso a tus medidas, evolución y podrá asignarte rutinas personalizadas.", style: TextStyle(color: Colors.grey)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                onPressed: () {
                  Navigator.pop(context);
                  _contratar(coach["idUsuario"]);
                },
                child: const Text("SÍ, CONTRATAR", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))
            )
          ],
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("ELIGE A TU COACH", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: _cargando
          ? Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))
          : FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: _entrenadores.length,
              itemBuilder: (context, index) {
                final coach = _entrenadores[index];
                final especialidad = coach["especialidad"] ?? "Preparador Físico General";
                final biografia = coach["biografia"] ?? "Este entrenador aún no ha escrito su biografía, pero está listo para ayudarte a conseguir tus objetivos.";
                return Semantics(
                  label: '${coach["nombre"]}, $especialidad',
                  child: Card(
                    color: Theme.of(context).colorScheme.surface,
                    margin: const EdgeInsets.only(bottom: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white12)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Semantics(
                                label: 'Icono de entrenador',
                                excludeSemantics: true,
                                child: CircleAvatar(radius: 30, backgroundColor: Theme.of(context).primaryColor.withValues(alpha:0.2), child: Icon(Icons.sports, size: 30, color: Theme.of(context).primaryColor)),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(coach["nombre"], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                      Text(especialidad, style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
                                    ],
                                  )
                              )
                            ],
                          ),
                          const SizedBox(height: 15),
                          Text(biografia, style: const TextStyle(color: Colors.grey, height: 1.5)),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity, height: 45,
                            child: Tooltip(
                              message: 'Seleccionar a ${coach["nombre"]} como entrenador',
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                onPressed: () => _mostrarConfirmacion(coach),
                                child: Text("SELECCIONAR", style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
    );
  }
}