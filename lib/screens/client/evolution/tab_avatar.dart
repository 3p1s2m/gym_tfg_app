import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/api_constants.dart';
import '../../../widgets/logro_dialog.dart';
import '../../../main.dart'; // 👈 Importamos el chivato global

class TabAvatar extends StatefulWidget {
  final int? idCliente; // 👈 NUEVO: Para ver medidas de un cliente específico desde coach
  const TabAvatar({super.key, this.idCliente});

  @override
  State<TabAvatar> createState() => _TabAvatarState();
}

class _TabAvatarState extends State<TabAvatar> with TickerProviderStateMixin {
  List<dynamic> _todasLasMedidas = [];
  bool _cargandoMedidas = true;
  late AnimationController _animController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 4.0, end: 12.0).animate(_animController);
    _cargarMedidas();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _cargarMedidas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return;

      String endpoint = widget.idCliente != null 
          ? "${ApiConstants.baseUrl}/coach/cliente/${widget.idCliente}/medidas"
          : ApiConstants.medidas;
      final url = Uri.parse(endpoint);
      final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _todasLasMedidas = jsonDecode(response.body);
            _cargandoMedidas = false;
          });
        }
      } else {
        if (mounted) setState(() => _cargandoMedidas = false);
      }
    } catch (e) {
      if (mounted) setState(() => _cargandoMedidas = false);
    }
  }

  Future<void> _guardarMedida(String zona, double valor) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return;

      final url = Uri.parse(ApiConstants.medidas);
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({"zona": zona, "medidaCm": valor}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _cargarMedidas();
        if (mounted) Navigator.pop(context);

        if (mounted) {
          try {
            var decodedBody = jsonDecode(response.body);
            List<dynamic> nuevosLogros = decodedBody["nuevosLogros"] ?? [];

            if (nuevosLogros.isNotEmpty) {
              for (var logro in nuevosLogros) {
                await showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext context) {
                      return DialogoCelebracionLogro(logro: logro, colorBrillo: obtenerColorGlow(logro["dificultad"]));
                    }
                );
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Registro guardado'), backgroundColor: Colors.green));
            }
          } catch(e) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Registro guardado'), backgroundColor: Colors.green));
          }
        }
      }
    } catch (e) {
      print("Error guardando medida: $e");
    }
  }

  void _abrirPanelZona(String zona) {
    TextEditingController inputController = TextEditingController();
    List<dynamic> medidasZona = _todasLasMedidas.where((m) => m["zona"] == zona).toList();

    double dia1 = medidasZona.isNotEmpty ? medidasZona.first["medidaCm"] : 0.0;
    double hoy = medidasZona.isNotEmpty ? medidasZona.last["medidaCm"] : 0.0;
    double diferencia = hoy - dia1;
    String signo = diferencia >= 0 ? "+" : "";
    String unidad = zona == "Peso Corporal" ? "kg" : "cm";

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) {
        return FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 25, left: 20, right: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(zona == "Peso Corporal" ? "Evolución de Peso" : "Medidas: $zona", style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              if (medidasZona.isNotEmpty)
                MergeSemantics(
                  child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(children: [const Text("DÍA 1", style: TextStyle(color: Colors.grey, fontSize: 10)), Text("$dia1", style: const TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold))]),
                    const ExcludeSemantics(child: Icon(Icons.arrow_forward, color: Colors.white24)),
                    Column(children: [const Text("ÚLTIMA", style: TextStyle(color: Colors.grey, fontSize: 10)), Text("$hoy", style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 18, fontWeight: FontWeight.bold))]),
                    Column(children: [const Text("EVOLUCIÓN", style: TextStyle(color: Colors.grey, fontSize: 10)), Text("$signo${diferencia.toStringAsFixed(1)} $unidad", style: TextStyle(color: diferencia >= 0 ? Colors.greenAccent : Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold))]),
                  ],
                  ),
                )
              else const Text("No hay registros. ¡Añade el primero!", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 25),
              if (medidasZona.length >= 2)
                Container(height: 150, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(15)), child: ExcludeSemantics(child: _buildGraficoMedidas(medidasZona, unidad))),
              const SizedBox(height: 25),
              Row(
                children: [
                  Expanded(child: TextField(controller: inputController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), decoration: InputDecoration(labelText: "Añadir registro hoy ($unidad)", labelStyle: const TextStyle(color: Colors.grey), filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)))),
                  const SizedBox(width: 15),
                  ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () { double? val = double.tryParse(inputController.text); if (val != null) _guardarMedida(zona, val); }, child: const Text("GUARDAR", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
          ),
        );
      },
    );
  }

  Widget _buildGraficoMedidas(List<dynamic> medidas, String unidad) {
    List<FlSpot> puntos = [];
    for (int i = 0; i < medidas.length; i++) {
      puntos.add(FlSpot(i.toDouble(), (medidas[i]["medidaCm"] as num).toDouble()));
    }
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false), titlesData: const FlTitlesData(show: false), borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchSpotThreshold: 30,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => Colors.black87,
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              return touchedSpots.map((spot) {
                int index = spot.x.toInt();
                DateTime fechaDate = DateTime.parse(medidas[index]["fecha"]);
                String fechaFormateada = "${fechaDate.day.toString().padLeft(2, '0')}/${fechaDate.month.toString().padLeft(2, '0')}/${fechaDate.year}";
                return LineTooltipItem("${spot.y} $unidad\n", TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 14), children: [TextSpan(text: fechaFormateada, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.normal))]);
              }).toList();
            },
          ),
        ),
        lineBarsData: [LineChartBarData(spots: puntos, isCurved: true, color: Theme.of(context).primaryColor, barWidth: 3, dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 4, color: Theme.of(context).primaryColor, strokeWidth: 1, strokeColor: Colors.black)), belowBarData: BarAreaData(show: true, color: Theme.of(context).primaryColor.withValues(alpha:0.2)))],
      ),
    );
  }

  Widget _buildPuntoInteractivo(String zona, double top, double left) {
    bool tieneDatos = _todasLasMedidas.any((m) => m["zona"] == zona);
    return Positioned(
      top: top, left: left,
      child: Semantics(
        label: "$zona, ${tieneDatos ? 'con datos registrados' : 'sin datos, toca para añadir'}, toca para ver medidas",
        button: true,
        child: GestureDetector(
        onTap: () => _abrirPanelZona(zona),
        child: AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tieneDatos ? Theme.of(context).primaryColor.withValues(alpha:0.3) : Colors.redAccent.withValues(alpha:0.3),
                boxShadow: [BoxShadow(color: tieneDatos ? Theme.of(context).primaryColor.withValues(alpha:0.8) : Colors.redAccent.withValues(alpha:0.8), blurRadius: _glowAnimation.value, spreadRadius: 2)],
                border: Border.all(color: tieneDatos ? Theme.of(context).primaryColor : Colors.redAccent, width: 2),
              ),
              child: const Icon(Icons.add, size: 15, color: Colors.white),
            );
          },
        ),
      ),
    ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoMedidas) return Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor));

    List<dynamic> medidasPeso = _todasLasMedidas.where((m) => m["zona"] == "Peso Corporal").toList();
    String pesoActualText = medidasPeso.isNotEmpty ? "${medidasPeso.last["medidaCm"]} kg" : "-- kg";

    // 👇 ESCUCHAMOS A LA VARIABLE GLOBAL DEL GÉNERO
    return ValueListenableBuilder<String>(
        valueListenable: appGenero,
        builder: (context, generoActual, child) {
          // Si el género es nulo o 'cargando', usa 'hombre' como valor visual
          String generoVisual = (generoActual == null || generoActual == "cargando") ? "hombre" : (generoActual == "otro" ? "hombre" : generoActual);
          String rutaCuerpoBase = 'assets/images/body_${generoVisual}_frente.png';

          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                child: Text("Toca una zona muscular para registrar o ver tus medidas en centímetros.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),

              Expanded(
                child: Center(
                  child: SizedBox(
                    width: 300,
                    height: 520,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(child: Image.asset(rutaCuerpoBase, fit: BoxFit.contain, semanticLabel: 'Figura corporal ${generoVisual == "hombre" ? "masculina" : "femenina"}, vista frontal')),
                        _buildPuntoInteractivo("Torso / Pecho", 130, 135),
                        _buildPuntoInteractivo("Cintura", 220, 135),
                        _buildPuntoInteractivo("Cadera", 260, 135),
                        _buildPuntoInteractivo("Brazo Izquierdo", 150, 60),
                        _buildPuntoInteractivo("Brazo Derecho", 150, 210),
                        _buildPuntoInteractivo("Cuádriceps Izq.", 320, 100),
                        _buildPuntoInteractivo("Cuádriceps Der.", 320, 170),
                      ],
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                child: Card(
                  color: Theme.of(context).colorScheme.surface,
                  elevation: 5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.white12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Theme.of(context).primaryColor.withValues(alpha:0.2), shape: BoxShape.circle),
                      child: Icon(Icons.monitor_weight_outlined, color: Theme.of(context).primaryColor),
                    ),
                    title: const Text("Peso Corporal", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: const Text("Añadir o ver evolución", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    trailing: Text(pesoActualText, style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 20, fontWeight: FontWeight.bold)),
                    onTap: () => _abrirPanelZona("Peso Corporal"),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          );
        }
    );
  }
}