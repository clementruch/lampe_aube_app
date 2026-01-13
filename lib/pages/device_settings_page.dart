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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.device.name);
    _targetLux = (widget.device.targetLux ?? 120).toDouble();
  }

  double devTargetLux(Device d) =>
      (d.targetLux ?? 120).toDouble();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final api = context.read<AppState>().api;

    setState(() => _saving = true);
    try {
      await api.renameDevice(widget.device.id, _nameCtrl.text.trim());
      await api.setDeviceTargetLux(widget.device.id, _targetLux!);

      widget.device.name = _nameCtrl.text.trim();
      widget.device.targetLux = _targetLux;

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
                child: TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nom de la lampe',
                    hintText: 'ex: Lampe Chambre',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
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
                      max: 1200,
                      divisions: 48,
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
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
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
