import 'package:flutter/material.dart';

import '../services/http_api.dart';

class DeviceAlarmsPage extends StatefulWidget {
  final Device device;
  final HttpApi api;
  const DeviceAlarmsPage({super.key, required this.device, required this.api});

  @override
  State<DeviceAlarmsPage> createState() => _DeviceAlarmsPageState();
}

class _DeviceAlarmsPageState extends State<DeviceAlarmsPage> {
  late Future<List<Alarm>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.listAlarms(widget.device.id);
  }

  Future<void> _reload() async {
    setState(() {
      _future = widget.api.listAlarms(widget.device.id);
    });
  }

  String _formatTime(Alarm a) =>
      '${a.hour.toString().padLeft(2, '0')}:${a.minute.toString().padLeft(2, '0')}';


  Widget _daysChips(Set<int> days) {
    const labels = {
      1: 'Lu',
      2: 'Ma',
      3: 'Me',
      4: 'Je',
      5: 'Ve',
      6: 'Sa',
      7: 'Di'
    };
    final ordered = [1, 2, 3, 4, 5, 6, 7];
    return Wrap(
      spacing: 6,
      children: ordered
          .map((d) => FilterChip(
                label: Text(labels[d]!),
                selected: days.contains(d),
                onSelected: null,
              ))
          .toList(),
    );
  }

  Future<void> _createOrEdit({Alarm? existing}) async {
    final result = await showDialog<Alarm>(
      context: context,
      builder: (context) => _AlarmEditorDialog(
        initial: existing ??
            Alarm(
              id: null,
              deviceId: widget.device.id,
              hour: 7,
              minute: 0,
              days: <int>{1, 2, 3, 4, 5}, // L-V par défaut
              durationMinutes: 15,
              enabled: true,
            ),
      ),
    );
    if (result != null) {
      final fixed = result.copyWith(deviceId: widget.device.id);
      await widget.api.saveAlarm(fixed);
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                existing == null ? 'Alarme ajoutée' : 'Alarme mise à jour')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Réveils — ${widget.device.name}'),
      ),
      body: FutureBuilder<List<Alarm>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final alarms = snapshot.data ?? const <Alarm>[];
          if (alarms.isEmpty) {
            return Center(
              child: Text(
                'Aucune alarme.\nAjoute ton premier réveil avec le bouton +',
                textAlign: TextAlign.center,
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.builder(
              itemCount: alarms.length,
              itemBuilder: (context, i) {
                final a = alarms[i];
                return ListTile(
                  title: Text(
                    _formatTime(a),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${a.durationMinutes} min d’aube'),
                      const SizedBox(height: 4),
                      _daysChips(a.days),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: a.enabled,
                        onChanged: (v) async {
                          await widget.api.toggleAlarm(widget.device.id, a.id!, v);
                          await _reload();
                        },
                      ),
                      IconButton(
                        tooltip: 'Supprimer',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          if (a.id == null) return;
                          final ok = await _confirmDelete(a);
                          if (ok == true) {
                            await widget.api.deleteAlarm(widget.device.id, a.id!);
                            await _reload();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Alarme supprimée')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  onTap: () => _createOrEdit(existing: a),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createOrEdit(),
        icon: const Icon(Icons.add_alarm),
        label: const Text('Ajouter'),
      ),
    );
  }

  Future<bool?> _confirmDelete(Alarm a) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer cette alarme ?'),
        content: Text(
          '${a.hour.toString().padLeft(2, '0')}:${a.minute.toString().padLeft(2, '0')} • ${a.durationMinutes} min d’aube',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer')),
        ],
      ),
    );
  }
}

class _AlarmEditorDialog extends StatefulWidget {
  final Alarm initial;
  const _AlarmEditorDialog({required this.initial});

  @override
  State<_AlarmEditorDialog> createState() => _AlarmEditorDialogState();
}

class _AlarmEditorDialogState extends State<_AlarmEditorDialog> {
  late int hour;
  late int minute;
  late Set<int> days; // 1..7
  int duration = 15;
  bool enabled = true;

  @override
  void initState() {
    super.initState();
    hour = widget.initial.hour;
    minute = widget.initial.minute;
    days = {...widget.initial.days};
    duration = widget.initial.durationMinutes;
    enabled = widget.initial.enabled;
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
    );
    if (picked != null) {
      setState(() {
        hour = picked.hour;
        minute = picked.minute;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordered = [1, 2, 3, 4, 5, 6, 7];
    const labels = {
      1: 'Lu',
      2: 'Ma',
      3: 'Me',
      4: 'Je',
      5: 'Ve',
      6: 'Sa',
      7: 'Di'
    };
    final durations = const [10, 15, 20, 30, 45];

    return AlertDialog(
      title: const Text('Éditer l’alarme'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilledButton.tonalIcon(
              onPressed: _pickTime,
              icon: const Icon(Icons.schedule),
              label: Text(
                  '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}'),
            ),
            const SizedBox(height: 12),
            const Text('Jours'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: ordered
                  .map((d) => FilterChip(
                        label: Text(labels[d]!),
                        selected: days.contains(d),
                        onSelected: (sel) {
                          setState(() {
                            if (sel) {
                              days.add(d);
                            } else {
                              days.remove(d);
                            }
                          });
                        },
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            const Text('Durée de l’aube'),
            DropdownButton<int>(
              value: duration,
              items: durations
                  .map((d) =>
                      DropdownMenuItem(value: d, child: Text('$d minutes')))
                  .toList(),
              onChanged: (v) => setState(() => duration = v ?? duration),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: enabled,
              onChanged: (v) => setState(() => enabled = v),
              title: const Text('Activée'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              widget.initial.copyWith(
                hour: hour,
                minute: minute,
                days: days,
                durationMinutes: duration,
                enabled: enabled,
              ),
            );
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
