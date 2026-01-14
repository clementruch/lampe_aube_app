import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../services/http_api.dart';
import '../utils/alarm_service.dart';

class _Row {
  final Alarm alarm;
  final Device? device;
  _Row(this.alarm, this.device);
}

class _AlarmsBundle {
  final List<Device> devices;
  final List<_Row> rows;
  final List<Alarm> alarmsRaw;
  const _AlarmsBundle({
    required this.devices,
    required this.rows,
    required this.alarmsRaw,
  });
}

class GlobalAlarmsPage extends StatefulWidget {
  const GlobalAlarmsPage({super.key});

  @override
  State<GlobalAlarmsPage> createState() => _GlobalAlarmsPageState();
}

class _GlobalAlarmsPageState extends State<GlobalAlarmsPage> {
  late Future<_AlarmsBundle> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _loadAll();
  }

  Future<_AlarmsBundle> _loadAll() async {
    final app = context.read<AppState>();
    final api = app.api;

    await AlarmService.instance.init(api: api);

    final devices = await api.listDevices(token: app.token!);
    final alarms  = await api.listAllAlarms();

    await AlarmService.instance.rescheduleAll(alarms);

    final byId = {for (final d in devices) d.id: d};
    final rows = alarms
        .map((a) => _Row(a, (a.sunrise && a.deviceId != null) ? byId[a.deviceId] : null))
        .toList()
      ..sort((ra, rb) {
        final ta = ra.alarm.hour * 60 + ra.alarm.minute;
        final tb = rb.alarm.hour * 60 + rb.alarm.minute;
        return ta.compareTo(tb);
      });

    return _AlarmsBundle(devices: devices, rows: rows, alarmsRaw: alarms);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _loadAll();
    });
  }

  String _hhmm(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  String _days(Set<int> days) {
    if (days.isEmpty) return '—';
    const map = {1: 'Lu', 2: 'Ma', 3: 'Me', 4: 'Je', 5: 'Ve', 6: 'Sa', 7: 'Di'};
    return [1, 2, 3, 4, 5, 6, 7].where(days.contains).map((d) => map[d]!).join(' ');
  }

  Future<void> _toggle(_Row row, bool enabled) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final api = context.read<AppState>().api;
      await api.toggleAlarmById(row.alarm.id!, enabled);

      if (enabled) {
        await AlarmService.instance.scheduleFor(row.alarm);
      } else {
        await AlarmService.instance.cancelFor(row.alarm);
      }

      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de modifier : $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(_Row row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer cette alarme ?'),
        content: Text('${row.device?.name ?? "Téléphone"} • ${_hhmm(row.alarm.hour, row.alarm.minute)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await context.read<AppState>().api.deleteAlarmById(row.alarm.id!);

      await AlarmService.instance.cancelFor(row.alarm);

      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alarme supprimée')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Suppression échouée : $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openEditor({_Row? existing}) async {
    final bundle = await _future;

    final edited = await showModalBottomSheet<_EditorResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AlarmEditorSheet(
        devices: bundle.devices,
        existing: existing,
      ),
    );
    if (edited == null) return;

    setState(() => _busy = true);
    try {
      final api = context.read<AppState>().api;

      // 1) Sauvegarde côté backend
      final saved = (existing == null)
          ? await api.saveAlarm(Alarm(
              id: null,
              deviceId: edited.sunrise ? edited.device!.id : null,
              hour: edited.hour,
              minute: edited.minute,
              days: edited.days,
              durationMinutes: edited.duration,
              enabled: edited.enabled,
              sunrise: edited.sunrise,
              label: edited.label,
            ))
          : await api.saveAlarm(existing.alarm.copyWith(
              deviceId: edited.sunrise ? edited.device!.id : null,
              hour: edited.hour,
              minute: edited.minute,
              days: edited.days,
              durationMinutes: edited.duration,
              enabled: edited.enabled,
              sunrise: edited.sunrise,
              label: edited.label,
            ));

      // 2) Replanification locale
      await AlarmService.instance.cancelFor(saved);
      if (saved.enabled) {
        await AlarmService.instance.scheduleFor(saved);
      }

      // 3) Synchronisation "aube" côté lampe (backend /devices/:id/sunrise)
      //    - si aube activée : on push la prochaine occurrence
      //    - sinon : on efface sur la lampe concernée
      DateTime? nextOccurrence;
      if (saved.sunrise && saved.enabled && saved.deviceId != null) {
        if (saved.days.isEmpty) {
          nextOccurrence = AlarmService.instance.nextOnceAt(saved.hour, saved.minute);
        } else {
          // plus proche jour parmi le set
          nextOccurrence = saved.days
              .map((d) => AlarmService.instance.nextWeekdayAt(d, saved.hour, saved.minute))
              .reduce((a, b) => a.isBefore(b) ? a : b);
        }
        await api.setDeviceSunrise(saved.deviceId!, nextOccurrence, saved.durationMinutes);
      } else {
        // Cas où on désactive l'aube ou on passe en alarme simple :
        // si l'alarme précédente était une aube liée à une lampe, on nettoie sur cette lampe.
        final String? previousDeviceId =
            existing?.device?.id;
        if (previousDeviceId != null) {
          await api.setDeviceSunrise(previousDeviceId, null, 0);
        }
      }

      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(existing == null ? 'Alarme créée' : 'Alarme enregistrée')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enregistrement échoué : $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Toutes les alarmes')),
      body: FutureBuilder<_AlarmsBundle>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Erreur : ${snap.error}'));
          }

          final bundle = snap.data!;
          if (bundle.rows.isEmpty) {
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Aucune alarme.\nAppuie sur + pour en créer une (avec ou sans lampe).',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              itemCount: bundle.rows.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final r = bundle.rows[i];
                final a = r.alarm;
                final isSunrise = a.sunrise && r.device != null;

                final subtitle = isSunrise
                    ? '${r.device!.name} • ${_days(a.days)} • ${a.durationMinutes} min d’aube'
                    : '${a.label ?? "Téléphone"} • ${_days(a.days)} • Alarme simple';

                return ListTile(
                  leading: Icon(
                    isSunrise ? Icons.wb_sunny : Icons.alarm,
                    color: a.enabled ? (isSunrise ? Colors.orange : Colors.green) : Colors.grey,
                  ),
                  title: Text(
                    _hhmm(a.hour, a.minute),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(subtitle),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(value: a.enabled, onChanged: (v) => _toggle(r, v)),
                      IconButton(
                        tooltip: 'Modifier',
                        icon: const Icon(Icons.edit),
                        onPressed: () => _openEditor(existing: r),
                      ),
                      IconButton(
                        tooltip: 'Supprimer',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(r),
                      ),
                    ],
                  ),
                  onTap: () => _openEditor(existing: r),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : () => _openEditor(),
        icon: _busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.add_alarm),
        label: const Text('Ajouter'),
      ),
    );
  }
}

