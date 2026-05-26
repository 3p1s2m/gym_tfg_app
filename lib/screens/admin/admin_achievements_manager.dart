import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_constants.dart';

class AdminAchievementsManager extends StatefulWidget {
  const AdminAchievementsManager({super.key});
  @override
  State<AdminAchievementsManager> createState() => _AdminAchievementsManagerState();
}

class _AdminAchievementsManagerState extends State<AdminAchievementsManager> {
  List<dynamic> _logros = [];
  bool _cargando = true;

  @override
  void initState() { super.initState(); _cargarLogros(); }

  Future<void> _cargarLogros() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final res = await http.get(Uri.parse(ApiConstants.catalogoLogros),headers: {'Authorization': 'Bearer ${prefs.getString('jwt_token')}'});
      if (res.statusCode == 200 && mounted) {
        setState(() { _logros = jsonDecode(utf8.decode(res.bodyBytes)); _cargando = false; });
      }
    } catch (e) { if(mounted) setState(() => _cargando = false); }
  }

  void _abrirCrearLogro() {
    TextEditingController nombreCtrl = TextEditingController();
    TextEditingController descCtrl = TextEditingController();
    String difSeleccionada = 'BRONCE';

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Crear Nuevo Logro', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextField(controller: nombreCtrl, decoration: InputDecoration(labelText: 'Nombre del logro', hintText: 'Nombre del logro', filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
                  const SizedBox(height: 15),
                  TextField(controller: descCtrl, maxLines: 3, decoration: InputDecoration(labelText: 'Descripción', hintText: 'Descripción', filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    value: difSeleccionada, dropdownColor: Theme.of(context).colorScheme.surface, decoration: InputDecoration(filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
                    items: ['BRONCE', 'PLATA', 'ORO', 'DIAMANTE', 'ELITE'].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (v) => setModalState(() => difSeleccionada = v!),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                      onPressed: () async {
                        if (nombreCtrl.text.isEmpty || descCtrl.text.isEmpty) return;
                        Navigator.pop(context); setState(() => _cargando = true);

                        String icono = "gema_${difSeleccionada.toLowerCase()}.png";
                        final prefs = await SharedPreferences.getInstance();
                        final res = await http.post(Uri.parse(ApiConstants.adminCrearLogro), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${prefs.getString('jwt_token')}'}, body: jsonEncode({"nombre": nombreCtrl.text, "descripcion": descCtrl.text, "dificultad": difSeleccionada, "iconoUrl": icono}));

                        if (res.statusCode == 200) { _cargarLogros(); if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Logro Creado'), backgroundColor: Colors.green)); }
                      },
                      child: const Text('Crear Logro', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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

  Color _getColorDificultad(String dificultad) {
    switch (dificultad) { case 'BRONCE': return Colors.brown.shade400; case 'PLATA': return Colors.grey.shade400; case 'ORO': return Colors.amber; case 'DIAMANTE': return Colors.cyan; case 'ELITE': return Colors.purpleAccent; default: return Colors.grey; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('CATÁLOGO DE LOGROS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2.0)), backgroundColor: Theme.of(context).appBarTheme.backgroundColor, foregroundColor: Theme.of(context).appBarTheme.foregroundColor, centerTitle: true, elevation: 0),
      floatingActionButton: FloatingActionButton(tooltip: 'Crear nuevo logro', backgroundColor: Theme.of(context).primaryColor, onPressed: _abrirCrearLogro, child: const Icon(Icons.add, color: Colors.black)),
      body: _cargando ? Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor)) : ListView.builder(
        padding: const EdgeInsets.all(15), itemCount: _logros.length,
        itemBuilder: (context, index) {
          final logro = _logros[index];
          final color = _getColorDificultad(logro['dificultad']);
          return MergeSemantics(
            child: Card(
              color: Theme.of(context).colorScheme.surface, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.white12)),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    Container(width: 50, height: 50, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.2)), child: Icon(Icons.emoji_events, size: 30, color: color)),
                    const SizedBox(width: 15),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(logro['nombre'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 4), Text(logro['descripcion'], style: const TextStyle(color: Colors.grey, fontSize: 12))])),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}