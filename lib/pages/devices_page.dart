import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../services/http_api.dart';
import 'device_page.dart';
import 'device_settings_page.dart';
import 'login_page.dart';

class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});
  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  late Future<List<Device>> _future;

  @override
  void initState() {
    super.initState();
    final api = context.read<AppState>().api;
    final app = context.read<AppState>();
    _future = api.listDevices(token: app.token!);
  }

  Future<void> _reload() async {
    final api = context.read<AppState>().api;
    final app = context.read<AppState>();
    setState(() {
      _future = api.listDevices(token: app.token!);
    });
  }

  Future<void> _createDevice() async {
    final api = context.read<AppState>().api;
    final nameCtrl = TextEditingController(text: 'Nouvelle lampe');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ajouter une lampe'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Nom'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await api.createDevice(nameCtrl.text.trim());
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Lampe ajoutée')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Device>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Mes lampes')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Impossible de charger les lampes.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}', // 👈 détail technique
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed: _reload, child: const Text('Réessayer')),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () async {
                        await context.read<AppState>().logout();
                        if (!mounted) return;
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                          (route) => false,
                        );
                      },
                      child: const Text('Se reconnecter'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final devices = snapshot.data ?? const <Device>[];

        return Scaffold(
          appBar: AppBar(
            title: const Text('Mes lampes'),
            actions: [
              // Menu profil (déconnexion)
              PopupMenuButton<String>(
                tooltip: 'Compte',
                onSelected: (value) async {
                  if (value == 'logout') {
                    await context
                        .read<AppState>()
                        .logout(); // vide token + prefs
                    if (!mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                      (route) => false,
                    );
                  } else if (value == 'add') {
                    await _createDevice();
                  } else if (value == 'refresh') {
                    await _reload();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'refresh',
                    child: ListTile(
                      leading: Icon(Icons.refresh),
                      title: Text('Actualiser'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'add',
                    child: ListTile(
                      leading: Icon(Icons.add),
                      title: Text('Ajouter une lampe'),
                    ),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'logout',
                    child: ListTile(
                      leading: Icon(Icons.logout),
                      title: Text('Se déconnecter'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _reload,
            // permet le pull-to-refresh même si la liste est vide
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: devices.isEmpty ? 1 : devices.length,
              itemBuilder: (context, i) {
                if (devices.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'Aucune lampe pour le moment.\nUtilise le menu pour en ajouter.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                final d = devices[i];
                return ListTile(
                  title: Text(d.name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => DevicePage(device: d)),
                    );
                  },
                  onLongPress: () async {
                    final changed = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DeviceSettingsPage(device: d),
                      ),
                    );
                    if (changed == true) await _reload();
                  },
                );
              },
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              await _reload();
            },
            child: const Icon(Icons.refresh),
          ),
        );
      },
    );
  }
}
