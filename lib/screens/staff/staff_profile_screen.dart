import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../services/api_constants.dart';
import '../auth/login_screen.dart';
import '../../main.dart'; // Chivatos globales

class StaffProfileScreen extends StatefulWidget {
  const StaffProfileScreen({super.key});

  @override
  State<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends State<StaffProfileScreen> {
  Map<String, dynamic>? _datosUsuario;
  bool _cargando = true;
  String _mensajeError = "";
  File? _fotoLocal;

  @override
  void initState() {
    super.initState();
    _cargarFotoLocal();
    _obtenerPerfilDeLaBaseDeDatos();
  }

  Future<void> _cargarFotoLocal() async {
    final prefs = await SharedPreferences.getInstance();
    String? rutaFoto = prefs.getString('ruta_foto_perfil');
    if (rutaFoto != null && rutaFoto.isNotEmpty) {
      setState(() => _fotoLocal = File(rutaFoto));
    }
  }

  Future<void> _obtenerPerfilDeLaBaseDeDatos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) {
        setState(() { _cargando = false; _mensajeError = "No hay sesión iniciada"; });
        return;
      }

      final url = Uri.parse("${ApiConstants.baseUrl}/usuarios/me");
      final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        bool tieneCoach = data["entrenadorAsignado"] != null;
        await prefs.setBool('tiene_entrenador', tieneCoach);

