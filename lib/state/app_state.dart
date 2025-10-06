import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/http_api.dart';

class AppState extends ChangeNotifier {
  final HttpApi api;
  final SharedPreferences prefs;
  bool _initialized = false;
  String? _token;
  String? _email;
  String? get token => _token;

  AppState({required this.api, required this.prefs}) {
    _bootstrap();
  }

  bool get initialized => _initialized;
  bool get isAuthenticated => _token != null;
  String? get email => _email;

  Future<void> _bootstrap() async {
    _token = prefs.getString('auth_token');
    _email = prefs.getString('auth_email');
    api.authToken = _token;
    _initialized = true;
    notifyListeners();
  }

  Future<String?> login(
      {required String email, required String password}) async {
    final res = await api.login(email: email, password: password);
    if (res.success) {
      _token = res.token;
      _email = email;
      api.authToken = _token;
      await prefs.setString('auth_token', _token!);
      await prefs.setString('auth_email', _email!);
      notifyListeners();
      return null;
    } else {
      return res.errorMessage ?? 'Échec de connexion';
    }
  }

  Future<String?> signup(
      {required String email, required String password}) async {
    final res = await api.signup(email: email, password: password);
    if (res.success) {
      _token = res.token;
      _email = email;
      api.authToken = _token;
      await prefs.setString('auth_token', _token!);
      await prefs.setString('auth_email', _email!);
      notifyListeners();
      return null;
    } else {
      return res.errorMessage ?? 'Échec d’inscription';
    }
  }

  Future<void> logout() async {
    _token = null;
    _email = null;
    api.authToken = null;
    await prefs.remove('auth_token');
    await prefs.remove('auth_email');
    notifyListeners();
  }
}
