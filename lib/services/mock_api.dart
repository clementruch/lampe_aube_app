import 'dart:async';

class LoginResult {
  final bool success;
  final String? token;
  final String? errorMessage;
  LoginResult({required this.success, this.token, this.errorMessage});
}

class Device {
  final String id;
  String name;
  Device({required this.id, required this.name});
}

class DeviceState {
  final String deviceId;
  bool power;
  double brightness; // 0..1
  double colorTemp;  // 2000..6500 (K)
  double lux;
  double temp;

  DeviceState({
    required this.deviceId,
    this.power = false,
    this.brightness = 0.4,
    this.colorTemp = 3200,
    this.lux = 20,
    this.temp = 22.0,
  });

  DeviceState copyWith({
    bool? power,
    double? brightness,
    double? colorTemp,
    double? lux,
    double? temp,
  }) {
    return DeviceState(
      deviceId: deviceId,
      power: power ?? this.power,
      brightness: brightness ?? this.brightness,
      colorTemp: colorTemp ?? this.colorTemp,
      lux: lux ?? this.lux,
      temp: temp ?? this.temp,
    );
  }
}

class Alarm {
  final String? id;
  final String deviceId;
  final int hour;
  final int minute;
  final Set<int> days; // 1=Lun ... 7=Dim
  final int durationMinutes; // 10/15/30...
  final bool enabled;

  Alarm({
    required this.id,
    required this.deviceId,
    required this.hour,
    required this.minute,
    required this.days,
    required this.durationMinutes,
    required this.enabled,
  });

  Alarm copyWith({
    String? id,
    String? deviceId,
    int? hour,
    int? minute,
    Set<int>? days,
    int? durationMinutes,
    bool? enabled,
  }) {
    return Alarm(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      days: days ?? this.days,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      enabled: enabled ?? this.enabled,
    );
  }
}

class DeviceConfig {
  final String deviceId;
  final double targetLux; // seuil de luminosité visé par l'éclairage adaptatif

  DeviceConfig({required this.deviceId, required this.targetLux});

  DeviceConfig copyWith({double? targetLux}) =>
      DeviceConfig(deviceId: deviceId, targetLux: targetLux ?? this.targetLux);
}

class MockApi {
  static const _demoUsers = {
    'demo@aube.app': 'azerty123',
    'clement@aube.app': 'password',
  };

  Future<LoginResult> login(
      {required String email, required String password}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final ok = _demoUsers[email] == password;
    if (ok || password.length >= 6) {
      return LoginResult(
          success: true,
          token: 'dev.jwt.${DateTime.now().millisecondsSinceEpoch}');
    }
    return LoginResult(success: false, errorMessage: 'Identifiants invalides');
  }

  // --- App IoT mock ---

  final List<Device> _devices = [
    Device(id: 'dev-1', name: 'Lampe Chambre'),
    Device(id: 'dev-2', name: 'Lampe Salon'),
  ];

  final Map<String, DeviceState> _states = {
    'dev-1': DeviceState(
        deviceId: 'dev-1',
        power: false,
        brightness: 0.3,
        colorTemp: 3200,
        lux: 12,
        temp: 22.1),
    'dev-2': DeviceState(
        deviceId: 'dev-2',
        power: true,
        brightness: 0.7,
        colorTemp: 4000,
        lux: 35,
        temp: 21.8),
  };

  final List<Alarm> _alarms = [
    Alarm(
      id: 'al-1',
      deviceId: 'dev-1',
      hour: 7,
      minute: 0,
      days: {1, 2, 3, 4, 5},
      durationMinutes: 15,
      enabled: true,
    ),
  ];

  final Map<String, StreamController<DeviceState>> _controllers = {};

  Future<List<Device>> listDevices({required String token}) async {
    await Future.delayed(const Duration(milliseconds: 250));
    return List<Device>.from(_devices);
  }

  Future<DeviceState> getDeviceState(String deviceId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _states[deviceId]!;
  }

