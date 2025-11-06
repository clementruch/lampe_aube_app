import 'dart:io';
import 'package:alarm/alarm.dart' as alarm_pkg;
import 'package:alarm/model/alarm_settings.dart';
import 'package:alarm/model/notification_settings.dart';
import 'package:alarm/model/volume_settings.dart';
import 'package:flutter/material.dart';
import 'package:lampe_aube_app/services/http_api.dart' show HttpApi, Alarm;

class AlarmService {
  AlarmService._();
  static final instance = AlarmService._();

  late HttpApi _api;

  Future<void> init({required HttpApi api}) async {
    _api = api;
    await alarm_pkg.Alarm.init();

    alarm_pkg.Alarm.ringing.listen((alarmSet) async {
      for (final ringing in alarmSet.alarms) {
        final serverId = ringing.payload;
        if (serverId != null && serverId.startsWith('oneshot:')) {
          final alarmId = serverId.substring('oneshot:'.length);
          try {
            await _api.toggleAlarmById(alarmId, false);
          } catch (_) {
          }
        }
      }
    });
  }

  Future<void> rescheduleAll(List<Alarm> alarms) async {
    await alarm_pkg.Alarm.stopAll();
    for (final a in alarms) {
      if (!a.enabled) continue;
      await scheduleFor(a);
    }
  }

  Future<void> scheduleFor(Alarm a) async {
    final base = (((a.id?.hashCode ?? 0) & 0x7FFFFFFF) % 1000000000);
    const String audioAsset = 'assets/alarm.mp3';

    AlarmSettings mkSettings(int id, DateTime when, {required bool oneshot}) {
      final payload = oneshot ? 'oneshot:${a.id}' : 'repeat:${a.id}';
      return AlarmSettings(
        id: id,
        dateTime: when,
        assetAudioPath: audioAsset,
        loopAudio: true,
        vibrate: true,
        androidFullScreenIntent: true,
        volumeSettings: VolumeSettings.fade(
          volume: 0.9,
          fadeDuration: const Duration(seconds: 5),
          volumeEnforced: true,
        ),
        notificationSettings: NotificationSettings(
          title: a.sunrise ? (a.label ?? 'Réveil (aube)') : (a.label ?? 'Réveil'),
          body: a.sunrise
              ? 'La lampe a commencé l’aube il y a ${a.durationMinutes} min'
              : 'Alarme simple',
          stopButton: 'Arrêter',
          icon: Platform.isAndroid ? 'notification_icon' : null,
          iconColor: const Color(0xFF2F6DB1),
        ),
        payload: payload,
        allowAlarmOverlap: false,
      );
    }

    if (a.days.isNotEmpty) {
      for (final d in a.days) {
        final id = _deriveId(base, d);
        final when = _nextWeekdayAt(d, a.hour, a.minute);
        await alarm_pkg.Alarm.set(alarmSettings: mkSettings(id, when, oneshot: false));
      }
    } else {
      final when = _nextOnceAt(a.hour, a.minute);
      await alarm_pkg.Alarm.set(alarmSettings: mkSettings(base, when, oneshot: true));
    }
  }

  Future<void> cancelFor(Alarm a) async {
    final base = (((a.id?.hashCode ?? 0) & 0x7FFFFFFF) % 1000000000);
    if (a.days.isEmpty) {
      await alarm_pkg.Alarm.stop(base);
    } else {
      for (final d in a.days) {
        await alarm_pkg.Alarm.stop(_deriveId(base, d));
      }
    }
  }

  // Helpers
  int _deriveId(int base, int day) =>
      ((base * 31 + day) & 0x7FFFFFFF) % 1000000000;

  DateTime _nextOnceAt(int h, int m) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, h, m);
    return today.isAfter(now) ? today : today.add(const Duration(days: 1));
  }

  DateTime _nextWeekdayAt(int weekday1to7, int h, int m) {
    final now = DateTime.now();
    var delta = (weekday1to7 - now.weekday) % 7;
    if (delta == 0) {
      final today = DateTime(now.year, now.month, now.day, h, m);
      if (!today.isAfter(now)) delta = 7;
    }
    final target = now.add(Duration(days: delta));
    return DateTime(target.year, target.month, target.day, h, m);
  }

  // Helpers publics
  DateTime nextOnceAt(int h, int m) => _nextOnceAt(h, m);

  DateTime nextWeekdayAt(int weekday1to7, int h, int m) =>
      _nextWeekdayAt(weekday1to7, h, m);
}
