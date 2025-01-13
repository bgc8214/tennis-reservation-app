import 'package:flutter/cupertino.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'reservation_timer_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await MobileAds.instance.initialize();

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