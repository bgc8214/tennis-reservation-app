import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/alarm_setting.dart';
import '../models/tennis_court.dart';

class AlarmProvider with ChangeNotifier {
  Map<String, AlarmSetting> _alarmSettings = {};
  final FlutterLocalNotificationsPlugin _notificationsPlugin;

  AlarmProvider(this._notificationsPlugin);

  Map<String, AlarmSetting> get alarmSettings => _alarmSettings;

  AlarmSetting getAlarmSetting(String courtName) {
    return _alarmSettings[courtName] ?? AlarmSetting();
  }

  Future<void> loadAlarmSettings(List<String> courtNames) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _alarmSettings = {
        for (var name in courtNames)
          name: _loadAlarmSettingForCourt(prefs, name)
      };
      notifyListeners();
      debugPrint('알람 설정 로드 완료: $_alarmSettings');
    } catch (e) {
      debugPrint('알람 설정 로드 실패: $e');
    }
  }

  AlarmSetting _loadAlarmSettingForCourt(
      SharedPreferences prefs, String courtName) {
    final jsonString = prefs.getString('alarm_$courtName');
    if (jsonString != null) {
      try {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        return AlarmSetting.fromJson(json);
      } catch (e) {
        debugPrint('알람 설정 파싱 실패: $e');
      }
    }
    return AlarmSetting();
  }

  Future<void> updateAlarmSetting(
      String courtName, AlarmSetting setting, TennisCourt court) async {
    _alarmSettings[courtName] = setting;

    // SharedPreferences에 저장
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('alarm_$courtName', jsonEncode(setting.toJson()));
      notifyListeners();
      debugPrint('알람 설정 저장 완료: $courtName -> $setting');

      // 알림 스케줄링
      await scheduleNotifications(courtName, court, setting);
    } catch (e) {
      debugPrint('알람 설정 저장 실패: $e');
    }
  }

  Future<void> scheduleNotifications(
      String courtName, TennisCourt court, AlarmSetting setting) async {
    // 기존 알람 모두 취소
    await _cancelExistingNotifications(courtName);

    if (!setting.hasAnyAlarm) {
      debugPrint('$courtName의 알람이 꺼져있어 예약하지 않습니다.');
      return;
    }

    final reservationTime = court.getNextReservationDate();
    final now = DateTime.now();

    // 다음 12개월에 대한 알람 설정
    for (int i = 0; i < 12; i++) {
      final targetMonth = now.month + i;
      final targetYear = now.year + (targetMonth > 12 ? 1 : 0);
      final normalizedMonth = ((targetMonth - 1) % 12) + 1;

      final monthlyReservationTime = DateTime(
        targetYear,
        normalizedMonth,
        reservationTime.day,
        reservationTime.hour,
        reservationTime.minute,
      );

      // 1일 전 알림
      if (setting.oneDayBefore) {
        await _scheduleNotification(
          courtName,
          monthlyReservationTime,
          const Duration(days: 1),
          '1일 전',
        );
      }

      // 1시간 전 알림
      if (setting.oneHourBefore) {
        await _scheduleNotification(
          courtName,
          monthlyReservationTime,
          const Duration(hours: 1),
          '1시간 전',
        );
      }

      // 커스텀 알림
      for (var customTime in setting.customTimes) {
        await _scheduleNotification(
          courtName,
          monthlyReservationTime,
          customTime.duration,
          customTime.displayText,
        );
      }
    }

    // 예약된 알림 확인
    await _checkPendingNotifications();
  }

  Future<void> _scheduleNotification(
    String courtName,
    DateTime reservationTime,
    Duration beforeDuration,
    String label,
  ) async {
    final notificationTime = reservationTime.subtract(beforeDuration);
    final now = DateTime.now();

    if (notificationTime.isAfter(now)) {
      try {
        final notificationId =
            '${courtName}_${beforeDuration.inMinutes}_${reservationTime.millisecondsSinceEpoch}'
                .hashCode;
        final scheduledDate = tz.TZDateTime.from(notificationTime, tz.local);

        final notificationDetails = NotificationDetails(
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'default',
            badgeNumber: 1,
            interruptionLevel: InterruptionLevel.timeSensitive,
            categoryIdentifier: 'tennis_reservation',
          ),
          android: const AndroidNotificationDetails(
            'reservation_timer_channel',
            'reservation_timer',
            channelDescription: '테니스장 예약 알림',
            importance: Importance.max,
            priority: Priority.high,
            enableVibration: true,
            playSound: true,
            fullScreenIntent: true,
          ),
        );

        await _notificationsPlugin.zonedSchedule(
          notificationId,
          '예약 알림',
          '$courtName ${reservationTime.year}년 ${reservationTime.month}월 ${reservationTime.day}일 예약 $label입니다.',
          scheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload:
              'tennis_reservation_${label}_${courtName}_${reservationTime.millisecondsSinceEpoch}',
        );
        debugPrint(
            '${reservationTime.year}년 ${reservationTime.month}월 $label 알림 예약 완료');
      } catch (e) {
        debugPrint('$label 알림 예약 실패: $e');
      }
    }
  }

  Future<void> _cancelExistingNotifications(String courtName) async {
    final pendingRequests =
        await _notificationsPlugin.pendingNotificationRequests();
    for (var request in pendingRequests) {
      if (request.payload?.contains(courtName) == true) {
        await _notificationsPlugin.cancel(request.id);
        debugPrint('알람 취소: ${request.id} - ${request.body}');
      }
    }
  }

  Future<void> _checkPendingNotifications() async {
    final pendingRequests =
        await _notificationsPlugin.pendingNotificationRequests();
    for (var request in pendingRequests) {
      debugPrint('알림 ID: ${request.id}, 제목: ${request.title}, 내용: ${request.body}');
    }
    debugPrint('총 예약된 알림 개수: ${pendingRequests.length}');
  }

  Future<void> checkAndRestoreNotifications(List<TennisCourt> courts) async {
    final pendingRequests =
        await _notificationsPlugin.pendingNotificationRequests();

    for (var court in courts) {
      final setting = getAlarmSetting(court.name);
      if (setting.hasAnyAlarm) {
        // 해당 위치에 대한 알람이 있는지 확인
        bool hasNotifications = false;
        for (var request in pendingRequests) {
          if (request.payload?.contains(court.name) == true) {
            hasNotifications = true;
            break;
          }
        }

        // 알람이 없으면 다시 설정
        if (!hasNotifications) {
          debugPrint('${court.name}에 대한 알람이 없어 다시 설정합니다.');
          await scheduleNotifications(court.name, court, setting);
        }
      }
    }
  }
}
