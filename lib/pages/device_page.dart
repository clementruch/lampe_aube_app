import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../services/http_api.dart';
import 'alarms_page.dart';
import 'device_settings_page.dart';

class DevicePage extends StatefulWidget {
  final Device device;
  const DevicePage({super.key, required this.device});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  DeviceState? _state;
  StreamSubscription<DeviceState>? _sub;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final api = context.read<AppState>().api;
    _bootstrap(api);
  }

  Future<void> _bootstrap(HttpApi api) async {
    try {
      final s = await api.getDeviceState(widget.device.id);
      if (!mounted) return;
      setState(() {
        _state = s;
        _loading = false;
      });
      _sub = api.subscribeState(widget.device.id).listen((s) {
        if (!mounted) return;
        setState(() => _state = s);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Impossible de charger l’état du périphérique')),
      );
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    final theme = Theme.of(context);

    if (_loading || _state == null) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final s = _state!;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.alarm),
            tooltip: 'Réveils',
            onPressed: () {
              final api = context.read<AppState>().api;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      DeviceAlarmsPage(device: widget.device, api: api),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Paramètres',
            onPressed: () async {
              final api = context.read<AppState>().api;

              // on attend le résultat de la page paramètres
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => DeviceSettingsPage(device: widget.device),
                ),
              );

              // si la page a enregistré quelque chose, on recharge le device et on met à jour le titre
              if (changed == true) {
                final fresh = await api.getDevice(widget.device.id);
                if (!mounted) return;
                setState(() {
                  widget.device.name =
                      fresh.name; // on met à jour le nom affiché
                });
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Power
          Card(
            child: SwitchListTile(
              title: const Text('Alimentation'),
              subtitle: Text(s.power ? 'Allumée' : 'Éteinte'),
              value: s.power,
              onChanged: (v) async {
                final ns = await api.setPower(widget.device.id, v);
                setState(() => _state = ns);
              },
            ),
          ),
          const SizedBox(height: 12),

          // Brightness
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Luminosité'),
                  Slider(
                    value: s.brightness,
                    min: 0,
                    max: 1,
                    onChanged: (v) =>
                        setState(() => _state = s.copyWith(brightness: v)),
                    onChangeEnd: (v) async {
                      final ns = await api.setBrightness(widget.device.id, v);
                      setState(() => _state = ns);
                    },
                  ),
                  Text('${(s.brightness * 100).round()} %'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Température de couleur
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Température de couleur (K)'),
                  Slider(
                    value: s.colorTemp.clamp(2000, 6500).toDouble(),
                    min: 2000,
                    max: 6500,
                    divisions: 9,
                    onChanged: (v) =>
                        setState(() => _state = s.copyWith(colorTemp: v)),
                    onChangeEnd: (v) async {
                      final ns = await api.setColorTemp(widget.device.id, v);
                      setState(() => _state = ns);
                    },
                  ),
                  Text('${s.colorTemp.round()} K'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Sensors (Lux + Temp)
          Card(
            child: ListTile(
              title: const Text('Capteurs (live)'),
              subtitle: Text(
                'Lux: ${s.lux.toStringAsFixed(0)} • '
                'Temp: ${s.temp.toStringAsFixed(1)} °C',
              ),
              leading: Icon(Icons.sensors, color: theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 12),

          // Presets
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _applyPreset(api, 'lecture'),
                  child: const Text('Lecture'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _applyPreset(api, 'relax'),
                  child: const Text('Relax'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _applyPreset(api, 'nuit'),
                  child: const Text('Nuit'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _applyPreset(HttpApi api, String preset) async {
    switch (preset) {
      case 'lecture':
        await api.setPower(widget.device.id, true);
        await api.setBrightness(widget.device.id, 0.8);
        await api.setColorTemp(widget.device.id, 4500);
        break;
      case 'relax':
        await api.setPower(widget.device.id, true);
        await api.setBrightness(widget.device.id, 0.5);
        await api.setColorTemp(widget.device.id, 3000);
        break;
      case 'nuit':
        await api.setPower(widget.device.id, true);
        await api.setBrightness(widget.device.id, 0.15);
        await api.setColorTemp(widget.device.id, 2700);
        break;
    }
  }
}
