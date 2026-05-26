import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../services/api_constants.dart';
import '../auth/login_screen.dart';
import '../../main.dart';

class AdminSettings extends StatefulWidget {
  const AdminSettings({super.key});
  @override
  State<AdminSettings> createState() => _AdminSettingsState();
}

class _AdminSettingsState extends State<AdminSettings> {
  Map<String, dynamic>? _datosUsuario;
  bool _cargando = true;
  String _mensajeError = "";
  File? _fotoLocal;

  @override
  void initState() {
    super.initState();
    _cargarFotoLocal();
    _obtenerPerfil();
  }

  Future<void> _cargarFotoLocal() async {
    final prefs = await SharedPreferences.getInstance();
    String? ruta = prefs.getString('ruta_foto_perfil');
    if (ruta != null && ruta.isNotEmpty) {
      setState(() => _fotoLocal = File(ruta));
    }
  }

  Future<void> _obtenerPerfil() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) {
        if(mounted) setState(() { _cargando = false; _mensajeError = "No hay sesión."; });
        return;
      }

      final res = await http.get(Uri.parse("${ApiConstants.baseUrl}/usuarios/me"), headers: {'Authorization': 'Bearer $token'});

      if (res.statusCode == 200) {
        if (mounted) setState(() { _datosUsuario = jsonDecode(utf8.decode(res.bodyBytes)); _cargando = false; });
      } else {
        if(mounted) setState(() { _cargando = false; _mensajeError = "Error del servidor: ${res.statusCode}"; });
      }
    } catch(e) {
      if(mounted) setState(() { _cargando = false; _mensajeError = "Error de red: $e"; });
    }
  }

  Future<void> _cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_role');
    await prefs.remove('user_id');
    await prefs.remove('ruta_foto_perfil');
    if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
  }

  void _abrirSelectorColor() {
    Color colorTemp = Theme.of(context).primaryColor;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: const Text("Color Corporativo", style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
                child: ColorPicker(pickerColor: colorTemp, enableAlpha: false, labelTypes: const [], onColorChanged: (c) => setStateDialog(() => colorTemp = c))
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: colorTemp, foregroundColor: Colors.black),
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt('tema_color', colorTemp.value);
                    appColorTema.value = colorTemp;
                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text("Aplicar")
              ),
            ],
          )
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return Scaffold(backgroundColor: Theme.of(context).scaffoldBackgroundColor, body: Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor)));
    if (_mensajeError.isNotEmpty && _datosUsuario == null) return Scaffold(backgroundColor: Theme.of(context).scaffoldBackgroundColor, body: Center(child: Text(_mensajeError, style: const TextStyle(color: Colors.redAccent))));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('PERFIL Y AJUSTES', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2.0)), backgroundColor: Theme.of(context).appBarTheme.backgroundColor, foregroundColor: Theme.of(context).appBarTheme.foregroundColor, centerTitle: true, elevation: 0),
      body: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Semantics(
                    label: 'Foto de perfil del administrador',
                    image: true,
                    child: CircleAvatar(radius: 50, backgroundColor: Theme.of(context).colorScheme.surface, backgroundImage: _fotoLocal != null ? FileImage(_fotoLocal!) : null, child: _fotoLocal == null ? Icon(Icons.admin_panel_settings, size: 50, color: Theme.of(context).primaryColor, semanticLabel: 'Sin foto de perfil') : null),
                  ),
                  Semantics(
                    label: 'Cambiar foto de perfil',
                    button: true,
                    child: GestureDetector(
                      onTap: () async {
                        final img = await ImagePicker().pickImage(source: ImageSource.gallery);
                        if(img != null) { setState(() => _fotoLocal = File(img.path)); final p = await SharedPreferences.getInstance(); await p.setString('ruta_foto_perfil', img.path); }
                      },
                      child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, shape: BoxShape.circle), child: CircleAvatar(radius: 14, backgroundColor: Theme.of(context).primaryColor, child: const Icon(Icons.camera_alt, size: 16, color: Colors.black))),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 15),
            Text(_datosUsuario?["nombre"] ?? "Administrador", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(_datosUsuario?["email"] ?? "admin@gym.com", style: const TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 30),

            const Align(alignment: Alignment.centerLeft, child: Text("PERSONALIZACIÓN", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5))),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white12)),
              child: Column(
                children: [
                  ListTile(leading: Icon(Icons.color_lens_outlined, color: Theme.of(context).primaryColor), title: const Text("Color Global de la App"), trailing: CircleAvatar(backgroundColor: Theme.of(context).primaryColor, radius: 10), onTap: _abrirSelectorColor),
                  const Divider(color: Colors.white12, height: 1, indent: 50),
                  MergeSemantics(
                    child: ValueListenableBuilder<bool>(
                        valueListenable: appModoOscuro,
                        builder: (context, isDark, child) => ListTile(
                          leading: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: Theme.of(context).primaryColor), title: const Text("Modo Oscuro"),
                          trailing: Switch(value: isDark, activeColor: Theme.of(context).primaryColor, onChanged: (val) async { final prefs = await SharedPreferences.getInstance(); await prefs.setBool('modo_oscuro', val); appModoOscuro.value = val; }),
                        )
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 1, indent: 50),
                  ValueListenableBuilder<double>(
                    valueListenable: appTamanoFuente,
                    builder: (context, escala, child) {
                      const pasos = [0.85, 1.0, 1.2, 1.4];
                      const etiquetas = ['Pequeño', 'Normal', 'Grande', 'Muy grande'];
                      int idx = pasos.indexWhere((p) => (p - escala).abs() < 0.01);
                      if (idx == -1) idx = 1;
                      Future<void> cambiar(int i) async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setDouble('tamano_fuente', pasos[i]);
                        appTamanoFuente.value = pasos[i];
                      }
                      return ListTile(
                        leading: Icon(Icons.text_fields, color: Theme.of(context).primaryColor),
                        title: const Text("Tamaño de Letra"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Reducir tamaño de letra',
                              icon: const Icon(Icons.remove_circle_outline),
                              color: idx > 0 ? Theme.of(context).primaryColor : Colors.grey,
                              onPressed: idx > 0 ? () => cambiar(idx - 1) : null,
                            ),
                            Text(etiquetas[idx], style: const TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(
                              tooltip: 'Aumentar tamaño de letra',
                              icon: const Icon(Icons.add_circle_outline),
                              color: idx < pasos.length - 1 ? Theme.of(context).primaryColor : Colors.grey,
                              onPressed: idx < pasos.length - 1 ? () => cambiar(idx + 1) : null,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withValues(alpha:0.1), foregroundColor: Colors.redAccent, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.redAccent))),
                icon: const Icon(Icons.logout), label: const Text("CERRAR SESIÓN", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                onPressed: () {
                  showDialog(context: context, builder: (context) => AlertDialog(backgroundColor: Theme.of(context).colorScheme.surface, title: const Text("¿Cerrar sesión?", style: TextStyle(fontWeight: FontWeight.bold)), content: const Text("Saldrás al panel de inicio.", style: TextStyle(color: Colors.grey)), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))), TextButton(onPressed: () { Navigator.pop(context); _cerrarSesion(); }, child: const Text("Salir", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)))]));
                },
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      ),
    );
  }
}