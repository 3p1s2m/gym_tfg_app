import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/api_constants.dart';
import '../../../main.dart';

class TabFrecuencia extends StatefulWidget {
  final int? idCliente; // Si no es null, somos el Coach
  const TabFrecuencia({super.key, this.idCliente});

  @override
  State<TabFrecuencia> createState() => _TabFrecuenciaState();
}

class _TabFrecuenciaState extends State<TabFrecuencia> {
  bool _cargando = true;
  bool _esFrente = true;
  Map<String, Map<String, dynamic>> _datosVolumen = {};

  final Map<String, String> _nombresLegibles = {
    "chest": "Pectorales", "abs_core": "Abdomen y Core", "shoulders": "Hombros",
    "biceps": "Bíceps", "triceps": "Tríceps", "forearms": "Antebrazos", "neck": "Cuello",
    "back_high": "Espalda Alta", "lats": "Dorsales", "back_low": "Espalda Baja",
    "quads": "Cuádriceps", "hamstrings": "Isquiosurales", "glutes": "Glúteos",
    "calves": "Gemelos", "adductors": "Aductores", "abductors": "Abductores"
  };

  @override
  void initState() { super.initState(); _cargarDatos(); }

  Future<void> _cargarDatos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return;

      String urlBase = widget.idCliente != null
          ? "${ApiConstants.baseUrl}/entrenamientos/coach/cliente/${widget.idCliente}/mapa-calor"
          : ApiConstants.mapaCalor;

      final response = await http.get(Uri.parse(urlBase), headers: {'Authorization': 'Bearer $token'});

