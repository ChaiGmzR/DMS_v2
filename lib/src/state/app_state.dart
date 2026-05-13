import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/models.dart';

class AppState extends ChangeNotifier {
  AppState(this.api);

  static const _tokenKey = 'dms_token';
  static const _userKey = 'dms_user';
  static const _legacyApiKey = 'dms_api_base_url';
  static const _fixedApiBaseUrl = 'http://192.168.1.10:5000/api';

  final ApiClient api;

  AppUser? user;
  String? token;
  String apiBaseUrl = defaultApiBaseUrl();
  bool isLoading = true;

  bool get isAuthenticated => token != null && user != null;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    apiBaseUrl = defaultApiBaseUrl();
    await prefs.remove(_legacyApiKey);
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    token = null;
    user = null;
    api
      ..baseUrl = apiBaseUrl
      ..token = null;
    isLoading = false;
    notifyListeners();
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    apiBaseUrl = defaultApiBaseUrl();
    api.baseUrl = apiBaseUrl;

    final data = await api.login(username: username, password: password);
    token = '${data['token']}';
    user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
    api.token = token;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyApiKey);
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    notifyListeners();
  }

  Future<void> logout() async {
    token = null;
    user = null;
    api.token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    notifyListeners();
  }

  static String defaultApiBaseUrl() {
    return _fixedApiBaseUrl;
  }
}
