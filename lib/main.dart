import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/auth/login_screen.dart';
import 'screens/client/client_navigation.dart';
import 'screens/coach/coach_navigation.dart';
// 👇 AÑADE ESTAS DOS IMPORTACIONES:
import 'screens/staff/staff_navigation.dart';
import 'screens/admin/admin_navigation.dart';

// 👇 LAS TRES VARIABLES GLOBALES QUE ACTUALIZAN LA APP AL VUELO
final ValueNotifier<Color> appColorTema = ValueNotifier<Color>(Colors.cyanAccent);
final ValueNotifier<bool> appModoOscuro = ValueNotifier<bool>(true);
final ValueNotifier<String> appGenero = ValueNotifier<String>("hombre");
final ValueNotifier<double> appTamanoFuente = ValueNotifier<double>(1.0);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  int colorValue = prefs.getInt('tema_color') ?? Colors.cyanAccent.value;
  bool isDark = prefs.getBool('modo_oscuro') ?? true;
  String generoGuardado = prefs.getString('genero') ?? "hombre";
  double tamanoFuente = prefs.getDouble('tamano_fuente') ?? 1.0;

  appColorTema.value = Color(colorValue);
  appModoOscuro.value = isDark;
  appGenero.value = generoGuardado;
  appTamanoFuente.value = tamanoFuente;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: appColorTema,
      builder: (context, colorActual, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: appModoOscuro,
          builder: (context, isDark, child) {

            return MaterialApp(
              title: 'Symmetry',
              debugShowCheckedModeBanner: false,
              themeMode: isDark ? ThemeMode.dark : ThemeMode.light,

              // ☀️ TEMA CLARO
              theme: ThemeData.light().copyWith(
                primaryColor: colorActual,
                scaffoldBackgroundColor: const Color(0xFFF5F5F5),
                colorScheme: ColorScheme.light(
                  primary: colorActual,
                  secondary: colorActual,
                  surface: Colors.white,
                ),
                indicatorColor: colorActual,
                appBarTheme: const AppBarTheme(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 0,
                ),
              ),

              // 🌙 TEMA OSCURO
              darkTheme: ThemeData.dark().copyWith(
                primaryColor: colorActual,
                scaffoldBackgroundColor: const Color(0xFF121212),
                colorScheme: ColorScheme.dark(
                  primary: colorActual,
                  secondary: colorActual,
                  surface: const Color(0xFF1C1C1E),
                ),
                indicatorColor: colorActual,
                appBarTheme: const AppBarTheme(
                  backgroundColor: Color(0xFF121212),
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
              ),

              home: const SplashScreen(),
              builder: (context, child) {
                return ValueListenableBuilder<double>(
                  valueListenable: appTamanoFuente,
                  builder: (context, escala, _) {
                    return MediaQuery(
                      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(escala)),
                      child: child!,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

// --- EL PORTERO (SPLASH SCREEN) ---
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _comprobarSesion();
  }

  Future<void> _comprobarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');
    final String? rol = prefs.getString('user_role');

    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    if (token != null && rol != null) {
      switch (rol) {
        case 'cliente':
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainNavigation()));
          break;
        case 'entrenador':
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CoachNavigation()));
          break;
        case 'admin':
        // 👇 ¡ARREGLADO! Ahora te manda a la pantalla real, no a DashboardAdmin
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminNavigation()));
          break;
        case 'staff':
        // 👇 ¡ARREGLADO! Ahora te manda a la pantalla real de Staff
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const StaffNavigation()));
          break;
        default:
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('SYMMETRY', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4.0)),
            const SizedBox(height: 20),
            CircularProgressIndicator(color: appColorTema.value),
          ],
        ),
      ),
    );
  }
}