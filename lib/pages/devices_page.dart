import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../services/http_api.dart';
import 'device_page.dart';
import 'device_settings_page.dart';

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
    _future = api.listDevices(token: app.email ?? '');
  }

  Future<void> _reload() async {
    final api = context.read<AppState>().api;
    final app = context.read<AppState>();
    setState(() {
      _future = api.listDevices(token: app.email ?? '');
    });
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    final app = context.read<AppState>();

    return FutureBuilder<List<Device>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final devices = snapshot.data ?? const <Device>[];
        return Scaffold(
          appBar: AppBar(title: const Text('Mes lampes')),
          body: RefreshIndicator(
            onRefresh: _reload,
            child: ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, i) {
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
                      MaterialPageRoute(builder: (_) => DeviceSettingsPage(device: d)),
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
