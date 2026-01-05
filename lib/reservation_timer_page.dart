import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'models/tennis_court.dart';
import 'providers/court_provider.dart';
import 'providers/favorite_provider.dart';
import 'providers/alarm_provider.dart';
import 'reservation_card.dart';
import 'rolling_reservation_card.dart';
import 'services/notice_service.dart';
import 'widgets/notice_popup.dart';
import 'screens/calendar_view_page.dart';
import 'screens/settings_page.dart';
import 'theme/court_colors.dart';
import 'theme/court_typography.dart';

class ReservationTimerPage extends StatefulWidget {
  const ReservationTimerPage({Key? key}) : super(key: key);

  @override
  _ReservationTimerPageState createState() => _ReservationTimerPageState();
}

enum SortOption {
  time('시간순', CupertinoIcons.clock),
  name('이름순', CupertinoIcons.textformat_abc);

  const SortOption(this.label, this.icon);
  final String label;
  final IconData icon;
}

enum CourtTypeTab {
  all('전체'),
  monthly('월간 오픈'),
  rolling('매일 오픈');

  const CourtTypeTab(this.label);
  final String label;
}

class _ReservationTimerPageState extends State<ReservationTimerPage> {
  Timer? _timer;
  String _searchQuery = '';
  bool _showOnlyFavorites = false;
  SortOption _sortOption = SortOption.time;
  CourtTypeTab _selectedTab = CourtTypeTab.all;

  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;

  final NoticeService _noticeService = NoticeService();

