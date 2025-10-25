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
import 'providers/court_provider.dart';
import 'providers/favorite_provider.dart';
import 'providers/alarm_provider.dart';
import 'reservation_card.dart';
import 'services/notice_service.dart';
import 'widgets/notice_popup.dart';
import 'screens/calendar_view_page.dart';
import 'screens/settings_page.dart';

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

class _ReservationTimerPageState extends State<ReservationTimerPage> {
  Timer? _timer;
  String _searchQuery = '';
  bool _showOnlyFavorites = false;
  SortOption _sortOption = SortOption.time;

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
      if (_searchQuery.isNotEmpty &&
          !court.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '코트알람',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          // 캘린더 버튼
                          CupertinoButton(
                            padding: const EdgeInsets.all(8),
                            minSize: 0,
                            onPressed: () {
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (context) => const CalendarViewPage(),
                                ),
                              );
                            },
                            child: const Icon(
                              CupertinoIcons.calendar,
                              size: 28,
                            ),
                          ),
                          // 설정 버튼
                          CupertinoButton(
                            padding: const EdgeInsets.all(8),
                            minSize: 0,
                            onPressed: () {
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (context) => const SettingsPage(),
                                ),
                              );
                            },
                            child: const Icon(
                              CupertinoIcons.settings,
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 검색바 및 필터
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    children: [
                      CupertinoSearchTextField(
                        placeholder: '테니스장 검색',
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            color: _showOnlyFavorites
                                ? CupertinoColors.activeBlue
                                : CupertinoColors.systemGrey5,
                            minSize: 0,
                            onPressed: () {
                              setState(() {
                                _showOnlyFavorites = !_showOnlyFavorites;
                              });
                            },
                            child: Row(
                              children: [
                                Icon(
                                  CupertinoIcons.star_fill,
                                  size: 16,
                                  color: _showOnlyFavorites
                                      ? CupertinoColors.white
                                      : CupertinoColors.systemGrey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '즐겨찾기만',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _showOnlyFavorites
                                        ? CupertinoColors.white
                                        : CupertinoColors.systemGrey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 정렬 버튼
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            color: CupertinoColors.systemGrey5,
                            minSize: 0,
                            onPressed: () {
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
                                  color: CupertinoColors.systemGrey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _sortOption.label,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: CupertinoColors.systemGrey,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  CupertinoIcons.chevron_down,
                                  size: 14,
                                  color: CupertinoColors.systemGrey,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${filteredCourts.length}개',
                            style: const TextStyle(
                              fontSize: 14,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: courtProvider.isLoading
                      ? const Center(
                          child: CupertinoActivityIndicator(radius: 20.0),
                        )
                      : courtProvider.error != null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    CupertinoIcons.exclamationmark_triangle,
                                    size: 64,
                                    color: CupertinoColors.systemGrey,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    '데이터를 불러올 수 없습니다',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    courtProvider.error!,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: CupertinoColors.systemGrey,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),
                                  CupertinoButton.filled(
                                    onPressed: () async {
                                      await courtProvider.fetchCourts();
                                    },
                                    child: const Text('다시 시도'),
                                  ),
                                ],
                              ),
                            )
                          : filteredCourts.isEmpty
                              ? const Center(
                                  child: Text(
                                    '검색 결과가 없습니다',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: CupertinoColors.systemGrey,
                                    ),
                                  ),
                                )
                          : CupertinoScrollbar(
                              child: CustomScrollView(
                                slivers: <Widget>[
                                  CupertinoSliverRefreshControl(
                                    onRefresh: () async {
                                      await courtProvider.fetchCourts();
                                    },
                                  ),
                                  SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (BuildContext context, int index) {
                                        final court = filteredCourts[index];
                                        final reservationTime =
                                            court.getNextReservationDate();
                                        final remainingTime =
                                            reservationTime.difference(now);

                                        return ReservationCard(
                                          location: court.name,
                                          reservationTime: reservationTime,
                                          remainingTime: remainingTime,
                                          bookingUrl: court.bookingUrl,
                                          alarmSettings: {},
                                          isFavorite: favoriteProvider
                                              .isFavorite(court.name),
                                          onAlarmSettingsChanged:
                                              (oneDayBefore, oneHourBefore) {},
                                          onLaunchURL: _launchURL,
                                          onToggleFavorite: () {
                                            favoriteProvider
                                                .toggleFavorite(court.name);
                                          },
                                        );
                                      },
                                      childCount: filteredCourts.length,
                                    ),
                                  ),
                                ],
                              ),
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

  @override
  void dispose() {
    _timer?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }
}
