import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/nutricion_service.dart';
import '../../models/alimento.dart';

class NutricionScreen extends StatefulWidget {
  const NutricionScreen({super.key});

  @override
  State<NutricionScreen> createState() => _NutricionScreenState();
}

class _NutricionScreenState extends State<NutricionScreen> {
  final NutricionService _service = NutricionService();
  final TextEditingController _controller = TextEditingController();

  List<Alimento> _resultadosBusqueda = [];
  List<dynamic> _diarioHoy = [];
  List<dynamic> _datosSemana = [];
  bool _cargandoBusqueda = false;
  double _objetivoCalorias = 2000;

  @override
  void initState() {
    super.initState();
    _cargarDiario();
    _cargarObjetivo();
    _cargarSemanal();
  }

  Future<void> _cargarDiario() async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8080/api/nutricion/diario/1'),
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        setState(() => _diarioHoy = jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint("Error cargando diario: $e");
    }
  }

  Future<void> _cargarObjetivo() async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8080/api/nutricion/objetivo/1'),
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _objetivoCalorias = (data['objetivo'] ?? 2000).toDouble());
      }
    } catch (e) {
      debugPrint("Error cargando objetivo: $e");
    }
  }

  Future<void> _cargarSemanal() async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8080/api/nutricion/semanal/1'),
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        setState(() => _datosSemana = jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint("Error cargando semanal: $e");
    }
  }

  Future<void> _guardarObjetivo(double valor) async {
    try {
      await http.post(
        Uri.parse('http://10.0.2.2:8080/api/nutricion/objetivo/1'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"objetivo": valor}),
      );
      setState(() => _objetivoCalorias = valor);
      _mostrarSnack("✅ Objetivo guardado", Colors.green);
    } catch (e) {
      _mostrarSnack("❌ Error al guardar objetivo", Colors.red);
    }
  }

  void _ejecutarBusqueda(String valor) async {
    if (valor.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _cargandoBusqueda = true;
      _resultadosBusqueda.clear();
    });
    try {
      final lista = await _service.buscarAlimentos(valor);
      setState(() {
        _resultadosBusqueda = lista;
        _cargandoBusqueda = false;
      });
      if (lista.isEmpty) _mostrarSnack("No se encontraron resultados", Colors.orange);
    } catch (e) {
      setState(() => _cargandoBusqueda = false);
      _mostrarSnack("Error en la IA: $e", Colors.red);
    }
  }

  Future<void> _guardarEnBaseDeDatos(Alimento item) async {
    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:8080/api/nutricion/guardar'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "nombre": item.nombre,
          "calorias": item.kcal,
          "proteinas": item.proteinas,
          "carbohidratos": item.carbohidratos,
          "grasas": item.grasas,
          "usuario": {"idUsuario": 1}
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        _mostrarSnack("✅ Añadido correctamente", Colors.green);
        _controller.clear();
        setState(() => _resultadosBusqueda.clear());
        await _cargarDiario();
        await _cargarSemanal();
      }
    } catch (e) {
      _mostrarSnack("❌ Error al guardar", Colors.red);
    }
  }

  Future<void> _borrarComida(dynamic id) async {
    if (id == null) return;
    try {
      final response = await http.delete(
        Uri.parse('http://10.0.2.2:8080/api/nutricion/borrar/$id'),
      );
      if (response.statusCode == 200) {
        _mostrarSnack("🗑️ Eliminado del diario", Colors.blueGrey);
        await _cargarDiario();
        await _cargarSemanal();
      }
    } catch (e) {
      _mostrarSnack("Error de conexión al borrar", Colors.red);
    }
  }

  double get _totalKcal => _diarioHoy.fold(0, (s, i) => s + (i['calorias'] ?? 0).toDouble());
  double get _totalProteinas => _diarioHoy.fold(0, (s, i) => s + (i['proteinas'] ?? 0).toDouble());
  double get _totalCarbos => _diarioHoy.fold(0, (s, i) => s + (i['carbohidratos'] ?? 0).toDouble());
  double get _totalGrasas => _diarioHoy.fold(0, (s, i) => s + (i['grasas'] ?? 0).toDouble());

  void _mostrarDialogoObjetivo() {
    final ctrl = TextEditingController(text: _objetivoCalorias.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.flag, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text("Objetivo calórico"),
          ],
        ),
        content: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: TextField(
            autofocus: true,
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: "Calorías objetivo",
              hintText: "Ej: 2500",
              suffixText: "kcal",
              filled: true,
              fillColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
            onPressed: () {
              final valor = double.tryParse(ctrl.text);
              if (valor != null && valor > 0) {
                _guardarObjetivo(valor);
                Navigator.pop(ctx);
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text("MI DIARIO NUTRICIONAL",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1)),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined, color: Colors.deepPurple),
            tooltip: "Configurar objetivo",
            onPressed: _mostrarDialogoObjetivo,
          ),
        ],
      ),
      body: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: Column(
        children: [
          _buildSearchBox(),
          if (_cargandoBusqueda) const LinearProgressIndicator(color: Colors.deepPurple),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 160),
              children: [
                _buildResumenCirculos(),
                _buildBarraProgreso(),
                _buildGraficaSemanal(),
                if (_resultadosBusqueda.isNotEmpty) ...[
                  _buildSectionHeader("RESULTADO IA", Icons.auto_awesome, Colors.deepPurple),
                  ..._resultadosBusqueda.map((item) => _buildAlimentoCardIA(item)),
                  const SizedBox(height: 8),
                ],
                _buildSectionHeader("ALIMENTOS DE HOY", Icons.restaurant_menu, Colors.orange),
                if (_diarioHoy.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: Text("No hay registros.\nEscribe arriba para empezar.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 15)),
                    ),
                  )
                else
                  ..._diarioHoy.map((comida) => _buildDiarioTile(comida)),
              ],
            ),
          ),
        ],
        ),
      ),
      bottomSheet: _buildResumenTotal(),
    );
  }

  Widget _buildSearchBox() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: colorScheme.surface,
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          labelText: 'Describe tu comida o ingrediente',
          hintText: "Ej: Desayuno un café y 2 galletas",
          prefixIcon: const Icon(Icons.auto_awesome, color: Colors.deepPurple),
          suffixIcon: IconButton(
            tooltip: 'Buscar con IA',
            icon: const Icon(Icons.send, color: Colors.deepPurple),
            onPressed: () => _ejecutarBusqueda(_controller.text),
          ),
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
        ),
        onSubmitted: _ejecutarBusqueda,
      ),
    );
  }

  Widget _buildResumenCirculos() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.deepPurple.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Semantics(label: "${_totalKcal.toStringAsFixed(0)} kcal", child: _buildCirculo("${_totalKcal.toStringAsFixed(0)}", "kcal", Colors.yellowAccent, 60)),
          Semantics(label: "${_totalProteinas.toStringAsFixed(0)}g Proteínas", child: _buildCirculo("${_totalProteinas.toStringAsFixed(0)}g", "Proteínas", Colors.greenAccent, 48)),
          Semantics(label: "${_totalCarbos.toStringAsFixed(0)}g Carbos", child: _buildCirculo("${_totalCarbos.toStringAsFixed(0)}g", "Carbos", Colors.orangeAccent, 48)),
          Semantics(label: "${_totalGrasas.toStringAsFixed(0)}g Grasas", child: _buildCirculo("${_totalGrasas.toStringAsFixed(0)}g", "Grasas", Colors.redAccent, 48)),
        ],
      ),
    );
  }

  Widget _buildCirculo(String valor, String etiqueta, Color color, double size) {
    return Column(
      children: [
        Container(
          width: size, height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
            color: color.withOpacity(0.15),
          ),
          child: Center(
            child: Text(valor, style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold,
                fontSize: size > 50 ? 14 : 11)),
          ),
        ),
        const SizedBox(height: 6),
        Text(etiqueta, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _buildBarraProgreso() {
    final progreso = (_totalKcal / _objetivoCalorias).clamp(0.0, 1.0);
    final color = progreso < 0.7 ? Colors.green : progreso < 0.9 ? Colors.orange : Colors.red;
    final restante = _objetivoCalorias - _totalKcal;

    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Objetivo diario", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colorScheme.onSurface)),
              Text("${_objetivoCalorias.toStringAsFixed(0)} kcal",
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Semantics(
              label: '${(_totalKcal / _objetivoCalorias * 100).clamp(0, 100).toStringAsFixed(0)} por ciento del objetivo calórico diario',
              child: LinearProgressIndicator(
                value: progreso,
                backgroundColor: colorScheme.surfaceContainerHighest,
                color: color,
                minHeight: 12,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${_totalKcal.toStringAsFixed(0)} kcal consumidas",
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
              Text(restante > 0 ? "Faltan ${restante.toStringAsFixed(0)} kcal" : "¡Objetivo superado!",
                  style: TextStyle(
                      color: restante > 0 ? colorScheme.onSurfaceVariant : Colors.red,
                      fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGraficaSemanal() {
    if (_datosSemana.isEmpty) return const SizedBox.shrink();

    final maxKcal = _datosSemana
        .map((d) => (d[1] ?? 0).toDouble())
        .fold(0.0, (a, b) => a > b ? a : b);

    final diasSemana = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Gráfica de calorías de los últimos 7 días. ${_datosSemana.map((d) => "${['Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'][(DateTime.tryParse(d[0].toString())?.weekday ?? 1) - 1]}: ${(d[1] ?? 0).toStringAsFixed(0)} kcal").join(', ')}',
      child: ExcludeSemantics(child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("ÚLTIMOS 7 DÍAS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1, color: colorScheme.onSurface)),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _datosSemana.map((dato) {
                final kcal = (dato[1] ?? 0).toDouble();
                final altura = maxKcal > 0 ? (kcal / maxKcal) : 0.0;
                final fecha = dato[0].toString();
                final dia = DateTime.tryParse(fecha);
                final etiqueta = dia != null ? diasSemana[dia.weekday - 1] : "?";
                final esHoy = fecha == DateTime.now().toIso8601String().substring(0, 10);

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text("${kcal.toStringAsFixed(0)}",
                        style: TextStyle(fontSize: 8, color: colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      width: 28,
                      height: (altura * 60).clamp(4.0, 60.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: esHoy
                              ? [const Color(0xFF6A11CB), const Color(0xFF2575FC)]
                              : [Colors.blue[200]!, Colors.blue[400]!],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(etiqueta,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: esHoy ? FontWeight.bold : FontWeight.normal,
                            color: esHoy ? Colors.deepPurple : colorScheme.onSurfaceVariant)),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    )),
    );
  }

  Widget _buildSectionHeader(String titulo, IconData icono, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          Icon(icono, color: color, size: 18),
          const SizedBox(width: 8),
          Text(titulo, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.bold,
              color: color, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildAlimentoCardIA(Alimento item) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: colorScheme.secondaryContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.deepPurple[100],
          child: const Icon(Icons.auto_awesome, color: Colors.deepPurple, size: 18),
        ),
        title: Text(item.nombre, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colorScheme.onSecondaryContainer)),
        subtitle: Text(
            "${item.kcal} kcal  •  P: ${item.proteinas}g  •  C: ${item.carbohidratos}g  •  G: ${item.grasas}g",
            style: TextStyle(fontSize: 11, color: colorScheme.onSecondaryContainer.withOpacity(0.7))),
        trailing: IconButton(
          tooltip: 'Añadir al diario',
          icon: const Icon(Icons.add_circle, color: Colors.green, size: 32),
          onPressed: () => _guardarEnBaseDeDatos(item),
        ),
      ),
    );
  }

  Widget _buildDiarioTile(dynamic comida) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange[100],
          child: const Icon(Icons.restaurant, color: Colors.deepOrange, size: 18),
        ),
        title: Text(comida['nombre'] ?? "Sin nombre",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: colorScheme.onSurface)),
        subtitle: Text(
            "${comida['calorias']} kcal  •  P: ${comida['proteinas'] ?? 0}g  •  C: ${comida['carbohidratos'] ?? 0}g  •  G: ${comida['grasas'] ?? 0}g",
            style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withOpacity(0.54))),
        trailing: IconButton(
          tooltip: 'Eliminar del diario',
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          onPressed: () => _borrarComida(comida['idComida'] ?? comida['id']),
        ),
      ),
    );
  }

  Widget _buildResumenTotal() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 25),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("TOTAL HOY:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: colorScheme.onSurface)),
          Text("${_totalKcal.toStringAsFixed(0)} kcal",
              style: const TextStyle(fontSize: 26, color: Colors.deepPurple, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _mostrarSnack(String msg, Color col) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: col,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }
}