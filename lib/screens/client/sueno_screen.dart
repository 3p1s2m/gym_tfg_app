import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class SuenoScreen extends StatefulWidget {
  const SuenoScreen({super.key});

  @override
  State<SuenoScreen> createState() => _SuenoScreenState();
}

class _SuenoScreenState extends State<SuenoScreen> {
  final FlutterLocalNotificationsPlugin _notificaciones = FlutterLocalNotificationsPlugin();

  TimeOfDay _horaInicio = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _horaFin = const TimeOfDay(hour: 7, minute: 0);
  List<dynamic> _registrosSemana = [];
  List<dynamic> _registrosHoy = [];
  bool _cargando = true;
  String _userId = '1';
  double _horasObjetivo = 8.0;

  final Map<String, Map<String, dynamic>> _recomendaciones = {
    'excelente': {'color': Colors.green, 'emoji': '😴', 'texto': 'Sueño excelente. Tu recuperación muscular será óptima.'},
    'bueno': {'color': Colors.lightGreen, 'emoji': '🙂', 'texto': 'Buen descanso. Rinde bien en el entreno de hoy.'},
    'regular': {'color': Colors.orange, 'emoji': '😐', 'texto': 'Descanso justo. Considera reducir la intensidad hoy.'},
    'malo': {'color': Colors.red, 'emoji': '😔', 'texto': 'Poco descanso. Tu cortisol estará alto. Evita entrenar pesado.'},
  };

  @override
  void initState() {
    super.initState();
    _inicializarNotificaciones();
    _cargarDatos();
  }

  Future<void> _inicializarNotificaciones() async {
    const AndroidInitializationSettings android =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings = InitializationSettings(android: android);
    await _notificaciones.initialize(settings);
  }

