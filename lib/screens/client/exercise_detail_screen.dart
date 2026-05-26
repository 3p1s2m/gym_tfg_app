import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/api_constants.dart';

class EjercicioDetalleScreen extends StatefulWidget {
  final Map<String, dynamic> ejercicio;
  final bool modoSeleccion; // 👇 Vuelve la variable para saber si mostramos el botón de añadir

  const EjercicioDetalleScreen({super.key, required this.ejercicio, this.modoSeleccion = false});

  @override
  State<EjercicioDetalleScreen> createState() => _EjercicioDetalleScreenState();
}

class _EjercicioDetalleScreenState extends State<EjercicioDetalleScreen> {
  bool _cargandoHistorial = true;
  List<dynamic> _historialDelEjercicio = [];

  @override
  void initState() {
    super.initState();
    _cargarHistorialEspecifico();
  }

  // 👇 Magia: Nos traemos el historial y filtramos SOLO las veces que hicimos este ejercicio
  Future<void> _cargarHistorialEspecifico() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return;

      final response = await http.get(
        Uri.parse("${ApiConstants.baseUrl}/entrenamientos/historial"),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        List<dynamic> todoElHistorial = jsonDecode(response.body);
        List<dynamic> historialFiltrado = [];

        for (var entreno in todoElHistorial) {
          List<dynamic> setsDeEsteEjercicio = [];
          var sets = entreno["sets"] ?? entreno["setsRealizados"] ?? [];

          for (var s in sets) {
            // Comprobamos si el ID del ejercicio coincide con el que estamos viendo
            if (s["ejercicio"] != null && s["ejercicio"]["idEjercicio"] == widget.ejercicio["idEjercicio"]) {
              setsDeEsteEjercicio.add(s);
            }
          }

          // Si ese día hicimos este ejercicio, lo guardamos en la lista filtrada
          if (setsDeEsteEjercicio.isNotEmpty) {
            historialFiltrado.add({
              "fecha": entreno["fecha"],
              "sets": setsDeEsteEjercicio
            });
          }
        }

        if (mounted) {
          setState(() {
            _historialDelEjercicio = historialFiltrado;
            _cargandoHistorial = false;
          });
        }
      } else {
        if (mounted) setState(() => _cargandoHistorial = false);
      }
    } catch (e) {
      if (mounted) setState(() => _cargandoHistorial = false);
    }
  }

  // --- ESCUDO PARA LAS FECHAS DE JAVA ---
  String _formatearFecha(dynamic f) {
    if (f == null) return "Fecha desconocida";
    try {
      DateTime fechaLimpia;
      if (f is String) {
        fechaLimpia = DateTime.parse(f);
      } else if (f is List && f.length >= 3) {
        fechaLimpia = DateTime(f[0], f[1], f[2]);
      } else {
        return "Fecha inválida";
      }
      return "${fechaLimpia.day.toString().padLeft(2, '0')}/${fechaLimpia.month.toString().padLeft(2, '0')}/${fechaLimpia.year}";
    } catch (e) {
      return "Fecha desconocida";
    }
  }

  @override
  Widget build(BuildContext context) {
    String nombre = widget.ejercicio["nombre"] ?? "Ejercicio";
    String imagenUrl = widget.ejercicio["urlMedia"] ?? "";
    String descripcion = widget.ejercicio["descripcion"] ?? "Sin descripción.";
    String musculoPrincipal = widget.ejercicio["grupoMuscular"] ?? "General";
    String nivel = widget.ejercicio["nivel"] ?? "-";
    String equipamiento = widget.ejercicio["equipamiento"] ?? "-";

    // Colores dinámicos adaptados al tema
    Color colorSuperficie = Theme.of(context).colorScheme.surface;
    Color colorTexto = Theme.of(context).colorScheme.onSurface;
    Color colorBorde = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(nombre.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        ),
        
        // 👇 AQUÍ VUELVE EL BOTÓN DE AÑADIR (Solo si modoSeleccion es true)
        floatingActionButton: widget.modoSeleccion
            ? FloatingActionButton.extended(
                backgroundColor: Theme.of(context).primaryColor,
                onPressed: () => Navigator.pop(context, widget.ejercicio),
                icon: const Icon(Icons.add, color: Colors.black),
                label: const Text("Añadir a Rutina", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              )
            : null,

        body: Column(
          children: [
            // IMAGEN (Ahora se adapta al fondo y no tiene el recuadro blanco feo)
            Container(
              width: double.infinity,
              height: 220,
              color: Theme.of(context).scaffoldBackgroundColor,
              child: imagenUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imagenUrl,
                      fit: BoxFit.cover,
                      imageBuilder: (context, imageProvider) => Semantics(
                        label: nombre,
                        child: Image(image: imageProvider, fit: BoxFit.cover),
                      ),
                      errorWidget: (context, url, error) => ExcludeSemantics(child: Icon(Icons.fitness_center, size: 80, color: colorTexto.withValues(alpha: 0.2))),
                    )
                  : Semantics(label: 'Imagen no disponible', child: Icon(Icons.image_not_supported, size: 80, color: colorTexto.withValues(alpha: 0.2))),
            ),
            
            Container(
              color: colorSuperficie,
              child: TabBar(
                indicatorColor: Theme.of(context).primaryColor,
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(icon: Icon(Icons.info_outline), text: "Información"),
                  Tab(icon: Icon(Icons.history), text: "Mis Récords"),
                ],
              ),
            ),

            Expanded(
              child: TabBarView(
                children: [
                  // PESTAÑA 1: INFO
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildEtiquetaInfo(musculoPrincipal, Theme.of(context).primaryColor),
                            const SizedBox(width: 10),
                            _buildEtiquetaInfo(nivel, Colors.orange),
                            const SizedBox(width: 10),
                            _buildEtiquetaInfo(equipamiento, Colors.blueGrey),
                          ],
                        ),
                        const SizedBox(height: 25),
                        Text("Ejecución", style: TextStyle(color: colorTexto, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Text(
                          descripcion.replaceAll("<p>", "").replaceAll("</p>", "\n").replaceAll("<li>", "• ").replaceAll("</li>", ""),
                          style: const TextStyle(color: Colors.grey, height: 1.5, fontSize: 14),
                        ),
                      ],
                    ),
                  ),

                  // PESTAÑA 2: RÉCORDS
                  _cargandoHistorial
                      ? Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))
                      : _historialDelEjercicio.isEmpty
                          ? const Center(child: Text("Aún no has registrado este ejercicio.\n¡Dale duro la próxima vez!", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                              padding: const EdgeInsets.all(15),
                              itemCount: _historialDelEjercicio.length,
                              itemBuilder: (context, index) {
                                var entreno = _historialDelEjercicio[index];
                                List<dynamic> sets = entreno["sets"];
                                
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 15),
                                  decoration: BoxDecoration(color: colorSuperficie, borderRadius: BorderRadius.circular(15), border: Border.all(color: colorBorde)),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                                        decoration: BoxDecoration(color: Theme.of(context).primaryColor.withValues(alpha: 0.15), borderRadius: const BorderRadius.vertical(top: Radius.circular(15))),
                                        child: Row(
                                          children: [
                                            Icon(Icons.calendar_month, color: Theme.of(context).primaryColor, size: 18),
                                            const SizedBox(width: 8),
                                            Text(_formatearFecha(entreno["fecha"]), style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(15.0),
                                        child: Column(
                                          children: sets.asMap().entries.map((entry) {
                                            int numeroSerie = entry.key + 1;
                                            var s = entry.value;
                                            double peso = (s["pesoKg"] ?? s["peso"] ?? 0).toDouble();
                                            int reps = (s["repeticiones"] ?? s["reps"] ?? 0).toInt();

                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 8.0),
                                              child: MergeSemantics(child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text("Serie $numeroSerie", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                                                  Row(
                                                    children: [
                                                      Text("$peso kg", style: TextStyle(color: colorTexto, fontSize: 16, fontWeight: FontWeight.bold)),
                                                      const ExcludeSemantics(child: Text("  x  ", style: TextStyle(color: Colors.grey))),
                                                      Text("$reps reps", style: TextStyle(color: colorTexto, fontSize: 16, fontWeight: FontWeight.bold)),
                                                      const SizedBox(width: 10),
                                                      const ExcludeSemantics(child: Icon(Icons.check_circle, color: Colors.green, size: 18)),
                                                    ],
                                                  )
                                                ],
                                              )),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget auxiliar para pintar los globitos de información
  Widget _buildEtiquetaInfo(String texto, Color color) {
    if (texto == "-") return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        texto,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}