import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../services/api_constants.dart';
import '../client/routines/active_workout_screen.dart';
import '../client/evolution/tab_frecuencia.dart';

// 👇 IMPORTAMOS LAS PESTAÑAS ORIGINALES DEL CLIENTE
import '../client/evolution/tab_avatar.dart';
import '../client/evolution/tab_historial.dart';
import '../client/evolution/tab_logros.dart';

class CoachClientDetail extends StatefulWidget {
  final Map<String, dynamic> cliente;
  const CoachClientDetail({super.key, required this.cliente});

  @override
  State<CoachClientDetail> createState() => _CoachClientDetailState();
}

class _CoachClientDetailState extends State<CoachClientDetail> {
  bool _cargando = true;
  List<dynamic> _rutinasCliente = [];
  List<dynamic> _misRutinasCoach = []; // La biblioteca del entrenador

  int? _miIdCoach;
  WebSocketChannel? _canalChat;
  final TextEditingController _chatController = TextEditingController();
  List<Map<String, dynamic>> _mensajesChat = [];

  @override
  void initState() {
    super.initState();
    _cargarDatosYChat();
  }

  @override
  void dispose() {
    _canalChat?.sink.close();
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosYChat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final idString = prefs.getString('user_id');
      if (token == null || idString == null) return;

      _miIdCoach = int.parse(idString);
      int idCliente = widget.cliente["idUsuario"];

      // 1. DESCARGAMOS LAS RUTINAS
      final resRutinasC = await http.get(Uri.parse("${ApiConstants.baseUrl}/coach/cliente/$idCliente/rutinas"), headers: {'Authorization': 'Bearer $token'});
      final resBiblioteca = await http.get(Uri.parse(ApiConstants.rutinas), headers: {'Authorization': 'Bearer $token'}); // Mis plantillas de coach

      if (resRutinasC.statusCode == 200 && resBiblioteca.statusCode == 200) {
        setState(() {
          _rutinasCliente = jsonDecode(utf8.decode(resRutinasC.bodyBytes));
          _misRutinasCoach = jsonDecode(utf8.decode(resBiblioteca.bodyBytes));
        });
      }

      // 2. DESCARGAMOS HISTORIAL DE CHAT
      final resChat = await http.get(Uri.parse(ApiConstants.historialChat(idCliente)), headers: {'Authorization': 'Bearer $token'});
      if (resChat.statusCode == 200) {
        List<dynamic> historial = jsonDecode(utf8.decode(resChat.bodyBytes));
        setState(() => _mensajesChat = historial.map((msg) => {"texto": msg["contenido"], "soyYo": msg["emisor"]["idUsuario"] == _miIdCoach}).toList());
      }

      // 3. CONECTAMOS WEBSOCKET EN VIVO
      _canalChat = WebSocketChannel.connect(Uri.parse(ApiConstants.wsChat(_miIdCoach!)));
      _canalChat!.stream.listen((mensajeJson) {
        final data = jsonDecode(mensajeJson);
        if (data["emisorId"] == idCliente) {
          if (mounted) setState(() => _mensajesChat.add({"texto": data["contenido"], "soyYo": false}));
        }
      });

    } catch (e) {
      print("Error cargando ficha: $e");
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _asignarRutinaBD(int idRutina) async {
    Navigator.pop(context); // Cierra el modal
    setState(() => _cargando = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final url = Uri.parse("${ApiConstants.baseUrl}/coach/cliente/${widget.cliente["idUsuario"]}/asignar-rutina/$idRutina");
    final response = await http.post(url, headers: {'Authorization': 'Bearer $token'});

    if (response.statusCode == 200) {
      await _cargarDatosYChat();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Rutina asignada correctamente'), backgroundColor: Colors.green));
    }
  }
  Future<void> _importarRutina(int idRutina) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final url = Uri.parse("${ApiConstants.baseUrl}/coach/importar-rutina/$idRutina");

    final response = await http.post(url, headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Importada a tu biblioteca'), backgroundColor: Colors.green));
    }
  }

  void _abrirModalAsignarRutina() {
    showModalBottomSheet(
      context: context, backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Tu Biblioteca de Plantillas", style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            if (_misRutinasCoach.isEmpty)
              const Text("No tienes plantillas creadas. Ve a 'Biblioteca' a crearlas.", style: TextStyle(color: Colors.grey))
            else
              ..._misRutinasCoach.where((r) => r["archivada"] == false && r["idClienteAsignado"] == null).map((rutina) => Card(
                color: Colors.white10,
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: Theme.of(context).primaryColor.withValues(alpha:0.2), child: Text(rutina["icono"] ?? "🏋️")),
                  title: Text(rutina["nombre"] ?? "Plantilla"),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                    onPressed: () => _asignarRutinaBD(rutina["idRutina"]),
                    child: const Text("ASIGNAR", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),
              ))
          ],
        ),
      ),
    );
  }

  void _enviarMensaje() {
    if (_chatController.text.trim().isEmpty || _canalChat == null) return;
    String texto = _chatController.text;
    setState(() => _mensajesChat.add({"texto": texto, "soyYo": true}));
    final msg = jsonEncode({"emisorId": _miIdCoach, "receptorId": widget.cliente["idUsuario"], "contenido": texto});
    _canalChat!.sink.add(msg);
    _chatController.clear();
  }

  @override
  Widget build(BuildContext context) {
    String nombre = widget.cliente["nombre"] ?? "Atleta";
    int idCli = widget.cliente["idUsuario"]; // 👈 EL ID DEL CLIENTE

    return DefaultTabController(
      length: 6, // 👈 5 PESTAÑAS
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(nombre.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
          elevation: 0,
          bottom: TabBar(
            isScrollable: true, // 👈 1. ESTO EVITA QUE SE CORTEN LAS PALABRAS
            tabAlignment: TabAlignment.start, // 👈 2. Las alinea a la izquierda de forma bonita
            indicatorColor: Theme.of(context).primaryColor,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            tabs: const [
              Tab(icon: Icon(Icons.accessibility_new), text: "Físico"),
              Tab(icon: Icon(Icons.local_fire_department), text: "Frecuencia"),
              Tab(icon: Icon(Icons.calendar_month), text: "Historial"),
              Tab(icon: Icon(Icons.diamond_outlined), text: "Logros"),
              Tab(icon: Icon(Icons.fitness_center), text: "Rutinas"),
              Tab(icon: Icon(Icons.chat), text: "Chat"),
            ],
          ),
        ),
        body: _cargando
            ? Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))
            : TabBarView(
          children: [
            // 👇 REUTILIZAMOS LOS COMPONENTES MÁGICAMENTE PASÁNDOLE EL ID
            TabAvatar(idCliente: idCli),
            TabFrecuencia(idCliente: idCli), // Asegúrate de pasar la variable correcta del ID del cliente
            TabHistorial(idCliente: idCli),
            TabLogros(idCliente: idCli),
            _buildRutinas(),
            _buildChat(nombre),
          ],
        ),
      ),
    );
  }