      debugPrint("🗺️ MAPA CALOR status: ${response.statusCode}");
      debugPrint("🗺️ MAPA CALOR body: ${response.body}");
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _datosVolumen = Map<String, dynamic>.from(jsonDecode(response.body))
                .map((key, value) => MapEntry(key, Map<String, dynamic>.from(value)));
            _cargando = false;
          });
          debugPrint("🗺️ MAPA CALOR keys: ${_datosVolumen.keys.toList()}");
          debugPrint("🗺️ chest hechas: ${_datosVolumen['chest']?['hechas']}");
        }
      } else {
        if (mounted) setState(() => _cargando = false);
      }
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _actualizarObjetivo(String musculo, int nuevoObjetivo) async {
    if (nuevoObjetivo < 0) return;

    // IDEA 2: Si el usuario intenta cambiar algo bloqueado, no le dejamos
    bool fijadoPorCoach = _datosVolumen[musculo]?["fijadoPorCoach"] ?? false;
    if (widget.idCliente == null && fijadoPorCoach) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🔒 Tu Entrenador ha bloqueado este objetivo.')));
      return;
    }

    setState(() => _datosVolumen[musculo]!["objetivo"] = nuevoObjetivo);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      // ARREGLO DEL BUG: El coach usa una ruta distinta para guardar en el cliente
      String postUrl = widget.idCliente != null
          ? ApiConstants.guardarObjetivosCoach(widget.idCliente!)
          : ApiConstants.guardarObjetivos;

      await http.post(
        Uri.parse(postUrl),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({"musculo": musculo, "seriesObjetivo": nuevoObjetivo}),
      );
    } catch (e) { print(e); }
  }

  // IDEA 4: Banner de Racha
  Widget _buildBannerRacha() {
    int activos = 0; int cumplidos = 0;
    _datosVolumen.forEach((k, d) {
      int obj = d["objetivo"] ?? 0;
      double hechas = d["hechas"] ?? 0.0;
      if (obj > 0) {
        activos++;
        if (hechas >= obj) cumplidos++;
      }
    });

    if (activos == 0) return const SizedBox.shrink();
    bool semanaPerfecta = (activos == cumplidos);

    final labelRacha = semanaPerfecta ? "Semana perfecta, todos los objetivos cumplidos" : "Objetivos de volumen cumplidos: $cumplidos de $activos esta semana";
    return Semantics(
      label: labelRacha,
      container: true,
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 8),
          color: semanaPerfecta ? Colors.orange.shade900 : Colors.black26,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(semanaPerfecta ? Icons.local_fire_department : Icons.tablet_outlined, color: semanaPerfecta ? Colors.yellow : Colors.grey, size: 20),
              const SizedBox(width: 8),
              Text(semanaPerfecta ? "¡SEMANA PERFECTA! 🔥" : "Objetivos cumplidos: $cumplidos / $activos", style: TextStyle(color: semanaPerfecta ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ],
          ),
        ),
      ),
    );
  }

  Color _getColorDinamico(double hechas, int objetivo, Color colorTema) {
    if (hechas <= 0) return Colors.transparent;

    if (objetivo == 0) {
      // Sin objetivo: escala absoluta (0–20 series/semana)
      double alpha = (hechas / 20.0).clamp(0.2, 1.0);
      return colorTema.withValues(alpha: alpha);
    }

    double porcentaje = (hechas / objetivo) * 100;
    if (porcentaje < 50) return colorTema.withValues(alpha: 0.35);
    else if (porcentaje < 100) return colorTema.withValues(alpha: 0.7);
    else if (porcentaje <= 120) return colorTema;
    else return Color.lerp(colorTema, Colors.black, 0.4) ?? Colors.black;
  }

  List<Widget> _buildCapasAgrupadas(String idBackend, List<String> imagenes, String generoVisualActual, Color colorTema) {
    List<Widget> capas = [];
    double hechas = _datosVolumen[idBackend]?["hechas"] ?? 0.0;
    int objetivo = _datosVolumen[idBackend]?["objetivo"] ?? 0;
    Color colorPintar = _getColorDinamico(hechas, objetivo, colorTema);

    if (colorPintar != Colors.transparent) {
      for (String musculo in imagenes) {
        capas.add(
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(colorPintar, BlendMode.srcIn),
                  child: Image.asset('assets/images/partes/mask_${generoVisualActual}_${_esFrente ? "frente" : "espalda"}_$musculo.png', fit: BoxFit.contain, errorBuilder: (c, e, s) => const SizedBox.shrink()),
                ),
              ),
            ),
          ),
        );
      }
    }
    return capas;
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor));

    return ValueListenableBuilder<String>(
      valueListenable: appGenero,
      builder: (context, generoActual, child) {
        String genero = (generoActual.isEmpty || generoActual == "otro") ? "hombre" : generoActual;
        Color temaApp = Theme.of(context).primaryColor;

        return Column(
          children: [
            _buildBannerRacha(),
            Expanded(
              flex: 5,
              child: Container(
                color: Colors.black12,
                child: Center(
                  child: SizedBox(
                    width: 300, height: 520,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(child: Semantics(label: _esFrente ? "Vista frontal del cuerpo, toca para ver espalda" : "Vista trasera del cuerpo, toca para ver frente", button: true, child: GestureDetector(onTap: () => setState(() => _esFrente = !_esFrente), child: Image.asset('assets/images/body_${genero}_${_esFrente ? "frente" : "espalda"}.png', fit: BoxFit.contain)))),
                        if (_esFrente) ...[
                          ..._buildCapasAgrupadas('chest', ['chest'], genero, temaApp),
                          ..._buildCapasAgrupadas('abs_core', ['abdominals'], genero, temaApp),
                          ..._buildCapasAgrupadas('quads', ['quadriceps', 'sartorio'], genero, temaApp),
                          ..._buildCapasAgrupadas('biceps', ['biceps'], genero, temaApp),
                          ..._buildCapasAgrupadas('shoulders', ['shoulders'], genero, temaApp),
                          ..._buildCapasAgrupadas('forearms', ['forearms'], genero, temaApp),
                          ..._buildCapasAgrupadas('neck', ['neck'], genero, temaApp),
                          ..._buildCapasAgrupadas('adductors', ['adductors'], genero, temaApp),
                          ..._buildCapasAgrupadas('abductors', ['abductors'], genero, temaApp),
                          ..._buildCapasAgrupadas('calves', ['calves'], genero, temaApp),
                          ..._buildCapasAgrupadas('triceps', ['triceps'], genero, temaApp),
                        ] else ...[
                          ..._buildCapasAgrupadas('back_high', ['traps'], genero, temaApp),
                          ..._buildCapasAgrupadas('back_low', ['lumbar', 'obliques'], genero, temaApp),
                          ..._buildCapasAgrupadas('lats', ['lats'], genero, temaApp),
                          ..._buildCapasAgrupadas('triceps', ['triceps'], genero, temaApp),
                          ..._buildCapasAgrupadas('glutes', ['glutes'], genero, temaApp),
                          ..._buildCapasAgrupadas('hamstrings', ['hamstrings'], genero, temaApp),
                          ..._buildCapasAgrupadas('calves', ['calves'], genero, temaApp),
                          ..._buildCapasAgrupadas('shoulders', ['shoulders'], genero, temaApp),
                          ..._buildCapasAgrupadas('forearms', ['forearms'], genero, temaApp),
                          ..._buildCapasAgrupadas('adductors', ['adductors'], genero, temaApp),
                          ..._buildCapasAgrupadas('abductors', ['abductors'], genero, temaApp),
                          ..._buildCapasAgrupadas('neck', ['neck'], genero, temaApp),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Container(padding: const EdgeInsets.symmetric(vertical: 5), width: double.infinity, color: Theme.of(context).appBarTheme.backgroundColor, child: Text(_esFrente ? "VISTA FRONTAL (Toca para girar)" : "VISTA TRASERA (Toca para girar)", textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 2))),
            Expanded(
              flex: 5,
              child: ListView.builder(
                padding: const EdgeInsets.all(15),
                itemCount: _nombresLegibles.length,
                itemBuilder: (context, index) {
                  String keyInterna = _nombresLegibles.keys.elementAt(index);
                  String nombreBonito = _nombresLegibles.values.elementAt(index);
                  double hechas = _datosVolumen[keyInterna]?["hechas"] ?? 0.0;
                  int objetivo = _datosVolumen[keyInterna]?["objetivo"] ?? 0;
                  bool fijadoPorCoach = _datosVolumen[keyInterna]?["fijadoPorCoach"] ?? false;

                  double progreso = objetivo > 0 ? (hechas / objetivo) : 0.0;
                  bool fatigado = progreso > 1.2; // IDEA 3: Detección de fatiga

                  Widget inkWellRow = InkWell(
                    // IDEA 3: Alerta de fatiga al tocar el panel del músculo
                    onTap: fatigado ? () {
                      showDialog(context: context, builder: (_) => AlertDialog(
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.orange), SizedBox(width: 10), Text("Músculo Fatigado")]),
                        content: Text("Has superado el 120% de tu volumen óptimo semanal para $nombreBonito. Te recomendamos darle 48h de descanso a esta zona para evitar lesiones."),
                        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text("Entendido", style: TextStyle(color: temaApp)))],
                      ));
                    } : null,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 15), padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(15), border: Border.all(color: fatigado ? Colors.orange : Colors.white12)),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(nombreBonito, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  if (fatigado) const Padding(padding: EdgeInsets.only(left: 8.0), child: Icon(Icons.warning, color: Colors.orange, size: 16)),
                                ],
                              ),
                              Row(
                                children: [
                                  // IDEA 2: Si el coach lo fijó y tú eres el usuario, ves un candado. Si eres el coach, ves los botones normales.
                                  if (fijadoPorCoach && widget.idCliente == null) ...[
                                    const Icon(Icons.lock, color: Colors.amber, size: 16),
                                    const SizedBox(width: 5),
                                    Text("$objetivo sets", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
                                  ] else ...[
                                    IconButton(tooltip: 'Reducir objetivo de series', icon: const Icon(Icons.remove_circle_outline, color: Colors.grey), onPressed: () => _actualizarObjetivo(keyInterna, objetivo - 1)),
                                    Text("$objetivo sets", style: TextStyle(color: temaApp, fontWeight: FontWeight.bold, fontSize: 16)),
                                    IconButton(tooltip: 'Aumentar objetivo de series', icon: const Icon(Icons.add_circle_outline, color: Colors.grey), onPressed: () => _actualizarObjetivo(keyInterna, objetivo + 1)),
                                  ]
                                ],
                              )
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Text("${hechas.toStringAsFixed(1)} hechas", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Semantics(
                                  label: '$nombreBonito: ${hechas.toStringAsFixed(1)} series realizadas${objetivo > 0 ? " de $objetivo objetivo, ${(progreso * 100).clamp(0, 100).toStringAsFixed(0)} por ciento" : ""}',
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: LinearProgressIndicator(
                                      value: progreso > 1.0 ? 1.0 : progreso,
                                      minHeight: 8, backgroundColor: Colors.white10,
                                      valueColor: AlwaysStoppedAnimation<Color>(fatigado ? Colors.orange : temaApp),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                  return fatigado
                      ? Semantics(hint: 'Toca para ver advertencia de fatiga', child: inkWellRow)
                      : inkWellRow;
                },
              ),
            )
          ],
        );
      },
    );
  }
}