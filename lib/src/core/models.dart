import 'dart:convert';

class DmsException implements Exception {
  DmsException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.nombreCompleto,
    required this.rol,
    this.area,
  });

  final int id;
  final String username;
  final String nombreCompleto;
  final String rol;
  final String? area;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: _intValue(json['id']),
      username: '${json['username'] ?? ''}',
      nombreCompleto: '${json['nombre_completo'] ?? json['username'] ?? ''}',
      rol: '${json['rol'] ?? ''}',
      area: json['area'] == null ? null : '${json['area']}',
    );
  }

  factory AppUser.fromStoredString(String value) {
    return AppUser.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'nombre_completo': nombreCompleto,
    'rol': rol,
    'area': area,
  };

  String get displayName =>
      nombreCompleto.isNotEmpty ? nombreCompleto : username;

  bool get canCapture => rol == 'Inspector_LQC' || rol == 'Inspector_OQC';

  bool get canRepair =>
      rol == 'Reparador' || rol == 'Supervisor_Produccion' || rol == 'Admin';

  bool get canQuality => rol == 'Supervisor_Calidad' || rol == 'Admin';

  bool get canManageUsers =>
      rol == 'Admin' ||
      rol == 'Supervisor_Calidad' ||
      rol == 'Supervisor_Produccion';

  String get etapaDeteccion {
    if (rol == 'Inspector_LQC') return 'LQC';
    if (rol == 'Inspector_OQC') return 'OQC';
    return '';
  }
}

class DefectItem {
  const DefectItem({
    required this.id,
    required this.fecha,
    required this.linea,
    required this.codigo,
    required this.defecto,
    required this.ubicacion,
    required this.area,
    required this.modelo,
    required this.tipoInspeccion,
    required this.etapaDeteccion,
    required this.status,
    required this.registradoPor,
  });

  final String id;
  final String fecha;
  final String linea;
  final String codigo;
  final String defecto;
  final String ubicacion;
  final String area;
  final String modelo;
  final String tipoInspeccion;
  final String etapaDeteccion;
  final String status;
  final String registradoPor;

  factory DefectItem.fromJson(Map<String, dynamic> json) {
    return DefectItem(
      id: '${json['id'] ?? ''}',
      fecha: '${json['fecha'] ?? ''}',
      linea: '${json['linea'] ?? ''}',
      codigo: '${json['codigo'] ?? ''}',
      defecto: '${json['defecto'] ?? ''}',
      ubicacion: '${json['ubicacion'] ?? ''}',
      area: '${json['area'] ?? ''}',
      modelo: '${json['modelo'] ?? 'N/A'}',
      tipoInspeccion: '${json['tipo_inspeccion'] ?? ''}',
      etapaDeteccion: '${json['etapa_deteccion'] ?? ''}',
      status: '${json['status'] ?? ''}',
      registradoPor: '${json['registrado_por'] ?? ''}',
    );
  }
}

class SelectOption {
  const SelectOption({required this.value, required this.label});

  final String value;
  final String label;

  factory SelectOption.fromJson(Map<String, dynamic> json) {
    return SelectOption(
      value: '${json['value'] ?? ''}',
      label: '${json['label'] ?? json['value'] ?? ''}',
    );
  }
}

int _intValue(Object? value) {
  if (value is int) return value;
  return int.tryParse('$value') ?? 0;
}
