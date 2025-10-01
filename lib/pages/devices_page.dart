import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

class DevicesPage extends StatelessWidget {
  const DevicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes lampes'),
        actions: [
          IconButton(
            onPressed: () => app.logout(),
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Card(
              child: ListTile(
                  title: Text('Lampe Chambre'),
                  subtitle: Text('État : éteinte'),
                  trailing: Icon(Icons.chevron_right))),
          SizedBox(height: 12),
          Card(
              child: ListTile(
                  title: Text('Lampe Salon'),
                  subtitle: Text('État : allumée'),
                  trailing: Icon(Icons.chevron_right))),
        ],
      ),
    );
  }
}
