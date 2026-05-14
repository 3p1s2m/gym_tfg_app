import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/api_constants.dart';
import '../../../widgets/logro_dialog.dart';

class TabLogros extends StatefulWidget {
  final int? idCliente; // 👈 NUEVO: Para ver logros de un cliente específico desde coach
  const TabLogros({super.key, this.idCliente});

  @override
  State<TabLogros> createState() => _TabLogrosState();
}

class _TabLogrosState extends State<TabLogros> {
  List<dynamic> _catalogoLogros = [];
  List<dynamic> _misLogros = [];
  bool _cargandoLogros = true;

  @override
  void initState() {
    super.initState();
    _cargarLogros();
  }

  Future<void> _cargarLogros() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return;

      String catalogoEndpoint = ApiConstants.catalogoLogros;
      String misLogrosEndpoint = widget.idCliente != null 
          ? "${ApiConstants.baseUrl}/coach/cliente/${widget.idCliente}/logros"
          : ApiConstants.misLogros;
      
      final resCatalogo = await http.get(Uri.parse(catalogoEndpoint), headers: {'Authorization': 'Bearer $token'});
      final resMisLogros = await http.get(Uri.parse(misLogrosEndpoint), headers: {'Authorization': 'Bearer $token'});

      print("Catalogo status: ${resCatalogo.statusCode}");
      print("Catalogo body: ${resCatalogo.body}");
      print("MisLogros status: ${resMisLogros.statusCode}");
      print("MisLogros body: ${resMisLogros.body}");

      if (resCatalogo.statusCode == 200 && resMisLogros.statusCode == 200) {
        if (mounted) {
          setState(() {
            try {
              _catalogoLogros = List<dynamic>.from(jsonDecode(resCatalogo.body));
            } catch (e) {
              print("Error decoding catalogo: $e");
              _catalogoLogros = [];
            }
            try {
              _misLogros = List<dynamic>.from(jsonDecode(resMisLogros.body));
            } catch (e) {
              print("Error decoding misLogros: $e");
              _misLogros = [];
            }
            _cargandoLogros = false;
          });
        }
        print("Decoded catalogo length: ${_catalogoLogros.length}");
        print("Decoded misLogros length: ${_misLogros.length}");
        print("Catálogo: ${_catalogoLogros.length} logros");
        print("Mis Logros: ${_misLogros.length} logros");
      } else {
        if (mounted) setState(() => _cargandoLogros = false);
      }
    } catch (e) {
      print("Error cargando logros: $e");
      if (mounted) setState(() => _cargandoLogros = false);
    }
  }

  IconData _obtenerIconoParaLogro(String nombre) {
    String n = nombre.toLowerCase();
    if (n.contains("tiempo") || n.contains("sólida")) return Icons.timer;
    if (n.contains("racha") || n.contains("semana") || n.contains("hábito") || n.contains("año")) return Icons.calendar_month;
    if (n.contains("disco") || n.contains("pluma") || n.contains("fuerza") || n.contains("muro") || n.contains("pesado")) return Icons.fitness_center;
    if (n.contains("pierna")) return Icons.directions_run;
    if (n.contains("volumen") || n.contains("motores") || n.contains("máquina") || n.contains("atlas")) return Icons.electric_bolt;
    if (n.contains("medida") || n.contains("cuerpo") || n.contains("simetría") || n.contains("metódico") || n.contains("culturista")) return Icons.accessibility_new;
    if (n.contains("arquitecto")) return Icons.edit_document;
    return Icons.emoji_events;
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoLogros) return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
    if (_catalogoLogros.isEmpty) return const Center(child: Text("No hay logros disponibles", style: TextStyle(color: Colors.grey)));

    return GridView.builder(
      padding: const EdgeInsets.all(15),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 15,
        mainAxisSpacing: 25,
        childAspectRatio: 0.7,
      ),
      itemCount: _catalogoLogros.length,
      itemBuilder: (context, index) {
        var logro = _catalogoLogros[index];
        bool estaDesbloqueado = _misLogros.any((miLogro) => miLogro["logro"]["idLogro"] == logro["idLogro"]);
        String rutaImagen = "assets/images/${logro['iconoUrl']}";
        IconData iconoInterno = _obtenerIconoParaLogro(logro["nombre"]);

        return Column(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  showDialog(
                      context: context,
                      barrierDismissible: true,
                      builder: (BuildContext context) {
                        return Dialog(
                          backgroundColor: const Color(0xFF1C1C1E),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          child: Padding(
                            padding: const EdgeInsets.all(25.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  height: 120, width: 120,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      estaDesbloqueado
                                          ? Image.asset(rutaImagen, fit: BoxFit.cover)
                                          : ColorFiltered(
                                        colorFilter: const ColorFilter.matrix([0.2126, 0.7152, 0.0722, 0, 0, 0.2126, 0.7152, 0.0722, 0, 0, 0.2126, 0.7152, 0.0722, 0, 0, 0, 0, 0, 0.4, 0]),
                                        child: Image.asset(rutaImagen, fit: BoxFit.cover),
                                      ),
                                      Icon(iconoInterno, size: 40, color: estaDesbloqueado ? Colors.white : Colors.white24)
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(logro["nombre"], textAlign: TextAlign.center, style: const TextStyle(color: Colors.cyanAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 10),
                                Text(logro["descripcion"], textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                              ],
                            ),
                          ),
                        );
                      }
                  );
                },
                child: TweenAnimationBuilder(
                  tween: Tween<double>(begin: 0.8, end: estaDesbloqueado ? 1.0 : 0.85),
                  duration: const Duration(milliseconds: 800),
                  builder: (context, double scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        decoration: estaDesbloqueado ? BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: obtenerColorGlow(logro["dificultad"]), blurRadius: 15, spreadRadius: 2)]) : null,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            estaDesbloqueado
                                ? Image.asset(rutaImagen)
                                : ColorFiltered(
                              colorFilter: const ColorFilter.matrix([0.2126, 0.7152, 0.0722, 0, 0, 0.2126, 0.7152, 0.0722, 0, 0, 0.2126, 0.7152, 0.0722, 0, 0, 0, 0, 0, 0.4, 0]),
                              child: Image.asset(rutaImagen),
                            ),
                            Icon(iconoInterno, size: 24, color: estaDesbloqueado ? Colors.white : Colors.white24)
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(logro["nombre"], textAlign: TextAlign.center, maxLines: 2, style: TextStyle(color: estaDesbloqueado ? Colors.white : Colors.white38, fontSize: 10, fontWeight: estaDesbloqueado ? FontWeight.bold : FontWeight.normal))
          ],
        );
      },
    );
  }
}