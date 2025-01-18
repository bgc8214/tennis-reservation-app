import 'package:flutter/cupertino.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'reservation_timer_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await MobileAds.instance.initialize();
  
  // 알림 초기화
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  final DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      debugPrint('알림 응답 받음: ${response.payload}');
    },
  );
  
  // 시간대 초기화
  tz.initializeTimeZones();
  
  try {
    final bool initialized = await AndroidAlarmManager.initialize();
    debugPrint('알람 매니저 초기화 ${initialized ? "성공" : "실패"}');
  } catch (e) {
    debugPrint('알람 매니저 초기화 오류: $e');
  }

  final interstitialAdUnitId = kReleaseMode
      ? 'ca-app-pub-5291862857093530/3944179124' // Release mode ID
      : 'ca-app-pub-3940256099942544/1033173712'; // Debug mode ID

  InterstitialAd? interstitialAd;
  bool isAdLoaded = false;

  InterstitialAd.load(
    adUnitId: interstitialAdUnitId,
    request: AdRequest(),
    adLoadCallback: InterstitialAdLoadCallback(
      onAdLoaded: (InterstitialAd ad) {
        interstitialAd = ad;
        isAdLoaded = true;
      },
      onAdFailedToLoad: (LoadAdError error) {
        print('InterstitialAd failed to load: $error');
      },
    ),
  );

  await Future.delayed(Duration(seconds: 2));

  if (isAdLoaded && interstitialAd != null) {
    interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        ad.dispose();
        runApp(const MyApp());
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        ad.dispose();
        runApp(const MyApp());
      },
    );
    interstitialAd?.show();
  } else {
    runApp(const MyApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: '테니스장 예약 타이머',
      theme: CupertinoThemeData(
        primaryColor: CupertinoColors.activeGreen,
        brightness: Brightness.light,
      ),
      home: ReservationTimerPage(),
    );
  }
}