  /// Stream “temps réel” simulé : fait varier légèrement lux/temp toutes les 2s.
  Stream<DeviceState> subscribeState(String deviceId) {
    _controllers.putIfAbsent(
        deviceId, () => StreamController<DeviceState>.broadcast());

    Timer.periodic(const Duration(seconds: 2), (t) {
      final s = _states[deviceId]!;
      final driftLux = (s.power ? 2 : -1);
      final driftTemp = 0.05 * (t.tick % 2 == 0 ? 1 : -1);

      final updated = s.copyWith(
        lux: (s.lux + driftLux).clamp(0, 200).toDouble(),
        temp: (s.temp + driftTemp),
      );
      _states[deviceId] = updated;
      _controllers[deviceId]?.add(updated);
      if (!_controllers[deviceId]!.hasListener) t.cancel();
    });

    Future.microtask(() => _controllers[deviceId]!.add(_states[deviceId]!));
    return _controllers[deviceId]!.stream;
  }

  Future<DeviceState> setPower(String deviceId, bool on) async {
    final s = _states[deviceId]!;
    final updated =
        s.copyWith(power: on, lux: on ? (s.lux + 5) : (s.lux * 0.5));
    _states[deviceId] = updated;
    _controllers[deviceId]?.add(updated);
    return updated;
  }

  Future<DeviceState> setBrightness(String deviceId, double b) async {
    final s = _states[deviceId]!;
    final updated = s.copyWith(brightness: b, lux: (10 + b * 100));
    _states[deviceId] = updated;
    _controllers[deviceId]?.add(updated);
    return updated;
  }

  Future<DeviceState> setColorTemp(String deviceId, double colorTemp) async {
    final s = _states[deviceId]!;
    final updated = s.copyWith(colorTemp: colorTemp);
    _states[deviceId] = updated;
    _controllers[deviceId]?.add(updated);
    return updated;
  }

  String _genAlarmId() => 'al-${DateTime.now().millisecondsSinceEpoch}';

  Future<List<Alarm>> listAlarms(String deviceId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _alarms.where((a) => a.deviceId == deviceId).toList()
      ..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
  }

  Future<Alarm> saveAlarm(Alarm alarm) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (alarm.id == null) {
      final created = alarm.copyWith(id: _genAlarmId());
      _alarms.add(created);
      return created;
    } else {
      final idx = _alarms.indexWhere((a) => a.id == alarm.id);
      if (idx >= 0) {
        _alarms[idx] = alarm;
        return alarm;
      }
      // si l'id n'existait pas, on l'ajoute
      final created = alarm.copyWith(id: alarm.id);
      _alarms.add(created);
      return created;
    }
  }

  Future<void> deleteAlarm(String alarmId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    _alarms.removeWhere((a) => a.id == alarmId);
  }

  Future<Alarm> toggleAlarm(String alarmId, bool enabled) async {
    await Future.delayed(const Duration(milliseconds: 120));
    final idx = _alarms.indexWhere((a) => a.id == alarmId);
    if (idx >= 0) {
      final updated = _alarms[idx].copyWith(enabled: enabled);
      _alarms[idx] = updated;
      return updated;
    }
    throw Exception('Alarm not found');
  }

    // --- Device config mock ---
  final Map<String, DeviceConfig> _deviceConfigs = {
    'dev-1': DeviceConfig(deviceId: 'dev-1', targetLux: 120),
    'dev-2': DeviceConfig(deviceId: 'dev-2', targetLux: 150),
  };

  Future<DeviceConfig> getDeviceConfig(String deviceId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _deviceConfigs[deviceId] ??
        (_deviceConfigs[deviceId] = DeviceConfig(deviceId: deviceId, targetLux: 120));
  }

  Future<DeviceConfig> saveDeviceConfig(String deviceId, {double? targetLux}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final current = await getDeviceConfig(deviceId);
    final updated = current.copyWith(targetLux: targetLux);
    _deviceConfigs[deviceId] = updated;
    return updated;
  }

  Future<Device> renameDevice(String deviceId, String newName) async {
    await Future.delayed(const Duration(milliseconds: 180));
    final idx = _devices.indexWhere((d) => d.id == deviceId);
    if (idx < 0) {
      throw Exception('Device not found');
    }
    _devices[idx].name = newName;
    return _devices[idx];
  }
}
