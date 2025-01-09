import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'alarm_settings_dialog.dart';
import 'reservation_card.dart';

class ReservationTimerPage extends StatefulWidget {
  const ReservationTimerPage({Key? key}) : super(key: key);

  @override
  _ReservationTimerPageState createState() => _ReservationTimerPageState();
}

class _ReservationTimerPageState extends State<ReservationTimerPage> {
  Timer? _timer;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final Map<String, String> _bookingUrls = {
    '매헌시민의숲 테니스장': 'https://m.booking.naver.com/booking/10/bizes/210031/',
    '내곡 테니스장': 'https://m.booking.naver.com/booking/10/bizes/217811/',
  };
  Map<String, DateTime> _nextReservationTimes = {};
  Map<String, Map<String, bool>> _alarmSettings = {
    '매헌시민의숲 테니스장': {'oneDayBefore': false, 'oneHourBefore': false},
    '내곡 테니스장': {'oneDayBefore': false, 'oneHourBefore': false},
  };

  @override
  void initState() {
    super.initState();
    _requestNotificationPermission();
    tz.initializeTimeZones();
    _initializeNotifications();
    _loadAlarmSettings();
    _calculateNextReservationTimes();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _calculateNextReservationTimes();
      });
    });
  }

  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.request();
    if (status.isDenied) {
      debugPrint('알림 권한이 거부되었습니다.');
    }
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _scheduleNotification(String location, String message) async {
    const androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'your_channel_id',
      'your_channel_name',
      channelDescription: 'your_channel_description',
      importance: Importance.max,
      priority: Priority.high,
    );
    const platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      0,
      '예약 알림',
      message,
      platformChannelSpecifics,
    );
  }

  Future<void> _loadAlarmSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _alarmSettings.forEach((key, value) {
        _alarmSettings[key] = {
          'oneDayBefore': prefs.getBool('${key}_oneDayBefore') ?? false,
          'oneHourBefore': prefs.getBool('${key}_oneHourBefore') ?? false,
        };
      });
    });
  }

  Future<void> _saveAlarmSettings(String location) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${location}_oneDayBefore', _alarmSettings[location]!['oneDayBefore']!);
    await prefs.setBool('${location}_oneHourBefore', _alarmSettings[location]!['oneHourBefore']!);
  }

  void _calculateNextReservationTimes() {
    final now = DateTime.now();

    _nextReservationTimes = {
      '매헌시민의숲 테니스장': _getNextReservationDate(now, 1),
      '내곡 테니스장': _getNextReservationDate(now, 10),
    };

    _nextReservationTimes = Map.fromEntries(
      _nextReservationTimes.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value)),
    );
  }

  DateTime _getNextReservationDate(DateTime now, int day) {
    var reservationDate = DateTime(now.year, now.month, day, 9, 0);
    if (now.isAfter(reservationDate)) {
      reservationDate = DateTime(now.year, now.month + 1, day, 9, 0);
    }
    return reservationDate;
  }

  void _launchURL(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return CupertinoPageScaffold(
      // navigationBar: const CupertinoNavigationBar(
      //   middle: Text(
      //     '테니스장 예약 타이머',
      //     style: TextStyle(
      //       fontWeight: FontWeight.w600,
      //     ),
      //   ),
      // ),
      child: SafeArea(
        child: CupertinoScrollbar(
          child: ListView.builder(
            itemCount: _nextReservationTimes.length,
            itemBuilder: (context, index) {
              final location = _nextReservationTimes.keys.elementAt(index);
              final reservationTime = _nextReservationTimes[location]!;
              final remainingTime = reservationTime.difference(now);

              return ReservationCard(
                location: location,
                reservationTime: reservationTime,
                remainingTime: remainingTime,
                bookingUrl: _bookingUrls[location]!,
                alarmSettings: _alarmSettings,
                onAlarmSettingsChanged: (oneDayBefore, oneHourBefore) {
                  setState(() {
                    _alarmSettings[location] = {
                      'oneDayBefore': oneDayBefore,
                      'oneHourBefore': oneHourBefore,
                    };
                    _saveAlarmSettings(location);

                    if (oneDayBefore) {
                      _scheduleNotification(
                          location, '$location 예약 1일 전 알림입니다.');
                    }
                    if (oneHourBefore) {
                      _scheduleNotification(
                          location, '$location 예약 1시간 전 알림입니다.');
                    }
                  });
                },
                onLaunchURL: _launchURL,
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
