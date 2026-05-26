import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/api_constants.dart';
import '../exercise_selection_screen.dart';

// 👇 AQUÍ IMPORTAMOS LA ANIMACIÓN DEL LOGRO QUE YA TIENES CREADA
import '../../../widgets/logro_dialog.dart';

class CreateRoutineScreen extends StatefulWidget {
  // Si esto llega null = Crear. Si llega con datos = Editar.
  final Map<String, dynamic>? rutinaEdicion;

  const CreateRoutineScreen({super.key, this.rutinaEdicion});

  @override
  State<CreateRoutineScreen> createState() => _CreateRoutineScreenState();
}

class _CreateRoutineScreenState extends State<CreateRoutineScreen> {
  final TextEditingController _nombreController = TextEditingController();
  List<Map<String, dynamic>> _ejerciciosSeleccionados = [];
  bool _guardando = false;
  String _iconoSeleccionado = "🏋️‍♂️";
  final List<String> _opcionesIconos = ["🏋️‍♂️", "💪", "🦵", "🧍", "👕", "⚡", "🔥", "🏃‍♂️", "⏱️"];

  @override
  void initState() {
    super.initState();
    // Si estamos editando, rellenamos los datos
    if (widget.rutinaEdicion != null) {
      _nombreController.text = widget.rutinaEdicion!['nombre'] ?? '';
      _iconoSeleccionado = widget.rutinaEdicion!['icono'] ?? '🏋️‍♂️';
      if (widget.rutinaEdicion!['ejercicios'] != null) {
        _ejerciciosSeleccionados = List<Map<String, dynamic>>.from(widget.rutinaEdicion!['ejercicios']);
      }
    }
  }

  Future<void> _guardarPlantillaEnNube() async {
    if (_nombreController.text.isEmpty || _ejerciciosSeleccionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pon un nombre y al menos 1 ejercicio.'), backgroundColor: Colors.orange));
      return;
    }
    setState(() => _guardando = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      bool esEdicion = widget.rutinaEdicion != null;
      final urlStr = esEdicion ? "${ApiConstants.rutinas}/${widget.rutinaEdicion!['idRutina']}" : ApiConstants.rutinas;
      final url = Uri.parse(urlStr);

      List<int> idsEjercicios = _ejerciciosSeleccionados.map((ej) => ej["idEjercicio"] as int).toList();

      final bodyJson = jsonEncode({
        "nombre": _nombreController.text,
        "icono": _iconoSeleccionado,
        "ejerciciosIds": idsEjercicios
      });

      http.Response response;
      if (esEdicion) {
        response = await http.put(url, headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}, body: bodyJson);
      } else {
        response = await http.post(url, headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}, body: bodyJson);
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {

          // 👇 LA MAGIA DE LOS LOGROS EN LA PANTALLA DE CREAR RUTINA 👇
          try {
            // Usamos response.body directo para evitar el problema de los acentos que te vaciaba los logros antes
            var decodedBody = jsonDecode(response.body);
            List<dynamic> nuevosLogros = decodedBody["nuevosLogros"] ?? [];

            if (nuevosLogros.isNotEmpty) {
              for (var logro in nuevosLogros) {
                // Si Java dice que ganamos "El Arquitecto", lanzamos tu animación pop-up
                await showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext context) {
                      return DialogoCelebracionLogro(
                        logro: logro,
                        colorBrillo: obtenerColorGlow(logro["dificultad"]),
                      );
                    }
                );
              }
            }
          } catch (e) {
            // Lo ignoramos. Si es un PUT (edición), Java no devuelve los logros, devuelve solo la Rutina, así que daría error el jsonDecode.
          }

          if (mounted) {
            Navigator.pop(context, true); // Cerramos y avisamos que hay que recargar la lista
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Plantilla guardada.'), backgroundColor: Colors.green));
          }
        }
      }
    } catch (e) {
      print("Error: $e");
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _mostrarSelectorIconos() {
    showModalBottomSheet(
        context: context,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (BuildContext context) {
          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Elige el logo de la rutina", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 15, runSpacing: 15,
                  children: _opcionesIconos.map((icono) => Semantics(
                    label: 'Seleccionar icono $icono',
                    button: true,
                    child: GestureDetector(
                    onTap: () {
                      setState(() => _iconoSeleccionado = icono);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(15)),
                      child: ColorFiltered(
                        colorFilter: ColorFilter.mode(Theme.of(context).primaryColor, BlendMode.srcIn),
                        child: Text(icono, style: const TextStyle(fontSize: 32)),
                      ),
                    ),
                  ))).toList(),
                ),
                const SizedBox(height: 30),
              ],
            ),
          );
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    String titulo = widget.rutinaEdicion != null ? "Editar Plantilla" : "Diseñar Plantilla";

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        actions: [
          _guardando
              ? Padding(padding: const EdgeInsets.all(15.0), child: CircularProgressIndicator(color: Theme.of(context).primaryColor))
              : TextButton(onPressed: _guardarPlantillaEnNube, child: Text("GUARDAR", style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)))
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Semantics(
                  label: 'Selector de icono de rutina, toca para cambiar',
                  button: true,
                  child: GestureDetector(
                    onTap: _mostrarSelectorIconos,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface.withOpacity(0.8), borderRadius: BorderRadius.circular(15), border: Border.all(color: Theme.of(context).primaryColor, width: 2)),
                      child: ColorFiltered(
                        colorFilter: ColorFilter.mode(Theme.of(context).primaryColor, BlendMode.srcIn),
                        child: Text(_iconoSeleccionado, style: const TextStyle(fontSize: 35)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: TextField(
                    controller: _nombreController,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Nombre de la rutina',
                      hintText: "Nombre (ej. Empuje)",
                      hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface.withOpacity(0.5),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.3))), 
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2))
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            Text("Ejercicios de la rutina (Arrastra para ordenar):", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            Expanded(
              child: _ejerciciosSeleccionados.isEmpty
                  ? const Center(child: Text("Aún no has añadido ejercicios.", style: TextStyle(color: Colors.grey)))
                  : ReorderableListView.builder(
                itemCount: _ejerciciosSeleccionados.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = _ejerciciosSeleccionados.removeAt(oldIndex);
                    _ejerciciosSeleccionados.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final ej = _ejerciciosSeleccionados[index];
                  return Card(
                    key: ValueKey("${ej['idEjercicio']}_$index"),
                    color: Colors.transparent,
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 5),
                    child: ListTile(
                      leading: ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_handle, color: Colors.grey)),
                      title: Text(ej["nombre"]),
                      subtitle: Text(ej["grupoMuscular"] ?? "General", style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 12)),
                      trailing: IconButton(tooltip: 'Eliminar ejercicio de la rutina', icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => setState(() => _ejerciciosSeleccionados.removeAt(index))),
                    ),
                  );
                },
              ),
            ),

            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () async {
                  final nuevoEj = await Navigator.push(context, MaterialPageRoute(builder: (context) => const ExerciseSelectionScreen()));
                  if (nuevoEj != null) setState(() => _ejerciciosSeleccionados.add(nuevoEj));
                },
                icon: Icon(Icons.add, color: Theme.of(context).primaryColor), label: Text("Añadir Ejercicio", style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}