        setState(() {
          _datosUsuario = data;
          _cargando = false;
        });
      } else {
        setState(() {
          _cargando = false;
          _mensajeError = "Error del servidor: Code ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _cargando = false;
        _mensajeError = "Error de red/formato: $e";
      });
    }
  }

  Future<void> _actualizarPerfilEnBaseDeDatos(Map<String, dynamic> datosNuevos) async {
    setState(() => _cargando = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final url = Uri.parse("${ApiConstants.baseUrl}/usuarios/me");
      final bodyJson = jsonEncode(datosNuevos);

      final response = await http.put(url, headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}, body: bodyJson);

      if (response.statusCode == 200) {
        var decodedData = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _datosUsuario = decodedData;
          _cargando = false;
        });

        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Ficha actualizada"), backgroundColor: Colors.green));
      } else {
        setState(() => _cargando = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Error del servidor: ${response.statusCode}"), backgroundColor: Colors.red));
      }
    } catch (e) {
      setState(() => _cargando = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Error al guardar: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _mostrarOpcionesDeFoto() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.photo_camera, color: Theme.of(context).primaryColor),
              title: const Text('Hacer una foto'),
              onTap: () { Navigator.pop(context); _seleccionarFoto(ImageSource.camera); },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: Theme.of(context).primaryColor),
              title: const Text('Elegir de la galería'),
              onTap: () { Navigator.pop(context); _seleccionarFoto(ImageSource.gallery); },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _seleccionarFoto(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);
    if (image != null) {
      setState(() => _fotoLocal = File(image.path));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ruta_foto_perfil', image.path);
    }
  }

  // 👇 CIERRE DE SESIÓN LIMPIO: Solo borra credenciales.
  Future<void> _cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('jwt_token');
    await prefs.remove('user_role');
    await prefs.remove('user_id');
    await prefs.remove('tiene_entrenador');
    await prefs.remove('ruta_foto_perfil');
    // NO SE TOCA appColorTema, ni appModoOscuro, ni appGenero.

    if (mounted) {
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false
      );
    }
  }

  String _calcularEdad(String? fechaISO) {
    if (fechaISO == null || fechaISO.isEmpty) return "--";
    try {
      DateTime nacimiento = DateTime.parse(fechaISO);
      DateTime hoy = DateTime.now();
      int edad = hoy.year - nacimiento.year;
      if (hoy.month < nacimiento.month || (hoy.month == nacimiento.month && hoy.day < nacimiento.day)) {
        edad--;
      }
      return edad.toString();
    } catch (e) {
      return "--";
    }
  }

  // 👇 SELECTOR DE COLOR CORREGIDO (Actualiza en tiempo real sin fallos)
  void _abrirSelectorColor() {
    Color colorTemporal = Theme.of(context).primaryColor;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: const Text("Elige tu color", style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: ColorPicker(
                  pickerColor: colorTemporal,
                  onColorChanged: (color) {
                    // Actualiza el color en el propio diálogo
                    setStateDialog(() => colorTemporal = color);
                  },
                  pickerAreaHeightPercent: 0.8,
                  enableAlpha: false,
                  labelTypes: const [],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancelar", style: TextStyle(color: Colors.grey))
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: colorTemporal, foregroundColor: Colors.black),
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt('tema_color', colorTemporal.value);

                    // Actualiza toda la app al instante
                    appColorTema.value = colorTemporal;

                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text("Aplicar Color"),
                ),
              ],
            );
          }
      ),
    );
  }

  void _abrirEdicionPerfil() async {
    if (_datosUsuario == null) return;

    final prefs = await SharedPreferences.getInstance();
    bool soyEntrenador = prefs.getString('user_role') == 'entrenador';

    TextEditingController nombreCtrl = TextEditingController(text: _datosUsuario!["nombre"] ?? "");
    TextEditingController especialidadCtrl = TextEditingController(text: _datosUsuario!["especialidad"] ?? "");
    TextEditingController bioCtrl = TextEditingController(text: _datosUsuario!["biografia"] ?? "");

    DateTime? fechaNacSeleccionada;
    if (_datosUsuario!["fechaNacimiento"] != null) {
      fechaNacSeleccionada = DateTime.tryParse(_datosUsuario!["fechaNacimiento"]);
    }

    String? generoSeleccionado = _datosUsuario!["genero"];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: const Text("Ficha Personal", style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: "Alias / Nombre", labelStyle: TextStyle(color: Colors.grey), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)))),
                    const SizedBox(height: 15),

                    DropdownButtonFormField<String>(
                      value: generoSeleccionado,
                      decoration: const InputDecoration(labelText: "Género del Avatar", labelStyle: TextStyle(color: Colors.grey), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38))),
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      items: const [
                        DropdownMenuItem(value: "HOMBRE", child: Text("Hombre")),
                        DropdownMenuItem(value: "MUJER", child: Text("Mujer")),
                        DropdownMenuItem(value: "OTRO", child: Text("Otro")),
                      ],
                      onChanged: (String? newValue) {
                        setStateDialog(() {
                          generoSeleccionado = newValue;
                        });
                      },
                    ),

                    if (soyEntrenador) ...[
                      const Divider(color: Colors.white24, height: 30),
                      Text("Perfil Profesional (Público)", style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
                      TextField(controller: especialidadCtrl, decoration: const InputDecoration(labelText: "Especialidad", labelStyle: TextStyle(color: Colors.grey), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)))),
                      TextField(controller: bioCtrl, maxLines: 3, decoration: const InputDecoration(labelText: "Biografía corta", labelStyle: TextStyle(color: Colors.grey), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)))),
                    ],

                    const SizedBox(height: 20),
                    const Text("Fecha de Nacimiento:", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 5),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.surface,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15)
                        ),
                        icon: Icon(Icons.calendar_today, color: Theme.of(context).primaryColor, size: 18),
                        label: Text(
                          fechaNacSeleccionada == null
                              ? "Seleccionar fecha"
                              : "${fechaNacSeleccionada!.day.toString().padLeft(2, '0')}/${fechaNacSeleccionada!.month.toString().padLeft(2, '0')}/${fechaNacSeleccionada!.year}",
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        ),
                        onPressed: () async {
                          DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: fechaNacSeleccionada ?? DateTime.now().subtract(const Duration(days: 365 * 25)),
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.dark(
                                    primary: Theme.of(context).primaryColor,
                                    onPrimary: Colors.black,
                                    surface: Theme.of(context).colorScheme.surface,
                                    onSurface: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                child: child!
                              );
                            },
                          );
                          if (picked != null) {
                            setStateDialog(() => fechaNacSeleccionada = picked);
                          }
                        },
                      ),
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                  onPressed: () {
                    Navigator.pop(context);

                    String? fechaParseada;
                    if (fechaNacSeleccionada != null) {
                      fechaParseada = "${fechaNacSeleccionada!.year}-${fechaNacSeleccionada!.month.toString().padLeft(2, '0')}-${fechaNacSeleccionada!.day.toString().padLeft(2, '0')}";
                    }

                    _actualizarPerfilEnBaseDeDatos({
                      "nombre": nombreCtrl.text,
                      "fechaNacimiento": fechaParseada,
                      "genero": generoSeleccionado,
                      "especialidad": especialidadCtrl.text,
                      "biografia": bioCtrl.text
                    });
                  },
                  child: const Text("Guardar en BD", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))
      );
    }

    if (_datosUsuario == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
                const SizedBox(height: 20),
                const Text("No pudimos cargar tu perfil", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(_mensajeError, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.black),
                  icon: const Icon(Icons.login),
                  label: const Text("VOLVER AL LOGIN"),
                  onPressed: () => _cerrarSesion(),
                )
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('MI PERFIL (STAFF)', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2.0)),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // --- CABECERA Y FOTO ---
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    backgroundImage: _fotoLocal != null ? FileImage(_fotoLocal!) : null,
                    child: _fotoLocal == null ? Icon(Icons.person, size: 50, color: Theme.of(context).primaryColor) : null,
                  ),
                  GestureDetector(
                    onTap: _mostrarOpcionesDeFoto,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, shape: BoxShape.circle),
                      child: CircleAvatar(radius: 14, backgroundColor: Theme.of(context).primaryColor, child: const Icon(Icons.camera_alt, size: 16, color: Colors.black)),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 15),
            Text(_datosUsuario!["nombre"] ?? "Sin nombre", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(_datosUsuario!["email"] ?? "Sin correo", style: const TextStyle(color: Colors.grey, fontSize: 14)),

            const SizedBox(height: 30),

            // --- PERSONALIZACIÓN ---
            const Align(alignment: Alignment.centerLeft, child: Text("PERSONALIZACIÓN", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5))),
            const SizedBox(height: 10),

            Container(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(15)),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.monitor_weight_outlined, color: Theme.of(context).primaryColor),
                    title: const Text("Actualizar Ficha Personal"),
                    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                    onTap: _abrirEdicionPerfil,
                  ),
                  const Divider(color: Colors.grey, height: 1, indent: 50, endIndent: 20,),
                  ListTile(
                    leading: Icon(Icons.color_lens_outlined, color: Theme.of(context).primaryColor),
                    title: const Text("Color Global de la App"),
                    trailing: CircleAvatar(backgroundColor: Theme.of(context).primaryColor, radius: 10),
                    onTap: _abrirSelectorColor,
                  ),
                  const Divider(color: Colors.grey, height: 1, indent: 50, endIndent: 20,),

                  // 👇 INTERRUPTOR DE MODO OSCURO (ESCUCHA LA VARIABLE GLOBAL DIRECTAMENTE)
                  ValueListenableBuilder<bool>(
                      valueListenable: appModoOscuro,
                      builder: (context, isDark, child) {
                        return ListTile(
                          leading: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: Theme.of(context).primaryColor),
                          title: const Text("Modo Oscuro"),
                          trailing: Switch(
                            value: isDark,
                            activeColor: Theme.of(context).primaryColor,
                            onChanged: (val) async {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setBool('modo_oscuro', val);
                              appModoOscuro.value = val;
                            },
                          ),
                        );
                      }
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- CUENTA Y PRIVACIDAD ---
            const Align(alignment: Alignment.centerLeft, child: Text("CUENTA Y PRIVACIDAD", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5))),
            const SizedBox(height: 10),

            Container(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(15)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: const Text("Ocultar en el Ranking"),
                    trailing: Switch(
                      value: _datosUsuario!["ocultoEnRanking"] == true,
                      activeColor: Theme.of(context).primaryColor,
                      onChanged: (val) {
                        _actualizarPerfilEnBaseDeDatos({"ocultoEnRanking": val});
                      },
                    ),
                  ),
                  const Divider(color: Colors.grey, height: 1, indent: 50, endIndent: 20,),
                  ListTile(
                    leading: const Icon(Icons.notifications_active_outlined),
                    title: const Text("Notificaciones Push"),
                    trailing: Switch(
                        value: _datosUsuario!["notificacionesPush"] == true,
                        activeColor: Theme.of(context).primaryColor,
                        onChanged: (val) {
                          _actualizarPerfilEnBaseDeDatos({"notificacionesPush": val});
                        }
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // --- BOTÓN CERRAR SESIÓN ---
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withValues(alpha:0.1), foregroundColor: Colors.redAccent, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.redAccent))),
                icon: const Icon(Icons.logout),
                label: const Text("CERRAR SESIÓN", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      title: const Text("¿Cerrar sesión?", style: TextStyle(fontWeight: FontWeight.bold)),
                      content: const Text("Se borrarán tus datos locales de sesión y volverás a la pantalla de acceso.", style: TextStyle(color: Colors.grey)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
                        TextButton(onPressed: () { Navigator.pop(context); _cerrarSesion(); }, child: const Text("Salir", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