class _EditorResult {
  final bool sunrise;
  final Device? device;
  final int hour;
  final int minute;
  final Set<int> days;
  final int duration;
  final bool enabled;
  final String? label;

  const _EditorResult({
    required this.sunrise,
    required this.device,
    required this.hour,
    required this.minute,
    required this.days,
    required this.duration,
    required this.enabled,
    this.label,
  });
}

class _AlarmEditorSheet extends StatefulWidget {
  final List<Device> devices;
  final _Row? existing;
  const _AlarmEditorSheet({required this.devices, this.existing});

  @override
  State<_AlarmEditorSheet> createState() => _AlarmEditorSheetState();
}

class _AlarmEditorSheetState extends State<_AlarmEditorSheet> {
  bool sunrise = true;
  Device? device;
  int hour = 7;
  int minute = 0;
  Set<int> days = {};
  int duration = 15;
  bool enabled = true;
  final _labelCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final r = widget.existing!;
      final a = r.alarm;
      sunrise = a.sunrise && r.device != null;
      device  = r.device ?? (widget.devices.isNotEmpty ? widget.devices.first : null);
      hour    = a.hour;
      minute  = a.minute;
      days    = {...a.days};
      duration= a.durationMinutes;
      enabled = a.enabled;
      _labelCtrl.text = a.label ?? '';
    } else {
      device = widget.devices.isNotEmpty ? widget.devices.first : null;
    }
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
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
    final viewInset = MediaQuery.of(context).viewInsets.bottom;
    const labels = {1: 'Lu', 2: 'Ma', 3: 'Me', 4: 'Je', 5: 'Ve', 6: 'Sa', 7: 'Di'};
    final ordered = [1, 2, 3, 4, 5, 6, 7];
    const durations = [10, 15, 20, 30, 45];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              ListTile(
                title: Text(
                  widget.existing == null ? 'Nouvelle alarme' : 'Modifier l’alarme',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ),
              const Divider(height: 1),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + viewInset),
                  children: [
                    SwitchListTile(
                      value: sunrise,
                      onChanged: (v) => setState(() => sunrise = v),
                      title: const Text('Simuler l’aube sur une lampe'),
                      subtitle: const Text('OFF : alarme sans lampe (notification locale)'),
                    ),
                    const SizedBox(height: 8),

                    if (sunrise) ...[
                      const Text('Lampe'),
                      const SizedBox(height: 6),
                      DropdownButton<Device>(
                        value: device,
                        isExpanded: true,
                        items: widget.devices
                            .map((d) => DropdownMenuItem(value: d, child: Text(d.name)))
                            .toList(),
                        onChanged: (d) => setState(() => device = d),
                      ),
                      const SizedBox(height: 12),
                    ],

                    FilledButton.tonalIcon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.schedule),
                      label: Text('${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}'),
                    ),
                    const SizedBox(height: 12),

                    const Text('Jours (laisser vide pour une seule fois)'),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: ordered
                          .map((d) => FilterChip(
                                label: Text(labels[d]!),
                                selected: days.contains(d),
                                showCheckmark: false,
                                onSelected: (sel) => setState(() {
                                  if (sel) {
                                    days.add(d);
                                  } else {
                                    days.remove(d);
                                  }
                                }),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 12),

                    if (sunrise) ...[
                      const Text('Durée de l’aube'),
                      DropdownButton<int>(
                        value: duration,
                        isExpanded: true,
                        items: durations.map((d) => DropdownMenuItem(value: d, child: Text('$d minutes'))).toList(),
                        onChanged: (v) => setState(() => duration = v ?? duration),
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (!sunrise) ...[
                      TextField(
                        controller: _labelCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Libellé (optionnel)',
                          hintText: 'Ex: Réveil semaine',
                        ),
                      ),
                    ],

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: enabled,
                      onChanged: (v) => setState(() => enabled = v),
                      title: const Text('Activée'),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler'))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: (!sunrise || device != null)
                            ? () {
                                Navigator.pop(
                                  context,
                                  _EditorResult(
                                    sunrise: sunrise,
                                    device: device,
                                    hour: hour,
                                    minute: minute,
                                    days: days,
                                    duration: duration,
                                    enabled: enabled,
                                    label: _labelCtrl.text.trim().isEmpty ? null : _labelCtrl.text.trim(),
                                  ),
                                );
                              }
                            : null,
                        child: const Text('Enregistrer'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
