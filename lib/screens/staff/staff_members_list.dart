import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:gym_tfg_app/services/api_constants.dart';

class StaffMembersList extends StatefulWidget {
  const StaffMembersList({super.key});

  @override
  State<StaffMembersList> createState() => _StaffMembersListState();
}

class _StaffMembersListState extends State<StaffMembersList> {
  late TextEditingController _searchController;
  List<Map<String, dynamic>> _miembros = [];
  List<Map<String, dynamic>> _miembrosFiltrados = [];
  bool _cargando = true;
  String? _token;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_filtrarMiembros);
    _obtenerTokenYCargarSocios();
  }
  Future<void> _abrirModalAsignarCoach(Map<String, dynamic> miembro) async {
    // 1. Descargamos la lista de entrenadores
    final prefs = await SharedPreferences.getInstance();
    final response = await http.get(Uri.parse("${ApiConstants.baseUrl}/usuarios/entrenadores"), headers: {'Authorization': 'Bearer $_token'});
    if (response.statusCode != 200) return;
    List<dynamic> coaches = jsonDecode(utf8.decode(response.bodyBytes));

    // 2. Mostramos el Modal
    if (!mounted) return;
    showModalBottomSheet(
      context: context, backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Asignar Entrenador a ${miembro['nombre']}", style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            ...coaches.map((c) => MergeSemantics(
              child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.sports)),
              title: Text(c["nombre"]),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(miembro['email'] ?? 'N/A', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
                  const SizedBox(height: 4),
                  Text('Coach: ${miembro['nombreEntrenador'] ?? "Sin asignar"}', style: TextStyle(fontSize: 11, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)), // 👈 EL NOMBRE DEL COACH
                  if ((miembro['diasInactivo'] as num?)!.toInt() >= 0)
                    Text('Inactivo hace ${miembro['diasInactivo']} días', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
                ],
              ),
              // 👇 AÑADIMOS EL BOTÓN DE ASIGNAR COACH
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.sports, color: Colors.grey),
                    tooltip: "Asignar Entrenador",
                    onPressed: () => _abrirModalAsignarCoach(miembro),
                  ),
                  miembro['nombreEntrenador'] == c['nombre']
                      ? ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)), onPressed: () => _actualizarEstadoPago(miembro, 'AL_DIA'), child: Text('Pagar', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 11, fontWeight: FontWeight.bold)))
                      : OutlinedButton(style: OutlinedButton.styleFrom(side: BorderSide(color: Theme.of(context).colorScheme.primary), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)), onPressed: () => _actualizarEstadoPago(miembro, 'IMPAGADO'), child: Text('Al día', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 11, fontWeight: FontWeight.bold))),
                ],
              ),
              onTap: () async {
                Navigator.pop(context); // Cierra modal
                // 3. Enviamos a Java la petición de asignar
                final url = Uri.parse(ApiConstants.staffAsignarCoach(miembro['idUsuario'], c['idUsuario']));
                final res = await http.put(url, headers: {'Authorization': 'Bearer $_token'});
                if (res.statusCode == 200) {
                  _cargarSocios(); // Recargamos para ver el nombre actualizado
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Entrenador asignado'), backgroundColor: Colors.green));
                }
              },
            )))
          ],
        ),
      ),
    );
  }

  /// 1️⃣ Obtiene el token JWT y carga la lista de socios
  Future<void> _obtenerTokenYCargarSocios() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('jwt_token');

      if (_token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Error: No hay sesión iniciada'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        setState(() => _cargando = false);
        return;
      }

      await _cargarSocios();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      setState(() => _cargando = false);
    }
  }

  /// 2️⃣ Carga la lista de socios desde el backend
  Future<void> _cargarSocios() async {
    if (_token == null) return;

    try {
      setState(() => _cargando = true);

      final url = Uri.parse('${ApiConstants.baseUrl}/usuarios/staff/clientes');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _miembros = List<Map<String, dynamic>>.from(
            data.map((item) => Map<String, dynamic>.from(item as Map)),
          );
          _miembrosFiltrados = List.from(_miembros);
          _cargando = false;
        });
      } else if (response.statusCode == 401) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Sesión expirada. Inicia sesión nuevamente.'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        setState(() => _cargando = false);
      } else {
        throw Exception('Error al cargar socios: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de conexión: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      setState(() => _cargando = false);
    }
  }

  /// 3️⃣ Filtra la lista en tiempo real por nombre o email
  void _filtrarMiembros() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      if (query.isEmpty) {
        _miembrosFiltrados = List.from(_miembros);
      } else {
        _miembrosFiltrados = _miembros
            .where((miembro) =>
                (miembro['nombre']?.toString() ?? '').toLowerCase().contains(query) ||
                (miembro['email']?.toString() ?? '').toLowerCase().contains(query))
            .toList();
      }
    });
  }

  /// 4️⃣ Actualiza el estado de pago en el backend
  Future<void> _actualizarEstadoPago(
    Map<String, dynamic> miembro,
    String nuevoEstado,
  ) async {
    if (_token == null) return;

    try {
      final idUsuario = miembro['idUsuario'];
      final url = Uri.parse(
        '${ApiConstants.baseUrl}/usuarios/staff/clientes/$idUsuario/estado-pago',
      );

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'estadoPago': nuevoEstado,
        }),
      );

      if (response.statusCode == 200) {
        // ✅ Actualizar en la lista local
        setState(() {
          final index = _miembros.indexWhere(
            (m) => m['idUsuario'] == idUsuario,
          );
          if (index != -1) {
            _miembros[index]['estadoPago'] = nuevoEstado;
            _filtrarMiembros(); // Refrescar filtrados
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Estado actualizado a ${nuevoEstado == 'AL_DIA' ? 'Al día' : 'Impagado'}',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else if (response.statusCode == 401) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Sesión expirada'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      } else {
        throw Exception('Error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// 5️⃣ Obtiene el color basado en el estado de pago
  Color _getEstadoColor(String estado) {
    if (estado == 'IMPAGADO') {
      return Theme.of(context).colorScheme.error.withValues(alpha: 0.2);
    }
    return Theme.of(context).colorScheme.primary.withValues(alpha: 0.1);
  }

  /// 6️⃣ Obtiene el icono basado en el estado de pago
  IconData _getEstadoIcon(String estado) {
    return estado == 'IMPAGADO' ? Icons.warning : Icons.check_circle;
  }

  void _mostrarOpcionesSocio(Map<String, dynamic> miembro) {
    showModalBottomSheet(
      context: context, backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Opciones: ${miembro['nombre']}", style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            ListTile(
              leading: Icon(miembro['estadoPago'] == 'IMPAGADO' ? Icons.check_circle : Icons.cancel, color: miembro['estadoPago'] == 'IMPAGADO' ? Colors.green : Colors.red),
              title: Text(miembro['estadoPago'] == 'IMPAGADO' ? 'Marcar como Pagado' : 'Marcar como Impago'),
              onTap: () { Navigator.pop(context); _actualizarEstadoPago(miembro, miembro['estadoPago'] == 'IMPAGADO' ? 'AL_DIA' : 'IMPAGADO'); },
            ),
            const Divider(color: Colors.white12),
            ListTile(
              leading: const Icon(Icons.sports, color: Colors.blueAccent),
              title: const Text('Asignar Entrenador'),
              subtitle: Text("Actual: ${miembro['nombreEntrenador'] ?? 'Ninguno'}", style: const TextStyle(fontSize: 10)),
              onTap: () async {
                Navigator.pop(context);
                // 1. Pedir coaches a BD
                final prefs = await SharedPreferences.getInstance();
                final res = await http.get(Uri.parse("${ApiConstants.baseUrl}/usuarios/entrenadores"), headers: {'Authorization': 'Bearer $_token'});
                if (res.statusCode != 200) return;
                List<dynamic> coaches = jsonDecode(utf8.decode(res.bodyBytes));
                if(!mounted) return;
                // 2. Mostrar lista de coaches
                showDialog(context: context, builder: (context) => AlertDialog(
                  backgroundColor: Theme.of(context).colorScheme.surface, title: const Text("Elegir Coach"),
                  content: FocusTraversalGroup(
                    policy: ReadingOrderTraversalPolicy(),
                    child: SizedBox(width: double.maxFinite, child: ListView.builder(
                    shrinkWrap: true, itemCount: coaches.length,
                    itemBuilder: (c, i) => ListTile(title: Text(coaches[i]["nombre"]), onTap: () async {
                      Navigator.pop(context);
                      final url = Uri.parse(ApiConstants.staffAsignarCoach(miembro['idUsuario'], coaches[i]['idUsuario']));
                      final resp = await http.put(url, headers: {'Authorization': 'Bearer $_token'});
                      if(resp.statusCode == 200) { _cargarSocios(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Entrenador asignado'))); }
                    }),
                  ))),
                ));
              },
            ),
            const Divider(color: Colors.white12),
            ListTile(
              leading: const Icon(Icons.lock_reset, color: Colors.orange),
              title: const Text('Cambiar Contraseña'),
              onTap: () {
                Navigator.pop(context);
                TextEditingController passCtrl = TextEditingController();
                showDialog(context: context, builder: (context) => AlertDialog(
                  backgroundColor: Theme.of(context).colorScheme.surface, title: Text("Nueva contraseña para ${miembro['nombre']}", style: const TextStyle(fontSize: 14)),
                  content: FocusTraversalGroup(
                    policy: ReadingOrderTraversalPolicy(),
                    child: TextField(autofocus: true, controller: passCtrl, decoration: const InputDecoration(labelText: "Nueva contraseña", hintText: "Ej: 123456")),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
                    ElevatedButton(onPressed: () async {
                      Navigator.pop(context);
                      final url = Uri.parse(ApiConstants.staffCambiarPassword(miembro['idUsuario']));
                      final resp = await http.put(url, headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'}, body: jsonEncode({"nuevaPassword": passCtrl.text}));
                      if(resp.statusCode == 200 && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Contraseña cambiada'), backgroundColor: Colors.green));
                    }, child: const Text("Cambiar"))
                  ],
                ));
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'GESTIÓN DE SOCIOS',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2.0),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 🔍 Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(15),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar socio por nombre o email...',
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Theme.of(context).colorScheme.primary,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        tooltip: 'Borrar búsqueda',
                        icon: Icon(
                          Icons.clear,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _filtrarMiembros();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
            ),
          ),
          // 📋 Lista de socios
          Expanded(
            child: _cargando
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  )
                : _miembrosFiltrados.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 60,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'No hay socios registrados'
                                  : 'No se encontraron resultados',
                              style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _cargarSocios,
                        color: Theme.of(context).colorScheme.primary,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          itemCount: _miembrosFiltrados.length,
                          itemBuilder: (context, index) {
                            final miembro = _miembrosFiltrados[index];
                            final estadoPago =
                                miembro['estadoPago'] as String? ?? 'AL_DIA';
                            final esImpagado = estadoPago == 'IMPAGADO';
                            final diasInactivo =
                                (miembro['diasInactivo'] as num?)?.toInt() ?? -1;

                            return Card(
                              color: Theme.of(context).colorScheme.surface,
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _getEstadoColor(estadoPago),
                                  child: Icon(
                                    _getEstadoIcon(estadoPago),
                                    color: esImpagado
                                        ? Theme.of(context).colorScheme.error
                                        : Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                title: Text(
                                  miembro['nombre'] as String? ?? 'N/A',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      miembro['email'] as String? ?? 'N/A',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.7),
                                      ),
                                    ),
                                    if (diasInactivo >= 0)
                                      Text(
                                        'Inactivo hace $diasInactivo días',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: Semantics(label: 'Ver opciones del miembro', button: true, child: const Icon(Icons.more_vert)),
                                onTap: () => _mostrarOpcionesSocio(miembro),
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

