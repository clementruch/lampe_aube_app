import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../services/mock_api.dart';
import 'device_page.dart';

class DevicesPage extends StatelessWidget {
  const DevicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final api = app.api;

    return FutureBuilder<List<Device>>(
      future: api.listDevices(token: app.email ?? ''),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Mes lampes')),
            body: const Center(child: Text('Aucun périphérique trouvé')),
          );
        }

        final devices = snapshot.data!;
        return Scaffold(
          appBar: AppBar(title: const Text('Mes lampes')),
          body: ListView.builder(
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final d = devices[index];
              return ListTile(
                title: Text(d.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DevicePage(device: d),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
