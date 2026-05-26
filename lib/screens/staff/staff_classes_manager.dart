import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/api_constants.dart';

class StaffClassesManager extends StatefulWidget {
  const StaffClassesManager({super.key});
  @override
  State<StaffClassesManager> createState() => _StaffClassesManagerState();
}

class _StaffClassesManagerState extends State<StaffClassesManager> {
  List<dynamic> _clases = [];
  List<dynamic> _entrenadores = [];
  bool _cargando = true;

  late List<DateTime> _proximos7Dias;
  late DateTime _fechaActiva;

  final List<Map<String, String>> _plantillas = [
    {"nombre": "Spinning", "color": "00bcd4", "imagen": "https://images.unsplash.com/photo-1517836357463-d25dfeac3438?q=80&w=600"},
    {"nombre": "Yoga", "color": "8bc34a", "imagen": "https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?q=80&w=600"},
    {"nombre": "CrossFit", "color": "f44336", "imagen": "https://images.unsplash.com/photo-1534438327276-14e5300c3a48?q=80&w=600"},
    {"nombre": "Pilates", "color": "9c27b0", "imagen": "https://images.unsplash.com/photo-1518611012118-696072aa579a?q=80&w=600"},
  ];

  @override
  void initState() {
    super.initState();
    DateTime hoy = DateTime.now();
    _proximos7Dias = List.generate(7, (index) => hoy.add(Duration(days: index)));
    _fechaActiva = _proximos7Dias.first;
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return;

      final resClases = await http.get(Uri.parse(ApiConstants.clasesGrupales), headers: {'Authorization': 'Bearer $token'});
      final resCoaches = await http.get(Uri.parse("${ApiConstants.baseUrl}/usuarios/entrenadores"), headers: {'Authorization': 'Bearer $token'});

      if (resClases.statusCode == 200 && resCoaches.statusCode == 200) {
        if (mounted) {
          setState(() {
            _clases = jsonDecode(utf8.decode(resClases.bodyBytes));
            _entrenadores = jsonDecode(utf8.decode(resCoaches.bodyBytes));
            _cargando = false;
          });
        }
      }
    } catch(e) {
      if(mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _eliminarClase(int idClase) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(backgroundColor: Theme.of(context).colorScheme.surface, title: const Text('¿Cancelar Clase?'), content: const Text('Esto borrará la clase y eliminará a todos los apuntados.', style: TextStyle(color: Colors.grey)), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Volver')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí, borrar', style: TextStyle(color: Colors.red)))]),
    );

    if (confirmar == true) {
      setState(() => _cargando = true);
      final prefs = await SharedPreferences.getInstance();
      await http.delete(Uri.parse(ApiConstants.staffEliminarClase(idClase)), headers: {'Authorization': 'Bearer ${prefs.getString('jwt_token')}'});
      _cargarDatos();
    }
  }

  void _abrirCrearClase(Map<String, String> plantilla) {
    TextEditingController salaCtrl = TextEditingController();
    DateTime fechaElegida = DateTime.now();
    TimeOfDay horaElegida = TimeOfDay.now();
    String aforoSeleccionado = '20';
    String? profeSeleccionado;

    Color colorFondoInput = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1);

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
          builder: (context, setModalState) {
            return FocusTraversalGroup(
              policy: ReadingOrderTraversalPolicy(),
              child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Programar: ${plantilla["nombre"]}', style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  DropdownButtonFormField<String>(
                    value: profeSeleccionado,
                    dropdownColor: Theme.of(context).colorScheme.surface,
                    decoration: InputDecoration(
                        labelText: "Instructor", labelStyle: const TextStyle(color: Colors.grey),
                        filled: true, fillColor: colorFondoInput,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)
                    ),
                    items: _entrenadores.map<DropdownMenuItem<String>>((coach) {
                      return DropdownMenuItem<String>(value: coach["nombre"], child: Text(coach["nombre"]));
                    }).toList(),
                    onChanged: (value) => setModalState(() => profeSeleccionado = value),
                  ),

                  const SizedBox(height: 15),
                  TextField(controller: salaCtrl, decoration: InputDecoration(labelText: 'Sala (Ej: Ciclo)', labelStyle: const TextStyle(color: Colors.grey), filled: true, fillColor: colorFondoInput, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.calendar_today, size: 16), label: Text("${fechaElegida.day}/${fechaElegida.month}", style: TextStyle(color: Theme.of(context).primaryColor)), onPressed: () async {
                        DateTime? date = await showDatePicker(context: context, initialDate: fechaElegida, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30)));
                        if (date != null) setModalState(() => fechaElegida = date);
                      })),
                      const SizedBox(width: 10),
                      Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.access_time, size: 16), label: Text(horaElegida.format(context), style: TextStyle(color: Theme.of(context).primaryColor)), onPressed: () async {
                        TimeOfDay? time = await showTimePicker(context: context, initialTime: horaElegida);
                        if (time != null) setModalState(() => horaElegida = time);
                      })),
                    ],
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    value: aforoSeleccionado, dropdownColor: Theme.of(context).colorScheme.surface, decoration: InputDecoration(labelText: "Aforo Máximo", labelStyle: const TextStyle(color: Colors.grey), filled: true, fillColor: colorFondoInput, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
                    items: ['10', '15', '20', '30', '50'].map((String a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                    onChanged: (value) => setModalState(() => aforoSeleccionado = value!),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                      onPressed: () async {
                        if (profeSeleccionado == null || salaCtrl.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Elige un instructor y una sala', style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent));
                          return;
                        }

                        Navigator.pop(context); setState(() => _cargando = true);
                        DateTime finalD = DateTime(fechaElegida.year, fechaElegida.month, fechaElegida.day, horaElegida.hour, horaElegida.minute);

                        final prefs = await SharedPreferences.getInstance();
                        await http.post(Uri.parse(ApiConstants.staffCrearClase), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${prefs.getString('jwt_token')}'},
                            body: jsonEncode({"nombre": plantilla["nombre"], "entrenador": profeSeleccionado, "sala": salaCtrl.text, "totales": int.parse(aforoSeleccionado), "fechaHora": finalD.toIso8601String(), "colorHex": plantilla["color"], "imagenUrl": plantilla["imagen"]})
                        );
                        _cargarDatos();
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Clase publicada en la App'), backgroundColor: Colors.green));
                      },
                      child: const Text('PUBLICAR CLASE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
              ),
            );
          }
      ),
    );
  }

  void _seleccionarPlantilla() {
    showModalBottomSheet(
        context: context, backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) => FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text("Elige una Plantilla", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ..._plantillas.map((p) => ListTile(
              leading: Semantics(
                label: 'Imagen de plantilla ${p["nombre"]}',
                image: true,
                child: CircleAvatar(backgroundImage: CachedNetworkImageProvider(p["imagen"]!)),
              ),
              title: Text(p["nombre"]!, style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: Icon(Icons.add_circle, color: Theme.of(context).primaryColor),
              onTap: () { Navigator.pop(context); _abrirCrearClase(p); },
            ))
          ],
          ),
        )
    );
  }

  // Helpers para la vista
  bool _esMismoDia(DateTime d1, DateTime d2) => d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  String _formatearHora(DateTime d) => "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";
  Color _colorFromHex(String? hexString) {
    if (hexString == null || hexString.isEmpty) return Theme.of(context).primaryColor;
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    try { return Color(int.parse(buffer.toString(), radix: 16)); } catch(e) { return Theme.of(context).primaryColor; }
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> clasesFiltradas = _clases.where((clase) {
      if (clase["fechaHora"] == null) return false;
      return _esMismoDia(DateTime.parse(clase["fechaHora"]), _fechaActiva);
    }).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('GESTIÓN DE CLASES', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2.0)), centerTitle: true, elevation: 0, backgroundColor: Theme.of(context).appBarTheme.backgroundColor, foregroundColor: Theme.of(context).appBarTheme.foregroundColor),
      floatingActionButton: FloatingActionButton.extended(backgroundColor: Theme.of(context).primaryColor, onPressed: _seleccionarPlantilla, icon: const Icon(Icons.add, color: Colors.black), label: const Text("Nueva Clase", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),

      body: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: Column(
        children: [
          // 👇 LA SEMANA IGUAL QUE EN EL MURO SOCIAL
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _proximos7Dias.map((fecha) {
                bool activo = _esMismoDia(fecha, _fechaActiva);
                const nombresDias = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"];
                return Semantics(
                  label: nombresDias[fecha.weekday - 1],
                  button: true,
                  child: GestureDetector(
                    onTap: () => setState(() => _fechaActiva = fecha),
                    child: CircleAvatar(
                      radius: 20, backgroundColor: activo ? Theme.of(context).primaryColor : Colors.transparent,
                      child: Text(["L", "M", "M", "J", "V", "S", "D"][fecha.weekday - 1], style: TextStyle(color: activo ? Colors.black : Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // 👇 LISTA DE CLASES CON EL DISEÑO DEL CLIENTE Y EL BOTÓN DE BORRAR
          Expanded(
            child: _cargando
                ? Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))
                : clasesFiltradas.isEmpty
                ? const Center(child: Text("No hay clases programadas para hoy.", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              itemCount: clasesFiltradas.length,
              itemBuilder: (context, index) {
                final clase = clasesFiltradas[index];
                Color colorClase = _colorFromHex(clase["colorHex"]);
                DateTime d = DateTime.parse(clase["fechaHora"]);

                return Card(
                  color: Theme.of(context).colorScheme.surface, margin: const EdgeInsets.only(bottom: 15), clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Colors.transparent, width: 2)),
                  child: SizedBox(
                    height: 120,
                    child: Stack(
                      children: [
                        Row(
                          children: [
                            Expanded(flex: 4, child: ColorFiltered(colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation), child: CachedNetworkImage(imageUrl: clase["imagenUrl"] ?? "", fit: BoxFit.cover, height: double.infinity, errorWidget: (context, url, error) => Container(color: Colors.black26), imageBuilder: (context, imageProvider) => Semantics(label: 'Imagen de ${clase["nombre"] ?? "la clase"}', child: Image(image: imageProvider, fit: BoxFit.cover, height: double.infinity))))),
                            Expanded(flex: 6, child: Container(decoration: BoxDecoration(border: Border(right: BorderSide(color: colorClase, width: 6))), padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_formatearHora(d), style: const TextStyle(color: Colors.grey, fontSize: 14)), Text("${clase["ocupadas"] ?? 0} / ${clase["totales"] ?? 20} plazas", style: TextStyle(color: colorClase, fontSize: 12, fontWeight: FontWeight.bold))]), const Spacer(), Text(clase["nombre"] ?? "Clase", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(clase["sala"] ?? "Sala 1", style: const TextStyle(color: Colors.grey, fontSize: 14))]))),
                          ],
                        ),
                        // 👇 EL BOTÓN DE BORRAR PARA EL STAFF (Arriba a la derecha)
                        Positioned(
                          top: 5,
                          right: 15,
                          child: IconButton(
                              tooltip: 'Eliminar clase',
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => _eliminarClase(clase["idClase"])
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }
}