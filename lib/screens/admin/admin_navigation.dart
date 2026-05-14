import 'package:flutter/material.dart';
import 'admin_dashboard.dart';
import 'admin_users_manager.dart';
import 'admin_achievements_manager.dart';
import 'admin_settings.dart';

class AdminNavigation extends StatefulWidget {
  const AdminNavigation({super.key});

  @override
  State<AdminNavigation> createState() => _AdminNavigationState();
}

class _AdminNavigationState extends State<AdminNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const AdminDashboard(),
    const AdminUsersManager(),
    const AdminAchievementsManager(),
    const AdminSettings(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: 'Usuarios'),
          BottomNavigationBarItem(icon: Icon(Icons.emoji_events), label: 'Logros'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Config'),
        ],
      ),
    );
  }
}

