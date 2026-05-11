import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/models.dart';

class AppState extends ChangeNotifier {
  AppState(this.api);

  static const _tokenKey = 'dms_token';
  static const _userKey = 'dms_user';
  static const _apiKey = 'dms_api_base_url';

  final ApiClient api;

  AppUser? user;
  String? token;
  String apiBaseUrl = defaultApiBaseUrl();
  bool isLoading = true;

  bool get isAuthenticated => token != null && user != null;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    apiBaseUrl = prefs.getString(_apiKey) ?? defaultApiBaseUrl();
    token = prefs.getString(_tokenKey);
    final storedUser = prefs.getString(_userKey);
    user = storedUser == null ? null : AppUser.fromStoredString(storedUser);
    api
      ..baseUrl = apiBaseUrl
      ..token = token;
    isLoading = false;
    notifyListeners();
  }

  Future<void> login({
    required String username,
    required String password,
    required String apiUrl,
  }) async {
    apiBaseUrl = _normalizeApiUrl(apiUrl);
    api.baseUrl = apiBaseUrl;

    final data = await api.login(username: username, password: password);
    token = '${data['token']}';
    user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
    api.token = token;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKey, apiBaseUrl);
    await prefs.setString(_tokenKey, token!);
    await prefs.setString(_userKey, jsonEncode(user!.toJson()));
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

  Future<void> saveApiBaseUrl(String value) async {
    apiBaseUrl = _normalizeApiUrl(value);
    api.baseUrl = apiBaseUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKey, apiBaseUrl);
    notifyListeners();
  }

  static String defaultApiBaseUrl() {
    return 'http://192.168.1.10:5000/api';
  }

  String _normalizeApiUrl(String value) {
    var clean = value.trim();
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    return clean;
  }
}
