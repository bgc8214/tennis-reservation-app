import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'dart:io';
import '../providers/court_provider.dart';
import '../providers/favorite_provider.dart';
import '../models/tennis_court.dart';

class CalendarViewPage extends StatefulWidget {
  const CalendarViewPage({Key? key}) : super(key: key);

  @override
  State<CalendarViewPage> createState() => _CalendarViewPageState();
}

class _CalendarViewPageState extends State<CalendarViewPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  bool _localeInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeLocale();
  }

  Future<void> _initializeLocale() async {
    await initializeDateFormatting('ko_KR', null);
    if (mounted) {
      setState(() {
        _localeInitialized = true;
      });
    }
  }

  void _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (Platform.isAndroid) {
      final intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: url,
        package: 'com.nhn.android.search',
      );

      try {
        await intent.launch();
      } catch (e) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else if (Platform.isIOS) {
      final naverUrl =
          'naversearchapp://inappbrowser?url=${Uri.encodeComponent(url)}';
      final naverUri = Uri.parse(naverUrl);

      try {
        final canLaunchNaver = await canLaunchUrl(naverUri);
        if (canLaunchNaver) {
          showCupertinoModalPopup(
            context: context,
            builder: (context) => CupertinoActionSheet(
              actions: [
                CupertinoActionSheetAction(
                  child: const Text('네이버 앱으로 열기'),
                  onPressed: () async {
                    Navigator.pop(context);
                    await launchUrl(naverUri);
                  },
                ),
                CupertinoActionSheetAction(
                  child: const Text('브라우저로 열기'),
                  onPressed: () async {
                    Navigator.pop(context);
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                ),
              ],
              cancelButton: CupertinoActionSheetAction(
                child: const Text('취소'),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
          );
        } else {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_localeInitialized) {
      return const CupertinoPageScaffold(
        child: Center(
          child: CupertinoActivityIndicator(radius: 20.0),
        ),
      );
    }

    final courtProvider = context.watch<CourtProvider>();
    final favoriteProvider = context.watch<FavoriteProvider>();
    final brightness = CupertinoTheme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    // 선택된 날짜의 예약 코트들
    final reservationsOnSelectedDay = _getReservationsForDay(_selectedDay, courtProvider.visibleCourts);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('예약 캘린더'),
        previousPageTitle: '뒤로',
        backgroundColor: isDark ? CupertinoColors.black : CupertinoColors.white,
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 캘린더
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? CupertinoColors.darkBackgroundGray
                    : CupertinoColors.white,
                borderRadius: BorderRadius.circular(12),
                border: isDark
                    ? Border.all(
                        color: CupertinoColors.systemGrey4.darkColor,
                        width: 0.5)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? CupertinoColors.black.withOpacity(0.3)
                        : CupertinoColors.systemGrey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TableCalendar(
                firstDay: DateTime.utc(2024, 1, 1),
                lastDay: DateTime.utc(2025, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                calendarFormat: _calendarFormat,
                onFormatChanged: (format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                },
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                eventLoader: (day) {
                  return _getReservationsForDay(day, courtProvider.visibleCourts);
                },
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: CupertinoColors.systemBlue.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: const BoxDecoration(
                    color: CupertinoColors.activeGreen,
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: const BoxDecoration(
                    color: CupertinoColors.systemOrange,
                    shape: BoxShape.circle,
                  ),
                  outsideDaysVisible: false,
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: true,
                  titleCentered: true,
                  formatButtonShowsNext: false,
                ),
              ),
            ),
            // 선택된 날짜의 예약 목록
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  DateFormat('M월 d일 (E)', 'ko_KR').format(_selectedDay),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: reservationsOnSelectedDay.isEmpty
                  ? const Center(
                      child: Text(
                        '이 날짜에는 예약이 없습니다',
                        style: TextStyle(
                          fontSize: 16,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: reservationsOnSelectedDay.length,
                      itemBuilder: (context, index) {
                        final court = reservationsOnSelectedDay[index];
                        final isFavorite = favoriteProvider.isFavorite(court.name);
                        final reservationTime = court.getNextReservationDate();

                        return CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => _launchURL(court.bookingUrl),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? CupertinoColors.darkBackgroundGray
                                  : CupertinoColors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: isDark
                                  ? Border.all(
                                      color: CupertinoColors.systemGrey4.darkColor,
                                      width: 0.5)
                                  : null,
                              boxShadow: [
                                BoxShadow(
                                  color: isDark
                                      ? CupertinoColors.black.withOpacity(0.3)
                                      : CupertinoColors.systemGrey.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isFavorite
                                      ? CupertinoIcons.star_fill
                                      : CupertinoIcons.star,
                                  color: isFavorite
                                      ? CupertinoColors.systemYellow
                                      : CupertinoColors.systemGrey,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        court.name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${reservationTime.hour.toString().padLeft(2, '0')}:${reservationTime.minute.toString().padLeft(2, '0')} 오픈',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: CupertinoColors.systemGrey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  CupertinoIcons.chevron_right,
                                  color: CupertinoColors.systemGrey,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<TennisCourt> _getReservationsForDay(DateTime day, List<TennisCourt> courts) {
    return courts.where((court) {
      final reservationDate = court.getNextReservationDate();
      return reservationDate.day == day.day &&
          reservationDate.month == day.month &&
          reservationDate.year == day.year;
    }).toList();
  }
}
