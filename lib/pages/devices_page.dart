import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../services/http_api.dart';
import 'device_page.dart';
import 'device_settings_page.dart';
import 'login_page.dart';
import 'alarms_all_page.dart';

class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});
  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  final Map<String, DeviceState> _states = {};
  List<Device> _devices = [];
  bool _loading = true;
  bool _busy = false;
  Timer? _poll;

  HttpApi get _api => context.read<AppState>().api;
  String get _token => context.read<AppState>().token!;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _refreshStates());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final list = await _api.listDevices(token: _token);
      if (!mounted) return;
      setState(() {
        _devices = list;
        _loading = false;
      });
      await _refreshStates();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(e);
    }
  }

  Future<void> _refreshStates() async {
    if (_busy || !mounted || _devices.isEmpty) return;
    _busy = true;
    try {
      final futures = _devices.map((d) => _api.getDeviceState(d.id));
      final results = await Future.wait(futures, eagerError: false);
      if (!mounted) return;
      setState(() {
        for (final st in results) {
          _states[st.deviceId] = st;
        }
      });
    } catch (_) {
    } finally {
      _busy = false;
    }
  }

  Future<void> _reloadDevices() async {
    try {
      final list = await _api.listDevices(token: _token);
      if (!mounted) return;
      setState(() => _devices = list);
      await _refreshStates();
    } catch (e) {
      _showError(e);
    }
  }

  void _showError(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erreur: $e')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes lampes'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                await context.read<AppState>().logout();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              } else if (value == 'refresh') {
                await _reloadDevices();
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
        onRefresh: _reloadDevices,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: _devices.isEmpty ? 1 : _devices.length,
          itemBuilder: (context, i) {
            if (_devices.isEmpty) {
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
            final d = _devices[i];
            final st = _states[d.id];
            String subtitle;
            if (st == null) {
              subtitle = '…';
            } else if ((st.lux == -1 && st.temp == -50) ||
                st.lux.isNaN ||
                st.temp.isNaN) {
              subtitle = 'Aucune donnée';
            } else {
              subtitle = 'Lux: ${st.lux.toStringAsFixed(0)} • '
                  'Temp: ${st.temp.toStringAsFixed(1)} °C';
            }

            return ListTile(
              key: ValueKey(d.id),
              title: Text(d.name),
              subtitle: Text(subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DevicePage(device: d)),
                );
                final ns = await _api.getDeviceState(d.id);
                if (!mounted) return;
                setState(() => _states[d.id] = ns);
              },
              onLongPress: () async {
                final changed = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DeviceSettingsPage(device: d),
                  ),
                );
                if (changed == true) await _reloadDevices();
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GlobalAlarmsPage()),
          );
        },
        icon: const Icon(Icons.alarm),
        label: const Text('Alarmes'),
      ),
    );
  }
}