  @override
  void initState() {
    super.initState();
    _initializeApp();
    _loadBannerAd();
    _checkNotices();

    // 1초마다 UI 업데이트 (카운트다운용)
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _initializeApp() async {
    // 권한 요청
    await _requestNotificationPermission();
    await _requestExactAlarmPermission();

    // Provider 데이터 로드
    if (mounted) {
      final courtProvider = context.read<CourtProvider>();
      final favoriteProvider = context.read<FavoriteProvider>();
      final alarmProvider = context.read<AlarmProvider>();

      await courtProvider.fetchCourts();
      await favoriteProvider.loadFavorites();

      final courtNames = courtProvider.courts.map((c) => c.name).toList();
      await alarmProvider.loadAlarmSettings(courtNames);
      await alarmProvider.checkAndRestoreNotifications(courtProvider.courts);
    }
  }

  Future<void> _requestNotificationPermission() async {
    if (Platform.isIOS) return;

    final status = await Permission.notification.request();
    debugPrint('알림 권한: ${status.isGranted ? "승인" : "거부"}');
  }

  Future<void> _requestExactAlarmPermission() async {
    if (Platform.isAndroid) {
      const MethodChannel channel = MethodChannel('exact_alarm_permission');
      try {
        final bool isGranted =
            await channel.invokeMethod('checkExactAlarmPermission');
        if (!isGranted) {
          final intent = AndroidIntent(
            action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
            package: 'com.boss.tennis_app',
          );
          await intent.launch();
          debugPrint('정확한 알람 권한 요청됨');
        }
      } catch (e) {
        debugPrint("Error checking exact alarm permission: $e");
      }
    }
  }

  void _loadBannerAd() {
    try {
      final bannerAdUnitId = kReleaseMode
          ? 'ca-app-pub-5291862857093530/5190376835'
          : 'ca-app-pub-3940256099942544/9214589741';

      _bannerAd = BannerAd(
        adUnitId: bannerAdUnitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) {
            setState(() {
              _isBannerAdReady = true;
            });
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint('배너 광고 로드 실패: $error');
            ad.dispose();
            setState(() {
              _isBannerAdReady = false;
            });
          },
        ),
      );

      _bannerAd?.load();
    } catch (e) {
      debugPrint('배너 광고 로드 중 예외 발생: $e');
      setState(() {
        _isBannerAdReady = false;
      });
    }
  }

  Future<void> _checkNotices() async {
    try {
      final unviewedNotice = await _noticeService.getUnviewedNotice();
      if (unviewedNotice != null && mounted) {
        await showCupertinoDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => NoticePopup(
            notice: unviewedNotice,
            onConfirm: () {
              _noticeService.markNoticeAsViewed(unviewedNotice.id);
              Navigator.pop(context);
            },
          ),
        );
      }
    } catch (e) {
      debugPrint('공지사항 확인 중 오류 발생: $e');
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
    final now = DateTime.now();
    final courtProvider = context.watch<CourtProvider>();
    final favoriteProvider = context.watch<FavoriteProvider>();

    // 검색어와 필터 적용
    var filteredCourts = courtProvider.visibleCourts.where((court) {
      // 탭 필터 적용
      switch (_selectedTab) {
        case CourtTypeTab.all:
          break; // 전체이므로 필터링 없음
        case CourtTypeTab.monthly:
          if (court.openingType != OpeningType.monthly) return false;
          break;
        case CourtTypeTab.rolling:
          if (court.openingType != OpeningType.weekly) return false;
          break;
      }

      // 검색어 필터
      if (_searchQuery.isNotEmpty &&
          !court.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      // 즐겨찾기 필터
      if (_showOnlyFavorites && !favoriteProvider.isFavorite(court.name)) {
        return false;
      }
      return true;
    }).toList();

    // 즐겨찾기가 먼저, 그 다음 선택된 정렬 방식으로 정렬
    filteredCourts.sort((a, b) {
      final aIsFavorite = favoriteProvider.isFavorite(a.name);
      final bIsFavorite = favoriteProvider.isFavorite(b.name);

      if (aIsFavorite && !bIsFavorite) return -1;
      if (!aIsFavorite && bIsFavorite) return 1;

      // 선택된 정렬 방식 적용
      switch (_sortOption) {
        case SortOption.time:
          return a.getNextReservationDate().compareTo(b.getNextReservationDate());
        case SortOption.name:
          return a.name.compareTo(b.name);
      }
    });

    return CupertinoPageScaffold(
      child: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // 헤더
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          // App icon
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/icon.png',
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '코트알람',
                            style: CourtTypography.display3.copyWith(
                              color: CourtColors.grass,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          // 캘린더 버튼
                          CupertinoButton(
                            padding: const EdgeInsets.all(10),
                            minSize: 0,
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (context) => const CalendarViewPage(),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: CourtColors.grass.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: CourtColors.grass.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                CupertinoIcons.calendar,
                                size: 22,
                                color: CourtColors.grass,
                              ),
                            ),
                          ),
                          // 설정 버튼
                          CupertinoButton(
                            padding: const EdgeInsets.all(10),
                            minSize: 0,
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (context) => const SettingsPage(),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: CourtColors.clay.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: CourtColors.clay.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                CupertinoIcons.settings,
                                size: 22,
                                color: CourtColors.clay,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 검색바 및 필터 - 간소화
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    children: [
                      // 검색바와 필터를 한 줄로
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: CourtColors.textGrey.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    CupertinoIcons.search,
                                    size: 18,
                                    color: CourtColors.textGrey,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: CupertinoTextField(
                                      placeholder: '검색',
                                      placeholderStyle: TextStyle(
                                        color: CourtColors.textGrey,
                                        fontSize: 15,
                                      ),
                                      decoration: null,
                                      style: const TextStyle(fontSize: 15),
                                      onChanged: (value) {
                                        setState(() {
                                          _searchQuery = value;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 즐겨찾기 필터
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _showOnlyFavorites = !_showOnlyFavorites;
                              });
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _showOnlyFavorites
                                    ? CourtColors.ballYellow
                                    : CourtColors.textGrey.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Icon(
                                  CupertinoIcons.star_fill,
                                  size: 20,
                                  color: _showOnlyFavorites
                                      ? CourtColors.hardCourt
                                      : CourtColors.textGrey,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // 탭 UI - 간소화
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              CourtColors.hardCourt.withOpacity(0.1),
                              CourtColors.hardCourt.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: CourtColors.ballYellow.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: CourtTypeTab.values.map((tab) {
                            final isSelected = _selectedTab == tab;
                            final tabColor = tab == CourtTypeTab.all
                                ? CourtColors.grass
                                : tab == CourtTypeTab.monthly
                                    ? CourtColors.clay
                                    : CourtColors.ballYellow;

                            return Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  setState(() {
                                    _selectedTab = tab;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOut,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    gradient: isSelected
                                        ? LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              tabColor.withOpacity(0.2),
                                              tabColor.withOpacity(0.1),
                                            ],
                                          )
                                        : null,
                                    borderRadius: BorderRadius.circular(12),
                                    border: isSelected
                                        ? Border.all(
                                            color: tabColor.withOpacity(0.5),
                                            width: 2,
                                          )
                                        : null,
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: tabColor.withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Text(
                                    tab.label,
                                    textAlign: TextAlign.center,
                                    style: CourtTypography.label1.copyWith(
                                      color: isSelected
                                          ? (tab == CourtTypeTab.rolling
                                              ? CourtColors.hardCourt
                                              : tabColor)
                                          : CourtColors.textGrey,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 정렬과 개수만 표시
                      Row(
                        children: [
                          // 정렬 버튼
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              showCupertinoModalPopup(
                                context: context,
                                builder: (context) => CupertinoActionSheet(
                                  title: const Text('정렬'),
                                  actions: SortOption.values.map((option) {
                                    return CupertinoActionSheetAction(
                                      onPressed: () {
                                        setState(() {
                                          _sortOption = option;
                                        });
                                        Navigator.pop(context);
                                      },
                                      isDefaultAction: _sortOption == option,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(option.icon, size: 20),
                                          const SizedBox(width: 8),
                                          Text(option.label),
                                          if (_sortOption == option) ...[
                                            const SizedBox(width: 8),
                                            const Icon(
                                              CupertinoIcons.check_mark,
                                              size: 20,
                                              color: CupertinoColors.activeBlue,
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  cancelButton: CupertinoActionSheetAction(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('취소'),
                                  ),
                                ),
                              );
                            },
                            child: Row(
                              children: [
                                Icon(
                                  _sortOption.icon,
                                  size: 16,
                                  color: CourtColors.textGrey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _sortOption.label,
                                  style: CourtTypography.caption.copyWith(
                                    color: CourtColors.textGrey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  CupertinoIcons.chevron_down,
                                  size: 12,
                                  color: CourtColors.textGrey,
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${filteredCourts.length}개',
                            style: CourtTypography.caption.copyWith(
                              color: CourtColors.grass,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 코트 리스트
                Expanded(
                  child: filteredCourts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.search,
                                size: 64,
                                color: CourtColors.textGrey.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '검색 결과가 없습니다',
                                style: CourtTypography.body1.copyWith(
                                  color: CourtColors.textGrey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _buildCourtsList(
                          filteredCourts,
                          favoriteProvider,
                          now,
                        ),
                ),
                if (_isBannerAdReady)
                  SizedBox(
                    height: _bannerAd!.size.height.toDouble(),
                    width: _bannerAd!.size.width.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourtsList(
    List<TennisCourt> courts,
    FavoriteProvider favoriteProvider,
    DateTime now,
  ) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: courts.length,
      itemBuilder: (context, index) {
        final court = courts[index];
        final isFavorite = favoriteProvider.isFavorite(court.name);

        if (court.openingType == OpeningType.weekly) {
          return RollingReservationCard(
            location: court.name,
            todayTargetDate: court.getTodayReservationTargetDate(),
            nextOpenTime: court.getNextReservationDate(),
            bookingUrl: court.bookingUrl,
            isFavorite: isFavorite,
            onLaunchURL: _launchURL,
            onToggleFavorite: () {
              favoriteProvider.toggleFavorite(court.name);
            },
          );
        } else {
          final nextReservation = court.getNextReservationDate();
          final remaining = nextReservation.difference(now);

          return ReservationCard(
            location: court.name,
            reservationTime: nextReservation,
            remainingTime: remaining,
            bookingUrl: court.bookingUrl,
            alarmSettings: {},
            isFavorite: isFavorite,
            onAlarmSettingsChanged: (oneDayBefore, oneHourBefore) {},
            onLaunchURL: _launchURL,
            onToggleFavorite: () {
              favoriteProvider.toggleFavorite(court.name);
            },
            openingType: court.openingType,
          );
        }
      },
    );
  }

  Widget _buildOriginalCourtsList(
    List<TennisCourt> courts,
    CourtProvider courtProvider,
    FavoriteProvider favoriteProvider,
    DateTime now,
  ) {
    // 월간 오픈과 매일 오픈 분리
    final monthlyCourts =
        courts.where((c) => c.openingType == OpeningType.monthly).toList();
    final rollingCourts =
        courts.where((c) => c.openingType == OpeningType.weekly).toList();

    // 탭에 따라 표시할 코트 필터링
    List<TennisCourt> displayCourts;
    bool showSections = false;

    switch (_selectedTab) {
      case CourtTypeTab.all:
        displayCourts = courts;
        showSections = true; // 전체 탭에서는 섹션 헤더 표시
        break;
      case CourtTypeTab.monthly:
        displayCourts = monthlyCourts;
        break;
      case CourtTypeTab.rolling:
        displayCourts = rollingCourts;
        break;
    }

    return CupertinoScrollbar(
      child: CustomScrollView(
        slivers: <Widget>[
          CupertinoSliverRefreshControl(
            onRefresh: () async {
              await courtProvider.fetchCourts();
            },
          ),
          // 월간 오픈 섹션
          if ((_selectedTab == CourtTypeTab.all || _selectedTab == CourtTypeTab.monthly) && monthlyCourts.isNotEmpty) ...[
            // 섹션 헤더 (전체 탭에서만)
            if (showSections)
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
                  child: Row(
                    children: [
                      const Text(
                        '📅',
                        style: TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '이번 달 예약 오픈',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${monthlyCourts.length}개',
                        style: const TextStyle(
                          fontSize: 16,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  final court = monthlyCourts[index];
                  final reservationTime = court.getNextReservationDate();
                  final remainingTime = reservationTime.difference(now);

                  return ReservationCard(
                    location: court.name,
                    reservationTime: reservationTime,
                    remainingTime: remainingTime,
                    bookingUrl: court.bookingUrl,
                    alarmSettings: {},
                    isFavorite: favoriteProvider.isFavorite(court.name),
                    onAlarmSettingsChanged: (oneDayBefore, oneHourBefore) {},
                    onLaunchURL: _launchURL,
                    onToggleFavorite: () {
                      favoriteProvider.toggleFavorite(court.name);
                    },
                    openingType: court.openingType,
                  );
                },
                childCount: monthlyCourts.length,
              ),
            ),
          ],
          // 매일 오픈 섹션
          if ((_selectedTab == CourtTypeTab.all || _selectedTab == CourtTypeTab.rolling) && rollingCourts.isNotEmpty) ...[
            // 섹션 헤더 (전체 탭에서만)
            if (showSections)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: monthlyCourts.isNotEmpty ? 24 : 16,
                    bottom: 8,
                  ),
                  child: Row(
                    children: [
                      const Text(
                        '🔄',
                        style: TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '매일 오픈',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${rollingCourts.length}개',
                        style: const TextStyle(
                          fontSize: 16,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  final court = rollingCourts[index];
                  final todayTargetDate = court.getTodayReservationTargetDate();
                  final nextOpenTime = court.getNextReservationDate();

                  return RollingReservationCard(
                    location: court.name,
                    todayTargetDate: todayTargetDate,
                    nextOpenTime: nextOpenTime,
                    bookingUrl: court.bookingUrl,
                    isFavorite: favoriteProvider.isFavorite(court.name),
                    onLaunchURL: _launchURL,
                    onToggleFavorite: () {
                      favoriteProvider.toggleFavorite(court.name);
                    },
                  );
                },
                childCount: rollingCourts.length,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }
}
