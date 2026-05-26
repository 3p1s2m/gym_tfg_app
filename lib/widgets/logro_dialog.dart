import 'package:flutter/material.dart';

// Función PÚBLICA (Sin el guion bajo) para poder usarla en cualquier pantalla
Color obtenerColorGlow(String dificultad) {
  switch (dificultad) {
    case "BRONCE": return Colors.brown.withValues(alpha:0.6);
    case "PLATA": return Colors.grey.withValues(alpha:0.6);
    case "ORO": return Colors.amber.withValues(alpha:0.6);
    case "DIAMANTE": return Colors.lightBlueAccent.withValues(alpha:0.8);
    case "ELITE": return Colors.purpleAccent.withValues(alpha:0.9);
    default: return Colors.cyanAccent.withValues(alpha:0.5);
  }
}

class DialogoCelebracionLogro extends StatefulWidget {
  final Map<String, dynamic> logro;
  final Color colorBrillo;

  const DialogoCelebracionLogro({Key? key, required this.logro, required this.colorBrillo}) : super(key: key);

  @override
  State<DialogoCelebracionLogro> createState() => _DialogoCelebracionLogroState();
}

class _DialogoCelebracionLogroState extends State<DialogoCelebracionLogro> {
  bool _revelado = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _revelado = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    String rutaImagen = "assets/images/${widget.logro['iconoUrl']}";

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(25.0),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _revelado ? widget.colorBrillo.withValues(alpha:0.5) : Colors.transparent, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("¡NUEVO LOGRO!", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 30),
            SizedBox(
              height: 180,
              width: 180,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 800),
                switchInCurve: Curves.easeOutBack,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: _revelado ? _buildGemaColor(rutaImagen) : _buildGemaGris(rutaImagen),
              ),
            ),
            const SizedBox(height: 30),
            Semantics(
              liveRegion: true,
              label: _revelado ? 'Logro desbloqueado: ${widget.logro["nombre"] ?? ""}' : '',
              child: AnimatedOpacity(
                opacity: _revelado ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 500),
                child: Column(
                  children: [
                    Text(widget.logro["nombre"], textAlign: TextAlign.center, style: TextStyle(color: widget.colorBrillo, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text(widget.logro["descripcion"], textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 15)),
                    const SizedBox(height: 25),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: widget.colorBrillo.withValues(alpha:0.2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () => Navigator.pop(context),
                      child: Text("Reclamar", style: TextStyle(color: widget.colorBrillo, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildGemaGris(String ruta) {
    return ExcludeSemantics(
      child: ColorFiltered(
        key: const ValueKey(1),
        colorFilter: const ColorFilter.matrix([0.2126, 0.7152, 0.0722, 0, 0, 0.2126, 0.7152, 0.0722, 0, 0, 0.2126, 0.7152, 0.0722, 0, 0, 0, 0, 0, 0.4, 0]),
        child: Transform.scale(scale: 1.5, child: Image.asset(ruta)),
      ),
    );
  }

  Widget _buildGemaColor(String ruta) {
    return Container(
      key: const ValueKey(2),
      decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: widget.colorBrillo, blurRadius: 40, spreadRadius: 10)]),
      child: Transform.scale(scale: 1.8, child: Image.asset(ruta, semanticLabel: 'Gema ${widget.logro["dificultad"] ?? ""}')),
    );
  }
}