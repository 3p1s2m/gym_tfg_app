import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:cached_network_image/cached_network_image.dart'; // 👈 NUEVO IMPORT
import 'coach_catalog_screen.dart';
import '../../services/api_constants.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  bool _tieneEntrenador = false;
  bool _esEntrenador = false;
  bool _esStaffOAdmin = false;

  int? _miId;
  int? _coachId;
  String _nombreCoach = "Mi Entrenador";

  late List<DateTime> _proximos7Dias;
  late DateTime _fechaActiva;

  List<dynamic> _clasesGym = [];
  List<dynamic> _noticiasMuro = [];
  List<dynamic> _usuariosRanking = [];
  List<Map<String, dynamic>> _mensajesChat = [];

  bool _cargando = true;

  WebSocketChannel? _canalChat;
  final TextEditingController _chatController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _inicializarFechas();
    _cargarTodoDesdeBD();
  }

  @override
  void dispose() {
    _canalChat?.sink.close();
    _chatController.dispose();
    super.dispose();
  }

  void _inicializarFechas() {
    DateTime hoy = DateTime.now();
    _proximos7Dias = List.generate(7, (index) => hoy.add(Duration(days: index)));
    _fechaActiva = _proximos7Dias.first;
  }

  Future<void> _cargarTodoDesdeBD() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final rol = prefs.getString('user_role');

      if (mounted) {
        setState(() {
          _esEntrenador = (rol == 'entrenador');
          _esStaffOAdmin = (rol == 'staff' || rol == 'admin');
        });
      }

      if (token == null) return;

      final headers = {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};

      final resPerfil = await http.get(Uri.parse("${ApiConstants.baseUrl}/usuarios/me"), headers: headers);
      if (resPerfil.statusCode == 200) {
        final perfil = jsonDecode(utf8.decode(resPerfil.bodyBytes));
        _miId = perfil["idUsuario"];
      }

      final resCoach = await http.get(Uri.parse("${ApiConstants.baseUrl}/usuarios/mi-entrenador"), headers: headers);
      if (resCoach.statusCode == 200) {
        final coachData = jsonDecode(utf8.decode(resCoach.bodyBytes));
        if (mounted) {
          setState(() {
            _tieneEntrenador = true;
            _coachId = coachData["idUsuario"];
            _nombreCoach = coachData["nombre"];
          });
        }
        _conectarWebSocket();
        _cargarHistorialChat(headers);
      } else {
        if (mounted) setState(() => _tieneEntrenador = false);
      }

      final resMuro = await http.get(Uri.parse(ApiConstants.muroSocial), headers: headers);
      if (resMuro.statusCode == 200) _noticiasMuro = List<dynamic>.from(jsonDecode(utf8.decode(resMuro.bodyBytes)).reversed);

      final resClases = await http.get(Uri.parse(ApiConstants.clasesGrupales), headers: headers);
      if (resClases.statusCode == 200) _clasesGym = List<dynamic>.from(jsonDecode(utf8.decode(resClases.bodyBytes)));

      final resRanking = await http.get(Uri.parse("${ApiConstants.baseUrl}/usuarios/ranking"), headers: headers);
      if (resRanking.statusCode == 200) _usuariosRanking = List<dynamic>.from(jsonDecode(utf8.decode(resRanking.bodyBytes)));

    } catch (e) {
      print("Error cargando sección social: $e");
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarDialogoPublicar() {
    TextEditingController txtCtrl = TextEditingController();
    XFile? fotoSeleccionada;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 20, right: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Crear Anuncio", style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: txtCtrl, maxLines: 4,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(hintText: "¿Qué quieres comunicar al gimnasio?", filled: true, fillColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)),
                  ),
                  const SizedBox(height: 15),
                  InkWell(
                      onTap: () async {
                        final picker = ImagePicker();
                        final XFile? foto = await picker.pickImage(source: ImageSource.gallery);
                        if (foto != null) setModalState(() => fotoSeleccionada = foto);
                      },
                      child: Container(
                        width: double.infinity,
                        height: fotoSeleccionada == null ? 60 : 150,
                        decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(15)),
                        child: fotoSeleccionada == null
                            ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate, color: Theme.of(context).primaryColor), const SizedBox(width: 10), const Text("Añadir Foto de Galería", style: TextStyle(color: Colors.grey))])
                            : ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.file(File(fotoSeleccionada!.path), fit: BoxFit.cover)),
                      )
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () async {
                        if (txtCtrl.text.isNotEmpty || fotoSeleccionada != null) {
                          Navigator.pop(context);

                          setState(() => _cargando = true);
                          final prefs = await SharedPreferences.getInstance();
                          final token = prefs.getString('jwt_token');

                          var uri = Uri.parse("${ApiConstants.baseUrl}/social/publicar");
                          var request = http.MultipartRequest('POST', uri);
                          request.headers.addAll({'Authorization': 'Bearer $token'});
                          request.fields['texto'] = txtCtrl.text.isEmpty ? "Nuevo Anuncio" : txtCtrl.text;

                          if (fotoSeleccionada != null) {
                            request.files.add(await http.MultipartFile.fromPath('foto', fotoSeleccionada!.path));
                          }
                          await request.send();
                          await _cargarTodoDesdeBD();
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Anuncio publicado'), backgroundColor: Colors.green));
                        }
                      },
                      child: const Text("PUBLICAR ANUNCIO", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          }
      ),
    );
  }

  Future<void> _gestionarReservaBD(int idClase, bool esReserva) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) return;

    String endpoint = esReserva ? "reservar" : "cancelar";
    final url = Uri.parse("${ApiConstants.clasesGrupales}/$idClase/$endpoint");

    final response = esReserva ? await http.post(url, headers: {'Authorization': 'Bearer $token'}) : await http.delete(url, headers: {'Authorization': 'Bearer $token'});

    if (response.statusCode == 200) {
      await _cargarTodoDesdeBD();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(esReserva ? '✅ ¡Plaza reservada!' : '🗑️ Reserva cancelada.'), backgroundColor: esReserva ? Colors.green : Colors.redAccent));
    }
  }

  Future<void> _cargarHistorialChat(Map<String, String> headers) async {
    if (_coachId == null) return;
    final resChat = await http.get(Uri.parse(ApiConstants.historialChat(_coachId!)), headers: headers);
    if (resChat.statusCode == 200) {
      List<dynamic> historial = jsonDecode(utf8.decode(resChat.bodyBytes));
      if (mounted) setState(() => _mensajesChat = historial.map((msg) => {"texto": msg["contenido"], "soyYo": msg["emisor"]["idUsuario"] == _miId}).toList());
    }
  }

  void _conectarWebSocket() {
    if (_miId == null) return;
    _canalChat = WebSocketChannel.connect(Uri.parse(ApiConstants.wsChat(_miId!)));
    _canalChat!.stream.listen((mensajeJson) {
      final data = jsonDecode(mensajeJson);
      if (mounted) setState(() => _mensajesChat.add({"texto": data["contenido"], "soyYo": false}));
    });
  }

  void _enviarMensaje() {
    if (_chatController.text.trim().isEmpty || _canalChat == null) return;
    String texto = _chatController.text;
    setState(() => _mensajesChat.add({"texto": texto, "soyYo": true}));
    final msg = jsonEncode({"emisorId": _miId, "receptorId": _coachId, "contenido": texto});
    _canalChat!.sink.add(msg);
    _chatController.clear();
  }

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
    if (_cargando) return Scaffold(backgroundColor: Theme.of(context).scaffoldBackgroundColor, body: Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor)));

    return DefaultTabController(
      length: (_esEntrenador || _esStaffOAdmin) ? 3 : 4,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('COMUNIDAD', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2.0)),
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
          elevation: 0,
          centerTitle: true,
          bottom: TabBar(
            indicatorColor: Theme.of(context).primaryColor,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            tabs: [
              const Tab(icon: Icon(Icons.campaign), text: "Muro"),
              const Tab(icon: Icon(Icons.event_available), text: "Clases"),
              const Tab(icon: Icon(Icons.emoji_events), text: "Ranking"),
              if (!_esEntrenador && !_esStaffOAdmin) const Tab(icon: Icon(Icons.chat), text: "Coach"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildMuroNoticias(),
            _buildListaClases(),
            _buildRanking(),
            if (!_esEntrenador && !_esStaffOAdmin) _tieneEntrenador ? _buildChatEntrenador() : _buildMuroDePagoChat(),
          ],
        ),
      ),
    );
  }

  Widget _buildMuroNoticias() {
    return Stack(
      children: [
        if (_noticiasMuro.isEmpty)
          const Center(child: Text("El muro está vacío.", style: TextStyle(color: Colors.grey)))
        else
        // 👇 AÑADIDO EL REFRESH INDICATOR PARA DESLIZAR Y RECARGAR
          RefreshIndicator(
            onRefresh: _cargarTodoDesdeBD,
            color: Theme.of(context).primaryColor,
            child: ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: _noticiasMuro.length,
              itemBuilder: (context, index) {
                final post = _noticiasMuro[index];
                bool isAdmin = post["usuario"]["rol"] == "STAFF" || post["usuario"]["rol"] == "ADMIN";
                bool tieneImagen = post["urlImagen"] != null && post["urlImagen"].toString().isNotEmpty;

                DateTime fechaPub;
                try {
                  fechaPub = DateTime.parse(post["fechaPublicacion"]);
                } catch(e) {
                  fechaPub = DateTime.now();
                }

                String urlFoto = "";
                if (tieneImagen) {
                  urlFoto = post["urlImagen"].toString().startsWith("http")
                      ? post["urlImagen"]
                      : "${ApiConstants.baseUrl.replaceAll('/api', '')}${post["urlImagen"]}";
                }

                return Card(
                  color: Theme.of(context).colorScheme.surface, margin: const EdgeInsets.only(bottom: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.white12)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(backgroundColor: isAdmin ? Colors.purpleAccent.withValues(alpha: 0.2) : Colors.orangeAccent.withValues(alpha: 0.2), child: Icon(isAdmin ? Icons.admin_panel_settings : Icons.sports, color: isAdmin ? Colors.purpleAccent : Colors.orangeAccent)),
                            const SizedBox(width: 15),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(post["usuario"]["nombre"], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text("${fechaPub.day}/${fechaPub.month}/${fechaPub.year}", style: const TextStyle(color: Colors.grey, fontSize: 12))])),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: (isAdmin ? Colors.purpleAccent : Colors.orangeAccent).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(5)), child: Text(post["usuario"]["rol"], style: TextStyle(color: isAdmin ? Colors.purpleAccent : Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)))
                          ],
                        ),
                        const SizedBox(height: 15),
                        Text(post["textoCaption"] ?? "", style: const TextStyle(fontSize: 15, height: 1.5)),
                        if (tieneImagen) ...[
                          const SizedBox(height: 15),
                          ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              // 👇 MAGIA DE LA CACHÉ APLICADA
                              child: CachedNetworkImage(
                                imageUrl: urlFoto,
                                width: double.infinity, height: 200, fit: BoxFit.cover,
                                placeholder: (context, url) => Container(height: 200, color: Colors.white10, child: Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor, strokeWidth: 2))),
                                errorWidget: (context, url, error) => Container(height: 200, color: Colors.white10, child: const Center(child: Icon(Icons.broken_image, color: Colors.grey))),
                              )
                          )
                        ]
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

        if (_esEntrenador || _esStaffOAdmin)
          Positioned(
            bottom: 20, right: 20,
            child: FloatingActionButton(
              backgroundColor: Theme.of(context).primaryColor,
              onPressed: _mostrarDialogoPublicar,
              child: const Icon(Icons.add, color: Colors.black),
            ),
          )
      ],
    );
  }

  Widget _buildRanking() {
    if (_usuariosRanking.isEmpty) return const Center(child: Text("No hay usuarios visibles", style: TextStyle(color: Colors.grey)));
    return Column(
      children: [
        Container(padding: const EdgeInsets.all(15), color: Theme.of(context).primaryColor.withValues(alpha: 0.05), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.info_outline, color: Theme.of(context).primaryColor, size: 16), const SizedBox(width: 10), Text("Top Atletas del Gimnasio", style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 12))])),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: _usuariosRanking.length,
            itemBuilder: (context, index) {
              final user = _usuariosRanking[index];
              bool esTop3 = index < 3;
              Color colorPuesto = index == 0 ? Colors.amber : (index == 1 ? Colors.grey.shade400 : (index == 2 ? Colors.brown.shade400 : Colors.white24));
              String puntos = (user["puntuacion"] ?? 0).toString();
              String nombreCoach = user["nombreEntrenador"] ?? "Entrena por libre";
              bool soyYo = user["idUsuario"] == _miId;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                decoration: BoxDecoration(
                    color: soyYo ? Theme.of(context).primaryColor.withValues(alpha: 0.15) : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: soyYo ? Theme.of(context).primaryColor : Colors.white12, width: soyYo ? 2 : 1)
                ),
                child: Row(
                  children: [
                    SizedBox(width: 30, child: Text("#${index + 1}", style: TextStyle(color: colorPuesto, fontWeight: FontWeight.bold, fontSize: esTop3 ? 20 : 16))),
                    const SizedBox(width: 5),
                    const CircleAvatar(radius: 20, backgroundColor: Colors.white10, child: Icon(Icons.person, color: Colors.grey)),
                    const SizedBox(width: 15),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user["nombre"] ?? "Usuario", style: TextStyle(fontSize: 16, fontWeight: soyYo ? FontWeight.bold : FontWeight.normal)),
                        Text("Coach: $nombreCoach", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    )),
                    Text("$puntos pts", style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildListaClases() {
    List<dynamic> clasesFiltradas = _clasesGym.where((clase) {
      if (clase["fechaHora"] == null) return false;
      return _esMismoDia(DateTime.parse(clase["fechaHora"]), _fechaActiva);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _proximos7Dias.map((fecha) {
              bool activo = _esMismoDia(fecha, _fechaActiva);
              return GestureDetector(
                onTap: () => setState(() => _fechaActiva = fecha),
                child: CircleAvatar(
                  radius: 20, backgroundColor: activo ? Theme.of(context).primaryColor : Colors.transparent,
                  child: Text(["L", "M", "M", "J", "V", "S", "D"][fecha.weekday - 1], style: TextStyle(color: activo ? Colors.black : Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: clasesFiltradas.isEmpty
              ? const Center(child: Text("No hay clases programadas para hoy.", style: TextStyle(color: Colors.grey)))
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            itemCount: clasesFiltradas.length,
            itemBuilder: (context, index) {
              final clase = clasesFiltradas[index];
              Color colorClase = _colorFromHex(clase["colorHex"]);
              bool estoyInscrito = clase["reservadaPorMi"] == true;

              return Card(
                color: Theme.of(context).colorScheme.surface, margin: const EdgeInsets.only(bottom: 15), clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: estoyInscrito ? Colors.greenAccent.withValues(alpha: 0.5) : Colors.transparent, width: 2)),
                child: InkWell(
                  onTap: () async {
                    final accion = await Navigator.push(context, MaterialPageRoute(builder: (c) => ClassDetailScreen(clase: clase, colorVisual: colorClase, estoyInscrito: estoyInscrito, esEntrenador: (_esEntrenador || _esStaffOAdmin))));
                    if (accion == 'reservar') _gestionarReservaBD(clase["idClase"], true);
                    if (accion == 'cancelar') _gestionarReservaBD(clase["idClase"], false);
                  },
                  child: SizedBox(
                    height: 120,
                    child: Stack(
                      children: [
                        Row(
                          children: [
                            Expanded(
                                flex: 4,
                                child: ColorFiltered(
                                    colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
                                    // 👇 MAGIA CACHÉ
                                    child: CachedNetworkImage(
                                        imageUrl: clase["imagenUrl"] ?? "",
                                        fit: BoxFit.cover, height: double.infinity,
                                        placeholder: (context, url) => Container(color: Colors.black26, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).primaryColor))),
                                        errorWidget: (context, url, error) => Container(color: Colors.black26)
                                    )
                                )
                            ),
                            Expanded(flex: 6, child: Container(decoration: BoxDecoration(border: Border(right: BorderSide(color: colorClase, width: 6))), padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_formatearHora(DateTime.parse(clase["fechaHora"])), style: const TextStyle(color: Colors.grey, fontSize: 14)), Text("${clase["ocupadas"] ?? 0} / ${clase["totales"] ?? 20} plazas", style: TextStyle(color: colorClase, fontSize: 12, fontWeight: FontWeight.bold))]), const Spacer(), Text(clase["nombre"] ?? "Clase", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(clase["sala"] ?? "Sala 1", style: const TextStyle(color: Colors.grey, fontSize: 14))]))),
                          ],
                        ),
                        if (estoyInscrito) Positioned(bottom: 0, right: 6, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: const BoxDecoration(color: Colors.greenAccent, borderRadius: BorderRadius.only(topLeft: Radius.circular(10))), child: const Text("INSCRITO", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10))))
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChatEntrenador() {
    return Column(
      children: [
        Container(
            padding: const EdgeInsets.all(15), color: Theme.of(context).appBarTheme.backgroundColor,
            child: Row(
                children: [
                  CircleAvatar(backgroundColor: Theme.of(context).primaryColor.withValues(alpha:0.2), child: Icon(Icons.sports, color: Theme.of(context).primaryColor)),
                  const SizedBox(width: 15),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_nombreCoach, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))])
                ]
            )
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: _mensajesChat.length,
            itemBuilder: (context, index) {
              final msg = _mensajesChat[index];
              return _buildBurbujaChat(msg["texto"], msg["soyYo"]);
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(color: Theme.of(context).appBarTheme.backgroundColor, border: const Border(top: BorderSide(color: Colors.white12))),
          child: Row(
            children: [
              Expanded(child: TextField(controller: _chatController, decoration: InputDecoration(hintText: "Escribe un mensaje...", hintStyle: const TextStyle(color: Colors.grey), filled: true, fillColor: Theme.of(context).colorScheme.surface, contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none)))),
              const SizedBox(width: 10),
              CircleAvatar(backgroundColor: Theme.of(context).primaryColor, child: IconButton(icon: const Icon(Icons.send, color: Colors.black), onPressed: _enviarMensaje))
            ],
          ),
        )
      ],
    );
  }

  Widget _buildBurbujaChat(String texto, bool soyYo) {
    return Align(
      alignment: soyYo ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
            color: soyYo ? Theme.of(context).primaryColor.withValues(alpha: 0.2) : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.only(topLeft: const Radius.circular(20), topRight: const Radius.circular(20), bottomLeft: Radius.circular(soyYo ? 20 : 0), bottomRight: Radius.circular(soyYo ? 0 : 20)),
            border: Border.all(color: soyYo ? Theme.of(context).primaryColor.withValues(alpha: 0.5) : Colors.transparent)
        ),
        constraints: const BoxConstraints(maxWidth: 250),
        child: Text(texto, style: const TextStyle(fontSize: 14)),
      ),
    );
  }

  Widget _buildMuroDePagoChat() {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 50.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).primaryColor.withValues(alpha: 0.1), boxShadow: [BoxShadow(color: Theme.of(context).primaryColor.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 5)]), child: Icon(Icons.lock_outline, size: 70, color: Theme.of(context).primaryColor)),
              const SizedBox(height: 30),
              const Text("Chat Exclusivo", textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              const Text("Contrata a un entrenador personal para poder escribirle en cualquier momento y resolver tus dudas al instante.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 15, height: 1.5)),
              const SizedBox(height: 40),
              SizedBox(
                  width: double.infinity, height: 55,
                  child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      icon: const Icon(Icons.star, color: Colors.black),
                      label: const Text("CONTRATAR ENTRENADOR", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      onPressed: () async {
                        final bool? contratado = await Navigator.push(context, MaterialPageRoute(builder: (context) => const CoachCatalogScreen()));
                        if (contratado == true) { setState(() => _cargando = true); await _cargarTodoDesdeBD(); }
                      }
                  )
              )
            ],
          ),
        ),
      ),
    );
  }
}

