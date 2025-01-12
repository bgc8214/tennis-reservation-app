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
    '귀뚜라미 테니스장': 'https://booking.kitutennis.co.kr/reservation_01.asp',
    '정현 중보들 실내테니스장': 'https://share.gg.go.kr/facilityListO/view?instiCode=1010017&facilityId=F0001',
    '경기도 인재개발원 테니스장': 'https://share.gg.go.kr/facilityListO/view?instiCode=6411268&facilityId=F0041',
    '준 실내 테니스장': 'https://m.place.naver.com/place/1937531034/ticket',
  };
  Map<String, DateTime> _nextReservationTimes = {};
  Map<String, Map<String, bool>> _alarmSettings = {
    '매헌시민의숲 테니스장': {'oneDayBefore': false, 'oneHourBefore': false},
    '내곡 테니스장': {'oneDayBefore': false, 'oneHourBefore': false},
    '귀뚜라미 테니스장': {'oneDayBefore': false, 'oneHourBefore': false},
    '정현 중보들 실내테니스장': {'oneDayBefore': false, 'oneHourBefore': false},
    '경기도 인재개발원 테니스장': {'oneDayBefore': false, 'oneHourBefore': false},
    '준 실내 테니스장': {'oneDayBefore': false, 'oneHourBefore': false},
  };

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
    _requestNotificationPermission();
    tz.initializeTimeZones();
    _initializeNotifications();
    _loadAlarmSettings();
    _calculateNextReservationTimes();
    _nextReservationTimes = {
      '매헌시민의숲 테니스장': _getNextReservationDate(DateTime.now(), 1),
      '내곡 테니스장': _getNextReservationDate(DateTime.now(), 10),
      '귀뚜라미 테니스장': _getNextReservationDate(DateTime.now(), 15),
      '정현 중보들 실내테니스장': _getNextReservationDate(DateTime.now(), 21, hour:10),
      '경기도 인재개발원 테니스장': _getNextReservationDate(DateTime.now(), 22, hour:10),
      '준 실내 테니스장': _getNextReservationDate(DateTime.now(), 25, hour: 0),
    };
    _nextReservationTimes = Map.fromEntries(
      _nextReservationTimes.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value)),
    );
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

    if (_alarmSettings[location]?['oneDayBefore'] == true) {
      final oneDayBefore = reservationTime.subtract(Duration(days: 1));
      if (oneDayBefore.isAfter(now)) {
        await _flutterLocalNotificationsPlugin.zonedSchedule(
          0,
          '예약 알림',
          '$location 예약 1일 전 알림입니다.',
          tz.TZDateTime.from(oneDayBefore, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'your_channel_id',
              'your_channel_name',
              channelDescription: 'your_channel_description',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      }
    }

    if (_alarmSettings[location]?['oneHourBefore'] == true) {
      final oneHourBefore = reservationTime.subtract(Duration(hours: 1));
      if (oneHourBefore.isAfter(now)) {
        await _flutterLocalNotificationsPlugin.zonedSchedule(
          1,
          '예약 알림',
          '$location 예약 1시간 전 알림입니다.',
          tz.TZDateTime.from(oneHourBefore, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'your_channel_id',
              'your_channel_name',
              channelDescription: 'your_channel_description',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      }
    }
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
      '귀뚜라미 테니스장': _getNextReservationDate(now, 15),
      '정현 중보들 실내테니스장': _getNextReservationDate(now, 21, hour:10),
      '경기도 인재개발원 테니스장': _getNextReservationDate(now, 22, hour:10),
      '준 실내 테니스장': _getNextReservationDate(now, 25, hour: 0),
    };

    _nextReservationTimes = Map.fromEntries(
      _nextReservationTimes.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value)),
    );
  }

  DateTime _getNextReservationDate(DateTime now, int day, {int hour = 9}) {
    var reservationDate = DateTime(now.year, now.month, day, hour, 0);
    if (now.isAfter(reservationDate)) {
      reservationDate = DateTime(now.year, now.month + 1, day, hour, 0);
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
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/9214589741',
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
      adUnitId: 'ca-app-pub-3940256099942544/1033173712',
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

  void _onAlarmSettingsChanged(bool oneDayBefore, bool oneHourBefore) {
    final location = _nextReservationTimes.keys.firstWhere((key) => _nextReservationTimes[key] != null);
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
                          onAlarmSettingsChanged: _onAlarmSettingsChanged,
                          onLaunchURL: _launchURL,
                        );
                      },
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