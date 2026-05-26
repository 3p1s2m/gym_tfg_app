import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_constants.dart';
import '../client/social_screen.dart';

class StaffDashboard extends StatefulWidget {
  final VoidCallback? onNavigateToSocios;

  const StaffDashboard({super.key, this.onNavigateToSocios});
  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
  double _ingresosHoy = 0.0;
  int _clasesHoy = 0;
  int _sociosImpagados = 0;
  bool _haFichado = false;
  String _horaFichaje = "";

  @override
  void initState() {
    super.initState();
    _cargarMetricas();
  }

  Future<void> _cargarMetricas() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) return;
    try {
      final resClases = await http.get(Uri.parse(ApiConstants.clasesGrupales), headers: {'Authorization': 'Bearer $token'});
      if (resClases.statusCode == 200) {
        List<dynamic> clases = jsonDecode(utf8.decode(resClases.bodyBytes));
        int hoy = 0; DateTime now = DateTime.now();
        for (var c in clases) {
          DateTime fecha = DateTime.parse(c["fechaHora"]);
          if (fecha.year == now.year && fecha.month == now.month && fecha.day == now.day) hoy++;
        }
        if(mounted) setState(() => _clasesHoy = hoy);
      }
      final resSocios = await http.get(Uri.parse(ApiConstants.staffClientes), headers: {'Authorization': 'Bearer $token'});
      if (resSocios.statusCode == 200) {
        List<dynamic> socios = jsonDecode(utf8.decode(resSocios.bodyBytes));
        if(mounted) setState(() => _sociosImpagados = socios.where((s) => s["estadoPago"] == "IMPAGADO").length);
      }
    } catch(e) { print(e); }
  }

  void _fichar() {
    setState(() {
      _haFichado = !_haFichado;
      DateTime now = DateTime.now();
      _horaFichaje = "${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}";
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_haFichado ? '✅ Entrada registrada a las $_horaFichaje' : '👋 Salida registrada a las $_horaFichaje'), backgroundColor: _haFichado ? Colors.green : Colors.orange));
  }

  void _registrarNuevoCliente() {
    TextEditingController nombreCtrl = TextEditingController();
    TextEditingController emailCtrl = TextEditingController();
    TextEditingController passCtrl = TextEditingController();
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Alta Rápida de Cliente", style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            TextField(autofocus: true, controller: nombreCtrl, decoration: InputDecoration(labelText: 'Nombre completo', hintText: 'Nombre completo', filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
            const SizedBox(height: 10),
            TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'Email', hintText: 'Email', filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
            const SizedBox(height: 10),
            TextField(controller: passCtrl, decoration: InputDecoration(labelText: 'Contraseña', hintText: 'Contraseña', filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor), onPressed: () async {
              if (nombreCtrl.text.isEmpty || emailCtrl.text.isEmpty || passCtrl.text.isEmpty) return;
              Navigator.pop(context);
              final prefs = await SharedPreferences.getInstance();
              final res = await http.post(Uri.parse(ApiConstants.staffCrearCliente), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${prefs.getString('jwt_token')}'}, body: jsonEncode({"nombre": nombreCtrl.text, "email": emailCtrl.text, "password": passCtrl.text, "rol": "CLIENTE", "peso": 70, "altura": 170, "genero": "OTRO", "fechaNacimiento": "2000-01-01"}));
              if (res.statusCode == 200 && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Cliente registrado'), backgroundColor: Colors.green));
              }
            }, child: const Text("REGISTRAR CLIENTE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // 👇 LA FUNCIÓN DE PUBLICAR ANUNCIOS
  void _mostrarDialogoPublicar() {
    TextEditingController txtCtrl = TextEditingController();
    XFile? fotoSeleccionada;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 20, right: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Publicar Aviso Global", style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: txtCtrl, maxLines: 4, style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(hintText: "¿Qué quieres comunicar al gimnasio?", filled: true, fillColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)),
                  ),
                  const SizedBox(height: 15),
                  Semantics(
                    label: 'Añadir imagen a la publicación',
                    button: true,
                    child: InkWell(
                      onTap: () async {
                        final picker = ImagePicker();
                        final XFile? foto = await picker.pickImage(source: ImageSource.gallery);
                        if (foto != null) setModalState(() => fotoSeleccionada = foto);
                      },
                      child: Container(
                        width: double.infinity, height: fotoSeleccionada == null ? 60 : 150,
                        decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(15)),
                        child: fotoSeleccionada == null
                            ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate, color: Theme.of(context).primaryColor), const SizedBox(width: 10), const Text("Añadir Foto", style: TextStyle(color: Colors.grey))])
                            : ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.file(File(fotoSeleccionada!.path), fit: BoxFit.cover)),
                      )
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () async {
                        if (txtCtrl.text.isNotEmpty || fotoSeleccionada != null) {
                          Navigator.pop(context);
                          final prefs = await SharedPreferences.getInstance();
                          final token = prefs.getString('jwt_token');

                          var request = http.MultipartRequest('POST', Uri.parse("${ApiConstants.baseUrl}/social/publicar"));
                          request.headers.addAll({'Authorization': 'Bearer $token'});
                          request.fields['texto'] = txtCtrl.text.isEmpty ? "Aviso de Recepción" : txtCtrl.text;
                          if (fotoSeleccionada != null) request.files.add(await http.MultipartFile.fromPath('foto', fotoSeleccionada!.path));

                          await request.send();
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Anuncio publicado en el muro'), backgroundColor: Colors.green));
                        }
                      },
                      child: const Text("PUBLICAR AHORA", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('RECEPCIÓN', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2.0)), backgroundColor: Theme.of(context).appBarTheme.backgroundColor, centerTitle: true, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetricCard('Ingresos Hoy', '€${_ingresosHoy.toStringAsFixed(2)}', Colors.greenAccent),
                const SizedBox(width: 15),
                _buildMetricCard('Impagos', '$_sociosImpagados', Colors.redAccent),
                const SizedBox(width: 15),
                _buildMetricCard('Clases Hoy', '$_clasesHoy', Colors.orangeAccent),
              ],
            ),
            const SizedBox(height: 30),
            Text('Acciones Rápidas', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            GridView.count(
              crossAxisCount: 2, mainAxisSpacing: 15, crossAxisSpacing: 15, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildBotonAccion(_haFichado ? "Terminar Turno" : "Fichar Entrada", _haFichado ? Icons.timer_off : Icons.timer, _haFichado ? Colors.orange : Theme.of(context).primaryColor, _fichar),
                _buildBotonAccion("Pase de Día (5€)", Icons.euro, Colors.greenAccent, () { setState(() => _ingresosHoy += 5.0); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pase de Día vendido (+5€)'), backgroundColor: Colors.green)); }),
                _buildBotonAccion("Nuevo Cliente", Icons.person_add, Colors.blueAccent, _registrarNuevoCliente),

                // 👇 EL BOTÓN AHORA TE LLEVA AL MURO
                _buildBotonAccion("Muro Social", Icons.campaign, Colors.purpleAccent, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SocialScreen()))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String titulo, String valor, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withValues(alpha: 0.3), width: 2)),
        child: MergeSemantics(child: Column(children: [Text(titulo, style: const TextStyle(color: Colors.grey, fontSize: 10)), const SizedBox(height: 8), Text(valor, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold))])),
      ),
    );
  }

  Widget _buildBotonAccion(String titulo, IconData icono, Color color, VoidCallback onTap) {
    return Semantics(
      label: titulo,
      button: true,
      child: InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(15),
      child: Container(
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(radius: 25, backgroundColor: color.withValues(alpha: 0.2), child: Icon(icono, color: color, size: 30)),
            const SizedBox(height: 10),
            Text(titulo, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    ),
    );
  }
}