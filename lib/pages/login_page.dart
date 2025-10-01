import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController(text: 'demo@aube.app');
  final _pwdCtrl = TextEditingController(text: 'azerty123');
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final app = context.read<AppState>();
    final err =
        await app.login(email: _emailCtrl.text.trim(), password: _pwdCtrl.text);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.wb_sunny_rounded,
                    size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text('Lampe Aube',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration:
                                const InputDecoration(labelText: 'Email'),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty)
                                return 'Email requis';
                              if (!v.contains('@')) return 'Email invalide';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _pwdCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                                labelText: 'Mot de passe'),
                            validator: (v) {
                              if (v == null || v.isEmpty)
                                return 'Mot de passe requis';
                              if (v.length < 6) return 'Au moins 6 caractères';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text(_error!,
                                  style: TextStyle(
                                      color: theme.colorScheme.error)),
                            ),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _loading ? null : _submit,
                              child: _loading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Text('Se connecter'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () {
// Dans le MVP on "simule" une création de compte : on laisse passer si mdp >= 6
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  'Astuce : n\'importe quel email + mot de passe (>=6) fonctionne en dev.')));
                        },
                  child: const Text('Créer un compte'),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
