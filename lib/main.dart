import 'package:flutter/cupertino.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'reservation_timer_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
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