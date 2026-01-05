import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
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
import '../theme/court_colors.dart';
import '../theme/court_typography.dart';

class CalendarViewPage extends StatefulWidget {
  const CalendarViewPage({Key? key}) : super(key: key);

  @override
  State<CalendarViewPage> createState() => _CalendarViewPageState();
}

enum CalendarFilter {
  all('전체'),
  monthly('월간 오픈'),
  rolling('매일 오픈'),
  favorites('즐겨찾기');

  const CalendarFilter(this.label);
  final String label;
}

class _CalendarViewPageState extends State<CalendarViewPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  bool _localeInitialized = false;
  CalendarFilter _selectedFilter = CalendarFilter.all;

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

    // 필터링된 코트 목록
    final filteredCourts = _getFilteredCourts(
      courtProvider.visibleCourts,
      favoriteProvider,
    );

    // 선택된 날짜의 예약 코트들
    final reservationsOnSelectedDay = _getReservationsForDay(
      _selectedDay,
      filteredCourts,
    );

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          '예약 캘린더',
          style: CourtTypography.headline3.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        previousPageTitle: '뒤로',
        backgroundColor: CourtColors.lightBg,
        border: Border(
          bottom: BorderSide(
            color: CourtColors.grass.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 필터 탭
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      CourtColors.hardCourt.withOpacity(0.08),
                      CourtColors.hardCourt.withOpacity(0.04),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: CourtColors.ballYellow.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: CalendarFilter.values.map((filter) {
                    final isSelected = _selectedFilter == filter;
                    final filterColor = filter == CalendarFilter.all
                        ? CourtColors.grass
                        : filter == CalendarFilter.monthly
                            ? CourtColors.clay
                            : filter == CalendarFilter.rolling
                                ? CourtColors.ballYellow
                                : CourtColors.urgent;

                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _selectedFilter = filter;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      filterColor.withOpacity(0.2),
                                      filterColor.withOpacity(0.1),
                                    ],
                                  )
                                : null,
                            borderRadius: BorderRadius.circular(10),
                            border: isSelected
                                ? Border.all(
                                    color: filterColor.withOpacity(0.5),
                                    width: 1.5,
                                  )
                                : null,
                          ),
                          child: Text(
                            filter.label,
                            textAlign: TextAlign.center,
                            style: CourtTypography.caption.copyWith(
                              color: isSelected
                                  ? (filter == CalendarFilter.rolling
                                      ? CourtColors.hardCourt
                                      : filterColor)
                                  : CourtColors.textGrey,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            // 캘린더
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    CourtColors.lightBgSecondary,
                    CourtColors.lightBgTertiary,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: CourtColors.grass.withOpacity(0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: CourtColors.grass.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
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
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                eventLoader: (day) {
                  return _getReservationsForDay(day, filteredCourts);
                },
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: CourtColors.grass.withOpacity(0.3),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: CourtColors.grass,
                      width: 2,
                    ),
                  ),
                  todayTextStyle: CourtTypography.label1.copyWith(
                    color: CourtColors.grass,
                    fontWeight: FontWeight.w700,
                  ),
                  selectedDecoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [CourtColors.grass, CourtColors.grassLight],
                    ),
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: CourtTypography.label1.copyWith(
                    color: CourtColors.lightBgSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                  markerDecoration: const BoxDecoration(
                    color: CourtColors.clay,
                    shape: BoxShape.circle,
                  ),
                  markerSize: 5,
                  markersMaxCount: 3,
                  outsideDaysVisible: false,
                  defaultTextStyle: CourtTypography.label1.copyWith(
                    color: CourtColors.textDark,
                  ),
                  weekendTextStyle: CourtTypography.label1.copyWith(
                    color: CourtColors.urgent,
                  ),
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: true,
                  titleCentered: true,
                  formatButtonShowsNext: false,
                  titleTextStyle: CourtTypography.headline3.copyWith(
                    fontWeight: FontWeight.w700,
                    color: CourtColors.hardCourt,
                  ),
                  formatButtonTextStyle: CourtTypography.caption.copyWith(
                    color: CourtColors.grass,
                    fontWeight: FontWeight.w600,
                  ),
                  formatButtonDecoration: BoxDecoration(
                    color: CourtColors.grass.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: CourtColors.grass.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  leftChevronIcon: Icon(
                    CupertinoIcons.chevron_left,
                    color: CourtColors.grass,
                    size: 20,
                  ),
                  rightChevronIcon: Icon(
                    CupertinoIcons.chevron_right,
                    color: CourtColors.grass,
                    size: 20,
                  ),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: CourtTypography.caption.copyWith(
                    color: CourtColors.textGrey,
                    fontWeight: FontWeight.w600,
                  ),
                  weekendStyle: CourtTypography.caption.copyWith(
                    color: CourtColors.urgent.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, events) {
                    if (events.isEmpty) return const SizedBox.shrink();

                    final courts = events.cast<TennisCourt>();
                    final urgencyColor = _getUrgencyColorForDate(date, courts);

                    return Positioned(
                      bottom: 4,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: urgencyColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: urgencyColor.withOpacity(0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // 선택된 날짜 헤더
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          CourtColors.grass.withOpacity(0.2),
                          CourtColors.grass.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: CourtColors.grass.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.calendar,
                          size: 16,
                          color: CourtColors.grass,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('M월 d일 (E)', 'ko_KR').format(_selectedDay),
                          style: CourtTypography.label1.copyWith(
                            color: CourtColors.grass,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: CourtColors.clay.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: CourtColors.clay.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      '${reservationsOnSelectedDay.length}개',
                      style: CourtTypography.label1.copyWith(
                        color: CourtColors.clay,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 예약 리스트
            Expanded(
              child: reservationsOnSelectedDay.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.calendar_badge_minus,
                            size: 64,
                            color: CourtColors.textGrey.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '이 날짜에는 예약이 없습니다',
                            style: CourtTypography.body1.copyWith(
                              color: CourtColors.textGrey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: reservationsOnSelectedDay.length,
                      itemBuilder: (context, index) {
                        final court = reservationsOnSelectedDay[index];
                        final isFavorite = favoriteProvider.isFavorite(court.name);

                        return _buildReservationCard(
                          court,
                          isFavorite,
                          favoriteProvider,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReservationCard(
    TennisCourt court,
    bool isFavorite,
    FavoriteProvider favoriteProvider,
  ) {
    final now = DateTime.now();
    final reservationTime = court.openingType == OpeningType.weekly
        ? DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day, court.hour, court.minute)
        : court.getNextReservationDate();

    final remaining = reservationTime.difference(now);
    final daysRemaining = remaining.inDays;

    // 긴급도 색상
    final urgencyColor = CourtColors.getColorForDays(daysRemaining);

    // 예약 타입 배지
    final typeColor = court.openingType == OpeningType.monthly
        ? CourtColors.clay
        : CourtColors.ballYellow;
    final typeLabel = court.openingType == OpeningType.monthly
        ? '월간'
        : '매일';

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        HapticFeedback.lightImpact();
        _launchURL(court.bookingUrl);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              CourtColors.lightBgSecondary,
              CourtColors.lightBgTertiary,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: urgencyColor.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: urgencyColor.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 즐겨찾기 아이콘
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    favoriteProvider.toggleFavorite(court.name);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isFavorite
                          ? CourtColors.ballYellow
                          : CourtColors.textGrey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isFavorite
                          ? CupertinoIcons.star_fill
                          : CupertinoIcons.star,
                      color: isFavorite
                          ? CourtColors.hardCourt
                          : CourtColors.textGrey,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // 코트 이름
                Expanded(
                  child: Text(
                    court.name,
                    style: CourtTypography.headline3.copyWith(
                      fontWeight: FontWeight.w700,
                      color: CourtColors.hardCourt,
                    ),
                  ),
                ),
                // 예약 타입 배지
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: typeColor.withOpacity(0.4),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    typeLabel,
                    style: CourtTypography.caption.copyWith(
                      color: court.openingType == OpeningType.monthly
                          ? typeColor
                          : CourtColors.hardCourt,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 예약 시간 정보
            Row(
              children: [
                Icon(
                  CupertinoIcons.clock,
                  size: 16,
                  color: urgencyColor,
                ),
                const SizedBox(width: 6),
                Text(
                  '${reservationTime.hour.toString().padLeft(2, '0')}:${reservationTime.minute.toString().padLeft(2, '0')} 오픈',
                  style: CourtTypography.body2.copyWith(
                    color: CourtColors.textDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                // 남은 시간
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: urgencyColor,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: urgencyColor.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    _formatRemainingTime(remaining),
                    style: CourtTypography.caption.copyWith(
                      color: CourtColors.lightBgSecondary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            // 매일 오픈인 경우 예약 가능 날짜 표시
            if (court.openingType == OpeningType.weekly) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: CourtColors.ballYellow.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: CourtColors.ballYellow.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.arrow_right_circle,
                      size: 14,
                      color: CourtColors.hardCourt,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${DateFormat('M월 d일 (E)', 'ko_KR').format(DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day).add(const Duration(days: 7)))} 예약 가능',
                      style: CourtTypography.caption.copyWith(
                        color: CourtColors.hardCourt,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatRemainingTime(Duration remaining) {
    if (remaining.isNegative) {
      return '종료됨';
    }

    final days = remaining.inDays;
    final hours = remaining.inHours % 24;
    final minutes = remaining.inMinutes % 60;

    if (days > 0) {
      return 'D-$days';
    } else if (hours > 0) {
      return '${hours}시간 ${minutes}분';
    } else {
      return '$minutes분';
    }
  }

  List<TennisCourt> _getFilteredCourts(
    List<TennisCourt> courts,
    FavoriteProvider favoriteProvider,
  ) {
    return courts.where((court) {
      switch (_selectedFilter) {
        case CalendarFilter.all:
          return true;
        case CalendarFilter.monthly:
          return court.openingType == OpeningType.monthly;
        case CalendarFilter.rolling:
          return court.openingType == OpeningType.weekly;
        case CalendarFilter.favorites:
          return favoriteProvider.isFavorite(court.name);
      }
    }).toList();
  }

  List<TennisCourt> _getReservationsForDay(
    DateTime day,
    List<TennisCourt> courts,
  ) {
    return courts.where((court) {
      if (court.openingType == OpeningType.weekly) {
        // 매일 오픈: 매일 오픈하므로 모든 날짜에 표시
        return true;
      } else {
        // 월간 오픈: 해당 월의 특정 일에만 표시
        return court.day == day.day;
      }
    }).toList();
  }

  Color _getUrgencyColorForDate(DateTime date, List<TennisCourt> courts) {
    final now = DateTime.now();
    int minDays = 999;

    for (final court in courts) {
      final reservationTime = court.openingType == OpeningType.weekly
          ? DateTime(date.year, date.month, date.day, court.hour, court.minute)
          : court.getNextReservationDate();

      final remaining = reservationTime.difference(now);
      final days = remaining.inDays;

      if (days < minDays) {
        minDays = days;
      }
    }

    return CourtColors.getColorForDays(minDays);
  }
}