// Sub-pantalla dentro del archivo
class ClassDetailScreen extends StatelessWidget {
  final Map<String, dynamic> clase;
  final Color colorVisual;
  final bool estoyInscrito;
  final bool esEntrenador;

  const ClassDetailScreen({super.key, required this.clase, required this.colorVisual, required this.estoyInscrito, required this.esEntrenador});

  @override
  Widget build(BuildContext context) {
    DateTime d = DateTime.parse(clase["fechaHora"]);
    int ocupadas = clase["ocupadas"] ?? 0;
    int totales = clase["totales"] ?? 20;
    bool estaLlena = ocupadas >= totales;

    String textoBoton = "RESERVAR PLAZA";
    Color colorBoton = colorVisual;

    if (esEntrenador) {
      textoBoton = "MODO LECTURA (STAFF)";
      colorBoton = Colors.grey;
    } else if (estoyInscrito) {
      textoBoton = "CANCELAR RESERVA";
      colorBoton = Colors.redAccent;
    } else if (estaLlena) {
      textoBoton = "CLASE COMPLETA";
      colorBoton = Colors.grey;
    }

    return Scaffold(
        body: Stack(fit: StackFit.expand, children: [
          ColorFiltered(
              colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
              // 👇 MAGIA CACHÉ
              child: CachedNetworkImage(
                  imageUrl: clase["imagenUrl"] ?? "",
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: Colors.black87),
                  errorWidget: (context, url, error) => const SizedBox()
              )
          ),
          Container(color: Colors.black.withValues(alpha: 0.85)),
          SafeArea(child: Padding(padding: const EdgeInsets.all(25.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(clase["nombre"] ?? "", style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w300), overflow: TextOverflow.ellipsis)), CircleAvatar(backgroundColor: colorVisual, child: IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: () => Navigator.pop(context)))]),
            const SizedBox(height: 50),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("HORARIO:", style: TextStyle(color: colorVisual, fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 5), Text("${d.day}/${d.month}/${d.year}\n${d.hour}:${d.minute.toString().padLeft(2, '0')}", style: const TextStyle(color: Colors.white, height: 1.5, fontSize: 16)), const SizedBox(height: 30), Text("SALA:", style: TextStyle(color: colorVisual, fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 5), Text(clase["sala"] ?? "", style: const TextStyle(color: Colors.white, fontSize: 16))])),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("MONITOR:", style: TextStyle(color: colorVisual, fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 5), Text(clase["entrenador"] ?? "", style: const TextStyle(color: Colors.white, fontSize: 16)), const SizedBox(height: 30), Text("AFORO:", style: TextStyle(color: colorVisual, fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 5), Text("$ocupadas de $totales", style: const TextStyle(color: Colors.white, fontSize: 16))])),
            ]),
            const SizedBox(height: 40),
            Text("DESCRIPCIÓN:", style: TextStyle(color: colorVisual, fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 10), Text(clase["descripcion"] ?? "", style: const TextStyle(color: Colors.white, height: 1.5, fontSize: 15)),
            const Spacer(),
            SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: colorBoton),
                  onPressed: (esEntrenador || (estaLlena && !estoyInscrito)) ? null : () => Navigator.pop(context, estoyInscrito ? 'cancelar' : 'reservar'),
                  child: Text(textoBoton, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.0)),
                )
            )
          ])))
        ])
    );
  }
}