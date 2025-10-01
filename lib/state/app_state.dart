import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/mock_api.dart';

class AppState extends ChangeNotifier {
  final MockApi api;
  final SharedPreferences prefs;
  bool _initialized = false;
  String? _token;
  String? _email;

  AppState({required this.api, required this.prefs}) {
    _bootstrap();
  }

  bool get initialized => _initialized;
  bool get isAuthenticated => _token != null;
  String? get email => _email;

  Future<void> _bootstrap() async {
    _token = prefs.getString('auth_token');
    _email = prefs.getString('auth_email');
    _initialized = true;
    notifyListeners();
  }

  Future<String?> login(
      {required String email, required String password}) async {
    final result = await api.login(email: email, password: password);
    if (result.success) {
      _token = result.token;
      _email = email;
      await prefs.setString('auth_token', _token!);
      await prefs.setString('auth_email', _email!);
      notifyListeners();
      return null; // pas d'erreur
    } else {
      return result.errorMessage ?? 'Échec de connexion';
    }
  }

  Future<void> logout() async {
    _token = null;
    _email = null;
    await prefs.remove('auth_token');
    await prefs.remove('auth_email');
    notifyListeners();
  }
}
