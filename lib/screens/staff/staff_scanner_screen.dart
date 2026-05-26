import 'package:flutter/material.dart';

class StaffScannerScreen extends StatefulWidget {
  const StaffScannerScreen({super.key});

  @override
  State<StaffScannerScreen> createState() => _StaffScannerScreenState();
}

class _StaffScannerScreenState extends State<StaffScannerScreen> {
  // Cuando quieras implementar el escáner real en el futuro,
  // aquí irá la lógica del controlador de la cámara.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('ESCÁNER QR', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2.0)),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        centerTitle: true,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.qr_code_scanner,
                size: 80,
                color: Theme.of(context).primaryColor.withValues(alpha: 0.3)
              ),
            ),
            const SizedBox(height: 20),
            const Text(
                'Escáner QR en Puerta',
                style: TextStyle(color: Colors.grey, fontSize: 16)
            ),
            const SizedBox(height: 30),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                ),
                onPressed: () {
                  // Acción futura
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('La cámara se activará en futuras versiones.'))
                  );
                },
                icon: const Icon(Icons.qr_code_scanner, color: Colors.black),
                label: const Text('Activar Escáner', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),

            const SizedBox(height: 20),
            Text(
              'Función disponible próximamente',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}