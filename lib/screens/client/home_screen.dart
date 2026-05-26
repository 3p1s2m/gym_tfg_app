import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/exercise_service.dart';
import '../../services/api_constants.dart';
import '../../main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _esFrente = true;

  // Datos de la Evaluación IA
  String? _rangoPectoral;
  String? _rangoDorsal;
  String? _rangoPiernas;
  String? _rangoBrazos;

  @override
  void initState() {
    super.initState();
    _cargarProgresoUsuario();
    ExerciseService.syncExercisesWithServer();
  }

  // --- 1. CARGA DE DATOS ---
  Future<void> _cargarProgresoUsuario() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('jwt_token');
      if (token == null) { _limpiarMusculos(); return; }

      final response = await http.get(Uri.parse(ApiConstants.progresoIA), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'});

      if (response.statusCode == 200) {
        final Map<String, dynamic> datos = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _rangoPectoral = datos['pectoral'];
            _rangoDorsal = datos['dorsal'];
            _rangoPiernas = datos['piernas'];
            _rangoBrazos = datos['brazos'];

            if (datos['genero'] != null) {
              String gen = datos['genero'].toString().toLowerCase();
              appGenero.value = gen;
              prefs.setString('genero', gen);
            }
          });
        }
      } else { _limpiarMusculos(); }
    } catch (e) { _limpiarMusculos(); }
  }

  void _limpiarMusculos() {
    if (mounted) {
      setState(() { _rangoPectoral = null; _rangoDorsal = null; _rangoPiernas = null; _rangoBrazos = null; });
    }
  }

  // --- 2. LÓGICA DE COLORES DE LA IA ---
  Color _getColorDeGema(String? rango) {
    switch (rango) {
      case "elite": return const Color.fromRGBO(113, 27, 255, 1.0);
      case "diamante": return const Color.fromRGBO(25, 221, 246, 1.0);
      case "oro": return const Color.fromRGBO(255, 200, 60, 1.0);
      case "plata": return const Color.fromRGBO(217, 220, 222, 1.0);
      case "bronce": return const Color.fromRGBO(134, 87, 57, 1.0);
      default: return Colors.transparent;
    }
  }

  // 👇 FUNCIÓN SIMPLE: Lee de 'assets/images/' (las máscaras grandes originales)
  List<Widget> _buildCapaIA(String musculo, String? rangoIA, String generoVisualActual) {
    if (rangoIA == null) return [];

    Color colorPintar = _getColorDeGema(rangoIA);

    if (colorPintar != Colors.transparent) {
      return [
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(colorPintar.withValues(alpha: 0.85), BlendMode.srcIn),
              child: Image.asset(
                // OJO AQUÍ: Ya no busca en partes/, busca en la carpeta principal
                'assets/images/mask_${generoVisualActual}_${_esFrente ? "frente" : "espalda"}_$musculo.png',
                key: ValueKey("mask_ia_${generoVisualActual}_${_esFrente}_$musculo"),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
          ),
          ),
        )
      ];
    }
    return [];
  }

  // --- ESCÁNER DE CÁMARA (IA) ---
  void _mostrarOpcionesImagen(String nombreMusculo) {
    showModalBottomSheet(
      context: context, backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              Padding(padding: const EdgeInsets.all(16.0), child: Text('¿De dónde quieres sacar la foto?', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold))),
              ListTile(leading: Icon(Icons.photo_library, color: Theme.of(context).primaryColor), title: const Text('Elegir de la Galería'), onTap: () { Navigator.pop(context); _evaluarMusculo(nombreMusculo, ImageSource.gallery); }),
              ListTile(leading: Icon(Icons.camera_alt, color: Theme.of(context).primaryColor), title: const Text('Hacer Foto Ahora'), onTap: () { Navigator.pop(context); _evaluarMusculo(nombreMusculo, ImageSource.camera); }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _evaluarMusculo(String nombreMusculo, ImageSource origenElegido) async {
    final picker = ImagePicker();
    final fotoCapturada = await picker.pickImage(source: origenElegido, imageQuality: 80);
    if (fotoCapturada == null) return;

    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⏳ Enviando a Gemini AI...'), backgroundColor: Theme.of(context).primaryColor));

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) throw Exception("No hay sesión");

      // 👇 Petición ultra limpia: Solo mandamos la foto. Java ya sabe quiénes somos por el token.
      var request = http.MultipartRequest('POST', Uri.parse(ApiConstants.procesarIA));
      request.headers.addAll({'Authorization': 'Bearer $token'});
      request.files.add(await http.MultipartFile.fromPath('foto', fotoCapturada.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        _cargarProgresoUsuario();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ ¡Gemini ha evaluado tu físico!'), backgroundColor: Colors.green));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error en IA: ${response.statusCode}'), backgroundColor: Colors.red));
      }
    } catch (e) { print("Error: $e"); }
  }
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appGenero,
      builder: (context, generoActual, child) {
        String generoVisual = (generoActual.isEmpty || generoActual == "otro") ? "hombre" : generoActual;
        String rutaCuerpoBase = 'assets/images/body_${generoVisual}_${_esFrente ? "frente" : "espalda"}.png';

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(title: const Text('SYMMETRY', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2.0)), backgroundColor: Theme.of(context).appBarTheme.backgroundColor, foregroundColor: Theme.of(context).appBarTheme.foregroundColor, elevation: 0, centerTitle: true),
          body: FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 25),
                color: const Color(0xFF000000).withValues(alpha: 0.8),
                child: _buildLeyendaGemas(),
              ),

              const SizedBox(height: 10),
              Text(_esFrente ? "VISTA FRONTAL" : "VISTA TRASERA", style: const TextStyle(color: Colors.grey, letterSpacing: 3.0, fontSize: 12)),

              Expanded(
                child: Center(
                  child: SizedBox(
                    width: 300, height: 520,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(child: Semantics(label: _esFrente ? "Vista frontal del cuerpo, toca para ver espalda" : "Vista trasera del cuerpo, toca para ver frente", child: GestureDetector(onTap: () => setState(() => _esFrente = !_esFrente), child: Image.asset(rutaCuerpoBase, fit: BoxFit.contain)))),
                        if (_esFrente) ...[
                          // 👇 Usamos los nombres simples de las imágenes antiguas:
                          ..._buildCapaIA('pectoral', _rangoPectoral, generoVisual),
                          ..._buildCapaIA('brazos', _rangoBrazos, generoVisual),
                          ..._buildCapaIA('piernas', _rangoPiernas, generoVisual),

                          _buildHitboxInvisible('Pectoral', 100, 90, 120, 60),
                          _buildHitboxInvisible('Piernas', 260, 90, 120, 130),
                          _buildHitboxInvisible('Brazos', 120, 30, 50, 130),
                          _buildHitboxInvisible('Brazos', 120, 220, 50, 130),
                        ] else ...[
                          // 👇 Nombres simples para la espalda:
                          ..._buildCapaIA('dorsal', _rangoDorsal, generoVisual), // O 'dorsal' si tu imagen se llama dorsal
                          ..._buildCapaIA('brazos', _rangoBrazos, generoVisual),
                          ..._buildCapaIA('piernas', _rangoPiernas, generoVisual),

                          _buildHitboxInvisible('Dorsal', 90, 80, 140, 120),
                          _buildHitboxInvisible('Piernas', 260, 90, 120, 130),
                          _buildHitboxInvisible('Brazos', 120, 30, 50, 130),
                          _buildHitboxInvisible('Brazos', 120, 220, 50, 130),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
              const Padding(padding: EdgeInsets.only(bottom: 20.0), child: Text("Toca un músculo para evaluar. Toca el fondo para girar.", style: TextStyle(color: Colors.grey, fontSize: 11))),
            ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLeyendaGemas() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildGemaMini('assets/images/gema_bronce.png', 'Gema Bronce'),
        _buildGemaMini('assets/images/gema_plata.png', 'Gema Plata'),
        _buildGemaMini('assets/images/gema_oro.png', 'Gema Oro'),
        _buildGemaMini('assets/images/gema_diamante.png', 'Gema Diamante'),
        _buildGemaMini('assets/images/gema_elite.png', 'Gema Elite'),
      ],
    );
  }

  Widget _buildGemaMini(String ruta, String semanticsLabel) {
    return Transform.scale(scale: 2, child: Image.asset(ruta, height: 40, fit: BoxFit.contain, semanticLabel: semanticsLabel, errorBuilder: (c,e,s) => const SizedBox()));
  }

  Widget _buildHitboxInvisible(String nombre, double top, double left, double width, double height) {
    return Positioned(top: top, left: left, child: Semantics(label: "$nombre, toca para evaluar músculo", button: true, child: GestureDetector(onTap: () => _mostrarOpcionesImagen(nombre), child: Container(width: width, height: height, color: Colors.transparent))));
  }
}