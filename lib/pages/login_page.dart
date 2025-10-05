import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'devices_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController(text: 'demo@aube.app');
  final _passCtrl = TextEditingController(text: 'demo');
  bool _loading = false;

  Future<void> _do(bool signup) async {
    if (!_formKey.currentState!.validate()) return;
    final app = context.read<AppState>();
    setState(() => _loading = true);
    try {
      final err = signup
          ? await app.signup(
              email: _emailCtrl.text.trim(), password: _passCtrl.text)
          : await app.login(
              email: _emailCtrl.text.trim(), password: _passCtrl.text);

      if (err == null && mounted) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const DevicesPage()));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err ?? 'Erreur inconnue')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mot de passe'),
              validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : () => _do(false),
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('Se connecter'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _loading ? null : () => _do(true),
              child: const Text('Créer un compte'),
            ),
          ],
        ),
      ),
    );
  }
}
