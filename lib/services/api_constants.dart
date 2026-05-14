class ApiConstants {
  // 1. LA URL MAESTRA (Si cambias de IP, solo lo cambias aquí una vez)
  static const String baseUrl = 'http://10.0.2.2:8080/api';

  // 2. RUTAS DE USUARIOS
  static const String login = '$baseUrl/usuarios/login';

  // 3. RUTAS DE ENTRENAMIENTO Y RUTINAS
  static const String getEjercicios = '$baseUrl/ejercicios';
  static const String rutinas = '$baseUrl/rutinas';
  static const String guardarEntrenamiento = '$baseUrl/entrenamientos/guardar';
  static const String resumenEntrenamientos = '$baseUrl/entrenamientos/resumen';
  // 👇 AÑADE ESTA LÍNEA
  static const String mapaCalor = '$baseUrl/entrenamientos/mapa-calor';
  static const String guardarObjetivos = '$baseUrl/entrenamientos/objetivos';
  // Como el ID del ejercicio cambia, hacemos una pequeña función
  static String fantasmaEntrenamiento(int idEjercicio) => '$baseUrl/entrenamientos/anterior/$idEjercicio';

  // 4. RUTAS DE EVOLUCIÓN (IA Y MEDIDAS)
  static const String progresoIA = '$baseUrl/evaluaciones/progreso';
  static const String procesarIA = '$baseUrl/evaluaciones/procesar';
  static const String medidas = '$baseUrl/medidas';

  // 5. RUTAS DE LOGROS
  static const String catalogoLogros = '$baseUrl/logros/catalogo';
  static const String misLogros = '$baseUrl/logros/mis-logros';

  // 6. RUTAS SOCIALES Y CHAT
  static const String muroSocial = '$baseUrl/social';
  static const String clasesGrupales = '$baseUrl/clases';

  static String historialChat(int idCoach) => '$baseUrl/chat/historial/$idCoach';
  // 👇 IP mágica de Android Studio para WebSockets
  static String wsChat(int miId) => 'ws://10.0.2.2:8080/ws/chat?userId=$miId';

  static String guardarObjetivosCoach(int id) => '$baseUrl/entrenamientos/coach/cliente/$id/objetivos';

  // 7. RUTAS DE STAFF (TRABAJADORES/RECEPCIONISTAS)
  static const String staffClientes = '$baseUrl/usuarios/staff/clientes';
  static String staffActualizarEstadoPago(int idUsuario) => '$baseUrl/usuarios/staff/clientes/$idUsuario/estado-pago';
  // 8. RUTAS DE ADMIN
  static String staffAsignarCoach(int idCliente, int idCoach) => '$baseUrl/usuarios/staff/clientes/$idCliente/asignar-coach/$idCoach';
  static const String staffCrearClase = '$baseUrl/clases/staff/crear';
  static String staffEliminarClase(int idClase) => '$baseUrl/clases/staff/$idClase/eliminar';
  static const String staffCrearCliente = '$baseUrl/usuarios/staff/clientes';
  static String staffCambiarPassword(int idUsuario) => '$baseUrl/usuarios/staff/clientes/$idUsuario/password';
  // 8. RUTAS DE ADMIN
  static const String adminDashboardStats = '$baseUrl/usuarios/admin/dashboard/stats'; // 👈 NUEVO
  static const String adminUsuarios = '$baseUrl/usuarios/admin/usuarios';
  static String adminEliminarUsuario(int idUsuario) => '$baseUrl/usuarios/admin/usuarios/$idUsuario';

  // 9. RUTAS DE LOGROS (REALES)
  static const String logrosCatalogo = '$baseUrl/logros'; // 👈 NUEVO
  static const String adminCrearLogro = '$baseUrl/logros/admin/crear'; // 👈 NUEVO
}