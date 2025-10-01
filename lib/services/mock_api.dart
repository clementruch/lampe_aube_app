class LoginResult {
  final bool success;
  final String? token;
  final String? errorMessage;
  LoginResult({required this.success, this.token, this.errorMessage});
}

/// MockApi simule le backend pour le MVP
class MockApi {
// Email/mot de passe d'exemple (tu peux changer)
  static const _demoUsers = {
    'demo@aube.app': 'azerty123',
    'clement@aube.app': 'password',
  };

  Future<LoginResult> login(
      {required String email, required String password}) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final ok = _demoUsers[email] == password;
    if (ok) {
// Un faux token JWT
      return LoginResult(
          success: true,
          token: 'fake.jwt.token.${DateTime.now().millisecondsSinceEpoch}');
    }
// Accepte aussi n'importe quel email avec mot de passe >= 6 caractères (pour dev rapide)
    if (password.length >= 6) {
      return LoginResult(
          success: true,
          token: 'dev.jwt.token.${DateTime.now().millisecondsSinceEpoch}');
    }
    return LoginResult(success: false, errorMessage: 'Identifiants invalides');
  }
}
