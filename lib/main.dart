import 'package:flutter/cupertino.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'reservation_timer_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'dart:io' show Platform;
import 'dart:async' show unawaited;
import 'dart:async' show Completer;
import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase 초기화 먼저 실행 (필수)
  await Firebase.initializeApp();
  
  // 앱 실행
  runApp(const MyApp());
  
  // 나머지 초기화는 백그라운드에서 진행
  unawaited(MobileAds.instance.initialize());
  
  // 알림 초기화
  if (Platform.isIOS) {
    unawaited(_initializeNotifications());
  } else {
    unawaited(_initializeNotifications());
  }
}

Future<void> _initializeNotifications() async {
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
  
  tz.initializeTimeZones();
  
  if (Platform.isAndroid) {
    try {
      final bool initialized = await AndroidAlarmManager.initialize();
      debugPrint('알람 매니저 초기화 ${initialized ? "성공" : "실패"}');
    } catch (e) {
      debugPrint('알람 매니저 초기화 오류: $e');
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: '코트알람',
      theme: CupertinoThemeData(
        primaryColor: CupertinoColors.activeGreen,
        brightness: Brightness.light,
      ),
      home: SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late Completer<InterstitialAd?> _adCompleter;

  @override
  void initState() {
    super.initState();
    _adCompleter = Completer<InterstitialAd?>();
    _loadAd();
    _navigateToMain();
  }

  void _loadAd() {
    // 테스트 광고 ID 사용
    final interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712'; // 테스트 광고 ID

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          if (!_adCompleter.isCompleted) {
            _adCompleter.complete(ad);
          }
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('InterstitialAd failed to load: $error');
          if (!_adCompleter.isCompleted) {
            _adCompleter.complete(null);
          }
        },
      ),
    );
  }

  Future<void> _navigateToMain() async {
    // 광고 로딩 시작하고 잠시 대기
    final ad = await Future.any([
      _adCompleter.future,
      Future.delayed(const Duration(milliseconds: 3000), () => null),
    ]);

    if (ad != null) {
      // 광고가 로드되었으면 보여주고 메인으로 이동
      final showAdCompleter = Completer<void>();
      
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (InterstitialAd ad) {
          ad.dispose();
          _goToMainScreen();
        },
        onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
          ad.dispose();
          _goToMainScreen();
        },
      );

      await ad.show();
    } else {
      // 광고가 없으면 바로 메인으로 이동
      _goToMainScreen();
    }
  }

  void _goToMainScreen() {
    Navigator.of(context).pushReplacement(
      CupertinoPageRoute(
        builder: (context) => const ReservationTimerPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Center(
        child: Image.asset('assets/splash.png'),
      ),
    );
  }
}