  Future<void> _cargarDatos() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id') ?? '1';
    await Future.wait([_cargarHoy(), _cargarSemanal()]);
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _cargarHoy() async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8080/api/sueno/hoy/$_userId'),
      ).timeout(const Duration(seconds: 5));

      debugPrint("STATUS HOY: ${response.statusCode}");
      debugPrint("BODY HOY: ${response.body}"); // 👈 AÑADE ESTO

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) setState(() => _registrosHoy = data is List ? data : []);
      }
    } catch (e) {
      debugPrint("Error cargando sueño hoy: $e");
    }
  }

  Future<void> _cargarSemanal() async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8080/api/sueno/semanal/$_userId'),
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        if (mounted) setState(() => _registrosSemana = jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint("Error cargando semanal sueño: $e");
    }
  }

  Future<void> _guardarRegistro() async {
    debugPrint("🔥 GUARDANDO REGISTRO...");
    final inicio = '${_horaInicio.hour.toString().padLeft(2, '0')}:${_horaInicio.minute.toString().padLeft(2, '0')}';
    final fin = '${_horaFin.hour.toString().padLeft(2, '0')}:${_horaFin.minute.toString().padLeft(2, '0')}';
    debugPrint("🕐 Inicio: $inicio - Fin: $fin - UserId: $_userId");

    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:8080/api/sueno/guardar'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'usuarioId': int.parse(_userId),
          'horaInicio': inicio,
          'horaFin': fin,
        }),
      );
      debugPrint("📡 STATUS: ${response.statusCode}");
      debugPrint("📡 BODY: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        _mostrarSnack('✅ Sueño registrado correctamente', Colors.green);
        await _cargarDatos();
        await _programarAlarma();
      }
    } catch (e) {
      debugPrint("❌ ERROR: $e");
      _mostrarSnack('❌ Error al guardar: $e', Colors.red);
    }
  }

  Future<void> _borrarRegistro(dynamic id) async {
    try {
      final response = await http.delete(
        Uri.parse('http://10.0.2.2:8080/api/sueno/borrar/$id'),
      );
      if (response.statusCode == 200) {
        _mostrarSnack('🗑️ Registro eliminado', Colors.blueGrey);
        await _notificaciones.cancel(id.hashCode);
        await _cargarDatos();
      }
    } catch (e) {
      _mostrarSnack('❌ Error al borrar', Colors.red);
    }
  }

  Future<void> _programarAlarma() async {
    await _notificaciones.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '✅ Sueño registrado',
      'Te despertarás a las ${_horaFin.hour.toString().padLeft(2, '0')}:${_horaFin.minute.toString().padLeft(2, '0')}. ¡Buenas noches!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'sueno_channel', 'Alarma Sueño',
          channelDescription: 'Alarma para despertar',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
      ),
    );
    _mostrarSnack('⏰ Alarma programada para las ${_horaFin.format(context)}', Colors.blue);
  }

  String _calcularHorasTexto() {
    int minInicio = _horaInicio.hour * 60 + _horaInicio.minute;
    int minFin = _horaFin.hour * 60 + _horaFin.minute;
    if (minFin < minInicio) minFin += 1440;
    return ((minFin - minInicio) / 60.0).toStringAsFixed(1);
  }

  Map<String, dynamic> _getRecomendacion(double horas) {
    if (horas >= 8) return _recomendaciones['excelente']!;
    if (horas >= 7) return _recomendaciones['bueno']!;
    if (horas >= 6) return _recomendaciones['regular']!;
    return _recomendaciones['malo']!;
  }

  Future<void> _seleccionarHora(bool esInicio) async {
    final hora = await showTimePicker(
      context: context,
      initialTime: esInicio ? _horaInicio : _horaFin,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (hora != null) {
      setState(() {
        if (esInicio) _horaInicio = hora;
        else _horaFin = hora;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    final horasTexto = _calcularHorasTexto();
    final horas = double.tryParse(horasTexto) ?? 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        _buildCardRegistro(horasTexto),
        const SizedBox(height: 12),
        _buildListaRegistrosHoy(),
        const SizedBox(height: 12),
        _buildCardObjetivo(),
        const SizedBox(height: 12),
        _buildGraficaSemanal(),
        const SizedBox(height: 12),
        _buildInfoCientifica(),
      ],
    );
  }

  Widget _buildCardRegistro(String horasTexto) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.bedtime, color: Colors.white70, size: 18),
              SizedBox(width: 8),
              Text('NUEVO REGISTRO DE SUEÑO', style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSelectorHora('Me duermo', _horaInicio, true, const Color(0xFF6C63FF)),
              Column(
                children: [
                  Text(horasTexto, style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold)),
                  const Text('horas', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
              _buildSelectorHora('Me despierto', _horaFin, false, const Color(0xFFFF6584)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.save, color: Colors.white, size: 18),
              label: const Text('Guardar y programar alarma', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: _guardarRegistro,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorHora(String label, TimeOfDay hora, bool esInicio, Color color) {
    final horaFormateada = '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';
    return Semantics(
      label: "$label: $horaFormateada, toca para cambiar",
      button: true,
      child: GestureDetector(
      onTap: () => _seleccionarHora(esInicio),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
            const SizedBox(height: 4),
            Text(
              '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}',
              style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildListaRegistrosHoy() {
    if (_registrosHoy.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('No hay registros hoy. ¡Añade tu primer sueño!',
              style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.list, color: Color(0xFF6C63FF), size: 18),
              SizedBox(width: 8),
              Text('REGISTROS DE HOY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 12),
          ..._registrosHoy.map((registro) {
            final horas = (registro['horasDormidas'] ?? 0).toDouble();
            final rec = _getRecomendacion(horas);
            final id = registro['id'];

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: (rec['color'] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: (rec['color'] as Color).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Text(rec['emoji'], style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${registro['horaInicio']} → ${registro['horaFin']}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          '${horas.toStringAsFixed(1)}h dormidas',
                          style: TextStyle(color: rec['color'] as Color, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Eliminar registro de sueño',
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => _borrarRegistro(id),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCardObjetivo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.flag, color: Color(0xFF6C63FF), size: 18),
              SizedBox(width: 8),
              Text('OBJETIVO DE SUEÑO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Horas recomendadas:', style: TextStyle(color: Colors.grey)),
              Text('${_horasObjetivo.toStringAsFixed(0)}h',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          Slider(
            value: _horasObjetivo,
            min: 6,
            max: 10,
            divisions: 8,
            activeColor: const Color(0xFF6C63FF),
            label: '${_horasObjetivo.toStringAsFixed(1)}h',
            semanticFormatterCallback: (v) => '${v.toStringAsFixed(0)} horas',
            onChanged: (val) => setState(() => _horasObjetivo = val),
          ),
          _buildRecomendacionPorObjetivo(),
        ],
      ),
    );
  }

  Widget _buildRecomendacionPorObjetivo() {
    String texto = '';
    if (_horasObjetivo >= 9) texto = '💪 Ideal para atletas en fase de volumen o recuperación intensa.';
    else if (_horasObjetivo >= 8) texto = '🏋️ Perfecto para ganar músculo y optimizar la testosterona.';
    else if (_horasObjetivo >= 7) texto = '⚡ Suficiente para mantenimiento y rendimiento general.';
    else texto = '⚠️ Mínimo recomendado. Puede afectar a la recuperación muscular.';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(texto, style: const TextStyle(fontSize: 12, color: Colors.grey)),
    );
  }

  Widget _buildGraficaSemanal() {
    if (_registrosSemana.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Text('Sin registros esta semana', style: TextStyle(color: Colors.grey))),
      );
    }

    final maxHoras = _registrosSemana
        .map((r) => (r['horasDormidas'] ?? 0).toDouble())
        .fold(0.0, (a, b) => a > b ? a : b);

    final diasSemana = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

    final resumenSemanal = _registrosSemana.map((r) {
      final h = (r['horasDormidas'] ?? 0).toDouble();
      final f = r['fecha']?.toString() ?? '';
      final d = DateTime.tryParse(f);
      final etq = d != null ? ['lunes','martes','miércoles','jueves','viernes','sábado','domingo'][d.weekday - 1] : '';
      return '$etq ${h.toStringAsFixed(1)} horas';
    }).join(', ');

    return Semantics(
      label: 'Gráfica semanal de sueño. $resumenSemanal',
      excludeSemantics: false,
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Row(
            children: const [
              Icon(Icons.bar_chart, color: Color(0xFF6C63FF), size: 18),
              SizedBox(width: 8),
              Text('SUEÑO ESTA SEMANA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
            ],
          ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _registrosSemana.map((registro) {
                final horas = (registro['horasDormidas'] ?? 0).toDouble();
                final altura = maxHoras > 0 ? horas / maxHoras : 0.0;
                final fecha = registro['fecha']?.toString() ?? '';
                final dia = DateTime.tryParse(fecha);
                final etiqueta = dia != null ? diasSemana[dia.weekday - 1] : '?';
                final esHoy = fecha == DateTime.now().toIso8601String().substring(0, 10);
                final rec = _getRecomendacion(horas);

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${horas.toStringAsFixed(1)}h', style: const TextStyle(fontSize: 8, color: Colors.grey)),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      width: 28,
                      height: (altura * 80).clamp(4.0, 80.0),
                      decoration: BoxDecoration(
                        color: esHoy ? const Color(0xFF6C63FF) : (rec['color'] as Color).withOpacity(0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(etiqueta, style: TextStyle(
                        fontSize: 11,
                        fontWeight: esHoy ? FontWeight.bold : FontWeight.normal,
                        color: esHoy ? const Color(0xFF6C63FF) : Colors.grey)),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLeyenda(Colors.green, '+8h Excelente'),
              const SizedBox(width: 12),
              _buildLeyenda(Colors.orange, '6-7h Regular'),
              const SizedBox(width: 12),
              _buildLeyenda(Colors.red, '-6h Malo'),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildLeyenda(Color color, String texto) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(texto, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildInfoCientifica() {
    final items = [
      {'emoji': '🧠', 'titulo': 'Memoria muscular', 'texto': 'Durante el sueño profundo se libera hormona del crecimiento, esencial para reparar fibras musculares.'},
      {'emoji': '⚡', 'titulo': 'Rendimiento', 'texto': 'Dormir menos de 6h reduce la fuerza máxima hasta un 20% y aumenta el tiempo de reacción.'},
      {'emoji': '🔥', 'titulo': 'Quema de grasa', 'texto': 'El sueño regula la leptina y grelina, las hormonas del hambre. Poco sueño = más antojos.'},
      {'emoji': '💉', 'titulo': 'Testosterona', 'texto': 'El 70% de la testosterona diaria se produce mientras duermes. Esencial para ganar músculo.'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.science, color: Color(0xFF6C63FF), size: 18),
              SizedBox(width: 8),
              Text('CIENCIA DEL SUEÑO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['emoji']!, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['titulo']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(item['texto']!, style: const TextStyle(color: Colors.grey, fontSize: 12, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          )),
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