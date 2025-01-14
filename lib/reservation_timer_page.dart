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

class ReservationTimerPage extends StatefulWidget {
  const ReservationTimerPage({Key? key}) : super(key: key);

  @override
  _ReservationTimerPageState createState() => _ReservationTimerPageState();
}

class _ReservationTimerPageState extends State<ReservationTimerPage> {
  Timer? _timer;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
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

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
    _fetchTennisCourts();
    _requestNotificationPermission();
    tz.initializeTimeZones();
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

  Future<void> _scheduleNotification(String location, DateTime reservationTime) async {
    final now = DateTime.now();

    debugPrint('Attempting to schedule notification for $location at $reservationTime');

    if (_alarmSettings[location]?['oneDayBefore'] == true) {
      final oneDayBefore = reservationTime.subtract(Duration(days: 1));
      if (oneDayBefore.isAfter(now)) {
        debugPrint('Scheduling 1 day before notification for $location at $oneDayBefore');
        await _flutterLocalNotificationsPlugin.zonedSchedule(
          0,
          '예약 알림',
          '$location 예약 1일 전 알림입니다.',
          tz.TZDateTime.from(oneDayBefore, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'reservation_timer_channel',
              'reservation_timer',
              channelDescription: '테니스장 예약 알림',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.inexact,
        );
        debugPrint('1 day before notification scheduled successfully');
      } else {
        debugPrint('1 day before notification not scheduled: time has passed');
      }
    }

    if (_alarmSettings[location]?['oneHourBefore'] == true) {
      final oneHourBefore = reservationTime.subtract(Duration(hours: 1));
      if (oneHourBefore.isAfter(now)) {
        debugPrint('Attempting to schedule 1 hour before notification for $location at $oneHourBefore');
        await _flutterLocalNotificationsPlugin.zonedSchedule(
          1,
          '예약 알림',
          '$location 예약 1시간 전 알림입니다.',
          tz.TZDateTime.from(oneHourBefore, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'reservation_timer_channel',
              'reservation_timer',
              channelDescription: '테니스장 예약 알림',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.inexact,
        );
        debugPrint('1 hour before notification scheduled successfully');
      } else {
        debugPrint('1 hour before notification not scheduled: time has passed');
      }
    }
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
    final bannerAdUnitId = kReleaseMode
        ? 'ca-app-pub-5291862857093530/5643847992' // Release mode ID
        : 'ca-app-pub-3940256099942544/9214589741'; // Debug mode ID

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
      adUnitId: 'ca-app-pub-5291862857093530/3944179124',
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
                                return SizedBox.shrink(); // Return an empty widget if data is missing
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
            bottom: 50,
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