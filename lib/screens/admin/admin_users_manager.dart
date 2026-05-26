import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_constants.dart';

class AdminUsersManager extends StatefulWidget {
  const AdminUsersManager({super.key});

  @override
  State<AdminUsersManager> createState() => _AdminUsersManagerState();
}

class _AdminUsersManagerState extends State<AdminUsersManager> {
  List<Map<String, dynamic>> _usuarios = [];
  List<Map<String, dynamic>> _usuariosFiltrados = [];
  bool _cargando = true;
  String _filtroRol = 'Todos';
  String _busquedaActual = '';

  @override
  void initState() { super.initState(); _cargarUsuarios(); }

  Future<void> _cargarUsuarios() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final res = await http.get(Uri.parse(ApiConstants.adminUsuarios), headers: {'Authorization': 'Bearer ${prefs.getString('jwt_token')}'});
      if (res.statusCode == 200 && mounted) {
        setState(() { _usuarios = List<Map<String, dynamic>>.from(jsonDecode(utf8.decode(res.bodyBytes))); _aplicarFiltros(); _cargando = false; });
      }
    } catch (e) { if (mounted) setState(() => _cargando = false); }
  }

  void _aplicarFiltros() {
    setState(() {
      _usuariosFiltrados = _usuarios.where((u) {
        bool matchRol = _filtroRol == 'Todos' || u['rol'] == _filtroRol.toUpperCase();
        bool matchBusqueda = u['nombre'].toString().toLowerCase().contains(_busquedaActual) || u['email'].toString().toLowerCase().contains(_busquedaActual);
        return matchRol && matchBusqueda;
      }).toList();
    });
  }

  Future<void> _eliminarUsuario(int idUsuario) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(backgroundColor: Theme.of(context).colorScheme.surface, title: const Text('¿Eliminar usuario?'), content: const Text('Esta acción borrará todo su historial y es irreversible.', style: TextStyle(color: Colors.grey)), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí, eliminar', style: TextStyle(color: Colors.red)))]),
    );

    if (confirmar == true) {
      setState(() => _cargando = true);
      final prefs = await SharedPreferences.getInstance();
      final res = await http.delete(Uri.parse(ApiConstants.adminEliminarUsuario(idUsuario)), headers: {'Authorization': 'Bearer ${prefs.getString('jwt_token')}'});
      if (res.statusCode == 200) { _cargarUsuarios(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Eliminado'), backgroundColor: Colors.green)); }
      else { setState(() => _cargando = false); if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Error'), backgroundColor: Colors.red)); }
    }
  }

  // 👇 NUEVO MÉTODO PARA CAMBIAR CONTRASEÑA DESDE EL ADMIN
  void _cambiarPasswordAdmin(Map<String, dynamic> usuario) {
    TextEditingController passCtrl = TextEditingController();

    showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text("Nueva contraseña para ${usuario['nombre']}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: TextField(
                autofocus: true,
                controller: passCtrl,
                decoration: InputDecoration(
                    labelText: "Nueva contraseña",
                    hintText: "Escribe la nueva clave",
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)
                )
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.black),
                onPressed: () async {
                  if (passCtrl.text.isEmpty) return;
                  Navigator.pop(context); // Cierra el modal

                  final prefs = await SharedPreferences.getInstance();
                  final token = prefs.getString('jwt_token');

                  // Como la lógica de Java ya existe para el Staff y hace exactamente lo mismo (cambiar pwd),
                  // el Admin puede usar esa misma ruta, ya que su token (al ser ADMIN) le da permisos universales
                  final url = Uri.parse(ApiConstants.staffCambiarPassword(usuario['idUsuario']));

                  final resp = await http.put(
                      url,
                      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
                      body: jsonEncode({"nuevaPassword": passCtrl.text})
                  );

                  if(resp.statusCode == 200 && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Contraseña actualizada'), backgroundColor: Colors.green));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Error al actualizar'), backgroundColor: Colors.redAccent));
                  }
                },
                child: const Text("Cambiar")
            )
          ],
        )
    );
  }

  // 👇 NUEVO MENÚ INFERIOR AL TOCAR UN USUARIO
  void _mostrarOpcionesUsuario(Map<String, dynamic> usuario) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(usuario['nombre'], style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 18, fontWeight: FontWeight.bold)),
            Text(usuario['email'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 20),

            ListTile(
              leading: const Icon(Icons.lock_reset, color: Colors.orangeAccent),
              title: const Text('Restablecer Contraseña'),
              onTap: () {
                Navigator.pop(context);
                _cambiarPasswordAdmin(usuario);
              },
            ),

            const Divider(color: Colors.white12),

            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
              title: const Text('Eliminar Usuario', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                _eliminarUsuario(usuario['idUsuario']);
              },
            ),
          ],
        ),
        ),
      ),
    );
  }

  void _abrirCrearUsuario() {
    TextEditingController nombreCtrl = TextEditingController();
    TextEditingController emailCtrl = TextEditingController();
    TextEditingController passCtrl = TextEditingController();
    TextEditingController pesoCtrl = TextEditingController();
    TextEditingController alturaCtrl = TextEditingController();
    String rolSeleccionado = 'CLIENTE';
    String generoSeleccionado = 'HOMBRE';
    DateTime? fechaNac;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
          builder: (context, setModalState) {
            bool esCliente = rolSeleccionado == 'CLIENTE';

            return FocusTraversalGroup(
              policy: ReadingOrderTraversalPolicy(),
              child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dar de Alta a Usuario', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),

                    // DATOS BÁSICOS
                    TextField(controller: nombreCtrl, decoration: InputDecoration(labelText: 'Nombre completo', hintText: 'Nombre completo', filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
                    const SizedBox(height: 10),
                    TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'Email', hintText: 'Email', filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
                    const SizedBox(height: 10),
                    TextField(controller: passCtrl, obscureText: true, decoration: InputDecoration(labelText: 'Contraseña inicial', hintText: 'Contraseña inicial', filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: rolSeleccionado, dropdownColor: Theme.of(context).colorScheme.surface, decoration: InputDecoration(labelText: 'Rol del usuario', filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
                      items: ['CLIENTE', 'ENTRENADOR', 'STAFF', 'ADMIN'].map((role) => DropdownMenuItem(value: role, child: Text(role))).toList(),
                      onChanged: (value) => setModalState(() => rolSeleccionado = value!),
                    ),

                    // DATOS ESPECÍFICOS DE CLIENTE
                    if (esCliente) ...[
                      const Divider(color: Colors.white24, height: 30),
                      const Text("Ficha Física Obligatoria", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: pesoCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Peso (kg)', hintText: 'Peso (kg)', filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)))),
                          const SizedBox(width: 10),
                          Expanded(child: TextField(controller: alturaCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Altura (cm)', hintText: 'Altura (cm)', filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: DropdownButtonFormField<String>(
                            value: generoSeleccionado, dropdownColor: Theme.of(context).colorScheme.surface, decoration: InputDecoration(filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
                            items: ['HOMBRE', 'MUJER', 'OTRO'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                            onChanged: (value) => setModalState(() => generoSeleccionado = value!),
                          )),
                          const SizedBox(width: 10),
                          Expanded(child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 16), label: Text(fechaNac == null ? "Nacimiento" : "${fechaNac!.day}/${fechaNac!.month}/${fechaNac!.year}", style: const TextStyle(fontSize: 12)),
                            onPressed: () async {
                              DateTime? date = await showDatePicker(context: context, initialDate: DateTime(2000), firstDate: DateTime(1900), lastDate: DateTime.now());
                              if (date != null) setModalState(() => fechaNac = date);
                            },
                          )),
                        ],
                      ),
                    ],

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity, height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                        onPressed: () async {
                          if (nombreCtrl.text.isEmpty || emailCtrl.text.isEmpty || passCtrl.text.isEmpty) return;
                          if (esCliente && (pesoCtrl.text.isEmpty || alturaCtrl.text.isEmpty || fechaNac == null)) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rellena la ficha física'))); return;
                          }

                          Navigator.pop(context); setState(() => _cargando = true);

                          Map<String, dynamic> bodyJson = {"nombre": nombreCtrl.text, "email": emailCtrl.text, "password": passCtrl.text, "rol": rolSeleccionado};
                          if (esCliente) {
                            bodyJson["peso"] = double.tryParse(pesoCtrl.text) ?? 0;
                            bodyJson["altura"] = double.tryParse(alturaCtrl.text) ?? 0;
                            bodyJson["genero"] = generoSeleccionado;
                            bodyJson["fechaNacimiento"] = "${fechaNac!.year}-${fechaNac!.month.toString().padLeft(2,'0')}-${fechaNac!.day.toString().padLeft(2,'0')}";
                          }

                          final prefs = await SharedPreferences.getInstance();
                          final res = await http.post(Uri.parse(ApiConstants.adminUsuarios), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${prefs.getString('jwt_token')}'}, body: jsonEncode(bodyJson));

                          if (res.statusCode == 200) { _cargarUsuarios(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Usuario creado'), backgroundColor: Colors.green)); }
                          else { setState(() => _cargando = false); if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: ${res.body}'), backgroundColor: Colors.red)); }
                        },
                        child: const Text('Crear Cuenta', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              ),
            );
          }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('DIRECTORIO', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2.0)), backgroundColor: Theme.of(context).appBarTheme.backgroundColor, foregroundColor: Theme.of(context).appBarTheme.foregroundColor, centerTitle: true, elevation: 0),
      floatingActionButton: FloatingActionButton(tooltip: 'Crear nuevo usuario', backgroundColor: Theme.of(context).primaryColor, onPressed: _abrirCrearUsuario, child: const Icon(Icons.person_add, color: Colors.black)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Expanded(flex: 6, child: TextField(decoration: InputDecoration(labelText: 'Buscar usuario', hintText: "Buscar...", prefixIcon: const Icon(Icons.search), filled: true, fillColor: Theme.of(context).colorScheme.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 0)), onChanged: (val) { _busquedaActual = val.toLowerCase(); _aplicarFiltros(); })),
                const SizedBox(width: 10),
                Expanded(flex: 4, child: DropdownButtonFormField<String>(value: _filtroRol, dropdownColor: Theme.of(context).colorScheme.surface, decoration: InputDecoration(filled: true, fillColor: Theme.of(context).colorScheme.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12)), items: ['Todos', 'Cliente', 'Entrenador', 'Staff', 'Admin'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(), onChanged: (v) { _filtroRol = v!; _aplicarFiltros(); })),
              ],
            ),
          ),
          Expanded(
            child: _cargando ? Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor)) : _usuariosFiltrados.isEmpty ? const Center(child: Text("No hay resultados", style: TextStyle(color: Colors.grey))) : RefreshIndicator(
              color: Theme.of(context).primaryColor, onRefresh: _cargarUsuarios,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 15), itemCount: _usuariosFiltrados.length,
                itemBuilder: (context, index) {
                  final u = _usuariosFiltrados[index];
                  String rolStr = u['rol']; bool esMoroso = u['estadoPago'] == 'IMPAGADO';
                  Color cRol = rolStr == 'ADMIN' ? Colors.redAccent : (rolStr == 'STAFF' ? Colors.orangeAccent : (rolStr == 'ENTRENADOR' ? Colors.purpleAccent : Theme.of(context).primaryColor));

                  return Card(
                    color: Theme.of(context).colorScheme.surface, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.white12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                      leading: CircleAvatar(backgroundColor: cRol.withValues(alpha: 0.2), child: Icon(Icons.person, color: cRol)),
                      title: Text(u['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(u['email'], style: const TextStyle(fontSize: 12, color: Colors.grey)), const SizedBox(height: 5), Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: cRol.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)), child: Text(rolStr, style: TextStyle(color: cRol, fontSize: 10, fontWeight: FontWeight.bold))), const SizedBox(width: 8), if (rolStr == 'CLIENTE') Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: esMoroso ? Colors.red.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)), child: Text(esMoroso ? 'IMPAGADO' : 'AL DÍA', style: TextStyle(color: esMoroso ? Colors.redAccent : Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)))])]),

                      // 👇 AHORA TOCA AQUÍ PARA ABRIR LAS OPCIONES
                      trailing: Semantics(label: 'Opciones del usuario', button: true, child: const Icon(Icons.more_vert, color: Colors.grey)),
                      onTap: () => _mostrarOpcionesUsuario(u),
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
}