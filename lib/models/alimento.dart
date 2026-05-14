class Alimento {
  final String nombre;
  final double kcal;
  final double proteinas;
  final double carbohidratos;
  final double grasas;

  Alimento({
    required this.nombre,
    required this.kcal,
    required this.proteinas,
    required this.carbohidratos,
    required this.grasas,
  });

  factory Alimento.fromJson(Map<String, dynamic> json) {

    final nutrients = json['nutrients'] ?? {};

    return Alimento(
      nombre: json['label'] ?? 'Alimento desconocido',
      kcal: (nutrients['ENERC_KCAL'] ?? 0).toDouble(),
      proteinas: (nutrients['PROCNT'] ?? 0).toDouble(),
      carbohidratos: (nutrients['CHOCDF'] ?? 0).toDouble(),
      grasas: (nutrients['FAT'] ?? 0).toDouble(),
    );
  }
}