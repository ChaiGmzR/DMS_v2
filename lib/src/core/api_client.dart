import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class ApiClient {
  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? '';

  String baseUrl;
  String? token;

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final data = await _send(
      'POST',
      '/auth/login',
      body: {'username': username, 'password': password},
      includeAuth: false,
    );
    return data as Map<String, dynamic>;
  }

  Future<List<DefectItem>> getDefects({
    String? fechaInicio,
    String? fechaFin,
    String? linea,
    String? codigo,
    String? defecto,
    String? status,
  }) async {
    final data = await _send(
      'GET',
      '/defectos',
      query: {
        'fechaInicio': fechaInicio,
        'fechaFin': fechaFin,
        'linea': linea,
        'codigo': codigo,
        'defecto': defecto,
        'status': status,
      },
    );
    return (data as List)
        .map((item) => DefectItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> createDefect(Map<String, dynamic> payload) async {
    await _send('POST', '/defectos', body: payload);
  }

  Future<String> getModelo(String codigo) async {
    final data =
        await _send(
              'GET',
              '/modelo',
              query: {'codigo': codigo},
              includeAuth: false,
            )
            as Map<String, dynamic>;
    return '${data['modelo'] ?? ''}';
  }

  Future<List<Map<String, dynamic>>> getRepairPending() async {
    return _list('/repairs/pendientes');
  }

  Future<List<Map<String, dynamic>>> getRepairInProcess() async {
    return _list('/repairs/en-proceso');
  }

  Future<String?> startRepair(String defectId) async {
    final data =
        await _send('POST', '/repairs/iniciar', body: {'defect_id': defectId})
            as Map<String, dynamic>;
    return data['repair_id'] == null ? null : '${data['repair_id']}';
  }

  Future<List<Map<String, dynamic>>> getRepairHistory(String defectId) async {
    return _list('/repairs/defecto/$defectId');
  }

  Future<void> finishRepair({
    required String repairId,
    required String accionCorrectiva,
    String? materialesUsados,
    String? observaciones,
  }) async {
    await _send(
      'POST',
      '/repairs/$repairId/finalizar',
      body: {
        'accion_correctiva': accionCorrectiva,
        'materiales_usados': materialesUsados,
        'observaciones': observaciones,
      },
    );
  }

  Future<List<Map<String, dynamic>>> getQaPending() async {
    return _list('/qa/pendientes');
  }

  Future<void> approveQa(String repairId, String observaciones) async {
    await _send(
      'POST',
      '/qa/$repairId/aprobar',
      body: {'observaciones_qa': observaciones},
    );
  }

  Future<void> rejectQa(String repairId, String observaciones) async {
    await _send(
      'POST',
      '/qa/$repairId/rechazar',
      body: {'observaciones_qa': observaciones},
    );
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    final data = await _send('GET', '/usuarios') as Map<String, dynamic>;
    return _asMapList(data['data']);
  }

  Future<List<SelectOption>> getRoles() async {
    final data =
        await _send('GET', '/usuarios/roles/list') as Map<String, dynamic>;
    return _asMapList(data['data']).map(SelectOption.fromJson).toList();
  }

  Future<List<SelectOption>> getAreas() async {
    final data =
        await _send('GET', '/usuarios/areas/list') as Map<String, dynamic>;
    return _asMapList(data['data']).map(SelectOption.fromJson).toList();
  }

  Future<void> createUser(Map<String, dynamic> payload) async {
    await _send('POST', '/usuarios', body: payload);
  }

  Future<void> updateUser(String id, Map<String, dynamic> payload) async {
    await _send('PUT', '/usuarios/$id', body: payload);
  }

  Future<void> changeUserPassword(String id, String password) async {
    await _send(
      'PUT',
      '/usuarios/$id/password',
      body: {'new_password': password},
    );
  }

  Future<void> deactivateUser(String id) async {
    await _send('DELETE', '/usuarios/$id');
  }

  Future<List<Map<String, dynamic>>> _list(String path) async {
    final data = await _send('GET', path);
    return _asMapList(data);
  }

  List<Map<String, dynamic>> _asMapList(Object? value) {
    if (value is! List) return const [];
    return value.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<Object?> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String?>? query,
    bool includeAuth = true,
  }) async {
    if (baseUrl.trim().isEmpty) {
      throw DmsException('Configura la URL de la API');
    }

    final uri = _uri(path, query);
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (includeAuth && token != null) 'Authorization': 'Bearer $token',
    };

    late final http.Response response;
    final encodedBody = body == null ? null : jsonEncode(_cleanBody(body));
    try {
      response = switch (method) {
        'GET' => await http.get(uri, headers: headers),
        'POST' => await http.post(uri, headers: headers, body: encodedBody),
        'PUT' => await http.put(uri, headers: headers, body: encodedBody),
        'DELETE' => await http.delete(uri, headers: headers),
        _ => throw DmsException('Metodo HTTP no soportado: $method'),
      };
    } on http.ClientException catch (error) {
      throw DmsException('No se pudo conectar con la API: ${error.message}');
    }

    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    if (decoded is Map<String, dynamic>) {
      final error =
          decoded['error'] ?? decoded['message'] ?? response.reasonPhrase;
      final details = decoded['details'];
      throw DmsException(details == null ? '$error' : '$error: $details');
    }
    throw DmsException(
      'Error ${response.statusCode}: ${response.reasonPhrase}',
    );
  }

  Uri _uri(String path, Map<String, String?>? query) {
    final root = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final filtered = <String, String>{};
    query?.forEach((key, value) {
      if (value != null && value.trim().isNotEmpty) filtered[key] = value;
    });
    return Uri.parse(
      '$root$path',
    ).replace(queryParameters: filtered.isEmpty ? null : filtered);
  }

  Map<String, dynamic> _cleanBody(Map<String, dynamic> body) {
    return Map.fromEntries(body.entries.where((entry) => entry.value != null));
  }
}
