import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'alarm_settings_dialog.dart';
import 'reservation_card.dart'; // 추가


class ReservationTimerPage extends StatefulWidget {
  const ReservationTimerPage({Key? key}) : super(key: key);

  @override
  _ReservationTimerPageState createState() => _ReservationTimerPageState();
}

class _ReservationTimerPageState extends State<ReservationTimerPage> {
  Timer? _timer;
  final Map<String, String> _bookingUrls = {
    '매헌시민의숲 테니스장': 'https://www.spo1.or.kr/front/main/main.do',
    '내곡 테니스장': 'https://www.spo1.or.kr/front/main/main.do',
  };
  Map<String, DateTime> _nextReservationTimes = {};
  final Map<String, Map<String, bool>> _alarmSettings = {
    '매헌시민의숲 테니스장': {'oneDayBefore': false, 'oneHourBefore': false},
    '내곡 테니스장': {'oneDayBefore': false, 'oneHourBefore': false},
  };

  @override
  void initState() {
    super.initState();
    _calculateNextReservationTimes();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _calculateNextReservationTimes();
      });
    });
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
      navigationBar: const CupertinoNavigationBar(
        middle: Text(
          '테니스장 예약 타이머',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
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
