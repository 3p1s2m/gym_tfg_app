import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 👇 NUEVO: Para la vibración del móvil
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../widgets/logro_dialog.dart';
import '../../../services/api_constants.dart';
import '../exercise_selection_screen.dart';
import '../exercise_detail_screen.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  final Map<String, dynamic>? plantilla;
  const ActiveWorkoutScreen({super.key, this.plantilla});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _ejerciciosActivos = [];
  bool _cargandoFantasma = false;

  final DateTime _horaInicio = DateTime.now();
  Timer? _cronometroGeneral;
  int _segundosEntrenando = 0;

  // 👇 VARIABLES PARA EL TEMPORIZADOR DE DESCANSO MANUAL
  int _tiempoDescansoElegido = 90; // Por defecto 1 minuto y medio (90s)
  int _segundosRestantesDescanso = 0;
  bool _descansoActivo = false;
  Timer? _timerDescanso;

  // 👇 NUEVO: VARIABLE PARA SABER A QUÉ HORA MINIMIZAMOS LA APP
  DateTime? _tiempoUltimaPausa;

  String _formatearTiempo(int segundos) {
    int minutos = segundos ~/ 60;
    int segs = segundos % 60;
    return "${minutos.toString().padLeft(2, '0')}:${segs.toString().padLeft(2, '0')}";
  }

  String _formatearTiempoGeneral(int segundos) {
    int horas = segundos ~/ 3600;
    int minutos = (segundos % 3600) ~/ 60;
    int segs = segundos % 60;
    if (horas > 0) return "${horas.toString().padLeft(2, '0')}:${minutos.toString().padLeft(2, '0')}:${segs.toString().padLeft(2, '0')}";
    return "${minutos.toString().padLeft(2, '0')}:${segs.toString().padLeft(2, '0')}";
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 👈 NUEVO: Nos suscribimos a los eventos del móvil
    _prepararEntrenamiento();
    _cronometroGeneral = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _segundosEntrenando = DateTime.now().difference(_horaInicio).inSeconds);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // 👈 NUEVO: Nos desuscribimos al salir
    _cronometroGeneral?.cancel();
    _timerDescanso?.cancel(); 
    super.dispose();
  }

  // =======================================================================
  // 👇 EL ESCUDO CONTRA LA PAUSA DEL SISTEMA OPERATIVO 👇
  // =======================================================================
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // La app se ha minimizado (Ej: el usuario abre Spotify o WhatsApp)
      _tiempoUltimaPausa = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      // La app vuelve a estar en pantalla
      if (_tiempoUltimaPausa != null) {
        int segundosEnSegundoPlano = DateTime.now().difference(_tiempoUltimaPausa!).inSeconds;

        // El cronómetro general no se rompe porque calcula la diferencia desde "_horaInicio"
        // PERO al cronómetro de descanso hay que restarle el tiempo que hemos estado fuera:
        if (_descansoActivo) {
          setState(() {
            _segundosRestantesDescanso -= segundosEnSegundoPlano;
          });

          // Si el tiempo de descanso terminó mientras estábamos en la otra app:
          if (_segundosRestantesDescanso <= 0) {
            _segundosRestantesDescanso = 0;
            _descansoActivo = false;
            _timerDescanso?.cancel();

            // Hacemos vibrar el móvil y lanzamos el aviso de inmediato al volver
            for (int i = 0; i < 3; i++) {
              Future.delayed(Duration(milliseconds: i * 300), () => HapticFeedback.heavyImpact());
            }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('🔥 ¡Tiempo de descanso terminado! A por la siguiente serie.', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.green, duration: Duration(seconds: 4))
              );
            }
          }
        }
        _tiempoUltimaPausa = null; // Reseteamos la variable
      }
    }
  }

  // --- LÓGICA DEL DESCANSO MANUAL ---
  void _iniciarDescanso() {
    _timerDescanso?.cancel();
    setState(() {
      _segundosRestantesDescanso = _tiempoDescansoElegido;
      _descansoActivo = true;
    });

    _timerDescanso = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_segundosRestantesDescanso > 0) {
        if (mounted) setState(() => _segundosRestantesDescanso--);
      } else {
        timer.cancel();
        if (mounted) setState(() => _descansoActivo = false);

        // 📳 Hacemos vibrar el móvil 3 veces cuando termina el tiempo
        for (int i = 0; i < 3; i++) {
          Future.delayed(Duration(milliseconds: i * 300), () => HapticFeedback.heavyImpact());
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('🔥 ¡Tiempo de descanso terminado! A por la siguiente serie.', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.green, duration: Duration(seconds: 4))
          );
        }
      }
    });
  }

  void _detenerDescanso() {
    _timerDescanso?.cancel();
    setState(() {
      _descansoActivo = false;
      _segundosRestantesDescanso = 0;
    });
  }

  void _mostrarPanelDescanso() {
    showModalBottomSheet(
        context: context,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (BuildContext context) {
          return StatefulBuilder(
              builder: (context, setModalState) {
                return FocusTraversalGroup(
                  policy: ReadingOrderTraversalPolicy(),
                  child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Tiempo de Descanso", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 25),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: Icon(Icons.remove_circle_outline, color: Theme.of(context).primaryColor, size: 45),
                            onPressed: () {
                              if (_tiempoDescansoElegido > 15) setModalState(() => _tiempoDescansoElegido -= 15);
                            },
                          ),
                          Text(
                            _formatearTiempo(_tiempoDescansoElegido),
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 45, fontWeight: FontWeight.bold, fontFeatures: const [FontFeature.tabularFigures()]),
                          ),
                          IconButton(
                            icon: Icon(Icons.add_circle_outline, color: Theme.of(context).primaryColor, size: 45),
                            onPressed: () => setModalState(() => _tiempoDescansoElegido += 15),
                          ),
                        ],
                      ),
                      const SizedBox(height: 35),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (_descansoActivo)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                              onPressed: () { _detenerDescanso(); Navigator.pop(context); },
                              icon: const Icon(Icons.stop), label: const Text("Detener", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12)),
                            onPressed: () { _iniciarDescanso(); Navigator.pop(context); },
                            icon: const Icon(Icons.play_arrow), label: Text(_descansoActivo ? "Reiniciar" : "Iniciar", style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                  ),
                );
              }
          );
        }
    );
  }

  // --- LÓGICA DE DATOS (Mantenida igual) ---
  Future<void> _prepararEntrenamiento() async {
    if (widget.plantilla != null && widget.plantilla!["ejercicios"] != null) {
      setState(() => _cargandoFantasma = true);
      for (var ejOriginal in widget.plantilla!["ejercicios"]) { await _agregarEjercicioConFantasma(ejOriginal); }
      setState(() => _cargandoFantasma = false);
    }
  }

  Future<List<dynamic>> _obtenerFantasma(int idEjercicio) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return [];
      final response = await http.get(Uri.parse(ApiConstants.fantasmaEntrenamiento(idEjercicio)), headers: {'Authorization': 'Bearer $token'});
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) { print("Error obteniendo fantasma: $e"); }
    return [];
  }

  Future<void> _agregarEjercicioConFantasma(Map<String, dynamic> ejercicioSeleccionado) async {
    int idEjercicio = ejercicioSeleccionado["idEjercicio"];
    List<dynamic> setsAnteriores = await _obtenerFantasma(idEjercicio);
    List<Map<String, dynamic>> seriesNuevas = [];

    if (setsAnteriores.isEmpty) {
      seriesNuevas.add({"reps": "", "peso": "", "rir": "0", "rpe": "0", "completada": false, "peso_previo": "", "reps_previas": ""});
    } else {
      for (var setAnterior in setsAnteriores) {
        var peso = setAnterior['pesoKg'] ?? "";
        var reps = setAnterior['repeticiones'] ?? "";
        seriesNuevas.add({"reps": "", "peso": "", "rir": "0", "rpe": "0", "completada": false, "peso_previo": peso.toString(), "reps_previas": reps.toString()});
      }
    }

    setState(() {
      _ejerciciosActivos.add({
        "ejercicio": ejercicioSeleccionado["nombre"] ?? "Desconocido",
        "musculo": ejercicioSeleccionado["grupoMuscular"] ?? "General",
        "datosCompletos": ejercicioSeleccionado,
        "series": seriesNuevas
      });
    });
  }

  Future<bool> _confirmarSalida() async {
    if (_ejerciciosActivos.isEmpty) return true;
    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text("¿Abandonar entrenamiento?", style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text("Perderás todo el progreso de esta sesión no guardado.", style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.7))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("Cancelar", style: TextStyle(color: Theme.of(context).primaryColor))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Sí, abandonar", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    return resultado ?? false;
  }

  Future<void> _confirmarBorradoEjercicio(int index) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text("¿Eliminar ejercicio?", style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text("Se borrarán las series que hayas apuntado para este ejercicio.", style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.7))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("Cancelar", style: TextStyle(color: Theme.of(context).primaryColor))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Eliminar", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (resultado == true) setState(() => _ejerciciosActivos.removeAt(index));
  }

  Future<void> _finalizarRutina() async {
    List<Map<String, dynamic>> setsParaEnviar = [];
    try {
      for (var ej in _ejerciciosActivos) {
        final datosCompletos = ej["datosCompletos"];
        if (datosCompletos == null) continue;
        final int idEjercicio = int.parse(datosCompletos["idEjercicio"].toString());

        for (var serie in ej["series"]) {
          if (serie["completada"] == true) {
            String finalPeso = serie["peso"].toString().isNotEmpty ? serie["peso"].toString() : (serie["peso_previo"]?.toString() ?? "0");
            String finalReps = serie["reps"].toString().isNotEmpty ? serie["reps"].toString() : (serie["reps_previas"]?.toString() ?? "0");
            String finalRir  = serie["rir"].toString().isNotEmpty ? serie["rir"].toString() : "0";
            String finalRpe  = serie["rpe"].toString().isNotEmpty ? serie["rpe"].toString() : "0";

            setsParaEnviar.add({"idEjercicio": idEjercicio, "pesoKg": double.tryParse(finalPeso) ?? 0.0, "repeticiones": int.tryParse(finalReps) ?? 0, "rir": int.tryParse(finalRir) ?? 0, "rpe": int.tryParse(finalRpe) ?? 0});
          }
        }
      }
    } catch (e) { print("🔴 Error interno recopilando los datos: $e"); }

    if (setsParaEnviar.isEmpty) {
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Tienes que marcar la casilla "OK" de alguna serie para guardarla.'), backgroundColor: Colors.orange));
      return;
    }

    int minutosEntreno = DateTime.now().difference(_horaInicio).inMinutes;
    if (minutosEntreno <= 0) minutosEntreno = 1;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) throw Exception("Sin sesión");

      final response = await http.post(Uri.parse(ApiConstants.guardarEntrenamiento), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}, body: jsonEncode({"duracionMinutos": minutosEntreno, "sets": setsParaEnviar}));

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          var decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
          List<dynamic> nuevosLogros = decodedBody["nuevosLogros"] ?? [];

          if (nuevosLogros.isNotEmpty) {
            for (var logro in nuevosLogros) {
              await showDialog(context: context, barrierDismissible: false, builder: (BuildContext context) => DialogoCelebracionLogro(logro: logro, colorBrillo: obtenerColorGlow(logro["dificultad"])));
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ ¡Entrenamiento guardado con éxito!'), backgroundColor: Colors.green));
          }
          if (!mounted) return;
          Navigator.pop(context);
        }
      } else { throw Exception("Error ${response.statusCode}: ${response.body}"); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error al guardar: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    String tituloAppBar = widget.plantilla != null ? widget.plantilla!["nombre"] : "ENTRENAMIENTO LIBRE";

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, dynamic result) async {
        if (didPop) return;
        final salir = await _confirmarSalida();
        if (salir && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(tituloAppBar.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor, fontSize: 16)),
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
          actions: [
            Center(
              child: Semantics(
                label: 'Tiempo de entrenamiento: ${_formatearTiempoGeneral(_segundosEntrenando)}',
                liveRegion: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Theme.of(context).primaryColor.withValues(alpha:0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha:0.5))),
                  child: ExcludeSemantics(child: Row(
                    children: [
                      Icon(Icons.timer, color: Theme.of(context).primaryColor, size: 16),
                      const SizedBox(width: 5),
                      Text(_formatearTiempoGeneral(_segundosEntrenando), style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 14, fontFeatures: const [FontFeature.tabularFigures()])),
                    ],
                  )),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Añadir ejercicio',
              icon: Icon(Icons.add_box_outlined, color: Theme.of(context).primaryColor),
              onPressed: () async {
                final ejercicioSeleccionado = await Navigator.push(context, MaterialPageRoute(builder: (context) => const ExerciseSelectionScreen()));
                if (ejercicioSeleccionado != null) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Buscando historial...'), duration: Duration(milliseconds: 500)));
                  await _agregarEjercicioConFantasma(ejercicioSeleccionado);
                }
              },
            )
          ],
        ),

        // 👇 EL BOTÓN DE FINALIZAR RUTINA ABAJO DEL TODO
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Theme.of(context).appBarTheme.backgroundColor, border: const Border(top: BorderSide(color: Colors.white12, width: 1))),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: _finalizarRutina,
              child: const Text("FINALIZAR RUTINA", style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
            ),
          ),
        ),

        // 👇 EL NUEVO BOTÓN FLOTANTE DEL TEMPORIZADOR MANUAL
        floatingActionButton: FloatingActionButton.extended(
          tooltip: _descansoActivo ? 'Descanso activo, toca para ajustar' : 'Iniciar tiempo de descanso',
          backgroundColor: _descansoActivo ? Colors.orange : Theme.of(context).primaryColor,
          onPressed: _mostrarPanelDescanso,
          icon: Icon(_descansoActivo ? Icons.timer : Icons.timer_outlined, color: Colors.black),
          label: Text(
              _descansoActivo ? _formatearTiempo(_segundosRestantesDescanso) : "Descanso",
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16, fontFeatures: [FontFeature.tabularFigures()])
          ),
        ),

        body: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: _cargandoFantasma
            ? Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))
            : ReorderableListView.builder(
          padding: const EdgeInsets.only(left: 15, right: 15, top: 15, bottom: 80),
          itemCount: _ejerciciosActivos.length,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex -= 1;
              final item = _ejerciciosActivos.removeAt(oldIndex);
              _ejerciciosActivos.insert(newIndex, item);
            });
          },
          itemBuilder: (context, indexEjer) {
            final ejercicio = _ejerciciosActivos[indexEjer];
            return Card(
              key: ValueKey("${ejercicio["ejercicio"]}_$indexEjer"),
              color: Theme.of(context).colorScheme.surface,
              margin: const EdgeInsets.only(bottom: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.white12)),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: true,
                  iconColor: Theme.of(context).primaryColor,
                  title: Row(
                    children: [
                      ReorderableDragStartListener(index: indexEjer, child: Icon(Icons.drag_handle, color: Theme.of(context).colorScheme.onSurface, size: 28)),
                      const SizedBox(width: 15),
                      Expanded(child: Text(ejercicio["ejercicio"], style: const TextStyle(fontWeight: FontWeight.bold))),
                      if (ejercicio["datosCompletos"] != null)
                        IconButton(tooltip: 'Ver información del ejercicio', icon: const Icon(Icons.info_outline, color: Colors.grey), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => EjercicioDetalleScreen(ejercicio: ejercicio["datosCompletos"])))),
                      IconButton(tooltip: 'Eliminar ejercicio', icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _confirmarBorradoEjercicio(indexEjer)),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(left: 30.0),
                    child: Text(ejercicio["musculo"], style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 12)),
                  ),
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  SizedBox(width: 35, child: Text("SET", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                                  SizedBox(width: 65, child: Text("KG", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                                  SizedBox(width: 65, child: Text("REPS", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                                  SizedBox(width: 55, child: Tooltip(message: "Reps in Reserve", triggerMode: TooltipTriggerMode.tap, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text("RIR", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)), SizedBox(width: 2), Icon(Icons.help_outline, size: 10, color: Colors.grey)]))),
                                  SizedBox(width: 55, child: Tooltip(message: "Rate of Perceived Exertion", triggerMode: TooltipTriggerMode.tap, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text("RPE", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)), SizedBox(width: 2), Icon(Icons.help_outline, size: 10, color: Colors.grey)]))),
                                  // 👇 HEMOS ELIMINADO LA COLUMNA REST PARA QUE QUEDE MÁS LIMPIO
                                  SizedBox(width: 50, child: Text("OK", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                                ],
                              ),
                            ),
                            const Divider(color: Colors.white12, height: 1),

                            ...List.generate(ejercicio["series"].length, (indexSerie) {
                              var serie = ejercicio["series"][indexSerie];
                              bool estaCompletada = serie["completada"];
                              return Container(
                                color: estaCompletada ? Theme.of(context).primaryColor.withValues(alpha:0.1) : Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    SizedBox(width: 35, child: Container(alignment: Alignment.center, child: Text("${indexSerie + 1}"))),
                                    SizedBox(width: 65, child: _buildMiniInputBox(serie["peso"], serie["peso_previo"], (val) => serie["peso"] = val, labelText: 'Peso en kg')),
                                    SizedBox(width: 65, child: _buildMiniInputBox(serie["reps"], serie["reps_previas"], (val) => serie["reps"] = val, labelText: 'Repeticiones')),
                                    SizedBox(width: 55, child: _buildMiniInputBox(serie["rir"], "-", (val) => serie["rir"] = val, labelText: 'RIR')),
                                    SizedBox(width: 55, child: _buildMiniInputBox(serie["rpe"] ?? "", "-", (val) => serie["rpe"] = val, labelText: 'RPE')),
                                    SizedBox(
                                      width: 50,
                                      child: Center(child: Semantics(label: 'Serie ${indexSerie + 1} ${estaCompletada ? "completada" : "pendiente"}', child: Checkbox(value: estaCompletada, activeColor: Theme.of(context).primaryColor, checkColor: Colors.black, onChanged: (val) => setState(() => serie["completada"] = val)))),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                      child: TextButton.icon(
                        onPressed: () => setState(() => ejercicio["series"].add({"reps": "", "peso": "", "rir": "0", "rpe": "0", "completada": false, "fantasma": ""})),
                        icon: const Icon(Icons.add, color: Colors.grey, size: 16),
                        label: const Text("Añadir Serie", style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        ),
      ),
    );
  }

  Widget _buildMiniInputBox(String valorInicial, String? hint, Function(String) onChanged, {String? labelText}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: TextFormField(
        initialValue: valorInicial,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.5), fontSize: 11),
          hintText: (hint != null && hint.isNotEmpty) ? hint : "-",
          hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.3), fontSize: 14),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface.withValues(alpha:0.8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        ),
        onChanged: onChanged,
      ),
    );
  }
}