import 'package:flutter/material.dart';
import '../../services/exercise_service.dart';
import 'exercise_detail_screen.dart'; // IMPORTAMOS LA NUEVA PANTALLA

class ExerciseSelectionScreen extends StatefulWidget {
  const ExerciseSelectionScreen({super.key});

  @override
  State<ExerciseSelectionScreen> createState() => _ExerciseSelectionScreenState();
}

class _ExerciseSelectionScreenState extends State<ExerciseSelectionScreen> {
  List<Map<String, dynamic>> _todosLosEjercicios = [];
  List<Map<String, dynamic>> _ejerciciosFiltrados = [];

  bool _cargando = true;
  String _busquedaActual = "";

  // VARIABLES DE LOS FILTROS
  String _filtroMusculo = "Todos";
  String _filtroNivel = "Todos";
  String _filtroEquipo = "Todos";

  // LISTAS DESPLEGABLES (Se rellenan solas)
  List<String> _listaMusculos = ["Todos"];
  List<String> _listaNiveles = ["Todos"];
  List<String> _listaEquipos = ["Todos"];

  @override
  void initState() {
    super.initState();
    _cargarEjerciciosDesdeCache();
  }

  Future<void> _cargarEjerciciosDesdeCache() async {
    final ejerciciosCacheados = await ExerciseService.getExercises();

    Set<String> musculos = {"Todos"};
    Set<String> niveles = {"Todos"};
    Set<String> equipos = {"Todos"};

    for (var ej in ejerciciosCacheados) {
      if (ej["grupoMuscular"] != null) musculos.add(ej["grupoMuscular"].toString().trim());
      if (ej["nivel"] != null) niveles.add(ej["nivel"].toString().trim());
      if (ej["equipamiento"] != null) equipos.add(ej["equipamiento"].toString().trim());
    }

    setState(() {
      _todosLosEjercicios = ejerciciosCacheados;
      _ejerciciosFiltrados = _todosLosEjercicios;

      _listaMusculos = musculos.toList()..sort();
      _listaNiveles = niveles.toList()..sort();
      _listaEquipos = equipos.toList()..sort();

      // Forzamos "Todos" al principio
      _listaMusculos.remove("Todos"); _listaMusculos.insert(0, "Todos");
      _listaNiveles.remove("Todos"); _listaNiveles.insert(0, "Todos");
      _listaEquipos.remove("Todos"); _listaEquipos.insert(0, "Todos");

      _cargando = false;
    });
  }

  // 👇 NUEVA FUNCIÓN PARA FORZAR LA DESCARGA DE JAVA AL DESLIZAR
  Future<void> _sincronizarYRecargar() async {
    await ExerciseService.syncExercisesWithServer();
    await _cargarEjerciciosDesdeCache();
  }

  void _filtrarEjercicios() {
    setState(() {
      _ejerciciosFiltrados = _todosLosEjercicios.where((ej) {
        bool matchTexto = (ej["nombre"] ?? "").toLowerCase().contains(_busquedaActual.toLowerCase());
        bool matchMusculo = _filtroMusculo == "Todos" || ej["grupoMuscular"] == _filtroMusculo;
        bool matchNivel = _filtroNivel == "Todos" || ej["nivel"] == _filtroNivel;
        bool matchEquipo = _filtroEquipo == "Todos" || ej["equipamiento"] == _filtroEquipo;

        return matchTexto && matchMusculo && matchNivel && matchEquipo;
      }).toList();
    });
  }

