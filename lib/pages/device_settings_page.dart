import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../services/http_api.dart';

class DeviceSettingsPage extends StatefulWidget {
  final Device device;
  const DeviceSettingsPage({super.key, required this.device});

  @override
  State<DeviceSettingsPage> createState() => _DeviceSettingsPageState();
}

class _DeviceSettingsPageState extends State<DeviceSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  double? _targetLux;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.device.name);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final api = context.read<AppState>().api;
    try {
      final dev = await api.getDevice(widget.device.id);
      if (!mounted) return;
      setState(() {
        _nameCtrl.text = dev.name;
        _targetLux = devTargetLux(dev);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur chargement paramètres: $e')),
      );
    }
  }

  double devTargetLux(Device d) {
    try {
      return (d as dynamic).targetLux?.toDouble() ?? 120.0;
    } catch (_) {
      return 120.0;
    }
  }

 Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final api = context.read<AppState>().api;

    setState(() => _saving = true);
    try {
      // Renommer
      await api.renameDevice(widget.device.id, _nameCtrl.text.trim());
      // Sauver targetLux
      if (_targetLux != null) {
        await api.setDeviceTargetLux(widget.device.id, _targetLux!);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paramètres enregistrés')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading || _targetLux == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Paramètres — ${widget.device.name}')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Paramètres — ${widget.device.name}')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Général', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nom de la lampe',
                        hintText: 'ex: Lampe Chambre',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Éclairage adaptatif', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Seuil de luminosité cible (lux)'),
                    Slider(
                      value: _targetLux!,
                      min: 20,
                      max: 500,
                      divisions: 48, // pas de ~10 lux
                      label: '${_targetLux!.round()} lux',
                      onChanged: (v) => setState(() => _targetLux = v),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('${_targetLux!.round()} lux'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'La lampe essayera de maintenir au moins ce niveau de lux '
                      'en ajustant sa luminosité via le capteur.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save),
                label: const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
