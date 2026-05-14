import 'package:flutter/material.dart';
import '../client/nutricion_screen.dart';
import 'staff_dashboard.dart';
import 'staff_members_list.dart';
import 'staff_classes_manager.dart';
import 'staff_profile_screen.dart';

class StaffNavigation extends StatefulWidget {
  const StaffNavigation({super.key});
  @override
  State<StaffNavigation> createState() => _StaffNavigationState();
}

class _StaffNavigationState extends State<StaffNavigation> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Lista de pantallas sincronizada con los índices de los botones
    final List<Widget> screens = [
      StaffDashboard(onNavigateToSocios: () => setState(() => _selectedIndex = 1)), // 0
      const StaffMembersList(),     // 1
      const StaffClassesManager(),  // 2
      const NutricionScreen(),      // 3
      const StaffProfileScreen(),   // 4
    ];

    return Scaffold(
      // IndexedStack evita que las pantallas se reinicien al cambiar de pestaña
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        // Configuración visual
        type: BottomNavigationBarType.fixed,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        iconSize: 22,
        showUnselectedLabels: true,

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Socios',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Clases',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome_outlined),
            activeIcon: Icon(Icons.auto_awesome),
            label: 'Nutrición',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}