  // --- MODAL DE FILTROS AVANZADOS ---
  void _abrirPanelFiltros() {
    showModalBottomSheet(
        context: context,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (BuildContext context) {
          return StatefulBuilder(
              builder: (context, setModalState) {
                return Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Filtros Avanzados", style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),

                      _buildDropdown("Músculo Principal", _filtroMusculo, _listaMusculos, (val) {
                        setModalState(() => _filtroMusculo = val!);
                        _filtrarEjercicios();
                      }),
                      const SizedBox(height: 15),

                      _buildDropdown("Nivel", _filtroNivel, _listaNiveles, (val) {
                        setModalState(() => _filtroNivel = val!);
                        _filtrarEjercicios();
                      }),
                      const SizedBox(height: 15),

                      _buildDropdown("Equipamiento", _filtroEquipo, _listaEquipos, (val) {
                        setModalState(() => _filtroEquipo = val!);
                        _filtrarEjercicios();
                      }),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                          onPressed: () => Navigator.pop(context),
                          child: const Text("APLICAR FILTROS", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        ),
                      )
                    ],
                  ),
                );
              }
          );
        }
    );
  }

  Widget _buildDropdown(String titulo, String valorActual, List<String> opciones, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(10)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              dropdownColor: Theme.of(context).colorScheme.surface,
              value: valorActual,
              icon: Icon(Icons.arrow_drop_down, color: Theme.of(context).primaryColor),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              onChanged: onChanged,
              items: opciones.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(value: value, child: Text(value));
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Catálogo", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
      ),
      body: Column(
        children: [
          // BARRA DE BÚSQUEDA + BOTÓN DE FILTROS
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    style: TextStyle(color: Theme.of(context).primaryColor),
                    decoration: InputDecoration(
                      labelText: 'Buscar ejercicio',
                      hintText: "Buscar...",
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: Icon(Icons.search, color: Theme.of(context).primaryColor),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (texto) {
                      _busquedaActual = texto;
                      _filtrarEjercicios();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Semantics(
                  label: 'Filtrar ejercicios',
                  button: true,
                  child: GestureDetector(
                    onTap: _abrirPanelFiltros,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Theme.of(context).primaryColor.withValues(alpha:0.2), borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.tune, color: Theme.of(context).primaryColor),
                    ),
                  ),
                )
              ],
            ),
          ),

          // LISTA DE EJERCICIOS
          Expanded(
            child: _cargando
                ? Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))
                : _ejerciciosFiltrados.isEmpty
                ? const Center(child: Text("No hay coincidencias.", style: TextStyle(color: Colors.grey)))
                // 👇 AÑADIMOS EL REFRESH INDICATOR AQUÍ 👇
                : RefreshIndicator(
                    color: Theme.of(context).primaryColor,
                    onRefresh: _sincronizarYRecargar,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _ejerciciosFiltrados.length,
                      itemBuilder: (context, index) {
                        final ejercicio = _ejerciciosFiltrados[index];
                bool tieneFoto = ejercicio["urlMedia"] != null && ejercicio["urlMedia"].toString().isNotEmpty;

                return InkWell(
                  // AL PULSAR LA FILA -> VAMOS A LOS DETALLES
                  onTap: () async {
                    // Abrimos los detalles y le decimos que SÍ muestre el botón (modoSeleccion: true)
                    // Además, "await" espera a ver qué responde esa pantalla al cerrarse
                    final ejercicioSeleccionado = await Navigator.push(
                    context,
                    MaterialPageRoute(
                    builder: (context) => EjercicioDetalleScreen(ejercicio: ejercicio, modoSeleccion: true),
                    )
                    );

                    // Si la pantalla de detalles nos devuelve el ejercicio (porque pulsó el botón)...
                    if (ejercicioSeleccionado != null) {
                    // ...entonces cerramos también el buscador y devolvemos el ejercicio a la rutina
                      if (!mounted) return;
                    Navigator.pop(context, ejercicioSeleccionado);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white12))),
                    child: Row(
                      children: [
                        // IMAGEN
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: tieneFoto
                              ? Image.network(ejercicio["urlMedia"], width: 70, height: 70, fit: BoxFit.cover, semanticLabel: ejercicio["nombre"], errorBuilder: (c,e,s) => _placeholder())
                              : _placeholder(),
                        ),
                        const SizedBox(width: 15),
                        // TEXTOS
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ejercicio["nombre"] ?? "N/A", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 5),
                              Text("${ejercicio["grupoMuscular"] ?? ''} • ${ejercicio["equipamiento"] ?? ''}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                        // BOTÓN DE AÑADIR (Solo este botón añade)
                        IconButton(
                          tooltip: 'Añadir ejercicio a la rutina',
                          icon: Icon(Icons.add_circle, color: Theme.of(context).primaryColor, size: 30),
                          onPressed: () {
                            Navigator.pop(context, ejercicio); // Escupe el ejercicio a la rutina
                          },
                        )
                      ],
                    ),
                  ),
                );
              },
                    ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(width: 70, height: 70, color: Colors.white10, child: const Icon(Icons.fitness_center, color: Colors.grey));
  }
}
