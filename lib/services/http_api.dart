import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

// ---- Models (compatibles avec ton app actuelle) ----
class LoginResult {
  final bool success;
  final String? token;
  final String? errorMessage;
  LoginResult({required this.success, this.token, this.errorMessage});
}

class Device {
  final String id;
  String name;
  double? targetLux;

  Device({required this.id, required this.name, this.targetLux});

  factory Device.fromJson(Map<String, dynamic> j) =>
      Device(
        id: j['id'] as String,
        name: j['name'] as String,
        targetLux: (j['targetLux'] as num?)?.toDouble(),
      );
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

// ---- Alarm model pour la page Alarmes ----
class Alarm {
  final String? id;
  final String deviceId;
  final int hour;
  final int minute;
  final Set<int> days;           // 1..7
  final int durationMinutes;
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

  factory Alarm.fromJson(Map<String, dynamic> j, String deviceId) {
    final List dynDays = j['days'] ?? [];
    final daysSet = dynDays.map((e) {
      if (e is int) return e;
      if (e is String) return int.tryParse(e) ?? 0;
      return 0;
    }).where((x) => x > 0).toSet();

    return Alarm(
      id: j['id'] as String?,
      deviceId: deviceId,
      hour: j['hour'] as int,
      minute: j['minute'] as int,
      days: daysSet,
      durationMinutes: j['durationMinutes'] as int,
      enabled: j['enabled'] as bool,
    );
  }

  Map<String, dynamic> toBackendPayload() => {
        'hour': hour,
        'minute': minute,
        'days': days.toList(),
        'durationMinutes': durationMinutes,
        'enabled': enabled,
      };
}

// ----------------------------------------------------
//               HTTP API (backend Nest)
// ----------------------------------------------------
class HttpApi {
  final String baseUrl;      // ex: http://10.0.2.2:3000
  final http.Client _client;

  HttpApi({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  // ---- Auth (MVP : on “réussit” toujours) ----
  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    // Quand l’auth sera prête, on appellera /auth/login ici.
    return LoginResult(success: true, token: 'dev-token');
  }

  // ---- Device ----
  Future<Device> getDevice(String id) async {
    final list = await listDevices(token: 'demo'); // le token n’est pas utilisé côté back pour l’instant
    final dev = list.firstWhere((d) => d.id == id, orElse: () => throw Exception('Device not found'));
    return dev;
  }

  Future<void> renameDevice(String id, String name) async {
    final r = await _client.patch(
      Uri.parse('$baseUrl/devices/$id/name'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name}),
    );
    if (r.statusCode != 200) throw Exception('renameDevice failed: ${r.body}');
  }

  Future<void> setDeviceTargetLux(String id, double value) async {
    final r = await _client.patch(
      Uri.parse('$baseUrl/devices/$id/targetLux'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'value': value}),
    );
    if (r.statusCode != 200) throw Exception('setDeviceTargetLux failed: ${r.body}');
  }

  // ---- Devices ----
  Future<List<Device>> listDevices({required String token}) async {
    final r = await _client.get(Uri.parse('$baseUrl/devices'));
    if (r.statusCode != 200) {
      throw Exception('GET /devices failed: ${r.statusCode}');
    }
    final List list = jsonDecode(r.body) as List;
    return list.map((e) => Device.fromJson(e as Map<String, dynamic>)).toList();
  }

  // Etat local simulé pour le moment
  final Map<String, DeviceState> _states = {};
  final Map<String, StreamController<DeviceState>> _controllers = {};

  Future<DeviceState> getDeviceState(String deviceId) async {
    // init si besoin
    _states.putIfAbsent(deviceId, () => DeviceState(deviceId: deviceId));
    // renvoie l’état courant
    return _states[deviceId]!;
  }

  /// “Temps réel” simulé (petit drift lux/temp toutes les 2s)
  Stream<DeviceState> subscribeState(String deviceId) {
    _controllers.putIfAbsent(
        deviceId, () => StreamController<DeviceState>.broadcast());

    // push initial
    Future.microtask(() => _controllers[deviceId]!.add(_states[deviceId]!));

    // tick
    Timer.periodic(const Duration(seconds: 2), (t) {
      if (!_controllers[deviceId]!.hasListener) {
        t.cancel();
        return;
      }
      final s = _states[deviceId]!;
      final driftLux = (s.power ? 2 : -1);
      final driftTemp = 0.05 * (t.tick % 2 == 0 ? 1 : -1);

      final updated = s.copyWith(
        lux: (s.lux + driftLux).clamp(0, 200).toDouble(),
        temp: (s.temp + driftTemp),
      );
      _states[deviceId] = updated;
      _controllers[deviceId]!.add(updated);
    });

    return _controllers[deviceId]!.stream;
  }

  Future<DeviceState> setPower(String deviceId, bool on) async {
    final s = _states[deviceId] ?? DeviceState(deviceId: deviceId);
    final updated = s.copyWith(power: on, lux: on ? (s.lux + 5) : (s.lux * 0.5));
    _states[deviceId] = updated;
    _controllers[deviceId]?.add(updated);
    return updated;
  }

  Future<DeviceState> setBrightness(String deviceId, double b) async {
    final s = _states[deviceId] ?? DeviceState(deviceId: deviceId);
    final updated = s.copyWith(brightness: b, lux: (10 + b * 100));
    _states[deviceId] = updated;
    _controllers[deviceId]?.add(updated);
    return updated;
  }

  Future<DeviceState> setColorTemp(String deviceId, double colorTemp) async {
    final s = _states[deviceId] ?? DeviceState(deviceId: deviceId);
    final updated = s.copyWith(colorTemp: colorTemp);
    _states[deviceId] = updated;
    _controllers[deviceId]?.add(updated);
    return updated;
  }

  // ---- Alarms (réels via backend) ----
  Future<List<Alarm>> listAlarms(String deviceId) async {
    final r = await _client.get(Uri.parse('$baseUrl/devices/$deviceId/alarms'));
    if (r.statusCode != 200) throw Exception('GET alarms failed');
    final List list = jsonDecode(r.body) as List;
    return list
        .map((j) => Alarm.fromJson(j as Map<String, dynamic>, deviceId))
        .toList();
  }

  Future<void> deleteAlarm(String id, String deviceId) async {
    final r = await _client.delete(Uri.parse('$baseUrl/devices/$deviceId/alarms/$id'));
    if (r.statusCode != 200 && r.statusCode != 204) {
      throw Exception('DELETE alarm failed');
    }
  }

  Future<Alarm> saveAlarm(Alarm a) async {
    if (a.id == null) {
      final r = await _client.post(
        Uri.parse('$baseUrl/devices/${a.deviceId}/alarms'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(a.toBackendPayload()),
      );
      if (r.statusCode != 201 && r.statusCode != 200) {
        throw Exception('POST alarm failed: ${r.body}');
      }
      return Alarm.fromJson(jsonDecode(r.body), a.deviceId);
    } else {
      final r = await _client.patch(
        Uri.parse('$baseUrl/devices/${a.deviceId}/alarms/${a.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(a.toBackendPayload()),
      );
      if (r.statusCode != 200) throw Exception('PATCH alarm failed');
      return Alarm.fromJson(jsonDecode(r.body), a.deviceId);
    }
  }

  Future<void> toggleAlarm(String id, String deviceId, bool enabled) async {
    final r = await _client.patch(
      Uri.parse('$baseUrl/devices/$deviceId/alarms/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'enabled': enabled}),
    );
    if (r.statusCode != 200) throw Exception('toggle alarm failed');
  }
}
