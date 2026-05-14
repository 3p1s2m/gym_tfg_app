import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_constants.dart';
import 'coach_client_detail.dart';

class CoachDashboard extends StatefulWidget {
  const CoachDashboard({super.key});

  @override
  State<CoachDashboard> createState() => _CoachDashboardState();
}

class _CoachDashboardState extends State<CoachDashboard> {
  List<dynamic> _todosLosClientes = [];
  List<dynamic> _clientesFiltrados = [];
  bool _cargando = true;
  String _busquedaActual = "";

  @override
  void initState() {
    super.initState();
    _cargarMisClientes();
  }

  Future<void> _cargarMisClientes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return;

      final url = Uri.parse("${ApiConstants.baseUrl}/usuarios/mis-clientes");
      final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _todosLosClientes = data;
            _clientesFiltrados = data;
            _cargando = false;
          });
        }
      } else {
        if (mounted) setState(() => _cargando = false);
      }
    } catch (e) {
      print("Error cargando clientes: $e");
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _filtrarClientes(String texto) {
    setState(() {
      _busquedaActual = texto;
      _clientesFiltrados = _todosLosClientes.where((cliente) {
        String nombre = (cliente["nombre"] ?? "").toLowerCase();
        String email = (cliente["email"] ?? "").toLowerCase();
        return nombre.contains(texto.toLowerCase()) || email.contains(texto.toLowerCase());
      }).toList();
    });
  }
  Widget _buildSemaforoEstado(int diasInactivo) {
    Color color;
    String texto;

    // LÓGICA DE RANGOS QUE DISEÑASTE
    if (diasInactivo < 0) {
      color = Colors.grey;
      texto = "Sin registros";
    } else if (diasInactivo <= 1) {
      color = Colors.greenAccent;
      texto = "Activo";
    } else if (diasInactivo <= 3) {
      color = Colors.yellowAccent;
      texto = "Aviso ($diasInactivo días)";
    } else if (diasInactivo <= 6) {
      color = Colors.orangeAccent;
      texto = "Alerta ($diasInactivo días)";
    } else if (diasInactivo <= 14) {
      color = Colors.redAccent;
      texto = "Peligro ($diasInactivo días)";
    } else {
      color = Colors.black; // O un gris muy oscuro si el fondo de tu app es negro puro
      texto = "Abandono (+14 días)";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color == Colors.black ? Colors.white10 : color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color == Colors.black ? Colors.grey : color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color == Colors.black ? Colors.grey : color,
                  boxShadow: color == Colors.black ? [] : [BoxShadow(color: color, blurRadius: 4)] // Efecto LED brillante
              )
          ),
          const SizedBox(width: 6),
          Text(
              texto,
              style: TextStyle(
                  color: color == Colors.black ? Colors.grey : color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold
              )
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // BARRA DE BÚSQUEDA
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: TextField(
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: "Buscar atleta...",
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: Icon(Icons.search, color: Theme.of(context).primaryColor),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
              onChanged: _filtrarClientes,
            ),
          ),

          // RESUMEN RÁPIDO
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              children: [
                Text("Mis Atletas (${_clientesFiltrados.length})", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // LISTA DE CLIENTES
          Expanded(
            child: _cargando
                ? Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))
                : _clientesFiltrados.isEmpty
                ? const Center(child: Text("No se encontraron atletas.", style: TextStyle(color: Colors.grey)))
                // 👇 AÑADIMOS EL REFRESH INDICATOR AQUÍ 👇
                : RefreshIndicator(
                    color: Theme.of(context).primaryColor,
                    onRefresh: _cargarMisClientes, // Llama a la base de datos al deslizar
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(), // Obliga a que siempre se pueda deslizar
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _clientesFiltrados.length,
                      itemBuilder: (context, index) {
                        final cliente = _clientesFiltrados[index];

                // Extraemos datos clave
                String nombre = cliente["nombre"] ?? "Sin Nombre";
                int racha = cliente["rachaActualDias"] ?? 0;
                bool alDia = cliente["estadoPago"] == "AL_DIA";

                return Card(
                  color: Theme.of(context).colorScheme.surface,
                  margin: const EdgeInsets.only(bottom: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.white12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(15),
                    leading: Stack(
                      children: [
                        const CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.white10,
                          child: Icon(Icons.person, color: Colors.grey, size: 30),
                        ),
                        Positioned(
                          bottom: 0, right: 0,
                          child: Container(
                            width: 14, height: 14,
                            decoration: BoxDecoration(
                                color: alDia ? Colors.greenAccent : Colors.redAccent,
                                shape: BoxShape.circle,
                                border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2)
                            ),
                          ),
                        )
                      ],
                    ),
                    title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 5.0),
                      child: Row(
                        children: [
                          const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 14),
                          const SizedBox(width: 4),
                          Text("$racha puntos", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                    ),
                    trailing: _buildSemaforoEstado(cliente["diasInactivo"] ?? -1),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => CoachClientDetail(cliente: cliente)),
                      );
                    },
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