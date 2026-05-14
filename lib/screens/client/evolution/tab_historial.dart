import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../services/api_constants.dart';

class TabHistorial extends StatefulWidget {
  final int? idCliente;
  const TabHistorial({super.key, this.idCliente});

  @override
  State<TabHistorial> createState() => _TabHistorialState();
}

class _TabHistorialState extends State<TabHistorial> {
  Map<DateTime, dynamic> _entrenamientosPorDia = {};
  bool _cargandoHistorial = true;
  DateTime _diaSeleccionado = DateTime.now();
  DateTime _mesEnfocado = DateTime.now();

  String _modoAnalizador = "Músculo";
  String _filtroAnalizador = "Todos";
  String _metricaAnalizador = "Tonelaje";
  final List<String> _opcionesMetricas = ["Tonelaje", "Peso Máximo", "Series", "Repeticiones"];

  @override
  void initState() {
    super.initState();
    _cargarResumenHistorial();
  }

  Future<void> _cargarResumenHistorial() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return;

      String endpoint = widget.idCliente != null
          ? "${ApiConstants.baseUrl}/entrenamientos/coach/cliente/${widget.idCliente}/historial"
          : "${ApiConstants.baseUrl}/entrenamientos/historial";

      final response = await http.get(Uri.parse(endpoint), headers: {'Authorization': 'Bearer $token'});

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        Map<DateTime, dynamic> mapaTemporal = {};

        for (var entreno in data) {
          if (entreno["fecha"] == null) continue;

          DateTime fechaLimpia;
          var f = entreno["fecha"];

          // 👇 EL ESCUDO CONTRA EL FORMATO DE FECHAS DE JAVA 👇
          if (f is String) {
            DateTime fechaRaw = DateTime.parse(f);
            fechaLimpia = DateTime.utc(fechaRaw.year, fechaRaw.month, fechaRaw.day);
          } else if (f is List && f.length >= 3) {
            // Si Java manda la fecha como un array [2026, 3, 26]
            fechaLimpia = DateTime.utc(f[0], f[1], f[2]);
          } else {
            continue;
          }

          mapaTemporal[fechaLimpia] = entreno;
        }

