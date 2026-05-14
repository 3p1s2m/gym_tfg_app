import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/api_constants.dart';
import 'create_routine_screen.dart';
import 'active_workout_screen.dart';
import '../coach_catalog_screen.dart';
import '../sueno_screen.dart';

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key});

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  List<Map<String, dynamic>> _misRutinas = [];
  List<Map<String, dynamic>> _rutinasEntrenador = [];
  List<Map<String, dynamic>> _rutinasArchivadas = [];

  bool _cargando = true;
  bool _tieneEntrenador = false;
  bool _esEntrenador = false;
  bool _viendoArchivadas = false;
  int _tabActual = 0;

  @override
  void initState() {
    super.initState();
    _cargarDatosDeArranque();
  }

  Future<void> _cargarDatosDeArranque() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    setState(() {
      _esEntrenador = prefs.getString('user_role') == 'entrenador';
    });

    if (!_esEntrenador && token != null) {
      try {
        final res = await http.get(
            Uri.parse("${ApiConstants.baseUrl}/usuarios/mi-entrenador"),
            headers: {'Authorization': 'Bearer $token'}
        );
        bool tieneReal = (res.statusCode == 200);
        await prefs.setBool('tiene_entrenador', tieneReal);
        if (mounted) setState(() => _tieneEntrenador = tieneReal);
      } catch(e) {
        if (mounted) setState(() => _tieneEntrenador = prefs.getBool('tiene_entrenador') ?? false);
      }
    }

    await _cargarRutinasDeLaNube();
  }

  Future<void> _cargarRutinasDeLaNube() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) {
        if (mounted) setState(() => _cargando = false);
        return;
      }

      final url = Uri.parse(ApiConstants.rutinas);
      final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        List<Map<String, dynamic>> propias = [];
        List<Map<String, dynamic>> delEntrenador = [];
        List<Map<String, dynamic>> archivadas = [];

        for (var r in data) {
          if (r["archivada"] == true) {
            archivadas.add(r);
          } else if (r["esDelEntrenador"] == true && !_esEntrenador) {
            delEntrenador.add(r);
          } else {
            propias.add(r);
          }
        }

        if (mounted) {
          setState(() {
            _misRutinas = propias;
            _rutinasEntrenador = delEntrenador;
            _rutinasArchivadas = archivadas;
            _cargando = false;
          });
        }
      } else {
        if (mounted) setState(() => _cargando = false);
      }
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _eliminarRutina(Map<String, dynamic> rutina) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return;
      final url = Uri.parse("${ApiConstants.rutinas}/${rutina['idRutina']}");
      final response = await http.delete(url, headers: {'Authorization': 'Bearer $token'});

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🗑️ Plantilla eliminada'), backgroundColor: Colors.redAccent));
          setState(() => _cargando = true);
          _cargarRutinasDeLaNube();
        }
      } else {
        if (mounted) _mostrarDialogoArchivar(rutina);
      }
    } catch (e) {
      debugPrint("Error eliminando: $e");
    }
  }

  Future<void> _cambiarEstadoArchivo(int idRutina, bool archivar) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return;
      String accion = archivar ? "archivar" : "desarchivar";
      final url = Uri.parse("${ApiConstants.rutinas}/$idRutina/$accion");
      final response = await http.put(url, headers: {'Authorization': 'Bearer $token'});

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(archivar ? '📦 Plantilla archivada' : '✅ Plantilla restaurada'),
              backgroundColor: Colors.green));
          setState(() => _cargando = true);
          _cargarRutinasDeLaNube();
        }
      }
    } catch (e) {
      debugPrint("Error archivando: $e");
    }
  }

  void _confirmarBorrado(Map<String, dynamic> rutina) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text("¿Eliminar plantilla?"),
        content: Text("¿Seguro que quieres borrar '${rutina["nombre"]}'?",
            style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancelar", style: TextStyle(color: Theme.of(context).primaryColor))),
          TextButton(
              onPressed: () { Navigator.pop(context); _eliminarRutina(rutina); },
              child: const Text("Eliminar", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
  }

  void _mostrarDialogoArchivar(Map<String, dynamic> rutina) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text("No se puede borrar"),
        content: const Text(
            "Esta plantilla ya tiene un historial de entrenamientos.\n\n¿Quieres archivarla para ocultarla de tu lista principal?",
            style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          TextButton(
              onPressed: () { Navigator.pop(context); _cambiarEstadoArchivo(rutina["idRutina"], true); },
              child: Text("Archivar",
                  style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _construirIcono(String? iconoStr) {
    if (iconoStr == null || iconoStr.isEmpty || iconoStr == "null") {
      return Icon(Icons.fitness_center, color: Theme.of(context).primaryColor, size: 28);
    }
    return ColorFiltered(
        colorFilter: ColorFilter.mode(Theme.of(context).primaryColor, BlendMode.srcIn),
        child: Text(iconoStr, style: const TextStyle(fontSize: 24)));
  }

  @override
  Widget build(BuildContext context) {
    if (_viendoArchivadas) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('PAPELERA',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2.0)),
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
          leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _viendoArchivadas = false)),
        ),
        body: _cargando
            ? Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))
            : _buildListaArchivadas(),
      );
    }

    return DefaultTabController(
      length: _esEntrenador ? 1 : 3,
      child: Builder(
        builder: (context) {
          final tabController = DefaultTabController.of(context);
          tabController.addListener(() {
            if (mounted) setState(() => _tabActual = tabController.index);
          });

          return Scaffold(
            appBar: AppBar(
              title: const Text('RUTINAS',
                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2.0)),
              backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
              foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
              elevation: 0,
              centerTitle: true,
              actions: [
                IconButton(
                    icon: Icon(Icons.archive_outlined, color: Theme.of(context).primaryColor),
                    onPressed: () => setState(() => _viendoArchivadas = true)),
                const SizedBox(width: 10),
              ],
              bottom: TabBar(
                indicatorColor: Theme.of(context).primaryColor,
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey,
                tabs: [
                  Tab(
                      icon: const Icon(Icons.person),
                      text: _esEntrenador ? "Mi Biblioteca" : "Mis Plantillas"),
                  if (!_esEntrenador) const Tab(icon: Icon(Icons.sports), text: "Mi Entrenador"),
                  if (!_esEntrenador) const Tab(icon: Icon(Icons.bedtime), text: "Sueño"),
                ],
              ),
            ),
            body: _cargando
                ? Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))
                : TabBarView(
              children: [
                _buildListaRutinas(_misRutinas, false),
                if (!_esEntrenador)
                  _tieneEntrenador
                      ? _buildListaRutinas(_rutinasEntrenador, true)
                      : _buildMuroDePagoPremium(),
                if (!_esEntrenador) const SuenoScreen(),
              ],
            ),
            floatingActionButton: (_tabActual == 2 && !_esEntrenador)
                ? null
                : FloatingActionButton.extended(
              backgroundColor: Theme.of(context).primaryColor,
              onPressed: () async {
                final recargar = await Navigator.push(context,
                    MaterialPageRoute(builder: (context) => const CreateRoutineScreen()));
                if (recargar == true) {
                  setState(() => _cargando = true);
                  _cargarRutinasDeLaNube();
                }
              },
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text("Nueva Plantilla",
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildListaRutinas(List<Map<String, dynamic>> lista, bool esEntrenadorView) {
    if (lista.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                  esEntrenadorView ? Icons.assignment_ind_outlined : Icons.fitness_center,
                  size: 80,
                  color: Colors.grey.withValues(alpha: 0.3)),
              const SizedBox(height: 20),
              Text(
                  esEntrenadorView
                      ? "Tu entrenador aún no te ha\nasignado ninguna rutina para hoy."
                      : "No tienes rutinas creadas.\n¡Crea tu primera plantilla!",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: lista.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex -= 1;
          final item = lista.removeAt(oldIndex);
          lista.insert(newIndex, item);
        });
      },
      itemBuilder: (context, index) {
        final rutina = lista[index];
        final int numEjercicios = (rutina["ejercicios"] as List?)?.length ?? 0;

        return Card(
          key: ValueKey("rutina_${rutina['idRutina']}_$index"),
          color: Theme.of(context).colorScheme.surface,
          margin: const EdgeInsets.only(bottom: 15),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: const BorderSide(color: Colors.white12, width: 1)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                      padding: EdgeInsets.only(right: 10.0),
                      child: Icon(Icons.drag_handle, color: Colors.grey)),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: _construirIcono(rutina["icono"]),
                ),
              ],
            ),
            title: Text(rutina["nombre"] ?? "Sin nombre",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            subtitle: Text("$numEjercicios ejercicios",
                style: const TextStyle(color: Colors.grey)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!esEntrenadorView) ...[
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.grey),
                    onPressed: () async {
                      final recargar = await Navigator.push(context,
                          MaterialPageRoute(
                              builder: (context) => CreateRoutineScreen(rutinaEdicion: rutina)));
                      if (recargar == true) {
                        setState(() => _cargando = true);
                        _cargarRutinasDeLaNube();
                      }
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        color: Colors.grey.withValues(alpha: 0.5)),
                    onPressed: () => _confirmarBorrado(rutina),
                  ),
                ],
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle),
                  child: Icon(Icons.play_arrow,
                      color: Theme.of(context).primaryColor, size: 24),
                ),
              ],
            ),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(
                    builder: (context) => ActiveWorkoutScreen(plantilla: rutina))),
          ),
        );
      },
    );
  }

  Widget _buildListaArchivadas() {
    if (_rutinasArchivadas.isEmpty) {
      return const Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 20),
            Text("Tu papelera está vacía.", style: TextStyle(color: Colors.grey, fontSize: 16))
          ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: _rutinasArchivadas.length,
      itemBuilder: (context, index) {
        final rutina = _rutinasArchivadas[index];
        return Card(
          color: Theme.of(context).colorScheme.surface,
          margin: const EdgeInsets.only(bottom: 15),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: const BorderSide(color: Colors.white12, width: 1)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            leading: ColorFiltered(
                colorFilter: const ColorFilter.matrix([
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0, 0, 0, 0.4, 0
                ]),
                child: _construirIcono(rutina["icono"])),
            title: Text(rutina["nombre"] ?? "Sin nombre",
                style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    decoration: TextDecoration.lineThrough)),
            trailing: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.withValues(alpha: 0.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                icon: const Icon(Icons.restore, color: Colors.greenAccent),
                label: const Text("Restaurar",
                    style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                onPressed: () => _cambiarEstadoArchivo(rutina["idRutina"], false)),
          ),
        );
      },
    );
  }

  Widget _buildMuroDePagoPremium() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    boxShadow: [
                      BoxShadow(
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                          blurRadius: 20,
                          spreadRadius: 5)
                    ]),
                child: Icon(Icons.lock_outline, size: 70, color: Theme.of(context).primaryColor)),
            const SizedBox(height: 30),
            const Text("Sube al siguiente nivel",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            const SizedBox(height: 15),
            const Text(
                "Contrata a un entrenador personal para recibir rutinas semanales adaptadas a tus objetivos, revisión técnica y chat directo 24/7.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 15, height: 1.5)),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                icon: const Icon(Icons.star, color: Colors.black),
                label: const Text("VER PLANES PREMIUM",
                    style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 1.2)),
                onPressed: () async {
                  final bool? contratado = await Navigator.push(context,
                      MaterialPageRoute(builder: (context) => const CoachCatalogScreen()));
                  if (contratado == true) {
                    setState(() => _cargando = true);
                    await _cargarDatosDeArranque();
                  }
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}