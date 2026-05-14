import 'package:flutter/material.dart';

// Importamos las pantallas
import '../../services/exercise_service.dart';
import 'coach_dashboard.dart'; // El dashboard de clientes que acabamos de crear
import '../client/routines/routines_list_screen.dart'; // Reciclamos la biblioteca
import '../client/social_screen.dart'; // Reciclamos la comunidad
import '../client/profile_screen.dart'; // Reciclamos el perfil

class CoachNavigation extends StatefulWidget {
  const CoachNavigation({super.key});

  @override
  State<CoachNavigation> createState() => _CoachNavigationState();
}

class _CoachNavigationState extends State<CoachNavigation> {
  int _indiceSeleccionado = 0; // Por defecto arrancamos en Mis Clientes
  @override
  void initState() {
    super.initState();
    ExerciseService.syncExercisesWithServer();
  }
  // La lista de pantallas reales
  final List<Widget> _pantallas = [
    const CoachDashboard(),      // 0. Clientes
    const RoutinesScreen(),      // 1. Biblioteca (Plantillas maestras)
    const SocialScreen(),        // 2. Comunidad (Muro, Ranking)
    const ProfileScreen(),       // 3. Perfil del Coach
  ];

  void _alTocarBoton(int index) {
    setState(() {
      _indiceSeleccionado = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Quitamos el AppBar de aquí porque cada pantalla ya tiene el suyo propio
      body: _pantallas[_indiceSeleccionado],

      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        currentIndex: _indiceSeleccionado,
        onTap: _alTocarBoton,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Clientes'),
          BottomNavigationBarItem(icon: Icon(Icons.library_books), label: 'Biblioteca'),
          BottomNavigationBarItem(icon: Icon(Icons.public), label: 'Comunidad'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Perfil'),
        ],
      ),
    );
  }
}