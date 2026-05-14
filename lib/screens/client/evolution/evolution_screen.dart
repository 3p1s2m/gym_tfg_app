import 'package:flutter/material.dart';
import 'tab_avatar.dart';
import 'tab_historial.dart';
import 'tab_logros.dart';
import 'tab_frecuencia.dart'; // 👈 IMPORTACIÓN NUEVA

class EvolutionScreen extends StatelessWidget {
  const EvolutionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4, // 👈 AHORA SON 4 PESTAÑAS
      initialIndex: 0,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('ANALÍTICA', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
          elevation: 0,
          centerTitle: true,
          bottom: TabBar(
            indicatorColor: Theme.of(context).primaryColor,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            isScrollable: false,
            labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            tabs: const [
              Tab(icon: Icon(Icons.accessibility_new), text: "Medidas"),
              Tab(icon: Icon(Icons.local_fire_department), text: "Frecuencia"), // 👈 NUEVA
              Tab(icon: Icon(Icons.calendar_month), text: "Historial"),
              Tab(icon: Icon(Icons.diamond_outlined), text: "Logros"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            TabAvatar(),
            TabFrecuencia(), // 👈 NUEVA PESTAÑA POSICIONADA AQUÍ
            TabHistorial(),
            TabLogros(),
          ],
        ),
      ),
    );
  }
}