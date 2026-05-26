import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_constants.dart';
import '../client/social_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Map<String, dynamic>? _stats;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarStats();
  }

  Future<void> _cargarStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return;

      final res = await http.get(Uri.parse(ApiConstants.adminDashboardStats), headers: {'Authorization': 'Bearer $token'});

      if (res.statusCode == 200) {
        if (mounted) setState(() { _stats = jsonDecode(utf8.decode(res.bodyBytes)); _cargando = false; });
      } else {
        if (mounted) setState(() => _cargando = false);
      }
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // 👇 LÓGICA DE PUBLICAR ANUNCIOS DESDE EL DASHBOARD ADMIN
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
                    autofocus: true, controller: txtCtrl, maxLines: 4, style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(labelText: "Aviso global", hintText: "¿Qué quieres comunicar al gimnasio?", filled: true, fillColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)),
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
                            ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate, color: Theme.of(context).primaryColor), const SizedBox(width: 10), const Text("Añadir Foto (Opcional)", style: TextStyle(color: Colors.grey))])
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
                          request.fields['texto'] = txtCtrl.text.isEmpty ? "Aviso Importante" : txtCtrl.text;
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
      appBar: AppBar(title: const Text('PANEL ADMINISTRATIVO', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2.0)), backgroundColor: Theme.of(context).appBarTheme.backgroundColor, foregroundColor: Theme.of(context).appBarTheme.foregroundColor, centerTitle: true, elevation: 0),
      body: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: _cargando
          ? Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))
          : _stats == null
          ? const Center(child: Text("Error al cargar las estadísticas", style: TextStyle(color: Colors.redAccent)))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Finanzas (Estimación Mensual)', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            Container(
              width: double.infinity, padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3), width: 2)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Beneficio Neto Estimado', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 10),
                  Text('€${_stats!["beneficio"].toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatItem('Ingresos', '€${_stats!["ingresosBrutos"].toStringAsFixed(0)}', Colors.blueAccent),
                      _buildStatItem('Gastos', '€${_stats!["gastosSimulados"].toStringAsFixed(0)}', Colors.redAccent),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
            Text('Resumen de Usuarios', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            GridView.count(
              crossAxisCount: 2, mainAxisSpacing: 15, crossAxisSpacing: 15, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildUserCard('Clientes Totales', '${_stats!["totalClientes"]}', Colors.blueAccent),
                _buildUserCard('Empleados', '${_stats!["totalEmpleados"]}', Colors.purpleAccent),
                _buildUserCard('Al Día', '${_stats!["clientesActivos"]}', Colors.greenAccent),
                _buildUserCard('Morosos', '${_stats!["clientesImpagados"]}', Colors.redAccent),
              ],
            ),

            const SizedBox(height: 30),
            Text('Comunicación', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            // 👇 EL NUEVO BOTÓN DE IR AL MURO
            SizedBox(
              width: double.infinity, height: 60,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SocialScreen())),
                icon: const Icon(Icons.campaign, color: Colors.black, size: 28),
                label: const Text('IR AL MURO SOCIAL', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildStatItem(String titulo, String valor, Color color) {
    return MergeSemantics(child: Column(children: [Text(titulo, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 11)), const SizedBox(height: 5), Text(valor, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold))]));
  }

  Widget _buildUserCard(String titulo, String cantidad, Color color) {
    return Container(
      padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withValues(alpha: 0.3), width: 2)),
      child: MergeSemantics(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.people, size: 40, color: color.withValues(alpha: 0.7)), const SizedBox(height: 10), Text(titulo, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12)), const SizedBox(height: 5), Text(cantidad, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold))])),
    );
  }
}