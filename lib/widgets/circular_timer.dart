import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';

class CircularTimerWidget extends StatefulWidget {
  final int segundosTotales;
  const CircularTimerWidget({super.key, required this.segundosTotales});

  @override
  State<CircularTimerWidget> createState() => _CircularTimerWidgetState();
}

class _CircularTimerWidgetState extends State<CircularTimerWidget> {
  Timer? _timer;
  late int _segundosRestantes;
  late int _maxSegundos;
  bool _estaCorriendo = false;

  @override
  void initState() {
    super.initState();
    _maxSegundos = widget.segundosTotales;
    _segundosRestantes = _maxSegundos;
  }

  void _iniciarPausar() {
    if (_estaCorriendo) {
      _timer?.cancel();
      setState(() => _estaCorriendo = false);
    } else {
      if (_segundosRestantes == 0) _segundosRestantes = _maxSegundos;
      setState(() => _estaCorriendo = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_segundosRestantes > 0) {
          setState(() => _segundosRestantes--);
        } else {
          timer.cancel();
          setState(() => _estaCorriendo = false);
          HapticFeedback.vibrate();
          HapticFeedback.heavyImpact();
        }
      });
    }
  }

  void _editarTiempo() {
    int minsActuales = _maxSegundos ~/ 60;
    int segsActuales = _maxSegundos % 60;
    TextEditingController minController = TextEditingController(text: minsActuales.toString());
    TextEditingController segController = TextEditingController(text: segsActuales.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text("Tiempo de Descanso", style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: TextField(
                controller: minController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.cyanAccent, fontSize: 24, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(labelText: "Min", labelStyle: TextStyle(color: Colors.grey, fontSize: 12), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white12)), focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent))),
              ),
            ),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 10.0), child: Text(":", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
            Expanded(
              child: TextField(
                controller: segController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.cyanAccent, fontSize: 24, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(labelText: "Seg", labelStyle: TextStyle(color: Colors.grey, fontSize: 12), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white12)), focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          TextButton(
              onPressed: () {
                setState(() {
                  int minInput = int.tryParse(minController.text) ?? 0;
                  int segInput = int.tryParse(segController.text) ?? 0;
                  _maxSegundos = (minInput * 60) + segInput;
                  if (_maxSegundos <= 0) _maxSegundos = 1;
                  _segundosRestantes = _maxSegundos;
                  _estaCorriendo = false;
                  _timer?.cancel();
                });
                Navigator.pop(context);
              },
              child: const Text("Guardar", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double progreso = _maxSegundos > 0 ? _segundosRestantes / _maxSegundos : 0;
    String tiempoStr = "${(_segundosRestantes ~/ 60)}:${(_segundosRestantes % 60).toString().padLeft(2, '0')}";

    return GestureDetector(
      onTap: _iniciarPausar,
      onLongPress: _editarTiempo,
      child: Center(
        child: SizedBox(
          width: 36, height: 36,
          child: Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: progreso, strokeWidth: 3, backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(_estaCorriendo ? Theme.of(context).primaryColor : Colors.grey),
              ),
              Center(child: Text(tiempoStr, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 10, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
      ),
    );
  }
}