import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_constants.dart';
import '../client/client_navigation.dart';
import '../coach/coach_navigation.dart';
import '../staff/staff_navigation.dart';
import '../admin/admin_navigation.dart';
import '../../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  // 👇 NUEVA VARIABLE PARA CONTROLAR SI SE VE LA CONTRASEÑA
  bool _ocultarPassword = true;

  Future<void> _iniciarSesion() async {
    setState(() => _isLoading = true);
    final url = Uri.parse(ApiConstants.login);

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _emailController.text, 'password': _passwordController.text}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String tokenDelBackend = data['token'];
        final String rolDelBackend = data['rol'];
        final String idDelBackend = data['idUsuario'];
        final bool tieneEntrenadorBackend = data['tieneEntrenador'] == 'true';
        final String generoBackend = data['genero'] ?? 'hombre';

        final prefs = await SharedPreferences.getInstance();

        await prefs.remove('jwt_token');
        await prefs.remove('user_role');
        await prefs.remove('user_id');
        await prefs.remove('tiene_entrenador');

        await prefs.setString('jwt_token', tokenDelBackend);
        await prefs.setString('user_role', rolDelBackend);
        await prefs.setString('user_id', idDelBackend);
        await prefs.setBool('tiene_entrenador', tieneEntrenadorBackend);
        await prefs.setString('genero', generoBackend);

        appGenero.value = generoBackend;

        if (mounted) {
          if (rolDelBackend == 'admin') {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminNavigation()));
          } else if (rolDelBackend == 'staff') {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const StaffNavigation()));
          } else if (rolDelBackend == 'entrenador') {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CoachNavigation()));
          } else if (rolDelBackend == 'cliente') {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainNavigation()));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rol no soportado aún.')));
          }
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Correo o contraseña incorrectos'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo conectar con el servidor.'), backgroundColor: Colors.orange));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarRecuperarPassword() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text("Recuperar contraseña"),
          content: const Text("Por motivos de seguridad, las cuentas son gestionadas exclusivamente por el gimnasio.\n\nPor favor, acude a recepción o contacta con el administrador para generar una nueva contraseña.", style: TextStyle(color: Colors.grey)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Entendido", style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold))
            )
          ],
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.fitness_center, size: 80, color: Theme.of(context).primaryColor),
              const SizedBox(height: 20),
              const Text('SYMMETRY', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
              const SizedBox(height: 50),

              TextField(
                controller: _emailController,
                decoration: InputDecoration(hintText: 'Correo electrónico', hintStyle: const TextStyle(color: Colors.grey), filled: true, fillColor: Theme.of(context).colorScheme.surface, prefixIcon: const Icon(Icons.email, color: Colors.grey), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)),
              ),
              const SizedBox(height: 20),

              // 👇 CAMPO DE CONTRASEÑA CON EL OJITO
              TextField(
                controller: _passwordController,
                obscureText: _ocultarPassword, // 👈 Controlado por la variable
                decoration: InputDecoration(
                    hintText: 'Contraseña',
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    prefixIcon: const Icon(Icons.lock, color: Colors.grey),

                    // 👇 EL BOTÓN DEL OJITO
                    suffixIcon: IconButton(
                      icon: Icon(_ocultarPassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                      onPressed: () {
                        setState(() {
                          _ocultarPassword = !_ocultarPassword;
                        });
                      },
                    ),

                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)
                ),
              ),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _mostrarRecuperarPassword,
                  child: const Text("¿Has olvidado tu contraseña?", style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity, height: 55,
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))
                    : ElevatedButton(
                  onPressed: _iniciarSesion,
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 5),
                  child: const Text('INICIAR SESIÓN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}