import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

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

  factory Device.fromJson(Map<String, dynamic> j) => Device(
        id: j['id'] as String,
        name: j['name'] as String,
        targetLux: (j['targetLux'] as num?)?.toDouble(),
      );
}

class DeviceState {
  final String deviceId;
  bool power;
  double brightness; // 0..1
  double colorTemp; // 2000..6500 (K)
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
  final Set<int> days; // 1..7
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
    final daysSet = dynDays
        .map((e) {
          if (e is int) return e;
          if (e is String) return int.tryParse(e) ?? 0;
          return 0;
        })
        .where((x) => x > 0)
        .toSet();

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

class HttpApi {
  final String baseUrl;
  final http.Client _client;
  String? authToken;

  HttpApi({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  Map<String, String> _headersJson() => {
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      };

  // ---- Auth backend ----
  Future<LoginResult> signup(
      {required String email, required String password}) async {
    final r = await _client.post(
      Uri.parse('$baseUrl/auth/signup'),
      headers: _headersJson(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (r.statusCode == 201 || r.statusCode == 200) {
      final token = (jsonDecode(r.body) as Map)['access_token'] as String;
      authToken = token;
      return LoginResult(success: true, token: token);
    }
    return LoginResult(success: false, errorMessage: r.body);
  }

  Future<LoginResult> login(
      {required String email, required String password}) async {
    final r = await _client.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headersJson(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (r.statusCode == 201 || r.statusCode == 200) {
      final token = (jsonDecode(r.body) as Map)['access_token'] as String;
      authToken = token;
      return LoginResult(success: true, token: token);
    }
    return LoginResult(success: false, errorMessage: r.body);
  }

  // ---- Device state ----
  Future<DeviceState> getDeviceState(String deviceId) async {
    final r = await _client.get(
      Uri.parse('$baseUrl/devices/$deviceId/state'),
      headers: _headersJson(),
    );
    if (r.statusCode != 200) {
      throw Exception('GET state failed: ${r.body}');
    }
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return DeviceState(
      deviceId: j['deviceId'] as String,
      power: j['power'] as bool,
      brightness: (j['brightness'] as num).toDouble(),
      colorTemp: (j['colorTemp'] as num).toDouble(),
      lux: (j['lux'] as num).toDouble(),
      temp: (j['temp'] as num).toDouble(),
    );
  }

  Future<DeviceState> setPower(String deviceId, bool on) async {
    final r = await _client.patch(
      Uri.parse('$baseUrl/devices/$deviceId/state'),
      headers: _headersJson(),
      body: jsonEncode({'power': on}),
    );
    if (r.statusCode != 200) throw Exception('PATCH power failed: ${r.body}');
    return getDeviceState(deviceId);
  }

  Future<DeviceState> setBrightness(String deviceId, double b) async {
    final r = await _client.patch(
      Uri.parse('$baseUrl/devices/$deviceId/state'),
      headers: _headersJson(),
      body: jsonEncode({'brightness': b}),
    );
    if (r.statusCode != 200)
      throw Exception('PATCH brightness failed: ${r.body}');
    return getDeviceState(deviceId);
  }

  Future<DeviceState> setColorTemp(String deviceId, double colorTemp) async {
    final r = await _client.patch(
      Uri.parse('$baseUrl/devices/$deviceId/state'),
      headers: _headersJson(),
      body: jsonEncode({'colorTemp': colorTemp}),
    );
    if (r.statusCode != 200)
      throw Exception('PATCH colorTemp failed: ${r.body}');
    return getDeviceState(deviceId);
  }

  // ---- Telemetry (si l’ESP32 push) ----
  Future<void> pushTelemetry(String deviceId,
      {required double lux, required double temp}) async {
    final r = await _client.post(
      Uri.parse('$baseUrl/devices/$deviceId/telemetry'),
      headers: _headersJson(),
      body: jsonEncode({'lux': lux, 'temp': temp}),
    );
    if (r.statusCode != 201 && r.statusCode != 200) {
      throw Exception('POST telemetry failed: ${r.body}');
    }
  }

  // Polling “live” sans simulation (rafraîchit toutes les 2s)
  Stream<DeviceState> subscribeState(String deviceId,
      {Duration every = const Duration(seconds: 2)}) async* {
    while (true) {
      yield await getDeviceState(deviceId);
      await Future.delayed(every);
    }
  }

  // ---- Devices ----
  Future<Device> getDevice(String id) async {
    // En l'absence de GET /devices/:id côté back, on lit la liste puis on filtre.
    // (authToken est déjà défini après login/signup)
    final r = await _client.get(
      Uri.parse('$baseUrl/devices'),
      headers: _headersJson(),
    );
    if (r.statusCode != 200) {
      throw Exception('GET /devices failed: ${r.statusCode}');
    }
    final List list = jsonDecode(r.body) as List;
    final devices =
        list.map((e) => Device.fromJson(e as Map<String, dynamic>)).toList();
    final dev = devices.firstWhere(
      (d) => d.id == id,
      orElse: () => throw Exception('Device not found'),
    );
    return dev;
  }

  Future<List<Device>> listDevices({required String token}) async {
    authToken ??= token; // on l’initialise si nécessaire
    final r = await _client.get(Uri.parse('$baseUrl/devices'),
        headers: _headersJson());
    if (r.statusCode != 200)
      throw Exception('GET /devices failed: ${r.statusCode}');
    final List list = jsonDecode(r.body) as List;
    return list.map((e) => Device.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> renameDevice(String id, String name) async {
    final r = await _client.patch(
      Uri.parse('$baseUrl/devices/$id/name'),
      headers: _headersJson(),
      body: jsonEncode({'name': name}),
    );
    if (r.statusCode != 200) throw Exception('renameDevice failed: ${r.body}');
  }

  Future<void> setDeviceTargetLux(String id, double value) async {
    final r = await _client.patch(
      Uri.parse('$baseUrl/devices/$id/targetLux'),
      headers: _headersJson(),
      body: jsonEncode({'value': value}),
    );
    if (r.statusCode != 200)
      throw Exception('setDeviceTargetLux failed: ${r.body}');
  }

  // ---- Alarms ----
  Future<List<Alarm>> listAlarms(String deviceId) async {
    final r = await _client.get(
      Uri.parse('$baseUrl/devices/$deviceId/alarms'),
      headers: _headersJson(),
    );
    if (r.statusCode != 200) throw Exception('GET alarms failed');
    final List list = jsonDecode(r.body) as List;
    return list
        .map((j) => Alarm.fromJson(j as Map<String, dynamic>, deviceId))
        .toList();
  }

  Future<void> deleteAlarm(String deviceId, String id) async {
    final r = await _client.delete(
      Uri.parse('$baseUrl/devices/$deviceId/alarms/$id'),
      headers: _headersJson(),
    );
    if (r.statusCode != 200 && r.statusCode != 204)
      throw Exception('DELETE alarm failed');
  }

  Future<Alarm> saveAlarm(Alarm a) async {
    if (a.id == null) {
      final r = await _client.post(
        Uri.parse('$baseUrl/devices/${a.deviceId}/alarms'),
        headers: _headersJson(),
        body: jsonEncode(a.toBackendPayload()),
      );
      if (r.statusCode != 201 && r.statusCode != 200)
        throw Exception('POST alarm failed: ${r.body}');
      return Alarm.fromJson(jsonDecode(r.body), a.deviceId);
    } else {
      final r = await _client.patch(
        Uri.parse('$baseUrl/devices/${a.deviceId}/alarms/${a.id}'),
        headers: _headersJson(),
        body: jsonEncode(a.toBackendPayload()),
      );
      if (r.statusCode != 200) throw Exception('PATCH alarm failed');
      return Alarm.fromJson(jsonDecode(r.body), a.deviceId);
    }
  }

  Future<void> toggleAlarm(String deviceId, String id, bool enabled) async {
    final r = await _client.patch(
      Uri.parse('$baseUrl/devices/$deviceId/alarms/$id'),
      headers: _headersJson(),
      body: jsonEncode({'enabled': enabled}),
    );
    if (r.statusCode != 200) throw Exception('toggle alarm failed');
  }
}