// --- PESTAÑA RUTINAS (Ahora se pueden ver e importar con el mismo diseño) ---
  Widget _buildRutinas() {
    return Column(
      children: [
        if (_rutinasCliente.isEmpty)
          const Expanded(child: Center(child: Text("El cliente no tiene rutinas.", style: TextStyle(color: Colors.grey))))
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: _rutinasCliente.length,
              itemBuilder: (context, index) {
                final r = _rutinasCliente[index];
                bool esAsignada = r["esDelEntrenador"] == true;

                return Card(
                  color: Theme.of(context).colorScheme.surface,
                  margin: const EdgeInsets.only(bottom: 10),
                  // 👇 Mismo borde que el cliente
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.white12, width: 1)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    // 👇 Mismo icono con color primario
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Theme.of(context).primaryColor.withValues(alpha:0.1), borderRadius: BorderRadius.circular(12)),
                      child: ColorFiltered(colorFilter: ColorFilter.mode(Theme.of(context).primaryColor, BlendMode.srcIn), child: Text(r["icono"] ?? "🏋️", style: const TextStyle(fontSize: 24))),
                    ),
                    title: Text(r["nombre"] ?? "Rutina", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    subtitle: Text(esAsignada ? "Asignada por ti" : "Creada por el cliente", style: const TextStyle(color: Colors.grey, fontSize: 12)),

                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                      color: Theme.of(context).colorScheme.surface,
                      onSelected: (value) {
                        if (value == 'ver') {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => ActiveWorkoutScreen(plantilla: r)));
                        } else if (value == 'importar') {
                          _importarRutina(r["idRutina"]);
                        }
                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(value: 'ver', child: Row(children: [Icon(Icons.visibility), SizedBox(width: 10), Text('Ver ejercicios')])),
                        const PopupMenuItem<String>(value: 'importar', child: Row(children: [Icon(Icons.copy), SizedBox(width: 10), Text('Importar a mi biblioteca')])),
                      ],
                    ),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ActiveWorkoutScreen(plantilla: r))),
                  ),
                );
              },
            ),
          ),
        Container(
          padding: const EdgeInsets.all(15),
          child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, minimumSize: const Size(double.infinity, 50)),
              onPressed: _abrirModalAsignarRutina,
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text("ASIGNAR NUEVA RUTINA", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))
          ),
        )
      ],
    );
  }
  // --- PESTAÑA CHAT (Datos Reales) ---
  Widget _buildChat(String nombre) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: _mensajesChat.length,
            itemBuilder: (context, index) {
              final msg = _mensajesChat[index];
              return Align(
                alignment: msg["soyYo"] ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(color: msg["soyYo"] ? Theme.of(context).primaryColor.withValues(alpha: 0.2) : Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: msg["soyYo"] ? Theme.of(context).primaryColor.withValues(alpha: 0.5) : Colors.transparent)),
                  constraints: const BoxConstraints(maxWidth: 250),
                  child: Text(msg["texto"], style: const TextStyle(fontSize: 14)),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(color: Theme.of(context).appBarTheme.backgroundColor, border: const Border(top: BorderSide(color: Colors.white12))),
          child: Row(
            children: [
              Expanded(child: TextField(controller: _chatController, decoration: InputDecoration(hintText: "Escribe a $nombre...", hintStyle: const TextStyle(color: Colors.grey), filled: true, fillColor: Theme.of(context).colorScheme.surface, contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none)))),
              const SizedBox(width: 10),
              CircleAvatar(backgroundColor: Theme.of(context).primaryColor, child: IconButton(icon: const Icon(Icons.send, color: Colors.black), onPressed: _enviarMensaje))
            ],
          ),
        )
      ],
    );
  }
}