        if (mounted) {
          setState(() {
            _entrenamientosPorDia = mapaTemporal;
            _cargandoHistorial = false;
          });
        }
      } else {
        if (mounted) setState(() => _cargandoHistorial = false);
      }
    } catch (e) {
      print("Error cargando historial: $e"); // Chivato por si acaso
      if (mounted) setState(() => _cargandoHistorial = false);
    }
  }

  // 👇 ESCUDOS ANTI-CRASH TOTALMENTE BLINDADOS 👇
  List<dynamic> _obtenerSets(dynamic entreno) {
    if (entreno == null) return [];
    return entreno["sets"] ?? entreno["setsRealizados"] ?? [];
  }

  String _obtenerNombreEjer(dynamic s) {
    if (s["nombreEjercicio"] != null) return s["nombreEjercicio"].toString();
    if (s["ejercicio"] != null && s["ejercicio"]["nombre"] != null) return s["ejercicio"]["nombre"].toString();
    return "Desconocido";
  }

  String _obtenerMusculo(dynamic s) {
    if (s["grupoMuscular"] != null) return s["grupoMuscular"].toString();
    if (s["ejercicio"] != null && s["ejercicio"]["grupoMuscular"] != null) return s["ejercicio"]["grupoMuscular"].toString();
    return "Otros"; // Protege de pintar Text(null)
  }

  double _obtenerPeso(dynamic s) {
    var p = s["pesoKg"] ?? s["peso"] ?? 0;
    if (p is num) return p.toDouble();
    if (p is String) return double.tryParse(p) ?? 0.0;
    return 0.0;
  }

  int _obtenerReps(dynamic s) {
    var r = s["repeticiones"] ?? s["reps"] ?? 0;
    if (r is num) return r.toInt();
    if (r is String) return int.tryParse(r) ?? 0;
    return 0;
  }

  int _calcularRachaSemanas() {
    if (_entrenamientosPorDia.isEmpty) return 0;
    var fechas = _entrenamientosPorDia.keys.toList()..sort((a, b) => b.compareTo(a));
    DateTime hoy = DateTime.now();
    int racha = 0;

    for (int i = 0; i < 52; i++) {
      DateTime inicioSemana = hoy.subtract(Duration(days: hoy.weekday - 1 + (i * 7)));
      DateTime finSemana = inicioSemana.add(const Duration(days: 6));

      bool entrenoEnSemana = fechas.any((f) => f.isAfter(inicioSemana.subtract(const Duration(days: 1))) && f.isBefore(finSemana.add(const Duration(days: 1))));

      if (entrenoEnSemana) racha++;
      else if (i != 0) break;
    }
    return racha;
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoHistorial) return Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor));

    DateTime diaNormalizado = DateTime.utc(_diaSeleccionado.year, _diaSeleccionado.month, _diaSeleccionado.day);
    dynamic entrenoDelDia = _entrenamientosPorDia[diaNormalizado];

    Map<String, List<dynamic>> ejerciciosAgrupados = {};
    for (var s in _obtenerSets(entrenoDelDia)) {
      String nombre = _obtenerNombreEjer(s);
      if (!ejerciciosAgrupados.containsKey(nombre)) ejerciciosAgrupados[nombre] = [];
      ejerciciosAgrupados[nombre]!.add(s);
    }

    Set<String> setMusculos = {"Todos"};
    Set<String> setEjercicios = {"Todos"};
    for (var entreno in _entrenamientosPorDia.values) {
      for (var s in _obtenerSets(entreno)) {
        setMusculos.add(_obtenerMusculo(s));
        setEjercicios.add(_obtenerNombreEjer(s));
      }
    }

    List<String> listaFiltros = _modoAnalizador == "Músculo" ? setMusculos.toList() : setEjercicios.toList();
    listaFiltros.sort();

    // Blindaje del resumen diario
    String nombreRutina = "ENTRENAMIENTO";
    if (entrenoDelDia != null) {
      if (entrenoDelDia["nombreRutina"] != null) nombreRutina = entrenoDelDia["nombreRutina"].toString();
      else if (entrenoDelDia["rutina"] != null && entrenoDelDia["rutina"]["nombre"] != null) nombreRutina = entrenoDelDia["rutina"]["nombre"].toString();
    }

    int duracion = 0;
    if (entrenoDelDia != null) {
      var d = entrenoDelDia["duracionMinutos"] ?? entrenoDelDia["duracion"];
      if (d is num) duracion = d.toInt();
      else if (d is String) duracion = int.tryParse(d) ?? 0;
    }

    int totalSeries = entrenoDelDia?["totalSeries"] ?? _obtenerSets(entrenoDelDia).length;

    double tonelajeTotal = 0;
    if (entrenoDelDia != null) {
      var t = entrenoDelDia["tonelajeTotal"];
      if (t is num) tonelajeTotal = t.toDouble();
      else if (t is String) tonelajeTotal = double.tryParse(t) ?? 0.0;

      if (tonelajeTotal == 0) {
        for (var s in _obtenerSets(entrenoDelDia)) { tonelajeTotal += (_obtenerPeso(s) * _obtenerReps(s)); }
      }
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          if (_entrenamientosPorDia.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 15, left: 15, right: 15), padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: Colors.orangeAccent.withValues(alpha:0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.orangeAccent.withValues(alpha:0.5))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("🔥", style: TextStyle(fontSize: 24)), const SizedBox(width: 10),
                  Text("${_calcularRachaSemanas()} Semanas seguidas", style: const TextStyle(color: Colors.orangeAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

          Container(
            margin: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1))),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1), lastDay: DateTime.utc(2030, 12, 31), focusedDay: _mesEnfocado, calendarFormat: CalendarFormat.month, startingDayOfWeek: StartingDayOfWeek.monday,
              headerStyle: HeaderStyle(formatButtonVisible: false, titleTextStyle: TextStyle(color: Theme.of(context).primaryColor, fontSize: 18, fontWeight: FontWeight.bold), leftChevronIcon: Icon(Icons.chevron_left, color: Theme.of(context).colorScheme.onSurface), rightChevronIcon: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface)),
              daysOfWeekStyle: DaysOfWeekStyle(weekdayStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)), weekendStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
              calendarStyle: CalendarStyle(
                defaultTextStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface), weekendTextStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)), outsideDaysVisible: false,
                todayDecoration: BoxDecoration(color: Theme.of(context).primaryColor.withValues(alpha:0.3), shape: BoxShape.circle),
                selectedDecoration: BoxDecoration(color: Theme.of(context).primaryColor, shape: BoxShape.circle), selectedTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                markerDecoration: BoxDecoration(color: Theme.of(context).primaryColor, shape: BoxShape.circle),
              ),
              eventLoader: (dia) => _entrenamientosPorDia.containsKey(DateTime.utc(dia.year, dia.month, dia.day)) ? ['entreno'] : [],
              selectedDayPredicate: (dia) => isSameDay(_diaSeleccionado, dia),
              onDaySelected: (diaSeleccionado, mesEnfocado) => setState(() { _diaSeleccionado = diaSeleccionado; _mesEnfocado = mesEnfocado; }),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0),
            child: entrenoDelDia != null
                ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Resumen del entrenamiento", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(gradient: LinearGradient(colors: [Theme.of(context).scaffoldBackgroundColor, Theme.of(context).primaryColor.withValues(alpha:0.1)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(15), border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha:0.5))),
                  child: Row(
                    children: [
                      Icon(Icons.timer, color: Theme.of(context).primaryColor, size: 35), const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nombreRutina.toUpperCase(), style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14)),
                            Text("$duracion min • $totalSeries series", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("TONELAJE", style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 10, letterSpacing: 1.0)),
                          Text("${tonelajeTotal.toStringAsFixed(0)} kg", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 15),

                ...ejerciciosAgrupados.entries.map((entry) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.key, style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
                        const Divider(color: Colors.white12),
                        ...entry.value.map((s) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("${_obtenerPeso(s)} kg  x  ${_obtenerReps(s)} reps", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13)),
                              const Icon(Icons.check_circle, color: Colors.green, size: 14),
                            ],
                          ),
                        ))
                      ],
                    ),
                  );
                }),
              ],
            ) : Padding(padding: const EdgeInsets.all(20), child: Center(child: Text("Día de descanso", style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 16)))),
          ),

          const Padding(padding: EdgeInsets.symmetric(vertical: 20.0), child: Divider(color: Colors.white12, thickness: 2)),

          Padding(padding: const EdgeInsets.symmetric(horizontal: 15.0), child: Align(alignment: Alignment.centerLeft, child: Text("Analizador de Progreso", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)))),
          const SizedBox(height: 15),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0),
            child: Row(
              children: [
                ToggleButtons(
                  isSelected: [_modoAnalizador == "Músculo", _modoAnalizador == "Ejercicio"],
                  onPressed: (index) {
                    setState(() {
                      _modoAnalizador = index == 0 ? "Músculo" : "Ejercicio";
                      _filtroAnalizador = "Todos";
                    });
                  },
                  fillColor: Theme.of(context).primaryColor.withValues(alpha:0.2),
                  selectedColor: Theme.of(context).primaryColor,
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(10),
                  borderColor: Colors.white12,
                  selectedBorderColor: Theme.of(context).primaryColor,
                  children: const [Padding(padding: EdgeInsets.symmetric(horizontal: 15), child: Text("Músculo")), Padding(padding: EdgeInsets.symmetric(horizontal: 15), child: Text("Ejercicio"))],
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1))),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        dropdownColor: Theme.of(context).colorScheme.surface,
                        value: listaFiltros.contains(_filtroAnalizador) ? _filtroAnalizador : "Todos",
                        style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
                        icon: Icon(Icons.arrow_drop_down, color: Theme.of(context).primaryColor),
                        items: listaFiltros.map((String f) => DropdownMenuItem(value: f, child: Text(f, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) => setState(() => _filtroAnalizador = val!),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (!(_modoAnalizador == "Músculo" && _filtroAnalizador == "Todos")) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1))),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    dropdownColor: Theme.of(context).colorScheme.surface,
                    value: _metricaAnalizador,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
                    icon: Icon(Icons.bar_chart, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                    items: _opcionesMetricas.map((String m) => DropdownMenuItem(value: m, child: Text("Métrica: $m"))).toList(),
                    onChanged: (val) => setState(() => _metricaAnalizador = val!),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 25),

          Container(
            margin: const EdgeInsets.symmetric(horizontal: 15),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(15), border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1))),
            child: _buildContenidoAnalizador(),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildContenidoAnalizador() {
    if (_modoAnalizador == "Músculo" && _filtroAnalizador == "Todos") {
      return _buildGraficoSimetria();
    } else if (_modoAnalizador == "Ejercicio" && _filtroAnalizador == "Todos") {
      return _buildGraficoEvolucion("Global");
    } else if (_modoAnalizador == "Músculo") {
      return _buildGraficoEvolucion("Musculo");
    } else {
      return _buildGraficoEvolucion("Ejercicio");
    }
  }

  Widget _buildGraficoSimetria() {
    Map<String, int> distribucion = {};
    int totalSeries = 0;

    for (var entreno in _entrenamientosPorDia.values) {
      for (var s in _obtenerSets(entreno)) {
        String musculo = _obtenerMusculo(s);
        distribucion[musculo] = (distribucion[musculo] ?? 0) + 1;
        totalSeries++;
      }
    }

    if (totalSeries == 0) return const Center(child: Text("No hay datos de entrenamiento.", style: TextStyle(color: Colors.grey)));

    List<Color> paleta = [Theme.of(context).primaryColor, Colors.purpleAccent, Colors.orangeAccent, Colors.greenAccent, Colors.pinkAccent, Colors.yellowAccent, Colors.blueAccent];
    int colorIndex = 0;
    List<PieChartSectionData> secciones = [];
    List<Widget> leyenda = [];

    distribucion.forEach((musculo, count) {
      Color colorFila = paleta[colorIndex % paleta.length];
      double porcentaje = (count / totalSeries) * 100;

      secciones.add(PieChartSectionData(color: colorFila, value: count.toDouble(), radius: 50, title: "${porcentaje.toStringAsFixed(0)}%", titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)));
      leyenda.add(Container(margin: const EdgeInsets.only(bottom: 5, right: 10), child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: colorFila, shape: BoxShape.circle)), const SizedBox(width: 5), Text(musculo, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 12))])));
      colorIndex++;
    });

    return Column(children: [Text("Simetría Muscular (Porcentaje de Series)", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)), const SizedBox(height: 20), SizedBox(height: 150, child: PieChart(PieChartData(sections: secciones, centerSpaceRadius: 40, sectionsSpace: 2))), const SizedBox(height: 20), Wrap(alignment: WrapAlignment.center, children: leyenda)]);
  }

  Widget _buildGraficoEvolucion(String modo) {
    String titulo = "";
    if (modo == "Global") titulo = "Evolución Global";
    if (modo == "Musculo") titulo = "Evolución: $_filtroAnalizador";
    if (modo == "Ejercicio") titulo = "Progresión: $_filtroAnalizador";

    return Column(
      children: [
        Text("$titulo ($_metricaAnalizador)", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        SizedBox(height: 180, child: _buildGrafica(modo: modo)),
      ],
    );
  }

  Widget _buildGrafica({required String modo}) {
    List<FlSpot> puntos = [];
    List<Map<String, dynamic>> datosTooltip = [];
    var fechasOrdenadas = _entrenamientosPorDia.keys.toList()..sort();

    int indiceX = 0;
    for (var fecha in fechasOrdenadas) {
      double valorY = 0;
      double extraInfo = 0;

      for (var s in _obtenerSets(_entrenamientosPorDia[fecha])) {
        bool sumar = false;
        double peso = _obtenerPeso(s);
        int reps = _obtenerReps(s);
        String musculo = _obtenerMusculo(s);
        String nombreEjer = _obtenerNombreEjer(s);

        if (modo == "Global") sumar = true;
        if (modo == "Musculo" && musculo == _filtroAnalizador) sumar = true;
        if (modo == "Ejercicio" && nombreEjer == _filtroAnalizador) sumar = true;

        if (sumar) {
          if (_metricaAnalizador == "Tonelaje") {
            valorY += (peso * reps);
          } else if (_metricaAnalizador == "Peso Máximo") {
            if (peso > valorY) valorY = peso;
          } else if (_metricaAnalizador == "Series") {
            valorY += 1;
          } else if (_metricaAnalizador == "Repeticiones") {
            valorY += reps;
          }
        }
      }

      if (valorY > 0) {
        puntos.add(FlSpot(indiceX.toDouble(), valorY));
        datosTooltip.add({"fecha": "${fecha.day}/${fecha.month}/${fecha.year}", "valor": valorY, "extra": extraInfo});
        indiceX++;
      }
    }

    if (puntos.isEmpty) return const Center(child: Text("Sin datos para esta métrica.", style: TextStyle(color: Colors.grey)));

    String sufijo = "";
    if (_metricaAnalizador == "Tonelaje" || _metricaAnalizador == "Peso Máximo") sufijo = "kg";
    if (_metricaAnalizador == "Series") sufijo = "sets";
    if (_metricaAnalizador == "Repeticiones") sufijo = "reps";

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false), titlesData: const FlTitlesData(show: false), borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchSpotThreshold: 30,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => Colors.black87, fitInsideHorizontally: true, fitInsideVertically: true,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                var data = datosTooltip[spot.x.toInt()];
                String textoPrincipal = "${data["valor"].toStringAsFixed(1)} $sufijo";
                return LineTooltipItem("$textoPrincipal\n", TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 13), children: [TextSpan(text: data["fecha"], style: const TextStyle(color: Colors.grey, fontSize: 10))]);
              }).toList();
            },
          ),
        ),
        lineBarsData: [LineChartBarData(spots: puntos, isCurved: true, color: Theme.of(context).primaryColor, barWidth: 3, dotData: FlDotData(show: true, getDotPainter: (spot, p, b, i) => FlDotCirclePainter(radius: 4, color: Theme.of(context).primaryColor, strokeWidth: 1, strokeColor: Colors.black)), belowBarData: BarAreaData(show: true, color: Theme.of(context).primaryColor.withValues(alpha:0.2)))],
      ),
    );
  }
}