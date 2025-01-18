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
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'dart:io';
import 'package:flutter/services.dart';

class ReservationTimerPage extends StatefulWidget {
  const ReservationTimerPage({Key? key}) : super(key: key);

  @override
  _ReservationTimerPageState createState() => _ReservationTimerPageState();
}

class _ReservationTimerPageState extends State<ReservationTimerPage> {
  Timer? _timer;
  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  Map<String, String> _bookingUrls = {};
  Map<String, DateTime> _nextReservationTimes = {};
  Map<String, Map<String, bool>> _alarmSettings = {};

  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;
  bool _hasShownAd = false;

  final TextEditingController _suggestionController = TextEditingController();

  static const String NOTIFICATION_CHANNEL_ID = 'reservation_timer_channel';
  static const String NOTIFICATION_CHANNEL_NAME = 'reservation_timer';
  static const String NOTIFICATION_CHANNEL_DESC = '테니스장 예약 알림';

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
    _fetchTennisCourts();
    _requestNotificationPermission();
    _requestExactAlarmPermission();
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    _initializeNotifications();
    _loadAlarmSettings();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _calculateNextReservationTimes();
      });
    });
    _loadBannerAd();
  }

  Future<void> _initializeFirebase() async {
    await Firebase.initializeApp();
  }

  Future<void> _requestNotificationPermission() async {
    if (Platform.isIOS) {
      return;
    }
    
    final status = await Permission.notification.request();
    if (status.isGranted) {
      debugPrint('알림 권한이 승인되었습니다.');
    } else if (status.isDenied) {
      debugPrint('알림 권한이 거부되었습니다.');
    } else if (status.isPermanentlyDenied) {
      debugPrint('알림 권한이 영구적으로 거부되었습니다.');
    }
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    final bool? initialized = await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('알림 응답 받음: ${response.payload}');
      },
    );

    if (initialized == true) {
      debugPrint('알림 초기화 완료');
      if (Platform.isIOS) {
        // iOS에서 권한 요청
        final granted = await _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
        debugPrint('iOS 알림 권한 ${granted == true ? "승인됨" : "거부됨"}');
      }
    } else {
      debugPrint('알림 초기화 실패');
    }
  }

  Future<void> _scheduleNotification(String location, DateTime reservationTime) async {
    final now = DateTime.now();
    debugPrint('Attempting to schedule notification for $location at $reservationTime');

    if (_alarmSettings[location]?['oneDayBefore'] == true) {
      final oneDayBefore = reservationTime.subtract(Duration(days: 1));
      if (oneDayBefore.isAfter(now)) {
        try {
          final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
          
          if (Platform.isAndroid) {
            _sendReservationNotification(notificationId, {
              'title': '예약 알림',
              'body': '$location 예약 1일 전 알림입니다.',
            });
          } else if (Platform.isIOS) {
            debugPrint('iOS 알림 설정 시작 - 1일 전');
            
            final scheduledDate = tz.TZDateTime.from(oneDayBefore, tz.local);
            debugPrint('iOS 알림 예약 시간 (1일 전): $scheduledDate');

            final notificationDetails = NotificationDetails(
              iOS: DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
                sound: 'default',
                badgeNumber: 1,
                interruptionLevel: InterruptionLevel.timeSensitive,
                categoryIdentifier: 'tennis_reservation',
              ),
              android: AndroidNotificationDetails(
                'reservation_timer_channel',
                'reservation_timer',
                channelDescription: '테니스장 예약 알림',
                importance: Importance.max,
                priority: Priority.high,
              ),
            );

            await _flutterLocalNotificationsPlugin.zonedSchedule(
              notificationId,
              '예약 알림',
              '$location 1일 전 알림입니다.',
              scheduledDate,
              notificationDetails,
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
              payload: 'tennis_reservation_1day',
            );
            debugPrint('iOS 1일 전 알림 예약 완료');
          }
          debugPrint('1 day before notification scheduled successfully for $location');
        } catch (e) {
          debugPrint('Failed to schedule 1 day before notification: $e');
        }
      } else {
        debugPrint('1 day before notification not scheduled: time has passed');
      }
    }

    if (_alarmSettings[location]?['oneHourBefore'] == true) {
      final oneHourBefore = reservationTime.subtract(Duration(hours: 1));
      if (oneHourBefore.isAfter(now)) {
        try {
          final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
          
          if (Platform.isAndroid) {
            _sendReservationNotification(notificationId, {
              'title': '예약 알림',
              'body': '$location 예약 1시간 전 알림입니다.',
            });
          } else if (Platform.isIOS) {
            debugPrint('iOS 알림 설정 시작 - 1시간 전');
            
            final scheduledDate = tz.TZDateTime.from(oneHourBefore, tz.local);
            debugPrint('iOS 알림 예약 시간 (1시간 전): $scheduledDate');

            final notificationDetails = NotificationDetails(
              iOS: DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
                sound: 'default',
                badgeNumber: 1,
                interruptionLevel: InterruptionLevel.timeSensitive,
                categoryIdentifier: 'tennis_reservation',
              ),
              android: AndroidNotificationDetails(
                'reservation_timer_channel',
                'reservation_timer',
                channelDescription: '테니스장 예약 알림',
                importance: Importance.max,
                priority: Priority.high,
              ),
            );

            await _flutterLocalNotificationsPlugin.zonedSchedule(
              notificationId,
              '예약 알림',
              '$location 1시간 전 알림입니다.',
              scheduledDate,
              notificationDetails,
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
              payload: 'tennis_reservation_1hour',
            );
            debugPrint('iOS 1시간 전 알림 예약 완료');
          }
          debugPrint('1 hour before notification scheduled successfully for $location');
        } catch (e) {
          debugPrint('Failed to schedule 1 hour before notification: $e');
        }
      } else {
        debugPrint('1 hour before notification not scheduled: time has passed');
      }
    }

    // 예약된 알림 확인
    await _checkPendingNotifications();
  }

  Future<void> _loadAlarmSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    setState(() {
      _alarmSettings = {
        for (var location in _nextReservationTimes.keys)
          location: {
            'oneDayBefore': keys.contains('${location}_oneDayBefore') ? prefs.getBool('${location}_oneDayBefore') ?? false : false,
            'oneHourBefore': keys.contains('${location}_oneHourBefore') ? prefs.getBool('${location}_oneHourBefore') ?? false : false,
          }
      };
    });
  }

  Future<void> _saveAlarmSettings(String location) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${location}_oneDayBefore', _alarmSettings[location]?['oneDayBefore'] ?? false);
    await prefs.setBool('${location}_oneHourBefore', _alarmSettings[location]?['oneHourBefore'] ?? false);
  }

  void _calculateNextReservationTimes() {
    final now = DateTime.now();
    _nextReservationTimes = {
      for (var location in _nextReservationTimes.keys)
        location: _getNextReservationDate(
          now,
          _nextReservationTimes[location]?.day ?? 1,
          hour: _nextReservationTimes[location]?.hour ?? 9,
          minute: _nextReservationTimes[location]?.minute ?? 0,
        )
    };
  }

  DateTime _getNextReservationDate(DateTime now, int day, {int hour = 9, int minute = 0}) {
    var reservationDate = DateTime(now.year, now.month, day, hour, minute);
    if (now.isAfter(reservationDate)) {
      reservationDate = DateTime(now.year, now.month + 1, day, hour, minute);
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

  void _loadBannerAd() {
    final bannerAdUnitId = 'ca-app-pub-3940256099942544/9214589741'; // Debug mode ID

    _bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      request: AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBannerAdReady = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          print('BannerAd failed to load: $error');
          _isBannerAdReady = false;
          ad.dispose();
        },
      ),
    )..load();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712', // Debug mode ID
      request: AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
          if (!_hasShownAd) {
            _showInterstitialAd();
            _hasShownAd = true;
          }
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('InterstitialAd failed to load: $error');
          _isInterstitialAdReady = false;
        },
      ),
    );
  }

  void _showInterstitialAd() {
    if (_isInterstitialAdReady && _interstitialAd != null) {
      _interstitialAd!.show();
      _interstitialAd = null;
      _loadInterstitialAd(); // Reload the ad for future use
    }
  }

  void _onAlarmSettingsChanged(String location, bool oneDayBefore, bool oneHourBefore) {
    setState(() {
      _alarmSettings[location] = {
        'oneDayBefore': oneDayBefore,
        'oneHourBefore': oneHourBefore,
      };
      _saveAlarmSettings(location);
      _scheduleNotification(location, _nextReservationTimes[location]!);
    });
  }

  void _submitSuggestion(String suggestion) async {
    try {
      await FirebaseFirestore.instance.collection('suggestions').add({
        'suggestion': suggestion,
        'timestamp': FieldValue.serverTimestamp(),
      });
      debugPrint('Suggestion submitted successfully');
    } catch (e) {
      debugPrint('Failed to submit suggestion: $e');
    }
  }

  Future<void> _fetchTennisCourts() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('tennis_courts').get();
      final courts = snapshot.docs.map((doc) => doc.data()).toList();
      if (courts.isNotEmpty) {
        setState(() {
          for (var court in courts) {
            _bookingUrls[court['name']] = court['bookingUrl'] ?? '';
            _nextReservationTimes[court['name']] = _getNextReservationDate(
              DateTime.now(),
              court['day'] ?? 1,
              hour: court['hour'] ?? 9,
              minute: court['minute'] ?? 0,
            );
          }
          _nextReservationTimes = Map.fromEntries(
            _nextReservationTimes.entries.toList()
              ..sort((a, b) => a.value.compareTo(b.value)),
          );
          _alarmSettings = {
            for (var court in courts)
              court['name']: {'oneDayBefore': false, 'oneHourBefore': false}
          };
        });
        _loadAlarmSettings();
      }
    } catch (e) {
      debugPrint('Failed to fetch tennis courts: $e');
    }
  }

  Future<void> _requestExactAlarmPermission() async {
    if (Platform.isAndroid) {
      const MethodChannel channel = MethodChannel('exact_alarm_permission');

      try {
        final bool isGranted = await channel.invokeMethod('checkExactAlarmPermission');
        if (!isGranted) {
          final intent = AndroidIntent(
            action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
            package: 'com.boss.tennis_app',
          );
          await intent.launch();
        }
      } catch (e) {
        print("Error checking exact alarm permission: $e");
      }
    }
  }

  @pragma('vm:entry-point')
  static void _sendReservationNotification(int id, Map<String, dynamic> params) async {
    debugPrint("🔥 예약 알림 콜백 시작");
    
    try {
      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      
      const AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
        'reservation_channel',
        'Reservation Notifications',
        channelDescription: '테니스장 예약 알림을 위한 채널',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );

      final DarwinNotificationDetails iOSNotificationDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        badgeNumber: 1,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );
      
      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: iOSNotificationDetails,
      );
      
      await flutterLocalNotificationsPlugin.show(
        id,
        params['title'],
        params['body'],
        notificationDetails,
      );
      debugPrint("🔥 예약 알림 전송 완료");
    } catch (e, stackTrace) {
      debugPrint("🔥 예약 알림 처리 중 오류 발생: $e");
      debugPrint("🔥 스택 트레이스: $stackTrace");
    }
  }

  Future<void> _checkPendingNotifications() async {
    final pendingRequests = await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
    for (var request in pendingRequests) {
      debugPrint('알림 ID: ${request.id}, 제목: ${request.title}, 내용: ${request.body}');
    }
    debugPrint('총 예약된 알림 개수: ${pendingRequests.length}');
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return CupertinoPageScaffold(
      child: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: CupertinoScrollbar(
                    child: CustomScrollView(
                      slivers: <Widget>[
                        CupertinoSliverRefreshControl(
                          onRefresh: () async {
                            await _fetchTennisCourts();
                          },
                        ),
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (BuildContext context, int index) {
                              final location = _nextReservationTimes.keys.elementAt(index);
                              final reservationTime = _nextReservationTimes[location];
                              final bookingUrl = _bookingUrls[location];

                              if (reservationTime == null || bookingUrl == null) {
                                return SizedBox.shrink();
                              }

                              final remainingTime = reservationTime.difference(now);

                              return ReservationCard(
                                location: location,
                                reservationTime: reservationTime,
                                remainingTime: remainingTime,
                                bookingUrl: bookingUrl,
                                alarmSettings: _alarmSettings,
                                onAlarmSettingsChanged: (oneDayBefore, oneHourBefore) => _onAlarmSettingsChanged(location, oneDayBefore, oneHourBefore),
                                onLaunchURL: _launchURL,
                              );
                            },
                            childCount: _nextReservationTimes.length,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isBannerAdReady)
                  Container(
                    height: _bannerAd!.size.height.toDouble(),
                    width: _bannerAd!.size.width.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  ),
              ],
            ),
          ),
          Positioned(
            bottom: 100,
            right: 16,
            child: GestureDetector(
              onTap: () {
                showCupertinoDialog(
                  context: context,
                  builder: (context) {
                    return CupertinoAlertDialog(
                      title: Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text('테니스장 추가 건의',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      content: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Container(
                          width: double.infinity,
                          height: 120,
                          child: CupertinoTextField(
                            controller: _suggestionController,
                            placeholder: '추가를 원하는 테니스장이나 건의사항을 적어주세요',
                            maxLines: null,
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemGrey6,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      actions: [
                        CupertinoDialogAction(
                          child: Text('취소',
                            style: TextStyle(
                              color: CupertinoColors.destructiveRed,
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                        CupertinoDialogAction(
                          child: Text('보내기',
                            style: TextStyle(
                              color: CupertinoColors.activeBlue,
                            ),
                          ),
                          onPressed: () {
                            final suggestion = _suggestionController.text;
                            _submitSuggestion(suggestion);
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    );
                  },
                );
              },
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey4,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(7.0),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/customer.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }
}