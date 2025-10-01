import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'state/app_state.dart';
import 'services/http_api.dart';
import 'pages/login_page.dart';
import 'pages/devices_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final api = HttpApi(baseUrl: 'http://10.0.2.2:3000');
  runApp(LampeAubeApp(api: api, prefs: prefs));
}

class LampeAubeApp extends StatelessWidget {
  final HttpApi api;
  final SharedPreferences prefs;
  const LampeAubeApp({super.key, required this.api, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState(api: api, prefs: prefs)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Lampe Aube',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F6DB1)),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
          ),
        ),
        home: const RootGate(),
      ),
    );
  }
}

/// RootGate choisit l'écran selon l'état de connexion.
class RootGate extends StatelessWidget {
  const RootGate({super.key});
  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, app, _) {
        if (!app.initialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return app.isAuthenticated ? const DevicesPage() : const LoginPage();
      },
    );
  }
}
