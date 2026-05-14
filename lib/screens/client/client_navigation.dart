import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'evolution/evolution_screen.dart';
import 'nutricion_screen.dart';
import 'routines/routines_list_screen.dart';
import 'profile_screen.dart';
import 'social_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _indiceSeleccionado = 0;


  final List<Widget> _pantallas = [
    const HomeScreen(),
    const EvolutionScreen(),
    const RoutinesScreen(),
    const NutricionScreen(),
    const SocialScreen(),
    const ProfileScreen(),
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
      body: _pantallas[_indiceSeleccionado],

      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        currentIndex: _indiceSeleccionado,
        onTap: _alTocarBoton,


        selectedFontSize: 11,
        unselectedFontSize: 10,
        iconSize: 24,
        showUnselectedLabels: true,

        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.person_pin_outlined),
              activeIcon: Icon(Icons.person_pin),
              label: 'Físico'
          ),
          BottomNavigationBarItem(
              icon: Icon(Icons.auto_graph_outlined),
              activeIcon: Icon(Icons.auto_graph),
              label: 'Evolución'
          ),
          BottomNavigationBarItem(
              icon: Icon(Icons.fitness_center_outlined),
              activeIcon: Icon(Icons.fitness_center),
              label: 'Rutinas'
          ),

          BottomNavigationBarItem(
              icon: Icon(Icons.restaurant_outlined),
              activeIcon: Icon(Icons.restaurant),
              label: 'Nutrición'
          ),
          // ----------------------------
          BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Social'
          ),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Perfil'
          ),
        ],
      ),
    );
  }
}