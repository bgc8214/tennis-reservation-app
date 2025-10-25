import 'package:flutter/cupertino.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'reservation_timer_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:io' show Platform;
import 'dart:async' show unawaited, Completer;
import 'firebase_options.dart';
import 'providers/court_provider.dart';
import 'providers/favorite_provider.dart';
import 'providers/alarm_provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase 초기화 시도
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase 초기화 성공');
  } catch (e) {
    debugPrint('Firebase 초기화 실패: $e');
    // Firebase 초기화 실패해도 앱은 계속 실행
  }

  // MobileAds 초기화
  try {
    await MobileAds.instance.initialize();
    debugPrint('MobileAds 초기화 성공');
  } catch (e) {
    debugPrint('MobileAds 초기화 실패: $e');
    // 광고 초기화 실패해도 앱은 계속 실행
  }

  // 앱 실행
  runApp(const MyApp());
  
  // 나머지 초기화는 백그라운드에서 진행
  unawaited(MobileAds.instance.initialize());

  // 알림 초기화
  final flutterLocalNotificationsPlugin = await _initializeNotifications();

  // 타임존 초기화
  tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
}

final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<FlutterLocalNotificationsPlugin> _initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );
  await _flutterLocalNotificationsPlugin.initialize(
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

  return _flutterLocalNotificationsPlugin;
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CourtProvider()),
        ChangeNotifierProvider(create: (_) => FavoriteProvider()),
        ChangeNotifierProvider(
          create: (_) => AlarmProvider(_flutterLocalNotificationsPlugin),
        ),
      ],
      child: CupertinoApp(
        navigatorKey: navigatorKey,
        title: '코트알람',
        theme: CupertinoThemeData(
          primaryColor: CupertinoColors.activeGreen,
          // 시스템 설정에 따라 자동으로 다크모드 적용
          brightness: MediaQueryData.fromView(
                  WidgetsBinding.instance.platformDispatcher.views.first)
              .platformBrightness,
        ),
        home: const SplashScreen(),
      ),
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
    try {
      // 릴리즈 모드와 디버그 모드에 따라 다른 광고 ID 사용
      final interstitialAdUnitId = kReleaseMode
          ? 'ca-app-pub-5291862857093530/6305546752'  // 릴리즈 모드
          : 'ca-app-pub-3940256099942544/1033173712'; // 테스트 광고 ID

      InterstitialAd.load(
        adUnitId: interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) {
            if (!_adCompleter.isCompleted) {
              _adCompleter.complete(ad);
            }
          },
          onAdFailedToLoad: (LoadAdError error) {
            debugPrint('전면 광고 로드 실패: $error');
            if (!_adCompleter.isCompleted) {
              _adCompleter.complete(null);
            }
          },
        ),
      );
    } catch (e) {
      debugPrint('광고 로드 중 예외 발생: $e');
      // 광고 로드 실패해도 앱은 계속 실행
      if (!_adCompleter.isCompleted) {
        _adCompleter.complete(null);
      }
    }
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